# 0x005 · 逆向与安全手记

我的个人博客源码，用 **Jekyll + Minimal Mistakes** 搭在 **GitHub Pages** 上。

> 站点地址：https://zhongzheng005-ux.github.io

这是一个**用户主页站**（仓库名必须叫 `zhongzheng005-ux.github.io`），
推上来之后 GitHub 会自动构建并发布，**不需要任何 CI、不需要装任何东西**。

---

## 怎么发一篇文章

在 `_posts/` 目录下新建一个文件，**文件名必须是 `日期-标题.md`** 的格式：

```
_posts/2026-09-27-my-first-post.md
```

文件内容：

```markdown
---
title: "文章标题"
date: 2026-09-27 10:00:00 +0800
categories: [逆向]
tags: [android, frida]
---

正文用 Markdown 写就行。

## 二级标题

```python
# 代码块会自动高亮
print("hello")
```
```

保存后提交推送，等大约 1 分钟 GitHub 构建完，刷新网站就能看到。

> `categories` 和 `tags` 可以随便写，会各自生成归档页（`/categories/`、`/tags/`）。
> `title` / `date` / `layout` / `comments` 这些**不用重复写** —— `_config.yml` 里已经给所有文章设好默认值了。

---

## 目录结构

```
_config.yml                  ← 全站配置（标题、主题、评论、统计……）
Gemfile                      ← 本地预览用的依赖声明
index.html                   ← 首页（落地页）
_data/navigation.yml         ← 顶部导航栏
_pages/blog.md               ← /blog/  文章归档
_pages/about.md              ← /about/ 关于
_pages/projects.md           ← /projects/ 项目
_includes/footer/custom.html ← 访问统计脚本
_posts/                      ← 文章放这里（目前是空的）
```

---

## 常改的几个地方

### 改站名 / 副标题

`_config.yml`：

```yaml
title: "0x005 · 逆向与安全手记"
description: "不定期更新，想到啥写啥"
```

### 换配色

`_config.yml` 里的 `minimal_mistakes_skin`，可选：

`default` `air` `contrast` `dark` `dirt` `mint` `sunrise` `aqua` `neon` `plum` `catppuccin_latte` `catppuccin_mocha`

### 改导航栏

`_data/navigation.yml`。

### 改侧边栏自我介绍

`_config.yml` 的 `author.bio`。

### 加项目到项目页

`_pages/projects.md` 的 `feature_row:`，照格式追一条。

---

## 启用评论（giscus）

评论区**现在还不会显示**，需要三步：

**第 1 步：给仓库开 Discussions**

仓库页面 → **Settings** → **General** → 往下拉到 **Features** → 勾上 **Discussions**。

**第 2 步：装 giscus App**

打开 👉 https://github.com/apps/giscus → 点 **Install** → 选择 `zhongzheng005-ux.github.io` 这个仓库。

**第 3 步：拿 ID 填进配置**

打开 👉 https://giscus.app → 输入仓库名 `zhongzheng005-ux/zhongzheng005-ux.github.io` →
下面会生成一段配置，把里面的两个值复制到 `_config.yml`：

```yaml
comments:
  giscus:
    repo_id: "R_kgDO..."        # ← 填这里
    category_id: "DIC_kwDO..."  # ← 和这里
```

（`category_name` 默认 `Announcements`，如果 giscus 页面显示的是别的分类名，一起改掉。）

---

## 访问统计

默认用 **[不蒜子](https://busuanzi.ibruce.info/)** —— 零注册、免登录，脚本在
`_includes/footer/custom.html`，装好就有数，页脚会显示「本站总访问量 N 次」。

如果想换成 Google Analytics：

1. 编辑 `_includes/footer/custom.html`，删掉里面那段
2. 编辑 `_config.yml`：

```yaml
analytics:
  provider: "google-gtag"
  google:
    tracking_id: "G-你的ID"
```

> ⚠️ 两者别同时开，会重复计数。

---

## 本地预览（可选）

只有想在本地看效果时才需要，**平时改完直接推上去就行**。

需要先装 Ruby，然后：

```powershell
bundle install
bundle exec jekyll serve
```

打开 http://127.0.0.1:4000 即可。

---

## 常见问题

**网站 404 / 一直没构建？**

去仓库 **Settings → Pages**，确认 **Source** 是 `Deploy from a branch`，
分支选 `main`、目录选 `/ (root)`。

**页面样式全丢了（纯文本）？**

多半是 `_config.yml` 里 `remote_theme` 那一行被改坏了。它应该是：

```yaml
remote_theme: "mmistakes/minimal-mistakes@4.28.1"
```

**构建报 `Unknown tag 'include_cached'`？**

`_config.yml` 的 `plugins:` 里必须有 `jekyll-include-cache`，别删。

**想看构建日志？**

仓库 → **Actions** 标签页，找最近一次 `pages build and deployment`。

---

## 许可

文章内容版权归作者所有；站点框架是 [Minimal Mistakes](https://github.com/mmistakes/minimal-mistakes)（MIT）。
