---
title: "dsh 知识库/向量记忆插件实测对比报告"
date: 2026-11-01
draft: false
featured: false
tags: ["对话报告"]
description: "最终保留启用:dsh-library + dsh-knowledge + dsh-engram 三套并存,互不冲突。"
---

# dsh 知识库/向量记忆插件实测对比报告

> 实测环境:云电脑 dsh 0.2.1-rc.5(profile: web),2026-11-01
> 目的:dsh 能否实现 open-webui 式向量库/知识库(RAG)能力?npm 生态 5 个候选逐一安装实测。

## 一、结论速览

| 插件 | 版本 | 兼容性 | 可用性(实测) | 稳定性 | 易用性 |
|---|---|---|---|---|---|
| **dsh-library** | 0.2.25 | ✅ 兼容 | ✅ library_add 导入 + library_search 检索实测通过 | 稳定 | 高(纯对话操作) |
| **dsh-knowledge** | 0.5.2 | ✅ 兼容 | ✅ knowledge_list_bases 实测通过,工具族全注册 | 稳定 | 高(带浏览器管理面板) |
| **dsh-engram** | 0.11.3 | ✅ 兼容 | ✅ 23 个 engram_* 工具全注册 | 稳定(embedding 需网络) | 高(记忆宫殿面板) |
| dsh-memory-search | 0.1.1 | ❌ 不兼容 | 硬锁 dsh-tools 0.1.0-rc.6,与内核 0.2.1-rc.5 冲突,曾导致整个 dsh 启动崩溃 | 已放弃 | - |
| dsh-advanced-memory | 0.9.17 | ❌ 不兼容 | 依赖 dsh-settings 的 `settingsNamespace` 导出,内核 API 不匹配 | 已放弃 | - |

**最终保留启用:dsh-library + dsh-knowledge + dsh-engram 三套并存,互不冲突。**

## 二、三套可用插件能力明细(实测)

### 1. dsh-library(本地文档知识库,最轻量)
- 依赖:仅 zod(安装秒级)
- 工具(6 个,前缀 `library_`):library_add / library_search / library_list / library_remove / library_diagnose / library_cite_check
- 实测:导入 697 字节 md → 自动分块(900 字符/块,120 重叠)→ 混合检索(0.6 语义 + 0.4 关键词)命中 → 结果注入对话带 [n] 来源标记 → 模型正确引用回答
- embedding:内置确定性 hash embedder(dims 256,零下载零依赖);可配外部 embedder 子进程(OpenAI 兼容/Ollama/本地 onnx)
- 特点:检索质量与 open-webui 接近(lost-in-the-middle 规避、多样性重排、相关性过滤),无管理界面

### 2. dsh-knowledge(Cherry Studio 风格知识库,功能最全)
- 依赖:重(mupdf/onnxruntime/tesseract/ppu-ocr/transformers 等,安装 130 包约 2 分钟)
- 结构:三层挂载(service + tool + UI),官方模板要求 3 条 insert
- 工具(前缀 `knowledge_`,实测已注册):knowledge_create_base / knowledge_add_document / knowledge_list_bases / knowledge_search(BM25+向量混合,跨 base)/ knowledge_read_document / knowledge_get_document / knowledge_read_evidence 等
- 面板:侧边栏出现"知识库"入口(浏览器管理界面,最接近 open-webui RAG 体验)
- embedding 支持:OpenAI 兼容 / Ollama / 本地 onnx / 词汇兜底(当前配置 `embeddingProvider: none`,即词汇检索,零外部依赖可先跑通;要语义检索配置 embeddingBaseUrl + model + key 即可)
- 多格式:PDF / Word / 网页 / OCR(图片)全部支持

### 3. dsh-engram(跨会话长期记忆"记忆宫殿")
- 依赖:@huggingface/transformers(安装中等)
- 工具(23 个,前缀 `engram_`):engram_save / engram_search / engram_update / engram_forget / engram_examine / engram_neighbors / engram_timeline / engram_episode_timeline / engram_stats / engram_tour / engram_assess / engram_report / engram_review / engram_review_queue / engram_facts / engram_distill / engram_reflect / engram_export / engram_import / engram_audit_forgotten / engram_ingest_history / engram_profile_edit / engram_language_guide
- 定位:不是文档知识库,是长期记忆(SM-2 间隔重复、证据闸门、来源审计、画像注入),与 knowledge/library 互补
- 注意:本地 embedding 模型首次使用需联网下载,**云电脑代理会超时(ETIMEDOUT)导致降级为关键词检索**;建议配置 HF 镜像或代理白名单后再启用语义检索

