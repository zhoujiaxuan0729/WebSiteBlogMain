---
title: "dsh 子智能体模型选择：机制、根因排查与实测报告"
date: 2026-11-01
draft: false
featured: false
tags: ["对话报告"]
description: "- 包：@deepseek-ai/dsh-tool-subagent（profile 内 lib/index.js + lib/model-selection-settings.js）"
---

# dsh 子智能体模型选择：机制、根因排查与实测报告

> 结论先行：**dsh 设计上原生支持子智能体（subagent）更换模型**，非第三方 hack。本次已完成端到端实测：设置落盘、工具注册、模型列举全部通过；期间定位并修复了一个部署层面的根因（官方包双份实例导致设置保存被拒）。
>
> 实测日期：2026-11-01 ~ 2026-11-02　环境：云电脑，dsh @deepseek-ai/dsh 0.2.1-rc.5，profile web

---

## 1. 摘要

| 项目 | 结论 |
|---|---|
| dsh 是否设计上支持 subagent 换模型 | **是**。内核 `dsh-tool-subagent` 包原生实现 `modelSelectionSettings`，开启后 subagent 工具 schema 扩展 `provider / model / reasoning_effort` 三字段，并注册 `list_subagent_models` 工具 |
| 换模型生效于哪种子代理 | **仅 spawn 型 subagent**。`subagent_fork`（fork 型）设计上永远继承父模型（复用 KV Cache），不可能有 provider/model 字段 |
| 默认行为 | 模型选择默认关闭（`enabled: false`），需在 GUI 或 profile 配置中显式开启并授权模型白名单 |
| 本次配置 | 3 个 provider 已注册：deepseek-official（2 模型）、zai-coding-cn 智谱（2 模型）、modelscope 魔塔（3 模型），共 7 个授权模型 |
| 稳定性评估 | 功能本身稳定（内核级、有持久化、有 revision 冲突保护）；本次唯一故障为**部署结构问题**（官方包双份实体拷贝导致模块实例分裂），非功能缺陷，已修复 |
| 效果评估 | subagent 工具可精确指定 provider/model/reasoning_effort；`list_subagent_models` 可枚举全部路由；模型目录仅作参考，适配器可接受未列出的模型 id |

---

## 2. 功能机制（内核设计层面）

### 2.1 模型选择扩展点

- 包：`@deepseek-ai/dsh-tool-subagent`（profile 内 `lib/index.js` + `lib/model-selection-settings.js`）
- 配置项：`Config.modelSelectionSettings: z.boolean().default(false)`
- 开启后，`defineTool` 参数才扩展 `provider / model / reasoning_effort` 三个字段，其中 **provider 与 model 必须成对提供**
- 同时注册只读工具 **`list_subagent_models`**：
  - 无参调用：列出全部已注册 provider
  - 传 `provider`：列出该 provider 的模型
  - 传 `provider + model`：查看精确模型与推理强度（reasoning effort）

### 2.2 spawn 与 fork 的模型约束（关键设计）

| 子代理类型 | 工具 | 能否换模型 | 原因 |
|---|---|---|---|
| spawn 型 | `subagent` | **能**（6 字段） | 新开子代理，模型路由可覆盖 |
| fork 型 | `subagent_fork` | **不能**（3 字段） | 代码注释明确：fork 复用父代理 KV Cache，provider/model 永远等同父代理 |

> 权威依据：`dsh-subagent-fork-in-process` 源码注释 —— fork 子代理的 provider/model 永远等同父代理，这是**设计约束**，不是缺陷。

### 2.3 会话级投影与设置 Service

- 设置持久化 key：`subagentModelSelectionPolicy`，事件 `subagent/model-selection-policy`，stateVersion 1
- 设置 Service：`SubagentModelSelectionConfig`（Service 名 `subagentModelSelection`），实例化于 `model-selection-settings.js`
  - `enabled`：boolean，默认 false
  - `allowedModels`：provider/model 路由白名单数组，启用时**至少 1 条**（校验宽松：provider/model 非空、不重复即可）
- 会话投影定义：`index.js:259-282`（`assertAllowedModelRoutes` / `recordSubagentModelSelection`）
- 生效范围：**新设置只对之后新建的会话生效**（已实测确认）

### 2.4 provider 路由注册

dsh-llm 通过 `ctx.llm.registerAdapter(providers, adapter)` 注册路由，`llm.listProviders()` 枚举。本次 profile 注册的 provider（来自 `cordis.patch.yml`）：

| provider id | 显示名 | 模型 | 来源 |
|---|---|---|---|
| deepseek-official | DeepSeek | deepseek-flash（默认）、deepseek-v4-pro | llm-deepseek-api-key |
| zai-coding-cn | 智谱 GLM(免费) | glm-4.5-flash、glm-5.3-flash | llm-pi-ai（自定义 patch） |
| modelscope | 魔塔 ModelScope(免费) | deepseek-ai/DeepSeek-V4.1-Flash-1017、Qwen/Qwen3.5-27B、ZhipuAI/GLM-5.2 | llm-pi-ai（自定义 patch，baseURL api-inference.modelscope.cn） |

