# MiniCPM Core AI 工作区

日常模型转换与量化的基础工作区。源码保存在本目录，Mac 上使用固定路径 **`~/workspace/minicpm-coreai`**。沿用现有 Xcode 27.2、Metal Toolchain、固定的 Nix 工具及官方 Python 锁文件，不接正式客户端。

## 目录

```text
minicpm-coreai/
  setup.sh             # 固定上游提交，按官方 uv.lock 安装环境
  export.sh            # 一次导出一个 run，保留命令、上游提交和日志
  tooling/             # flake.nix + flake.lock，仅开发工具
  scripts/             # 文字主干视图生成器
  recipes/             # 后续自定义量化配方
  coreai-models/       # 固定的上游源码与 .venv，不纳入设计仓库
  views/               # 派生 config 与权重符号链接，不复制权重
  runs/                # 每项任务独立输出，不纳入设计仓库
```

原始模型继续放在 `~/workspace/models/`，工作区通过符号链接引用。历史实验目录、诊断脚本和中间产物已清理；后续任务统一使用本工作区。

## 进入与初始化

```sh
cd ~/workspace/minicpm-coreai
nix develop path:./tooling
```

当前 Mac 已初始化。新建工作区时，将设计仓库的 `backend/coreai/` 复制过去，进入上述 devShell，再执行一次：

```sh
bash setup.sh
```

环境固定为：

- `apple/coreai-models@acbce1b41f95955ab56597d11d94b447b16a80bd`，依赖使用该提交的 `uv.lock`。
- CPython `3.12.15`；`uv sync --locked --no-dev --package coreai-models`，不安装测试工具。
- Nix 工具沿用 `tooling/flake.lock`。只将 `tooling/` 交给 Nix，不将模型与产物收入 Nix store。
- devShell 选择 Apple clang / SDK，并将上游 `.venv/bin` 加入 PATH，设置 `USE_OS_COREAI=1`。

升级时显式修改 `setup.sh` 中的提交并切换上游 checkout；日常初始化不更新依赖、不覆盖其他提交。上游源码保持独立，后续配方优先复用其现有实现。

## 准备文字主干视图

当前 Mac 已为两个现有模型准备下列视图。新环境需要时运行：

```sh
python scripts/prepare_text_view.py \
  ~/workspace/models/MiniCPM-V-4.7-1B views/1b-text
python scripts/prepare_text_view.py \
  ~/workspace/models/MiniCPM-V-4.7-35B-A3B views/35b-a3b-text
```

只派生顶层 `config.json`：1B 映射到 `qwen3_5`，MoE 映射到 `qwen3_5_moe`；保留原始 `text_config`，其余文件链接回原目录，包含 35B 的分片索引。已存在的视图不覆盖。

这是**文字主干**入口；完整 MiniCPM-V 视觉塔与多模态导出仍需后续配方。

## 转换与 4-bit 量化

进入 devShell 后执行。以下为任务模板，本次整理未运行这些任务。

```sh
# 1B FP16
bash export.sh 1b-f16-ctx128 views/1b-text \
  --platform macOS --compute-precision float16 \
  --compression none --max-context-length 128

# 35B-A3B：使用官方 Qwen3.5 4-bit 配方，含 MoE 专家布局与 router 排除规则
bash export.sh 35b-a3b-4bit-ctx128 views/35b-a3b-text \
  --platform macOS --compute-precision float16 --max-context-length 128 \
  --compression-config "$PWD/coreai-models/models/qwen3_5/qwen3_5_cfg.yaml"
```

`export.sh RUN_NAME MODEL_DIRECTORY [官方 CLI 参数...]` 直接调用官方 `coreai.llm.export`，不隐藏额外量化策略。每次用新 run 名称，已有目录会拒绝覆盖。结果例如：

```text
runs/35b-a3b-4bit-ctx128/
  command.sh
  upstream-revision.txt
  export.log
  model/                  # 官方生成的资源包
```

默认 `HF_HUB_OFFLINE=1` 使用本地模型。需要联网获取校准数据等资源时，显式设置 `HF_HUB_OFFLINE=0`。

## 3-bit 与自定义配方

配方入口放在 [`recipes/`](recipes/README.md)，通过 `--compression-config` 传入。当前固定上游没有 macOS `3bit` 预设；3-bit palettization、整数 4-bit 与 GGUF Q3_K 是不同格式，后续按目标执行路径选择，不在基础工作区编造映射。

本次没有新增 3-bit 算法、修改量化依赖或验证 35B / 量化链路。已知 torchao 原生扩展兼容问题保留到实际量化任务处理。

