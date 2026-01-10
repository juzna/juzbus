#!/bin/bash
set -e

echo "=== Installing juzbus ==="

# Check if we're in the project directory
if [ ! -f "Package.swift" ]; then
    echo "Error: Please run this script from the juzbus project root directory"
    exit 1
fi

# Build release binaries
echo "Building release binaries..."
swift build -c release

# Install binaries
echo "Installing binaries to /usr/local/bin..."
sudo cp .build/release/juzbus-directory /usr/local/bin/
sudo cp .build/release/juzbus /usr/local/bin/
sudo cp .build/release/juzbus-example /usr/local/bin/

# Make sure binaries are executable
sudo chmod +x /usr/local/bin/juzbus-directory
sudo chmod +x /usr/local/bin/juzbus
sudo chmod +x /usr/local/bin/juzbus-example

# Install LaunchAgent
echo "Installing LaunchAgent..."
mkdir -p ~/Library/LaunchAgents
cp LaunchAgents/cz.juzna.juzbus.plist ~/Library/LaunchAgents/

# Load the LaunchAgent
echo "Loading LaunchAgent..."
launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist 2>/dev/null || true

echo ""
echo "=== Installation complete! ==="
echo ""
echo "The directory service will start automatically when needed."
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
