#!/bin/bash
set -e

echo "Building Objective-C framework..."
cd "$(dirname "$0")/../.."
swift build -c release --product JuzbusObjCBridge
echo "Framework built successfully"
