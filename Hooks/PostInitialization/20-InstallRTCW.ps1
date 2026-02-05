#Requires -Modules Logging
#Requires -Modules Hooks

Invoke-Hook "PreInstallRTCW"

Write-Log -Message "Installing iortcw..."

if (-not (Test-Path -Path "${Env:SERVER_DIR}/iowolfded.x86_64")) {
    Write-Log "Could not find iowolfded.x86_64 in ${Env:SERVER_DIR}, proceeding with installation."

    $downloadUrl = $Env:IORTCW_URL

    Write-Log "Downloading iortcw from $downloadUrl"

    curl -L --output /tmp/iortcw.zip "$downloadUrl"

    unzip /tmp/iortcw.zip -d /tmp/iortcw

    Move-Item -Force -Path "/tmp/iortcw/iortcw*/*" -Destination $Env:SERVER_DIR
} else {
    Write-Log "iortcw already installed in ${Env:SERVER_DIR}, skipping installation."
}

chmod +x "${Env:SERVER_DIR}/iowolfded.x86_64"

Write-Log -Message "iortcw installation complete."

Invoke-Hook "PostInstallRTCW"

Set-Location $Env:SERVER_ROOT