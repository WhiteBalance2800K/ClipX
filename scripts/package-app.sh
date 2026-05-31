#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT="ClipX"
APP_NAME="ClipX"
CONFIGURATION="${CONFIGURATION:-release}"
BUNDLE_ID="${BUNDLE_ID:-com.clipx.app}"
VERSION="${VERSION:-0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PACKAGING_DIR="$ROOT_DIR/.build/packaging"
ICONSET_DIR="$PACKAGING_DIR/AppIcon.iconset"
ICON_PNG="$PACKAGING_DIR/AppIcon-1024.png"
ICON_SWIFT="$PACKAGING_DIR/make-icon.swift"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/module-cache}"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" --product "$PRODUCT"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BIN_DIR/$PRODUCT"
RESOURCE_BUNDLE="$BIN_DIR/ClipX_ClipXApp.bundle"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Missing executable: $EXECUTABLE" >&2
  exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Missing resource bundle: $RESOURCE_BUNDLE" >&2
  exit 1
fi

mkdir -p "$DIST_DIR" "$PACKAGING_DIR"
if [[ -e "$APP_DIR" ]]; then
  if command -v trash >/dev/null 2>&1; then
    trash "$APP_DIR"
  else
    rm -rf "$APP_DIR"
  fi
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$PRODUCT"
chmod 755 "$MACOS_DIR/$PRODUCT"

cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/ClipX_ClipXApp.bundle"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>ClipX</string>
  <key>CFBundleExecutable</key>
  <string>ClipX</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundleName</key>
  <string>ClipX</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

cat > "$ICON_SWIFT" <<'SWIFT'
import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

let rect = NSRect(origin: .zero, size: size)
let iconRect = rect.insetBy(dx: 66, dy: 66)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 196, yRadius: 196)

NSGraphicsContext.current?.saveGraphicsState()
iconPath.addClip()

let darkGradient = NSGradient(colors: [
    NSColor(calibratedWhite: 0.03, alpha: 1),
    NSColor(calibratedWhite: 0.115, alpha: 1)
])!
darkGradient.draw(in: iconPath, angle: -38)

let lightPanel = NSBezierPath()
lightPanel.move(to: NSPoint(x: 568, y: iconRect.maxY + 8))
lightPanel.line(to: NSPoint(x: iconRect.maxX + 8, y: iconRect.maxY + 8))
lightPanel.line(to: NSPoint(x: iconRect.maxX + 8, y: iconRect.minY - 8))
lightPanel.line(to: NSPoint(x: 456, y: iconRect.minY - 8))
lightPanel.close()
let lightGradient = NSGradient(colors: [
    NSColor(calibratedWhite: 0.96, alpha: 1),
    NSColor(calibratedWhite: 0.80, alpha: 1)
])!
lightGradient.draw(in: lightPanel, angle: -32)

let splitLine = NSBezierPath()
splitLine.move(to: NSPoint(x: 568, y: iconRect.maxY))
splitLine.line(to: NSPoint(x: 456, y: iconRect.minY))
NSColor(calibratedRed: 0.25, green: 0.87, blue: 0.93, alpha: 0.58).setStroke()
splitLine.lineWidth = 8
splitLine.stroke()

NSGraphicsContext.current?.restoreGraphicsState()

NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
iconPath.lineWidth = 7
iconPath.stroke()

func ringPath(center: NSPoint, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
}

func armPath(from start: NSPoint, through pivot: NSPoint, to tip: NSPoint) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: start)
    path.curve(
        to: pivot,
        controlPoint1: NSPoint(x: start.x + 82, y: start.y - 18),
        controlPoint2: NSPoint(x: pivot.x - 84, y: pivot.y + (start.y > pivot.y ? 42 : -42))
    )
    path.line(to: tip)
    return path
}

func bladePath(pivot: NSPoint, tip: NSPoint, inner: NSPoint) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: pivot)
    path.line(to: tip)
    path.line(to: inner)
    path.close()
    return path
}

let pivot = NSPoint(x: 506, y: 512)
let upperRing = NSPoint(x: 304, y: 686)
let lowerRing = NSPoint(x: 304, y: 338)
let ink = NSColor(calibratedWhite: 0.045, alpha: 1)
let edge = NSColor(calibratedWhite: 0.98, alpha: 0.96)
let shadow = NSColor(calibratedWhite: 0, alpha: 0.22)

let upperBlade = bladePath(
    pivot: NSPoint(x: 500, y: 533),
    tip: NSPoint(x: 820, y: 754),
    inner: NSPoint(x: 576, y: 488)
)
let lowerBlade = bladePath(
    pivot: NSPoint(x: 500, y: 491),
    tip: NSPoint(x: 820, y: 270),
    inner: NSPoint(x: 576, y: 536)
)

for offset in [NSPoint(x: 0, y: -9)] {
    let shadowArmA = armPath(
        from: NSPoint(x: upperRing.x + 50 + offset.x, y: upperRing.y - 30 + offset.y),
        through: NSPoint(x: pivot.x + offset.x, y: pivot.y + offset.y),
        to: NSPoint(x: 790 + offset.x, y: 274 + offset.y)
    )
    let shadowArmB = armPath(
        from: NSPoint(x: lowerRing.x + 50 + offset.x, y: lowerRing.y + 30 + offset.y),
        through: NSPoint(x: pivot.x + offset.x, y: pivot.y + offset.y),
        to: NSPoint(x: 790 + offset.x, y: 750 + offset.y)
    )
    shadow.setStroke()
    for path in [shadowArmA, shadowArmB] {
        path.lineWidth = 56
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}

edge.setStroke()
for path in [
    armPath(from: NSPoint(x: upperRing.x + 50, y: upperRing.y - 30), through: pivot, to: NSPoint(x: 790, y: 274)),
    armPath(from: NSPoint(x: lowerRing.x + 50, y: lowerRing.y + 30), through: pivot, to: NSPoint(x: 790, y: 750)),
    ringPath(center: upperRing, radius: 88),
    ringPath(center: lowerRing, radius: 88)
] {
    path.lineWidth = 58
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

ink.setStroke()
for path in [
    armPath(from: NSPoint(x: upperRing.x + 50, y: upperRing.y - 30), through: pivot, to: NSPoint(x: 790, y: 274)),
    armPath(from: NSPoint(x: lowerRing.x + 50, y: lowerRing.y + 30), through: pivot, to: NSPoint(x: 790, y: 750)),
    ringPath(center: upperRing, radius: 88),
    ringPath(center: lowerRing, radius: 88)
] {
    path.lineWidth = 34
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

for blade in [upperBlade, lowerBlade] {
    edge.setStroke()
    blade.lineWidth = 18
    blade.lineJoinStyle = .miter
    blade.stroke()
    ink.setFill()
    blade.fill()
}

let pivotDot = NSBezierPath(ovalIn: NSRect(x: pivot.x - 30, y: pivot.y - 30, width: 60, height: 60))
edge.setFill()
pivotDot.fill()
let pivotCore = NSBezierPath(ovalIn: NSRect(x: pivot.x - 15, y: pivot.y - 15, width: 30, height: 30))
ink.setFill()
pivotCore.fill()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not render icon")
}

try png.write(to: output)
SWIFT

swift "$ICON_SWIFT" "$ICON_PNG"

trash "$ICONSET_DIR" 2>/dev/null || rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Created $APP_DIR"
