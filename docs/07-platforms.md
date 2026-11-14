# 平台落地

设计范围：iOS / iPadOS、Android、macOS、Windows、Linux 和 Web；Windows 和 Linux 目前主要由 Web 交付。当前只推进 macOS 和 iOS，Android、Windows、Linux、Web 暂停，下面这些平台的内容保留但不再更新；双轨分工与后端实验边界见 [项目路线](14-roadmap.md)。本文说明同一份设计在各端怎么落地。平台事实核对于 2026-11-05，当时最新是 iOS / macOS 27.2、Android 17（API 37）。开发开始时再核对一次。

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

Claude、ChatGPT、Grok 的紧凑形态是“左上角菜单打开抽屉”，它们都自己实现了这层。系统自带的结构能得到同样的层级，还白拿返回手势和无障碍：

| 平台 | 建议 | 说明 |
|---|---|---|
| iOS / iPadOS | `NavigationSplitView`，`preferredCompactColumn` 设为详情 | 紧凑时打开就是对话，返回到历史。宽屏自动变成侧栏 |
| macOS | `NavigationSplitView` 加 `.inspector` | 对应侧栏、对话、详情栏 |
| Android | `ListDetailPaneScaffold`，紧凑时先显示详情 | Material 已不推荐导航抽屉，改用展开式 rail。历史不是导航目的地，用列表详情更贴切 |
| Web | 原型结构 | 紧凑形态是整页历史 |

这和“模仿那三家”有一点差别：历史从左侧滑出变成返回到上一层。层级相同，左上角位置相同。

Web 没有系统控件，所以向原生端的操作靠：紧凑形态的历史也是整页，图标是菜单，位置相同。手机浏览器的返回手势关掉最上面一层，顺序和 Android 的返回一样：底部面板、详情、历史、设置。

