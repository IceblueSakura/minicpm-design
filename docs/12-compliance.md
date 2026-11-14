# 开发期合规设计要求

本文是开发期按全球发布来做的设计要求，覆盖 iOS 和 Web。账号、品牌授权、正式 Bundle ID、税务、TestFlight 和提审不在这里，见 [首次发布与商店政策](13-release-and-store-policy.md)。

信息截至 2026-11-12，整理公开资料供设计和开发对照，不构成法律意见。标了 **待核实** 的条目要再对官方原文。必须上真机才能确认的行为标 **[待实测]**。

现状按当前仓库核对。下面只用文件和符号，不用会过时的行号。

本文只定规格。改原型或客户端时，新状态要能用查询参数打开，并更新 `states.html` 和 [状态矩阵](05-states.md)。行为以这里和 [隐私设计](08-privacy.md) 为准。

## 前提

这些已经定了，见 [决策记录](10-decisions.md)：

- 不做付费、内购、订阅和广告。
- 不做追踪，不接第三方统计或广告 SDK。
- 端侧推理为主。在线备用默认关闭，用户同意后才开启，关掉后仍可完全离线使用。
- 隐私政策、使用条款、支持页、无障碍说明现在就用占位链接，集中在一处配置。
- 开发期只在个人设备上用免费签名测试。付费开发者计划放到首次发布前。

界面上叫“在线备用（可选）”。规则层的运行位置仍是“这台设备 / 远程”（`local` / `remote`），说的是同一件事，标识不改。

## 先做的三件事

1. **一个配置常量。** 隐私政策、使用条款、支持页、无障碍说明和联系邮箱从同一处读取。发布前只改这一处，并做“关于与法律”页。
2. **在线备用改成同意后才开。** 现在选“远程”会直接切换，切换后用撤销。这不够：开启前要说明发送什么、发给谁，并取得同意。每条走了备用通道的回答都要有标记。关闭后仍可完全离线使用。
3. **按多语言和无障碍来写。** iOS 文案已经集中在 String Catalog，先补 English，权限说明移出工程文件。Web 的中文写在组件里，先加一层 i18n。

其余事项（AI 身份告知、内容反馈、年龄、Privacy Manifest、Web 存储说明）也要在代码里留好位置，见下表。

## P0：开发期必须预留

到发布前再补就要返工。

