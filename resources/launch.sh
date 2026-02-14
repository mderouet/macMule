#!/bin/bash
# macMule — eMule for macOS
# Launches eMule v0.72a under Wine Crossover (x86_64 via Rosetta 2)

set -e

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WINE_DIR="$BUNDLE_DIR/Resources/wine"
EMULE_DIR="$BUNDLE_DIR/Resources/emule"
USER_PREFIX="$HOME/Library/Application Support/macMule"

# First launch: copy Wine prefix + eMule to a writable user location
if [ ! -d "$USER_PREFIX" ]; then
    cp -R "$BUNDLE_DIR/Resources/wine-prefix" "$USER_PREFIX"
    mkdir -p "$USER_PREFIX/drive_c/eMule"
    cp -R "$EMULE_DIR/"* "$USER_PREFIX/drive_c/eMule/"
fi

# Sync bundled config files that don't exist in user prefix yet
for f in staticservers.dat addresses.dat nodes.dat; do
    BUNDLE_FILE="$EMULE_DIR/config/$f"
    USER_FILE="$USER_PREFIX/drive_c/eMule/config/$f"
    if [ -f "$BUNDLE_FILE" ] && [ ! -f "$USER_FILE" ]; then
        cp "$BUNDLE_FILE" "$USER_FILE"
    fi
done

export WINEPREFIX="$USER_PREFIX"
export PATH="$WINE_DIR/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="$WINE_DIR/lib"
export WINEDEBUG=-all

exec wine64 "C:\\eMule\\emule.exe" 2>/dev/null
