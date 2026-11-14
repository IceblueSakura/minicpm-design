# 设计语言

设计语言分三层。**产品层**跨平台不变，**操作层**尽量接近，**表现层**由各平台决定。改设计时先判断改的是哪一层。

| 层 | 内容 | 落到原生端 |
|---|---|---|
| 产品层 | 角色颜色的含义、双轨波形、实时控制条结构、隐私信号、状态词、文案语气 | 必须一致 |
| 操作层 | 入口位置、页面层级、任务步骤、控件顺序、返回回到哪里 | 尽量接近。和平台控件冲突时平台优先 |
| 表现层 | 字体、圆角、阴影、控件样式、导航控件、转场、主题风格 | 跟随平台 |

优先级是平台原生、操作逻辑、颜色风格，依次让步。角色颜色的含义属于产品层，具体色值和整体风格属于表现层，可以随平台偏移。

网页端没有系统控件可依靠，所以原型里的表现层就是网页端的最终样式。

## 视觉来源

三种颜色来自书写和瓷器：**青瓷**是模型，**墨**是你，**朱砂**是正在发生的事。

纸上的墨是人留下的，青瓷是一件安静的器物，朱砂是印章，落下去就算数。这个隐喻只服务于颜色的分工，不延伸成纹样、书法字或国风装饰。界面本身保持克制，底色是略带绿灰的纸色。

## 颜色

颜色首先是角色。同一个角色在任何平台、任何主题下含义不变。色值在 `tokens/light.json` 和 `tokens/dark.json`。

| 角色 | Token | 含义 | 用在 |
|---|---|---|---|
| 青瓷 | `jade` `jade-wave` `jade-soft` `on-jade` | 模型，和模型有关的主操作 | 模型波形、实时按钮、选中态、隐私声明 |
| 墨 | `ink` `ink-2` `ink-3` `you-wave` | 你，以及普通文字 | 你的波形、正文、发送按钮 |
| 朱砂 | `cinnabar` `cinnabar-soft` `on-cinnabar` | 正在采集；要小心的事 | 取景框、采集点、实时状态条、结束按钮、错误 |
| 琥珀 | `amber` `amber-soft` | 等待或受限，不是错误 | 暂停、重连、下载提示、注意事项 |
| 纸面 | `chrome` `surface` `raised` `sunken` | 层次 | 底色 |
| 线 | `line` `line-2` `control` | 分隔和边界 | 分隔线、容器、控件边界 |

### 使用规则

- **朱砂的第一含义是“正在采集”。** 用户看到朱砂框、朱砂条和采集点就知道设备正在听或看。不采集时，这些位置不能出现朱砂：暂停和静音时侧栏标记、状态条换成琥珀，麦克风按钮用中性色和划线图标。
- **语音实时也要有朱砂。** 语音没有取景框，所以时长前面有一个采集点，远看模式时是整圈朱砂框。
- **话轮灯不用朱砂。** 灯说的是谁在说话，不是有没有采集。打断的朱砂只留在波形里。
- **青瓷不用来表示成功。** 它代表模型。成功状态用文字，不用绿色提示。
- **颜色不是唯一信号。** 每个状态同时有文字或图标，色觉差异用户不靠颜色判断。
- **一屏只有一个高饱和主角。** 实时时是结束按钮和取景框，其他控件保持中性。

原生端的破坏性操作用系统红色（比如 iOS 的 `.destructive`），不用朱砂。这样朱砂在原生端可以更纯粹地表示采集状态。网页端目前错误和采集共用朱砂，第一阶段可以维持。

### 对比度

`node tools/tokens.mjs` 检查 22 组前景背景，浅色和深色共 44 项，全部通过。文字要求 4.5:1，图形和控件边界要求 3:1。

| 组合 | 浅色 | 深色 |
|---|---|---|
| `ink-3` 在 `surface` | 5.3 | 6.0 |
| `ink-3` 在 `sunken` | 4.7 | 6.6 |
| `jade-wave` 在 `surface` | 3.1 | 9.1 |
| `control` 在 `surface` | 3.3 | 3.8 |

`line` 和 `line-2` 只用于装饰性分隔，不能作为控件的唯一边界。需要识别控件边界时用 `control`。

