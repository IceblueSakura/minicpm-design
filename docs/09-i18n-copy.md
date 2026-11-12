# 文案与多语言

第一阶段支持 English、简体中文、繁體中文（台灣）、繁體中文（香港）。网页原型仍只有简体中文；iOS 客户端使用原生 String Catalog 接入四语，简体中文是源语言。现阶段重点是原型的交互展示和 SwiftUI 原生用法，不扩展真实服务。

全球发布不能只有简体中文：Web 的界面先补 English，台湾和香港两列仍按下面的术语表做，需要母语审校。政策页每种语言各一份。

字符串不必等全部界面定稿才抽。隐私、法律、AI 身份告知和在线备用的说明现在就要进消息表，见 [开发期合规](12-compliance.md)。其余字符串可以等界面稳定后一次补齐。

## 文案原则

| 原则 | 例子 |
|---|---|
| 先说发生了什么，再说能做什么 | 连不上本机模型。它没有响应，你写的内容会留在这里。 |
| 写结果，不写机制 | 回答更完整，响应更慢 |
| 第二人称称呼用户，第三人称“它”称呼模型 | 它现在听不到也看不到 |
| 不用感叹号，不卖萌，不道歉 | 用“没有发出去”，不用“抱歉，发送失败了！” |
| 状态短，说明完整 | 状态词 2–6 字，说明是完整句子 |
| 隐私声明说事实 | 只在这台设备上处理，内容不会离开 |
| 按钮用动词，写清后果 | 下载 6.0 GB、外放继续、带上摘要新开 |

模型用“它”，产品名用 MiniCPM。实时转写里说话人叫“你”和“MiniCPM”。

### 错误文案结构

一句话说事实，一句话说下一步，再加一个动作。

> **没有麦克风权限** 在系统设置里允许后重试，或者先用文字继续。 [重试] [用文字]

用户的输入如果保留了，要说出来。

### 词汇禁区

默认界面不出现：推理、量化、token、KV、上下文窗口、Agent、Skill、Harness、后端、WebSocket、参数名。这些词只出现在高级设置、开发者页面和“显示技术信息”打开之后。

规格的精度标记 Q4、F16 是例外，用户决定保留，只作为“轻量”“完整”旁边的小字，不单独出现。

## 语言标识

| 语言 | BCP 47 | Apple | Android 资源目录 | 网页 `lang` |
|---|---|---|---|---|
| English | `en` | `en` | `values` | `en` |
| 简体中文 | `zh-Hans` | `zh-Hans` | `values-b+zh+Hans` | `zh-Hans` |
| 繁體中文（台灣） | `zh-Hant-TW` | `zh-Hant-TW` | `values-b+zh+Hant+TW` | `zh-Hant-TW` |
| 繁體中文（香港） | `zh-Hant-HK` | `zh-Hant-HK` | `values-b+zh+Hant+HK` | `zh-Hant-HK` |

Apple 的台湾和香港资源分开建，不能把香港文案放进通用繁体资源。iOS 的界面语言由系统选择；应用内“界面语言”打开系统的 App 设置，不维护第二套语言偏好，也不在根视图强行覆盖 `locale`。这样 SwiftUI、Foundation 和系统控件使用同一套语言选择。

语言列表用各语言自己的名字显示，不翻译。

## 术语表

这是第一版术语，**繁体两列需要母语审校**。香港和台湾用词有实际差异，不能用简繁转换生成。

### 核心概念

