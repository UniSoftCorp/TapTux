#!/bin/sh
# TapTuxCLISetup.sh - bootstrap only. Ensures python3 + curl exist, downloads
# TapTuxCLISetup.py and hands over to it. All JSON reading, dependency
# downloads, extraction and isolation happen in TapTuxCLISetup.py, not here.
set -eu

RAW="${TAPTUX_RAW_URL:-https://raw.githubusercontent.com/UniSoftCorp/TapTux-Repository/main}"
DEST="${TAPTUX_HOME:-$HOME/.taptux}/bootstrap"
have() { command -v "$1" >/dev/null 2>&1; }

if ! have python3 || ! have curl; then
    echo "TapTux: installing python3 and curl..." >&2
    SUDO=""; [ "$(id -u)" -eq 0 ] || ! have sudo || SUDO="sudo"
    if have pkg; then pkg install -y python curl
    elif have apt-get; then $SUDO apt-get update && $SUDO apt-get install -y python3 curl ca-certificates
    elif have dnf; then $SUDO dnf install -y python3 curl
    elif have pacman; then $SUDO pacman -Sy --noconfirm python curl
    elif have apk; then $SUDO apk add python3 curl
    else echo "TapTux: no supported package manager; install python3 and curl, then re-run." >&2; exit 1
    fi
fi

mkdir -p "$DEST"
# A token, if one is exported, goes to curl on stdin (never in argv or this file).
{ [ -z "${TAPTUX_GITHUB_TOKEN:-}" ] || printf 'Authorization: token %s\n' "$TAPTUX_GITHUB_TOKEN"; } |
    curl -fsSL -H @- "$RAW/TapTuxCLISetup.py" -o "$DEST/TapTuxCLISetup.py" ||
    { echo "TapTux: couldn't download TapTuxCLISetup.py (private repo? export TAPTUX_GITHUB_TOKEN)." >&2; exit 1; }

cd "$DEST" && exec python3 TapTuxCLISetup.py "$@"
