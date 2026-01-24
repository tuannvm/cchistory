#!/bin/bash
# Build script for CCHistory

set -e

# Developer certificate for code signing (required)
# Set via: export DEVELOPER_IDENTITY="<your-identity>"
if [ -z "$DEVELOPER_IDENTITY" ]; then
    echo "Error: DEVELOPER_IDENTITY environment variable not set"
    echo "Set it with: export DEVELOPER_IDENTITY=\"<your-certificate-identity>\""
    echo "Find your identity with: security find-identity -v -p codesigning"
    exit 1
fi

echo "Building CCHistory..."

# Build using Swift Package Manager
swift build -c release --product CCHistory

# Create app bundle
rm -rf CCHistory.app
mkdir -p CCHistory.app/Contents/MacOS
mkdir -p CCHistory.app/Contents/Resources
cp .build/release/CCHistory CCHistory.app/Contents/MacOS/

# Copy app icon to Resources
cp CCHistory.icns CCHistory.app/Contents/Resources/

# Copy webui bundle resources to Resources
echo "Copying webui resources to app Resources..."

# Try to copy from bundle first
if [ -d ".build/release/CCHistory_CCHistory.bundle" ]; then
  cp .build/release/CCHistory_CCHistory.bundle/*.html CCHistory.app/Contents/Resources/ 2>/dev/null || true
  cp .build/release/CCHistory_CCHistory.bundle/*.css CCHistory.app/Contents/Resources/ 2>/dev/null || true
  cp .build/release/CCHistory_CCHistory.bundle/*.js CCHistory.app/Contents/Resources/ 2>/dev/null || true
fi

# Fallback: copy from source directory if files not in bundle
if [ ! -f "CCHistory.app/Contents/Resources/index.html" ]; then
  echo "Bundle files missing, copying from source..."
  cp Sources/CCHistory/webui/index.html CCHistory.app/Contents/Resources/
  cp Sources/CCHistory/webui/css/styles.css CCHistory.app/Contents/Resources/
  cp Sources/CCHistory/webui/js/app.js CCHistory.app/Contents/Resources/
fi

echo "Webui files copied:"
ls -la CCHistory.app/Contents/Resources/ | grep -E "(index|styles|app\.js)"

# Create Info.plist
cat > CCHistory.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CCHistory</string>
  <key>CFBundleIdentifier</key>
  <string>com.cchistory.app</string>
  <key>CFBundleName</key>
  <string>CCHistory</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.0.1</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleIconFile</key>
  <string>CCHistory</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

# Remove quarantine attributes
xattr -cr CCHistory.app

# Code sign with Apple Developer certificate
codesign --force --deep --sign "$DEVELOPER_IDENTITY" CCHistory.app

# Verify signature
codesign -vvv CCHistory.app

echo "Build complete: CCHistory.app"
echo "Run with: open CCHistory.app"