| 概念 | 简体中文 | 台灣 | 香港 | English |
|---|---|---|---|---|
| 对话 | 对话 | 對話 | 對話 | Chat |
| 新对话 | 新对话 | 新對話 | 新對話 | New chat |
| 临时对话 | 临时对话 | 臨時對話 | 臨時對話 | Temporary chat |
| 实时会话 | 实时会话 | 即時對話 | 即時對話 | Live |
| 应用场景 | 应用场景 | 應用情境 | 應用場景 | Scene |
| 模型 | 模型 | 模型 | 模型 | Model |
| 记忆 | 记忆 | 記憶 | 記憶 | Memory |
| 已记住的内容 | 已记住的内容 | 已記住的內容 | 已記住的內容 | Saved memories |
| 主动提醒 | 主动提醒 | 主動提醒 | 主動提示 | Nudges |
| 这台设备 | 这台设备 | 這部裝置 | 此裝置 | This device |
| 在线备用 | 在线备用 | 線上備用 | 線上備用 | Online fallback |
| 隐私政策 | 隐私政策 | 隱私權政策 | 私隱政策 | Privacy Policy |
| 使用条款 | 使用条款 | 使用條款 | 使用條款 | Terms of Use |
| 本机处理 | 本机处理 | 在裝置上處理 | 在裝置上處理 | On device |
| 规格 | 规格 | 規格 | 規格 | Size |
| 轻量（规格） | 轻量 | 輕量 | 輕量 | Lite |
| 完整（规格） | 完整 | 完整 | 完整 | Full |
| 全能（模型类型） | 全能 | 全能 | 全能 | All-in-one |
| 看图（模型类型） | 看图 | 看圖 | 看圖 | Vision |
| 拍照提问 | 拍照提问 | 拍照提問 | 拍照提問 | Ask with a photo |
| 说话输入 | 说话输入 | 語音輸入 | 語音輸入 | Dictate |
| 定时通知 | 定时通知 | 定時通知 | 定時通知 | Scheduled notification |
| 备份 | 备份 | 備份 | 備份 | Backup |
| 远看模式 | 远看模式 | 遠看模式 | 遠看模式 | Far view |

“主动提醒”是模型在实时里先开口，“定时通知”是系统到点发通知，两个词不要混用。

### 场景

| ID | 简体中文 | 台灣 | 香港 | English |
|---|---|---|---|---|
| `life` | 生活助手 | 生活助理 | 生活助手 | Everyday |
| `work` | 工作助手 | 工作助理 | 工作助手 | Work |
| `game` | 游戏助手 | 遊戲助理 | 遊戲助手 | Gaming |
| `community` | 社区助手 | 社群助理 | 社群助手 | Community |

“社区”在港台更偏居住社区，线上社区用“社群”。

### 差异最大的日常词

| 简体中文 | 台灣 | 香港 | English |
|---|---|---|---|
| 隐私 | 隱私 | **私隱** | Privacy |
| 设置 | 設定 | 設定 | Settings |
| 默认 | 預設 | 預設 | Default |
| 文件 | 檔案 | 檔案 | File |
| 数据 | 資料 | 資料 | Data |
| 屏幕 | 螢幕 | 螢幕 | Screen |
| 麦克风 | 麥克風 | **咪高風** | Microphone |
| 摄像头 | 相機 | 相機 | Camera |
| 移动网络 | 行動網路 | **流動數據** | Cellular |
| 联网 | 連網 | 連線 | Online |
| 缓存 | 快取 | 快取 | Cache |
| 软件 | 軟體 | **軟件** | Software |
| 撤销 | 復原 | 還原 | Undo |
| 视频 | 影片 | 影片 | Video |
| 音频 | 音訊 | 音訊 | Audio |
| 网络 | 網路 | **網絡** | Network |

### 实时控制

这些文字在紧凑形态下空间最紧。

| 控制 | 简体中文 | 台灣 | 香港 | English（≤ 6 字符） |
|---|---|---|---|---|
| 麦克风 | 麦克风 | 麥克風 | 咪高風 | Mic |
| 画面 | 画面 | 畫面 | 畫面 | Video |
| 定格提问 | 定格提问 | 定格提問 | 定格提問 | Freeze |
| 先听我说 | 先听我说 | 先聽我說 | 先聽我說 | Wait |
| 转文字 | 转文字 | 轉文字 | 轉文字 | Type |
| 更多 | 更多 | 更多 | 更多 | More |
| 继续 | 继续 | 繼續 | 繼續 | Resume |
| 结束 | 结束 | 結束 | 結束 | End |

状态词：

