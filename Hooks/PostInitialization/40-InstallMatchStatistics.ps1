#Requires -Modules Logging

# LANCommander match statistics: load QMM2 in place of the game module, and the LANCommander
# plugin (https://github.com/LANCommander/LANCommander.MatchStatistics.QMM) into QMM2, so the
# matches played on the server are reported to LANCommander.
#
# QMM2 and the plugin are built into the image, in /opt/qmm. QMM_GAME, QMM_MOD_DIR, QMM_MOD_FILE,
# QMM_PLUGIN, QMM_MOD and QMM_VM_GAME describe the game and are set by the image. When the match statistics
# are on, this writes into <QMM_MOD_DIR> in Merged/, so into Overlay/:
#
#   <QMM_MOD_FILE>          QMM2. The game's module that was there is kept as qmm_<QMM_MOD_FILE>,
#                           and QMM2 loads it (or the game's QVM, for games that run one)
#   qmm2.json               QMM2's settings: the game, the plugin and lancommander_qmm.cfg. One that
#                           this hook didn't write is left alone
#   qmmaddons/lancommander/ The plugin. Its .interposer/ folder keeps the logs and the reports not
#                           delivered yet
#   lancommander_qmm.cfg    The MATCH_STATS_* settings as lc_* cvars. QMM2 execs it once the plugin
#                           has registered them
#
# Turned off, the game's own module is put back.

$header = '// Generated from the MATCH_STATS_* environment variables on every start'

function ConvertTo-Bool([string] $Value) {
    switch ($Value.Trim().ToLowerInvariant()) {
        { $_ -in 'true', '1', 'yes', 'on' }   { return '1' }
        { $_ -in 'false', '0', 'no', 'off' } { return '0' }
        default                              { return $null }
    }
}

function Get-Hash([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
}

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '').Replace(';', '') + '"' }

$enabled = switch (ConvertTo-Bool "$Env:MATCH_STATS_ENABLED") {
    '1'     { $true }
    '0'     { $false }
    default { [bool]($Env:MATCH_STATS_SERVER_URL -and $Env:MATCH_STATS_TOKEN) }
}

$qmm     = '/opt/qmm/qmm2.so'
$plugin  = Join-Path '/opt/qmm' "$Env:QMM_PLUGIN"
$modDir  = "$Env:QMM_MOD_DIR"
$modFile = "$Env:QMM_MOD_FILE"
# QMM2's "mod": auto loads the game's QVM if it has one, else qmm_<QMM_MOD_FILE>
$mod     = if ($Env:QMM_MOD) { $Env:QMM_MOD } else { 'auto' }

if (-not $modDir -or -not $modFile -or -not (Test-Path -LiteralPath $qmm) -or -not (Test-Path -LiteralPath $plugin -PathType Leaf)) {
    Write-Log -Level Error "QMM2 or the match statistics plugin is missing from /opt/qmm, or QMM_MOD_DIR/QMM_MOD_FILE are empty"
    return
}

$dir      = Join-Path $Env:SERVER_ROOT $modDir
$target   = Join-Path $dir $modFile
$original = Join-Path $dir "qmm_$modFile"
$lower    = Join-Path (Join-Path $Env:SERVER_DIR $modDir) $modFile
# The hash of Server/<dir>/<file> when it was last kept as qmm_<file>, to pick up server updates
$marker   = Join-Path $dir ".qmm_$modFile.sha256"
$qmmHash  = Get-Hash $qmm

if (-not $enabled) {
    if ((Get-Hash $target) -eq $qmmHash) {
        if (Test-Path -LiteralPath $original) {
            Move-Item -Force -LiteralPath $original -Destination $target
        } else {
            Remove-Item -Force -LiteralPath $target
        }
        Remove-Item -Force -LiteralPath $marker -ErrorAction SilentlyContinue
        Write-Log "Match statistics are off; removed QMM2 from $modDir/$modFile"
    }
    return
}

if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    Write-Log -Level Error "$modDir/ not found in $Env:SERVER_ROOT, so the match statistics plugin can't be installed (QMM_MOD_DIR is the game or mod folder)"
    return
}

$lowerHash = Get-Hash $lower
$targetHash = Get-Hash $target

if ($targetHash -and $targetHash -ne $qmmHash) {
    # The game's module, from Server/ or Overlay/
    Move-Item -Force -LiteralPath $target -Destination $original
    if ($lowerHash) { Set-Content -LiteralPath $marker -Value $lowerHash }
    Write-Log "Kept $modDir/$modFile as qmm_$modFile"
} elseif ($lowerHash -and $lowerHash -ne $qmmHash -and $lowerHash -ne "$(Get-Content -LiteralPath $marker -Raw -ErrorAction SilentlyContinue)".Trim()) {
    # Server/ has a new module since QMM2 was installed: the server was updated
    Copy-Item -Force -LiteralPath $lower -Destination $original
    Set-Content -LiteralPath $marker -Value $lowerHash
    Write-Log "Server/$modDir/$modFile changed; kept the new one as qmm_$modFile"
}