**操作层的约定**：左上角是历史，标题打开模型和处理位置，加号是添加内容，右下是主按钮，长按是消息菜单，选项用底部面板，返回关闭最上层，撤销用底部轻提示。控件各用各的，这些位置和走法三端接近。

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
| `chrome` `surface` `raised` `sunken` | 使用 | 功能层用系统背景色；对话内容层用主题纸面，主题“素”用系统背景色，见 [设计语言](02-design-language.md#apple-端风格与主题) | M3 surface 角色 |
| `ink` `ink-2` `ink-3` | 使用 | 系统 label 色 | `onSurface` `onSurfaceVariant` |
| `line` `line-2` `control` | 使用 | 系统分隔色 | `outlineVariant` `outline` |
| `jade` | 使用 | App accent | `primary` |
| `jade-wave` `you-wave` `overlap` `cinnabar` `amber` 及其浅色 | 使用 | Asset Catalog 自定义色 | 扩展色，`CompositionLocal` 提供 |

**iOS / macOS**：内容偏单色时可以用品牌色作 accent。着色只给主操作和状态，不给多个控件上色，少用自定义工具栏背景。玻璃上只有实时主按钮和结束按钮带色。第一阶段没有实时，同一位置的发送和拍照按钮带色。

**Android**：Material 区分品牌一致的静态方案和个性化的动态方案，语义色可以固定。建议第一版用 token 生成静态方案。动态配色可能把 `primary` 变成接近朱砂的颜色，破坏“朱砂等于采集”的含义。以后可以只让中性色跟随壁纸。

**增强对比度**：iOS 的 Increase Contrast 和 Android 的高对比文字需要额外一组色值，现在还没有定义。

## 实时会话

这是平台差异最大的地方。实时是下阶段，这一节先留着。开工前先看 [下阶段要对齐的事实](04-live-session.md#下阶段要对齐的事实)。

### 离开应用

| | 事实 | 设计 |
|---|---|---|
| iOS | 后台提交 Metal 任务会报错，相机后台不可用。`BGContinuedProcessingTask` 的 GPU 能力要用户发起并检查设备支持，不能作为 iPhone 基线 **[推断]** | 离开即暂停 |
| Android | 麦克风和相机前台服务要在应用可见时启动，之后可以继续。Android 17 对不可见进程有内存上限，后台音频要有 while-in-use 能力的前台服务 | 离开即暂停，与 iOS 一致 |
| macOS | 没有这类限制 **[推断]**。要防止 App Nap，用 `beginActivity` | 继续运行，菜单栏显示状态 |
| Web | 页面可见性决定资源 | 继续运行；手机浏览器切走时按暂停处理 |

用户决定不做后台 GPU 能力：需要算力的功能都在前台工作，各平台只提供系统级的定时通知和备忘录。这样隐私规则统一，也避开模型驻留后台时被内存上限杀掉的风险。

这里的“前台”指应用开着并由用户发起。macOS 和桌面 Web 上，窗口不在最前面时会话继续，否则“一起看屏幕”做不到。

### 屏幕常亮

实时期间不让系统自动息屏，否则息屏等于离开应用。行为规格见 [实时会话](04-live-session.md#屏幕)。下表的接口名未逐条核对官方文档，开发前确认。

| | 保持常亮 | 按电源键 |
|---|---|---|
| iOS | `isIdleTimerDisabled` | 应用离开前台，走暂停 **[待实测]** |
| Android | `FLAG_KEEP_SCREEN_ON` | `ON_STOP`，走暂停 **[待实测]** |
| macOS | `beginActivity` 加 `.idleDisplaySleepDisabled` | 不适用 |
| Web | Screen Wake Lock API，不支持时提示屏幕可能熄灭 | 手机浏览器走 `visibilitychange` |

远看模式靠深色界面省电，不改系统亮度，Web 也改不了。

### 车机

第一版不做。iOS 26.4 起 CarPlay 有语音对话应用类别，要申请 entitlement，只能用指定模板，没有唤醒词（来自二手报道，未读 CarPlay 开发指南）。手机锁屏时 CarPlay 里能不能跑本机模型 **[待实测]**，这决定以后要不要做。

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
| 被系统回收 | 下次启动恢复 | `ApplicationExitInfo` | 同左 | 下次打开恢复 |

iOS 和 Android 上用户撤销权限时系统会结束进程 **[待实测]**，走“被系统回收”路径，所以没有单独的暂停状态。

### 崩溃和意外退出

| | 模型中断，应用还在 | 下次打开时判断 |
|---|---|---|
| iOS | 模型和应用同进程时没有这一层，直接走下次打开 | 本地标记，`MetricKit` 给诊断 |
| Android | 模型放在独立进程时能重启 | 本地标记，`ApplicationExitInfo` 给原因 |
| macOS | 模型放在子进程时能重启 | 本地标记，`MetricKit` 给诊断 |
| Web | `GPUDevice.lost` 或 Worker 报错后重新申请设备，模型要重新载入 | 本地标记 |

本地标记：开始实时、开始回答、开始载入前写一个标记，正常结束时清掉。下次打开还在就是意外退出。这样不依赖系统给的原因，四端相同 **[待实测]**。

iOS 和 Android 上内存超限时，系统可能直接结束应用，应用来不及处理 **[待实测]**。“载入时退出”就是防这种情况。

### 发热和电量

| 原型等级 | iOS `thermalState` | Android `getThermalHeadroom` | Web |
|---|---|---|---|
| 正常 | `.nominal` `.fair` | < 0.75 | 正常 |
| 放慢 | `.serious` | ≥ 0.75 | 用 Compute Pressure（仅桌面 Chrome、Edge），否则看响应延迟 |
| 只用声音 | `.serious` 持续 2 分钟 | ≥ 0.9 | 同上 |
| 暂停 | `.critical` | ≥ 1.0 | 不适用 |

阈值是起点，要用实机数据调 **[待实测]**。Android 的 headroom 最多 10 秒查一次，部分设备状态可能一直是 NONE，要配合响应延迟判断。

| 电量等级的信号 | iOS | Android | macOS | Web |
|---|---|---|---|---|
| 低电量模式 | `isLowPowerModeEnabled` | `PowerManager.isPowerSaveMode` | `isLowPowerModeEnabled`（macOS 12 起） | 没有 |
| 电量和充电 | `UIDevice.batteryLevel` | `BatteryManager` | IOKit 电源信息 | Battery Status API |

Battery Status API 不是所有主流浏览器都支持，也不能在 Worker 里用。读不到电量时，Web 不走电量阶梯，只看发热和响应延迟 **[待实测]**。

### 屏幕共享

| | 能力 | 第一版 |
|---|---|---|
| macOS | `SCContentSharingPicker`（14+） | 提供，用系统选择器 |
| Web 桌面 | `getDisplayMedia` | 提供 |
| Android | `MediaProjection`，每次重新同意，可选单个应用，状态栏有提示，锁屏时自动停止 | 不提供。共享别的应用时模型在后台，不做 |
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
| 渠道 | 发布时用 Background Assets，Apple 托管上限 200GB。开发期免费签名不可用，先用 URLSession，仍走同一个 `ModelStore` | Play AI pack 单包 ≤ 1.5GB，累计上限文档有出入，6GB 模型大概率走自有 CDN | 自有 CDN，存进浏览器的站点存储（OPFS） |
| 后台下载 | 系统托管 | 用户发起的数据传输任务（`setUserInitiated`） | 不适用 |
| 移动网络 | `allowsExpensiveNetworkAccess` | 超过 200MB 走确认 | 不适用 |
| 审核 | 4.2.3 要求首次启动下载前披露大小，欢迎流程已满足 | 禁止下载可执行代码，模型属于数据 **[推断]** | 不适用 |

换模型时要先释放旧模型再载入新模型，等待时间因设备差别很大。原型里的秒数是占位，要用实测数据换掉 **[待实测]**。

内存：iOS 有 `increased-memory-limit` 权限（部分机型），用 `os_proc_available_memory` 判断余量，不要缓存这个值。这个权限不在免费个人团队的能力表里，免费签名下能否生效 **[待实测]**。后端选型需记录实际设备与签名限制；轻量看图模型可用于接口验证，LES 大规格 MoE 的评估另行记录，不能用小模型结果替代。Android 17 按设备内存设上限，超限退出原因含 `MemoryLimiter:AnonSwap`。

开发期若把 iOS 客户端装到真机，只用免费个人团队、只装在自己的设备上。描述文件 7 天过期，不能用 TestFlight，iCloud 和 Apple 托管的模型包都测不了。限制和替代做法见 [开发期合规](12-compliance.md#个人设备测试)。付费账号、正式 Bundle ID 和提审见 [首次发布与商店政策](13-release-and-store-policy.md)。

### 规格

规格现在不定。实现时 backend 读硬件配置，列出能选的模型，交互见 [信息架构](03-structure.md#规格)。

官方客户端的现状可以当起点：手机上基本只发 Q4，视觉部分固定 F16，用户实际在选模型大小。V 4.6 约 1.6 GB，建议内存 ≥ 6GB；V 4.7 1B 约 1.8 GB，≥ 4GB；V 4.7 35B-A3B 约 16.6 GB，≥ 12GB，要较快的机身存储，目前只在 iOS（`refs/minicpm-v-apps/README_zh.md@d0dd7a6`）。下载源是 Hugging Face 和 ModelScope 竞速，用户无感，联网记录要写明这两个目的地。

公开的 `openbmb/MiniCPM-o-4_5-gguf` 里，语言模型 Q4_K_M 5.03 GB，F16 16.4 GB。llama.cpp-omni 还要视觉、音频、TTS 等模块：一份部署指南写 Q4_K_M 全部约 8.3 GB，项目说明写 F16 约 15–18 GB，占用约 19–20 GB，建议 32GB 以上的 Mac。**这比原型里的 6.0 GB 大**，原型的大小都是占位，换成实际发布包的数字。

按这些数字，手机基本只能跑轻量，完整主要给桌面。之后按机型选规格时，只需要替换推荐逻辑，见原型的 `bestSpec()`。Q8 这样的中间规格是数据里加一行的事。

### 内存

这是最大的技术风险：6GB 级模型能否在 8GB 手机上和全双工一起运行。**最便宜的验证**是在目标机型上加载模型跑 10 分钟实时，记录是否被杀和发热曲线。结果决定“全能”模型在手机上的推荐条件。这项验证已延后。

浏览器有同样的问题：WebGPU 下全能模型和全双工能跑到什么程度 **[待实测]**。跑不动时，浏览器只提供看图模型，走“这台设备跑不动”的路径，见 [没有实时的原因](03-structure.md#没有实时的原因)。

官方三个手机客户端现在都没有全能模型，`refs/` 里也没有 WebGPU 本机运行的实现，这两项都没有现成参考。

## 系统入口

原型里没有，原生端要做。这些入口让“处理一件小事”更快。

| 入口 | iOS | Android | macOS | Web |
|---|---|---|---|---|
| 分享进来 | Share Extension | `ACTION_SEND` | Share Extension | Web Share Target |
| 快速开始 | App Intents，Action Button，控制中心 | 快捷方式，快捷设置磁贴 | 全局快捷键，菜单栏 | 不适用 |
| 通知 | 定时通知，见下 | 同左 | 同左 | 不适用 |
| 小组件 | 开始语音、看东西 | 同左 | 不做 | 不适用 |

分享进来的流程：选图 → 打开新对话，附件已就位，光标在输入框。不用在分享面板里完成对话。

## 说话输入和朗读

看图基线用系统能力，模型不参与。下表的接口名未核对官方文档，开发前确认。

| | 说话输入 | 朗读 |
|---|---|---|
| iOS / macOS | `SFSpeechRecognizer`，`requiresOnDeviceRecognition` 开着，`supportsOnDeviceRecognition` 为假时不提供 **[待实测]** | `AVSpeechSynthesizer` |
| Android | `createOnDeviceSpeechRecognizer`（Android 12 起），设备不支持时不提供 **[待实测]** | `TextToSpeech` |
| Web | 不提供。Chrome 的 Web Speech 把音频发到服务器 | `speechSynthesis`，部分声音走网络时只用本机声音 **[待实测]** |

用户用输入法自带的语音键，不在应用的控制范围内。

## 定时通知和备忘录

这是应用不在前台时唯一发生的事，由系统完成，模型不运行。流程见 [信息架构](03-structure.md#定时通知和备忘录)。

| | iOS | Android | macOS | Web |
|---|---|---|---|---|
| 定时通知 | `UNUserNotificationCenter` 本地通知 | `AlarmManager.setAndAllowWhileIdle()` | 同 iOS | 页面关掉后发不了，存成日历文件 |
| 通知权限 | 第一次添加时问 | Android 13 起第一次添加时问 | 同 iOS | 不需要 |
| 写备忘录 | 系统分享面板 | `ACTION_SEND` | 系统分享面板 | 复制文字 |

- **Android 时间有偏差**：`setAndAllowWhileIdle()` 不用精确闹钟权限，Android 12 起在触发时间后一小时内发出，省电限制下可能更晚。精确闹钟权限 `SCHEDULE_EXACT_ALARM` 在 Android 14 默认拒绝，这个功能不值得申请。文案写“早上 9 点左右”还是“9 点”待定 **[待实测]**。
- **Web**：Notification Triggers API 已停止开发，页面关掉后没有本地定时通知。服务器推送不符合本机定位。
- **为什么备忘录走分享面板**：写入提醒事项要 `requestFullAccessToReminders`，一起拿到读取全部提醒的权限，和“用到什么要什么”不符。系统备忘录没有查到公开写入接口 **[推断]**。分享面板不用权限，代价是多一步，用户自己选目标应用。
- iOS 待处理的本地通知有数量上限，定时通知不多时不受影响 **[待实测]**。

## 备份

规则见 [隐私设计](08-privacy.md#备份与导出)。

| | iOS / iPadOS | macOS | Android | Web |
|---|---|---|---|---|
| 云备份 | iCloud，用户开启 | iCloud，用户开启 | 目标待定 | 目标待定 |
| 导出导入 | 有 | 有 | 有 | 有 |
| 系统自动备份 | 排除 | 排除 | 排除 | 不适用 |

**iCloud 用应用自己的备份，不用系统的设备备份。** 系统的 iCloud 云备份面向 iPhone 和 iPad，Mac 上是时间机器 **[推断]**，一套方案覆盖不了两端，而且用户开关不在我们这里。建议用 CloudKit 私有数据库，敏感字段放进 `CKRecord.encryptedValues`。Apple 的安全指南说，端到端加密的服务密钥不会提供给 Apple 服务器，靠 iCloud 钥匙串在设备间同步，钥匙串丢失时这些数据也恢复不了。第三方应用能否得到同样的保证、失败时怎么提示 **[待实测]**，确认后才能写“加密”，现在的文案不写。

**默认要排除系统备份**，否则对话会在用户不知情时进入设备备份，第一条承诺就不成立：

- iOS：`isExcludedFromBackup`。文档说它适合缓存和支持文件，文档目录里的常见操作可能把它重置，所以数据放 Application Support，在目录上设置 **[待实测]**。
- macOS：同一属性是否让时间机器跳过 **[待实测]**。备份盘在用户手里，影响较小。
- Android：`android:allowBackup="false"`，Android 12 起用 `android:dataExtractionRules` 排除，更早的版本单独写规则文件。

模型文件不进任何备份。

## macOS 特有

- 菜单栏完整：文件（新对话、导出）、编辑、显示（侧栏、详情）、对话（实时、停止）、窗口、帮助。
- 快捷键沿用原型：`⌘N` 新对话，`⌘K` 搜索，`⌘B` 侧栏，`⌘I` 详情，`⌘,` 设置，`Esc` 停止。实时中 `⌥M` 麦克风，`⌥V` 画面，`⌥F` 定格，`⌥H` 先听我说。
- 关闭窗口默认留在菜单栏，设置里可改。
- 拖放文件到窗口和 Dock 图标。

## iOS 27 要点

iOS 客户端最低版本是 27。来自 WWDC26 的 What's new in SwiftUI（session 269），其余是第三方整理的发布说明，都没有在 Xcode 里验证 **[待实测]**。

- Xcode 27 要 macOS 26.6 以上和 Apple 芯片，带 Swift 6.4。用它构建就得到新版 Liquid Glass，不用改代码，还会响应系统新增的玻璃着色滑块。
- iPhone 应用在 iOS 27 可以调整大小。按尺寸类判断形态，不按设备类型。这和“形态由窗口尺寸决定”一致。
- 工具栏空间不够时：`visibilityPriority`、`ToolbarOverflowMenu`、`topBarPinnedTrailing`。
- 确认和警告支持 `item:` 绑定，和 `.sheet` 写法相同。
- `@State` 变成宏。声明时有默认值又在 `init` 里赋值会报错。
- `toolbarMinimizeBehavior` 在 session 里出现，发布说明写已改名为 `toolbarMinimizationBehavior`，两个来源不一致，现在不用。
- iOS 27 要求场景生命周期。纯 SwiftUI 应用已经满足。

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
| 说话输入 | 能本机识别时有 | 能本机识别时有 | 能本机识别时有 | 无 |
| 保持屏幕亮着 | 有 | 有 | 有 | 有 |
| 远看模式 | 有 | 有 | 窄窗口 | 手机浏览器 |
| 定时通知 | 有 | 有 | 有 | 无 |
| 备份到 iCloud | 有 | 无 | 有 | 无 |
| 导出和导入对话 | 有 | 有 | 有 | 有 |

## 多语言

| | iOS / macOS | Android | Web |
|---|---|---|---|
| 应用内语言 | 系统设置 | `LocaleManager`，`generateLocaleConfig` | 自己实现 |
| 字符串 | String Catalog | 字符串资源 | ICU MessageFormat |
| 复数 | Vary by Plural | `plurals` | ICU |

用词和语言标识见 [文案与多语言](09-i18n-copy.md)。

## Token 到代码

`tokens/` 使用 Design Tokens 社区组（DTCG）的结构。颜色值保留十六进制字符串，方便手改，也是 Style Dictionary 能读的写法。

`tools/tokens.mjs` 先检查对比度和主题规则，全部通过才生成：原型的 token 块、`apps/web/src/styles/tokens.css`（只有默认主题）、iOS 的 Asset Catalog 颜色（根目录是默认主题的角色色，`Themes/` 是各主题的内容层颜色，都带增强对比度外观），以及 `MiniCPMCore` 的主题注册表和 App 里的主题显示名。规则见 [扩展接口](02-design-language.md#扩展接口)，选型见 [决策记录](10-decisions.md)。Android 开工时再看要不要换成 Style Dictionary，它内置 `compose/object` 格式，对 DTCG 2025.10 的支持还不完整，所以先不用新版的颜色对象写法。

## 交接方式

每个界面交给开发时给这四样：

1. 原型链接，带状态参数。
2. [状态矩阵](05-states.md) 里对应的行。
3. [组件清单](06-components.md) 里的分类：系统、组合或自绘。
4. 本文对应平台的说明。

第一阶段没有实时，几乎全部用系统控件，自绘只有品牌标记和说话输入的录音条。下阶段自绘组件建议先做双轨波形和实时控制条，这两个决定产品感觉，也最需要在真机上调。

## 参考

- Apple：[What's new in SwiftUI（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/269/)、[iCloud encryption](https://support.apple.com/guide/security/icloud-encryption-sec3cac31735/web)、[encryptedValues](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues)、[isExcludedFromBackup](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup)、[requestFullAccessToReminders](https://developer.apple.com/documentation/eventkit/ekeventstore/4162273-requestfullaccesstoreminders)、[isLowPowerModeEnabled](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled)、[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Color](https://developer.apple.com/design/human-interface-guidelines/color)、[Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)、[Running Metal in the background](https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background)、[Capturing screen content on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios)、[Background Assets](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs)、[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Android：[Schedule alarms](https://developer.android.com/develop/background-work/services/alarms)、[Exact alarms denied by default](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)、[Auto Backup](https://developer.android.com/identity/data/autobackup)、[Window size classes](https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes)、[Choosing a color scheme](https://m3.material.io/styles/color/choosing-a-scheme)、[Foreground service restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)、[Android 17 behavior changes](https://developer.android.com/about/versions/17/behavior-changes-all)、[Live updates](https://developer.android.com/develop/ui/views/notifications/live-update)、[MediaProjection](https://developer.android.com/media/grow/media-projection)、[Thermal API](https://developer.android.com/games/optimize/adpf/thermal)、[On-device AI delivery](https://developer.android.com/google/play/on-device-ai)
- Web：[Notification Triggers](https://developer.chrome.com/docs/web-platform/notification-triggers)、[Battery Status API](https://developer.mozilla.org/en-US/docs/Web/API/Battery_Status_API)、[GPUDevice.lost](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/lost)、[Media Session](https://w3c.github.io/mediasession/)、[Compute Pressure](https://developer.mozilla.org/en-US/docs/Web/API/Compute_Pressure_API)
- 模型：[MiniCPM-o 4.5 GGUF](https://huggingface.co/openbmb/MiniCPM-o-4_5-gguf/tree/main)、[llama.cpp-omni](https://github.com/tc-mb/llama.cpp-omni)、[部署指南](https://datawhalechina.github.io/hello-rocm/01-deploy/minicpm-o/minicpm-o-model)
- 车机（二手报道）：[MacRumors](https://www.macrumors.com/2026/02/18/ios-26-4-carplay-support/)、[AppleInsider](https://appleinsider.com/articles/26/02/18/ai-agents-are-coming-to-carplay-but-theyre-not-getting-the-keys)
- iOS 27 第三方整理：[Xcode 27](https://blakecrosley.com/blog/xcode-27-release)、[iOS 27 release notes](https://blakecrosley.com/blog/ios-27-release-notes)、[SwiftUI iOS 27](https://blakecrosley.com/blog/whats-new-swiftui-ios-27)
- Token：[DTCG 2025.10](https://www.designtokens.org/tr/2025.10/format/)、[Style Dictionary DTCG](https://styledictionary.com/info/dtcg/)