---

## 3. 配置路径

### 3.1 GUI 路径

插件页 →「内置插件配置 · 子智能体」（设置"子智能体的递归层级、数量和模型"）：

- 运行限制：最大递归深度（默认 1）、子智能体并行数量上限（默认 8）
- 模型选择区：开关"允许 Agent 为子智能体选择模型" + "Agent 可选择的模型"多选框 + 保存按钮

### 3.2 底层写入

- API：`POST /api/settings/mutate`
- 命名空间：`subagent-model-selection-settings`
- ops：`set enabled` + `set allowedModels`（路由数组 `{provider, model}`）
- JSON-RPC 外壳：`{type: "client-request", rpcId, method: "settings/mutate", payload: {args: {ns, ops, expectedRevision?}}}`（method 在**顶层**，args 为单层参数对象）

### 3.3 持久化位置

设置写入 profile 文档 `~/.dsh/profiles/web/cordis.patch.yml`（本次新增条目）：

```yaml
- id: subagent-model-selection-settings
  name: "@deepseek-ai/dsh-tool-subagent/model-selection-settings"
  config:
    enabled: true
    allowedModels:
      - provider: deepseek-official
        model: deepseek-flash
      # ... 共 7 条
```

---

## 4. 保存失败根因排查（本次主线）

### 4.1 现象

GUI 逐项操作（7 个 checkbox 全勾选、开关 `aria-checked=true`、递归深度 1/并行上限 8）后点保存，页面提示「本部署没有接受这些值，已保留供你修改」（英文：*The deployment did not accept these values; they were left for you to correct.*，出自 `dsh-client-ui-settings-subagent/lib/client.js:21`）。

前端逻辑（`SubagentModelSelectionCardController.save()`，client.js:480-740）：mutate 两个 set op → 保存后校验 `landed`（enabled 与 allowedModels 是否等于期望值）→ 失败显示 saveFailed。

### 4.2 API 复现（拿到后端真实响应）

直调 `/api/settings/mutate`（浏览器同源 fetch）逐步修正协议外壳后，后端返回：

```json
{"ok":false,"error":{"code":"settings/rejected",
  "message":"dsh: profile reload requires the root Include entry",
  "details":{"ns":"subagent-model-selection-settings"}}}
```

> 协议外壳踩坑记录（避免后人重复）：`method` 必须在 JSON-RPC 外壳**顶层**（不是 payload 内）；payload 需包一层 `{args: {...}}`（"Remote payload must contain exactly one plain-object args field"）。

### 4.3 代码追因

- `dsh-settings` 的 `mutate` → `write` → `configEditor.edit` → `reconcileProfilePatches(ownerContext.root, ...)`
- `dsh-app-boot` 的 `recompose`：`const entry = bootstrapIncludes.get(ctx); if (entry === void 0) throw ... "profile reload requires the root Include entry"`
- `bootstrapIncludes` 是**模块级 WeakMap**，key 为 boot 时的根 ctx；`mountRootInclude()` 在启动时（`boot()` 内）无条件挂载
- 当前进程明明走 `boot()` 启动，却取不到 entry —— 说明**调用 recompose 的 dsh-app-boot 模块实例 ≠ 执行 boot/mountRootInclude 的模块实例**

### 4.4 根因：官方包双份实体实例

- 官方设计（`initProfile` 模板）：profile 的 `package.json` 初始 `dependencies: {}`，**官方包全部由 host（全局 dsh 安装）提供**，profile 只装第三方插件
- 实际：`~/.dsh/profiles/web/node_modules/@deepseek-ai/` 存在**全套 308 个官方包实体拷贝**（inode 独立、非软链），与 host 全局 `.../dsh/node_modules/@deepseek-ai/` 双份并存（包集合与版本逐一核对**完全一致**，均为 0.2.1-rc.5）
- 后果：插件/服务加载官方包时优先命中 profile 本地拷贝 → 模块实例分裂 → `bootstrapIncludes` WeakMap 不共享 → settings 写入触发的 profile reload 找不到 root Include entry → 所有 settings/mutate 被拒
- 起源：多次 `npm install --legacy-peer-deps` 装插件把官方包实体化装进 profile；本次修复前 GUI 保存从未成功过

### 4.5 修复与验证

```bash
cd ~/.dsh/profiles/web/node_modules
mv @deepseek-ai @deepseek-ai.bak-1101c                      # 备份实体拷贝（保留回退）
ln -s /home/user/.npm-global/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai @deepseek-ai
# 重启 dsh web
```

- 重启后直调 mutate → `{"ok":true, "value": {"enabled":true, "allowedModels":[7 条], "revision":1}}`，设置写入 `cordis.patch.yml`
- 备份目录 `@deepseek-ai.bak-1101c`（308 包）保留在 profile，可随时回退

---

## 5. 实测验证结果（浏览器会话 · 主模型自证）

新会话中让主模型自证（非代码走查，权威）：

