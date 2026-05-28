#!/bin/bash

# Simple Live Reload for VibeProxy Development
# Uses find + entr for file watching (lightweight alternative to fswatch)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 VibeProxy Simple Live Reload${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if entr is available
if ! command -v entr &> /dev/null; then
    echo -e "${YELLOW}Installing entr for file watching...${NC}"
    if command -v brew &> /dev/null; then
        brew install entr
    else
        echo -e "${RED}Please install entr: brew install entr${NC}"
        exit 1
    fi
fi

# Function to rebuild
rebuild() {
    echo -e "${BLUE}🔨 Rebuilding VibeProxy...${NC}"
    
    # Clean build
    rm -rf src/.build
    
    # Build Swift app
    if swift build; then
        echo -e "${GREEN}✅ Swift build successful${NC}"
        
        # Create app bundle
        if ./create-app-bundle.sh; then
            echo -e "${GREEN}✅ App bundle updated${NC}"
            
            # Copy to Applications
            if [ -d "VibeProxy.app" ]; then
                sudo cp -r VibeProxy.app /Applications/
                echo -e "${GREEN}✅ App copied to /Applications${NC}"
                
                # Show file size
                BINARY_SIZE=$(ls -lh src/Sources/Resources/cli-proxy-api 2>/dev/null | awk '{print $5}' || echo "Unknown")
                echo -e "${BLUE}📊 Binary size: $BINARY_SIZE${NC}"
            fi
        else
            echo -e "${RED}❌ App bundle creation failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Swift build failed${NC}"
        return 1
    fi
}

# Function to cleanup
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping live reload...${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Initial build
echo -e "${BLUE}🔨 Initial build...${NC}"
rebuild

echo -e "${GREEN}🎯 Live reload active!${NC}"
echo -e "${YELLOW}Watching for changes in Swift files and config...${NC}"
echo -e "${BLUE}Press Ctrl+C to stop${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Watch Swift files and config
find src -name "*.swift" config.example.yaml | entr -c bash -c '
    echo "🔄 File change detected, rebuilding..."
    if '"'"'rebuild'"'"'; then
        echo "✅ Rebuild successful"
        osascript -e '"'"'display notification "Rebuilt successfully" with title "VibeProxy"'"
    else
        echo "❌ Rebuild failed"
        osascript -e 'display notification "Build failed" with title "VibeProxy"'
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
'

echo -e "${GREEN}Live reload stopped${NC}"