## 三、配置流程(可复现)

```bash
# 1. 安装(全部用 --legacy-peer-deps,生态 peer 冲突是常态)
cd ~/.dsh/profiles/web
npm install --legacy-peer-deps dsh-library dsh-knowledge @kenz1117/dsh-engram

# 2. 自研插件防修剪:写进 dependencies 用 file: 引用,或放 ~/.dsh/profiles/node_modules/ 兜底目录
#    (npm install 会清理不在 dependencies 的孤儿包,曾误删 dsh-model-call)

# 3. cordis.patch.yml 的 insert 段(实测有效配置)
```

```yaml
- insert:
    - id: dsh-model-call
      name: dsh-model-call
      config: {}
    - id: dsh-library
      name: dsh-library
      config:
        chunkSize: 900
        chunkOverlap: 120
        maxFileBytes: 5242880
        embedding: { dims: 256, command: '', timeoutMs: 30000, graceMs: 1000, maxOutputBytes: 1048576, maxBatchItems: 64 }
        search: { topK: 8, hybridWeight: 0.6, minRelevance: 0.15, diversityLambda: 0.5, lostMiddleHead: 1, lostMiddleTail: 1, maxResultChars: 16000 }
        injection: { enabled: true, maxChars: 12000 }
        citation: { windowChars: 150 }
    - id: knowledge
      name: dsh-knowledge/knowledge
      config:
        embeddingProvider: none
        embeddingBaseUrl: ''
        embeddingModel: ''
        embeddingApiKey: ''
        chunkSize: 800
        chunkOverlap: 100
        topK: 4
        localModelCacheDir: ''
    - id: tool-knowledge
      name: dsh-knowledge/tool-knowledge
    - id: ui-knowledge
      name: dsh-knowledge
    - id: dsh-engram
      name: '@kenz1117/dsh-engram'
      config:
        ingest: 'light'
```

```bash
# 4. 重启(杀 3080 后 setsid 启动,等 40s,以日志 token 访问)
# 5. 对话中验证:让模型调用 library_add / knowledge_list_bases / engram_search 即可
```

## 四、踩坑记录(重要)

| 坑 | 现象 | 解决 |
|---|---|---|
| peer 依赖冲突 | npm install 报 ERESOLVE | `--legacy-peer-deps`(生态普遍问题) |
| **npm 修剪孤儿包** | 自研 dsh-model-call 被 `npm install` 删除,报 ERR_MODULE_NOT_FOUND | 写进 package.json dependencies(file: 引用)或放 `~/.dsh/profiles/node_modules/` 兜底目录 |
| 内核包被插件依赖替换 | dsh-memory-search 硬锁 dsh-tools 0.1.0-rc.6,替换 0.2.1-rc.5 后 dsh 整个启动失败(SyntaxError: CallId 导出缺失) | 放弃该插件;用全局 dsh 配套内核包还原 `@deepseek-ai/*` |
| dsh-knowledge 只挂 service 层不生效 | 只写 1 条 insert,knowledge_* 工具不出现 | 官方模板需 **3 条 insert**(knowledge + tool-knowledge + ui-knowledge) |
| dsh 新版工具注册要求 | `tool must declare output { schema, render }` | 自研插件 register 时补 `output` 字段 |
| engram embedding 下载超时 | ETIMEDOUT(云电脑代理),降级关键词检索 | 配 HF 镜像 / 代理白名单;插件本身可用 |

## 五、与 open-webui 的对照

| 能力 | open-webui RAG | dsh-knowledge | dsh-library |
|---|---|---|---|
| 多格式文档(PDF/Word/OCR) | ✅ | ✅ | md/txt |
| 可视化知识库管理 | ✅ 完整界面 | ✅ 浏览器面板 | ❌ 纯对话 |
| 语义向量检索 | ✅ | ✅(需配 embedding) | ✅(内置 hash,可配外部) |
| 混合检索/重排 | ✅ | ✅ BM25+向量 | ✅ hybrid+diversity |
| 引用溯源 | ✅ | ✅ evidence | ✅ cite_check |
| 本地轻量部署 | ❌ 重 | 中(依赖重) | ✅ 极轻 |
| 荣耀20/AidLux 可行 | ❌ 8G 吃力 | ⚠️ onnx 原生模块待验 | ✅ 可行 |

## 六、当前启用状态

- dsh 启动日志无插件级报错(仅 onebot 需配置 accessToken 属既有问题、dream-skin/better-sidebar 为正常 pending)
- 三套知识库插件 + dsh-model-call(自研多模型调用)并存可用
