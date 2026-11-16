# 仓库内容与清理约定

本项目仅维护 Android。源码仓库保留 `lib/`、`android/`、`test/`、`tool/`、产品与开发文档、CI、许可证、`pubspec.yaml` 和 `pubspec.lock`。应用项目需要提交锁文件以固定依赖；图标、测试、正在使用的页面不能仅因名称或体积被删除。

## 不提交的内容

| 内容 | 处理方式 |
| --- | --- |
| `build/`、`.dart_tool/`、`android/.gradle/`、`.cxx/` | 可重新生成的构建与工具缓存，由 Git 忽略；需要清理构建时使用 `flutter clean` |
| APK / AAB 等安装包 | 通过 GitHub Release 分发，不作为源码提交；本地当前构建产物位于忽略的 `build/` |
| `.evolution/`、`.workbuddy/`、`.zcode/`、`.local/` | 本机分析、会话、研究、诊断或临时记录，不上传源码仓库 |
| `PROJECT_AUDIT_REPORT.md` 等过期临时审计稿 | 已由当前有效文档替代后清理；不能用旧报告声称当前状态 |
| `android/key.properties`、签名 keystore、`.env*`、`local.properties` | 本机配置或敏感文件，必须忽略；签名私钥和有效配置仍需在本机妥善保留，不能作为“无用文件”删除 |
| Windows / iOS / macOS / Linux / Web 平台工程 | 不生成、不恢复、不作为本项目支持平台 |

忽略规则不会自动移除已经被 Git 跟踪的文件。发现误跟踪内容时，应核实用途后以普通提交删除当前分支文件，保留可审计历史；不能为清理普通旧计划重写历史或删除 Release、标签、可用安装包。

## 发布说明维护

- `docs/releases/release-notes.md` 是完整日志，README 的「最新更新」只保留最新已发布版本摘要。
- 既有版本依据对应标签之间的真实变更整理；未发布的工作区改进写入 Unreleased，不回填为旧安装包能力。
- `tool/release_notes.py` 按版本提取说明；缺失、重复或空条目会失败。Release 工作流在构建前检查，并通过 `--notes-file` 使用同一份正文发布。
- 修改既有 GitHub Release 的说明时，保留 Release ID、标签、发布日期和全部附件，不重新发布旧版本。

## 2026-11-13 检查结果

- GitHub 当前分支未发现 APK/AAB、构建目录、`.dart_tool` 或签名配置被提交。文件名检查和常见凭据模式扫描未发现匹配；这不是完整历史凭据泄露审计。
- 唯一明确误上传的是 `.zcode/plans/plan-sess_dc8686f6-b889-44e8-aa7c-9fea2d681e71.md`，内容仍安排发布已过期的 v1.1.1；已通过[独立清理提交](https://github.com/yuchen0x1/Gitee-Android/commit/51e3e79ff57e08a3598fb8982fa63c4d295fd871)从 GitHub 当前分支移除，并同步本地主分支。
- 从 `lib/main.dart` 遍历本地导入关系后，发现 `lib/widgets/section_header.dart` 未被应用引用；在 GitHub 当前代码和测试中也只有自身定义，且本地无未提交修改。已通过[第二项清理提交](https://github.com/yuchen0x1/Gitee-Android/commit/b3902e1a645af0d1dc4d333702655729f1f57241)移除这个闲置组件。
- 本地清理过期计划、旧审计稿和重复诊断记录；最后一次验证结果、研究来源和可复用分析工具仍在已忽略的 `.evolution/` 中保留。
- `demo_page.dart` 原来连接着真实的使用指南入口，不能直接删功能。现已改为 `usage_guide_page.dart`，同步调用处，并移除过期的 `1.0.0+1` 与“未接入高亮库”说明。
- 6 个既有 GitHub Release 的更新日志已按版本补全；v1.0.0 只保留本地历史标签记录，不创建不存在的 GitHub 发布。
- v1.4.0 与 v1.4.1 的公开 APK 证书确实不同，安装兼容性说明已补充到 v1.4.1。未卸载手机应用，也未删除手机数据。

本轮研究、原 Release 说明、附件核对、清理明细和签名核验记录保留在本机忽略目录 `.evolution/release-maintenance-2026-11-13/`。这份公开文档不包含密钥或令牌。

### 清理后验证

- 可重建缓存从约 4.86 GB 减至约 2.31 GB，重新构建后的净释放空间为 **2,551,234,798 字节（约 2.55 GB）**；保留当前 Debug APK，旧 Release APK 和核验时下载的临时 APK 已删除。
- 96 项 Flutter 测试通过；同 SDK 静态分析检查 116 个 Dart 文件，0 diagnostics；Android Debug APK 构建和 `apksigner verify` 通过。
- 发布说明提取器的 6 项 Python 标准库测试通过，覆盖版本隔离、缺失版本、重复版本、空正文、拒绝发布 Unreleased，以及 Windows/Linux 换行一致性。
- Release workflow YAML 已解析并检查版本日志校验与 `--notes-file` 路径。CI/发布流程修改仍是本地准备，未触发远程流水线。
- 本机两份签名/配置文件的内容摘要与清理前完全一致；未跟踪密钥、缓存、会话或研究目录。

GitHub 已实际更新的内容仅为 6 个现有 Release 的说明，以及两项独立文件清理提交。其他功能、文档、忽略规则和流水线改动仍在本地工作区，没有一并推送。