## 双轨波形

产品的标志，表达“两个人同时在场”。

```text
          你   ▂▅▇▅▂ ▁ ▂▅▂          ▂▅▇▅▂
时间轴 ─────────────────────────────────────▶ 现在
       模型             ▃▆▇▆▃▂ ▂▆▇▆▃▁
                              ▓▓
                         重叠：有人打断
```

| 规则 | 说明 |
|---|---|
| 同一条时间轴 | 上下对齐的就是同一时刻，这是全部含义所在 |
| 上轨你，下轨模型 | 固定不变，不随主题和语言改变 |
| 墨和青瓷 | 不用渐变，不用发光 |
| 竖条 | 3 宽，步进 5，末端方形。来自真实电平，不做装饰性动画 |
| 最新在右 | 向左滚动 |
| 重叠铺色 | 打断是这张图里唯一的朱砂 |

同一个图形派生出：

| 派生 | 用途 |
|---|---|
| 品牌标记 | 静态十根短线，上墨下青瓷 |
| 实时图标 | 单色版，放在按钮上 |
| 缩略时间线 | 结束后的记录，用色块表示谁在什么时候说话 |

不要做成圆形声波、球体或拟人动画。

## 文字

原生端用系统字体和系统文字样式，跟随用户的字体大小设置。下表是层级，网页端的值在 `tokens/base.json`。

| 层级 | 网页（展开 / 紧凑） | iOS / macOS | Compose |
|---|---|---|---|
| 大标题 | 26 / 24，600 | `.title` | `headlineMedium` |
| 页面标题 | 20，600 | `.title2` | `titleLarge` |
| 标题 | 15，600 | `.headline` | `titleMedium` |
| 回答正文 | 14.5 / 16，行高 1.75 | `.body` | `bodyLarge` |
| 界面文字 | 14 / 15 | `.body` / `.callout` | `bodyMedium` |
| 说明 | 13 | `.footnote` | `bodySmall` |
| 辅助 | 12 | `.caption` | `labelMedium` |

