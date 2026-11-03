---
title: "DSH（DeepSeek Harness）插件生态质量与兼容性调研报告"
date: 2026-11-01
draft: false
featured: false
tags: ["对话报告"]
description: "1. 插件总量：全量索引口径约 1.5 万+（dshplugin.store 同步 GitHub dsh-plugin 话题：22975 仓库/15294 插件），审核收录口径 2500（dshmk."
---

# DSH（DeepSeek Harness）插件生态质量与兼容性调研报告

> **记录时间**：2026-11-01
> **调研范围**：dsh 插件搜索途径、数量、功能分类、质量信号、版本要求标注率、兼容性实测
> **合规说明**：dsh 为 DeepSeek 开源项目；数据来自官方文档、社区目录站与本地 npm 实测

---

## 一、核心结论

1. **插件总量**：全量索引口径约 **1.5 万+**（dshplugin.store 同步 GitHub `dsh-plugin` 话题：22975 仓库/15294 插件），审核收录口径 **2500**（dshmk.com），官方 npm 目录包收录 **4092**（dsh-plugin-catalog）。
2. **质量总评**：机制完善但生态早期——所有核心框架包均为 rc/alpha 预发布版；兼容性检查能拦下不匹配插件，但版本漂移严重（官方插件之间也会互相不兼容）。
3. **版本要求标注率**：**仅 27.4%**（4092 个插件中 1123 个标注 `engines.dsh`），多数插件未声明 dsh 版本兼容范围。

## 二、插件搜索途径（7 个）

| 途径 | 类型 | 规模/特点 |
|---|---|---|
| dshplugin.store | 社区目录 | 22975 仓库/15294 插件（2026-10-30 同步），18 分类 |
| dshmk.com | 社区市场 | 2500 插件/11 分类，30 分钟同步 GitHub，有排行榜与 API |
| dsh.so | 社区注册表 | 安全扫描 + 沙盒安装实测（L4/L5），可加为索引源 |
| dsh-plugin.app | 目录站 | 精选式 |
| deepseek-plugin.org | 教程站 | 安装方法指南 |
| GitHub topic `dsh-plugin` | 源头仓库 | 目录站数据来源 |
| Visual Studio Marketplace / JetBrains Marketplace | IDE 集成 | DSH Agent Sidebar GT112、DSH Studio 等 |

> 插件本质是 npm 包，安装命令：`dsh plugin --profile web add <spec>`（github:xxx / npm:xxx）；DSH 不内置索引源，市场索引需用户手动添加（https 优先）。

## 三、功能分类统计

### 3.1 dshmk.com 口径（2500 收录，2026-10-31）

| 分类 | 数量 | 占比 |
|---|---|---|
| 开发工具 | 1399 | 56.0% |
| Agent 与会话 | 298 | 11.9% |
| 界面增强 | 177 | 7.1% |
| 模型与 MCP | 33 | 1.3% |
| 生活娱乐 | 31 | 1.2% |
| 部署运维 | 15 | 0.6% |
| 学习研究 | 6 | 0.2% |

### 3.2 dshplugin.store 口径（15294 插件，多标签，合计>总数）

Web UI 6868、Skills 2449、Tools 2313、Workspace 2030、Auth 1827、Desktop 1627、Memory 1407、MCP 1299、Coding 1247、Theme 1075、Notify 1027、Fun 1010、Vision 843、Search 504、Browser 403。

> 技术类（Skills/Tools/Coding/MCP）合计约 7300 标签量级；Web UI 类占绝对多数但含大量主题/皮肤/桌宠类。

## 四、质量评估

### 4.1 版本成熟度（风险最高项）

- dsh 本体：`@deepseek-ai/dsh 0.2.1-rc.5`（latest，预发布）
- 核心分包：dsh-llm/tools/session/agent/skill/compaction 等全部 0.0.1-rc.x / 0.1.x-rc（预发布）
- **0.1.x → 0.2.x 存在破坏性变更**（0.2 移除部分 API，0.1.x 不再受支持）；部分插件锁单版本（如 dsh-consult 仅支持 0.1.5-rc.2）
- Node.js 要求 >=22.19（实测 22.23.2 满足）

