---
title: "浏览器 MCP Server 实测报告"
date: 2026-11-02
draft: false
featured: false
tags: ["对话报告"]
description: "给 dsh 的建议:首选 @playwright/mcp启动最快、导航 1.5s、25 工具、内存 126MB,其次 chrome-devtools-mcp32 工具最全、两步导航 0.9s。两者均通"
---

# 浏览器 MCP Server 实测报告

> 主线背景:dsh 是否可访问并登录网页(服务器面板/监控)的落地扩展——先测外部浏览器 MCP,之后挂进 dsh(dsh-mcp-client 通道已确认,profile 当前零 MCP 配置)。
> 实测日期:2026-11-02 | 环境:云主机 Linux,Node v22.23.2,npm 10.9.8,registry=npmmirror

---

## 1. 结论速览

| 结论 | 内容 |
|---|---|
| ✅ 可用且推荐 | **@playwright/mcp**(微软官方)、**chrome-devtools-mcp**(Google 官方)、**puppeteer-mcp-server**(官方示例)三者均实测成功访问本机网页 |
| ⚠️ 有条件可用 | **@executeautomation/playwright-mcp-server**:握手正常(33 工具)但锁死旧 chromium-1200 build,需专门补齐浏览器;且 npm 重装因网络波动失败,稳定性差 |
| ❌ 不推荐(架构不符) | **playwriter**:必须装 Chrome 扩展才能用,CLI 独立模式无法操作浏览器 |
| ❌ 未安装 | **browser-use MCP**(302AI/BrowserUse):npm 无此包,属 Python 生态,不适用 npm 安装 |
| 💾 安装文件 | 全部保留于 `~/mcp-browser-test/`(5 个独立目录 + 690MB 浏览器缓存) |

**给 dsh 的建议**:首选 `@playwright/mcp`(启动最快、导航 1.5s、25 工具、内存 126MB),其次 `chrome-devtools-mcp`(32 工具最全、两步导航 0.9s)。两者均通过 stdio 协议,可直接由 dsh-mcp-client 挂载(serverName/command/args)。

---

## 2. 测试环境

| 项 | 值 |
|---|---|
| 系统 | 云主机 Linux(10T 磁盘剩 99%) |
| Node / npm | v22.23.2 / 10.9.8 |
| npm 源 | npmmirror(国内镜像) |
| 浏览器二进制 | 系统 chromium 146(`/usr/local/bin/chromium`)+ 9222 端口 Chrome 146 + playwright 下载的 chromium 1248/1252(headless shell,690MB) |
| 测试目标页 | 本机 `http://127.0.0.1:8080/`(AIO Sandbox)——模拟"服务器面板/监控"本地访问场景 |
| 测试脚本 | `~/mcp-browser-test/handshake.js`(握手)、`nav-test.js` / `final-test.js`(导航) |

---

## 3. 安装清单(保留安装文件)

| 包 | 版本 | 目录(bin 入口) |
|---|---|---|
| @playwright/mcp | 0.0.84 | `~/mcp-browser-test/playwright-mcp/`(`node_modules/@playwright/mcp/cli.js`) |
| chrome-devtools-mcp | 1.12.0 | `~/mcp-browser-test/chrome-devtools-mcp/`(`build/src/bin/chrome-devtools-mcp.js`) |
| puppeteer-mcp-server | 0.7.2 | `~/mcp-browser-test/puppeteer-mcp-server/`(`dist/index.js`) |
| @executeautomation/playwright-mcp-server | 1.0.12 | `~/mcp-browser-test/ea-playwright-mcp/`(`dist/index.js`) |
| playwriter | 0.9.0 | `~/mcp-browser-test/playwriter/`(`bin.js`) |
| browser-use MCP | — | npm 无此包(`@browser-use/mcp-server` / `mcp-server-browser-use` / `browser-use-mcp-server` 均 NOT_FOUND,Python 生态) |

浏览器二进制缓存:`PLAYWRIGHT_BROWSERS_PATH=~/mcp-browser-test/.browsers`(690MB,含 chromium-1248/1252、chromium_headless_shell-1248/1252、ffmpeg-1013)。
下载关键:默认路径 `/opt/vm/preinstall` 无写权限(EACCES),必须显式指定 `PLAYWRIGHT_BROWSERS_PATH`;镜像 `PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright` 可秒级下载。

---

## 4. MCP stdio 握手测试(initialize + tools/list)

| Server | init 耗时 | 工具数 | 内存(RSS) | 协议版本 | 代表工具 |
|---|---|---|---|---|---|
| @playwright/mcp | **531ms** | 25 | 126MB | 2025-03-26 | browser_navigate / browser_click / browser_type / browser_snapshot |
| chrome-devtools-mcp | 1.5s | **32** | 148MB | 2025-03-26 | navigate_page / click / fill / evaluate_script / screenshot |
| puppeteer-mcp-server | 3.9s | 8 | **90MB** | 2024-11-05(旧) | puppeteer_navigate / puppeteer_click / puppeteer_fill |
| ea-playwright-mcp | 6.7s | **33** | 109MB | 2025-03-26 | playwright_navigate / playwright_fill / start_codegen_session |
| playwriter | 8.1s | 2 | 121MB | 2025-03-26 | execute / reset |

要点:全部 5 个包握手成功;playwright 启动最快、内存中等;puppeteer 内存最小但工具最少且协议版本旧;ea 工具最多但启动最慢;playwriter 只有 2 个工具(面向扩展的命令通道)。

---

## 5. 真实导航测试(访问 http://127.0.0.1:8080/)

