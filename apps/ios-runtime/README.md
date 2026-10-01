# Tempo iOS OTA Runtime

这是 Tempo iOS 的可更新内容层，不是第二个独立客户端。

- SwiftUI 保留 App 生命周期、系统导航、搜索、选项按钮、液态玻璃、权限、Keychain、App Group、小组件和 Live Activity。
- React Native + TypeScript 承载任务、RSS、番茄钟和设置的页面内容。
- `expo-updates` 只发布与当前原生 runtime 兼容的 JavaScript、样式和静态资源。
- Swift 数据层是唯一事实来源；TypeScript 通过 `TempoNativeBridge` 读取快照、订阅变化并提交动作。
- 每个迁移页面必须保留 Swift 回退开关，验证稳定后再移除旧实现。

## 本地验证

```bash
npm install
npm run typecheck
npm run export:ios
```

## 发布约束

原生依赖、权限、Bundle ID、entitlement、小组件、Live Activity 或 Swift 桥接协议发生变化时，必须构建新的 IPA 并提升 runtime version，不能只发 OTA。
