# Gitee Client

> **把码云装进口袋** —— 码云在手，协作不愁。刷通知、翻代码、回 Issue、审 PR，一部手机全搞定。

本项目是一个使用 Flutter 与 Material 3 构建的 Gitee（码云）非官方移动客户端。

> 郑重说明：本项目并非 Gitee 官方客户端，与深圳市奥思网络科技有限公司（码云运营方）无隶属或授权关系，仅基于 Gitee 开放能力为开发者提供便利。

## 一、这个项目解决什么

Gitee Client 把 Gitee Open API v5 的常用协作能力搬到手机上。如果你需要在通勤、出差或碎片时间里跟进仓库动态、回复 Issue、审阅 Pull Request，又不想打开浏览器或桌面 IDE，它就是为此准备的。

它特别适合这些时刻：

- 通勤路上快速查看个人仓库、Star 仓库、订阅仓库和组织仓库；
- 利用碎片时间阅读 README、文件内容、提交记录、Issue、PR 和通知；
- 出门在外处理仓库事务：Star、订阅、Fork、创建 Issue、创建 PR、管理协作者、Webhook、Release、Tag，仓库详情页一站搞定；
- 在意账号安全又有多账号需求的开发者：私人令牌登录配合系统安全存储，降低明文泄露风险；
- 希望把冗长的 Issue / PR 浓缩成中文摘要，可选接入 OpenAI 兼容接口（默认 DeepSeek API 地址）。

## 二、功能总览

| 模块 | 能力一览 |
| --- | --- |
| 账号与安全 | 使用 Gitee 私人令牌登录；令牌通过 Authorization 请求头传递，不写入 URL 或表单正文；令牌保存在 flutter_secure_storage，旧版明文令牌自动迁移并清理；支持账号管理、多账号切换、退出登录；支持深色模式、生物识别解锁、图片缓存清理 |
| 仓库与代码 | 浏览个人仓库、Star 仓库、订阅仓库、组织仓库和用户公开仓库；搜索仓库、用户和 Issue；查看仓库详情、README、目录、文件内容、分支、标签、提交记录和提交详情；查看代码文件，支持 Markdown 渲染、图片缓存和代码高亮；Star / Unstar、订阅 / 取消订阅、Fork 仓库；创建仓库，创建、编辑和删除仓库文件；管理分支保护、协作者、Webhook、Release、Tag、Fork、贡献者、语言统计和许可证信息 |
| Issue 与 Pull Request | 查看、搜索、筛选、创建和更新 Issue；查看、创建、编辑和删除 Issue 评论；查看、创建、关闭、重新打开和合并 Pull Request；查看 PR 提交、文件变更、评论和操作日志；管理 PR 审查人员、测试人员及审查状态；可选使用 AI 摘要服务快速理解 Issue / PR 内容 |
| 动态与通知 | 查看通知、未读数量、仓库动态、用户动态和接收事件；标记单条通知或全部通知为已读；查看关注、粉丝、组织成员和组织仓库；关注 / 取消关注用户 |
| 移动端体验 | Material 3 风格界面，支持明暗主题；半透明玻璃质感面板、背景模糊、细边框与分层阴影；底部导航、下拉刷新、分页加载、错误状态、空状态和骨架屏；支持 Android 深链入口 |

## 三、三步跑起来

### 第一步：备好环境

| 依赖 | 版本 / 说明 |
| --- | --- |
| Flutter | 3.x |
| Dart | 3.x |
| JDK | 17 |
| IDE / SDK | Android Studio 或已配置的 Android SDK |
| 设备 | Android 真机或模拟器 |

环境装好后，先给本机做个体检：

```bash
flutter doctor -v
flutter devices
```

### 第二步：拉代码、装依赖

```bash
git clone https://gitee.com/yuchen0x1/gitee-mobile-client.git
cd gitee-app
flutter pub get
```