| 状态 | 简体中文 | English |
|---|---|---|
| 聆听 | 聆听中 | Listening |
| 你在说 | 正在听你说 | Hearing you |
| 回应 | 正在回应 | Replying |
| 重叠 | 听到你了，先停下 | Go ahead |
| 暂停 | 已暂停 | Paused |
| 重连 | 正在重连 | Reconnecting |
| 模型重启 | 正在重启 | Restarting |

取景标签用短形式：

| 简体中文 | English |
|---|---|
| 本机处理 · 每秒看 1 帧 | On device · 1 fps |
| 正在上传 · 每 2 秒看 1 帧 | Uploading · 0.5 fps |
| 模型看不到画面 | Video off |

## 长度预算

宽度测试结论：英文在桌面都放得下，紧凑形态有两处超出。控制按钮可用宽度 50–56px，“Let me talk”需要 62px；取景标签可用 198px，“On this device · 1 frame per second”需要 239px。

上面的术语已经按这个结果收短。规则：

| 位置 | 预算 |
|---|---|
| 实时控制按钮 | 中文 4 字，英文 6 字符 |
| 状态词 | 中文 9 字，英文 16 字符，超出换行 |
| 取景标签 | 中文 12 字，英文 20 字符 |
| 按钮 | 中文 8 字，英文 18 字符，超出时纵向排列 |
| 设置项名称 | 允许换行，不截断 |

隐私相关文字不能截断。放不下就换行或换短句。

iOS 使用 Dynamic Type，不为了英文长文案缩小字号。辅助功能字号下，设置项的说明与操作改成纵向排列；对话的长横幅移入可滚动内容，输入区仍固定在底部，避免横幅向上越过导航栏。常规字号保留原来的紧凑布局。

## 格式

| 项目 | 规则 |
|---|---|
| 数字和单位 | 用系统格式化器。文件大小、时长、日期不要拼字符串 |
| 中英混排 | 简体中文和数字、拉丁字母之间留空格，原型已遵守。繁体沿用，审校时确认 |
| 引号 | 简体“ ”，繁体「 」，英文 “ ” |
| 复数 | 英文用 ICU 或平台复数规则，比如 `1 time` 和 `2 times` |
| 日期 | 相对时间用系统格式化，比如“周三”不写死 |
| 排序 | 语言列表固定顺序，其他列表按系统规则 |

## 全球发布要先有的文案

这些句子是草案，和别的文案一样还没定稿。中文占位符用 `{host}`、`{运营方}`，英文用 `{host}`、`{operator}`。不要拆开拼接。

| 位置 | 简体中文 | English |
|---|---|---|
| 欢迎页和新对话空状态 | 你在和 AI 模型对话，它可能出错，重要信息请核实。 | You are talking to an AI model. It can be wrong. Check anything important. |
| AI 回答的无障碍标签 | 以“AI 回答”开头 | Starts with “AI answer” |
| 体检等场景 | 仅帮助理解，不能替代医生。 | This only helps you read it. It is not a substitute for a doctor. |
| 在线备用说明 | 开启后，当这台设备跑不了时，你发出的文字、图片和文件会发送到 {host} 处理。{host} 由 {运营方} 运营，处理方式见其隐私政策。端侧对话不受影响。 | When this device cannot run the model, the text, images, and files you send go to {host}. {host} is operated by {operator}. See their privacy policy. On-device chats stay on this device. |
| 同意 / 拒绝 | 开启并同意 / 暂不开启 | Turn on and agree / Not now |
| 发送前 | 将发送到 {host} | Will be sent to {host} |
| 回答下方 | 经 {host} 处理 | Processed by {host} |
| 欢迎页底部 | 隐私政策 · 使用条款 | Privacy Policy · Terms of Use |
| iCloud 备份 | 存在你自己的 iCloud，开发者看不到。 | Stored in your iCloud. The developer cannot see it. |

“关于与法律”页要有：版本号、隐私政策、使用条款、开源许可（含 MiniCPM 模型许可）、联系与反馈、无障碍说明。链接从同一处配置读取，现在是 `https://example.com/privacy`、`/terms`、`/support`、`/accessibility`，邮箱 `support@example.com`。