| 优先级 | 要求 | 界面与文案 | iOS | Web | 现状 | 依据 |
|---|---|---|---|---|---|---|
| P0 | 统一的政策链接 | 所有链接从同一个常量读取：`privacyURL` = `https://example.com/privacy`，`termsURL` = `https://example.com/terms`，`supportURL` = `https://example.com/support`，`accessibilityURL` = `https://example.com/accessibility`，`contactEmail` = `support@example.com`。发布前只改这一处 | 新建 `apps/ios/Packages/MiniCPMCore/Sources/MiniCPMCore/AppLinks.swift`（规则层，便于测试）。界面从 `apps/ios/MiniCPM/Shared/Copy.swift` 引用 | 新建 `apps/web/src/core/config.ts`。`selectors.ts` 和界面只从这里取 | 缺失 | App Store Connect 隐私政策 URL 必填；审核指南 5.1.1(i)；GDPR 第 13 条 |
| P0 | “关于与法律”页 | 设置 → 关于：版本号、隐私政策、使用条款、开源许可（含 MiniCPM 模型许可和字体的 OFL 全文；JetBrains Mono 随安装包发布，首版就要列）、联系与反馈、无障碍说明。欢迎页底部一行“隐私政策 · 使用条款”。没有账号，不强制勾选同意 | `apps/ios/MiniCPM/Settings/SettingsView.swift` 新增“关于”分组；`apps/ios/MiniCPM/Onboarding/OnboardingView.swift` 底部链接 | `apps/web/src/ui/Settings.tsx` 新增“关于”页；`apps/web/src/ui/Onboard.tsx` 底部链接 | 缺失 | 5.1.1(i)；1.2 公开联系方式；模型许可的署名 |
| P0 | 在线备用：默认关、主动开、开前同意 | 开关名“在线备用（可选）”，默认关。首次开启或更换地址时说明：“开启后，当这台设备跑不了时，你发出的文字、图片和文件会发送到 {host} 处理。{host} 由 {运营方} 运营，处理方式见其隐私政策。端侧对话不受影响。”按钮“开启并同意” / “暂不开启”。记下同意的地址和时间；地址变了要重新确认；设置里随时可关 | `AppModel` 已有 `place`、`isRemote`、`sendingOut` 和 `prefs.offlineMode`，还没有同意记录。`setPlace`、欢迎页的 `useOwnServer()`、`ComposerArea.swift` 的“改用远程服务”都是直接切到远程 | `store.ts` 的 `backend` 默认 `'local'`。`obRemote()` 和 `setBackend('remote')` 直接切换，事后用撤销。`Onboard.tsx` 的“连接远程服务”、`Banner.tsx` 的“改用远程服务”都要先经过同意页。设置在 `Settings.tsx` 的“运行位置” | 部分 | 5.1.2(i)（含第三方 AI）；GDPR 第 6、13 条；CCPA 收集时告知 |
| P0 | 每次使用备用通道都可见 | 回答下方显示“经 {host} 处理”，离线也能读给读屏。发送前输入框旁显示“将发送到 {host}”。联网记录里每条备用请求列出时间、目的地、发送了什么类型的内容 | 切换运行位置时 `AppModel` 会写入 `PlaceMark`，`ThreadView.swift` 能显示“从这里开始……”。还要把标记下到每条回答，并在 `ComposerArea.swift` 发送前显示目的地 | `Head.tsx` 在标题显示“本机 / 远程”，`Inspector.tsx` 显示 host。还要下到每条消息 | 部分 | 5.1.2(i)；EU AI Act 第 50 条的透明度精神；[隐私设计](08-privacy.md) 的承诺 |
| P0 | 完全离线可用 | 离线模式保留。离线时端侧功能可用，联网搜索和在线备用显示“离线中，未发送”。模型下载完成后不依赖任何服务器 | `Prefs.offlineMode`。离线时远程不发送，本机仍可用 | `Banner.tsx` 的离线提示；`prefs.offlineMode` 同样优先于远程 | 已有 | 审核指南 2.1（审核设备离线也能用）；隐私承诺 |
| P0 | 模型下载：体积披露与确认 | 下载按钮写大小，空间不够要说。补：下载来源的域名。蜂窝网络下再次确认。可暂停、续传。可以删除模型、收回空间 | `OnboardingView.swift` 写“下载 …”，空间不够会提示。设置里有“只在 Wi-Fi 下下载”、`pauseDownload`、移除模型。等待 Wi-Fi 时可以改用移动网络。还没有下载来源域名 | `Onboard.tsx` 同样写大小和剩余空间。`Banner.tsx` 有“用移动网络继续” | 已有 | 4.2.3(ii)。来源域名仍要补 |
| P0 | 模型只是数据，功能随版本固定 | 能力开关写在 App 代码里。新模型只能打开当前版本已有的界面。实时入口必须随版本审核，不能因为下载了全能模型才出现。不下载脚本、插件或提示词模板引擎 | `AppModel.can(_:)` 只看当前模型的 `capabilities`。要改成“当前版本支持 ∩ 模型能力” | `selectors.ts` 的 `can()` 同样只看模型的 `caps` | 需调整 | 2.5.2；2.5.19（2026-10 新增，禁止隐藏或审核后才开启的功能） |
| P0 | 告知用户在和 AI 交互 | 新对话空状态和欢迎页写“你在和 AI 模型对话，它可能出错，重要信息请核实”。AI 回答的无障碍标签以“AI 回答”开头 | `Copy.swift`、`ThreadView.swift`。空对话现在有处理位置，没有 AI 身份告知 | `selectors.ts` 的 `privacyLine` 由 `Thread.tsx` 显示。同样只有处理位置 | 缺失 | EU AI Act 第 50(1) 条（2026-08-02 起适用，须在首次交互时以无障碍方式告知） |
| P0 | 内容安全与反馈 | 端侧输入和输出的轻量过滤与拒答文案。回答长按菜单“反馈这条回答”，打开邮件草稿到 `contactEmail`（用户每次主动发送，不建服务器）。体检等场景显示“仅帮助理解，不能替代医生” | 规则放 `MiniCPMCore`。长按菜单在 `ThreadView.swift` | 规则放 `apps/web/src/core/`。菜单在 `ui/menus.tsx` | 缺失 | 1.2（2026-10-16 起明确覆盖 AI 内容生成 App）；1.4.1 医疗。体检提示的范围仍见 [决策记录](10-decisions.md) 待定 5 |
| P0 | 年龄：预留接口与分级依据 | 欢迎流程前预留年龄信号。iOS 用 Declared Age Range，按现有 Service 协议做成可替换的空实现。未成年时默认关闭联网搜索和在线备用。年龄分级问卷要能回答：开放式 AI 对话、联网内容、医疗话题。Web 在使用条款写明适用年龄 | 协议加在 `MiniCPMCore/Services.swift`，和 `SearchService` 一样由 `AppServices` 注入。不要放进 `MiniCPM/Shared/Services.swift`，那里是说话输入和朗读。界面挂在 `OnboardingView.swift`。免费签名下能否返回年龄 **[待实测]** | 使用条款文案，链接来自 `config.ts` | 缺失 | 新版年龄分级（13+ / 16+ / 18+）；德州 SB 2420（2026-06-04 起） |
| P0 | Privacy Manifest | 新增 `PrivacyInfo.xcprivacy`：`NSPrivacyTracking` = false；`NSPrivacyCollectedDataTypes` 为空（目标是“不收集数据”）。按实际调用声明原因。仓库里会看剩余空间、用 UserDefaults 存偏好、读文件时间。接入时再对真实调用，常见原因码是 Disk Space 的 E174.1、UserDefaults 的 CA92.1、文件时间戳的 C617.1 | 新建 `apps/ios/MiniCPM/PrivacyInfo.xcprivacy`。现在没有这份文件 | 不适用 | 缺失 | [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)；[TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest) |
| P0 | 多语言 | iOS 先给 String Catalog 加 English。权限说明放进 `InfoPlist.xcstrings`。Web 把组件里的中文抽到消息表，`lang` 和日期格式跟随语言。政策页每种语言各一份。四语范围不变，见 [文案与多语言](09-i18n-copy.md) | `Localizable.xcstrings` 源语言 `zh-Hans`，460 条键，没有 English。相机、麦克风、相册、语音识别的用途说明写在 `project.pbxproj` 的 `INFOPLIST_KEY_*`，只有中文 | 中文写在 `src/ui/`。`index.html` 是 `lang="zh-Hans"`。`selectors.ts` 用 `toLocaleDateString('zh-Hans')`。设置里的语言列表还没有消息表 | 部分 | 全球发布；各地元数据和政策要用当地语言 |

