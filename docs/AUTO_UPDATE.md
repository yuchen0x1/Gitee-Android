# Android 自动更新

## 当前方案

应用使用 GitHub Releases 作为唯一更新源：

1. 应用启动后和「我的 → 检查更新」会请求公开 Release。
2. REST API 不可用时，版本检查回退到 GitHub 发布页；更新下载仍只接受 GitHub HTTPS 资产地址。
3. Android 通用 APK 下载到应用临时目录，界面显示真实进度和速度，并在失败时最多重试 3 次。
4. 安装前校验资产大小和 SHA-256。校验值来自 GitHub Release asset 的 `digest`，或同一 Release 中的 `SHA256SUMS.txt`。
5. 校验通过后通过 Android 系统安装器启动安装。普通应用不能静默安装，用户需要在系统界面确认。

下载失败、来源地址不受信任、缺少校验值或校验不匹配时，应用拒绝安装并保留当前版本。

## 发布流程

当前项目只发布 Android：

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

发布前提升 `pubspec.yaml` 的版本，例如 `1.4.2+8`，然后在 `main` 创建并推送匹配标签：

```bash
git tag v1.4.2
git push origin main v1.4.2
```

`.github/workflows/release.yml` 会：

- 校验标签版本与 `pubspec.yaml` 一致；
- 使用 Android release keystore 构建通用 APK、分架构 APK 和 AAB；
- 验证所有 APK 的签名，并要求证书指纹与既有正式证书一致；
- 生成 `SHA256SUMS.txt`；
- 将安装包和校验文件发布到 GitHub Release。

正式发布需要在 GitHub Actions 配置：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`

私钥文件和 `android/key.properties` 不得提交到仓库。工作流使用 GitHub 自动提供的 `GITHUB_TOKEN` 发布 Release。

## 渠道和版本策略

当前只使用 stable Release。版本号遵循 `MAJOR.MINOR.PATCH`，构建号放在 `+` 后。预发布版本不会被当前 `releases/latest` 检查选中；如果未来需要 beta 渠道，应新增明确的 Release 过滤配置和设置项。

## 测试

自动测试覆盖：版本比较、Release 解析、Android 资产选择、GitHub digest 解析、API 回退、缓存和并发检查。真实 APK 下载和系统安装需要已发布的带 SHA-256 资产、网络连接和 Android 设备，不能在没有这些条件时标记为通过。

## 已知限制

- Android 系统可能要求用户开启“允许安装未知来源应用”；应用不能绕过系统确认。
- GitHub Release 资产必须带 `digest` 或 `SHA256SUMS.txt`，否则客户端会拒绝安装。
- 当前不支持后台静默下载、断点续传和自动重启；下载在更新对话框中进行。
- APK 必须使用与已安装版本兼容的 release 签名，否则 Android 会拒绝覆盖安装。工作流要求从 GitHub Secrets 注入正式签名，并在发布前验证 APK 签名和证书指纹。
- 本项目不恢复 Windows、macOS 或 iOS 更新流程。
