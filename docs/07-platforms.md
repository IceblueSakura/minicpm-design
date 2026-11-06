# 平台落地

目标平台：iOS / iPadOS、Android、macOS、Web，Windows 和 Linux 目前主要由 Web 交付。本文说明同一份设计在各端怎么落地。平台事实核对于 2026-11-05，当时最新是 iOS / macOS 27.2、Android 17（API 37）。开发开始时再核对一次。

事实的把握度这样标：无标记为已读官方文档；**[推断]** 是从文档推出的结论；**[待实测]** 必须在真机上确认，现阶段不做，进入开发前处理。

## 总原则

**外壳归平台，语义归产品。**

| 由平台决定 | 由产品决定 |
|---|---|
| 导航结构的控件、转场、手势 | 页面之间的关系 |
| 列表、开关、菜单、弹窗的样式 | 选项的内容和顺序 |
| 字体、字号、圆角、阴影 | 文字层级 |
| 背景和文字的系统颜色 | 模型、你、采集、等待四个角色色 |
| 权限弹窗、生物识别、分享 | 触发时机和说明文案 |

原型回答“有什么、在什么状态、说什么”。平台回答“长什么样”。

## 四端一览

| | iOS / iPadOS | Android | macOS | Web |
|---|---|---|---|---|
| UI | SwiftUI | Jetpack Compose，Material 3 | SwiftUI，必要时 AppKit | 原型样式 |
| 设计系统 | Liquid Glass | Material 3 Expressive | Liquid Glass | 本项目 |
| 紧凑形态 | iPhone、iPad 窄分屏 | 宽 < 600dp 或高 < 480dp | 窄窗口 | 窄窗口、手机浏览器 |
| 展开形态 | iPad 全屏 | 宽 ≥ 840dp | 默认 | 默认 |
| 这台设备 | 本机引擎 | 本机引擎 | 本机引擎 | 浏览器（WebGPU） |
| 远程服务 | 可切换 | 可切换 | 可切换 | 可切换 |

## 导航

原型的紧凑形态是“左上角菜单打开抽屉”，这是 Claude、ChatGPT、Grok 的做法，它们都自己实现了这层。系统自带的结构能得到同样的层级，还白拿返回手势和无障碍：

| 平台 | 建议 | 说明 |
|---|---|---|
| iOS / iPadOS | `NavigationSplitView`，`preferredCompactColumn` 设为详情 | 紧凑时打开就是对话，返回到历史。宽屏自动变成侧栏 |
| macOS | `NavigationSplitView` 加 `.inspector` | 对应侧栏、对话、详情栏 |
| Android | `ListDetailPaneScaffold`，紧凑时先显示详情 | Material 已不推荐导航抽屉，改用展开式 rail。历史不是导航目的地，用列表详情更贴切 |
| Web | 原型结构 | 抽屉 |

这和“模仿那三家”有一点差别：历史从左侧滑出变成返回到上一层。层级相同，左上角位置相同。见 [决策记录](10-decisions.md) 待定项。

| 原型 | iOS | Android | macOS |
|---|---|---|---|
| 底部面板 | `.sheet` 加 `presentationDetents` | `ModalBottomSheet` | 弹出菜单或 `.popover` |
| 弹出菜单 | `Menu` | `DropdownMenu` | `Menu` |
| 长按操作 | `.contextMenu` | 长按加菜单 | 右键 `.contextMenu` |
| 设置 | `Form` 进 `NavigationStack` | 列表进详情 | `Settings` 场景，独立窗口，`⌘,` |
| 确认 | `.confirmationDialog` | `AlertDialog` | `.confirmationDialog` |
| 换模型的轻量确认 | 系统菜单不能就地展开，手机用底部面板内的说明行，iPad 和 macOS 用 `.confirmationDialog` 贴着选择器 | 底部面板内的说明行 | `.confirmationDialog` 贴着选择器 |
| 提示和撤销 | 自定义轻提示 | `Snackbar` | 自定义轻提示 |
| 搜索 | `.searchable` | `SearchBar` | `.searchable` |

## 颜色

| Token | Web | iOS / macOS | Android |
|---|---|---|---|
| `chrome` `surface` `raised` `sunken` | 使用 | 系统背景色 | M3 surface 角色 |
| `ink` `ink-2` `ink-3` | 使用 | 系统 label 色 | `onSurface` `onSurfaceVariant` |
| `line` `line-2` `control` | 使用 | 系统分隔色 | `outlineVariant` `outline` |
| `jade` | 使用 | App accent | `primary` |
| `jade-wave` `you-wave` `overlap` `cinnabar` `amber` 及其浅色 | 使用 | Asset Catalog 自定义色 | 扩展色，`CompositionLocal` 提供 |