## P1：首发前完成

| 优先级 | 要求 | 建议 | 落点 | 现状 | 依据 |
|---|---|---|---|---|---|
| P1 | 无障碍达到可申报水平 | 目标申报 VoiceOver、Larger Text（≥ 200%，用 Dynamic Type）、Dark Interface、Differentiate Without Color、Sufficient Contrast、Reduced Motion。Web 以 WCAG 2.2 AA 为目标。`accessibilityURL` 先用占位链接 | iOS 约 15 处 `accessibilityLabel`。Web 约 90 处 `aria-`（含样式表）。`app.css` 已有 `prefers-reduced-motion`。`tools/tokens.mjs` 会检查对比度 | 部分 | [Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)（iOS 26 起在商店展示） |
| P1 | 主题与无障碍标签 | 每个主题都有浅色、深色、增强对比度三套值并通过对比度检查；默认跟随系统外观；深色覆盖首次启动和设置。备用图标只在 iOS、只在用户主动选择时更换，每个都有深色、透明、着色变体 | `tokens/themes/` 和 `tools/tokens.mjs` 生成主题色板、增强对比度值和 `ThemeCatalog`；`SettingsView.swift` 的外观设置 | 色板和检查已完成；界面未接，未在设备上看过 | [Sufficient Contrast](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria/)、[Dark Interface](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria/)；2.3.8；5.2.5 |
| P1 | 本地数据权利 | 已有：清除全部对话、逐条删除记忆、联网记录。补：一键“删除全部数据（含模型与设置）”。导出和导入现在是“这项还没接入”（`notYet()` / 未连接的 `ArchiveService`）。隐私政策写明数据只在本机、怎么删除、在线备用的运营方和联系方式 | iOS `SettingsView.swift` 的 `PrivacySettings`。Web `Settings.tsx` 的隐私分组 | 部分 | GDPR 第 15、17、20 条；CCPA 删除权 |
| P1 | Web 存储与 cookie 说明 | 只用 localStorage（现在）、以后的 IndexedDB / OPFS 保存用户要求的功能数据（对话、设置、模型），不设标识符、不做统计时，属于“严格必要”，不需要 cookie 同意横幅，在隐私政策里说明即可。一旦加统计或错误上报，就要先做同意 | `apps/web/src/core/persist.ts` 的 `minicpm.state.v1`。导航在 `ui/Nav.tsx` | 已符合 | ePrivacy 第 5(3) 条；[EDPB 2/2023](https://www.edpb.europa.eu/documents/guideline/guidelines-22023-on-technical-scope-of-art-53-of-eprivacy-directive_en)；[ICO 严格必要例外](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/what-are-the-exceptions/) |
| P1 | 导出内容带机器可读的 AI 标记 | 导出的对话文件里加 `generator`（MiniCPM 和模型名）、`ai_generated: true`。以后生成图片或音频时加元数据 | 和导出一起做。格式仍见 [决策记录](10-decisions.md) 待定 8 | 缺失 | EU AI Act 第 50(2) 条（新系统 2026-08-02 起；已有系统宽限到 2026-12-02） |
| P1 | iCloud 备份说明 | 已有开启和删除确认。说明写清“存在你自己的 iCloud，开发者看不到” | `SettingsView.swift` 的“备份与迁移” | 已有 | 隐私营养标签：Apple 收集的数据不需要开发者申报 |
| P1 | 场景 / Agent 分发 | 首发只做内置场景。开放用户发布就是 UGC，要过滤、举报、屏蔽和联系方式 | [决策记录](10-decisions.md) 待定 2 | 未开始 | 1.2、4.7 |
| P1 | 账号删除 | 现在没有账号，不适用。以后加账号就必须在 App 内提供删除 | — | 不适用 | 5.1.1(v) |

## 在线备用的同意流程

和 [信息架构](03-structure.md#运行位置)、[隐私设计](08-privacy.md#在线备用) 是同一套规则。

1. **默认离线、默认端侧。** 安装后不需要网络账号。下载完模型即可完全离线使用。在线备用默认关闭。
2. **主动开启时说明。** 说明页写清三件事：发送什么（这次对话的文字、附加的图片和文件）、发给谁（{host} 和运营方，并链接其隐私政策）、什么时候发（只在这台设备跑不了，或用户选择走备用时）。按钮是“开启并同意”和“暂不开启”。
3. **每次发送都可见。** 输入框旁显示“将发送到 {host}”。回答下方显示“经 {host} 处理”。联网记录保留最近 7 天的目的地和内容类型。
4. **随时撤回。** 关闭开关立即停止发送。更换地址要重新同意。离线模式优先于一切网络发送。切回这台设备时，内容还没继续外发，用提示和撤销即可。

失败时绝不自动换运行位置。横幅上的“改用远程服务”和欢迎页的“连接远程服务”走同一步同意，不能绕过。

同意记录放在规则层，两端一起改：iOS 在 `AppModel`，Web 在 `store.ts`。字段至少是 host 和同意时间。

## 隐私营养标签：争取“不收集数据”

Apple 的定义：把数据传出设备，并以可读形式保存超过处理请求所需的时间，才叫“收集”。只在本机处理的不算。IP 或令牌随请求发送但不保留，或服务器处理完立即丢弃，也不用申报。用户自愿开启的功能如果会收集，同样要申报。

目标是 App Store 的隐私营养标签选“Data Not Collected”（不收集数据）。下面任何一行做不到，就不能再这么填。

| 数据流 | 是否算收集 | 会打破“不收集数据”的情况 | 建议 |
|---|---|---|---|
| 端侧推理、记忆、对话历史 | 不算，只在本机 | 无 | 保持 |
| 模型下载（Hugging Face / 自有 CDN / Apple 托管） | 通常不算 | 自有下载服务器记录并保留 IP 或设备信息 | 下载服务器不留存访问日志，或只做短期安全用途并单独评估 |
| 在线备用（开发者或合作方的服务器） | 处理完即丢弃就不算 | 服务器保存对话、图片或日志 | 要求运营方零留存，并写进隐私政策。做不到就申报“用户内容”等类型 |
| 用户自填的第三方服务 | 由用户选择的第三方处理 | 开发者把内容转经自己的代理 | 直连用户填写的地址。说明页提示对方的隐私政策 |
| 联网搜索 | 取决于搜索服务 | 搜索服务保留搜索词（这算开发者的第三方合作方） | 选不留存的搜索接口，或申报“搜索历史” |
| 崩溃与诊断 | Apple 自带的不需开发者申报 | 接入 Sentry、Firebase Crashlytics 等第三方 SDK | 只用 Xcode Organizer / MetricKit。设计里的崩溃报告仍是每次询问，不接第三方 SDK |
| 更新检查 | 只发版本号且不保留就不算 | 服务器记录 IP 和版本做统计 | 检查接口不留存，或改用 App Store 自身更新 |
| 反馈 | 用户每次从邮件主动发出，可属于可选申报 | 做成 App 内自动上传的反馈表单 | 用邮件草稿；或满足 Apple 的“可选披露”全部条件 |
| iCloud 备份 | 存在用户自己的 iCloud。Apple 收集的数据不需开发者申报 | 开发者服务器读取或镜像备份 | 只用用户的私有容器 |
| 匿名使用统计 | 现在没有发出任何请求 | 打开后真的上报，即使用户同意了 | 设置保留、默认关闭。真正发送前要重新评估，不能为了这个去接统计 SDK |

设置里的“匿名使用统计”和“崩溃报告”因此先留着，不删除。它们在真正发出请求之前，不改变上面的目标。

## 不适用的条款

付费相关（3.1.1、3.1.3、美区外链抽成）和追踪相关（ATT、`NSPrivacyTrackingDomains`）在“不付费、不追踪”的前提下都不适用。`NSPrivacyTracking` 设为 false 即可。以后加入收费、广告或统计时再评估。

## 个人设备测试

开发期可以在自己的设备上安装，只用免费的个人团队签名。不能用 TestFlight，也不能给别人安装。现在的签名团队是个人团队，Bundle ID `dev.icebluesakura.minicpm` 只给这个阶段用，正式 ID 见 [首次发布](13-release-and-store-policy.md)。

| 限制 | 内容 |
|---|---|
| 描述文件 | 7 天，到期后从 Xcode 重新安装 |
| 设备与应用 | 最多 3 台设备。每台最多 3 个由你签名的 App。每 7 天最多新建 10 个 App ID，扩展也各占一个 |
| 分发 | 不能用 TestFlight，也不能把包装给别人 |

免费个人团队和付费会员的能力不一样。下表来自 Apple 的 [iOS 能力表](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)。表上没写的两项单独标了。

| 能力 | 免费个人团队 | 开发期做法 |
|---|---|---|
| iCloud（CloudKit、文档、键值） | 不可用 | iCloud 备份测不了。用本地文件模拟，`BackupService` 保持可替换 |
| Apple 托管 Background Assets | 不可用 | 依赖付费会员和 App Store Connect。开发期用 URLSession 从 Hugging Face 或自有地址下载，仍走同一个 `ModelStore` |
| 推送通知 | 不可用 | 本项目不需要远程推送。本地下载完成通知可用 |
| Increased Debugging Memory Limit、Extended Virtual Addressing | 不可用 | 真机跑大模型时内存上限可能更低。`increased-memory-limit` 不在能力表里，免费签名能否生效 **[待实测]**。先用轻量看图模型 |
| Sensitive Content Analysis | 不可用 | 若打算用系统框架过滤敏感图片，要等付费账号。开发期先做文字过滤 |
| Sign in with Apple、内购、Apple Pay、Game Center | 不可用 | 本项目不用 |
| App Groups、Background Modes、Keychain Sharing、Data Protection | 可用 | 分享扩展、后台下载、应用锁可以照常做 |
| Declared Age Range | 待实测 | 能力表没有列出。先做成可替换的空实现，真机能否返回结果 **[待实测]** |

## 相关

- 行为规则：[隐私设计](08-privacy.md)、[信息架构](03-structure.md#运行位置)
- 文案：[文案与多语言](09-i18n-copy.md)
- 发布前清单和国区：[首次发布与商店政策](13-release-and-store-policy.md)
- 下载渠道在各端的差异：[平台落地](07-platforms.md#模型下载与内存)
