# MiniCPM iOS 客户端

初版骨架：界面和规则是真的，推理、下载和各项系统服务是空实现。最低 iOS 27，用系统控件和 Liquid Glass。架构和推理接口见 [客户端架构](../../docs/11-client-architecture.md)，控件映射见 [平台落地](../../docs/07-platforms.md)。

当前阶段重点完善 Web、iOS、macOS 的 UI/UX 设计与客户端骨架，全球 App Store（首发暂不含中国大陆）为首个原生发布目标。端侧推理后端选型与实验独立收敛在 [`backend/`](../../backend/README.md)，双轨分工见 [项目路线](../../docs/14-roadmap.md)。

## 在 Mac 上开始

需要 Xcode 27，它要求 macOS Tahoe 26.6 或更新、Apple 芯片。

1. 打开 `apps/ios/MiniCPM.xcodeproj`。
2. 开发团队已设为个人团队 `6NY7CFCMUH`（Iceblue Sakura (Personal Team)），自动签名。换人开发时在 Signing & Capabilities 里改成自己的团队。`PRODUCT_BUNDLE_IDENTIFIER` 现在是占位的 `dev.icebluesakura.minicpm`。
3. 选 iOS 27 模拟器运行。

已在 Xcode 27.2、iOS 27.2 模拟器上编译运行过，iPhone 和 iPad 都走过主要流程。真机没跑过。工程是手写的，`MiniCPM/` 是同步文件夹，加文件不用改工程。在模拟器上不用选开发团队。

构建设置对齐 Xcode 27.2 新建工程的模板：Swift 6 语言模式，App 目标默认隔离在 `MainActor`，打开 Approachable Concurrency 和 Member Import Visibility。`MiniCPMCore` 在 `Package.swift` 里打开同样的语言特性（`NonisolatedNonsendingByDefault`、`InferIsolatedConformances`、`MemberImportVisibility`），但不默认隔离到 `MainActor`，需要的类型自己标。

状态用启动参数打开：在 Scheme 的 Arguments 里写 `-stub`，后面跟逗号分隔的名字，比如 `-stub offline,oom`。

| 名字 | 打开的状态 |
|---|---|
| `nogpu`、`offline`、`oom` | 跑不了本机模型、连不上、载入失败 |
| `services` | 接上演示服务，走通搜索、定时通知、备份、导出导入和解锁。默认是未接入，点了提示“这项还没接入” |
| `backupfull`、`signedout`、`nocloud` | 配合 `services`：iCloud 空间不够、没有登录、没有 iCloud |
| `capture` | 配合 `services`：正在录屏，打开“录屏时遮盖内容”后遮盖 |
| `hot` | 配合 `services`：设备发热。只写入 `AppModel.thermal`，还没有界面 |
| `lockfail` | 配合 `services`：验证总是失败，停在锁定页 |

对话里发这些内容，能走到由模型决定的路径：以“记住”开头、含“查一下”、“提醒我”、“备忘”、“写长点”。

## 结构

