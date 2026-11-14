# 效果图

这里放 Apple 端风格与主题的效果图。只放真实渲染：Mac 上运行的 App、模拟器或 Xcode 预览的截图。不放模拟生成的图，也不拿网页原型的截图代替 App。规则见 [设计语言](../../02-design-language.md#apple-端风格与主题)。

## 现在的状态

还没有图。App 还没接主题、外观设置和字体，接上以后在 Mac 上按下面的清单渲染。

在那之前，主题的结构可以先在网页原型里看，比如 `index.html?task=report&palette=xuan&theme=dark`，参数见 [状态矩阵](../../05-states.md#主题)。原型的截图不放进这个目录。

## 命名

`<设备>-<画面>-<主题>-<外观>[-hc][-<变体>].png`

| 段 | 取值 |
|---|---|
| 设备 | `mac`、`iphone`、`ipad` |
| 画面 | `chat`、`code`、`settings-appearance`、`live` |
| 主题 | 主题 ID：`plain`、`celadon`、`xuan`、`indigo`、`wisteria`、`lab` |
| 外观 | `light`、`dark` |
| `-hc` | 打开了增强对比度 |
| 变体 | 只在比较同一维度时加，比如 `font-sarasa`、`font-noto-serif`、`accent-red`、`xxxl`（最大动态字体） |

例：`mac-chat-xuan-dark.png`、`iphone-chat-lab-dark-hc.png`、`iphone-chat-celadon-light-font-sarasa.png`。

## 清单

| # | 画面 | 设备 | 组合 | 看什么 |
|---|---|---|---|---|
| 1 | 对话：回答里有表格、代码块和测量行 | `mac`、`iphone` | 6 主题 × 浅色、深色，每台设备 12 张 | 纸面和墨色的色温；模型色只有一个主角；用户气泡不像“信息”；玻璃输入框下面的纸面 |
| 2 | 同上，增强对比度 | `iphone` | `celadon`、`lab` × 浅色、深色 | 辅助文字、分隔线、模型色加深后层次还在 |
| 3 | 设置 › 外观 | `mac`、`iphone` | `celadon` × 浅色、深色 | 主题网格的缩略、强调色（只有 Mac）、回答字体的下载说明 |
| 4 | 回答字体 | `iphone` | `celadon` 浅色 × 系统、更纱黑体、思源宋体；再加一张最大动态字体 | 行高、加粗、中英混排、繁体字形 |
| 5 | 代码块 | `mac` | `celadon` × 浅色、深色 | JetBrains Mono 和回退的苹方基线是否对齐，连字已关 |
| 6 | 强调色 | `mac` | `celadon`、`xuan` 浅色 × 系统“多色”、红色 | 控件跟系统；模型色、朱砂、琥珀不变。要等“多色”实验有结果 |
| 7 | 实时会话（下阶段） | `iphone` | `xuan` 浅色、`lab` 深色 | 朱砂和琥珀在不同纸面上仍然醒目、不和模型色混 |

## 怎么渲染

- **Mac**：窗口 1280 × 800 pt，Retina。用 `screencapture -o -l <窗口号>` 截单个窗口，不带阴影。
- **iPhone**：6.9 英寸模拟器，和 App Store 截图尺寸一致。用 `xcrun simctl io booted screenshot <文件>`。外观和增强对比度用 `xcrun simctl ui booted appearance dark`、`xcrun simctl ui booted increase_contrast enabled` 切换，命令以当前 Xcode 的 `xcrun simctl ui help` 为准。
- **状态**：用 `apps/ios/README.md` 里的 `-stub` 启动参数打开对应状态。主题接进 App 时再加选主题的启动参数，写进那份 README。
- **文件**：PNG 原图，不缩放、不加设备外框、不做有损压缩，可以无损压缩。

## 渲染记录

每批图记一行，方便以后对照。

| 日期 | 文件 | 系统和 Xcode 版本 | 设备 | 备注 |
|---|---|---|---|---|
