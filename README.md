# MiniCPM 设计

从 OpenBMB 社区出发，以跨端应用展示并推进 LES 为主的端侧推理效能。这个仓库目前承载 iOS、Android、macOS、Windows、Linux 和 Web 的 UI/UX 设计：一个可操作的网页原型、设计文档和 token，以及 [`apps/`](apps/) 中的客户端骨架。Windows 和 Linux 当前主要由 Web 交付，原生端遵循各自平台的控件与交互。

核心目标是证明并提升 OpenBMB 的端侧技术能力，积极探索新技术；隐私优先的使用场景让这些能力成为可用的 App。技术路线兼顾效能、研究成果与可维护性，不以最快产出产品为首要目标。

现阶段仍是 UI/UX 设计与客户端骨架，计算后端尚未选定或接入。工作区采用**“UI/UX 主线 + Backend 独立实验”双轨解耦**（见 [项目路线与双轨分工](docs/14-roadmap.md)）：

- **UI/UX 与客户端主线（当前重心）：** 持续完善 Web、Desktop、Mobile 三端 UI/UX 设计与 `apps/` 客户端骨架，现阶段重点推进 **Web、iOS、macOS**。
- **Backend 调研与实验轨道（独立隔离）：** 推理架构对比、Core AI 转换与 LES 判别实验统一收敛在 [`experiments/`](experiments/README.md)，在选型定案前不侵入主设计文档与客户端代码。首发目标仍为全球 App Store（暂不含中国大陆）。

文案仍是草案，网页继续用于验证交互。客户端若装到真机，只用个人设备的免费签名，不注册付费开发者计划，不用 TestFlight。见 [开发期合规](docs/12-compliance.md)。

## 从这里开始

| 想做的事 | 打开 |
|---|---|
| 操作产品 | [`index.html`](index.html) |
| 一次看完所有状态 | [`states.html`](states.html) |
| 理解为什么这样设计 | [设计思想](docs/01-philosophy.md) |
| 改颜色 | [`tokens/`](tokens/)，然后运行 `node tools/tokens.mjs` |
| 交给开发 | [平台落地](docs/07-platforms.md#交接方式) |
| 看还有什么没定 | [决策记录](docs/10-decisions.md) |
| 确认当前目标和双轨分工 | [项目路线与双轨分工](docs/14-roadmap.md) |
| 看合规和上架 | [开发期合规](docs/12-compliance.md) |
| 对照现有客户端怎么写界面 | [`refs/`](refs/README.md) |
| 运行真实 Web 客户端 | [`apps/web`](apps/web/README.md) |
| 在 Mac 上继续 iOS 客户端 | [`apps/ios`](apps/ios/README.md) |
| 接入推理后端 | [客户端架构](docs/11-client-architecture.md#推理接口) |
| 查看独立后端调研与实验 | [`experiments/`](experiments/README.md) |

用浏览器直接打开 HTML 文件，不需要服务器。

## 文档

| 文档 | 内容 |
|---|---|
| [01 设计思想](docs/01-philosophy.md) | 产品是什么、用户、八条原则、取舍 |
| [02 设计语言](docs/02-design-language.md) | 颜色角色、双轨波形、文字、动效、声音 |
| [03 信息架构](docs/03-structure.md) | 对象模型、两种形态、页面、主要流程 |
| [04 实时会话](docs/04-live-session.md) | 状态模型、打断、质量下降、结束方式 |
| [05 状态矩阵](docs/05-states.md) | 所有状态和打开它们的参数 |
| [06 组件清单](docs/06-components.md) | 系统、组合、自绘三类组件，图标对照 |
| [07 平台落地](docs/07-platforms.md) | 四端的控件映射和平台限制 |
| [08 隐私设计](docs/08-privacy.md) | 承诺、信号、在线备用的同意 |
| [09 文案与多语言](docs/09-i18n-copy.md) | 语气、四语术语表、AI 告知与法律页 |
| [10 决策记录](docs/10-decisions.md) | 已定、待确认、待定 |
| [11 客户端架构](docs/11-client-architecture.md) | `apps/` 的结构、推理接口、空实现 |
| [12 开发期合规](docs/12-compliance.md) | 按全球发布设计的要求、在线备用同意、个人设备测试限制 |
| [13 首次发布与商店政策](docs/13-release-and-store-policy.md) | 发布前清单、个人与组织账号、国区（待扩展调研 / 待定） |
| [14 项目路线与双轨分工](docs/14-roadmap.md) | 项目目标、UI/UX 三端演进主线与 Backend 独立实验的双轨边界 |

后端推理架构对比、Core AI 转换实验与端侧 MoE 调研已独立归入 [`experiments/README.md`](experiments/README.md)。

## 原型怎么用

- 右上角“原型状态”切换状态。手机宽度下在标题面板里，实时时在“更多”里。
- 地址栏参数能直接打开任意状态，列表在 [状态矩阵](docs/05-states.md)。
- 缩小窗口到 820 以下，就是手机形态。
- 默认打开第一阶段：只有看图模型，没有实时。全能模型和实时是下阶段的预留设计，在“原型状态”里切换，或者加 `?stage=2`。
- 所有数据都是模拟的。大多数设置只保存选择，不改变界面。

## 怎么继续调整

1. 改之前先看这个改动属于产品层还是表现层，见 [设计语言](docs/02-design-language.md)。
2. 原型只保留一份，直接改 `index.html`，回退用 git 历史。推送到 `main` 后，在 Actions 里手动运行 Pages 发布（`gh workflow run pages.yml --ref main`），[线上页面](https://icebluesakura.github.io/minicpm-design/)才会更新。
3. 颜色改 `tokens/*.json`，运行 `node tools/tokens.mjs` 同步到原型并检查对比度。
4. 新增状态时，同时加参数、加到 `states.html`、加到状态矩阵。
5. 决定了什么就记到决策记录。

## 文件

| 文件 | 说明 |
|---|---|
| `index.html` | 当前原型 |
| `states.html` | 状态总览 |
| `tokens/` | 颜色、尺寸、动效、实时常量 |
| `tools/tokens.mjs` | 同步 token 到原型和 `apps/`，检查对比度 |
| `docs/` | 设计文档 |
| `apps/` | 真实客户端：Web 和 iOS |
| `experiments/` | 独立后端调研、架构对比与隔离实验脚本（不接正式后端，见 [`experiments/README.md`](experiments/README.md)） |
| `refs/` | 上游参考仓库（submodule），只读，说明见 [`refs/README.md`](refs/README.md) |
