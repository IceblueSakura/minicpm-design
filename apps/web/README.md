# MiniCPM Web

真实 Web 客户端的初版。界面、状态和规则是真的，推理和下载是空实现。样式来自原型，这是 Web 的最终样式。结构和接口见 [客户端架构](../../docs/11-client-architecture.md)。

```sh
npm install
npm run dev      # http://localhost:5173
npm test
npm run build
```

## 结构

| 路径 | 内容 |
|---|---|
| `src/engine/types.ts` | 推理接口：`Engine`、`ModelStore`、`GenerationEvent` |
| `src/engine/stub.ts` | 空实现 |
| `src/engine/index.ts` | **接入 WebGPU 后端改这里** |
| `src/core/` | 状态和规则，不依赖 React。`selectors.ts` 里是所有隐私文案 |
| `src/ui/` | React 界面 |
| `src/styles/app.css` | 从原型移植，去掉了实时部分 |
| `src/styles/tokens.css` | 由 `tools/tokens.mjs` 生成，不要手改 |

## 打开失败状态

`?stub=` 让空实现模拟失败，可以写多个。

| 参数 | 状态 |
|---|---|
| `?stub=nogpu` | 这个浏览器跑不了本机模型 |
| `?stub=offline` | 发送时连不上本机模型 |
| `?stub=oom` | 载入时内存不够 |
| `?stub=empty` | 这个浏览器里还没有模型 |
| `?theme=dark` | 强制深色 |

清掉站点数据就回到首次启动。

发“记住……”“查一下……”“每天……提醒我……”能走通记忆、联网询问、定时通知卡片。
