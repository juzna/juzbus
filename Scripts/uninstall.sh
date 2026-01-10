#!/bin/bash

echo "=== Uninstalling juzbus ==="

# Unload the LaunchAgent
echo "Unloading LaunchAgent..."
launchctl unload ~/Library/LaunchAgents/cz.juzna.juzbus.plist 2>/dev/null || true

# Remove LaunchAgent plist
echo "Removing LaunchAgent plist..."
rm -f ~/Library/LaunchAgents/cz.juzna.juzbus.plist

# Remove binaries
echo "Removing binaries from /usr/local/bin..."
sudo rm -f /usr/local/bin/juzbus-directory
sudo rm -f /usr/local/bin/juzbus
sudo rm -f /usr/local/bin/juzbus-example

# Remove log file
echo "Removing log file..."
rm -f /tmp/juzbus-directory.log

echo ""
echo "=== Uninstallation complete! ==="
echo ""