> 手头已经有本仓库源码？跳过克隆，直接进入项目根目录执行 `flutter pub get` 即可。

### 第三步：运行或打包

```bash
# 使用默认连接设备运行
flutter run

# 指定 Android 模拟器或设备运行
flutter run -d emulator-5554
```

需要安装包时：

```bash
# Debug 包
flutter build apk --debug

# Release 包
flutter build apk --release
```

Release APK 默认输出位置：`build/app/outputs/flutter-apk/app-release.apk`。

## 四、版本与更新

正式版安装包（Windows 桌面便携版、Android 通用 APK、各 Android 架构 APK 以及 Android App Bundle）统一通过仓库 Releases 页面分发，可前往 <https://gitee.com/yuchen0x1/gitee-mobile-client/releases> 下载；推送 `v*` 标签会自动构建并创建新的 Release。

应用内置了更新检查：登录进入主页后会自动检查新版本，也可以在「我的」→「设置」→「检查更新」手动检查。发现新版本后，Android 会打开通用 APK 下载，Windows 会打开 x64 便携 ZIP 下载，其他平台会打开 Release 页面。

更新检查默认先访问 Gitee 公开 Release，失败或限流时自动回退 GitHub；检查过程不需要登录，不会发送 Gitee Token。检查结果会在应用进程内缓存 10 分钟，手动检查会强制刷新。

发布新版本时，请同步提升 `pubspec.yaml` 的版本号并推送对应的 `v*` 标签（例如 `2.0.0` 与 `v2.0.0`），这样客户端才能正确识别更新。

## 五、登录与日常使用

应用支持两种登录方式：

1. **Gitee 账号密码登录（OAuth）**：登录页点击「使用 Gitee 账号登录」后，应用会在系统浏览器中打开 Gitee 官方授权页。账号和密码只在 Gitee 页面输入，不会经过本应用，也不会被保存；授权完成后通过 `gitee://oauth/callback` 返回应用。OAuth 登录需要先在 Gitee 创建 OAuth 应用，并将回调地址设置为 `gitee://oauth/callback`。
2. **私人令牌登录**：在 Gitee 账号设置中创建私人令牌，并按需授予仓库、Issue、Pull Request、通知、组织等权限。应用不内置任何后台账号或默认密码，所有请求都使用你输入的 Gitee 私人令牌访问 Gitee Open API v5。

OAuth 配置通过构建参数注入，不要把真实密钥提交到仓库：

```bash
flutter run \
  --dart-define=GITEE_CLIENT_ID=你的_client_id \
  --dart-define=GITEE_CLIENT_SECRET=你的_client_secret \
  --dart-define=GITEE_REDIRECT_URI=gitee://oauth/callback
```

`GITEE_CLIENT_SECRET` 会随移动端构建产物存在，无法视为真正的秘密。当前默认回调使用 Android 自定义 scheme `gitee://oauth/callback`，其他应用可能注册同名 scheme 并拦截回调，因此更适合个人构建或内测。正式发布时建议由自有后端完成 authorization code 换 token，并改用 Android App Links/对应平台的 Universal Links；客户端只接收短期访问令牌。

3. **登录后**：应用会读取当前用户资料并进入主页。OAuth access token 和 refresh token 使用系统安全存储保存，启动时会在过期后尝试刷新；应用不会保存账号密码。
4. **浏览与搜索**：主页底部导航包含动态、仓库、搜索、我的等入口：
   - 在「动态」查看通知、未读数量和事件流；
   - 在「仓库」浏览个人仓库列表；
   - 在「搜索」查找仓库、用户或 Issue；
   - 在「我的」查看账号信息、Star 仓库、关注、粉丝、组织、订阅、我的 Issue 和设置项。
5. **管理仓库协作**：进入仓库详情页后，可以查看 README、文件目录、提交、Issue、PR、Release 等信息；也可以执行 Star、订阅、Fork、创建 Issue、创建 PR、创建/编辑文件、分支保护、协作者、Webhook、Tag 等操作。部分写入类操作需要令牌具备对应权限。

