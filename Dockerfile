# syntax=docker/dockerfile:1.7

FROM lancommander/base:latest

ENV IORTCW_URL="https://github.com/iortcw/iortcw/releases/download/1.51c/iortcw-1.51c-linux-x86_64.zip"

# Server settings
ENV START_EXE="./iowolfded.x86_64"
ENV START_ARGS="+set dedicated 2 +set sv_allowDownload 1 +set sv_dlURL \"\" +set com_hunkmegs 64"
ENV HTTP_FILESERVER_ENABLED="true"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged"
ENV HTTP_FILESERVER_FILE_PATTERN="^/.*\.(pk3|arena|bot|jpg|tga|wav|ogg)$"

# ----------------------------
# Dependencies
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    bzip2 \
    tar \
    unzip \
    xz-utils \
    p7zip-full \
    gosu \
  && rm -rf /var/lib/apt/lists/*

EXPOSE 27960/udp

# COPY Modules/ "${BASE_MODULES}/"
COPY Hooks/ "${BASE_HOOKS}/"

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]