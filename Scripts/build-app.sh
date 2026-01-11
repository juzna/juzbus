#!/bin/bash
set -e

echo "Building Juzbus Explorer..."
swift build --product juzbus-explorer -c release

APP_NAME="Juzbus Explorer"
APP_BUNDLE=".build/Juzbus Explorer.app"
EXECUTABLE=".build/release/juzbus-explorer"

echo "Creating app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Copying executable..."
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/Juzbus Explorer"

echo "Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Juzbus Explorer</string>
	<key>CFBundleIdentifier</key>
	<string>cz.juzna.juzbus.explorer</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Juzbus Explorer</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>15.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.developer-tools</string>
</dict>
</plist>
EOF

echo "Creating PkgInfo..."
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo ""
echo "✅ App bundle created successfully!"
echo "📦 Location: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "To install to Applications:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
