#!/bin/bash
# macMule build script
# Creates a self-contained macMule.app inside a distributable .dmg
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
EMULE_VERSION="0.72a"
EMULE_RELEASE_TAG="eMule_v0.72a-community"
EMULE_ASSET="emule0.72a_x64_beta1.zip"
WINE_APP="/Applications/Wine Crossover.app"
WINE_DIR="$WINE_APP/Contents/Resources/wine"

echo "=== macMule Build Script ==="
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
    --repo irwir/eMule \
    --pattern "$EMULE_ASSET" \
    --dir "$BUILD_DIR/tmp"
unzip -q "$BUILD_DIR/tmp/$EMULE_ASSET" -d "$BUILD_DIR/tmp/emule"
echo "  Downloaded and extracted"

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

# eMule executable
cp "$BUILD_DIR/tmp/emule/"*"/emule.exe" "$APP_DIR/Resources/emule/" 2>/dev/null \
    || cp "$BUILD_DIR/tmp/emule/emule.exe" "$APP_DIR/Resources/emule/"

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