### iOS 的目录

- `apps/ios/MiniCPM/Localizable.xcstrings` 源语言是 `zh-Hans`，已接入 English、台湾繁体和香港繁体。新增合规文案时同步补齐四语。
- 相机、麦克风、相册、语音识别的用途说明已在 `InfoPlist.xcstrings` 接入四语，`MiniCPM.xcodeproj/project.pbxproj` 的 `INFOPLIST_KEY_*` 保留源文案。用途说明和应用内的权限说明保持一致；在 Mac 上构建时检查最终权限提示的语言。

### Web 的消息表

中文现在写在 `apps/web/src/ui/` 的组件里。抽到新建的 `apps/web/src/i18n/`，界面只读消息表。`apps/web/index.html` 的 `lang="zh-Hans"` 和 `selectors.ts` 里的 `toLocaleDateString('zh-Hans')` 改成跟随当前语言。设置里已有四语列表，它还不切换文案。

## 字符串结构

跨平台的显式键名按界面位置和含义组织，不用序号。

```text
live.dock.mute          麦克风
live.dock.hush          先听我说
live.hold.call.title    来电中，实时已暂停
live.hold.call.sub      麦克风交给了电话，它现在听不到也看不到。
scene.life.name         生活助手
privacy.promise.local   只在这台设备上处理，内容不会离开
```

iOS 沿用 SwiftUI 的源文字面量和 Xcode 自动抽取，不为了与 Web 同名而额外包一层键名查找。静态界面文字使用 SwiftUI 的本地化初始化器；需要提前生成 `String` 的动态文案使用 `String(localized:)`，不能把未本地化的字符串变量当作已翻译的界面文字。资源在 `apps/ios/MiniCPM/Localizable.xcstrings`，系统权限说明在 `InfoPlist.xcstrings`。两者都由 Xcode 编译，不生成另一份运行时词典。

同一源文在不同交互里含义不同时，使用带语义键、`defaultValue` 和注释的 `LocalizedStringResource`。例如欢迎页的“继续”是 Continue，暂停下载后的“继续”是 Resume，不能共享一条英文译文。

给译者的说明应包含出现位置、长度预算、语气、占位符含义，尤其是隐私分支和系统格式化后的值。Apple 的 String Catalog 和 Android 的字符串资源都支持注释。

一句话不要拆成几段拼接，语序在不同语言里不同。需要变量时用占位符。

英文数量使用 String Catalog 的复数变化；同一句有两个数量时，各自使用 substitution，不只根据第一个数量决定整句。容量、时长先用 Foundation 格式化，再插入完整句子，不在译文后面手动补 `GB` 或“秒”。

用户输入、对话标题、真实文件名、记忆、模型回答和模型提示词不是界面文案，不随界面语言自动翻译。应用新建图片的默认文件名可以本地化；旧附件和用户文件名保持原样。原型的演示引擎仍使用既有触发词和占位回答，不把翻译当成真实模型语言能力。

本轮译文由 `agy` 的 `gemini-3.8-flash-high` 生成，按上述术语表检查；繁体两列仍需母语审校。

## 字体

繁体的台湾和香港字形有差异，同一个字符要按语言选字形。

- 原生端用系统字体，正确设置语言标识。Apple 平台有 PingFang SC、TC、HK 三组。
- Android 的 AOSP 字体配置没有香港专项，字形取决于厂商，要在实机上看。
- 网页端按 `lang` 切字体栈，不能全局固定 `SC` 字体。

原型里 `--font` 现在是简体优先，第一阶段接入繁体时要拆成三组。

## 模型回答的语言

界面语言和回答语言分开设置：跟随界面、跟随我说的语言、或指定语言。

粤语是待定问题：香港用户说粤语时，识别和语音回答能否支持，取决于模型能力。见 [决策记录](10-decisions.md)。

## 布局方向

第一阶段没有从右到左的语言。原生端仍然用 leading 和 trailing，不写死左右，避免以后返工。

双轨波形的时间轴是例外，始终从左到右，最新在右。
