# 仓库迁移公告（所有 AI 会话必须遵守）

**【永久规则】从 2026-11-04 起，本项目的 Gitee 仓库不再更新（旧 Gitee 仓库已删除），以后所有代码更新一律只推送到 GitHub 仓库。**

- GitHub 主页：https://github.com/yuchen0x1 （对应仓库：https://github.com/yuchen0x1/Gitee-Android）
- 任何 git push、提交、发版、同步任务：目标只能是 GitHub，绝不要再向 Gitee（gitee.com/yuchen0x1）推送任何内容。
- 推送前先 `git remote -v` 检查远程：远程应为 `origin https://github.com/yuchen0x1/Gitee-Android.git`，如不是先执行 `git remote set-url origin https://github.com/yuchen0x1/Gitee-Android.git`，推送时只使用 origin（GitHub）远程。
- 应用的更新检查与更新日志走 GitHub 公开 Release（REST API + 网页兜底），仓库地址集中在 `lib/services/update_service.dart` 的常量里，迁移仓库时只需改那里。

# 平台策略（所有 AI 会话必须遵守）

**【永久规则】从 2026-09-07 起，本项目不再保留 Windows 桌面端，以后只更新 Android 手机版。**

- `windows/` 桌面平台目录已删除，不要重新生成或恢复（如误删可用 `flutter create --platforms=windows .` 重建，但默认不要这么做）。
- 所有功能开发、构建（`flutter build apk`）、发版只针对 Android。
- 不要在 CI/Release 工作流中添加 Windows 构建任务，也不要在 README 等文档中恢复 Windows 平台的描述。
- `lib/` 中残留的 `TargetPlatform.windows` 分支（主题、更新包选择）属无害的平台判断代码，保留即可，不要专门清理。
