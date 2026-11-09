# syntax=docker/dockerfile:1.7

# ----------------------------
# QMM2 (https://github.com/thecybermind/qmm2), the plugin manager the match statistics plugin runs
# in. Built on Debian 12 like the base image, because the upstream Linux builds need glibc 2.38.
# QMM2_COMMIT is the commit LANCommander.MatchStatistics.QMM is built against.
# The sed fixes QMM2's console output (its own messages and the plugin's, lc_status too), which it
# hands to the engine through a pointer into a temporary string that is already freed
# ----------------------------
FROM debian:bookworm-slim AS qmm2

ARG QMM2_COMMIT=c60ac2392f4983c944971e71292c45235d6cedaf
ARG QMM_SDKS_COMMIT=30c923f3b6a589418f8be995eeb439089940efcd

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git make g++ && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init -q qmm2 && git -C qmm2 fetch -q --depth 1 https://github.com/thecybermind/qmm2 "$QMM2_COMMIT" && git -C qmm2 checkout -q FETCH_HEAD && \
    git init -q qmm_sdks && git -C qmm_sdks fetch -q --depth 1 https://github.com/thecybermind/qmm_sdks "$QMM_SDKS_COMMIT" && git -C qmm_sdks checkout -q FETCH_HEAD && \
    sed -i 's|intptr_t args\[\] = { (intptr_t)Log::log_format(metadata, message, false).c_str() };|std::string line = Log::log_format(metadata, message, false); intptr_t args[] = { (intptr_t)line.c_str() };|' qmm2/src/qmm.cpp && \
    grep -q 'intptr_t)line.c_str()' qmm2/src/qmm.cpp && \
    make -C qmm2 -j"$(nproc)" release64

FROM lancommander/base:latest

ENV IORTCW_URL="https://github.com/iortcw/iortcw/releases/download/1.51c/iortcw-1.51c-linux-x86_64.zip"

# Server settings
ENV START_EXE="./iowolfded.x86_64"
ENV START_ARGS="+set dedicated 2 +set sv_allowDownload 1 +set sv_dlURL \"\" +set com_hunkmegs 64"
ENV HTTP_FILESERVER_ENABLED="true"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged"
ENV HTTP_FILESERVER_FILE_PATTERN="^/.*\.(pk3|arena|bot|jpg|tga|wav|ogg)$"

# ----------------------------
# LANCommander match statistics (https://github.com/LANCommander/LANCommander.MatchStatistics.QMM)
#   - MATCH_STATS_ENABLED: auto (on when MATCH_STATS_SERVER_URL and MATCH_STATS_TOKEN are set),
#     true or false. When on, QMM2 is loaded in place of the game module and loads the plugin
#   - The MATCH_STATS_* settings become lc_* cvars in <QMM_MOD_DIR>/lancommander_qmm.cfg. Empty
#     settings are left out, so they can be set in server.cfg instead
#   - QMM_MOD_DIR is the folder of the mod the server runs (fs_game), main by default
#   - QMM_MOD makes QMM2 run the native qagame.mp.x86_64.so: QMM2 crashes the server running
#     iortcw's qagame.mp.qvm, which iortcw loads by default
# ----------------------------
ENV MATCH_STATS_ENABLED="auto" \
    MATCH_STATS_SERVER_URL="" \
    MATCH_STATS_TOKEN="" \
    MATCH_STATS_GAME_ID="" \
    MATCH_STATS_SERVER_ID="" \
    MATCH_STATS_MIN_PLAYERS="" \
    MATCH_STATS_RECORD_BOTS="" \
    MATCH_STATS_RECORD_CHAT="" \
    QMM_GAME="RTCWMP" \
    QMM_MOD_DIR="main" \
    QMM_MOD_FILE="qagame.mp.x86_64.so" \
    QMM_PLUGIN="lancommander_qmm_x86_64_RTCWMP.so" \
    QMM_MOD="qmm_qagame.mp.x86_64.so" \
    QMM_PLUGINS="" \
    QMM_VM_GAME="0"

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

ARG MATCH_STATS_VERSION=1.0.0
ARG MATCH_STATS_SHA256=f7a01c2ed6ebbf5af3416ea661e1cfcbbace2a89ec167c22deca400d39108cbb

ADD --checksum=sha256:${MATCH_STATS_SHA256} \
    https://github.com/LANCommander/LANCommander.MatchStatistics.QMM/releases/download/v${MATCH_STATS_VERSION}/LANCommander.QMM.MatchStatistics-v${MATCH_STATS_VERSION}.zip \
    /tmp/match-stats.zip

COPY --from=qmm2 /src/qmm2/bin/release/x86_64/qmm2_x86_64.so /opt/qmm/qmm2.so

RUN unzip -q -j /tmp/match-stats.zip "qmmaddons/lancommander/${QMM_PLUGIN}" -d /opt/qmm && \
    rm /tmp/match-stats.zip

# COPY Modules/ "${BASE_MODULES}/"
COPY Hooks/ "${BASE_HOOKS}/"

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]