if ($targetHash -ne $qmmHash) {
    Copy-Item -Force -LiteralPath $qmm -Destination $target
}

$addons = Join-Path $dir 'qmmaddons/lancommander'
New-Item -ItemType Directory -Path $addons -Force | Out-Null
$pluginTarget = Join-Path $addons $Env:QMM_PLUGIN
if ((Get-Hash $pluginTarget) -ne (Get-Hash $plugin)) {
    Copy-Item -Force -LiteralPath $plugin -Destination $pluginTarget
}

# QMM2 reads // comments in qmm2.json
$plugins = @("qmmaddons/lancommander/$Env:QMM_PLUGIN") + @("$Env:QMM_PLUGINS" -split '[\s,;]+' | Where-Object { $_ })
$json = @(
    $header
    '{'
    "  `"game`": `"$Env:QMM_GAME`","
    "  `"mod`": `"$mod`","
    '  "execcfg": "lancommander_qmm.cfg",'
    '  "plugins": ['
    (($plugins | ForEach-Object { "    `"$_`"" }) -join ",`n")
    '  ]'
    '}'
) -join "`n"

$qmmJson = Join-Path $dir 'qmm2.json'
if ((Test-Path -LiteralPath $qmmJson) -and (Get-Content -LiteralPath $qmmJson -TotalCount 1) -ne $header) {
    Write-Log -Level Warning "$modDir/qmm2.json wasn't written by this image and is left alone; it has to load qmmaddons/lancommander/$Env:QMM_PLUGIN and exec lancommander_qmm.cfg"
} else {
    [System.IO.File]::WriteAllText($qmmJson, $json + "`n")
}

# Only settings that are set, so the others can come from server.cfg. The token stays in the
# environment: the plugin expands %MATCH_STATS_TOKEN% itself
$values = [ordered]@{
    'lc_enabled'      = '1'
    'lc_server_url'   = $(if ($Env:MATCH_STATS_SERVER_URL) { ConvertTo-Quoted $Env:MATCH_STATS_SERVER_URL.TrimEnd('/') })
    'lc_token'        = $(if ($Env:MATCH_STATS_TOKEN) { '"%MATCH_STATS_TOKEN%"' })
    'lc_game_id'      = $(if ($Env:MATCH_STATS_GAME_ID) { ConvertTo-Quoted $Env:MATCH_STATS_GAME_ID })
    'lc_server_id'    = $(if ($Env:MATCH_STATS_SERVER_ID) { ConvertTo-Quoted $Env:MATCH_STATS_SERVER_ID })
    'lc_min_players'  = $Env:MATCH_STATS_MIN_PLAYERS
    'lc_record_bots'  = $(if ($Env:MATCH_STATS_RECORD_BOTS) { ConvertTo-Bool $Env:MATCH_STATS_RECORD_BOTS })
    'lc_record_chat'  = $(if ($Env:MATCH_STATS_RECORD_CHAT) { ConvertTo-Bool $Env:MATCH_STATS_RECORD_CHAT })
}

$lines = @("$header, set the others in server.cfg")
foreach ($key in $values.Keys) {
    if ($values[$key]) { $lines += "set $key $($values[$key])" }
}

$cfg = Join-Path $dir 'lancommander_qmm.cfg'
[System.IO.File]::WriteAllText($cfg, ($lines -join "`n") + "`n")

# QMM2 only loads in place of a native module
if ($Env:QMM_VM_GAME) {
    $Env:START_ARGS = "+set vm_game $Env:QMM_VM_GAME $Env:START_ARGS".Trim()
}

# The server runs as UID:GID and the plugin writes .interposer/ next to itself. Not -R through
# Merged/, which would copy every file up into Overlay/
chown "$($Env:UID):$($Env:GID)" $target $qmmJson $cfg (Join-Path $dir 'qmmaddons') $addons $pluginTarget

foreach ($setting in 'MATCH_STATS_SERVER_URL', 'MATCH_STATS_TOKEN', 'MATCH_STATS_GAME_ID') {
    if (-not [Environment]::GetEnvironmentVariable($setting)) {
        Write-Log -Level Warning "Match statistics are on, but $setting is empty; set it here or as lc_* in server.cfg"
    }
}

Write-Log "Match statistics are on: QMM2 ($Env:QMM_GAME) in $modDir/$modFile, plugin $Env:QMM_PLUGIN"
