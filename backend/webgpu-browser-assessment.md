# WebGPU 浏览器进展与 Web 端侧推理（自定义算子 / LES）调研评估

- **日期：** 2026-11-14
- **状态：** 调研归档（结论已写入 [决策记录](../docs/10-decisions.md)，Web 侧真实客户端演进与 WebGPU 推理后端开发已决定推迟）
- **调研目标：** 评估 Chrome、Firefox、Safari（macOS / iOS / iPadOS 三端）截至 2026-11 的 WebGPU 能力边界，判断能否基于 WebGPU 与自定义 WGSL 算子开发 Web 端侧推理，以及能否在浏览器载体上展示 OpenBMB LES 推理能力。

事实把握度说明：无标记为已核实官方文档、源码、发行说明或公开基准文献；**[推断]** 为基于机制推导的结论；**[待实测]** 须在目标真机浏览器实测确认。

---

## 1. 先看结论

1. **推迟 Web 侧推理与客户端开发的原因：**
   - **三端特性未对齐，自定义算子维护成本高：** Chrome 已稳定提供 `shader-f16`、`dot4I8Packed`、`subgroups` 与 `wasm64`；Safari 稳定版（27.2）尚无 `subgroups`（刚进 STP 249 / 27.3 Beta）与 `wasm64`；Firefox 仅在 Windows 与 Apple Silicon macOS 默认开启 WebGPU，且仍不支持 `shader-f16` 与 `subgroups`。若自写高性能 WGSL 算子，需同时维护多套内核变体并做硬件 Autotuning。
   - **iOS / iPadOS 浏览器无法承载中大型模型：** 移动端所有浏览器均受限于 WebKit / `WKWebView` 内核；iOS Jetsam 将页面 `WebContent` 与 `com.apple.WebKit.GPU` 合并计入严苛的进程内存配额（通常 1–2 GB+ 即触发无预警强杀且 JS 不可捕获），移动端 WebGPU 实务安全上限仅约 0.5B–1.5B（Q4）。**[待实测]**
   - **浏览器沙盒不适合作为 LES（闪存按需专家流式）主战场：** 原生端依赖 `preadv` 直接把 ~1.29 MiB 专家块写入统一内存共享 `MTLBuffer`；浏览器缺乏闪存到 `GPUBuffer` 的零拷贝直通路径，OPFS `FileSystemSyncAccessHandle.read` 到 `queue.writeBuffer` 会引入多次内存拷贝、Page Cache 不可控膨胀与 Worker 同步阻塞，无法代表 LES 在端侧的真实吞吐与能效上限。
2. **保留的后续选项：**
   - 本调研不否定 Web 端用轻量模型（桌面端 1B–4B Q4）做纯前端隐私推理的技术可行性。若未来重启 Web 侧开发，优先复用 `llama.cpp` WebGPU / WebLLM 等社区运行时骨架并仅针对热点算子定制 WGSL，或在桌面端以“双 Worker（OPFS + `SharedArrayBuffer` + WebGPU Slot Bank）+ 轻量 MoE”制作交互式 LES 机制演示。

---

## 2. 三大浏览器引擎 WebGPU 进展矩阵（截至 2026-11）

### 2.1 平台可用性与底层后端

| 浏览器与引擎 | Windows | macOS | iOS / iPadOS | Linux | Android |
|---|---|---|---|---|---|
| **Chrome / Edge**（Blink / Dawn，v155–156） | **默认开启**（v113+，D3D12） | **默认开启**（v113+，Metal） | 受限于 WebKit / `WKWebView`（同 Safari） | **部分默认开启**（v144 Intel Gen12+，v147–148 NVIDIA，Vulkan） | **默认开启**（v121+ Qualcomm/ARM，v146 GLES 3.1 兼容模式） |
| **Safari**（WebKit，v26 → v27.2 / 27.3 Beta） | 不适用 | **默认开启**（Safari 26+，Metal） | **默认开启**（Safari 26+，Metal） | 不适用 | 不适用 |
| **Firefox**（Gecko / Rust `wgpu`，v155 起双周发布，当前约 v158–159） | **默认开启**（v141+，D3D12） | **默认开启**（v145 渐进，v147+ 全量覆盖 Apple Silicon） | 受限于 WebKit / `WKWebView`（同 Safari） | **默认关闭**（Nightly 或 `about:config` 手动开启） | **默认关闭**（开发中，`about:config` 实验开启） |

