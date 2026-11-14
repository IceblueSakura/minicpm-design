# refs — 外部参考仓库

这里用 git submodule 引入八个上游只读仓库，用来对照**现有客户端界面实现**、**端侧推理引擎与桌面交互**以及**模型能力/部署契约**，不是本项目代码，不参与原型构建，也不改动其中任何文件。

原型仍然是 [`../index.html`](../index.html) 一份。客户端部分回答"结构、状态和文案在真实客户端里长什么样"，不决定本项目的样式（样式只对 Web 定稿，见 [设计语言](../docs/02-design-language.md)）；引擎与模型仓库只作只读对照基线，不直接锁定本项目的后端路线。

## 拉取

仓库是浅克隆（`.gitmodules` 里 `shallow = true`），首次克隆要带上子模块：

```sh
git clone --recurse-submodules git@github.com:IceblueSakura/minicpm-design.git
```

已经克隆过本项目的，补拉子模块：

```sh
git submodule update --init
```

需要看某个仓库的完整历史（blame、旧版本界面）：

```sh
git -C refs/minicpm-v-apps fetch --unshallow
```

## 八个仓库

| 本地路径 | 上游 | 固定提交 | 上游最近改动 | 工作区体积 |
|---|---|---|---|---|
| `refs/minicpm-v-apps` | [OpenBMB/MiniCPM-V-Apps](https://github.com/OpenBMB/MiniCPM-V-Apps) | `d0dd7a6` | 2026-10-29 | 7.5 MB |
| `refs/minicpm-o-demo` | [OpenBMB/MiniCPM-o-Demo](https://github.com/OpenBMB/MiniCPM-o-Demo) | `47709a9` | 2026-09-15 | 31 MB |
| `refs/mobilecpm` | [OpenBMB/MobileCPM](https://github.com/OpenBMB/MobileCPM) | `3943591` | 2024-07-04 | 27 MB |
| `refs/llama.cpp-omni` | [OpenBMB/llama.cpp-omni](https://github.com/OpenBMB/llama.cpp-omni) | `a64932e` | 2026-10-19 | 165 MB |
| `refs/minicpm-desk-pet` | [OpenBMB/MiniCPM-Desk-Pet](https://github.com/OpenBMB/MiniCPM-Desk-Pet) | `87dc4d7` | 2026-08-18 | 59 MB |
| `refs/minicpm-v` | [OpenBMB/MiniCPM-V](https://github.com/OpenBMB/MiniCPM-V) | `4dbbb6c` | 2026-11-09 | 564 MB |
| `refs/minicpm` | [OpenBMB/MiniCPM](https://github.com/OpenBMB/MiniCPM) | `f4293a1` | 2026-11-09 | 142 MB |
| `refs/cpm.cu` | [OpenBMB/CPM.cu](https://github.com/OpenBMB/CPM.cu) | `23aa7b7` | 2026-01-14 | 1.7 MB |

提交号固定在这里，是为了我们讨论时看的是同一份界面。升级时在对应目录检出新的上游版本，再提交新的 pin。

## refs/minicpm-v-apps —— 三端原生客户端，结构参考的首选

官方唯一的三端客户端：同一套功能分别用 Swift（iOS）、Kotlin（Android）、ArkTS（HarmonyOS）写了一遍，全部用系统控件，没有自绘 OS chrome。**信息架构和状态覆盖最全，是最该对着改的仓库。**

| 入口 | 看什么 |
|---|---|
| `MiniCPM-V-demo/Sources/Home` | 首页/会话页：空态入口卡片、输入区、浮动按钮 |
| `MiniCPM-V-demo/Sources/Settings/` | 设置页全家：`DownloadManager`（下载与进度）、`ModelConst`/`Model`（按设备内存分档的模型清单）、`ModelDetail`、`RealTimeVC`（实时理解的设置项）、`SubViews` |
| `MiniCPM-V-demo/Sources/Tutorial` | 首次启动的引导页 |
| `MiniCPM-V-demo/Sources/OCR` | OCR 结果展示 |
| `MiniCPM-V-demo/Sources/Localization/L10n*.swift` | 中英文案表与 key 组织方式 |
| `MiniCPM-V-demo/Sources/Base/Utils/MBTheme.swift` | 亮/暗色只在"单一取色入口 + 亮色→暗色映射表"里处理，另有跟随系统/始终深/始终浅三档偏好 |
| `MiniCPM-V-demo/Sources/Base/SwiftyCamera` | 拍照、录像、实时流的预览与采集界面 |
| `MiniCPM-V-demo-Android/.../minicpm_v_demo/` | 同一功能的 Kotlin 实现：`MainActivity`、`ModelManagerActivity`、`TtsActivity`、`ChatAdapter` |
| `MiniCPM-V-demo-HarmonyOS/entry/src/main/ets/` | ArkTS 实现：`pages/{Index,ModelManager,TtsPage}`、`components/{WelcomeCard,ChatMessageList,AiMessageItem,UserMessageItem,ImageSliceDialog}` |
| `PRIVACY.md`、`DOWNLOAD_zh.md` | 隐私表述与模型下载说明的现成文案 |

覆盖了聊天、图片切片设置、模型管理、TTS、首次引导、双语。**没有** macOS 客户端，也**没有**端侧/云端切换的界面表达。

`llama.cpp-omni/` 是嵌套子模块（上游 `tc-mb/llama.cpp-omni`，分支 `ios-omni`），默认没拉，要看实现再 `git submodule update --init --recursive`。

## refs/minicpm-o-demo —— 实时双工与会话界面，形态最全的一处

官方全模态 Web Demo。后端是 Python（`gateway.py`、`worker.py`、`core/`、`vad/`），**界面有两套**：`static/` 下的手写 HTML/CSS/JS 页面（中文界面，页面之间按 `/static/` 路径互引），和 `frontend/mobile/` 下的 React 重写版。`static/` 里还有一个专门画交互的 `mobile-flow-mock.html`（标题就是"移动端交互草图"），对本项目参考价值最高。

手写页面（`static/`，同一套 `duplex/duplex-shared.css`）：

| 入口 | 看什么 |
|---|---|
| `static/mobile-flow-mock.html` | **移动端交互草图**：手机外壳、双工的 live 与 soft 两屏、圆形按钮组、分页指示，自带一套 CSS 变量色板 |
| `static/index.html` | 首页：三种交互模式卡片 + 最近会话列表 |
| `static/turnbased.html` | 轮次对话；`lib/chat-eta-estimator.js` 是"还要等多久"的估算 |
| `static/omni/omni.html` | 音视频全双工（摄像头/文件两种媒体源） |
| `static/audio-duplex/audio_duplex.html`、`static/half-duplex/half_duplex.html` | 语音双工、半双工 |
| `static/mobile-omni/` | 移动版页面 + 可嵌入设置 widget（`settings-widget.{css,js}`） |
| `static/duplex/lib/` | 队列音效、音量（lufs）、会话录制、实时会话等交互层实现 |
| `static/faq/{zh,en}`、`static/session-viewer.html` | 帮助页与历史会话回看 |

React 版（`frontend/mobile/`，React 19 + TypeScript + Vite）：

| 入口 | 看什么 |
|---|---|
| `frontend/mobile/src/duplex/AudioDuplexScreen.tsx`、`VideoDuplexScreen.tsx` | 语音/视频通话全屏界面 |
| `frontend/mobile/src/duplex/{DuplexLogBubble.tsx,duplex.css,useDuplexSession.ts}` | 通话中的对话气泡、样式、会话状态机 |
| `frontend/mobile/src/shared/OmniSettingsWidget.tsx`、`settings-widget-entry.tsx` | 可嵌入设置面板的做法 |
| `frontend/mobile/src/i18n/{zh,en}.ts` | 双语 key 表，可与我们 [文案与多语言](../docs/09-i18n-copy.md) 对照 |
| `docs/site/zh/frontend/{index,components,pages,audio,duplex-session}.html` | **中文前端规格**：页面与路由、UI 组件、音频处理、双工会话各一章，含状态字段和协议细节 |

没有模型管理页，设置只有那个 widget。页面按浏览器与麦克风/摄像头的约束设计，原生端不能照搬。

## refs/mobilecpm —— 上一代 iOS 客户端，看信息架构和早期的取舍

2024 年 7 月停更的 CPM 手机客户端，Objective-C + Swift 混合。样式已经过时，**不要看它的视觉**；有用的是分层方式和一个完整客户端的页面清单。

| 入口 | 看什么 |
|---|---|
| `mobileCPM/mobileCPM/Sources/MainTabBar` | 底部 Tab 结构与切换逻辑（ObjC） |
| `mobileCPM/mobileCPM/Sources/Home` | 首页瀑布流，`Layout/`、`ViewModel/`、`Mock/`（内置模拟数据）、`Model/` 的分层 |
| `mobileCPM/mobileCPM/Sources/Chat` | 会话页与输入区，含 `UITextView` 输入、Cell 工具栏事件 |
| `mobileCPM/mobileCPM/Sources/Setting` | 设置页与模型管理 |
| `mobileCPM/mobileCPM/Sources/Base` | 网络、DB、缓存、图片、颜色等基础设施 |

Android 侧只有 `llama.cpp` 的示例，不是产品界面。

## refs/llama.cpp-omni —— 全模态 C++ 推理引擎基线

OpenBMB 主线全模态 C++ 引擎（注意：`refs/minicpm-v-apps` 内的嵌套子模块指向的是 `tc-mb/llama.cpp-omni` 的 `ios-omni` 分支，两者并列对照）。

- `app/`、`common/`、`examples/`：端侧应用与全双工多模态调用流程参考
- `ggml/`、`conversion/`、`convert_hf_to_gguf.py`：量化内核、模型转换与 GGUF 资产结构

## refs/minicpm-desk-pet —— macOS / 桌面本地伴侣应用

本地优先桌面伴侣应用，覆盖 Apple Silicon macOS 等桌面形态（Electron 壳 + `llama.cpp` sidecar）：

- `clawd-on-desk/`、`adapters/`：桌面常驻悬浮交互、状态机与本地开发工具联动
- `minicpm-sidecar/`、`llama.cpp/`、`skills/`：本地 sidecar 网关（`gateway/`）、进程生命周期管理与技能配置

## refs/minicpm-v —— 多模态模型与契约对照

MiniCPM-V / MiniCPM-o 系列多模态官方主仓库：

- `chat.py`、`omnilmm/`、`web_demos/`：官方推理入口、图像切片/预处理与聊天格式契约
- `docs/`：各版本多模态与全双工文档（含 `minicpm_o4dot5_*.md`、`minicpm_v4dot6_en.md`、`best_practice_summary_zh.md`）

## refs/minicpm —— 纯文本端侧模型与部署技能

MiniCPM5 与纯文本端侧基座主仓库：

- `skills/`：覆盖 `minicpm5-deploy-llama-cpp`、`minicpm5-deploy-mlx`、`minicpm5-deploy-litert` 等部署与微调技能模板
- `quantize/`、`tool_parsers/`、`minicpm_sala/`、`demo/`：量化脚本、工具解析器与长上下文实现

## refs/cpm.cu —— 轻量端侧 CUDA 推理与算子优化

- `cpmcu/`、`src/`、`examples/`、`scripts/`：端侧推理算子融合、量化与投机采样等底层性能优化实现参考

## 在 refs 里工作的约定

- **只读**。不要在子模块里改文件、提交或建分支；要试验就复制到 `refs/` 之外。
- 引用时带上路径和提交，例如 `refs/minicpm-v-apps/MiniCPM-V-demo/Sources/Base/Utils/MBTheme.swift@d0dd7a6`，避免上游更新后说不清是哪一版。
- 这些实现只提供结构和状态覆盖。颜色、间距、文案定稿仍以 `tokens/`、`docs/` 和原型为准；两边冲突时以本项目为准。
- 文档里引用具体平台行为时，按 [docs](../docs/) 的约定标 **[待实测]**。
