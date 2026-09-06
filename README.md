# Gitee Client

> 基于 Flutter 打造的 Gitee（码云）非官方客户端 —— 在手机上刷通知、读代码、回 Issue、审 PR。

![Release](https://img.shields.io/gitee/v/yuchen0x1/gitee-mobile-client) ![Platform](https://img.shields.io/badge/platform-Android-blue) ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter) ![License](https://img.shields.io/badge/license-MIT-green) ![Language](https://img.shields.io/badge/language-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-green)

> **声明**：本项目并非 Gitee 官方客户端，与深圳市奥思网络科技有限公司（码云运营方）无隶属或授权关系，仅基于 Gitee 开放能力（Open API v5）为开发者提供便利。

## 项目简介

Gitee Client 把 Gitee Open API v5 的常用协作能力搬到手机上。如果你需要在通勤、出差或碎片时间里跟进仓库动态、回复 Issue、审阅 Pull Request，又不想打开浏览器或桌面 IDE，它就是为此准备的。

所有请求都直接使用你自己的 Gitee 凭证（私人令牌或 OAuth 访问令牌）访问 Gitee 官方 API，项目不依赖任何自建后端，不内置代理账号，令牌保存在系统安全存储中。

适用场景：

- 通勤路上查看仓库动态、通知和事件流；
- 碎片时间阅读 README、源码、提交记录、Issue 和 PR；
- 出门在外处理仓库事务：Star、订阅、Fork、创建 Issue / PR、管理文件、Webhook、Release；
- 多账号开发者在多台设备间安全切换账号。

## 功能特性

**账号与安全**

- 私人令牌登录，令牌通过 Authorization 请求头传递，不写入 URL 或表单正文；
- 令牌保存在系统安全存储（flutter_secure_storage），旧版明文令牌自动迁移并清理；
- 多账号管理与一键切换；
- SSH 公钥管理（查看 / 添加 / 删除）；
- 生物识别解锁（指纹 / 面容），可在设置中开关。

**仓库与代码**

- 浏览个人仓库、Star 仓库、订阅仓库、组织仓库和任意用户公开仓库；
- 搜索仓库、用户和 Issue（含搜索历史）；仓库搜索使用 Gitee 网页搜索同款数据源；
- 查看仓库详情、README、文件目录、文件内容、分支、标签、提交记录和提交详情（支持提交评论）；
- Markdown 渲染、代码语法高亮、图片缓存；
- Star / 取消 Star、订阅 / 取消订阅、Fork 仓库，查看仓库关注者列表；
- 创建个人仓库和组织仓库；创建、编辑、删除仓库文件；
- 管理分支保护、协作者、Webhook（增删改 / 测试）、Tag、Release（创建 / 编辑 / 删除）、Issue 标签、里程碑和部署公钥。

**Issue 与 Pull Request**

- Issue：查看、搜索、筛选、创建、更新，评论的新增 / 编辑 / 删除，标签与里程碑的展示和设置；
- PR：查看、创建、评论、关闭、重新打开、合并；
- 查看 PR 提交列表、文件变更和操作日志；管理审查人员与测试人员。

**代码片段（Gist）**

- 查看自己的 Gist 列表与文件内容；
- 创建、编辑（含描述与文件内容）、删除；
- 收藏 / 取消收藏。

**动态与通知**

- 通知列表、未读计数、单条 / 全部标记已读；
- 用户动态、接收事件、仓库事件流；
- 关注 / 取消关注用户，查看关注与粉丝列表；组织和组织成员管理。

**体验细节**

- Material 3 界面，明暗主题跟随设置；
- 下拉刷新、分页加载、骨架屏、空状态与错误状态；
- Android 深链入口（`gitee://` scheme）。

## 支持平台

| 平台 | 形态 | 获取方式 |
| --- | --- | --- |
| Android | 通用 APK、分架构 APK、App Bundle | [Releases](https://gitee.com/yuchen0x1/gitee-mobile-client/releases) |

## 系统要求

从源码构建需要：

| 依赖 | 版本 / 说明 |
| --- | --- |
| Flutter | 3.x（stable 渠道） |
| Dart SDK | >=3.0.0 <4.0.0（随 Flutter 附带） |
| JDK | 17（Android 构建需要） |
| Android SDK | 通过 Android Studio 或命令行工具安装 |

装好后先自检：

```bash
flutter doctor -v
flutter devices
```

## 快速开始

```bash
# 1. 克隆仓库
git clone https://gitee.com/yuchen0x1/gitee-mobile-client.git
cd gitee-mobile-client

# 2. 安装依赖
flutter pub get

# 3. 连接设备后运行（Android 真机或模拟器）
flutter run
```

只想直接使用？前往 [Releases](https://gitee.com/yuchen0x1/gitee-mobile-client/releases) 下载安装包，无需配置任何环境。

## 登录配置

应用启动后进入登录页，使用 Gitee 私人令牌登录：

1. 在 Gitee「设置 → 安全设置 → 私人令牌」中[生成令牌](https://gitee.com/profile/personal_access_tokens)，按需勾选 projects、issues、pull_requests、notifications 等权限；
2. 把令牌粘贴进应用登录页即可。所有请求通过 `Authorization` 请求头携带令牌，不写入 URL。

## 使用说明

登录成功后进入主页，底部导航包含四个入口：

- **动态**：通知（含未读计数）、事件流；
- **仓库**：个人 / Star / 订阅 / 组织仓库列表；
- **搜索**：仓库、用户、Issue 全局搜索；
- **我的**：账号信息、关注 / 粉丝、组织、我的 Issue，以及全部设置项。

常用设置（「我的 → 设置」）：

| 设置项 | 说明 |
| --- | --- |
| 深色模式 | 明暗主题切换，本地持久化 |
| 生物识别解锁 | 开启后切回前台需要指纹 / 面容解锁 |
| 账号管理 | 多账号添加与切换 |
| AI 设置 | 配置 AI 摘要的 API Key、Base URL、Model |
| 清除缓存 | 清理图片缓存 |
| 检查更新 | 手动检查新版本 |
| 更新日志 | 查看历史版本的发布说明 |

**AI 摘要（可选）**：在「我的 → AI 设置」中填入 OpenAI 兼容接口的 API Key 即可启用，用于把 Issue / PR 浓缩为中文摘要。默认对接 DeepSeek（`https://api.deepseek.com`，模型 `deepseek-chat`），Base URL 和 Model 均可在设置页修改为其他 OpenAI 兼容服务。不配置则该功能不生效，不影响其他功能。

**应用更新**：进入主页后会自动检查新版本，也可在设置中手动检查。更新检查访问 Gitee 公开 Release，API 被限流时自动回退 Gitee 网页版发布页；检查不需要登录，不会发送 Gitee 令牌；结果在应用进程内缓存 10 分钟。发现新版本时，Android 直接下载通用 APK。

## 项目结构

```
gitee-mobile-client/
├── lib/
│   ├── ai/               # AI 摘要服务（OpenAI 兼容接口）
│   ├── api/              # Gitee Open API v5 封装（gitee_api.dart）与 HTTP 客户端
│   ├── auth/             # 登录凭证：令牌安全存储、多账号、生物识别锁
│   ├── models/           # Gitee API 数据模型与解析
│   ├── pages/            # 页面：登录、主页、仓库、Issue、PR、设置等
│   ├── providers/        # 应用设置（深色模式、搜索历史）
│   ├── services/         # 更新检查服务
│   ├── theme/            # Material 3 主题
│   ├── utils/            # 深链、外部链接工具
│   └── widgets/          # 通用组件：分页列表、Markdown 渲染、骨架屏等
├── test/                 # 单元测试与组件测试（9 个测试文件）
├── android/              # Android 平台配置（含 gitee:// 深链注册）
├── .github/workflows/    # CI 与 Release 工作流
└── pubspec.yaml          # 依赖与版本号（发布版本以此为准）
```

## 构建与发布

```bash
# Android Debug APK
flutter build apk --debug

# Android Release APK
flutter build apk --release

# Android 分架构 APK / App Bundle
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

产物位置：

- Android APK：`build/app/outputs/flutter-apk/`（Release 通用包为 `app-release.apk`）

**发布新版本**：仓库内置 Release 工作流（见下节），发布时需保证 `pubspec.yaml` 的 `version`（如 `2.0.2+5` 中的 `2.0.2`）与推送的 `v*` 标签一致（如 `v2.0.2`），工作流会在构建前校验两者，不一致将直接失败。客户端的更新检查同样依据该版本号判断是否有新版本。

功能升级后的完整发布流程：

1. 提升 `pubspec.yaml` 的 `version` 并提交；
2. 打标签并推送：`git tag v<版本> && git push origin main v<版本>`；
3. 构建安装包：`flutter build apk --release`；
4. 在 Gitee「发行版」页面创建发行版（选择标签）并上传 APK；

> 注意：Gitee 的发行版与标签绑定，**已发布发行版的标签不要删除或强推**，否则发行版会一并消失。

## 运行测试

```bash
# 静态分析
flutter analyze

# 单元测试与组件测试
flutter test
```

测试覆盖 API 客户端、Gitee 实体解析、OAuth 流程、深链处理、更新服务、Markdown 渲染、外部链接等模块，共 9 个测试文件。

## CI/CD

仓库内置两套 GitHub Actions 工作流（`.github/workflows/`）：

- **ci.yml**：`push` 时触发。Linux 上执行 `flutter analyze`、`flutter test` 并构建 APK。
- **release.yml**：推送 `v*` 标签（或手动触发）时运行。先校验标签与 `pubspec.yaml` 版本一致，然后构建 Android（通用 / 分架构 APK + AAB），并把这些产物发布为对应版本的 Release。

发布产物统一在仓库的 [Releases](https://gitee.com/yuchen0x1/gitee-mobile-client/releases) 页面下载。

## 常见问题

**需要自建后端服务吗？**
不需要。应用直连 Gitee Open API v5，唯一的外部可选依赖是你在 AI 设置中填写的 OpenAI 兼容摘要接口。

**令牌存在哪里，安全吗？**
令牌保存在系统安全存储（Android Keystore，由 flutter_secure_storage 提供）。从旧版本升级时，明文令牌会自动迁移到安全存储并删除原文件。

**部分操作提示无权限？**
写入类操作（创建 Issue / PR、编辑文件、管理 Webhook 等）要求令牌具备对应权限，请到 Gitee 重新生成令牌并勾选所需 scope。

**更新检查提示失败？**
更新检查只访问 Gitee 公开 Release（Open API 被限流时自动回退 Gitee 网页版发布页），不会访问 GitHub。两者都失败通常是当前网络无法连接 Gitee，可稍后在「我的 → 设置 → 检查更新」重试；检查结果缓存 10 分钟，手动检查会强制刷新。

**搜索结果来自哪里？**
仓库搜索使用 Gitee 网页搜索（so.gitee.com）同款数据源——Gitee Open API v5 的搜索接口存在服务端已知问题（即使令牌有效也可能返回空结果），因此仓库搜索不依赖该接口；用户与 Issue 搜索仍走 Open API v5。搜索为空时也可点击「在 Gitee 网页搜索」跳转网页版验证。

**这个仓库能作为 Dart 包发布到 pub.dev 吗？**
不能。`pubspec.yaml` 已设置 `publish_to: none`，本项目按应用项目维护。

## 致谢

- 设计参考：[GitTouch](https://github.com/pd4d10/git-touch)、[GitNex](https://github.com/gitnex-org/gitnex)、[flutter-GitConnect](https://github.com/TheAlphamerc/flutter-GitConnect)（仅产品与架构参考，未复制代码，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)）。

## 反馈与交流

- 问题反馈：[Gitee Issues](https://gitee.com/yuchen0x1/gitee-mobile-client/issues)
- QQ 交流群：1016190748
- Telegram：<https://t.me/lenmoC>

反馈时请说明使用的版本、运行平台和具体问题，便于更快定位。

## License

本项目基于 [MIT License](LICENSE) 开源发布。分发或二次开发时，请保留源码中的版权与许可声明。
