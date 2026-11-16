# 仓库迁移公告（所有 AI 会话必须遵守）

**【永久规则】从 2026-11-04 起，本项目的 Gitee 仓库不再更新（旧 Gitee 仓库已删除），以后所有代码更新一律只推送到 GitHub 仓库。**

- GitHub 主页：https://github.com/yuchen0x1 （对应仓库：https://github.com/yuchen0x1/Gitee-Android）
- 任何 git push、提交、发版、同步任务：目标只能是 GitHub，绝不要再向 Gitee（gitee.com/yuchen0x1）推送任何内容。
- 推送前先 `git remote -v` 检查远程：远程应为 `origin https://github.com/yuchen0x1/Gitee-Android.git`，如不是先执行 `git remote set-url origin https://github.com/yuchen0x1/Gitee-Android.git`，推送时只使用 origin（GitHub）远程。
- 应用的更新检查与更新日志走 GitHub 公开 Release（REST API + 网页兜底），仓库地址集中在 `lib/services/update_service.dart` 的常量里，迁移仓库时只需改那里。

# 平台策略（所有 AI 会话必须遵守）

**【永久规则】本项目只开发、运行、构建和发布 Android 版。从 2026-09-07 起不再保留 Windows 桌面端；2026-11-13 再次明确不生成其他平台版本。**

- 不要生成或恢复 `windows/`、`ios/`、`macos/`、`linux/`、`web/` 平台工程目录；若发现误生成的其他平台工程或应用产物，只在当前项目范围内清理。
- 所有功能开发、构建（`flutter build apk`）、发版只针对 Android。
- 本地运行仅使用 Android 真机或模拟器，不为预览生成桌面或 Web 版本。
- 不要在 CI/Release 工作流中添加其他平台构建任务，也不要在 README 等文档中将其他平台写为支持平台。CI 可以使用 Linux/Windows 主机执行 Android 构建。
- `lib/` 中残留的 `TargetPlatform.windows` 分支（主题、更新包选择）属无害的平台判断代码，保留即可，不要专门清理。
- Flutter SDK 和第三方插件自带的跨平台实现、依赖锁定信息、测试宿主缓存不代表本项目支持这些平台，不要为清理应用平台而修改 SDK、依赖包或破坏 Android 构建与本地测试。
