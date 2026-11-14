# 推理后端调研与实验（独立轨道）

本目录集中存放端侧推理后端（LES、Apple 混合加速、Core AI 等）的架构对比、判别实验记录与模型转换工作区。

## 与 UI/UX 主线的边界

- **双轨解耦：** 主工作区聚焦 **Web / Desktop / Mobile（重点 Web、iOS、macOS）的 UI/UX 设计与客户端骨架**，见 [项目路线与双轨分工](../docs/14-roadmap.md)。
- **契约隔离：** 在后端路线完成实证闭环并写回 [决策记录](../docs/10-decisions.md) 之前，所有实验代码、转换脚本与调研记录统一收敛在本目录（及远端 Mac 的 `~/workspace/minicpm-coreai`），不侵入主设计文档序列（`docs/01`–`docs/13`），也不直接修改 `apps/` 中的正式 [`Engine` / `ModelStore`](../docs/11-client-architecture.md#推理接口)。

## 目录索引

| 路径 | 说明 |
|---|---|
| [`ios-inference-options.md`](ios-inference-options.md) | iOS 推理架构与路线对比：35B-A3B 模型与 LES 基线、社区调用链、Apple 框架能力核实、三条候选路线与关键实验（E1–E3） |
| [`coreai-export-experiment.md`](coreai-export-experiment.md) | Core AI 转换与 E1 运行实验：1B 文字主干导出、Mac 执行、动态专家与展开循环状态对照、iOS 27.2 目标编译记录 |
| [`coreai/`](coreai/README.md) | Mac 日常模型转换与量化脚本工作区（Nix devShell、文字主干视图生成、按 run 归档导出日志） |
