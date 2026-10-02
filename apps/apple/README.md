# Tempo Apple 原生客户端

`apps/apple` 包含 Tempo 的原生 Apple 容器。导航、系统权限、WidgetKit、ActivityKit 与 Keychain 由 SwiftUI 负责；可热更新的内容层由 Expo/React Native Brownfield 包嵌入。它不包含 Flutter 引擎。

返回：[项目首页](../../README.md) · [设计规范](../../docs/DESIGN.md) · [系统架构](../../docs/ARCHITECTURE.md) · [iOS 签名](../../docs/IOS_PRIVATE_SIGNING.md)

## 支持范围

| 目标 | 最低系统 | Scheme | 主要能力 |
| --- | --- | --- | --- |
| iOS / iPadOS | 17.0 | `TempoiOS` | 原生容器、OTA 内容层、RSS、WidgetKit、ActivityKit、Keychain |
| macOS | 15.0 | `TempomacOS` | SwiftUI 桌面界面、原生设置与同步 |
| iOS 扩展 | 17.0 | `TempoWidgets` | 主屏幕/锁屏小组件、Live Activity、灵动岛 |

## 目录

```text
Shared/         跨 Apple 平台的模型、状态、视图、存储和网络实现
iOS/            iOS 应用入口与平台桥接
macOS/          macOS 应用入口
Configuration/  entitlements、扩展 Info.plist 与权限配置
Generated/      XcodeGen 生成的 Info.plist
project.yml     XcodeGen 工程定义和版本信息
```

工程还复用 `apps/flutter/ios` 中的品牌 Assets 和 ActivityAttributes 定义，保证主应用与 Widget 扩展使用同一份实时活动协议。这不是 Flutter iOS 客户端。

## 品牌名与兼容标识

用户可见品牌、工程、Target、Scheme 和新文件统一使用 **Tempo**。以下旧字符串仅作为升级兼容层保留，不代表品牌没有替换：

- `one.darker.qingxu` 与 `one.darker.qingxu.widgets`：保持 Bundle ID，确保新版能覆盖旧版。
- `group.one.darker.qingxu`：保持 App Group，确保主应用、小组件和灵动岛继续读取原数据。
- `Documents/Qingxu`、`Application Support/Qingxu` 与旧偏好键：保持存储路径，避免升级后看起来像“数据丢失”。
- `qingxu://`：保留为旧版深链兼容入口；新链接使用 `tempo://`。

## 环境要求

- macOS 与当前稳定版 Xcode。
- XcodeGen 2.42.0 或更高版本。
- Node.js 与 npm（用于生成 Expo Brownfield Swift Package）。
- 真机运行所需的 Apple 签名身份和描述文件。

安装并生成工程：

```bash
brew install xcodegen
cd apps/ios-runtime
npm ci
npm run prebuild:ios
npm run build:brownfield:ios
cd ../apple
xcodegen generate
open TempoApple.xcodeproj
```

`TempoApple.xcodeproj` 和 `apps/ios-runtime/artifacts` 都是生成产物。工程设置应修改 `project.yml`，然后重新生成，不要只在 Xcode 图形界面中修改生成工程。

## 本地构建

无签名模拟器构建示例：

```bash
xcodebuild \
  -project TempoApple.xcodeproj \
  -scheme TempoiOS \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

macOS 构建：

```bash
xcodebuild \
  -project TempoApple.xcodeproj \
  -scheme TempomacOS \
  -configuration Debug \
  build
```

设备型号以本机 `xcrun simctl list devices available` 为准。

## 签名与系统扩展

以下标识是稳定升级与系统扩展工作的前提：

```text
主应用：one.darker.qingxu
扩展：one.darker.qingxu.widgets
App Group：group.one.darker.qingxu
```

`TempoiOS` 依赖并嵌入 `TempoWidgets`。真机签名时必须为两个 target 选择同一 Team，并让两份描述文件都授权 App Group。详细检查与私密云端构建见 [iOS 签名文档](../../docs/IOS_PRIVATE_SIGNING.md)。

工程通过 Swift Package Manager 嵌入 `TempoRuntimePackage-release`。最低系统版本以 `project.yml` 为准（当前 iOS 17.0、macOS 15.0），GitHub Actions 使用稳定 Xcode 环境构建。

## OTA 的实际边界

- 可以 OTA：已挂载到 `ReactNativeView` 的 TypeScript 页面、布局、样式、图片和兼容业务逻辑。
- 必须重新构建 IPA：原生导航和搜索控件、Swift 代码、系统权限、原生依赖、Widget、锁屏组件与灵动岛扩展。
- `原生容器已接入` 表示 IPA 已链接 TempoRuntime，并能真正加载 EAS Update；不是只向 Expo 地址发一次探测请求。
- 当前开发者工具可打开“OTA 内容层”进行真机验证。其他 SwiftUI 页面会按模块逐步迁移，未迁移页面不会被虚假标记为可 OTA。

## 数据位置

- iOS：沿用 `Documents/Qingxu` 数据目录，兼容早期客户端数据。
- macOS：`Application Support/Qingxu`。
- 同步密钥与客户端直连 AI Key：Apple Keychain。
- Widget/Live Activity 快照：App Group 共享容器；阶段标识确保专注与休息切换时不复用旧倒计时。

导航顺序等设备偏好不参与同步。任务、番茄钟和 RSS 阅读状态使用与 Flutter 客户端相同的协议。

## 发布

公开 `build-release.yml` 工作流会生成：

- 包含扩展但未签名的 iOS IPA。
- 未签名、未公证的 macOS ZIP 与 DMG。

`Private Signed iOS` 手动工作流用于导入个人签名材料并生成加密私有产物。证书和描述文件不得提交到本目录。

## 修改检查

提交 Apple 客户端改动前至少确认：

1. iOS 专用 API 使用 `#if os(iOS)` 或可用性检查隔离，不破坏 macOS 编译。
2. App Group 快照字段与 Widget 读取保持兼容。
3. Live Activity 使用绝对结束时间和唯一阶段标识，不依赖后台逐秒刷新；展开态显示今日目标进度。
4. `project.yml` 可以重新生成工程。
5. `apps/ios-runtime` 可以生成 Brownfield Swift Package。
6. GitHub Actions 的 `apple-ios` 与 `apple-macos` 作业通过。
