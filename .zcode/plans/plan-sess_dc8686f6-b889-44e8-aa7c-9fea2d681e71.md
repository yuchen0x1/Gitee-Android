# Gitee Android：API 对齐 + 新功能接入 + UI 全面升级

## Context

应用长期未更新。对照 Gitee 官方 API 规格（v5 文档 5.4.93，已从 `https://gitee.com/api/v5/doc_json` 下载到 `~/gitee-spec-analysis/`）完成全面比对，结论：

- **v8 新版 API 全是企业版接口**（`/{enterprise_id}/...`），个人版客户端不适用，不迁移。
- **已确认破坏性变更**：仓库标签按 `name` 寻址（实测 `DELETE /labels/{id}` → 404、`/labels/{name}` → 200），而 `lib/api/gitee_api.dart:2090` 传 `label.id` → **标签删除已坏**；`lib/pages/repo_tools_page.dart:174` 为调用点。
- **疑似变更**：`updateMilestone` 用 PUT，但现行规格只有 `PATCH /milestones/{number}`（实测 id==number，路径不变）；`/repos/.../topics`、`/user/starred*`、`/user/subscriptions/{owner}/{repo}` 已从文档移除（文档常滞后于服务端，处理方式为登录态验证 + 失败降级，不删调用）。
- **v5 文档新增了 app 未用的接口**，按用户确认接入 6 项。
- UI 全面升级（用户已确认）：动效系统、主题化硬编码颜色、骨架屏形态化、搜索防抖、通知/动态页重构等。

## 一、API 修复（gitee_api.dart）

1. `deleteRepoLabel(owner, repo, String name)` — 改传 `name`；同步改 `repo_tools_page.dart:174` 调用（`label.name`）。
2. `updateMilestone` — `PUT` → `PATCH`（路径不变）。
3. `getRepoTopics` / starred / watch 调用保持不动，但确认失败时静默降级（topics 失败 → 空列表不弹错误，repo_detail_page.dart:133 处核对 try-catch）。
4. 核对 `setIssueLabels` PUT、`contents` PUT 等 PUT 用法仍在规格内（已在，不改）。

## 二、新接口接入（6 项功能）

新增 wrapper 均放 `gitee_api.dart`（沿用现有 `_request/_requestCached/_paging` 模式），model 放 `lib/models/`，响应字段以 `~/gitee-spec-analysis/v5_spec.json` 为准：

1. **仓库访问统计**：`GET /repos/{owner}/{repo}/traffic-data` → `RepoTraffic` model；UI 加在 `repo_tools_page.dart`（近 14 天浏览/克隆数区块，403 时显示"无权限"内联空态，复用现有 `_section`/`_InlineEmpty`）。
2. **CI 检查状态**：`GET /repos/{owner}/{repo}/commits/{ref}/check-runs` → `CheckRun` model（name/status/conclusion）；UI 加在 `commit_detail_page.dart` 头部（状态徽章行，含成功/失败/进行中配色；无检查则不显示区块）。
3. **Release 附件**：`GET/POST /repos/{owner}/{repo}/releases/{release_id}/attach_files`（+ DELETE、`.../attach_files/{id}/download`）→ `ReleaseAttachFile` model；`release_detail_page.dart` 由 StatelessWidget 改 StatefulWidget，新增附件列表区块（下载走 `launch_url.dart` 现有工具）。
4. **Issue↔PR 关联**：`GET /repos/{owner}/issues/{number}/pull_requests`（注意 owner 后无 repo）、`GET /repos/{owner}/{repo}/pulls/{number}/issues` → 复用现有 `PullRequest`/`Issue` model；UI：`issue_detail_page.dart` 加"关联 PR"区、`pr_detail_page.dart` 加"关联 Issue"区（可点击跳详情，空则隐藏）。
5. **创建仓库模板选择**（`create_repo_page.dart` + `gitee_api.dart` 的 `createUserRepo` 扩参）：
   - `GET /user/namespaces` → `Namespace` model → "归属空间"下拉（含个人/组织）
   - `GET /licenses` + `GET /licenses/{license}` → "License"下拉（body 传 `license`）
   - `GET /gitignore/templates` → ".gitignore 模板"下拉（body 传 `gitignore_template`）
   - 三项均为可选，接口失败时隐藏对应下拉不阻塞表单；`namespace` 传 path 参数

## 三、UI 全面升级

1. **动效系统**（新文件 `lib/widgets/anim.dart`）：
   - `FadeSlideIn`（列表项交错入场，delay 按索引）
   - `AnimatedSwitcher` 用于动态页 2 tab 内容切换（`dynamics_page.dart`）
   - Hero：`RepoCard` 头像 ↔ 仓库详情头像、`UserTile` 头像（tag = 图片 url）
2. **主题化硬编码颜色**（新文件 `lib/theme/code_theme.dart`）：
   - 代码高亮色板亮/暗两套（`code_view_page.dart:126-135,369,378`）
   - commit/pr 状态色、文件夹图标色（`repo_detail_page.dart:999`、`repo_file_browser_page.dart:215`）、`skeleton_list.dart:13-14` → 走 Theme
3. **骨架屏形态化**：`SkeletonList` 加 `variant`（repoCard/userTile/commitRow/issueRow），各列表页按语义选用。
4. **搜索升级**（`search_page.dart`）：400ms 防抖实时搜索（`Timer`），回车与输入并行。
5. **通知/动态页重构**：`dynamics_page.dart` 手写分页状态机（63-123、216-293）改用 `PagedListView` 统一模式。
6. **友好错误文案**（新文件 `lib/utils/error_message.dart`）：401/403/404/429/网络超时 → 中文文案；替换 `paged_list_view.dart:99`、`dynamics_page.dart:134` 等 `e.toString()` 直出。
7. **profile 设置区分组卡片化**（`profile_page.dart:117-236`），复用 `SectionHeader`。
8. **性能**：`GlassSurface` 加 `simple` 模式（半透明纯色+边框，无 BackdropFilter），RepoCard 长列表默认用 simple。

## 关键文件

改动：`lib/api/gitee_api.dart`、`lib/models/*`（新增 4 个 model 文件）、`lib/pages/{create_repo,repo_tools,commit_detail,release_detail,issue_detail,pr_detail,dynamics,search,profile,repo_detail,repo_file_browser,code_view}_page.dart`、`lib/widgets/{skeleton_list,glass_surface,paged_list_view,repo_card,user_tile}.dart`
新增：`lib/widgets/anim.dart`、`lib/theme/code_theme.dart`、`lib/utils/error_message.dart`

## 验证

1. `flutter analyze` 零告警
2. `flutter test`（现有测试通过；API wrapper 新增 mock 传输层单测，沿用 `setClientForTest` 注入模式）
3. `flutter build apk --debug` 编译通过
4. 手动验证清单（需登录态，交给用户）：标签删除、里程碑更新、topics 显示、6 项新功能、亮暗主题下代码高亮/骨架屏

## 分批交付

改动量大，按三批提交（各自 `flutter analyze` + `flutter test` 通过后单独 commit，推送 GitHub origin）：
- 批次 1：API 修复（labels/milestones/topics 降级）
- 批次 2：6 项新接口功能
- 批次 3：UI 全面升级