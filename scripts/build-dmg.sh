#!/bin/bash

# Build VibeProxy.app, create a DMG, and install to /Applications
# Usage: ./scripts/build-dmg.sh [version]
# If no version given, auto-increments patch from latest git tag

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# --- Resolve version ---
if [ -n "$1" ]; then
    VERSION="$1"
else
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    LATEST_TAG="${LATEST_TAG#v}"
    IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_TAG"
    PATCH=$((PATCH + 1))
    VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi
echo -e "${BLUE}Building VibeProxy v${VERSION}${NC}"

# --- Build app ---
echo -e "${BLUE}Building .app bundle...${NC}"
APP_VERSION="$VERSION" ./create-app-bundle.sh

if [ ! -d "VibeProxy.app" ]; then
    echo -e "${RED}Build failed — VibeProxy.app not found${NC}"
    exit 1
fi

# --- Create DMG ---
DMG_NAME="VibeProxy-${VERSION}.dmg"
DMG_STAGING=$(mktemp -d)

echo -e "${BLUE}Staging DMG contents...${NC}"
cp -r VibeProxy.app "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo -e "${BLUE}Creating ${DMG_NAME}...${NC}"
DMG_CREATED=false
if hdiutil create -volname "VibeProxy" -srcfolder "$DMG_STAGING" -ov -format UDZO -o "$PROJECT_DIR/$DMG_NAME" 2>/dev/null; then
    DMG_CREATED=true
else
    echo -e "${YELLOW}hdiutil failed (likely missing Full Disk Access) — skipping DMG${NC}"
    echo -e "${YELLOW}Fix: System Settings → Privacy & Security → Full Disk Access → add your terminal${NC}"
fi
rm -rf "$DMG_STAGING"

# --- Install locally ---
echo -e "${BLUE}Installing to /Applications...${NC}"
if [ -d "/Applications/VibeProxy.app" ]; then
    pkill -x CLIProxyMenuBar 2>/dev/null || true
    sleep 0.5
    rm -rf "/Applications/VibeProxy.app"
fi
cp -r VibeProxy.app /Applications/

# --- Summary ---
echo ""
echo -e "${GREEN}Done!${NC}"
echo -e "  Version:  ${GREEN}v${VERSION}${NC}"
if [ "$DMG_CREATED" = true ]; then
    CHECKSUM=$(shasum -a 256 "$DMG_NAME" | awk '{print $1}')
    echo -e "  DMG:      ${GREEN}${DMG_NAME}${NC} ($(du -h "$DMG_NAME" | awk '{print $1}'))"
    echo -e "  SHA-256:  ${CHECKSUM}"
fi
echo -e "  Installed to /Applications/VibeProxy.app"
echo ""
echo -e "${YELLOW}To launch:${NC} open /Applications/VibeProxy.app"