> 注：在 iOS 与 iPadOS 上，Chrome、Firefox、Edge 等浏览器受系统内核约束均运行在 WebKit 之上，WebGPU 能力与内存红线与 Safari 一致。

### 2.2 自定义推理算子关键能力对比

| 能力 / WGSL 扩展 | 对推理的作用 | Chrome（v155–156） | Safari（v27.2 稳定 / v27.3 Beta） | Firefox（v155–159） |
|---|---|---|---|---|
| **`shader-f16`**（`enable f16;`） | 减半权重与激活访存带宽，FP16 ALU 加速 | **支持**（v155–156 补齐 Linux NVIDIA） | **支持**（Safari 26.0+，对 `f16`/`f32` 显式转换校验极严） | **不支持**（仅可用 `f32` 运算） |
| **`subgroups`** | SIMD 线程束内洗牌/归约，加速 MatMul、Attention、Norm | **支持**（v134 核心落地；v144 `subgroup_id`；v151–152 `@subgroup_size`） | **v27.2 不支持**；STP 249（`317145@main`）与 **v27.3 Beta（2026-11-03）** 刚合入 | **不支持**（Bugzilla 1955417 跟踪中） |
| **`packed_4x8_integer_dot_product`**（`dot4I8Packed`） | 4×8-bit 打包整数点积，加速 INT8/INT4 量化内核 | **支持**（v123+，无硬件支持时提供软件回退） | **非全端稳定基线**（需运行时检测与回退） | **不支持 / 后端依赖** |
| **协作矩阵**（`subgroup_matrix`） | 对接 Tensor Core / `simdgroup_matrix` 加速大矩阵 GEMM | **实验旗标**（`chromium-experimental-subgroup-matrix`） | **未开放** | **未开放** |
| **Wasm Memory64**（`wasm64`） | 突破 32 位 Wasm 4 GB 线性内存上限 | **支持**（v133+） | **稳定版不支持**（STP 251/252 预览中） | **支持**（v134+） |
| **低开销传参与视图重解释** | 减少小参数 UBO 创建、支持混合量化打包读取 | **支持**（v149–150 `Immediates`；v153–154 `buffer_view`） | **未跟进** | **未跟进** |

---

## 3. 各端深度瓶颈与工程约束

### 3.1 Safari 三端（macOS / iOS / iPadOS）关键差异
- **版本稳定性演进：** Safari 26.0 首发后，Safari 27.0–27.2（27.2 于 2026-10-26 发布）修复了 `maxStorageBuffersInFragmentStage` 限制丢失、直接传递 `GPUTexture` 与 MSAA resolve 校验失败、WGSL 二元表达式校验，以及 `executeBundles()` 配合间接绘制严重掉帧等问题。
- **macOS Safari：** Apple Silicon 统一内存池较大，`maxBufferSize` 可通过 `requiredLimits` 申请至 1–4 GB；但因稳定版尚无 `wasm64`，加载多 GB 模型不能先读入 Wasm 线性堆，须从 OPFS 分片流式直接 `writeBuffer` 进 `GPUBuffer`。
- **iPadOS Safari：** M 系列 iPad 物理内存较大，但仍受移动版 WebKit 页配额约束，连续扩容或大块单 Buffer 仍存在 OOM 风险。**[待实测]**
- **iOS Safari（最大瓶颈）：**
  1. 默认 `maxBufferSize` 保守（通常 256 MB 起步）；即使通过 `requiredLimits` 申请更大上限，**iOS Jetsam** 仍会在总内存压力触顶时无预警强杀标签页，JS 无法通过 `try/catch` 或 `device.lost` 优雅兜底。**[待实测]**
  2. 长上下文 Prefill（如单次数百以上 token 的中间激活脉冲）与 KV Cache 扩容跳档极易触顶，必须强制做 **Chunked Prefill + 分片权重 Buffer + 显式 `.destroy()`**。
  3. **Lockdown Mode（锁定模式）** 下 WebGPU 等低层图形能力可能被限制或禁用；且切后台不允许持续 GPU 计算。

