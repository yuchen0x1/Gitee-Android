# 仓库迁移公告（所有 AI 会话必须遵守）

**【永久规则】从现在开始，本项目的 GitHub 仓库不再更新，以后所有代码更新一律只推送到 Gitee 仓库。**

- Gitee 主页：https://gitee.com/yuchen0x1 （对应仓库：https://gitee.com/yuchen0x1/<仓库名>）
- 任何 git push、提交、发版、同步任务：目标只能是 Gitee，绝不要再向 GitHub（github.com/yuchen0x1）推送任何内容。
- 推送前先 `git remote -v` 检查远程：如没有 Gitee 远程，先添加（`git remote add gitee https://gitee.com/yuchen0x1/<仓库名>.git`），推送时只使用 gitee 远程。

# 平台策略（所有 AI 会话必须遵守）

**【永久规则】从 2026-09-07 起，本项目不再保留 Windows 桌面端，以后只更新 Android 手机版。**

- `windows/` 桌面平台目录已删除，不要重新生成或恢复（如误删可用 `flutter create --platforms=windows .` 重建，但默认不要这么做）。
- 所有功能开发、构建（`flutter build apk`）、发版只针对 Android。
- 不要在 CI/Release 工作流中添加 Windows 构建任务，也不要在 README 等文档中恢复 Windows 平台的描述。
- `lib/` 中残留的 `TargetPlatform.windows` 分支（主题、更新包选择）属无害的平台判断代码，保留即可，不要专门清理。
