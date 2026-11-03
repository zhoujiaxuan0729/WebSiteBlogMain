# 我的 Hugo 博客骨架

把之前那个暖色调卡片首页改造成了一个最小可运行的 Hugo 项目。
所有模板都在 `layouts/` 里，没有外部主题依赖，改起来直接。

## 目录结构

```
hugo-blog/
├── hugo.toml              # 站点配置（改标题、tagline、菜单）
├── archetypes/
│   └── default.md         # 新文章模板
├── content/
│   ├── _index.md          # 首页
│   ├── about.md           # 关于页
│   └── posts/
│       ├── _index.md      # 归档页
│       ├── hugo-on-termux.md
│       └── ...            # 你的文章放这里
├── layouts/
│   ├── index.html         # 首页模板
│   ├── _default/
│   │   ├── baseof.html    # HTML 骨架
│   │   ├── single.html    # 文章详情页
│   │   └── list.html      # 列表/归档页
│   └── partials/
│       ├── head.html
│       ├── header.html
│       └── footer.html
└── static/
    └── css/main.css       # 全部样式，改配色改这里
```

## 日常使用

### 1. 新建一篇文章

```bash
hugo new posts/文章标题.md
```

打开生成的文件，编辑 front matter：

```yaml
---
title: "文章标题"
date: 2026-11-02
draft: false          # 改成 false 才会发布
featured: true        # 设为 true 就出现在首页置顶大卡
tags: ["标签1", "标签2"]
description: "一句话摘要，会显示在卡片上"
---

正文从这里开始，写 Markdown。
```

### 2. 本地预览

```bash
hugo server -D --bind 0.0.0.0 --baseURL http://你手机IP:1313
```

浏览器打开 `http://localhost:1313`。`-D` 表示把 draft=true 的草稿也渲染出来。

### 3. 编译发布

```bash
hugo
```

`public/` 目录就是完整的静态站点，扔到 Cloudflare Pages / GitHub Pages / OSS 即可。

## 改配置

打开 `hugo.toml`：

- `title`：博客名
- `params.tagline`：首页那句副标题
- `params.author`：名字
- `params.github` / `params.email`：页脚链接
- `baseURL`：发布后改成你的真实域名

## 改配色

打开 `static/css/main.css`，最上面 `:root` 那几个变量：

- `--bg`：页面底色
- `--card`：卡片底色
- `--accent`：琥珀棕强调色
- `--line`：边框色

改完保存，`hugo server` 会自动刷新。

## 加新页面

比如想加一个 `/games/` 小游戏目录：

```bash
hugo new games/_index.md
```

然后把每个游戏做成 `games/游戏名.md` 或者直接把 HTML 文件丢到 `static/games/` 下，就能通过 `/games/游戏名.html` 访问。
