# UPGRADE_ROADMAP.md

# Gitee Client 演进路线图

制定日期：2026-11-16  
总升级点：38 项  
优先级：P0 严重缺陷/安全；P1 核心体验和可靠性；P2 能力、性能和架构；P3 工程化与高级体验。

每行依次记录：升级名称和模块、当前问题、发现依据、竞品参考及其实现、我们的方案、预期效果、文件范围、难度、优先级、验收标准、当前状态。状态只写 `已完成`、`部分完成`、`阻塞` 或 `计划`。

| 编号 | 升级点与模块 | 当前问题 / 依据 | 对标与实现借鉴 | 本项目方案 / 文件 | 难度 / 优先级 | 效果与验收标准 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EV-001 | Release 签名强制 / Android 构建 | 缺少 key.properties 时旧配置可能回退 Debug；依据 `android/app/build.gradle.kts` | Round-Sync、Syncthing-Fork 的签名发布流程 | Release task 检查完整属性和 keystore，不再回退；`android/app/build.gradle.kts` | 中 / P0 | 错误配置在构建前失败，CI 正常注入密钥并产出正式签名包 | 已完成 |
| EV-002 | 校验和按文件名匹配 / 更新服务 | 多资产 sidecar 无命名匹配时旧逻辑取第一个 hash；依据 `lib/services/update_service.dart` | Round-Sync 的资产校验思路 | 逐行解析 SHA256SUMS，必须唯一匹配 APK 文件名；`lib/services/update_service.dart` | 低 / P0 | 乱序或缺失匹配的 sidecar 被拒绝，匹配项可下载通过 | 已完成 |
| EV-003 | 未知来源安装引导 / Android 安装 | Android 8+ 未授权时安装器直接失败；依据 `MainActivity.kt` | GitNex/Nextcloud 的权限说明模式 | 返回 `permission_required`，打开应用安装权限设置；`MainActivity.kt`、`update_installer.dart`、`update_dialog.dart` | 中 / P1 | 未授权设备显示明确设置入口，授权后可再次安装 | 已完成 |
| EV-004 | 通用 APK 选择 / 更新服务 | 多个 ABI 包时按附件顺序取第一个，可能不匹配；依据 `app_update.dart` | Release 矩阵项目的 universal 优先规则 | 优先 universal 或 `app-release.apk`，只有分包则不选；`lib/models/app_update.dart` | 低 / P1 | 混合资产 Release 始终选通用包，纯 ABI Release 转发布页 | 已完成 |
| EV-005 | 通知未读/全部筛选 / 动态 | 原流程不能稳定表达服务端未读筛选；依据通知页面和 Gitee 合同记录 | GitTouch、GitNex 的双视图和筛选 | `unread` 参数、筛选控件和分组列表；`gitee_api.dart`、`notifications_view.dart` | 中 / P1 | 切换筛选请求正确，刷新和分页不混入另一筛选结果 | 已完成 |
| EV-006 | 通知读状态可靠更新 / 动态 | 写失败时 UI 可能先移除，用户看不到真实状态 | GitNex 的操作菜单和状态联动 | 服务端成功后才改模型、角标和列表，失败保留并提示；通知组件和测试 | 中 / P1 | 注入 4xx/网络错误后列表保留，成功后只更新目标项 | 已完成 |
| EV-007 | 会话代际防串号 / API | 账号切换期间晚到响应可能覆盖新账号 | DioHub/Nextcloud 的状态隔离方向 | `ApiClient` 维护 session generation 并丢弃旧响应；`api_client.dart` | 中 / P0 | 并发切换账号测试中旧响应不改变当前状态 | 已完成 |
| EV-008 | Issue/PR/代码草稿保留 / 编辑器 | 提交失败或退出可能丢失长文本 | GitSync/GitJournal 的可恢复数据思想 | 安全存储草稿、成功后清理、状态组件提示；`composer_draft.dart` 等 | 中 / P1 | 进程重建后草稿可恢复，成功提交后草稿被清除 | 已完成 |
| EV-009 | 离线缓存账号隔离 / 持久化 | 同设备多账号可能看到另一账号缓存 | Nextcloud/GitNex 的账户隔离方向 | 使用令牌摘要作为缓存命名空间；`offline_cache.dart` | 中 / P1 | 切换账号后旧缓存不可读，清除账号只影响当前命名空间 | 已完成 |
| EV-010 | 仓库能力中心分区失败 / 仓库管理 | 一个无权限接口失败会遮蔽可访问信息 | GitNex/OctoLab 的分区加载和权限提示 | 各区块独立 future、过期结果保护、单区重试；`repo_tools_page.dart` | 中 / P1 | 403/404 只影响对应区块，其余区块仍显示 | 已完成 |
| EV-011 | 小屏和大字体布局 / UI | 320px 或 1.5 倍字体下操作入口容易溢出 | Material Files/Simple File Manager 的高密度布局 | `Wrap`、可滚动操作区和组件测试；通知、个人页、引导页 | 中 / P1 | 320px、1.5 倍字体、深色主题 widget 测试通过且无溢出 | 已完成 |
| EV-012 | 深链路由和冷启动 / 导航 | 深链初次启动时导航时序容易早于首屏 | DioHub/FastHub 的 deep link 入口 | 初始链接延迟到导航器可用，运行中链接复用统一解析；`deep_link.dart`、`main.dart` | 中 / P1 | 冷启动和运行中 `gitee://` 链接都进入正确页面 | 已完成 |
| EV-013 | 更新 API/网页/Atom 兜底 / 发布 | GitHub 匿名 API 可能限流 | GitHub 客户端的公开 Release 读取模式 | REST、网页 latest、Atom 分页边界；`update_service.dart` | 中 / P1 | API 403 时页面/Atom 可读，失败显示可重试错误 | 已完成 |
| EV-014 | 更新下载重试和完整性 / 发布 | 网络中断、错误资产或截断文件会导致安装风险 | Round-Sync、Syncthing-Fork 的校验和和状态反馈 | HTTPS 主机白名单、重试、进度、大小、SHA-256；更新服务和对话框 | 中 / P0 | hash/size 任一失败不进入安装器，临时文件被清理 | 已完成 |
| EV-015 | 发布日志版本门禁 / CI | 标签与应用版本或说明可能不同步 | Round-Sync/Nextcloud 的发布文档门禁 | `release_notes.py` 校验标签、版本和说明；`release.yml` | 低 / P1 | 缺版本说明或版本不一致时 Release job 失败 | 已完成 |
| EV-016 | 生物识别宿主合同 / Android | `local_auth_android` 要求 FragmentActivity，旧宿主不满足 | GitNex 等原生 Android 的 Activity 配置 | FlutterFragmentActivity + AppCompat 主题；`MainActivity.kt` 和 styles | 中 / P0 | Android 编译通过，真机指纹弹窗待设备验收 | 已完成 |
| EV-017 | Release AOT 路径稳定 / 构建 | 本地历史 Release 构建受中文路径和 AOT 读取影响 | CI Linux 构建作为稳定环境 | 在项目路径可复现环境和 CI 记录中验证 `flutter build apk --release`；CI 文档 | 中 / P1 | Linux CI 正常构建 universal、ABI、AAB，签名可验证 | 阻塞 |
| EV-018 | 真机更新闭环 / 设备验收 | 当前没有设备，无法验证安装器、版本替换和重启 | GitSync/Syncthing-Fork 的真实设备发布流程 | 用旧版和新版正式签名包做发现、下载、授权、安装、启动记录 | 中 / P1 | 旧版发现新版、校验、安装、重启后版本正确且证书连续 | 阻塞 |
| EV-019 | 管理列表完整分页 / 仓库管理 | 分支、标签、协作者、Fork 等仍有固定上限 | GitNex/OctoLab 的分页列表 | 统一分页组件和每区块独立游标；`repo_tools_page.dart`、`paged_list_view.dart` | 高 / P1 | 超过一页的数据可继续加载、去重、重试和结束 | 计划 |
| EV-020 | Gitee API 按域拆分 / 架构 | `gitee_api.dart` 过大，修改风险高 | DioHub/Nextcloud 的服务分层 | 按 repo/issue/pr/user/release 拆分 facade，保留兼容入口 | 高 / P2 | 公共调用不变，静态分析和全套测试通过 | 计划 |
| EV-021 | 统一错误类型 / 稳定性 | 页面各自解析字符串错误，用户提示不一致 | GitSync 的网络/权限/冲突分类 | `ApiFailure` 包含网络、认证、权限、限流、冲突和服务错误 | 中 / P1 | 相同错误在不同页面显示一致，日志不含令牌 | 计划 |
| EV-022 | 请求取消和页面销毁 / 性能 | 长请求在离开页面后仍占资源 | Flutter GitConnect 的 BLoC 生命周期思想 | 给分页和详情请求增加可取消 token 或请求代际；API client | 中 / P2 | 快速离开页面不会更新已销毁 State，网络请求可停止 | 计划 |
| EV-023 | 分类重试和退避 / 稳定性 | 目前重试策略集中在更新下载，业务写操作没有统一退避 | GitSync 的网络恢复自动重试 | 仅对幂等 GET 和明确可重试错误使用指数退避，写操作默认不重复 | 中 / P1 | 模拟 503/超时可按上限重试，4xx 不重复写入 | 计划 |
| EV-024 | 离线写任务队列 / 核心功能 | 断网时 Issue/评论/文件编辑只能失败后手动重试 | GitSync/PuppyGit 的任务恢复 | 保存幂等任务、展示队列、上线后逐项重试并可取消 | 高 / P1 | 断网创建任务可恢复，重复提交不会产生重复对象 | 计划 |
| EV-025 | 文件编辑冲突界面 / 代码协作 | 远端 SHA 变化时虽有冲突保护，但用户缺少差异决策界面 | GitSync/PuppyGit 的冲突 UI | 展示本地/远端摘要和重新载入、覆盖、复制三种动作；`code_view_page.dart` | 高 / P1 | 模拟远端变更时不覆盖数据，用户能选择下一步 | 部分完成 |
| EV-026 | 分支和标签浏览器 / 代码阅读 | 当前选择器适合短列表，不能搜索和分页 | GitNex/OctoLab 的仓库浏览 | 增加搜索、最近使用和分页；`branch_selector.dart`、repo API | 中 / P2 | 100+ 分支可检索，选择后刷新内容且不串页 | 计划 |
| EV-027 | 本地仓库搜索索引 / 搜索 | 大型目录只能逐页请求或文本过滤 | Material Files/GitNote 的树和全局搜索 | 对已缓存文件建立轻量索引，更新时增量失效 | 高 / P2 | 已缓存仓库搜索不发网络请求，索引损坏可重建 | 计划 |
| EV-028 | 动态筛选和时间范围 / 动态 | 事件流筛选维度有限，定位历史操作成本高 | OctoLab/GitNex 的 activity 分类 | 增加仓库、事件类型、时间范围筛选并保留 URL 状态 | 中 / P2 | 筛选条件组合正确，刷新和返回保留条件 | 计划 |
| EV-029 | 通知本地快照 / 通知 | 退出页面后筛选和已读状态没有持久快照 | GitTouch/FastHub 的本地通知模型 | 只缓存脱敏通知摘要和游标，账号隔离，网络恢复后校准 | 中 / P2 | 断网可看到最近快照，在线刷新不会重复或覆盖新状态 | 计划 |
| EV-030 | 后台更新提醒 / 自动化 | 没有后台检查；增加后台任务会耗电并涉及通知权限 | Syncthing-Fork/GitSync 的后台状态与触发器 | 先做可选开关、网络/充电条件和通知解释，再评估 WorkManager | 高 / P3 | 用户明确开启后按条件运行，可关闭且不泄露令牌 | 计划 |
| EV-031 | 账号导出与迁移 / 账号 | 多账号只能在当前安全存储中切换 | Nextcloud/GitNex 的账户管理 | 设计加密导出包，导出前生物识别，导入后再次确认 | 高 / P2 | 导出文件不含明文令牌，导入失败不影响已有账号 | 计划 |
| EV-032 | OAuth/Device Flow 选项 / 登录 | 私人令牌创建和复制门槛较高 | FastHub-RE、OctoLab 的 OAuth/多实例路径 | 评估 Gitee 官方可用授权流程；无官方合同不实现猜测接口 | 高 / P2 | 只有官方文档和测试环境确认后才开放，失败可回退 PAT | 计划 |
| EV-033 | 更新签名认证 / 安全 | SHA-256 只证明下载完整，不认证发布者 | GitHub Release 签名/供应链实践 | 评估签名 manifest 或 TUF；保留 SHA-256 作为兼容层 | 高 / P1 | 没有可信签名时明确提示，签名验证失败绝不安装 | 计划 |
| EV-034 | 依赖和 SBOM 门禁 / 安全 | pubspec 依赖存在可升级项，缺少定期风险记录 | Nextcloud/Round-Sync 的发布治理 | CI 生成依赖清单，人工审阅升级和许可证变化 | 中 / P2 | 依赖变更有 diff、许可证记录和可回滚版本 | 计划 |
| EV-035 | 隐私诊断导出 / 可观测性 | 无法在不暴露令牌的情况下收集失败上下文 | Syncthing-Fork 的状态解释 | 提供脱敏日志、版本、设备 API 级别和错误类别导出 | 中 / P3 | 导出包不含 Authorization、Key、正文和个人内容 | 计划 |
| EV-036 | 无障碍和减少动画 / UI | 现有 UI 测试覆盖布局，不足以证明语义标签和动画偏好 | igitea、Material Files 的可访问设计方向 | 为按钮、列表、状态增加语义，尊重 `disableAnimations` | 中 / P2 | TalkBack 可读关键操作，减少动画设置生效 | 部分完成 |
| EV-037 | CI 缓存与 Android 矩阵 / 工程化 | CI 只覆盖单一稳定构建，失败诊断和缓存还可增强 | Round-Sync/Syncthing-Fork 的矩阵发布 | 缓存 Flutter/pub/Gradle，分离 analyze/test/build，保留 Android-only | 中 / P2 | PR/推送反馈更快，失败步骤定位明确，不构建其他平台 | 计划 |
| EV-038 | 发布证明和回滚说明 / 工程化 | Release 有产物和 hash，但缺少证书指纹、来源和回滚手册 | Nextcloud/Round-Sync 的发布文档 | Release 附 SHA256、签名指纹、构建提交和回滚说明；`release.yml`、docs | 中 / P1 | 用户可核对来源和 hash，错误 Release 有可执行回滚步骤 | 计划 |

## 2. 执行顺序

### P0

EV-001、EV-002、EV-007、EV-014、EV-016 已落实。后续重点是 EV-033 的签名认证评估。

### P1

先完成 EV-017、EV-018 的 CI/真机验收，再做 EV-019、EV-021、EV-023、EV-024、EV-025 和 EV-038。它们直接影响核心协作可靠性和发布安全。

### P2/P3

在核心稳定后推进分页、搜索、诊断、无障碍、依赖门禁和可选后台任务。任何后台能力都必须先评估耗电、通知权限、隐私和撤销路径。

## 3. 研究和移植原则

- 只重新实现行为和接口契约，不复制 GPL/AGPL 代码。
- 不引入新的数据库、后台服务或跨平台工程，除非需求和迁移方案已经明确。
- 每个已实现项都必须有真实入口、业务逻辑、异常处理、测试和文档。
- 失败、阻塞和未验收项保持单独状态，不用计划数量冒充完成数量。