**iOS / macOS**：内容偏单色时可以用品牌色作 accent。着色只给主操作和状态，不给多个控件上色，少用自定义工具栏背景。玻璃上只有实时主按钮和结束按钮带色。

**Android**：Material 区分品牌一致的静态方案和个性化的动态方案，语义色可以固定。建议第一版用 token 生成静态方案。动态配色可能把 `primary` 变成接近朱砂的颜色，破坏“朱砂等于采集”的含义。以后可以只让中性色跟随壁纸。

**增强对比度**：iOS 的 Increase Contrast 和 Android 的高对比文字需要额外一组色值，现在还没有定义。

## 实时会话

这是平台差异最大的地方。

### 离开应用

| | 事实 | 设计 |
|---|---|---|
| iOS | 后台提交 Metal 任务会报错，相机后台不可用。`BGContinuedProcessingTask` 的 GPU 能力要用户发起并检查设备支持，不能作为 iPhone 基线 **[推断]** | 离开即暂停 |
| Android | 麦克风和相机前台服务要在应用可见时启动，之后可以继续。Android 17 对不可见进程有内存上限，后台音频要有 while-in-use 能力的前台服务 | 第一版离开即暂停，与 iOS 一致。语音在后台继续留作后续选项 |
| macOS | 没有这类限制 **[推断]**。要防止 App Nap，用 `beginActivity` | 继续运行，菜单栏显示状态 |
| Web | 页面可见性决定资源 | 继续运行；手机浏览器切走时按暂停处理 |

为什么 Android 第一版也暂停：隐私规则统一，模型驻留在后台时被内存上限杀掉的风险未知。

### 系统活动

用户离开应用时，系统级入口接替应用内的状态条。

| | 控件 | 显示 |
|---|---|---|
| iOS | Live Activity，灵动岛 | 已暂停、对话名、回到 MiniCPM |
| Android | 进行中通知，Live Update（`setRequestPromotedOngoing`） | 同上。不要用 `CallStyle`，它专用于通话 |
| macOS | `MenuBarExtra` | 状态灯、时长、麦克风、结束 |
| Web | 标题前缀，`mediaSession.setMicrophoneActive` / `setCameraActive`（Chrome、Safari） | 正在实时 |

系统活动里不显示转写内容。

### 打断信号

| 原型状态 | iOS | Android | macOS | Web |
|---|---|---|---|---|
| 来电 | `AVAudioSession.interruptionNotification`。iOS 27 新代码用 `didBecomeInactiveNotification` 和 `resumptionRecommendationNotification`，因为结束事件可能不到 | 失去音频焦点，通话状态 | 输入设备被占 | `track` 的 `mute` 事件 |
| 离开应用 | `scenePhase` | 生命周期 `ON_STOP` | 不适用 | `visibilitychange` |
| 耳机断开 | `routeChangeNotification`，`oldDeviceUnavailable` | `ACTION_AUDIO_BECOMING_NOISY` | 默认设备变化 | `devicechange` |
| 被系统回收 | 下次启动恢复 | `ApplicationExitInfo` | 同左 | 不适用 |

iOS 和 Android 上用户撤销权限时系统会结束进程 **[待实测]**，走“被系统回收”路径，所以没有单独的暂停状态。

### 发热和电量

| 原型等级 | iOS `thermalState` | Android `getThermalHeadroom` | Web |
|---|---|---|---|
| 正常 | `.nominal` `.fair` | < 0.75 | 正常 |
| 放慢 | `.serious` | ≥ 0.75 | 用 Compute Pressure（仅桌面 Chrome、Edge），否则看响应延迟 |
| 只用声音 | `.serious` 持续 2 分钟 | ≥ 0.9 | 同上 |
| 暂停 | `.critical` | ≥ 1.0 | 不适用 |

阈值是起点，要用实机数据调 **[待实测]**。Android 的 headroom 最多 10 秒查一次，部分设备状态可能一直是 NONE，要配合响应延迟判断。

低电量模式：iOS `isLowPowerModeEnabled`，Android `PowerManager.isPowerSaveMode`。

### 屏幕共享

