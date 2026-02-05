---
sidebar_label: Docker
---

# Return to Castle Wolfenstein Docker Container

This repository provides a Dockerized **Return to Castle Wolfenstein dedicated server via iortcw** suitable for running multiplayer Return to Castle Wolfenstein servers in a clean, reproducible way.  
The image is designed for **headless operation**, supports bind-mounted mods and configuration, and handles legacy runtime dependencies required by Return to Castle Wolfenstein.

---

## Features

- Runs the **Return to Castle Wolfenstein dedicated server** (`iowolfded.x86_64`)
- Optionally downloads and extracts mod archives from URLs at startup
- Automated build & push via GitHub Actions

## Docker Compose Example
```yaml
services:
  rtcw:
    image: lancommander/rtcw:latest
    container_name: rtcw-server

    # Return to Castle Wolfenstein uses UDP
    ports:
      - "27960:27960/udp"

    # Bind mounts so files appear on the host
    volumes:
      - ./config:/config

    environment:
      # Optional: download mods/maps at startup
      # EXTRA_MOD_URLS: >
      #   https://example.com/maps.zip,
      #   https://example.com/gameplay.pk3

      # Optional overrides
      # SERVER_ARGS: '+set dedicated 2 +set sv_allowDownload 1 +set sv_dlURL \"\" +set com_hunkmegs 64'

    # Ensure container restarts if the server crashes or host reboots
    restart: unless-stopped
```

---

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Base iortcw install
    │   └── main/          # Return to Castle Wolfenstein game files base directory
    ├── Overlay/           # Files to overlay on game directory (optional)
    │   └── main/          # Return to Castle Wolfenstein overlay directory
    │       ├── maps/      # Custom maps
    │       └── ...        # Any other files you want to overlay
    ├── Merged/            # Overlayfs merged view (auto-created)
    ├── .overlay-work/     # Overlayfs work directory (auto-created)
    ├── Scripts/
        └── Hooks/         # Script files in this directory get automatically executed if registered to a hook
```
Both directories **must be writable** by Docker.

---

## Game Files
You will need to copy the `mp_pak*.pk3` files from your retail copy of Return to Castle Wolfenstein into the `/config/Server/main` directory. The server will not run without these files.

---

## Configuration
An `autoexec.cfg` file can also be created for adjusting server settings.
Example:
```
////////////////////////////////////////////////////////////
// Return to Castle Wolfenstein - iortcw Dedicated Server
// autoexec.cfg
////////////////////////////////////////////////////////////

///////////////////////
// Server Identity
///////////////////////
set sv_hostname "^2RTCW ^7Dedicated Server"
set sv_maxclients "20"
set sv_privateClients "0"
set sv_privatePassword ""

///////////////////////
// Network / Master
///////////////////////
set sv_maxRate "25000"
set sv_fps "20"
set sv_timeout "200"
set sv_zombietime "2"
set sv_allowDownload "0"

set dedicated "2"          // 2 = Internet, 1 = LAN
set sv_master1 "master.idsoftware.com"
set sv_master2 "master0.gamespy.com"
set sv_master3 ""
set sv_master4 ""
set sv_master5 ""

///////////////////////
// RCON
///////////////////////
set rconPassword "CHANGE_ME_STRONG_PASSWORD"

///////////////////////
// Game Settings
///////////////////////
set g_gametype "2"          // 0=SP, 2=Objective, 3=Stopwatch
set timelimit "30"
set fraglimit "0"
set capturelimit "0"

set g_friendlyFire "1"
set g_teamForceBalance "1"
set g_teamAutoJoin "0"

set g_voiceChatsAllowed "1"
set g_noTeamSwitching "0"
set g_antiLag "1"

///////////////////////
// Voting
///////////////////////
set g_allowVote "1"
set voteFlags "0"
set g_voteLimit "5"

///////////////////////
// PunkBuster (if used)
///////////////////////
set sv_punkbuster "0"

///////////////////////
// Logging
///////////////////////
set g_log "games.log"
set g_logSync "1"
set logfile "3"

///////////////////////
// Anti-Flood / Abuse
///////////////////////
set sv_floodProtect "1"
set sv_floodProtectSlow "4"
set sv_floodProtectFast "4"
set sv_floodProtectBurst "8"

///////////////////////
// Download / Redirect
///////////////////////
set sv_wwwDownload "0"
set sv_wwwBaseURL ""
set sv_wwwDlDisconnected "0"

///////////////////////
// Messaging
///////////////////////
set g_motd "^7Welcome to ^2RTCW^7! Respect other players."
set sv_allowAnonymous "0"

///////////////////////
// Map Rotation
///////////////////////
set d1 "map mp_assault; set nextmap vstr d2"
set d2 "map mp_base; set nextmap vstr d3"
set d3 "map mp_castle; set nextmap vstr d4"
set d4 "map mp_depot; set nextmap vstr d5"
set d5 "map mp_village; set nextmap vstr d1"

set nextmap "vstr d1"

///////////////////////
// Execute on Load
///////////////////////
map mp_assault
```
All gameplay rules, cvars, maps, and RCON settings should live here.

## Extra Mod Downloads
Archives provided via `EXTRA_MOD_URLS` are extracted into `/config/Overlay` before startup.

---

## Environment Variables

| Variable | Description | Default |
|--------|-------------|---------|
| `EXTRA_MOD_URLS` | URLs to download and extract into `/config` at startup | *(empty)* |
| `SERVER_ARGS` | Additional Return to Castle Wolfenstein command-line arguments (advanced) | *(empty)* |

### `EXTRA_MOD_URLS`

A list of URLs separated by **commas**, **spaces**, or **newlines**.

Examples:

```bash
EXTRA_MOD_URLS="https://example.com/maps.zip,https://example.com/mod.pk3"
```
Archives are extracted into /config/Overlay. Single files are copied as-is.

---

## Running the Server
### Basic run (recommended)
```bash
mkdir -p config

docker run --rm -it \
  -p 27960:27960/udp \
  -v "$(pwd)/config:/config" \
  lancommander/rtcw:latest
```
### With automatic mod downloads
docker run --rm -it \
  -p 27960:27960/udp \
  -v "$(pwd)/config:/config" \
  -e EXTRA_MOD_URLS="https://example.com/modpack.zip" \
  lancommander/rtcw:latest

## Ports
- **UDP 27960** – default Return to Castle Wolfenstein server port

## License
iortcw is distributed under its own license.
This image contains only Docker build logic and helper scripts licensed under MIT.