## 六、AI 摘要（可选）

在「我的」→「AI 设置」中填写 OpenAI 兼容接口的 API Key 即可启用。默认摘要服务使用 DeepSeek Chat 接口格式；如需适配其他兼容服务，可在代码中调整 `AiSummary.baseUrl` 和 `AiSummary.model`。

## 七、典型操作一览

以下示例均为演示数据，不包含真实令牌或真实私密数据。

| 场景 | 你的操作 | 应用反馈 |
| --- | --- | --- |
| 登录 | 在 Gitee 官方授权页完成账号密码登录，或输入私人令牌 `<your_gitee_private_token>` | 登录成功进入主页，显示当前 Gitee 用户头像、用户名、仓库数、关注数、粉丝数 |
| 搜索仓库 | 搜索类型选“仓库”，关键词 `flutter`，第 1 页每页 20 条 | 返回仓库列表：owner/repo-name、仓库描述、Star 数、Fork 数、主要语言、更新时间 |
| 查看仓库文件 | 定位仓库 owner/repo，分支 main，路径 README.md | 渲染后的 README 内容；代码 / 文本文件内容支持语法高亮与图片加载 |
| 创建 Issue | 仓库 owner/repo，标题“修复登录状态失效问题”，内容描述复现步骤、预期结果和实际结果 | Issue 已创建，进入详情页显示编号、标题、状态、作者、时间和评论区 |
| 创建 Webhook | 仓库 owner/repo，回调地址 `https://example.com/webhook`，触发事件 push、pull_request、issue | Webhook 创建成功，仓库能力中心显示 Webhook 列表，可继续测试、编辑或删除 |

## 八、技术实现

- **界面**：Flutter、Material 3
- **网络**：http、Gitee Open API v5
- **本地配置**：shared_preferences
- **安全存储**：flutter_secure_storage
- **Markdown / 图片**：markdown_widget、cached_network_image
- **外部链接**：url_launcher
- **本地认证**：local_auth
- **深链**：app_links
- **代码高亮**：highlight
- **版本信息与更新**：package_info_plus、GitHub/Gitee Releases

## 九、常见疑问

**需要后台服务或内置账号吗？**
不需要内置账号。你可以通过 Gitee 官方 OAuth 页面使用账号密码登录，也可以使用自己的私人令牌；应用不会保存账号密码。

**令牌存在哪里，安全吗？**
令牌使用系统安全存储（flutter_secure_storage）保存；从旧版本升级时，明文令牌会自动迁移到安全存储并删除。

**AI 摘要是必需功能吗？**
不是。它是可选功能，需要你自行配置 OpenAI 兼容接口的 API Key，默认使用 DeepSeek。

**这个仓库能作为 Dart 包发布吗？**
不能。`pubspec.yaml` 中已设置 `publish_to: none`，项目当前按应用项目维护，不作为 Dart 包发布。

## 十、仓库信息

- 仓库地址：<https://gitee.com/yuchen0x1/gitee-mobile-client>
- 问题反馈：[Gitee Issues](https://gitee.com/yuchen0x1/gitee-mobile-client/issues)
- 维护状态：正常更新
- 许可证：暂未声明（如需分发，请补充 LICENSE 文件并在此处更新）

## 十一、来源与致谢

- 原项目：[nhzhongguo/gitee_app](https://gitee.com/nhzhongguo/gitee_app)（原创作者：nhzhongguo）
- 本仓库是在原项目基础上持续升级的二次开发版本，感谢原作者的付出。

## 十二、反馈与交流

- QQ 交流群：1016190748
- Telegram：<https://t.me/lenmoC>

联系或反馈时，请备注原项目地址 https://gitee.com/nhzhongguo/gitee_app、原创作者 nhzhongguo，并说明你使用的版本、运行平台和具体问题，便于更快定位。
