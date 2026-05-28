# ClipX

ClipX is a Swift macOS clipboard manager focused on one practical issue: text copied from iPhone Photos, Live Text, or Universal Clipboard can arrive on macOS as RTFD/rich text, so apps like Raycast, VS Code, and browser inputs may fail to paste it as normal text.

ClipX monitors the system pasteboard, detects those Universal Clipboard RTFD payloads, keeps the original history item, and writes the readable content back as plain text.

## Features

- Menu bar app with the 5 most recent clipboard items available for one-click paste.
- Full clipboard history window with search, favorites, pinning, delete, double-click paste, and keyboard navigation.
- Automatic RTFD cleanup for iOS to Mac Universal Clipboard text.
- Supports Text, URL, Image, File, RTF, RTFD, HTML, Color, and unknown pasteboard types.
- Image preview with right-click save as PNG.
- Settings for language, theme, shortcut, privacy, storage location, and advanced diagnostics.
- Local-only storage under Application Support. No cloud sync and no clipboard uploads.

## Why ClipX Exists

Universal Clipboard is useful, but some iOS sources copy text with rich text, RTFD, or attachment metadata. macOS tools may interpret that payload as a file or rich document instead of plain text. The result is frustrating: you copied text, but the Mac target app cannot paste it normally.

ClipX fixes that path by normalizing readable RTFD content into plain text while preserving the original clipboard record.

## Build

```bash
swift build
swift run ClipXCoreTestRunner
scripts/package-app.sh
```

The packaged app is generated at:

```text
dist/ClipX.app
```

## Requirements

- macOS 14 or later
- Swift 6 toolchain

Automatic paste requires macOS Accessibility permission. Without it, ClipX can still copy the selected history item back to the system pasteboard.

## 中文

默认中文说明: [README.md](README.md)
