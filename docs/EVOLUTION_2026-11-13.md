# Gitee Client 升级交付报告

日期：2026-11-13。范围：当前 Flutter Android 项目内的本地升级、研究和验证。

## 1. 项目认知与执行边界

- 定位：Gitee Open API v5 非官方 Android 客户端，Flutter / Dart 界面，Kotlin 平台桥接，无自建后端和业务数据库。
- 基线：`main`，HEAD `84f7f92`，`origin` 为 `https://github.com/yuchen0x1/Gitee-Android.git`，版本 `1.4.1+7`。
- 开始时已有 23 个受 Git 跟踪文件被修改，并有草稿、更新安装器、测试、文档等未跟踪内容。本轮在此基础上增量修改，没有重置、清理、提交、推送、发版或修改远程。
- 此前已经存在的草稿自动保存、代码编辑、更新下载与 SHA-256 校验、搜索并发保护等，不计为本轮新增成果。
- 环境：Flutter 3.47.1 / Dart 3.13.1，Android SDK 可用。`adb devices` 无设备，本机没有可用 Android 模拟器。

### 功能地图（从源代码核实）

| 模块 | 主要实现 | 状态与边界 |
| --- | --- | --- |
| 启动、导航、深链 | `lib/main.dart`、`home_page.dart`、`utils/deep_link.dart` | 启动登录恢复、四个主入口、gitee/网页链接路由已存在；未做真机冷启动验收 |
| 账号与锁屏 | `auth/auth_store.dart`、`auth/app_lock.dart` | 安全存储、旧令牌迁移、多账号、生物识别调用已存在；本轮修复 Android 宿主合同 |
| HTTP 与 Gitee API | `api/api_client.dart`、`api/gitee_api.dart` | 鉴权头、错误映射、超时、短期缓存、并发复用、会话保护；通知计数原来另用无作用域的静态缓存 |
| 仓库阅读与编辑 | `repo_detail_page.dart`、`repo_file_browser_page.dart`、`code_view_page.dart` | README、目录、源码、文件增改删与冲突处理均有业务代码；不是本轮新功能 |
| 仓库管理 | `repo_tools_page.dart` | 分支、标签、协作者、Webhook、语言、许可证、标签、里程碑、部署公钥、访问统计；本轮修复部分接口失败导致整页不可用 |
| Issue / PR | 详情页、`issue_composer.dart`、`pr_composer.dart` | 创建、评论、状态操作、审阅等 API 路径已存在；已有安全存储草稿与提交失败保留机制 |
| 动态与通知 | `dynamics_page.dart`、通知列表组件 | 原有事件流和通知分组；本轮补齐筛选、可靠读状态与错误恢复 |
| 搜索 | `search_page.dart`、`api/so_search_api.dart` | 仓库走网页搜索源，用户/Issue 走 v5；已有筛选、历史和防抖 |
| 持久化 | `providers/app_settings.dart`、`services/offline_cache.dart`、`composer_draft.dart` | 普通设置用 SharedPreferences；凭证、草稿、离线内容用安全存储，缓存按令牌摘要隔离；无数据库迁移 |
| AI 摘要 | `ai/ai_summary.dart`、`ai_settings_page.dart` | 可选兼容接口、Key 安全存储已存在；未配置真实服务，没有新增 AI 依赖或宣称在线可用 |
| 更新与交付 | `update_service.dart`、`update_installer.dart`、GitHub workflows | GitHub Release 检查、下载校验和系统安装桥接已有实现；本轮修复原生编译错误，不代表跨版本安装验收 |

审计采用重要源代码阅读、调用链检查、现有及新增测试与构建。没有发现 `lib/` 中 TODO/FIXME/Unimplemented 标记；这不能证明全部业务完整。未逐个真实操作全部管理端 API，不能将此报告视为生产安全审计或完整在线验收。

## 2. 五个开源项目研究

GitHub 匿名 REST API 查询受到 403 限流后，改用公开源码归档、raw 文件和 commits Atom，未执行外部项目代码，未安装竞品依赖。读取了各源码归档中的 LICENSE。以下时间是本次读取对应分支 Atom 的最新记录，不能代替整个项目的维护状态判断。

