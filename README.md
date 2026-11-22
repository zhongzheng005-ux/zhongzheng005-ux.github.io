# Eclipse的博客

> 站点地址：https://zhongzheng005-ux.github.io

**Hexo 7 + [Butterfly](https://butterfly.js.org/) 主题**，部署在 **GitHub Pages**（用户主页站）。

推上来就完事 —— **不用本地装 Node、不用跑任何命令**，GitHub Actions 会自动构建发布。

---

## 首次上线要在这里点一下 ⚠️

仓库 → **Settings** → 左侧 **Pages** → **Build and deployment**

- **Source** 选 **GitHub Actions**（不是 "Deploy from a branch"）

保存之后，每次 push 到 `main` 都会自动构建，1～2 分钟后上线。

---

## 怎么发一篇文章

在 `source/_posts/` 下新建 `标题.md`（中文标题可以），内容：

```markdown
---
title: 我的第一篇文章
date: 2026-11-22 13:00:00
tags:
  - 逆向
  - 安卓
categories:
  - 技术
description: 一句话简介，会显示在首页卡片上
cover:
top_img:
---

正文，正常写 Markdown。
```

然后：

```bash
git add .
git commit -m "new post"
git push
```

等 Actions 跑完就上线了。

### 想本地预览

需要先装 [Node.js](https://nodejs.org/)：

```bash
npm install
npx hexo server        # 打开 http://localhost:4000
```

---

## 文件都管什么

| 文件 | 作用 |
|---|---|
| `_config.yml` | 站点本身：站名、网址、语言、分页、永久链接 |
| `_config.butterfly.yml` | **外观全在这**：头像、菜单、侧栏卡片、打字机、字数统计、暗色模式、评论 |
| `package.json` | 依赖清单（Hexo 和主题版本） |
| `.github/workflows/pages.yml` | 自动构建部署的流程 |
| `source/_posts/` | **文章都放这里** |
| `source/img/avatar.jpg` | 头像 |
| `source/tags/index.md` | 标签页 |
| `source/categories/index.md` | 分类页 |
| `scaffolds/` | 新建文章的模板 |

---

## 常见改动

### 改头像
替换 `source/img/avatar.jpg`。

### 改侧栏那句自我介绍
`_config.butterfly.yml` → `aside.card_author.description`。

### 改打字机副标题
`_config.butterfly.yml` → `subtitle.sub` 那个列表，加一行就多一句轮播。

### 关掉某个侧栏卡片
`_config.butterfly.yml` → `aside.card_xxx.enable: false`。

### 开评论（giscus）

1. 仓库 → **Settings** → **General** → 往下找到 **Features** → 勾上 **Discussions**
2. 打开 https://giscus.app ，填入仓库 `zhongzheng005-ux/zhongzheng005-ux.github.io`
3. 它会给你两个值，填到 `_config.butterfly.yml`：
   ```yaml
   giscus:
     repo: zhongzheng005-ux/zhongzheng005-ux.github.io
     repo_id: <填这里>
     category_id: <填这里>
   ```
4. push，评论就出来了

---

## 页面里都有什么

- **首页** —— 文章卡片列表，带渐变封面
- **归档** —— 按时间分组
- **标签 / 分类** —— 自动从文章 front-matter 生成
- **搜索** —— 本地全文搜索，不依赖任何第三方服务
- **侧栏** —— 头像卡、公告、最近文章、分类、标签、归档、**站点概览**（总字数 / 阅读时长 / 载入天数）
- **暗色模式** —— 右下角齿轮切换
- **访问量** —— 不蒜子统计，免费、不用注册

---

## 技术栈

- [Hexo](https://hexo.io/) 7.3
- [hexo-theme-butterfly](https://www.npmjs.com/package/hexo-theme-butterfly) 5.7（npm 安装，无需 submodule）
- hexo-generator-searchdb（本地搜索）
- hexo-wordcount（字数 / 阅读时长）
- GitHub Actions + GitHub Pages
