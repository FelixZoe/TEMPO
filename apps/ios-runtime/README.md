# Tempo iOS OTA Runtime

这是 Tempo iOS 的可更新内容层，不是第二个独立客户端。

- SwiftUI 保留 App 生命周期、系统导航、搜索、选项按钮、液态玻璃、权限、Keychain、App Group、小组件和 Live Activity。
- React Native + TypeScript 承载收集箱、今天、番茄钟、RSS 和设置五个一级页面的业务内容。
- `expo-updates` 只发布与当前原生 runtime 兼容的 JavaScript、样式和静态资源。
- Swift 数据层是唯一事实来源；TypeScript 通过 `TempoNativeBridge` 读取快照、订阅变化并提交动作。
- 原有 Swift 数据文件继续直接使用；迁移不会清空任务、专注记录、RSS 订阅或同步配置。

## 本地验证

```bash
npm install
npm run typecheck
npm run export:ios
```

Swift Package 只能在 macOS/Xcode 环境构建：

```bash
npm run prebuild:ios
npm run build:brownfield:ios
```

输出位于 `artifacts/TempoRuntimePackage-release`。正式 IPA 接入前，GitHub Actions 会先验证这个隔离运行包能完整构建。

## GitHub OTA 发布

1. 登录 Expo 后在 <https://expo.dev/settings/access-tokens> 创建专用于 CI 的令牌。
2. 在 GitHub 仓库 `Settings → Secrets and variables → Actions` 新建仓库 Secret。
3. 名称必须为 `EXPO_TOKEN`，值只粘贴到 GitHub，不写入源码、日志或聊天。
4. 运行 `iOS OTA Runtime` 工作流，选择与安装包一致的更新通道；正式安装包使用 `production`。

工作流会依次完成 TypeScript 检查、iOS 导出、Brownfield Swift Package 构建，全部通过后才向对应 EAS Channel 发布 Update。安装包内固定使用 `production` 通道，避免“更新已经上传但设备找不到”的 Branch/Channel 错配。

## 发布约束

原生依赖、权限、Bundle ID、entitlement、小组件、Live Activity 或 Swift 桥接协议发生变化时，必须构建新的 IPA 并提升 runtime version，不能只发 OTA。
