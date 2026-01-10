#!/bin/bash
set -e

echo "Copying dylib to node/lib..."
cd "$(dirname "$0")/.."
mkdir -p lib
cp ../.build/release/libJuzbusObjCBridge.dylib lib/

# Update install name for bundled distribution
echo "Updating dylib install name..."
install_name_tool -id @loader_path/libJuzbusObjCBridge.dylib lib/libJuzbusObjCBridge.dylib

echo "Dylib copied and configured successfully"
