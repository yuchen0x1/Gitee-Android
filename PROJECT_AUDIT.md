# PROJECT_AUDIT.md

# Gitee Client 项目现状审计

审计日期：2026-11-16  
仓库：`yuchen0x1/Gitee-Android`  
分支：`main`  
HEAD：`b3902e1`  
版本：`1.4.2+8`  
远程：`origin -> https://github.com/yuchen0x1/Gitee-Android.git`

> 本审计基于当前工作树的源代码、配置、测试、CI 和既有 `.evolution/` 研究记录。工作树在审计开始时已有大量未提交改动；本轮没有重置、清理或覆盖这些改动。审计结论描述的是代码证据，不代表真实账号、真机或线上服务已经全部验收。

## 1. 项目定位

Gitee Client 是一个只面向 Android 发布的 Flutter 非官方 Gitee 客户端。它直接使用用户自己的 Gitee Open API v5 凭证，不设置自建业务后端，也没有项目自有数据库。主要用户是需要在手机上查看代码、跟进通知、处理 Issue/PR 和管理仓库的开发者。

核心场景：

- 登录后查看动态、通知、仓库和个人信息；
- 浏览 README、目录、源码、提交、分支、标签和 Release；
- 创建或更新 Issue、Pull Request、评论和仓库文件；
- 管理 Star、订阅、Fork、Webhook、协作者、里程碑和部署公钥；
- 在 Android 上安全保存多账号令牌，并使用生物识别锁屏；
- 从 GitHub Release 检查、下载、校验并交给 Android 系统安装新版本。

## 2. 技术与运行架构

| 层 | 实际实现 | 证据 |
| --- | --- | --- |
| UI | Flutter Material 3、Dart | `lib/pages/`、`lib/widgets/`、`lib/theme/` |
| 平台 | Android、Kotlin、FlutterFragmentActivity | `android/app/`、`MainActivity.kt` |
| API | `http` + `ApiClient` + `GiteeApi` | `lib/api/api_client.dart`、`lib/api/gitee_api.dart` |
| 搜索 | Gitee 网页搜索数据源和 v5 API | `lib/api/so_search_api.dart`、`lib/pages/search_page.dart` |
| 状态 | 页面 State、`Listenable` 设置对象、轻量服务缓存 | `lib/providers/`、`lib/services/` |
| 凭证 | `flutter_secure_storage`，旧明文令牌迁移 | `lib/auth/auth_store.dart` |
| 普通设置 | `shared_preferences` | `lib/providers/app_settings.dart` |
| 离线数据 | 安全存储中的按账号隔离缓存 | `lib/services/offline_cache.dart` |
| 草稿 | 安全存储中的 Issue/PR/代码编辑草稿 | `lib/services/composer_draft.dart` |
| 更新 | GitHub REST API、Release 页面和 Atom Feed 兜底 | `lib/services/update_service.dart` |
| 发布 | GitHub Actions，Android APK/AAB 和 SHA256SUMS | `.github/workflows/ci.yml`、`.github/workflows/release.yml` |

### 关键数据流

1. `main.dart` 加载设置、锁屏和令牌；令牌恢复后注入 `GiteeApi`。
2. 页面调用 `GiteeApi`；`ApiClient` 统一处理鉴权、超时、错误映射、会话代际和短期传输缓存。
3. 账号切换增加会话代际，旧请求完成后不能覆盖新账号状态。
4. 通知页面按未读/全部筛选，写操作在服务端成功后才改变 UI，并使相关计数缓存失效。
5. 更新服务只访问 GitHub 公开 Release；APK 下载后先校验 SHA-256 和大小，再调用 Android FileProvider/系统安装器。

## 3. 功能清单与实际状态

| 模块 | 已核实能力 | 当前边界 |
| --- | --- | --- |
| 登录与账号 | 私人令牌登录、多账号切换、安全存储、旧令牌迁移、生物识别锁 | 未用真实账号做本轮线上回归 |
| 动态与通知 | 事件流、通知分组、未读/全部、分页、刷新、读状态和失败恢复 | 没有推送服务和后台轮询 |
| 仓库阅读 | 仓库列表、README、文件树、代码高亮、提交和提交详情 | 超大仓库和长列表仍需真机性能数据 |
| 仓库管理 | 分支、标签、协作者、Webhook、语言、许可证、里程碑、部署公钥、Release | 部分管理列表仍有上限，长列表未全部分页 |
| Issue/PR | 列表、筛选、创建、评论、状态操作、合并和审阅相关路径 | 真实权限组合未全部在线验收 |
| Gist | 列表、查看、创建、编辑、删除和收藏 | 依赖 Gitee 接口可用性 |
| 搜索 | 仓库、用户、Issue，历史和防抖 | 网页搜索源受站点变化影响 |
| 离线 | 阅读缓存、按账号隔离、草稿保留 | 没有完整离线写入队列和冲突合并 |
| AI 摘要 | OpenAI 兼容接口配置，默认 DeepSeek | 未配置服务时不能宣称在线摘要已验收 |
| 更新 | GitHub API/网页/Atom 兜底、进度、SHA-256、大小检查和系统安装桥接 | 真机安装、证书连续性和跨版本闭环未验收 |

