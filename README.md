# ClipX

ClipX 是一个 Swift 写的 macOS 剪切板管理器。它重点解决一个很烦的问题：从 iPhone 照片、实况文本或 Universal Clipboard 复制文字到 Mac 时，内容有时会变成 RTFD/富文本包，导致 Raycast、VS Code、浏览器输入框等应用无法像普通文字一样粘贴。

ClipX 会监听系统剪切板，识别这类 Universal Clipboard RTFD 内容，保留原始记录，同时自动把可读文字写回为普通文本，让 Mac 端粘贴恢复正常。

## 主要功能

- macOS 菜单栏常驻，状态栏可直接查看最近 5 条历史并点击粘贴。
- 完整剪切板历史窗口，支持搜索、收藏、置顶、删除、双击粘贴和键盘上下切换。
- 自动修复 iOS 到 Mac 的 RTFD/富文本剪切板内容。
- 支持 Text、URL、Image、File、RTF、RTFD、HTML、Color 等常见剪切板类型。
- 图片历史支持预览，右键可保存为 PNG。
- 设置页支持语言、主题、快捷键、隐私、存储位置和高级调试项。
- 数据保存在本机 Application Support，不做云同步，不上传剪切板内容。

## 为什么需要 ClipX

Universal Clipboard 很方便，但 iOS 端复制的文字在某些来源里会带上富文本、RTFD 或附件结构。很多 macOS 工具会把它当作文件或富文本处理，结果就是明明复制的是文字，到了 Mac 却不能直接粘贴。

ClipX 的首要目标就是把这类内容还原成普通文本剪切板，同时保留原始历史，既能修复粘贴体验，也能避免丢掉原始内容。

## 构建

```bash
swift build
swift run ClipXCoreTestRunner
scripts/package-app.sh
```

打包产物会生成在：

```text
dist/ClipX.app
```

## 系统要求

- macOS 14 或更新版本
- Swift 6 toolchain

自动粘贴需要 macOS 辅助功能权限。未授权时，ClipX 仍可以把选中历史写入系统剪切板。

## English

English README: [README.en.md](README.en.md)