| 项目 / 许可证 | 直接阅读的源码 | 观察与采用 | 分支最新记录（UTC） |
| --- | --- | --- | --- |
| [GitTouch](https://github.com/pd4d10/git-touch) / Apache-2.0 | [gh_notification.dart](https://github.com/pd4d10/git-touch/blob/main/lib/screens/gh_notification.dart)、`notification_item.dart`、通知模型 | 通知分组、未读/参与/全部分类、明确的读状态入口；采用分组与未读/全部，不照搬 GitHub 查询参数 | main：2022-10-30，作为历史设计参考 |
| [GitNex](https://github.com/gitnex-org/gitnex) / GPL-3.0 | [NotificationsFragment.java](https://github.com/gitnex-org/gitnex/blob/main/app/src/main/java/org/mian/gitnex/fragments/NotificationsFragment.java)、`NotificationsFragmentBottomSheet.java` | Android 原生筛选与状态菜单、读状态计数联动；采用明确的操作反馈。其 Gitea/Forgejo 未读/置顶操作不等于 Gitee 支持这些写接口 | main：2026-08-20 |
| [DioHub](https://github.com/namanshergill/diohub) / GPL-3.0 | [notifications_service.dart](https://github.com/namanshergill/diohub/blob/main/lib/services/activity/notifications_service.dart)、筛选面板、通知卡片和模型 | API 筛选与本地呈现分层；采用可选筛选参数、模型读状态副本。main 的 README 很短，因此以实际源码为依据 | main：2026-03-10 |
| [FastHub](https://github.com/k0shk0sh/FastHub) / GPL-3.0 | [AllNotificationsPresenter.java](https://github.com/k0shk0sh/FastHub/blob/master/app/src/main/java/com/fastaccess/ui/modules/notification/all/AllNotificationsPresenter.java)、Activity、Fragment | 未读/全部入口、按仓库处理通知；本项目额外要求服务端确认成功才改变状态，避免静默失败 | master：2019-12-28，历史参考 |
| [flutter-GitConnect](https://github.com/TheAlphamerc/flutter-GitConnect) / GPL-3.0 | [notification_bloc.dart](https://github.com/TheAlphamerc/flutter-GitConnect/blob/master/lib/bloc/notification/notification_bloc.dart)、`notification_repository.dart`、README 结构 | 区分首次加载与下一页、封装仓库访问；采用可重试分页和独立通知视图，继续使用现有技术栈 | master：2022-11-05，历史参考 |

仅借鉴产品与架构理念；应用实现为本项目新增代码，没有移植 GPL 实现，也没有增加运行时依赖。研究记录位于 `.evolution/source-research-2026-11-13.json`、`diohub-research-2026-11-13.json`、`research-activity-2026-11-13.json`。许可证与来源同步至 `THIRD_PARTY_NOTICES.md`。

### 差距对照

| 维度 | 原有实际情况 | 优秀实践与差距 | 本轮结果 |
| --- | --- | --- | --- |
| 核心功能 | 有通知列表和读操作，但没有服务端未读筛选 | GitTouch/GitNex 分开管理未读和历史 | 默认未读、可切全部，参数符合 Gitee 合同 |
| UI | 仓库分组默认折叠，已读操作依赖滑动 | 参考明确操作入口和状态区分 | 默认展开，增加有提示的标记按钮，保留滑动 |
| 体验 | 写失败静默丢弃，空列表无刷新，分页失败无入口 | 状态操作应可见、可恢复 | 服务端确认后更新、失败提示、刷新保留内容和分页重试 |
| 架构 | 通知混在动态页，计数为独立静态缓存 | 模型、请求、页面职责应清楚 | 提取通知视图，复用有会话保护的传输缓存 |
| 自动化 | 仓库附加信息首屏重复请求，读状态需手动纠正 | 避免重复加载，自动联动状态 | 首次附加信息各请求一次；已读后失效计数缓存，未读列表重新定位页码 |
| 扩展 | 主流程任何接口失败均报整页错误 | 依照服务能力逐块退化 | 独立记录加载错误，保留可用资源与已有内容 |

接口核对：实际抓取 [Gitee 官方文档数据](https://gitee.com/api/v5/doc_json)，确认 `unread` 布尔参数、`{total_count, list}` 列表、PATCH 单条已读与 PUT 全部已读。没有把 GitHub 的 `all=false` 参数用于 Gitee。

## 3. 优先级与已实施成果

| 优先级 | 问题与价值 | 实施 / 风险 |
| --- | --- | --- |
| P0 | Kotlin 引用未生成的 BuildConfig 导致 Android 编译失败 | FileProvider authority 改用运行时包名；Debug 构建复测通过 |
| P0 | 生物识别插件要求 FragmentActivity，当前宿主和主题不符 | 使用 FlutterFragmentActivity、AppCompat 明暗主题；编译已验证，真实验证弹窗待设备 |
| P1 | 通知计数跨账号/筛选复用旧结果 | 使用传输层会话缓存和查询键；账号切换隔离、并发复用、写后失效；有回归测试 |
| P1 | 滑动失败仍移除、全部已读只改计数 | 改为服务端成功后更新模型、列表、角标，异常显示提示，写入期间防重复操作 |
| P1 | 刷新丢内容，分页失败难恢复，未读删行后页码偏移 | 刷新成功再替换、分页失败重试同一页、去重、未读写成功后从第一页重载 |
| P1 | Webhook/协作者无权限或许可证缺失导致能力中心整页失败 | 接口独立捕获错误，展示区块原因；成功数据保留；过期加载结果不覆盖新结果 |
| P2 | 附加信息重复串行加载、成功刷新后旧错误不消失 | 移除初次重复调用，四个附加接口并发，重试成功清理错误 |
| P2 | 通知操作不明显、卡片缺少 Material、窄屏需要适配 | 增加按钮与提示、稳定分组键、Material 点击反馈、Wrap 布局；320px / 1.5倍文字 / 深色测试通过 |

没有修改数据库、存储格式、包版本、仓库服务商或平台范围。GiteeApi 新参数是可选参数，已有调用保持兼容。点击通知仍打开外部网页，不自动更改已读状态。没有引入后台轮询、推送服务或新基础设施。

原生配置依据：[local_auth_android 官方说明](https://pub.dev/packages/local_auth_android#activity-changes)，并读取了当前安装的 2.0.10 版本 README 和插件对 FragmentActivity 的实际检查。FileProvider 包名依据 [Android Context.getPackageName](https://developer.android.com/reference/android/content/Context#getPackageName())。

## 4. 本轮主要文件

| 文件 | 变更目的 |
| --- | --- |
| `lib/widgets/notifications_view.dart`（新增） | 筛选、刷新、计数、写入确认、防重复、失败恢复和过期结果保护 |
| `lib/widgets/notification_group_list.dart` | 分组默认展开、稳定键、读按钮和滑动反馈、分页重试、Material 层 |
| `lib/models/notification.dart` | 读状态副本、兼容官方 content/type 字段、稳健解析布尔值 |
| `lib/api/gitee_api.dart` | 可选 unread 参数、会话计数缓存、强制刷新与写后失效 |
| `lib/pages/dynamics_page.dart` | 使用独立通知视图，保留原有事件流 |
| `lib/pages/home_page.dart` | 避免晚到的首页计数覆盖通知处理后的角标 |
| `lib/pages/repo_tools_page.dart` | 资源独立加载、逐区块错误、附加加载去重并发与错误恢复 |
| `android/.../MainActivity.kt` | 保留已有安装桥接，修正包名与生物识别宿主 |
| `android/app/src/main/res/values/styles.xml`、`values-night/styles.xml` | AppCompat 启动及正常主题 |
| `test/notification_api_test.dart`（新增） | API 合同、缓存隔离、并发复用、写后失效和模型 |
| `test/notifications_view_test.dart`（新增） | 通知真实组件事件与失败恢复、小屏大字体深色布局 |
| `test/repo_tools_page_test.dart`（新增） | 403/404 部分成功、错误恢复、慢速附加接口和首屏请求计数 |
| `README.md`、`THIRD_PARTY_NOTICES.md`、本报告 | 真实行为、研究来源、构建和验收边界 |
| `.evolution/` 本轮日志 / 研究记录 / 分析脚本 | 可复查的本地证据；不包含账号密钥 |

没有删除源文件。Android 安装器、Release workflow、草稿、搜索等在任务开始时已经存在的修改继续保留；Git 总 diff 包含这些既有工作，不能全部归为本轮成果。

## 5. 验证记录

| 状态 | 检查、命令与结果 |
| --- | --- |
| PASS | 基线 `flutter test --reporter compact`：exit 0，77 项 |
| PASS | 最终 `flutter test --no-pub --reporter expanded`：exit 0，96 项；新增 19 项，含失败注入和异步竞态；日志 `.evolution/final-tests.log` |
| PASS | `python .evolution/analyze-2026-11-13.py D:\DevTools\flutter\bin\cache\dart-sdk`：同一 SDK analysis_server 的 analyzer 协议，117 个文件、0 diagnostics、exit 0；见 `analyzer-diagnostics.json` |
| PASS | 修复后 `flutter build apk --debug --no-pub`：exit 0；产物 `build/app/outputs/flutter-apk/app-debug.apk`；日志 `android-build-verified.log` |
| PASS | Android SDK `aapt dump badging`：包名 `com.yuchen0x1.giteeclient`，版本 `1.4.1 / 7`，minSdk 24 / targetSdk 36；`apksigner verify --print-certs`：Debug 证书，包验证成功 |
| PASS | `git diff --check`：exit 0，只有既有文件的 CRLF 转换提醒 |
| FAIL | 首次 Debug 构建：BuildConfig unresolved reference；已修复并成功复测 |
| BLOCKED | `flutter analyze --no-pub`：exit 255，analysis_server LSP 初始化 JSON 截断。普通命令未通过；使用上面的同 SDK analyzer 协议完成替代静态检查，没有关闭 lint 或修改 SDK |
| BLOCKED | `flutter build apk --release --no-pub`：Gradle exit 1，三个架构的 AOT snapshotter exit 255，日志中 app.dill 中文路径显示乱码且读取失败；没有生成可交付 Release APK，见 `android-release-build.log` |
| BLOCKED | 真机安装、冷启动、指纹/设备凭证、外部浏览器、系统安装器、跨版本更新：无连接设备/模拟器，未执行 |
| BLOCKED | 真实账号的通知写入、仓库管理和 AI 端到端：本轮未使用账号凭证或写远程数据；测试使用明确的 MockClient fixture，不代替在线验收 |
| NOT APPLICABLE | 数据库迁移、Web/Windows 构建、推送发布：本轮范围没有这些操作 |

测试开发过程中曾发现通知卡片的 Material 缺失断言并修复；新测试的 finder 类型与 Snackbar 歧义也已纠正。最终 96 项全部通过。fixture 仅存在测试中，产品仍访问真实 Gitee API。

Release 失败与路径编码有关的判断来自日志，不代表已定位所有工具链原因。本目录没有可用 8.3 短路径。没有为绕过此问题迁移仓库、复制到其他项目目录或修改全局 SDK/系统设置。

没有提供真实运行截图：设备不可用。未把测试数据渲染结果包装成线上用户截图。Debug APK 使用 Android Debug 证书，不能视为正式签名版本。

## 6. 后续验收与规划

- **P1，设备验收**：用 Android 设备检查启动、生物识别开启/切后台/解锁、通知处理、浏览器跳转；用测试账号核对真实 Gitee 权限与错误提示。
- **P1，Release 构建**：在具备正常路径编码支持的本机环境或项目现有 Linux CI 中复测 AOT；本轮没有触发远程 CI。
- **P1，更新闭环**：真实旧版到新版的发现、下载、校验、Android 安装授权、安装和重启；核对发布证书连续性。本地 Debug 构建不证明此链路。
- **P2，管理列表分页**：当前能力中心分支/标签上限100，Fork/协作者20，贡献者界面仅展示前10；应逐步提供独立完整列表和按区块重试，当前界面不是完整仓库盘点工具。
- **P2，维护与可观测性**：继续按业务拆分大型 `gitee_api.dart` 和管理页，为 AI 服务增加明确配置校验、可恢复错误与隐私说明；不在没有实际需求时引入状态管理框架。
- **P3，自动化**：先确定隐私、耗电和服务商能力，再考虑后台提醒；当前没有新建推送服务或插件系统。

## 7. 本轮完成度评估

采用 1–5 级工程评估：1=不可用，2=存在明显缺口，3=本地有可用实现但关键场景未验收，4=广泛回归及设备/线上证据充分，5=长期生产数据支持。评分针对当前可见证据，不是全项目覆盖率或安全认证。

| 维度 | 评分 | 实际依据与限制 |
| --- | --- | --- |
| 功能完整度 | 3/5 | 已有核心协作功能，本轮完成通知和部分失败恢复；管理长列表与真实权限行为仍需完善/验收 |
| UI/UX | 3/5 | 通知操作入口、空态、重试、小屏大字体深色检查已落实；无完整设备视觉走查 |
| 代码质量 | 3/5 | 96 项测试、117 文件0 diagnostics；仍有较大的 API 和管理页模块 |
| 性能 | 3/5 | 计数请求可复用，附加信息从重复调用改为每项一次并发；没有启动/内存/帧耗时实测 |
| 安全性 | 3/5 | 安全存储/账号隔离已有基础，本轮修正计数会话隔离和生物识别宿主；未做渗透测试和完整签名升级验收 |
| 稳定性 | 3/5 | 失败注入、竞态、分页、Debug 构建通过；Release 工具链及设备验证仍受阻 |
| 可维护性 | 3/5 | 独立通知模块、接口兼容、文档和研究记录齐全；长期拆分仍有空间 |
| 扩展性 | 3/5 | 可选参数与分区加载允许渐进扩展；没有为评分引入未经验证的插件或后台架构 |

本轮研究、实现、本地回归和文档阶段已完成。受环境限制的 Release AOT、真机与在线端到端验收单独保留，不能宣称整体生产验收完成。
