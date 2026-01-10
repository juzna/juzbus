#!/bin/bash
set -e

echo "=== Installing juzbus (symlink mode for development) ==="

# Check if we're in the project directory
if [ ! -f "Package.swift" ]; then
    echo "Error: Please run this script from the juzbus project root directory"
    exit 1
fi

# Build release binaries
echo "Building release binaries..."
swift build -c release

# Get the absolute path to the build directory
BUILD_DIR="$(pwd)/.build/release"

# Remove existing binaries/symlinks
echo "Removing any existing installations..."
sudo rm -f /usr/local/bin/juzbus-directory
sudo rm -f /usr/local/bin/juzbus
sudo rm -f /usr/local/bin/juzbus-example

# Create symlinks to the build directory
echo "Creating symlinks to $BUILD_DIR..."
sudo ln -sf "$BUILD_DIR/juzbus-directory" /usr/local/bin/juzbus-directory
sudo ln -sf "$BUILD_DIR/juzbus" /usr/local/bin/juzbus
sudo ln -sf "$BUILD_DIR/juzbus-example" /usr/local/bin/juzbus-example

# Install LaunchAgent
echo "Installing LaunchAgent..."
mkdir -p ~/Library/LaunchAgents
cp LaunchAgents/cz.juzna.juzbus.plist ~/Library/LaunchAgents/

# Unload if already loaded, then load
echo "Reloading LaunchAgent..."
launchctl unload ~/Library/LaunchAgents/cz.juzna.juzbus.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist

echo ""
echo "=== Installation complete (symlink mode)! ==="
echo ""
echo "Binaries are symlinked to: $BUILD_DIR"
echo "After rebuilding with 'swift build -c release', changes will be immediately available."
echo ""
echo "To test the installation:"
echo "  1. Start an example instance:"
echo "     juzbus-example test-instance"
echo ""
echo "  2. In another terminal, list instances:"
echo "     juzbus list"
echo ""
echo "  3. Send a command to the instance:"
echo "     juzbus exec test-instance ping"
echo ""