**subagent 工具 schema（修复后，6 字段）：**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| prompt | string | 是 | 完整自包含任务描述（子代理看不到本会话上下文） |
| description | string | 是 | 3–5 词简短任务描述 |
| cwd | string | 否 | 子代理初始工作目录 |
| **provider** | string | 否 | LLM provider 路由；**必须与 model 同时提供** |
| **model** | string | 否 | 由 provider 解释的模型 id；**必须与 provider 同时提供** |
| **reasoning_effort** | string | 否 | 推理强度；省略时继承兼容配置或父级值 |

**subagent_fork 工具 schema（不变，3 字段）：** prompt / description / cwd —— 设计如此，fork 不换模型。

**list_subagent_models（已注册，实测结果）：**

| Provider | 模型 id | 说明 |
|---|---|---|
| deepseek-official | deepseek-flash | DeepSeek-V4.1-Flash |
| deepseek-official | deepseek-v4-pro | DeepSeek-V4-Pro（更强 agentic 编码/推理，成本更高） |
| zai-coding-cn | glm-4.5-flash | GLM-4.5-Flash |
| zai-coding-cn | glm-5.3-flash | GLM-5.3-Flash |
| modelscope | deepseek-ai/DeepSeek-V4.1-Flash-1017 | DeepSeek-V4.1-Flash |
| modelscope | Qwen/Qwen3.5-27B | Qwen3.5-27B |
| modelscope | ZhipuAI/GLM-5.2 | GLM-5.2 |

> 主模型备注：目录中的模型仅作参考，适配器可接受未列出的模型 id。

---

## 6. 稳定性与效果评估

### 6.1 稳定性

| 维度 | 评估 | 依据 |
|---|---|---|
| 功能可靠性 | **高**。内核级原生能力，schema 扩展由工具包显式控制 | 代码：`modelSelectionSettings` 分支 + `list_subagent_models` 注册 |
| 持久化 | **可靠**。设置写入 profile patch 文档，重启后保留 | 实测：mutate revision 0→1、`cordis.patch.yml` 落盘、重启后新会话生效 |
| 并发/冲突保护 | **有**。revision 冲突检测（前端 conflicted 态）+ 设置文档原子写 | `dsh-settings` write 的 `expectedRevision` 校验、`writeFileAtomic` |
| 本次故障归因 | 部署结构问题（官方包双份），**非功能缺陷**；修复后稳定 | 4.4 节根因链 |
| 已知风险 | ① 未来在 profile 内 `npm install` 可能再次实体化/破坏官方包软链；② 若 profile 官方包版本与 host 不一致，软链统一为 host 版本 | 4.5 节修复方案 |

### 6.2 效果

- **能力达成**：subagent 工具现在可指定 `provider/model/reasoning_effort`，主模型可把子任务路由给智谱 GLM、魔塔 Qwen 等非 DeepSeek 模型，实现"默认 ds、可换其他模型"的目标
- **路由可见**：`list_subagent_models` 提供枚举能力，便于编排
- **约束明确**：fork 型子代理不可换模型（KV Cache 复用设计），需要换模型时用 spawn 型
- **独立并行路径**：自研 `dsh-model-call`（call_model 工具）可直接调 zhipu/modelscope，与 subagent 路由设置互不依赖——"只想换个模型问问"已有更轻量路径

### 6.3 使用注意事项

1. **新会话才生效**：修改设置后，已存在的会话不生效，需新建会话
2. **provider/model 必须成对**：只传其一会校验失败
3. **白名单约束**：enabled 时 allowedModels 至少 1 条；未授权的 provider/model 不可选
4. **npm install 风险**：装新插件用 `npm install` 前注意官方包软链可能被重装实体化（若发生，重复 4.5 节修复：备份→软链→重启）
5. **备份**：`@deepseek-ai.bak-1101c` 为修复前实体拷贝备份，确认稳定后可清理

---

## 7. 使用示例

```text
请用 subagent 工具，provider 为 zai-coding-cn、model 为 glm-5.3-flash，
reasoning_effort 为 high，总结 /home/user/Doubao/chats/lib-test.md 的要点
```

（模型 id 以 list_subagent_models 返回为准；provider/model 必须成对出现）

---

## 8. 相关文件与存档

- 本报告：`/home/user/Doubao/chats/38447447855447810/dsh-subagent模型选择实测报告.md`
- 配置：`~/.dsh/profiles/web/cordis.patch.yml`（含新增 `subagent-model-selection-settings` 条目，备份 .bak-1031/.bak-1031b）
- 修复备份：`~/.dsh/profiles/web/node_modules/@deepseek-ai.bak-1101c`（308 个官方包实体拷贝）
- 内核代码：`dsh-tool-subagent/lib/index.js`、`lib/model-selection-settings.js`、`dsh-app-boot/lib/index.js`（bootstrapIncludes/mountRootInclude/recompose）
- 关联存档：`dsh-RAG插件实测存档`（云盘文件夹 XzOIfZ1S8lqf75dOAkscH2EsnIf，5 插件对比报告+安装包）

---

*报告完毕。如需复测：重启 dsh → 新会话让主模型自证 subagent schema 与 list_subagent_models。*