| Server | 结果 | 耗时 | 说明 |
|---|---|---|---|
| @playwright/mcp | ✅ 成功 | 1.5s(冷启动含下载后首跑 4.4s) | Page Title 已确认:`AIO Sandbox`;参数 `--browser chromium --headless`,需 playwright 浏览器 |
| chrome-devtools-mcp | ✅ 成功 | 0.9s | 两步调用:`list_pages` 拿 pageId → `navigate_page {pageId, url}`;工具名是 **navigate_page 不是 navigate** |
| puppeteer-mcp-server | ✅ 成功 | 3.1s(首轮 5.0s) | `Successfully navigated ... (Status: 200)`,自动复用系统 chromium |
| ea-playwright-mcp | ❌ 失败 | — | 锁死 `chromium-1200/chrome-linux64/chrome`,而当前 playwright 下载的是 1248/1252;补装 1200 需匹配其内置 playwright 版本,镜像未见旧 build |
| playwriter | ❌ 失败 | — | `The Playwriter Chrome extension is not connected`,必须装 Chrome 扩展,CLI 独立模式不可用 |

首轮踩坑记录:
- playwright:默认找 `chrome` 发行版报错 → 显式 `--browser chromium` 解决(需先下载 chromium);
- chrome-devtools:误调 `navigate` 报 `Tool navigate disabled` → 实际工具名为 `navigate_page`,且需先 `list_pages`;
- puppeteer:无坑,开箱即用;
- ea:`Executable doesn't exist at .browsers/chromium-1200/...`,旧 build 锁定;
- playwriter:报 `expected string, received undefined at code` → 参数为 `code`,但无扩展时仍拒绝执行。

---

## 6. 兼容性评估

| 维度 | @playwright/mcp | chrome-devtools-mcp | puppeteer-mcp-server | ea | playwriter |
|---|---|---|---|---|---|
| 安装复杂度 | 中(需下载 chromium) | 低(复用系统浏览器/连 9222) | 低(自动找浏览器) | 高(旧 build 锁定) | 高(需浏览器扩展) |
| 浏览器依赖 | playwright 自带 build | Chrome 144+ 或系统 chromium | chrome/chromium 任意 | playwright 1200 旧 build | 无(走扩展) |
| 工具完整度 | 高(25) | 最高(32) | 低(8) | 最高(33) | 极低(2) |
| 无头模式 | ✅ --headless | ✅ --headless | ✅ 默认无头 | ✅ 默认无头 | 依赖扩展 |
| 远程连接 | 内建 | ✅ `-u http://127.0.0.1:9222` | 支持连接 active tab | 内建 | 不适用 |
| 稳定性 | 高 | 高 | 高 | 中(安装易超时/目录被清空) | 低(CLI 模式) |
| dsh-mcp-client 适配 | ✅ stdio | ✅ stdio | ✅ stdio | ✅ stdio | 不推荐 |

实测中的两个环境级问题(与包本身无关,但影响安装):
1. `npx playwright install` 默认写 `/opt/vm/preinstall` 报 EACCES → 必须设 `PLAYWRIGHT_BROWSERS_PATH`;
2. npm 长安装命令偶发 `flow.mcp.proxy RPC 失败`(基础设施网络错误),ea 重装 3 次未完成——属于网络波动,非包缺陷。

---

## 7. 性能对比摘要

```
启动速度:   @playwright(0.5s) > cdp(1.5s) > puppeteer(3.9s) > ea(6.7s) > playwriter(8.1s)
导航速度:   cdp(0.9s) > @playwright(1.5s) > puppeteer(3.1s)
内存占用:   puppeteer(90MB) < ea(109MB) < playwriter(121MB) < @playwright(126MB) < cdp(148MB)
工具数量:   ea(33) = cdp(32) > @playwright(25) > puppeteer(8) > playwriter(2)
```

- 单次导航(本机回环)实际耗时均在 5 秒内,headless 首启需额外 1~4 秒;
- 内存普遍 90~150MB,对常驻 MCP server 可接受;
- 若挂入 dsh-mcp-client(stdio),@playwright/mcp 或 chrome-devtools-mcp 是平衡最佳;puppeteer 适合轻量场景(内存最小但能力少)。

---

## 8. 后续建议(与 dsh 主线衔接)

1. **挂载**:在 `~/.dsh/profiles/web/cordis.patch.yml` 的 mcp 段新增,如
   `@playwright/mcp` → `command: node, args: [<绝对路径>/cli.js, --browser, chromium, --headless], env: PLAYWRIGHT_BROWSERS_PATH=~/mcp-browser-test/.browsers`。
2. **登录类网页(面板/监控)**:MCP 侧具备 navigate/click/fill 能力;若面板需要账号密码,可用 dsh 的 bash 工具 curl 登录态或 MCP 模拟,视具体面板而定。
3. **真实面板端到端验证**:需用户提供真实面板 URL + 凭据后再实测(本机当前无真实面板,8080 为 AIO Sandbox 测试页)。

---

## 9. 附:保留的安装文件清单

```
~/mcp-browser-test/
├── handshake.js / nav-test.js / nav2.js / nav3.js / final-test.js / fix2.js / pw-test.js   # 测试脚本
├── playwright-mcp/      # @playwright/mcp 0.0.84 + 依赖
├── chrome-devtools-mcp/ # chrome-devtools-mcp 1.12.0 + 依赖
├── puppeteer-mcp-server/# puppeteer-mcp-server 0.7.2 + 依赖
├── ea-playwright-mcp/   # @executeautomation/playwright-mcp-server 1.0.12(重装未完成,目录被清空)
├── playwriter/          # playwriter 0.9.0 + 依赖
└── .browsers/           # 690MB:chromium-1248/1252、chromium_headless_shell-1248/1252、ffmpeg-1013
```

(本报告由实测数据整理,所有数字来自 2026-11-02 实测输出;ea 重装失败项已在正文标注。)
