# UPGRADE_REPORT.md

# Gitee Client 项目升级交付报告

日期：2026-11-16  
仓库：`yuchen0x1/Gitee-Android`  
分支：`main`，HEAD `b3902e1`  
版本：`1.4.2+8`  
远程：仅 GitHub `origin`

## 1. 交付范围

本轮按用户提供的 PROJECT EVOLUTION ENGINE 执行了项目扫描、竞品研究、风险审计、代码改动、测试和文档整理。当前工作树在本轮开始前已经存在大量未提交改动；本报告把这些既有改动与本轮新增修复分开说明，没有执行 reset、clean、commit、push、发布或远程写操作。

## 2. 竞品研究结果

- 研究项目：20 个相关开源项目，覆盖 Flutter GitHub/GitLab 客户端、原生 Gitea/Forgejo/GitLab 客户端、Android 文件管理器、Git 同步和发布工程。
- 直接源码级重点记录：GitTouch、GitNex、DioHub、FastHub、Flutter GitConnect；证据保存在 `.evolution/source-research-2026-11-13.json` 和 `.evolution/diohub-research-2026-11-13.json`。
- 其余项目核对了公开仓库、README、目录/依赖、许可证、Release 或活动记录；详细链接和结论见 `COMPETITOR_ANALYSIS.md`。
- 最值得借鉴：GitNex 的通知和账户流程、DioHub 的移动代码浏览、GitSync/PuppyGit 的恢复与冲突思想、Round-Sync 的资产校验与发布纪律、Nextcloud/Syncthing-Fork 的工程和状态解释。
- 当前项目优势：Gitee v5 业务覆盖较深、Android-only 范围清晰、令牌安全存储、多账号、通知写入确认、GitHub 更新校验和中文移动体验已形成组合。
- 明显短板：管理列表分页、离线写队列和冲突 UI、统一错误模型、真实设备/正式签名/线上更新闭环、性能基线和可观测性。
- 许可证结论：GPL/AGPL 项目只作为行为和架构参考，没有复制代码或新增不兼容依赖。

## 3. 升级数量和状态

共发现 **38 项**真实升级点：

| 状态 | 数量 | 说明 |
| --- | ---: | --- |
| 已完成 | 16 | EV-001 至 EV-016；其中本轮新增 4 项，其余是当前工作树中已有并经测试/代码核实的改进 |
| 部分完成 | 2 | EV-025 文件冲突决策界面、EV-036 无障碍/减少动画 |
| 阻塞 | 2 | EV-017 Release AOT/正式签名环境、EV-018 真机更新闭环 |
| 未实施计划 | 18 | 需要较大产品、协议、设备或安全设计，已写入路线图 |

逐项定义、依据、参考实现、文件、优先级和验收标准见 `UPGRADE_ROADMAP.md`。没有把未验证能力标成完成。

### 本轮新增的 4 项

1. **EV-001**：Release Gradle 任务缺少完整 `android/key.properties` 或 keystore 时直接失败，阻止 Debug 签名包冒充正式包。
2. **EV-002**：SHA256SUMS 逐行按 APK 文件名唯一匹配；乱序、缺失或重复冲突都拒绝。
3. **EV-003**：Android 8+ 未授权未知来源安装时返回可区分结果，并提供打开应用安装权限设置的入口。
4. **EV-004**：更新资产优先通用 APK；只有 ABI 分包时返回空，避免顺序依赖。

## 4. 代码和配置改动

### 本轮直接修改

- `android/app/build.gradle.kts`：Release 签名门禁。
- `android/app/src/main/kotlin/com/yuchen0x1/giteeclient/MainActivity.kt`：安装器权限状态和系统设置入口。
- `lib/services/update_installer.dart`：安装结果枚举和设置调用。
- `lib/widgets/update_dialog.dart`：未知来源权限错误和引导按钮。
- `lib/services/update_service.dart`：命名校验和解析，移除第一个 hash 兜底。
- `lib/models/app_update.dart`：通用 APK 选择策略。
- `test/update_service_test.dart`：纯 ABI 资产不误选。
- `test/update_download_test.dart`：校验和乱序匹配和无匹配拒绝。
- `PROJECT_AUDIT.md`、`COMPETITOR_ANALYSIS.md`、`UPGRADE_ROADMAP.md`、`UPGRADE_REPORT.md`、`CHANGELOG.md`：审计、研究、路线和交付记录。

