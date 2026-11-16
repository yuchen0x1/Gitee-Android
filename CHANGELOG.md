# CHANGELOG

## v1.4.2 · 2026-11-16

### 安全与发布

- Release 构建缺少 `android/key.properties` 或 keystore 时直接失败，不再回退到 Debug 签名。
- 更新下载的 SHA256SUMS 必须按 APK 文件名唯一匹配；无匹配或重复冲突时拒绝安装。
- 更新资产优先选择通用 Android APK，只有 ABI 分包时不再按顺序误选。
- Android 8+ 未允许安装未知来源应用时，更新对话框显示原因并提供系统设置入口。

### 工程与文档

- 新增 `PROJECT_AUDIT.md`、`COMPETITOR_ANALYSIS.md`、`UPGRADE_ROADMAP.md` 和 `UPGRADE_REPORT.md`。
- 补充 20 个更新服务/下载测试场景，完整 Flutter 回归达到 99 项。
- 保留 Android-only 发布策略，更新文档明确真实设备、正式签名和线上更新闭环仍需验收。

## v1.4.1 · 2026-11-10

- 修复订阅仓库列表加载失败、提交作者显示不完整的问题。
- 改善小屏及大字体下的个人页快捷入口和新手引导。
- 优化明暗主题、底部弹窗背景和发布说明摘要的可读性。
- Android 发布包使用配置的 Release 签名。

完整历史见 `docs/releases/release-notes.md` 和 `docs/EVOLUTION_2026-11-13.md`。
