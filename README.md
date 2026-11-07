# MiniCPM 设计

MiniCPM 客户端的设计资料：一个可操作的网页原型，加上设计文档和 token。最终会转成 Android、iOS、macOS 和 Web 的原生 UI。

现阶段是草案，文案都未定，主要用网页验证大致的交互逻辑，先不做真机测试。

## 从这里开始

| 想做的事 | 打开 |
|---|---|
| 操作产品 | [`index.html`](index.html) |
| 一次看完所有状态 | [`states.html`](states.html) |
| 理解为什么这样设计 | [设计思想](docs/01-philosophy.md) |
| 改颜色 | [`tokens/`](tokens/)，然后运行 `node tools/tokens.mjs` |
| 交给开发 | [平台落地](docs/07-platforms.md#交接方式) |
| 看还有什么没定 | [决策记录](docs/10-decisions.md) |
| 对照现有客户端怎么写界面 | [`refs/`](refs/README.md) |

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
| [08 隐私设计](docs/08-privacy.md) | 承诺、信号、规则 |
| [09 文案与多语言](docs/09-i18n-copy.md) | 语气、四语术语表、长度预算 |
| [10 决策记录](docs/10-decisions.md) | 已定、待确认、待定 |

## 原型怎么用

- 右上角“原型状态”切换状态。手机宽度下在标题面板里，实时时在“更多”里。
- 地址栏参数能直接打开任意状态，列表在 [状态矩阵](docs/05-states.md)。
- 缩小窗口到 820 以下，就是手机形态。
- 默认打开第一阶段：只有看图模型，没有实时。全能模型和实时是下阶段的预留设计，在“原型状态”里切换，或者加 `?stage=2`。
- 所有数据都是模拟的。大多数设置只保存选择，不改变界面。

## 怎么继续调整

1. 改之前先看这个改动属于产品层还是表现层，见 [设计语言](docs/02-design-language.md)。
2. 原型只保留一份，直接改 `index.html`，回退用 git 历史。推送到 `main` 后，[线上页面](https://icebluesakura.github.io/minicpm-design/)会自动更新。
3. 颜色改 `tokens/*.json`，运行 `node tools/tokens.mjs` 同步到原型并检查对比度。
4. 新增状态时，同时加参数、加到 `states.html`、加到状态矩阵。
5. 决定了什么就记到决策记录。

## 文件

| 文件 | 说明 |
|---|---|
| `index.html` | 当前原型 |
| `states.html` | 状态总览 |
| `tokens/` | 颜色、尺寸、动效、实时常量 |
| `tools/tokens.mjs` | 同步 token，检查对比度 |
| `docs/` | 设计文档 |
| `refs/` | 上游参考仓库（submodule），只读，说明见 [`refs/README.md`](refs/README.md) |