### 3.2 自定义 WGSL 算子的共性障碍
1. **Dispatch Overhead（算子调度墙）：** 2026 年跨硬件实证研究测得单次 WebGPU dispatch 在 Vulkan 底层约耗 24–36 µs、Metal 约 32–71 µs，端到端单操作开销可达 ~95 µs；Firefox 因 `wgpu` 与 IPC 开销更高。batch=1 自回归 Decode 必须通过自定义 WGSL 算子做深度 **Kernel Fusion**（融合 Norm、RoPE、反量化点积与激活），否则调度开销会吞噬大量吞吐。
2. **多变体与 Autotuning 成本：** 在三端特性不对齐的情况下，同一核心算子至少需维护 `f16 + subgroups`（Chrome）、`f16 + workgroup shared memory`（Safari ≤27.2）、`f32` 打包解包（Firefox/老旧 GPU）三套变体，且不同 GPU 架构的最优 tile 形状差异很大。
3. **缺少原生张量矩阵单元：** `subgroup_matrix` 尚未跨端标准化，WebNN 在 Safari 与 Firefox 也均未成熟，因此 Prefill 与视觉编码器密集 GEMM 吞吐明显弱于原生 Core ML / Core AI / Metal。

---

## 4. 在浏览器上展示 LES 的可行性边界分析

对照 [ios-inference-options.md](ios-inference-options.md) 中的 **MiniCPM-V 4.7 35B-A3B + LES**（40 层、256 专家/层、top-8 激活；Q3_K 单专家约 1.29 MiB，总专家包约 12.9 GiB，主文件约 1.55 GiB，mmproj 约 1.04 GiB）：

1. **无法替代原生 LES 轨道作为性能主战场：**
   - **内存底盘过不了 iOS 浏览器关：** 仅主文件 + mmproj + 状态与 `c+K` 专家槽位池即需 3–4 GiB+，远超 iOS Safari Jetsam 安全水位。
   - **I/O 到 GPU 存在沙盒拷贝税：** 原生端由 C++ 调 `preadv` 一次直写共享 `MTLBuffer`；浏览器只能经 `OPFS FileSystemSyncAccessHandle.read` → JS/Wasm 内存 → `device.queue.writeBuffer` → Staging/Metal Copy，且无法像原生端那样精细绕过 OS Page Cache。大块 OPFS 顺序读可达数百 MB/s 至 1.5+ GB/s，但 ~1.29 MiB 随机偏移读在受限沙盒中的真实延迟预计明显升高。**[待实测]**
   - **并发与隔离依赖：** `SyncAccessHandle.read` 在单 Worker 内阻塞事件循环，要实现计算与读盘重叠，必须拆出 **I/O Worker + Compute Worker + `SharedArrayBuffer`**，要求托管站点配置 **COOP / COEP** 跨域隔离响应头（GitHub Pages 默认不支持直接配置此类响应头，见 [客户端架构](../docs/11-client-architecture.md#接入真实后端)）。
   - **量化核缺口：** 社区 `Q3_K` 格式无现成 WGSL 实现，需从头编写并验证数值一致性。
2. **未来若仅需“纯前端机制 Demo”时的可行替代思路：**
   - 限定在 **桌面 Chrome / Edge（16 GB+ RAM）** 运行，改用结构同源但体积更小的稀疏 MoE（如总权重 3–6 GiB、主干 ≤ 1.5 GiB）演示“无预取 vs 前瞻深度 K + 统一 LRU 槽位缓存”的实时消融过程 **[推断]**；或在桌面交付中采用浏览器 UI 直连本机 `127.0.0.1` 原生 LES 服务。

---

## 5. 对项目路线的直接影响

- 当前阶段不再投入精力实现 `apps/web` 的 WebGPU 推理后端或扩展 Web 侧复杂能力；主工作区集中推进 **iOS、macOS 原生客户端骨架与设计规范**，后端研究继续集中于 `backend/` 的 Apple / LES 独立实验轨道。
- `index.html` 原型与 `apps/web/` 既有骨架继续保留，作为交互设计验证与后续阶段重启时的起点。
