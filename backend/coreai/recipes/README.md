# 转换与量化配方

优先使用固定上游自带配方，不复制一份维护：

- macOS 4-bit Qwen3.5 / MoE：`coreai-models/models/qwen3_5/qwen3_5_cfg.yaml`。包含四维专家权重配置，并排除 router gate。
- 自定义配方以后存到本目录，通过 `export.sh ... --compression-config recipes/NAME.yaml` 传入；每次使用新 run 名称。

当前上游没有 macOS `3bit` CLI 预设。底层 3-bit palettization 需另选实际导出路径与配方；现有 CLI 的 palettization YAML 限 iOS，而 Qwen3.5 的 iOS 配方尚未支持。此处不放未经验证的 3-bit 配方，也不把它映射为 GGUF Q3_K。

本次只搭工作区，没有运行量化，亦未调整已知 torchao / torch 原生扩展兼容问题。版本与既有结果见 [`backend/coreai-export-experiment.md`](../../coreai-export-experiment.md)。
