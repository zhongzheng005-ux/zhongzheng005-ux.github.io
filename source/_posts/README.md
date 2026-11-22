# 写文章就放这个目录里

文件名规则：`标题.md`（中文标题也完全没问题）

一篇文章长这样：

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
cover:                 # 留空就用主题的渐变色封面
top_img:               # 留空就用封面的颜色
---

正文从这里开始，正常写 Markdown 就行。
```

写完 commit + push，GitHub Actions 会自动构建发布，大约 1～2 分钟。

本地预览（需要先装 Node）：

```bash
npm install
npx hexo server      # 打开 http://localhost:4000
```
