# 安全与性能审计

这份审计覆盖 Apple 客户端的底部导航、敏感配置、同步链路与开屏动画，以及 Go 同步服务的认证、请求边界和长轮询。结论基于当前源码，不把“看起来可行”当成已经验证。

## 本轮已修复

### Keychain 写入可靠性

旧实现会先删除旧凭据，再新增新值；如果新增失败，原本可用的同步令牌、AI Key 或天气 Key 会丢失。现在改为：

1. 已存在时使用 SecItemUpdate；
2. 只有不存在时才使用 SecItemAdd；
3. 检查并向界面返回系统状态码；
4. 敏感值使用仅本机的安全存储，不写入同步文档。

Apple 建议为钥匙串项目选择满足功能的最严格访问级别；只有确实需要后台访问时才使用首次解锁后可读的级别。参考 [Restricting keychain item accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) 与 [kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly)。

### 传输安全

同步服务器和客户端直连 AI 接口现在要求 HTTPS。只有 localhost、127.0.0.1 与 ::1 的本机调试允许 HTTP，避免把 64 位同步密钥或 AI Key 明文发送到远程网络。

### 文档开发服务器依赖

VitePress 继续使用稳定版 1.6.4，但通过 npm overrides 将其内部 Vite 固定到 6.4.3，并使用 esbuild 0.25.12。这样保留现有默认主题与文档结构，同时避开旧 Vite 开发服务器的路径绕过问题。官方 npm 审计结果为 0 个已知漏洞，静态构建也已通过。

### 导航稳定性

iOS 始终只构建收集箱、今天、番茄钟、RSS 与设置 5 个独立 TabView 页面。用户可以调整顺序，但不能隐藏入口，也不会进入系统生成的“更多”页面。

### 开屏动画

动画只改变固定左右面板的位移与透明度：中间标志先出现，随后从中心线向左右打开。没有在每帧增删视图或改变列表数据，并继续遵循系统“减少动态效果”设置。Apple 提供 accessibilityReduceMotion 环境值供应用降低非必要动画，参考 [AccessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)。

## 已核对的服务端防线

Go 同步服务当前具备：

- 64 位十六进制令牌格式校验；
- SHA-256 后的常量时间令牌比较；
- 默认 2 MiB 请求体限制和最多 10,000 项任务限制；
- JSON 未知字段拒绝、尾随第二个 JSON 值拒绝；
- 客户端时间最多只允许超前 5 分钟；
- CORS 来源白名单；
- 读取头、读取、写入、空闲和优雅关闭超时；
- 25 秒变更长轮询，而不是高频固定轮询。

这些限制不能替代 HTTPS、主机防火墙、最小权限容器和数据备份。同步令牌等同于个人实例的完整访问权，泄露后应立即轮换。

## 性能结论

同步不是每秒上传完整数据。客户端把连续本地变更合并后再同步，计时器跨端状态使用结束时间和阶段 ID 表达；服务端修订号变化通过长轮询唤醒其他设备。正常网络下，一次长轮询占用一个请求，普通同步仍保留独立连接，不需要增加高频定时器。

当前可确认的性能边界：

- 客户端普通请求超时 15 秒，资源超时 30 秒；
- 可重试错误最多重试 2 次，并使用短退避；
- 长轮询与普通同步使用独立请求，避免高频定时器；
- Widget 与 Live Activity 读取共享快照，不直接发起同步网络请求。

若实际设备仍出现卡帧，下一步必须用 Instruments/ETTrace 区分主线程布局、列表 diff 或网络等待，不能仅凭动画观感继续堆延时。

## 仍需注意

### 个人实例边界

Tempo同步服务有意采用单令牌、单个人数据集，不是多用户租户系统。不要把同一实例和令牌发给不受信任的人，也不要直接把 8080 端口暴露到公网。

## 验证清单

- Git diff whitespace 检查；
- 仓库敏感信息扫描；
- npm 官方源依赖审计与 VitePress 静态构建；
- Go 单元测试与 HTTP API 测试；
- GitHub macOS Runner 上的 iOS/macOS 编译；
- iPhone 真机验证五项导航排序、同步恢复和减少动态效果。

最后两项依赖 Apple 构建环境与真机，只有工作流和安装测试通过后才算完成。