### 当前工作树中已有的相关改动

通知视图和读状态、API 会话缓存、离线缓存、草稿、代码编辑、仓库能力中心的分区失败、深链、Android FragmentActivity/主题、GitHub 更新服务和 CI/Release 工作流等仍保留在工作树，具体文件以 `git status` 和 `git diff` 为准。本轮没有把这些既有改动重新提交或覆盖。

### 数据和平台边界

- 没有数据库迁移。
- 没有改变安全存储键格式或删除用户配置。
- 没有新增 Windows、iOS、macOS、Linux 或 Web 工程。
- 没有推送、创建 Release、修改 GitHub 远程或使用 Gitee 远程。

## 5. 测试和验证

| 状态 | 命令 / 检查 | 结果 |
| --- | --- | --- |
| PASS | `flutter test test/update_service_test.dart test/update_download_test.dart` | 20 项通过 |
| PASS | `flutter test --no-pub --reporter compact` | 99 项通过 |
| PASS | `python -m unittest discover -s test -p "*_test.py"` | 6 项通过 |
| PASS | `dart analyze --format machine` | exit 0，无诊断输出 |
| PASS | `flutter build apk --debug --no-pub` | 成功，产物 `build/app/outputs/flutter-apk/app-debug.apk` |
| PASS | `git diff --check` | 通过；仅有既有换行转换提示 |
| EXPECTED FAIL | `flutter build apk --release --no-pub` | 因本机没有 `android/key.properties` 按新安全门禁失败；这是预期保护行为，不是正式包产物 |
| FAIL | `flutter analyze --no-pub` | Flutter analysis server 在 Windows 中文路径返回截断 JSON，exit 1；`dart analyze --format machine` 已作为替代静态检查通过 |
| BLOCKED | `adb devices`、真机安装和运行 | 仅发现 `emulator-5554 offline`，没有可用设备 |
| BLOCKED | 真实 Gitee 账号、通知写入、仓库管理、AI 和更新安装 | 本轮没有使用账号凭证或写远程数据 |
| NOT APPLICABLE | 其他平台构建 | 项目永久只支持 Android |

测试 fixture 验证的是模拟接口和本地行为，不能替代 Gitee 线上权限、Android 系统安装器或正式签名证书验收。

## 6. 升级前后变化

### 升级前

项目已经具备较完整的 Gitee 浏览和协作页面、通知和缓存改进、GitHub 更新下载代码，但发布签名会回退 Debug，校验和 sidecar 在多资产时有错误兜底，Android 安装权限失败缺少引导，通用 APK 选择存在顺序依赖。竞品对标和长期路线没有统一根文档。

### 升级后

- Release 构建失败更早、更安全，缺密钥不会产生误导性正式包。
- 更新下载完整性检查从“有 hash 即可”提升为“按资产名唯一匹配并校验大小/摘要”。
- Android 未知来源安装失败可解释、可进入系统设置后重试。
- 更新资产选择不再因 GitHub 附件顺序选择 ABI 分包。
- 形成项目审计、20 项竞品对标、38 项升级路线和逐项状态报告。
- 本地自动化证据为 99 项 Flutter 测试、6 项 Python 测试、Dart 静态分析和 Debug APK 构建通过。

## 7. 遗留问题和下一阶段

1. 在 Linux CI 或可用正式 keystore 环境验证 Release universal/ABI APK、AAB、签名指纹和证书连续性。
2. 连接 Android 真机，验收冷启动、深链、生物识别、通知写入、系统安装器和跨版本更新。
3. 完成管理列表分页和统一错误模型，再考虑离线写队列与文件冲突界面。
4. 评估签名 manifest/TUF 等发布认证方案；SHA-256 仍只提供完整性，不提供发布者认证。
5. 建立启动、内存、长列表和网络请求的可重复性能基线。
6. 所有外部发布动作仍需单独审阅；当前没有提交、推送、合并或发布。

本报告不把项目标记为生产级全链路完成，原因是正式签名、真机、真实账号和线上更新闭环仍缺少证据。