| | 能力 | 第一版 |
|---|---|---|
| macOS | `SCContentSharingPicker`（14+） | 提供，用系统选择器 |
| Web 桌面 | `getDisplayMedia` | 提供 |
| Android | `MediaProjection`，每次重新同意，可选单个应用，状态栏有提示，锁屏时自动停止 | 不提供。之后评估，风险是模型在后台的内存 |
| iOS | iOS 27 起 ScreenCaptureKit 取代 ReplayKit 选择器，不再需要广播扩展，后台全屏要 `screen-capture` 和 `audio` 模式 | 不提供 |
| Web 手机 | Chrome 和 Firefox Android 不支持 | 不提供 |

iOS 的关键矛盾：共享其他应用的屏幕时 MiniCPM 在后台，后台不能用 GPU，所以端侧模型跑不了 **[推断]**。只有连接远程服务时才可能。这影响“陪我打一局”这类场景在手机上的定位，手机上这些建议已隐藏。

### 无障碍

| 需求 | iOS / macOS | Android | Web |
|---|---|---|---|
| 播报状态 | `AccessibilityNotification.Announcement` | `LiveRegionMode.Polite` | `aria-live` |
| 转写 | 只播报整句，不逐字 | 同左 | `role="log"` |
| 字体放大 | Dynamic Type，body 14–53pt | 最高 200%，非线性 | 浏览器缩放 |
| 控制条放大 | 隐藏文字留图标，用 Large Content Viewer | 换行成两排 | 换行 |
| 最小目标 | 44pt | 48dp | 44px（WCAG 要求 24px） |

全双工和读屏有天然冲突：读屏的声音和模型的声音会叠在一起，也可能被模型听到。需要真人测试 **[待实测]**。

## 模型下载与内存

| | iOS | Android | Web |
|---|---|---|---|
| 渠道 | Background Assets，Apple 托管上限 200GB | Play AI pack 单包 ≤ 1.5GB，累计上限文档有出入，6GB 模型大概率走自有 CDN | 自有 CDN，存进浏览器的站点存储（OPFS） |
| 后台下载 | 系统托管 | 用户发起的数据传输任务（`setUserInitiated`） | 不适用 |
| 移动网络 | `allowsExpensiveNetworkAccess` | 超过 200MB 走确认 | 不适用 |
| 审核 | 4.2.3 要求首次启动下载前披露大小，欢迎流程已满足 | 禁止下载可执行代码，模型属于数据 **[推断]** | 不适用 |

换模型时要先释放旧模型再载入新模型，等待时间因设备差别很大。原型里的秒数是占位，要用实测数据换掉 **[待实测]**。

内存：iOS 有 `increased-memory-limit` 权限（部分机型），用 `os_proc_available_memory` 判断余量，不要缓存这个值。Android 17 按设备内存设上限，超限退出原因含 `MemoryLimiter:AnonSwap`。

这是最大的技术风险：6GB 级模型能否在 8GB 手机上和全双工一起运行。**最便宜的验证**是在目标机型上加载模型跑 10 分钟实时，记录是否被杀和发热曲线。结果决定“全能”模型在手机上的推荐条件。这项验证已延后。

浏览器有同样的问题：WebGPU 下全能模型和全双工能跑到什么程度 **[待实测]**。跑不动时，浏览器只提供轻量模型，这和“视觉模型没有实时”是同一个状态，不需要新设计。

## 系统入口

原型里没有，原生端要做。这些入口让“处理一件小事”更快。

| 入口 | iOS | Android | macOS | Web |
|---|---|---|---|---|
| 分享进来 | Share Extension | `ACTION_SEND` | Share Extension | Web Share Target |
| 快速开始 | App Intents，Action Button，控制中心 | 快捷方式，快捷设置磁贴 | 全局快捷键，菜单栏 | 不适用 |
| 通知 | 见隐私设计 | 同左 | 同左 | 不适用 |
| 小组件 | 开始语音、看东西 | 同左 | 不做 | 不适用 |

分享进来的流程：选图 → 打开新对话，附件已就位，光标在输入框。不用在分享面板里完成对话。

## macOS 特有

- 菜单栏完整：文件（新对话、导出）、编辑、显示（侧栏、详情）、对话（实时、停止）、窗口、帮助。
- 快捷键沿用原型：`⌘N` 新对话，`⌘K` 搜索，`⌘B` 侧栏，`⌘I` 详情，`⌘,` 设置，`Esc` 停止。实时中 `⌥M` 麦克风，`⌥V` 画面，`⌥F` 定格，`⌥H` 先听我说。
- 关闭窗口默认留在菜单栏，设置里可改。
- 拖放文件到窗口和 Dock 图标。

