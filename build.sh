#!/bin/bash
# macMule build script
# Creates a self-contained macMule.app inside a distributable .dmg
#
# Usage:
#   ./build.sh              Build latest stable eMule release
#   ./build.sh 0.70b        Build a specific version
#   ./build.sh 0.72a        Also works for pre-releases
#   ./build.sh --help       Show this help
#
# Prerequisites:
#   - Wine Crossover installed at /Applications/Wine Crossover.app
#     (brew install --cask gcenx/wine/wine-crossover)
#   - Rosetta 2 (softwareupdate --install-rosetta --agree-to-license)
#   - gh CLI for downloading eMule release (brew install gh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="macMule"
WINE_APP="/Applications/Wine Crossover.app"
WINE_DIR="$WINE_APP/Contents/Resources/wine"
EMULE_REPO="irwir/eMule"

# --- Help ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '2,/^$/s/^# \?//p' "$0"
    exit 0
fi

# --- Resolve version ---
if [ -n "${1:-}" ]; then
    EMULE_VERSION="$1"
    echo "=== macMule Build Script ==="
    echo "Version: $EMULE_VERSION (user-specified)"
else
    echo "=== macMule Build Script ==="
    echo "Detecting latest stable eMule release..."
    LATEST_TAG=$(gh release list --repo "$EMULE_REPO" --json tagName,isPrerelease \
        --jq '[.[] | select(.isPrerelease == false)][0].tagName')
    if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
        echo "ERROR: Could not detect latest release. Specify a version: ./build.sh 0.70b"
        exit 1
    fi
    # Extract version from tag like "eMule_v0.70b-community" -> "0.70b"
    EMULE_VERSION=$(echo "$LATEST_TAG" | sed 's/.*_v\(.*\)-community/\1/')
    echo "  Latest stable: v$EMULE_VERSION (tag: $LATEST_TAG)"
fi

EMULE_RELEASE_TAG="eMule_v${EMULE_VERSION}-community"
echo "Building $APP_NAME v$EMULE_VERSION"
echo ""

# --- Check prerequisites ---
echo "[1/7] Checking prerequisites..."

if [ ! -d "$WINE_APP" ]; then
    echo "ERROR: Wine Crossover not found at $WINE_APP"
    echo "Install with: brew install --cask gcenx/wine/wine-crossover"
    exit 1
fi

if ! /usr/bin/pgrep -q oahd 2>/dev/null; then
    echo "WARNING: Rosetta 2 may not be installed."
    echo "Install with: softwareupdate --install-rosetta --agree-to-license"
fi

if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI not found. Install with: brew install gh"
    exit 1
fi

echo "  Wine: $(wine --version 2>/dev/null || echo 'found')"
echo "  OK"

# --- Clean previous build ---
echo "[2/7] Preparing build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/tmp"

# --- Download eMule release ---
echo "[3/7] Downloading eMule v$EMULE_VERSION..."
gh release download "$EMULE_RELEASE_TAG" \
    --repo "$EMULE_REPO" \
    --pattern "*x64*.zip" \
    --dir "$BUILD_DIR/tmp"

EMULE_ZIP=$(ls "$BUILD_DIR/tmp/"*x64*.zip 2>/dev/null | head -1)
if [ -z "$EMULE_ZIP" ]; then
    echo "ERROR: No x64 zip found in release $EMULE_RELEASE_TAG"
    echo "Available assets:"
    gh release view "$EMULE_RELEASE_TAG" --repo "$EMULE_REPO" --json assets --jq '.assets[].name'
    exit 1
fi

unzip -q "$EMULE_ZIP" -d "$BUILD_DIR/tmp/emule"
echo "  Downloaded: $(basename "$EMULE_ZIP")"

# --- Create Wine prefix ---
echo "[4/7] Initializing Wine prefix..."
export WINEPREFIX="$BUILD_DIR/tmp/wine-prefix"
export WINEARCH=win64
export WINEDEBUG=-all
wineboot --init 2>/dev/null
# Wait for wineserver to finish
wineserver -w 2>/dev/null || true
echo "  Wine prefix created"

# --- Assemble .app bundle ---
echo "[5/7] Assembling $APP_NAME.app..."
APP_DIR="$BUILD_DIR/$APP_NAME.app/Contents"

mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources/wine"
mkdir -p "$APP_DIR/Resources/wine-prefix"
mkdir -p "$APP_DIR/Resources/emule/config"
mkdir -p "$APP_DIR/Resources/emule/Incoming"
mkdir -p "$APP_DIR/Resources/emule/Temp"
mkdir -p "$APP_DIR/Resources/emule/lang"
mkdir -p "$APP_DIR/Resources/emule/skins"

# App metadata
cp "$SCRIPT_DIR/resources/Info.plist" "$APP_DIR/"
cp "$SCRIPT_DIR/resources/PkgInfo" "$APP_DIR/"
cp "$SCRIPT_DIR/resources/launch.sh" "$APP_DIR/MacOS/"
chmod +x "$APP_DIR/MacOS/launch.sh"
cp "$SCRIPT_DIR/resources/eMule.icns" "$APP_DIR/Resources/"

# Wine binaries
echo "  Copying Wine (this takes a moment)..."
cp -R "$WINE_DIR/bin" "$APP_DIR/Resources/wine/"
cp -R "$WINE_DIR/lib" "$APP_DIR/Resources/wine/"
cp -R "$WINE_DIR/share" "$APP_DIR/Resources/wine/"

# Wine prefix
echo "  Copying Wine prefix..."
cp -R "$BUILD_DIR/tmp/wine-prefix/"* "$APP_DIR/Resources/wine-prefix/"

# eMule executable — find it wherever it is in the extracted zip
EMULE_EXE=$(find "$BUILD_DIR/tmp/emule" -iname "emule.exe" -type f | head -1)
if [ -z "$EMULE_EXE" ]; then
    echo "ERROR: emule.exe not found in the downloaded archive"
    exit 1
fi
cp "$EMULE_EXE" "$APP_DIR/Resources/emule/"
echo "  Found: $EMULE_EXE"

# eMule config
cp "$SCRIPT_DIR/config/"* "$APP_DIR/Resources/emule/config/"

# License
cp "$SCRIPT_DIR/LICENSE" "$APP_DIR/Resources/" 2>/dev/null || true

echo "  App bundle assembled"

# --- Create .dmg ---
echo "[6/7] Creating .dmg..."
DMG_STAGING="$BUILD_DIR/tmp/dmg-staging"
mkdir -p "$DMG_STAGING"
cp -R "$BUILD_DIR/$APP_NAME.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

DMG_NAME="macMule-v${EMULE_VERSION}.dmg"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$BUILD_DIR/$DMG_NAME" 2>/dev/null

echo "  Created $DMG_NAME"

# --- Cleanup ---
echo "[7/7] Cleaning up..."
rm -rf "$BUILD_DIR/tmp"

# --- Done ---
DMG_SIZE=$(du -h "$BUILD_DIR/$DMG_NAME" | cut -f1)
echo ""
echo "=== Build complete ==="
echo "  DMG: $BUILD_DIR/$DMG_NAME ($DMG_SIZE)"
echo "  App: $BUILD_DIR/$APP_NAME.app"
echo ""
echo "To release on GitHub:"
echo "  gh release create v$EMULE_VERSION $BUILD_DIR/$DMG_NAME \\"
echo "    --title \"macMule v$EMULE_VERSION\" \\"
echo "    --notes \"eMule for macOS. Download, drag to Applications, run.\""