| 路径 | 内容 |
|---|---|
| `Packages/MiniCPMCore/` | 状态和规则，不依赖 SwiftUI，用 `swift test` 测试 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/AppModel.swift` | 全部产品规则：运行位置、当前模型、发送、下载、隐私声明 |
| `Packages/MiniCPMCore/Tests/MiniCPMCoreTests/FlowRecoveryTests.swift` | 草稿恢复、附件归属/回收、消息重试与重新生成、备份离线/取消/恢复的回归 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/Engine.swift` | `Engine`、`ModelStore` 协议，和 Web 的 `apps/web/src/engine/types.ts` 同义 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/Services.swift` | 其余系统服务的协议、未接入实现和演示实现 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/Stub.swift` | 推理和下载的空实现 |
| `MiniCPM/App/` | 入口、根页面、历史列表 |
| `MiniCPM/Chat/` | 对话、输入框、横幅、标题面板、对话详情 |
| `MiniCPM/Onboarding/` | 欢迎、选模型、下载 |
| `MiniCPM/Settings/` | 设置全部页面 |
| `MiniCPM/Shared/Copy.swift` | 把 Core 的类型化状态翻成文案。规则层不写文案 |
| `MiniCPM/Assets.xcassets/*.colorset`、`Themes/` | 由 `node tools/tokens.mjs` 生成，不要手改。`Themes/` 是六套主题的内容层颜色，带增强对比度外观 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/ThemeCatalog.generated.swift`、`MiniCPM/Shared/ThemeNames.generated.swift` | 主题注册表和显示名，同样由工具生成。界面还没接主题 |

## 界面语言

支持 English、简体中文、繁體中文（台灣）、繁體中文（香港）。以简体中文为源语言，界面文案在 `MiniCPM/Localizable.xcstrings`，系统权限说明在 `MiniCPM/InfoPlist.xcstrings`，由 Xcode 抽取和编译，不引入第三方本地化框架。

默认跟随系统；“设置 → 通用 → 界面语言”打开系统的 App 设置。语言选择交给 iOS，不在应用里另存偏好或只覆盖 SwiftUI 的 `locale`。回答语言是另一项偏好，不自动翻译模型回答、用户内容或已有文件名。

普通界面文字直接用 SwiftUI 的本地化初始化器；提前生成的文案用 `String(localized:)`。同一中文在不同动作里含义不同时，用带 `defaultValue` 和注释的 `LocalizedStringResource` 区分，例如欢迎页的 Continue 与暂停下载后的 Resume。英文数量的复数变化放在 String Catalog，同一句的两个数量各自使用 substitution；容量和时长用 Foundation 格式化后插入整句。

新增文案后在 Mac 上构建一次，查看 Catalog 的新增、过期和待翻译条目。按 [文案与多语言](../../docs/09-i18n-copy.md) 的术语表翻译，特别检查占位符类型、远程目的地和 iCloud 备份的隐私分支。译文由 `agy --model gemini-3.8-flash-high` 生成，繁体两列仍需母语审校。

## 接入真实引擎

以下是选型后的接线参考，当前不按此直接启动后端实现。

1. 在 `MiniCPMCore` 或单独的包里实现 `Engine` 和 `ModelStore`。官方 `MTMDWrapper` 的对应关系见 [客户端架构](../../docs/11-client-architecture.md#接入真实后端)。
2. 改 `AppModel.stubbed(arguments:)`，或者在 `MiniCPMApp.swift` 里直接构造 `AppModel`。界面不用改。
3. 真实说话输入实现 `DictationService`，放进环境值 `\.dictation`。`isAvailable` 为真时麦克风才出现。

## 接入系统服务

规则已经写在 `AppModel` 里，接入时只写实现，传给 `AppServices`，再把它传给 `AppModel`。没传的项保持未接入。

| 协议 | 对应功能 | 实现时用 | 已有的规则 |
|---|---|---|---|
| `SearchService` | 联网搜索 | 待定的搜索接口 | 用户点了才发，离线模式不发，真的发出才写联网记录 |
| `SystemActionService` | 定时通知、备忘录 | `UNUserNotificationCenter`，备忘录的写入方式待定 | 成功后卡片才变成已添加 |
| `BackupService` | iCloud 备份 | CloudKit 或 iCloud Drive，待定 | 就地确认才开启，失败只在设置里显示，恢复不覆盖，声明跟着变 |
| `ArchiveService` | 导出、导入 | 文件格式待定 | 不含临时对话，导入跳过重复、可撤销，读不了时现有对话不变 |
| `AppLockService` | 打开时验证 | `LAContext` | `isAvailable` 为假时不锁定，超过“自动锁定”的时间才锁 |
| `DeviceConditionService` | 录屏、发热 | `sceneCaptureState`、`ProcessInfo.thermalState` | 录屏时遮盖，包括面板 |

联网搜索的结果现在不进回答：接真实引擎时把它加进 `GenerateRequest`。

## 验证

只在 macOS 上构建，需要 Xcode 27。

```sh
cd apps/ios
(cd Packages/MiniCPMCore && swift test)
xcodebuild -scheme MiniCPM -destination 'platform=iOS Simulator,name=iPhone 18 Pro' analyze
```

流程回归不依赖真实后端：普通草稿重启可恢复，临时附件离开即回收；异步导入固定目标对话；图片准备失败不生成无图回答，原消息可重试；重试旧消息和重新生成不会吞掉后续失败消息；备份恢复同时合并记忆，离线不调用恢复/删除服务，关闭上传后立即撤销也能继续。附件测试使用各自的临时目录，不触碰应用数据。上述 Swift 流程及选择器实际行为仍需在 macOS 上运行验证 **[待实测]**。

模拟器可用启动参数指定语言和地区，例如 `-AppleLanguages '(zh-Hant-HK)' -AppleLocale zh_HK`。走查欢迎、模型选择、空白对话、标题面板、设置和异常横幅；英文要检查长文案，四语都检查明暗模式和辅助功能字号。香港文案应出现“私隱”“咪高風”，不能误用台湾资源。

通过 SSH 构建真机版本时，登录钥匙串是锁着的，签名会报 `errSecInternalComponent`。在 Mac 本机构建，或者先 `security unlock-keychain`。

## 模拟器上看过的

- SDK 的 API 第一次编译就全部通过，原来列的不确定项都不用改。
- `.primary`、`.secondary` 放在 `Button` 的标签里会跟随强调色。列表行要用 `Color.primary`、`Color.secondary`。
- 系统的主按钮文字是白色，深色模式下配浅绿看不清。用 `prominentButton()`、`prominentGlassButton()`，文字走 `OnJade`。
- 超出 `safeAreaBar` 范围的视图能显示，但点不到。轻提示所以放在 `ChatView` 上，用输入区高度定位。
- `Section` 上的修饰符会落到每一行。`.sheet`、`.fileImporter` 要放在 `Form` 上。
- 常规字号下，长标签的 `Picker`、`LabeledContent` 会把值挤到单独一行，用 `ActionRow` 组织说明和操作；辅助功能字号下用 `AnyLayout` 纵向排列。联网搜索的长选项改用原生 `navigationLink` Picker，避免菜单值被截断。
- 辅助功能字号下，长横幅放进对话的滚动内容，不能固定在底栏里把导航和输入区顶出屏幕。模型行的操作也要纵排，避免 `Download` 被拆成碎词。
- 手机上 `List` 的选中项一变就推出详情，所以停在列表时选中项是空。
- `URL.path()` 默认做百分号编码，数据目录 `Application Support` 带空格，文件接口拿到的路径就不存在。读文件用 `path(percentEncoded: false)`。
- 不透明的视图只遮住画面，被遮住的内容仍在无障碍树里，读屏能读、能点。给 `NavigationSplitView` 外面加 `accessibilityHidden` 也拿不掉它，所以锁定时不构建内容。

**还没在模拟器上看的**

- `.inspector` 在紧凑形态变成 sheet 时的表现。
- 拖动关键盘时输入框的表现。
- iOS 27 上 iPhone 可调整窗口，形态判断全部走 `horizontalSizeClass`。
- 相机、相册和文件选择。模拟器走查没有碰这些。

**其他要留意的**

- `Info.plist` 的用途说明写了“默认在这台设备上处理，连接远程服务时发送到你设置的地址”，因为这段文字不能随运行位置变化。
- `AppIcon` 只有占位，没有图片，编译会有警告。
- `toolbarMinimizeBehavior` 没有用。session 里是这个名字，27.0 SDK 改成了 `toolbarMinimizationBehavior`。

## 现在没有的

- 第一阶段里还没做：恢复 iCloud 备份的欢迎步骤、对照原图、空闲释放内存、发热响应。这些设置项能保存，但不产生效果。
- 说话输入、联网搜索、定时通知、备忘录、备份、导出导入、打开时验证和录屏遮盖有接口和规则，真实实现还没有。
- 锁定时不构建对话内容，挂在对话上的标题面板和对话详情应随之关闭，还没在模拟器上走查。设置在锁定前关闭；导出后的分享面板挂在根视图上，锁定时还在。
- 下阶段的实时、语音回复和全能模型没有实现。`Conversation` 读到不认识的条目会跳过。
- macOS 客户端将在 `apps/macos/` 下拆分为独立工程，直接共用 `MiniCPMCore`（已声明 macOS 27）。