### 4.2 更新维护

- dshmk.com 排行榜今日 star 增长个位数（+3~+6），热度平稳偏小众
- 头部插件迭代频繁：dsh-context 0.78.x 高频发版、dsh-market 9.8k★、dsh-desktop 34k★、modlens 4.6k★
- 收录站"已验证"为结构级验证；dsh.so 提供实机沙盒验证（更强）

### 4.3 Star 分布

- 头部通用 Agent 项目高星（open-design 105k★、archify 92k★）
- dsh 专属插件以 1k~35k★ 为主，长尾大量 <1k★

## 五、版本要求标注情况（本次量化统计）

**数据源**：官方 npm 目录包 `dsh-plugin-catalog`（2026.1031.13045，4092 条目）实测解析。

| 指标 | 数值 |
|---|---|
| 插件总数 | 4092 |
| 标注 `engines.dsh` 的插件 | **1123（27.4%）** |
| 未标注（按 peer 依赖兜底检查） | 2969（72.6%） |
| 目录收录版本条目 | 每插件 1 条（目录快照，不代表实际版本数） |

**机制说明**（官方插件市场文档）：
- `engines.dsh`：该版本可运行的 dsh SemVer 范围；缺省表示任意版本
- 未声明 `engines.dsh` 的包按其 `@deepseek-ai/dsh*` peer 依赖检查
- 安装时双重检查（索引 engines + 包自身 engines/peer），不匹配直接拒绝
- 不兼容时可 `dsh plugin allow-version --accept-risk` 强制装（警告：可能导致崩溃或数据丢失）

## 六、兼容性实测报告（2026-11-01，本地）

**环境**：Linux 沙箱，Node v22.23.2，npm 10.9.8，dsh 0.2.1-rc.5（@deepseek-ai/dsh）。

| 插件 | 版本要求声明 | 实测结果 |
|---|---|---|
| dsh-context 0.78.2 | engines.dsh `>=0.2.0-rc.2`；peer: cordis ^4.0.4 等 | ✅ 安装成功（有 peer 警告但可用） |
| @deepseek-ai/dsh-compaction 0.0.1-rc.5 | peer 要求 dsh-llm/brand/session/commands/invariants 全部 ^0.0.1-rc.5 | ❌ 被拒绝（运行时为 rc.1，版本漂移） |

**结论**：官方插件自身也存在 peer 版本漂移导致装不上的情况；安装前必须核对 `engines.dsh` 与 peer 依赖范围。

## 七、实操建议

1. 装前查看插件 `engines.dsh` 是否覆盖当前 dsh 版本（0.1.x 与 0.2.x 不互通）
2. 优先选择持续发版、声明兼容范围的插件（更新维护信号强）
3. **固定 dsh 本体版本，不轻易升级 rc**（升级可能导致已装插件集体失效）
4. 可加 dsh.so 索引源（带实机验证）或用 `dsh-plugin-catalog` 做目录（npm 安装）
5. 技术底座类（MCP/编码/部署运维）插件选择面小（33/15 个），装前确认维护活跃度

## 八、数据来源

- 官方文档：https://deepseek-harness.github.io/deepseek-harness/guide/plugin-market
- dshplugin.store（2026-10-30 同步数据）
- dshmk.com（2026-10-31 数据）
- dsh.so / deepseek-plugin.org / Obsidian 插件页 / dsh-full-remote、dsh-consult 兼容性文档
- 本地实测：npm 安装 @deepseek-ai/dsh@0.2.1-rc.5 + dsh-plugin-catalog 解析统计 + 插件安装测试

*本报告由豆包工作助手整理，供 dsh 用户取用；第三方目录站与 DeepSeek AI 官方无隶属关系。*