- 回答的行高比界面文字大。长中文需要呼吸。
- 时间和计数用等宽数字，避免跳动：iOS `.monospacedDigit()`，Compose `fontFeatureSettings = "tnum"`，网页 `font-variant-numeric: tabular-nums`。
- 回答里的代码块用 JetBrains Mono，测量和计时仍用系统等宽字体，见 [字体](#字体)。

## 形状与空间

网页端的值：

| 用途 | 圆角 |
|---|---|
| 按钮、小控件 | 8 |
| 横幅、列表卡 | 10 |
| 卡片、菜单、取景框 | 12 |
| 输入框、控制条 | 14，紧凑形态 26 / 24 |
| 底部面板 | 20 |

对话列宽上限 760。手机边距 16。间距按内容关系决定，不强求统一栅格。

原生端的圆角、边距、阴影一律由系统控件和系统布局决定。自绘组件的圆角跟随相邻系统控件：iOS 用同心圆角，Android 用 M3 形状角色。

## 层次

内容层和功能层分开：

- **内容层**是对话、转写、取景画面。
- **功能层**是输入框、控制条、导航。

iOS 上 Liquid Glass 只用于功能层，内容层不用玻璃。摄像头全屏时控制条浮在画面上，这正是玻璃的用途。网页端用实色和模糊模拟。

## Apple 端风格与主题

下一步只做 macOS 和 iOS，这一节定 Apple 端的视觉风格和主题。方向、六套主题、强调色、字体和图标都已定（2026-11-14），见 [决策记录](10-decisions.md)。Apple 平台事实核对于 2026-11-14，来源列在文末。

主题色值已经落成 token：`tokens/themes/` 六个文件，`node tools/tokens.mjs` 校验后生成原型、Asset Catalog 和 Swift 注册表。效果图放在 [`docs/assets/style/`](assets/style/README.md)，只放 Mac 和模拟器上的真实渲染，不放模拟图。

### 方向：纸与器

三个方向里定了 B。A“系统原生”只给控件着色，辨识度最低；C“实验台”把测量常驻在顶部，最能展示性能，但和“第一屏是对话”冲突，留作主题。

| 层 | 规则 | 依据 |
|---|---|---|
| 结构归系统 | 导航、侧栏、列表、设置、菜单、底部面板、工具栏都用系统控件，不换背景 | HIG：栏、面板、弹出层去掉自定义背景 |
| 玻璃只在功能层 | 输入框、工具栏按钮、轻提示用 `glassEffect`。玻璃不着色，只有主按钮带主题色。不做玻璃强度设置，系统的 Liquid Glass 滑块负责 | HIG Materials、Color |
| 内容层是纸 | 对话区铺主题纸面：低彩度、带色温的底色，正文用墨色，长回答行高宽松。品牌色放在内容层，滚到玻璃下面时由玻璃折射出来 | HIG Branding（2026-09-09 更新） |
| 模型是器 | 主题色就是模型色，界面强调色默认也取它，见 [强调色](#强调色)。一屏只有一个高饱和主角 | 本文“颜色”一节 |
| 测量是刻度 | 测量行、运行详情用 SF Mono 等宽数字和辅助色，安静但随时可读 | [运行参数与测量](03-structure.md#运行参数与测量) |
| 信号锁定 | 朱砂（采集）、琥珀（等待）、系统红（破坏性操作）在所有主题下不变 | 本文“使用规则” |

角色色不走 `tint`。波形、品牌标记、实时按钮、结束按钮直接用角色色，所以系统强调色变成红色时，也不会和“正在采集”混淆。

### 主题

第一版六套，已定。主题只改内容层的纸面、文字色调和模型色。ID 稳定，显示名单独存，和场景相同。

| ID | 名称 | 纸面 | 模型色 | 适合 |
|---|---|---|---|---|
| `plain` | 素 | 系统中性色 | 青瓷；macOS 上控件跟随系统强调色 | 想要纯原生观感 |
| `celadon` | 青瓷（默认） | 绿灰 | 青瓷 | 现有品牌 |
| `xuan` | 宣纸 | 暖米色 | 黛蓝 | 长时间阅读 |
| `indigo` | 靛蓝 | 冷灰 | 靛蓝 | 偏工作 |
| `wisteria` | 紫藤 | 淡紫灰 | 紫藤 | 柔和 |
| `lab` | 实验台 | 石墨 | 青色 | 看性能的人 |

每个主题都要满足：

- **浅色、深色、增强对比度三套值**，写在 Asset Catalog 的 High Contrast 外观里，不在代码里判断。
- **对比度**：正文和辅助文字 ≥ 4.5:1，图形和控件边界 ≥ 3:1，浅色深色都查。默认主题达标是申报“对比度充足”无障碍标签的条件，但所有主题都按同一标准查。
- **色相**：模型色和朱砂的 OKLCH 色相差 ≥ 60°，和琥珀 ≥ 40°。红、橙、黄的模型色一律不做。
- **不像“信息”**：用户气泡用中性浅色，不用蓝、绿实心气泡（审核指南 5.2.5）。

### 扩展接口

六套之后再加主题，只加一个文件、跑一次工具，界面代码不动。

**一个主题一个文件**：`tokens/themes/<id>.json`，DTCG 结构。

| 字段 | 内容 |
|---|---|
| `$extensions.minicpm` | `name`（显示名，进 String Catalog）、`order`（排序）、`surfaces`：`theme` 或 `system`（“素”用系统背景） |
| `light`、`dark` | 可主题化的色值，缺的项沿用默认主题青瓷 |
| `light-hc`、`dark-hc` | 可选的增强对比度色值。缺的项由工具推导，见下 |

**可主题化**：纸面和层次（`chrome` `surface` `raised` `sunken`）、线（`line` `line-2` `control`）、文字（`ink` `ink-2` `ink-3` `you-wave`）、模型色（`jade` `jade-wave` `jade-soft` `on-jade`）、用户气泡（`user-bubble`）。`jade` 系列的名字沿用历史，含义是“模型色”，色值随主题变。

**锁定**：`cinnabar` `cinnabar-soft` `on-cinnabar` `amber` `amber-soft` `overlap`。主题文件里出现这些键，工具直接报错。

**增强对比度的推导**：主题没写的项按同一套规则从本主题的浅色或深色值算出，混色在 OKLab 里做。纸面不变，只加深文字、线和模型色。

| 项 | 增强对比度时 |
|---|---|
| `ink-3` | 取 `ink-2`（辅助文字升一级） |
| `ink-2` | `ink-2` 和 `ink` 各半 |
| `line`、`line-2` | 各升一级：`line` 取 `line-2`，`line-2` 取 `control` |
| `control` | 朝 `ink` 混 25% |
| `jade`、`jade-wave` | 朝 `ink` 混 25%。浅色下变深，深色下变亮，和纸面、`on-jade` 的对比度都升高 |

**工具的检查**（`tools/tokens.mjs`）：先查完再写，任何一项不通过就什么都不写，退出码为 1。

- 基础 token 的每个键都要归进可主题化或锁定，新加的键不归类就报错。
- 主题文件：ID 是小写加连字符；元数据齐全，`surfaces` 只能是 `theme` 或 `system`，`order` 不重复；只出现 `light` `dark` `light-hc` `dark-hc` 四组；锁定的键、不认识的键、带透明度的颜色都报错；必须有 `celadon.json`。
- 对比度：每个主题的四套值都过“对比度”一节的 22 组，现在 6 × 4 × 22 加默认的 44 组，共 572 组全部通过。
- 色相：`jade` 和 `jade-wave` 在四套值里都要离朱砂 ≥ 60°、离琥珀 ≥ 40°。现在最近的是紫藤深色增强对比度，离朱砂 89°。
- 生成的颜色名不能重名。
- 提醒：String Catalog 里缺某个主题的四语显示名时打印一行提示，不算失败。

**生成物**：

| 目标 | 内容 |
|---|---|
| Asset Catalog | `Themes/<前缀>/<前缀><角色>.colorset`，比如 `Themes/Xuan/XuanSurface`，生成的符号是 `.xuanSurface`。文件夹不开命名空间，靠前缀保证名字和符号不重复。每个颜色四个外观：浅色、深色、浅色增强对比度、深色增强对比度。根目录的 `AccentColor` 等保持青瓷，作为应用默认，可主题化的几项也加了增强对比度外观。`Themes/` 每次整个重写，删掉的主题不会残留 |
| Swift 注册表 | `MiniCPMCore/ThemeCatalog.generated.swift`：`Theme`（ID、排序、`surfaces`、`assetName(_:)`）、`ThemeRole`、`ThemeCatalog.all` 和 `resolve(_:)`。规则层不依赖 SwiftUI，只给出颜色名 |
| 显示名 | `MiniCPM/Shared/ThemeNames.generated.swift`：`Theme.name`，键是 `theme.<id>`，写成字面量，Xcode 能抽进 String Catalog。显示名不进规则层 |
| 原型 | `index.html` 的 `/* tokens:themes */` 块按 `data-palette` 和 `data-contrast` 切换，`/* tokens:palettes */` 是设置里主题卡片读的列表。参数见 [状态矩阵](05-states.md#主题) |
| Web（暂停） | 只生成默认主题，不同步主题 |

**规则层**：`MiniCPMCore` 的偏好只存主题 ID 字符串，用 `ThemeCatalog.resolve(_:)` 取主题。读到不认识的 ID（比如降级到旧版本）时回到青瓷，不改写存储，升回新版本后恢复。偏好字段和设置界面随外观设置一起加，现在还没有。

**加一套主题的步骤**：写 `tokens/themes/<id>.json` → 跑 `node tools/tokens.mjs` 直到检查通过 → 在 String Catalog 补四语显示名 → 按 [效果图清单](assets/style/README.md) 在 Mac 上渲染。备用图标单独走图标流程，不和主题绑定。

### 强调色

颜色分三种角色，只有第一种可以跟随系统：

| 角色 | 用在 | 来源 |
|---|---|---|
| 界面强调色 | 普通按钮、发送和拍照、开关、选中、链接、焦点 | 跟随主题（取模型色）或跟随系统 |
| 模型色 | 波形、品牌标记、实时按钮、模型相关的标识 | 只来自主题，不跟随系统 |
| 信号色 | 朱砂（采集）、琥珀（等待）、系统红（破坏性） | 锁定 |

设置项“强调色”有两个选项：跟随主题、跟随系统。默认值按平台惯例，读不到系统强调色时只能跟随主题：

| 平台 | 默认 | 说明 |
|---|---|---|
| macOS | 跟随系统 | 原生应用的惯例，HIG 要求尊重用户选择。系统强调色为“多色”（系统默认）时显示当前主题的模型色，用户选了别的颜色时显示用户的颜色。选“跟随主题”时整个窗口始终加 `tint` |
| iOS | 跟随主题 | iOS 没有系统强调色，这一项不显示 |
| Windows（暂停） | 跟随主题 | 系统有强调色（Fluent 的 `SystemAccentColor`），品牌应用通常默认用自己的颜色，再给“跟随系统”选项 |
| Linux（暂停） | 跟随主题 | 从 XDG 门户的 `org.freedesktop.appearance` `accent-color` 读取；没有这个键的桌面只能跟随主题 |
| Web（暂停） | 跟随主题 | 浏览器出于防指纹，CSS 的 `AccentColor` 只返回固定颜色，读不到真实值 |

**“多色”等于主题色。** macOS 的“多色”意思是让应用自己决定，所以没改过系统设置的用户看到的就是主题色；只有主动选过强调色的用户看到自己的颜色。实现方式：检测到“多色”时给窗口加 `.tint(主题模型色)`，否则不加，交给系统。

判断是否为“多色”没有公开 API，开工前先做一个最小实验 **[待实测]**：把 `AccentColor` 设成一个特殊颜色，系统切到“多色”后读 `NSColor.controlAccentColor`，看是否等于它；再确认 macOS 当前版本的默认值仍是“多色”。

- 实验通过：按上面实现，监听 `NSColor.systemColorsDidChangeNotification` 实时切换。
- 实验不通过：“多色”时只能显示 `AccentColor`（青瓷），其他主题的按钮也是青瓷。那时回来重新决定，是接受这一点，还是把默认改成跟随主题。

跟随系统时的约束：

- **撞色**：系统强调色可能是红色或橙色，接近朱砂。不和系统对抗，靠“颜色不是唯一信号”：采集始终同时有采集点和文字。
- **对比度**：任意强调色上的文字不直接用原色。有平台色阶时用色阶（Windows 的 `AccentDark1` / `AccentLight2`），没有时按明度夹取再选黑字或白字，保证 4.5:1。Apple 端由系统处理。
- **实时更新**：系统强调色变化时不用重启。macOS 监听 `NSColor.systemColorsDidChangeNotification`。

### 外观设置

| 设置 | 选项 | 平台 |
|---|---|---|
| 外观 | 跟随系统（默认）、浅色、深色 | 两端 |
| 主题 | 上表六套，用带预览的网格选 | 两端 |
| 强调色 | 跟随系统（macOS 默认）、跟随主题 | 只有 macOS 显示。规则见上一节 |
| 回答字体 | 系统（默认）、更纱黑体、思源宋体 | 两端。只用开源免费字体，优先 Noto 和更纱，规则见下一节 |
| 应用图标 | 首发只有默认图标，以后加主题图标 | 只有 iOS。每次更换系统都会弹提示，所以只在用户主动选择时换，不跟主题自动联动。每个图标要有深色、透明、着色三种变体 |

“显示技术信息”和测量的位置仍在高级设置，见 [运行参数与测量](03-structure.md#运行参数与测量)。

### 字体

界面文字一律用系统字体（SF 和苹方），跟随动态字体。可换的只有**回答正文**；回答里的代码块固定用 JetBrains Mono，不设选项；测量仍用 SF Mono。只用开源免费字体，优先 Noto 和更纱：Noto CJK 和思源同一设计，更纱由思源黑体和 Inter、Iosevka 合成，都是 SIL OFL 1.1。不用的字体：HarmonyOS Sans、MiSans、OPPO Sans、阿里巴巴普惠体免费但不开源，许可禁止修改且可撤销，不用；苹果的宋体、楷体、圆体是系统可下载字体，免费但不开源，也不用。

| 选项 | 字体 | 文件（按界面语言只下一套） | 说明 |
|---|---|---|---|
| 系统（默认） | 苹方 + SF | 不下载 | 首次启动和离线时都可用 |
| 更纱黑体 | Sarasa Gothic SC / TC / HC，Unhinted TTF 的 Regular、SemiBold、Bold | 每个字重约 13 MB，三个约 39 MB **[待实测]** | 中文是思源黑体，拉丁是 Inter，中文标点全宽，适合阅读。HC 是香港字形 |
| 思源宋体 | Noto Serif CJK SC / TC / HK 可变字体 | SC 约 23 MB，TC、HK 各约 15 MB | 一个文件含全部字重。名称没有保留字 |

- 选 Unhinted 版：Apple 平台不用 TrueType 微调信息，文件更小。
- Noto Sans CJK 和苹方风格接近，作为选项价值低，暂不提供；需要时可以作为更纱黑体的备选。
- 霞鹜文楷（OFL）留在候选：保留名“霞鹜”“LXGW”，繁体是传承字形，作者说明不太适合长篇正文。按扩展接口随时可以加。
- 圆体暂不提供：开源圆体要么停止维护，要么不覆盖简体。
- 更纱的许可里带 Adobe 的保留名“Source”，更纱本身不叫这个名字，用官方原文件即可。

**代码块：JetBrains Mono**（SIL OFL 1.1）。只用 Regular 和 Bold 两个静态 TTF，每个约 270 KB，打进安装包，不下载，首次启动和离线都能用。

- 没有中文字形，代码里的中文回退到苹方。JetBrains Mono 字宽 0.6 em，中文 1 em，不是 2:1，中文注释和 ASCII 对齐的表格会错位。代码块里中文少，接受；更纱等宽能 2:1 对齐，但要按需下载约 26 MB，不用。
- 关掉 `calt` 连字，`!=`、`->` 按原样显示，和用户复制出去的一致。
- 字号跟随动态字体，比回答正文小一档，和原型的 12.5 / 14.5 一致。

**交付**：

- 回答字体不打进安装包，放在 Apple 托管的 Background Assets 资源包里按需下载。按需资源（ODR）从 iOS 27 起废弃，macOS 本来就不支持。
- 选择字体时先写下载大小，用户确认后下载；下载完成前继续用系统字体。切回系统字体时可以删除资源包、收回空间。
- 下载完成后每次启动用 `CTFontManagerRegisterFontURLs` 以进程范围注册。字体是数据，不是代码，不受 2.5.2 限制。
- 下载来自 Apple 的服务器，不经过我们的服务器，仍符合“不收集数据”。联网记录里记一行“下载字体”。
- JetBrains Mono 例外，随安装包发布，用 Info.plist 的 `UIAppFonts`（iOS）和 `ATSApplicationFontsPath`（macOS）注册。
- 只发 OTF 或 TTF，不发 WOFF2。
- 现在只定方案，字体文件还没下载，也不进仓库。开工时从官方发布页取原文件。

**许可**：只用官方发布的原文件，不做子集、不转格式；否则按 OFL 算修改版本，保留名不能再用。“关于 › 开源许可”列出每款字体的版权声明和 OFL 全文。

**排版**：

- 字号用 `Font.custom(_:size:relativeTo: .body)`，跟随动态字体。
- 系统不会合成粗体和斜体。正文用 Regular，加粗用 SemiBold；“粗体文本”打开时各升一档（Regular→SemiBold，SemiBold→Bold）。思源宋体是可变字体，直接调字重。
- 各字体自带的行高差别很大，回答正文统一用“文字”一节的行高 1.75，不跟字体走。
- 中英混排以中文字体为主，用它自带的拉丁字形（更纱是 Inter，思源宋体是 Source Serif 风格）。斜体片段改用系统字体，更纱的斜体文件不下载。
- 按界面语言选文件：简体中文用 SC，繁体中文（台湾）用 TC，繁体中文（香港）用 HK（更纱叫 HC）。

**待实测**：CFF2 可变字体能否在 iOS 上直接注册（不行就换 TTF 可变字体，SC 约 25 MB）；更纱各字重的实际大小和资源包压缩后的下载大小；动态字体、粗体文本和 VoiceOver 在各字体下的表现；代码块里 JetBrains Mono 和回退的苹方基线是否对齐。

**扩展**：字体和主题一样走登记表：ID、显示名、每个地区的资源包 ID、PostScript 名、大小、许可。加一款字体只加一条登记和一个资源包，界面不动。

### 上架相关

- 用最新 SDK 构建，玻璃和控件用系统实现，不自己画玻璃。
- 不模仿“信息”或其他聊天应用的界面（4.1、5.2.5），不改系统控件的行为（2.5.9）。
- 截图可以展示不同主题，但必须是真实界面（2.3.3）。
- 主题全部免费，和“不做付费功能”一致。
- 首发目标申报的无障碍标签见 [开发期合规](12-compliance.md)。深色界面要覆盖首次启动、设置在内的所有常用流程。

字体来源：[JetBrains Mono](https://github.com/JetBrains/JetBrainsMono)、[Noto CJK](https://github.com/notofonts/noto-cjk)、[更纱黑体](https://github.com/be5invis/Sarasa-Gothic)（1.0.43，2026-10-25）、[霞鹜文楷](https://github.com/lxgw/LxgwWenKai)、[OFL FAQ](https://openfontlicense.org/ofl-faq/)、[Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs)、[CTFontManagerRegisterFontURLs](https://developer.apple.com/documentation/coretext/ctfontmanagerregisterfonturls(_:_:_:_:))、[Applying custom fonts to text](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text)。

来源：[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Color](https://developer.apple.com/design/human-interface-guidelines/color)、[Branding](https://developer.apple.com/design/human-interface-guidelines/branding)、[App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)、[tint(_:)](https://developer.apple.com/documentation/swiftui/view/tint(_:)-93mfq)、[Specifying your app's color scheme](https://developer.apple.com/documentation/xcode/specifying-your-apps-color-scheme)、[setAlternateIconName](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:))、[Apple Fonts](https://developer.apple.com/fonts/)、[Sufficient Contrast 评估标准](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria/)、[Dark Interface 评估标准](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria/)、[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)。

## 动效

动效只用来说明状态变化。实时时 GPU 被模型占用，界面动画越少越好。

| 动效 | 含义 | 时长 |
|---|---|---|
| 采集点呼吸 | 正在采集 | 1.6 秒循环 |
| 状态灯呼吸 | 连接中、重连中 | 1 秒循环 |
| 取帧闪烁 | 模型刚取了一帧 | 90 毫秒，四角亮起 |
| 输入框变控制条 | 进入实时 | 280 毫秒 |
| 取景出现 | 加入画面 | 320 毫秒 |
| 面板 | 底部面板 | 240 毫秒，用系统转场 |
| 控件反馈 | 悬停、按下 | 150 毫秒 |

曲线是 `cubic-bezier(.2, .7, .2, 1)`，用于自绘动效。系统转场不覆盖。

减弱动态效果打开时：去掉循环动画和位移，波形每 0.5 秒更新一次。减少透明度打开时：玻璃换成实色。

## 声音与触感

实时会话是听觉产品，提示音和触感是设计语言的一部分。下表是提议规格，尚未制作。

| 事件 | 提示音 | 触感 |
|---|---|---|
| 实时开始 | 上行两音，短 | 轻 |
| 实时结束 | 下行两音，短 | 轻 |
| 暂停 | 单音，低 | 警告 |
| 恢复 | 同开始 | 轻 |
| 静音切换 | 无 | 选择 |
| 主动提醒 | 无，模型开口本身就是提示 | 无 |

提示音不能被模型的麦克风当成用户说话，要从回声消除的参考信号里走。

## 图标

线性图标，24 格，线宽 1.7，圆头。原生端除了品牌和实时图标，都用 SF Symbols 和 Material Symbols，对照表见 [组件清单](06-components.md#图标)。

## 语气

文案是设计语言的一部分。像一个靠谱的朋友：直接、平静、不邀功。规则见 [文案与多语言](09-i18n-copy.md)。
