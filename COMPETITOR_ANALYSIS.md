# COMPETITOR_ANALYSIS.md

# 开源竞品与相关项目对标

研究日期：2026-11-16  
研究范围：GitHub 公开仓库、README、目录和可访问源码/Release/Issue 信息。重点项目使用 `.evolution/source-research-2026-11-13.json`、`.evolution/diohub-research-2026-11-13.json` 和本轮公开仓库检索记录交叉核对。

> 本表记录的是可复查的设计和工程证据，不把 README 宣传语当作功能验收。研究只用于方案对比，没有复制 GPL/AGPL 代码，也没有引入竞品运行时依赖。许可证只决定能否直接复用代码，不影响借鉴公开的产品思路。

## 1. 项目清单

| 项目 | 类型 / 许可证 | 实际参考点 | 对方优势 | 我们当前优势 | 结论 |
| --- | --- | --- | --- | --- | --- |
| [GitNex](https://github.com/gitnex-org/gitnex) | 原生 Android Forgejo/Gitea，GPL-3.0 | 通知、文件、Issue/PR、多账号、离线、主题 | Android 原生流程完整，自托管兼容和设置入口成熟 | Gitee API 适配更直接，Flutter 迭代更快 | 借鉴多账号、通知状态和设置信息架构；不复制代码 |
| [MGit](https://github.com/maks/MGit) | Android 本地 Git，GPL-3.0 | 本地仓库、clone、设备存储、平板布局 | 本地仓库模型和存储边界清楚 | 本项目聚焦 Gitee 协作，不需要完整本地 Git | 作为未来文件/离线能力参考 |
| [DioHub](https://github.com/namanshergill/diohub) | Flutter GitHub 客户端，GPL-3.0 | GraphQL、代码/commit 历史、深链、主题、缓存 | 移动端代码浏览和定制能力更丰富 | 我们已针对 Gitee v5 设计并实现大量管理接口 | 借鉴缓存分层、深链和代码阅读路径 |
| [GitTouch](https://github.com/pd4d10/git-touch) | Flutter GitHub 客户端，Apache-2.0 | 通知分组、未读/全部标签、状态模型 | 通知信息架构简单且容易理解 | 我们对 Gitee 未读写接口做了成功确认和失败恢复 | 借鉴分组与筛选，重新实现 |
| [FastHub](https://github.com/k0shk0sh/FastHub) | 历史 GitHub Android 客户端，GPL-3.0，已归档 | Issue/PR、通知、离线和成熟导航 | 功能覆盖广，适合作为老牌基线 | 我们的发布流水线和更新校验更现代 | 只保留功能基线，避免停更架构 |
| [FastHub-RE](https://github.com/AmirulAndalib/FastHub-RE) | GitHub Android 复兴分支，GPL 系 | Enterprise、多账号、完整 PR 工作流 | 功能面广 | 我们的产品范围更聚焦 Gitee | 借鉴工作流完整性，观察维护风险 |
| [GitSync](https://github.com/ViscousPot/GitSync) | Android/iOS Git 同步，GPL-3.0 | 网络恢复重试、冲突、后台触发器、Widget | 自动化和恢复机制强 | 我们不承担本地 Git 同步的复杂度 | 借鉴失败分类、重试和进度解释 |
| [PuppyGit](https://github.com/catpuppyapp/PuppyGit) | Android Git 工作台，GPL-3.0 | rebase、stash、冲突、Tasker 自动化 | Git 高级操作覆盖很全 | 我们更轻量，凭证设计不采用其默认密码反例 | 借鉴任务中心和冲突 UI，拒绝默认密钥 |
| [GitJournal](https://github.com/GitJournal/GitJournal) | Flutter Git 笔记，AGPL-3.0 | 远端持久化、迁移、冲突提示 | 数据可迁移和冲突问题记录清楚 | 我们已有按账号安全缓存和草稿 | 借鉴数据可恢复原则，不整合 AGPL 代码 |
| [GitNote](https://github.com/wiiznokes/gitnote) | Android Git 笔记，GPL-3.0 | 文件树、搜索、SSH/HTTPS、远端同步 | 文件树和同步入口直接 | 我们的 Gitee 协作 API 更完整 | 借鉴文件树和问题透明度 |
| [Round-Sync](https://github.com/newhinton/Round-Sync) | Android rclone 文件管理器，GPL-3.0 | 远端抽象、并发、SHA 校验、构建 flavor | 远端适配和发布资产管理成熟 | 我们只需单一 Gitee 服务 | 借鉴资产校验和构建文档 |
| [Syncthing-Fork](https://github.com/researchxxl/syncthing-android) | Android 同步，MPL-2.0 | 状态解释、进度、条件同步、持续 Release | 长时间运行状态和恢复反馈强 | 我们当前没有后台同步任务 | 借鉴状态可解释性和权限说明 |
| [Nextcloud Android](https://github.com/nextcloud/android) | 官方 Android 客户端，GPL-2.0 | 账户、后台任务、分层工程、发布文档 | 工程规模、后台任务和发布流程成熟 | 我们更小、更容易聚焦 Gitee | 借鉴模块边界和文档治理 |
| [Material Files](https://github.com/zhanghai/MaterialFiles) | Android 文件管理器，GPL-3.0 | Material UI、文件树、权限和搜索 | 文件浏览交互成熟 | 我们的代码浏览语义更强 | 借鉴空状态、权限提示和布局密度 |
| [Amaze File Manager](https://github.com/TeamAmaze/AmazeFileManager) | Android 文件管理器，GPL-3.0 | 标签页、搜索、书签、多主题、查看器 | 高频文件操作入口丰富 | 我们不引入文件管理器范围 | 借鉴仓库文件操作入口和可见反馈 |
| [Simple File Manager](https://github.com/SimpleMobileTools/Simple-File-Manager) | 轻量 Android 文件管理器 | Material You、少权限、存储分析 | 轻量、低门槛、反馈直接 | 我们已有 Material 3 和错误状态组件 | 借鉴轻量设置和权限最小化 |
| [OctoLab](https://github.com/secninjaz/OctoLab) | GitLab Android，开源 | 自托管、MR review、pipeline、to-do、多账号 | 工作流信息组织完整 | 我们面向 Gitee Issue/PR，接口更专门 | 借鉴实例配置和待办信息架构 |
| [Lab+ for GitLab](https://github.com/thelooter/labplus_for_gitlab) | Flutter GitLab，MIT | 多账号、Issue/PR、pipeline、FVM | Flutter 分层和版本固定清楚 | 我们的 Android-only 边界更明确 | 借鉴版本固定和状态模型 |
| [flutter_github](https://github.com/idisfkj/flutter_github) | Flutter GitHub 学习项目 | MSVM、Provider、MethodChannel、局部刷新 | 教学性架构清楚 | 我们已有真实 Gitee API 和更多业务 | 借鉴分层，不采用旧依赖 |
| [GitHao](https://github.com/conghaonet/GitHao) | 旧 Flutter GitHub 客户端，GPL-3.0 | Dio、Provider、事件总线、代码高亮 | 早期移动 GitHub 场景覆盖 | 现有 Flutter/SDK 更新程度更高 | 作为迁移和旧依赖反例 |
| [Flit](https://github.com/lycstar/flit) | Android Flutter IDE，GPL-3.0 | 流式构建日志、SAF、Device Auth、Git 操作 | 设备端工程输出和权限流程成熟 | 我们不做完整 IDE | 借鉴流式日志和 Android-only 发布边界 |

## 2. 维度对比

| 维度 | 领先项目的证据 | 当前项目现状 | 差距与改进 |
| --- | --- | --- | --- |
| 核心功能 | GitNex、DioHub、OctoLab 覆盖完整通知/代码/Issue/PR 流程 | Gitee 主要协作路径已存在 | 补齐管理长列表、批量操作和待办聚合 |
| 用户体验 | GitTouch、GitNex 把未读、全部、读状态做成明确入口 | 本项目已默认未读、支持全部和失败恢复 | 继续加强通知筛选记忆和跨页状态 |
| UI | Material Files、Simple File Manager 具备高密度文件操作和清晰空态 | Material 3、骨架屏、错误态已存在 | 做真机小屏、大字体、无障碍走查 |
| 架构 | DioHub/Flutter GitLab 项目分离模型、状态和请求 | API 聚合文件仍偏大，页面以局部 State 为主 | 逐步拆分 API 域，不为重构引入新状态框架 |
| 性能 | GitSync/Syncthing-Fork 解释后台进度和恢复原因 | 传输缓存、并发附加信息和分页保护已存在 | 增加请求耗时、缓存命中和长列表基线 |
| 安全 | GitNex/Nextcloud 展示账户、实例和权限设置；PuppyGit 暴露默认密码反例 | 安全存储、会话隔离、下载校验已存在 | 继续做日志脱敏、权限最小化和依赖审查 |
| 稳定性 | GitSync、Syncthing-Fork 有重试、恢复和状态解释 | 已有超时、分页重试、失败保留、更新重试 | 统一错误分类和写任务恢复 |
| 工程化 | Round-Sync、Nextcloud、Syncthing-Fork 有矩阵构建、签名、校验和、发布文档 | GitHub Actions 已构建 APK/AAB 和 SHA256SUMS | 补充签名连续性、构建可追溯性和设备验收记录 |

## 3. 值得采用的方案

1. **重新实现通知状态模型**：采用 GitTouch/GitNex 的分组和筛选思想，但保留 Gitee 的真实 `unread`、单条已读和全部已读接口。
2. **采用命名校验和**：参考 Round-Sync 等发布流程，sidecar 必须按资产名匹配，不能按位置猜测。
3. **采用可解释的失败恢复**：参考 GitSync/Syncthing-Fork，把重试、权限、网络、校验和失败分别呈现。
4. **保持轻量的模块边界**：参考 DioHub、Lab+ 和 Nextcloud 的分层方向，但不为了对标而增加 GraphQL、数据库或状态管理框架。
5. **保留 Android-only 策略**：参考 Flit、原生 Android 客户端的设备能力，继续只维护 `android/`，不恢复其他平台工程。

## 4. 不采用的方案

- 不直接复制 GPL/AGPL 实现到当前 MIT 项目。
- 不引入完整本地 Git 引擎、后台同步守护进程或推送服务，除非有明确用户需求、耗电预算和数据恢复方案。
- 不采用默认公开密码、把凭证写 URL、无条件接受第一个校验 hash 等不安全做法。
- 不把项目 README 的功能列表当成线上验收证据；所有新增能力仍需测试、真机或在线证据。
