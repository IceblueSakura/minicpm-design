# Core AI 转换与 E1 运行实验

日期：2026-11-13。本文记录在 `sakura-mac` 上针对 MiniCPM-V 4.7 1B 文字主干的导出、Mac 执行和 [E1](ios-inference-options.md#e1ios-能否执行最小动态专家与混合状态路径下一项) 小图对照。日常转换工作区已收敛至 [`backend/coreai/`](coreai/README.md)（Mac 固定路径 `~/workspace/minicpm-coreai`，原始权重位于 `~/workspace/models/`），历史临时产物已清理。

## 结果

**MiniCPM-V 4.7 1B 的文字主干已导出为 macOS 目标的 Core AI `.aimodel`。** 采用官方 Qwen3.5 配方，FP16、上下文 128、不量化。转换任务退出码为 0，墙钟约 68 秒；Core AI 公共资产 API 能重新读取，函数列表为 `main`、`prefill`。

随后已在系统 Core AI 运行时完成 1B 的 prefill 和 12 个 token 生成。E1 的动态专家输入，以及用标准算子展开的单步循环状态，在 Mac 上通过 FP32 / FP16 对照；两个 FP16 小图也完成 iOS 27.2 目标编译。原生 `GatedDeltaUpdate` 的归一化分支出现数值偏差，详见后文。

运行选择 GPU 偏好，尚未用 trace 确认 placement。完整 1B 的数值对齐、iOS 真机执行仍 **[待实测]**；本轮未执行 LES。视觉塔、图像投影和 35B-A3B 未转换。

## 环境与输入

| 项目 | 本次记录 |
|---|---|
| 主机 | `sakura-mac.local`，arm64，32 GiB 内存 |
| 系统 | macOS 27.3（`26C5035r`） |
| Xcode / iOS SDK | Xcode 27.2（`27B52`），iOS SDK 27.2 |
| Metal Toolchain | 转换时未安装；同日后续已安装官方 `27B47`，详情见文末 |
| 官方配方 | `apple/coreai-models@acbce1b41f95955ab56597d11d94b447b16a80bd` |
| Python | 隔离环境，CPython 3.12.15 |
| 核心依赖 | `coreai-core==1.0.0b3`、`coreai-torch==0.4.3`、`coreai-opt==0.4.0`、`torch==2.9.0`、`transformers==5.12.1` |
| 依赖安装 | 官方 `uv.lock`，`uv sync --locked --no-dev --python 3.12 --package coreai-models`；uv 由临时 `nix shell nixpkgs#uv` 提供 |
| 1B 原始权重 | `~/workspace/models/MiniCPM-V-4.7-1B/model.safetensors`，3,109,054,480 B，BF16 |
| 35B 原始权重 | `~/workspace/models/MiniCPM-V-4.7-35B-A3B/`，16 个分片共 70,425,903,448 B；本轮保留为后续输入 |

实验使用独立目录 `~/workspace/experiments/minicpm-coreai-20261113/`，没有修改原始权重、系统 Python、项目客户端或远端原有项目工作树。官方转换仓库固定提交，工作树干净。

## 两次尝试及适配原因

### 1. 原始 checkpoint 直接导出失败

使用官方 CLI，以本地模型目录为输入，设置 `--platform macOS --experimental --compute-precision float16 --compression none --max-context-length 128`。

失败发生在 `AutoConfig.from_pretrained`，退出码为 1：

```text
KeyError: 'minicpmv4_7'
ValueError: The checkpoint you are trying to load has model type
`minicpmv4_7` but Transformers does not recognize this architecture.
```

官方配方锁定 Transformers 5.12.1，原始配置声明 `transformers_version: 5.18.0`。这个失败发生在顶层架构识别，尚未进入 Core AI 图转换。

### 2. 文字主干视图导出成功

原始 `text_config.model_type` 是 `qwen3_5_text`，语言权重命名为 `model.language_model.*`，另有根目录 `lm_head.weight`。官方 Qwen3.5 配方支持相同命名空间及独立 LM head。

因此创建 `text-view-1b/`：

- 新建派生 `config.json`：顶层 `model_type` 设为 `qwen3_5`，`architectures` 设为 `Qwen3_5ForConditionalGeneration`；原始 `text_config`、`tie_word_embeddings`、`dtype` 原样保留。
- `model.safetensors`、tokenizer 文件、chat template、generation config 通过符号链接引用原目录。
- 官方 loader 仅选择语言权重与 LM head，排除视觉 / 投影权重；模型计算仍由官方 Qwen3.5 配方构建。
- 派生视图的用途与来源记录在 `text-view-1b-manifest.json`。这是文字主干的转换输入，不作为完整 MiniCPM-V 多模态模型的发布配置。

成功命令（在远端执行）：

```sh
ROOT="$HOME/workspace/experiments/minicpm-coreai-20261113"
cd "$ROOT/coreai-models"
export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 PYTHONUNBUFFERED=1
.venv/bin/coreai.llm.export "$ROOT/text-view-1b" \
  --platform macOS --experimental \
  --compute-precision float16 --compression none \
  --max-context-length 128 \
  --output-name minicpm-v47-1b-text-f16-ctx128 \
  --output-dir "$ROOT/output/text-1b"
```

## 产物与检查

远端资源包：

```text
~/workspace/experiments/minicpm-coreai-20261113/
  output/text-1b/minicpm-v47-1b-text-f16-ctx128/
    minicpm-v47-1b-text-f16-ctx128.aimodel/
      main.mlirb
      main.hash
      metadata.json
    tokenizer/
    metadata.json
```

- `.aimodel` 目录：**2,013,008,853 B**，约 2.01 GB。
- 含 tokenizer 的资源包：**2,033,010,832 B**，约 2.03 GB。
- `AIModelAsset.is_valid(path)` 返回 `True`。
- `AIModelAsset.load(path).summary(include_statistics=False)` 读取成功，包含 `main`、`prefill`。
- 资源包 metadata 记录 `vocab_size=248094`、`max_context_length=128`、无压缩、无已编译目标。
- 原始配置仍为 `model_type=minicpmv4_7`，派生视图继续链接原始权重。

以上是转换阶段的资产与结构检查；随后执行结果见下文。

当时的转换证据文件：

```text
logs/environment-sync.log
logs/native-1b-export.log
logs/text-1b-export.log
environment.json
text-view-1b-manifest.json
asset-validation.json
```

## 警告与后续处理

1. **Tokenizer 正则警告：** Transformers 在保存 tokenizer 时提示 incorrect regex pattern，并建议 `fix_mistral_regex=True`。本轮未修改规则；随后使用 `tokenizers.Tokenizer` 检查短 ChatML 输入，源 / 导出 tokenizer 的 19 个 token IDs 一致。后续更多输入与 chat template 仍需结合模型要求的 Transformers 版本核对，避免机械套用其他模型的修复。
2. **资产来源元数据：** 本地派生路径未在官方 metadata 注册表中，`.aimodel` 缺少作者、许可证与描述。原始模型 README 标注 Apache-2.0；发布资产时需补齐来源和许可字段。
3. **配方通用警告：** 1B 稠密模型未匹配 `GatherMM`，部分 RoPE 使用分解路径；prefill 不使用尾部输出模块，出现未匹配 externalization 的警告。后续以实际计算图和数值对齐确认路径。
4. **torchao 扩展：** 官方锁定环境提示其 C++ 扩展与 torch 2.9.0 不匹配。本轮 `compression=none` 已完成转换；尝试量化时需先处理对应版本兼容性。

下述工具链准备已完成，其后的执行与数值对照另节记录。

## 同日后续：开发组件与工具链补齐

用户授权安装 Metal 以及近期可能使用的其他开发组件后，已完成：

| 项目 | 当前状态 |
|---|---|
| Metal Toolchain | `xcodebuild -downloadComponent MetalToolchain` 成功，下载约 839 MB；组件 `27B47`，identifier `com.apple.dt.toolchain.Metal.32023.922.4` |
| Metal 编译器 / 链接器 | `metal`、`metallib` 可用；Apple metal `32023.922` |
| Core AI 构建工具 | `coreai-build 3605.6.3` 可用，支持 compile / package / inspect / metadata |
| iOS / macOS SDK | 当前 Xcode 27.2 自带，保持不变 |
| iOS 模拟器 | 已有可用 iOS 27.1 / 27.2 runtime，以及 iPhone / iPad 设备；ARM64 下载检查返回 `No needed downloadables found for arm64Only`（退出码 70），没有新增下载 |
| 设备支持 | `-showComponent DeviceSupport -json` 返回 `No updates`；下载检查返回 `No matching device support package for tools version 27B52`（退出码 70），没有可匹配的新包 |
| 性能与调试工具 | `lldb`、`devicectl`、`xctrace` 可用；已有 Core AI、Core ML、Foundation Models、Metal System Trace、Power Profiler、Time Profiler 模板 |
| 实验开发工具 | 固定 Nix devShell：uv 0.13.7、CMake 4.4.4、Ninja 1.13.2、pkg-config 0.29.2、Git 2.56.0、b3sum 1.8.7、jq 1.8.2 |

开发环境声明位于远端 `tooling/flake.nix` 与 `tooling/flake.lock`，nixpkgs 固定到 `2074cc672349f14240fb7ea90d509e0b643e9dd4`。使用 `mkShellNoCC`，在 shell 内显式选择 Xcode clang / clang++ 与 SDK，macOS deployment target 为 27.0；Python 转换继续使用原有锁定的 `.venv`。

进入方式：

```sh
cd ~/workspace/experiments/minicpm-coreai-20261113
nix develop path:./tooling
```

已完成的工具链验证：

- macOS 与 iOS Metal shader 均成功编译并生成 metallib。
- 在上述 devShell 中，对 macOS / iOS 分别使用对应 SDK，Swift 导入 `CoreAI`、`FoundationModels` 并引用 `AIModel` 的类型检查通过。
- `coreai-build inspect --io --json` 成功读取 1B 资产，列出 `main` / `prefill`，以及 `keyCache`、`valueCache`、`convStates`、`recurrentStates` 四类状态。

工具链阶段曾记录 `environment-after-toolchain.json`、`checks/coreai-asset-inspect.json` 和 `logs/` 下的组件安装、开发环境与验证日志，现已随历史材料清理。工具链准备阶段没有切换 Xcode 或升级转换依赖。

## 同日后续：1B 文字主干实际运行

当时使用 `run_text_asset.py`（现已清理），设置 `USE_OS_COREAI=1`，通过系统 Core AI 的 Python 绑定执行。`ComputeUnitKind.gpu()` 是工厂方法；设置 GPU 偏好后，允许的执行单元仍是 CPU、GPU、Neural Engine。

- 以明确的短 ChatML 输入要求一句问候，关闭思考的前缀也直接写入输入；本轮不依赖 Transformers 自动生成模板。
- 加载一次模型，保留 `keyCache`、`valueCache`、`convStates`、`recurrentStates`。先 prefill 前 18 个输入 token，再以最后一个 token 启动 decode，连续执行 12 次。
- 每次 `input_ids` 只传一个 token；`position_ids` 按官方配方传累计位置序列，其长度用于推导当前写入位置。
- 输出 logits 全部为有限值，贪心生成结果：

```text
Hello! I'm a AI assistant here to help you.
```

| 阶段 | 首次 12-token 运行的墙钟 |
|---|---|
| 模型加载 | 1.210 s |
| Prefill | 2.195 s |
| 前两个 decode 调用 | 2.660 s、1.340 s |
| 随后九个 decode 调用 | 各约 10.38–10.54 s |
| 最后一个 decode 调用 | 20.471 s |

这些时延仅作诊断记录：运行反复报告 `NSCocoaErrorDomain Code=4097`，连接 `com.apple.ANECompilerService` 出错。尚未分离服务等待、动态形状 specialization 与实际计算时间，也未 trace 实际 placement，暂不据此评价后端吞吐。

最终脚本再次执行单 token 检查，仍输出 `Hello`，退出码 0；缓存加载约 0.006 s、prefill 1.169 s，但 decode 耗时 80.300 s，并再次报告同一服务错误。两次运行的时延差异还需专项定位。

首次运行任务退出码为 0。当时的 1B 资产使用官方 GatedDelta 路径；下面的小图偏差使完整模型的逐步数值对齐成为后续必要检查。该资产已清理，未接入正式客户端。

## E1：动态专家与连续状态的 Mac 对照

### 输入与通过的路径

当时入口为 `run_e1.py`（现已清理），seed 为 `20261113`。固定小形状，不加载 35B 权重，不做压缩。

- **动态专家：** 官方 `GatherMM(num_batch_axes=0)`；输入 `x [1,2,1,1,8]`、专家张量 `[8,8,16]`、indices `[1,2,2]`。同一已加载函数依次接收 W1、W2、W1；W2 输出发生变化，恢复 W1 后与第一次结果逐字节一致。两次执行间等待完成，没有重新加载或重新导出函数。
- **状态：** Q/K/V 为 `[1,2,1,4]`，state 为 `[1,2,4,4]`。同一函数、同一个 mutable state 连续四步，逐步对照输出与状态。通过的实现将固定 `S=1` 的官方递推公式展开为标准 Torch 算子，显式做 Q/K 归一化、FP32 内部递推与回写，没有外部化为 GatedDelta composite，也没有自写 Metal。
- **参考：** 动态矩阵乘用 PyTorch 数学实现，递推用官方 PyTorch `GatedDeltaUpdate`；另以独立 NumPy 实现交叉核对。本次两套参考的输出和状态在两个 dtype 下均一致。
- **判定：** FP32 `atol=1e-5, rtol=1e-4`；FP16 `atol=2e-3, rtol=5e-3`。没有为原生失败放宽阈值；下表报告实际误差。

| dtype | 三次动态专家最大绝对误差 | 四步输出最大绝对误差 | 四步状态最大绝对误差 |
|---|---:|---:|---:|
| FP32 | `2.98023224e-8` | `7.45058060e-9` | `7.45058060e-9` |
| FP16 | `0` | `3.05175781e-5` | `1.22070313e-4` |

最终两次验证均退出码 0，包含 conversion、specialization、加载与执行。设置为 GPU 偏好、允许三类执行单元，placement 和峰值内存另待 trace。本轮动态专家输入每次新建 NDArray；共享 `MTLBuffer` 零拷贝与槽位复用仍 **[待实测]**。

### 原生 GatedDelta 的失败与定位

保留 `--delta-implementation native` 作为失败复现，不在运行失败后自动改用其他实现。

| 检查 | 观察 |
|---|---|
| FP32 原生归一化 | 首步输出约为参考 2 倍，最大绝对误差 `0.05040671`；状态也约为 2 倍，误差 `0.12623744` |
| FP32 显式 CPU-only | 复现相同输出偏差 |
| FP16 原生归一化 | 首步输出约为参考 4 倍，最大绝对误差 `0.15115356` |
| 普通输出代替 mutable state | 显式 CPU-only，仍复现 FP32 输出和最终状态偏差；六个普通输入未被修改 |
| 关闭 composite 内置 Q/K 归一化 | 同一个 FP32 首步输入，输出和状态与数学参考的误差均为 `0` |
| 单独检查状态持久化 | 非对称非零初态，`beta=0, g=log(0.5)`；同一 state 连续两步变为初态的 `1/2`、`1/4`。BYTES / METAL 两种 backing 均误差 `0` |

官方 PyTorch composite 与 NumPy 参考在 FP32 失败输入上完全一致。转换后的 IR 保留了 query 的 `0.5` 缩放，也包含 state handle 与 `write_handle`；不能仅凭输出倍数把原因归为漏乘 query scale。目前将差异定位到**当前组合版本的 Core AI GatedDelta 归一化执行路径**，内部公式或 lowering 根因尚待确认。

只把归一化移出 composite（`--delta-implementation explicit-norm`）又在 GPU 偏好 specialization 失败。系统日志给出：

```text
'scf.while' op along control flow edge from parent operands to Region #0:
source type #1 'memref<1x2x4x4xf32, \"MTLBuffer\">'
should match input type #1 'memref<1x2x4x4xf32>'
```

因此最小实验采用固定单步的标准算子展开，避开原生归一化分支与循环内存空间错误，并保持原公式和原数值断言。它是本轮明确标注的局部替代；完整 prefill / 混合层配方仍需另外解决，不将小图结果推广到完整模型。

### iOS 目标编译

对通过的 FP16 动态专家图与展开递推图运行：

```sh
xcrun coreai-build compile SOURCE.aimodel \
  --platform iOS --min-deployment-version 27.2 --preferred-compute gpu \
  --output OUTPUT_DIRECTORY
```

两图均编译九个目标架构：`h13g`、`h14g`、`h15g`、`h16g`、`h16p`、`h17g`、`h17p`、`h18p`、`h19p`，总共 18 个 `.aimodelc`，任务退出码 0。每个专家图产物约 14.5 KB，每个状态图产物约 28.6 KB；两类 `h17g` 代表产物的 `inspect --io --json` 读取通过。

远端 `devicectl` 已发现一台 available / paired 的物理 iPhone 17。本轮没有安装或运行 iOS 实验 App，没有变更设备、签名或 entitlements。真机加载、连续执行、GPU placement 与误差仍 **[待实测]**。

## 对路线的影响与下一步

Mac 小图已经显示：运行时专家输入能更新，公开标准算子能维持连续循环状态；原生 GatedDelta 的当前执行路径仍有明确缺口。保留三条候选，当前不据此选择或否决 Core AI 中心路线。

后续继续 E1 时，按上述小形状重建最小 iOS harness，使用个人设备免费签名，核对真机执行、误差、共享 buffer 与 placement；并单独做 1B 与原模型 / 官方配方的逐步数值对齐，处理原生归一化差异。日常转换与量化脚本见 [`backend/coreai/`](coreai/README.md)。