## Web 特有

- 原型就是实现参考，token 直接用。
- 手机浏览器：`interactive-widget=resizes-content`，`--safe-*` 处理安全区。
- 设置里隐藏平台没有的项：开机启动、应用锁、加密保存、禁止截屏。
- “这台设备”指这个浏览器，模型用 WebGPU 运行。Windows 和 Linux 走同一条路径，切换规则见 [信息架构](03-structure.md#运行位置)。
- 模型存在站点存储里，要申请持久存储（`navigator.storage.persist()`），否则空间紧张时可能被浏览器清掉。被清掉后走“还没有这个模型”的路径。
- “断网也能用”要求页面本身能离线打开，所以 Web 要做成 PWA，用 Service Worker 缓存页面。
- 模型跑在标签页里，关闭标签页就停了。实时中关闭时用系统的离开确认。桌面标签页切走后的运行情况 **[待实测]**。

## 设置项的平台差异

| 设置 | iOS | Android | macOS | Web |
|---|---|---|---|---|
| 界面语言 | 跳到系统的应用语言 | 同左，`LocaleManager` | 系统设置 | 应用内 |
| 外观 | 跟随系统，可不做 | 同左 | 同左 | 应用内 |
| 文字大小 | 跟随系统，删除此项 | 同左 | 应用内 | 应用内 |
| 禁止截屏 | **没有公开 API**，改成录屏时遮盖（`sceneCaptureState`） | `FLAG_SECURE` | 不适用 | 不适用 |
| 后台隐藏内容 | 进入后台前遮盖 | `setRecentsScreenshotEnabled(false)` | 不适用 | 不适用 |
| 打开时验证 | `LAContext` | `BiometricPrompt` | `LAContext` | 无 |
| 开机时启动 | 无 | 无 | `SMAppService` | 无 |
| 只在 Wi-Fi 下载 | 有 | 有 | 无 | 无 |
| 触感反馈 | 有 | 有 | 无 | 无 |

## 多语言

| | iOS / macOS | Android | Web |
|---|---|---|---|
| 应用内语言 | 系统设置 | `LocaleManager`，`generateLocaleConfig` | 自己实现 |
| 字符串 | String Catalog | 字符串资源 | ICU MessageFormat |
| 复数 | Vary by Plural | `plurals` | ICU |

用词和语言标识见 [文案与多语言](09-i18n-copy.md)。

## Token 到代码

`tokens/` 使用 Design Tokens 社区组（DTCG）的结构。颜色值保留十六进制字符串，方便手改，也是 Style Dictionary 能读的写法。

开发开始时用 Style Dictionary 生成代码，内置 `ios-swift/class.swift` 和 `compose/object` 格式。它对 DTCG 2025.10 的支持还不完整，所以先不用新版的颜色对象写法。

## 交接方式

每个界面交给开发时给这四样：

1. 原型链接，带状态参数。
2. [状态矩阵](05-states.md) 里对应的行。
3. [组件清单](06-components.md) 里的分类：系统、组合或自绘。
4. 本文对应平台的说明。

自绘组件建议先做：双轨波形和实时控制条。这两个决定产品感觉，也最需要在真机上调。

## 参考

- Apple：[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Color](https://developer.apple.com/design/human-interface-guidelines/color)、[Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)、[Running Metal in the background](https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background)、[Capturing screen content on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios)、[Background Assets](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs)、[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Android：[Window size classes](https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes)、[Choosing a color scheme](https://m3.material.io/styles/color/choosing-a-scheme)、[Foreground service restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)、[Android 17 behavior changes](https://developer.android.com/about/versions/17/behavior-changes-all)、[Live updates](https://developer.android.com/develop/ui/views/notifications/live-update)、[MediaProjection](https://developer.android.com/media/grow/media-projection)、[Thermal API](https://developer.android.com/games/optimize/adpf/thermal)、[On-device AI delivery](https://developer.android.com/google/play/on-device-ai)
- Web：[Media Session](https://w3c.github.io/mediasession/)、[Compute Pressure](https://developer.mozilla.org/en-US/docs/Web/API/Compute_Pressure_API)
- Token：[DTCG 2025.10](https://www.designtokens.org/tr/2025.10/format/)、[Style Dictionary DTCG](https://styledictionary.com/info/dtcg/)
