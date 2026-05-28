#!/bin/bash

# VibeProxy Live Reload Development Script
# Automatically rebuilds and restarts the app when source files change

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="VibeProxy"
BUILD_DIR="src/.build"
APP_BUNDLE="VibeProxy.app"
TEMP_APP="VibeProxy-Temp.app"
WATCH_DIRS=("src" "config.example.yaml")
LOG_FILE="dev-build.log"

echo -e "${GREEN}🚀 VibeProxy Live Reload Development Server${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check prerequisites
if ! command -v fswatch &> /dev/null; then
    echo -e "${YELLOW}⚠️  Installing fswatch for file watching...${NC}"
    if command -v brew &> /dev/null; then
        brew install fswatch
    else
        echo -e "${RED}❌ Please install fswatch: brew install fswatch${NC}"
        exit 1
    fi
fi

if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Swift not found. Please install Xcode Command Line Tools.${NC}"
    exit 1
fi

# Function to build the app
build_app() {
    echo -e "${BLUE}🔨 Building VibeProxy...${NC}"
    echo "$(date): Building..." >> $LOG_FILE
    
    # Clean previous build
    rm -rf $BUILD_DIR
    
    # Build Swift app
    if swift build -v -Xswiftc -warn-concurrency 2>&1 | tee -a $LOG_FILE; then
        echo -e "${GREEN}✅ Swift build successful${NC}"
        
        # Create app bundle
        echo -e "${BLUE}📦 Creating app bundle...${NC}"
        if ./create-app-bundle.sh 2>&1 | tee -a $LOG_FILE; then
            echo -e "${GREEN}✅ App bundle created: $APP_BUNDLE${NC}"
            
            # Copy to temp location for safe atomic update
            if [ -d "$APP_BUNDLE" ]; then
                echo -e "${BLUE}🔄 Updating app...${NC}"
                cp -r "$APP_BUNDLE" "$TEMP_APP"
                
                # Atomically replace the app in Applications
                if [ -d "/Applications/$APP_BUNDLE" ]; then
                    sudo rm -rf "/Applications/$APP_BUNDLE"
                fi
                sudo cp -r "$TEMP_APP" "/Applications/"
                rm -rf "$TEMP_APP"
                
                echo -e "${GREEN}✅ App updated in /Applications${NC}"
                
                # Show model info
                if [ -f "src/Sources/Resources/cli-proxy-api" ]; then
                    echo -e "${BLUE}📊 Binary info:$(ls -lh src/Sources/Resources/cli-proxy-api | awk '{print $5}') CLI proxy API${NC}"
                fi
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

# Function to start the development server
start_dev_server() {
    echo -e "${BLUE}🚀 Starting development server...${NC}"
    
    # Start the app in background for development
    if [ -d "/Applications/$APP_BUNDLE" ]; then
        echo -e "${YELLOW}📱 Opening VibeProxy for development testing...${NC}"
        open -a "/Applications/$APP_BUNDLE"
    fi
}

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping live reload...${NC}"
    if [ ! -z "$FSWATCH_PID" ]; then
        kill $FSWATCH_PID 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Initial build
echo -e "${BLUE}🔨 Initial build...${NC}"
build_app || {
    echo -e "${RED}❌ Initial build failed. Please fix compilation errors.${NC}"
    exit 1
}

# Start development server
start_dev_server

echo -e "${GREEN}🎯 Live reload active!${NC}"
echo -e "${YELLOW}Watching directories: ${WATCH_DIRS[*]}${NC}"
echo -e "${BLUE}Log file: $LOG_FILE${NC}"
echo -e "${BLUE}Press Ctrl+C to stop${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start file watching
fswatch -o "${WATCH_DIRS[@]}" | while read; do
    echo -e "\n${YELLOW}📁 File change detected, rebuilding...${NC}"
    echo "$(date): File change detected" >> $LOG_FILE
    
    # Debounce rapid changes
    sleep 0.5
    
    if build_app; then
        echo -e "${GREEN}✅ Rebuild successful${NC}"
        
        # Show notification
        osascript -e 'display notification "VibeProxy rebuilt successfully" with title "Live Reload"' 2>/dev/null || true
    else
        echo -e "${RED}❌ Rebuild failed${NC}"
        
        # Show error notification
        osascript -e 'display notification "Build failed - check terminal" with title "Live Reload Error"' 2>/dev/null || true
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
done

# Keep the script running
wait
