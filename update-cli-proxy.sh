#!/bin/bash

# Automatically download latest CLIProxyAPI release and rebuild VibeProxy
# Usage: ./update-cli-proxy.sh [VERSION]
# Example: ./update-cli-proxy.sh v6.3.57
# If no version specified, fetches the latest release

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$PROJECT_DIR/src/Sources/Resources"
TEMP_DIR=$(mktemp -d)

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ASSET_PATTERN="darwin_arm64"
elif [ "$ARCH" = "x86_64" ]; then
    ASSET_PATTERN="darwin_amd64"
else
    echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 VibeProxy CLI Proxy API Updater${NC}"
echo -e "${BLUE}Architecture: $ARCH${NC}"

# Determine version to fetch
if [ -n "$1" ]; then
    VERSION="$1"
    # Remove 'v' prefix if present
    VERSION="${VERSION#v}"
    TAG="v$VERSION"
    echo -e "${BLUE}Target version: $VERSION${NC}"
else
    echo -e "${BLUE}Fetching latest release...${NC}"
    TAG=$(gh release list --repo router-for-me/CLIProxyAPI --limit 1 --json tagName -q '.[0].tagName')
    if [ -z "$TAG" ]; then
        echo -e "${RED}❌ Unable to determine latest release tag${NC}"
        exit 1
    fi
    VERSION="${TAG#v}"
    echo -e "${BLUE}Latest version: $VERSION${NC}"
fi

# Fetch release info
echo -e "${BLUE}📥 Downloading CLIProxyAPI $VERSION ($ASSET_PATTERN)...${NC}"
ASSET_NAME="CLIProxyAPI_${VERSION}_${ASSET_PATTERN}.tar.gz"

# Get download URL
DOWNLOAD_URL=$(gh release view "$TAG" --repo router-for-me/CLIProxyAPI --json assets -q ".assets[] | select(.name == \"$ASSET_NAME\") | .url")

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}❌ Asset not found: $ASSET_NAME${NC}"
    echo -e "${YELLOW}Available assets:${NC}"
    gh release view "$TAG" --repo router-for-me/CLIProxyAPI --json assets -q ".assets[].name"
    exit 1
fi

# Download the tar.gz
cd "$TEMP_DIR"
curl -L -o "$ASSET_NAME" "$DOWNLOAD_URL"
echo -e "${GREEN}✅ Downloaded${NC}"

# Extract tar.gz
echo -e "${BLUE}📦 Extracting...${NC}"
tar -xzf "$ASSET_NAME"

# Find the binary (usually at root or in a subdirectory)
BINARY_PATH=""
if [ -f "cli-proxy-api" ]; then
    BINARY_PATH="cli-proxy-api"
elif [ -f "CLIProxyAPI" ]; then
    BINARY_PATH="CLIProxyAPI"
else
    # Search for it
    BINARY_PATH=$(find . -maxdepth 2 -type f -perm +111 ! -name "*.tar.gz" | head -1)
fi

if [ -z "$BINARY_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}❌ Binary not found in archive${NC}"
    echo -e "${YELLOW}Archive contents:${NC}"
    ls -la
    exit 1
fi

BINARY_SIZE=$(du -h "$BINARY_PATH" | cut -f1)
echo -e "${GREEN}✅ Extracted: $BINARY_PATH ($BINARY_SIZE)${NC}"

# Backup current binary
if [ -f "$RESOURCES_DIR/cli-proxy-api" ]; then
    BACKUP_PATH="$RESOURCES_DIR/cli-proxy-api.backup.$(date +%s)"
    echo -e "${BLUE}💾 Backing up current binary to: $(basename $BACKUP_PATH)${NC}"
    cp "$RESOURCES_DIR/cli-proxy-api" "$BACKUP_PATH"
fi

# Replace binary
echo -e "${BLUE}🔄 Replacing binary at $RESOURCES_DIR/cli-proxy-api...${NC}"
cp "$BINARY_PATH" "$RESOURCES_DIR/cli-proxy-api"
chmod +x "$RESOURCES_DIR/cli-proxy-api"
echo -e "${GREEN}✅ Binary replaced${NC}"

# Verify the new binary works
echo -e "${BLUE}🧪 Verifying binary...${NC}"
if "$RESOURCES_DIR/cli-proxy-api" --version &>/dev/null || "$RESOURCES_DIR/cli-proxy-api" -v &>/dev/null; then
    echo -e "${GREEN}✅ Binary verified${NC}"
else
    echo -e "${YELLOW}⚠️  Binary verification inconclusive (might still be OK)${NC}"
fi

# Rebuild VibeProxy
echo -e "${BLUE}🏗️  Rebuilding VibeProxy...${NC}"
cd "$PROJECT_DIR"

if command -v make &>/dev/null; then
    make app
else
    echo -e "${YELLOW}Make not found, running create-app-bundle.sh directly...${NC}"
    ./create-app-bundle.sh
fi

echo -e "${GREEN}✅ VibeProxy rebuilt successfully!${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✨ Update complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "Summary:"
echo "  • CLIProxyAPI version: $VERSION"
echo "  • Architecture: $ARCH"
echo "  • Binary location: $RESOURCES_DIR/cli-proxy-api"
echo "  • App bundle: $PROJECT_DIR/VibeProxy.app"
echo ""
echo "Next steps:"
echo "  1. Test the app: open $PROJECT_DIR/VibeProxy.app"
echo "  2. Or install: make install"
echo "  3. Or run: make run"
echo ""
if [ -n "$BACKUP_PATH" ]; then
    echo "Backup location: $BACKUP_PATH"
    echo "(Remove this file after confirming the new version works)"
fi