## 4. 审计发现

### 已处理的高优先级风险

- Android 宿主使用 `FlutterFragmentActivity`，满足 `local_auth_android` 的 FragmentActivity 要求。
- 更新下载限制 HTTPS 和允许主机，下载后校验大小及 SHA-256。
- 更新校验和现在按 APK 文件名匹配 sidecar；没有命名匹配时拒绝，不再取 sidecar 的第一个 hash。
- APK 选择优先通用包；只有 ABI 分包时不返回顺序不确定的包。
- Android 8+ 未授予未知来源安装权限时，更新流程返回可区分的状态并提供设置入口。
- Release Gradle 任务没有 `android/key.properties` 或 keystore 时直接失败，不会回退 Debug 签名。
- 通知计数按会话和筛选条件隔离；读操作失败保留列表并提示。
- 仓库能力中心按区块加载，单个权限错误不会遮蔽其他可用信息。

### 仍存在的缺陷和债务

1. 工作树包含多文件未提交改动；当前审计不能把所有改动归于本轮。
2. 没有连接 Android 真机或模拟器，因此启动、生物识别、深链、系统安装器和耗电未完成真实验收。
3. 本地没有正式发布 keystore；Release 构建按新规则会安全失败，必须通过 CI 密钥或本地授权配置。
4. `gitee_api.dart` 仍然较大，接口域和模型转换可以继续拆分。
5. 分支、标签、Fork、协作者等管理列表仍有分页和完整性缺口。
6. 写操作没有统一的离线队列、冲突解决和可恢复任务中心。
7. 没有崩溃报告、性能基线、网络请求指标和用户可控的诊断导出。
8. `gitee.com` 深链声明没有项目可控制的 `assetlinks.json` 证据，不能宣称 Android App Links 已自动验证。
9. 依赖存在可升级版本，但升级需要逐项兼容性验证，不能仅按版本提示批量升级。

## 5. 安全审计摘要

- 凭证：令牌通过 Authorization 头发送，不写 URL；安全存储由 `flutter_secure_storage` 提供。
- 更新：下载地址、重定向主机、资产类型和校验值均受限制；SHA-256 只提供完整性，不等于签名认证。
- 安装：使用非导出的 FileProvider，并只授予临时读取权限；安装权限由 Android 系统控制。
- 日志：现有测试和文档不应打印令牌；后续新增诊断必须继续脱敏。
- Release：GitHub Actions 使用仓库 Secret 注入签名；本地缺少密钥时应失败。
- 许可证：竞品研究只借鉴行为和架构思想，没有把 GPL/AGPL 源码复制进本项目；第三方声明见 `THIRD_PARTY_NOTICES.md`。

## 6. 工程成熟度

| 维度 | 当前判断 | 依据与限制 |
| --- | --- | --- |
| 功能完整度 | 中等偏上 | 核心协作路径多，管理长列表和在线权限组合仍有缺口 |
| 稳定性 | 中等 | 有错误恢复、会话保护和测试，真机与线上证据不足 |
| 安全性 | 中等 | 令牌和更新完整性基础较好，未做渗透测试和签名连续性验收 |
| 性能 | 未充分量化 | 有缓存和并发优化，但没有启动/内存/帧耗时基线 |
| 可维护性 | 中等 | 服务和页面职责已有拆分，API 聚合文件仍大 |
| 发布成熟度 | 中等 | CI/Release 已具备，正式签名、真机安装和回滚仍需外部条件 |

## 7. 审计使用的证据

- 源码：`lib/`、`android/`、`test/`、`tool/`；
- 配置：`pubspec.yaml`、`pubspec.lock`、Gradle、AndroidManifest、GitHub Actions；
- 既有研究：`.evolution/research.json`、`.evolution/source-research-2026-11-13.json`、`.evolution/diohub-research-2026-11-13.json`；
- 既有交付边界：`docs/EVOLUTION_2026-11-13.md`；
- 本轮新增验证：`test/update_service_test.dart`、`test/update_download_test.dart` 和后续完整测试记录。

## 8. 下一步

优先完成设备验收和正式 Release 签名，再推进管理列表分页、可恢复写任务和统一 API 错误模型。不要在没有真机和线上账号证据时把本项目标记为生产级全链路已验证。
