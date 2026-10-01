# iOS 混合架构与 OTA

Tempo iOS 采用 **SwiftUI 原生壳 + React Native/TypeScript 内容层**。这不是把 Apple 客户端整体改成跨平台应用，而是将适合快速迭代的页面内容与必须由系统原生实现的能力分开。

## 所有权边界

| SwiftUI 原生壳 | TypeScript OTA 内容层 |
| --- | --- |
| App 生命周期与 Scene | 任务列表与编辑内容 |
| Tab/Navigation、搜索、菜单和液态玻璃按钮 | RSS 列表、分类、文章内容与翻译状态 |
| Keychain、App Group、通知和后台任务 | 番茄钟主页面和统计内容 |
| WidgetKit、锁屏小组件和 Live Activity | 设置页的业务选项内容 |
| 本地数据库、同步引擎和冲突处理 | 页面布局、动效、文案和静态资源 |
| 原生权限与深链 | 通过桥接发出受控业务动作 |

## 横屏适配

- iPhone 竖屏保持单列和底部导航；横屏内容层改为双栏或“列表 + 详情”，系统导航仍由 SwiftUI 提供。
- iPad 根据可用宽度使用分栏，不把手机界面等比例放大。
- 页面不得依据固定设备型号判断布局，只依据 safe area、动态字体和可用宽度。
- 小组件和 Live Activity 不跟随主应用页面旋转，继续使用各自的系统布局族。

## 数据原则

Swift 数据层始终是唯一事实来源。OTA 层不维护第二份独立数据库，也不直接持有同步密钥。

1. Swift 通过 `bootstrap` 提供当前路由、主题、语言和数据修订号。
2. TypeScript 订阅 `tempoStateDidChange`，只消费不可变快照。
3. 新增、完成、删除、移动任务等操作通过 `perform(action, payload)` 回到 Swift。
4. Swift 完成持久化与同步后，再广播新的修订号和快照。

## 更新策略

- `preview`：内测设备验证。
- `production`：验证通过后发布给正式运行时。
- runtime version 与 IPA 的应用版本一致，例如 `0.3.2`。
- 启动时检查更新，失败立即使用上一次可工作的内置 bundle。
- 首批只迁移一个低风险页面，并保留原生 feature flag 回退。

## 必须重新构建 IPA 的变化

- 新增或升级原生依赖。
- 修改权限、entitlement、Bundle ID 或 App Group。
- 修改 WidgetKit、Live Activity、后台模式或原生桥接协议。
- 使用当前二进制中不存在的原生 API。

## 迁移顺序

1. 收集箱/今天的任务内容区域。
2. RSS 列表和阅读内容。
3. 番茄钟主页面；计时状态和 Live Activity 仍由 Swift 管理。
4. 设置页的业务内容。
5. 删除已稳定迁移页面的旧 Swift 内容实现。
