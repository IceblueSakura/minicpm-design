# MiniCPM iOS 客户端

初版骨架：界面和规则是真的，推理、下载、备份是空实现。最低 iOS 27，用系统控件和 Liquid Glass。架构和推理接口见 [客户端架构](../../docs/11-client-architecture.md)，控件映射见 [平台落地](../../docs/07-platforms.md)。

## 在 Mac 上开始

需要 Xcode 27，它要求 macOS Tahoe 26.6 或更新、Apple 芯片。

1. 打开 `apps/ios/MiniCPM.xcodeproj`。
2. 在 Signing & Capabilities 里选开发团队。`PRODUCT_BUNDLE_IDENTIFIER` 现在是占位的 `dev.icebluesakura.minicpm`。
3. 选 iOS 27 模拟器运行。

这份代码还没用 Xcode 编译过，第一次编译按下面的 [对照清单](#第一次编译时对照) 处理。工程是手写的，`MiniCPM/` 是同步文件夹，加文件不用改工程。

状态用启动参数打开：在 Scheme 的 Arguments 里勾选 `-stub nogpu`、`-stub offline`、`-stub oom`，可以用逗号合并，比如 `-stub offline,oom`。

对话里发这些内容，能走到由模型决定的路径：以“记住”开头、含“查一下”、“提醒我”、“备忘”、“写长点”。

## 结构

| 路径 | 内容 |
|---|---|
| `Packages/MiniCPMCore/` | 状态和规则，不依赖 SwiftUI，能在 Linux 上编译和测试 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/AppModel.swift` | 全部产品规则：运行位置、当前模型、发送、下载、隐私声明 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/Engine.swift` | `Engine`、`ModelStore` 协议，和 Web 的 `apps/web/src/engine/types.ts` 同义 |
| `Packages/MiniCPMCore/Sources/MiniCPMCore/Stub.swift` | 空实现 |
| `MiniCPM/App/` | 入口、根页面、历史列表 |
| `MiniCPM/Chat/` | 对话、输入框、横幅、标题面板、对话详情 |
| `MiniCPM/Onboarding/` | 欢迎、选模型、下载 |
| `MiniCPM/Settings/` | 设置全部页面 |
| `MiniCPM/Shared/Copy.swift` | 把 Core 的类型化状态翻成文案。规则层不写文案 |
| `MiniCPM/Assets.xcassets/*.colorset` | 由 `node tools/tokens.mjs` 生成，不要手改 |

文案以简体中文为源语言，`Localizable.xcstrings` 由 Xcode 在编译时抽取。

## 接入真实引擎

1. 在 `MiniCPMCore` 或单独的包里实现 `Engine` 和 `ModelStore`。官方 `MTMDWrapper` 的对应关系见 [客户端架构](../../docs/11-client-architecture.md#接入真实后端)。
2. 改 `AppModel.stubbed(arguments:)`，或者在 `MiniCPMApp.swift` 里直接构造 `AppModel`。界面不用改。
3. 真实说话输入实现 `DictationService`，放进环境值 `\.dictation`。`isAvailable` 为真时麦克风才出现。

## 在 Linux 上验证 Core

nixpkgs 的 Swift 编译清单时找不到运行库，要给出库路径。swift-testing 捕获错误回溯时在这个工具链上会段错误，和代码无关，所以关掉：

```sh
cd apps/ios/Packages/MiniCPMCore
nix shell nixpkgs#swift nixpkgs#swiftpm -c bash -c '
  S=$(nix eval --raw nixpkgs#swift.outPath)
  export LIBRARY_PATH=$S/lib NIX_LDFLAGS="-L$S/lib" LD_LIBRARY_PATH=$S/lib
  SWT_SWIFT_ERROR_BACKTRACING_ENABLED=0 swift test --scratch-path /tmp/minicpm-core-build'
```

## 第一次编译时对照

SwiftUI 在 Linux 上不能类型检查，App 层只过了语法检查。下面的 API 来自 WWDC26 session 269、第三方整理和 iOS 26 的记忆，没有对着 SDK 核对，第一次编译出错先看这里。

**iOS 27 新增**

| API | 用在 | 不确定的地方 |
|---|---|---|
| `ToolbarItemPlacement.topBarPinnedTrailing` | `ChatView`、`ConversationListView` | |
| `ToolbarItemGroup { }.visibilityPriority(.high)` | `ChatView` | |
| `ToolbarOverflowMenu { }` | `ChatView` | 放在 `if` 里能否作为 `ToolbarContent` |
| `.alert(_:item:) { item in }` | `ConversationListView`、`ChatView` | 标题参数是 `LocalizedStringKey` 还是 `Text`。资料两种都写过 |
| `.confirmationDialog(_:item:titleVisibility:) { } message: { item in }` | `TitleSheet`、`ModelSettings` | `message` 闭包是否带 `item` 参数 |
| `@State` 宏 | 全部视图 | 有默认值的属性不能在 `init` 里再赋值，私有成员初始化器被禁用。`SettingsView`、`ConversationListView`、`TitleSheet` 已写显式 `init` |

**iOS 26 引入**

`glassEffect(_:in:)`、`Glass.regular.interactive()`、`GlassEffectContainer(spacing:)`、`.buttonStyle(.glass)`、`.buttonStyle(.glassProminent)`、`.safeAreaBar(edge:)`、`Button(role: .close) { }`。

**Xcode 生成的符号**

`Color.userBubble`、`.youWave`、`.jadeWave` 来自 `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`。

**其他要留意的**

- Swift 6 严格并发：闭包都标了 `@MainActor`，`CameraPicker.Coordinator` 也是。Xcode 27 的 SDK 注解可能让其中一些多余或不够。
- `Info.plist` 的用途说明写了“默认在这台设备上处理，连接远程服务时发送到你设置的地址”，因为这段文字不能随运行位置变化。
- `AppIcon` 只有占位，没有图片，编译会有警告。
- `toolbarMinimizeBehavior` 没有用。session 里是这个名字，27.0 SDK 改成了 `toolbarMinimizationBehavior`。

**还要在模拟器上看的**

- `.inspector` 在紧凑形态变成 sheet 时的表现。
- 标题面板关闭后再打开设置的时机。
- 输入框在键盘弹出时和 `safeAreaBar` 的配合，以及拖动关键盘。
- 流式回答时 `defaultScrollAnchor(.bottom, for: .sizeChanges)` 是否跟随到底部。
- iOS 27 上 iPhone 可调整窗口，形态判断全部走 `horizontalSizeClass`。

## 现在没有的

- 第一阶段里还没做：恢复 iCloud 备份的欢迎步骤、说话输入、对照原图、定时通知的真实调度、打开时验证、录屏遮盖、空闲释放内存、发热响应。这些设置项能保存，但不产生效果。
- 下阶段的实时、语音回复和全能模型没有实现。`Conversation` 读到不认识的条目会跳过。
- 没有 macOS 目标。`MiniCPMCore` 已声明 macOS 27，加目标时能直接用。
