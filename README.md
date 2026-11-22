# Eclipse的博客

> 站点地址：https://zhongzheng005-ux.github.io

**Hexo 7 + [Butterfly](https://butterfly.js.org/) 主题**，部署在 **GitHub Pages**（用户主页站）。

推上来就完事 —— **不用本地装 Node、不用跑任何命令**，GitHub Actions 会自动构建发布。

外观是定制过的：**全屏壁纸 + 毛玻璃卡片 + 粒子吸附特效**。详见下面「换壁纸」。

---

## 首次上线要在这里点一下 ⚠️

仓库 → **Settings** → 左侧 **Pages** → **Build and deployment**

- **Source** 选 **GitHub Actions**（不是 "Deploy from a branch"）

保存之后，每次 push 到 `main` 都会自动构建，1～2 分钟后上线。

---

## 🖼 换壁纸（重点）

全站背景由 `_config.butterfly.yml` 里**这一行**控制：

```yaml
background: /img/bg.svg
```

### 换内置预设（一个词的事）

`source/img/` 里已经放好三张：

| 换成 | 效果 |
|---|---|
| `background: /img/bg.svg` | 深蓝紫渐变 + 网格（默认，最"技术感"） |
| `background: /img/bg-aurora.svg` | 极光，青绿 + 紫，颜色最活泼 |
| `background: /img/bg-midnight.svg` | 星空银河，最暗，长时间看最舒服 |

### 换成你自己的照片 / 图片

1. 把图片放进 **`source/img/`** 目录，比如 `source/img/my-wallpaper.jpg`
2. 把配置改成：
   ```yaml
   background: /img/my-wallpaper.jpg
   ```
3. push，1～2 分钟生效

- 支持 `jpg` / `png` / `webp` / `svg`，**也支持 `gif` 动图**
- 推荐 **1920×1080 或更大、横图**；会自动铺满屏幕、保持比例不变形
- 图片太大（>2MB）会让首屏变慢，建议先压一下

### 不想要图片，想要纯色/渐变也行

这行接受任何 CSS 背景值：

```yaml
background: linear-gradient(135deg, #0f172a, #1e293b)
```

### 顺便：首页横幅的图

首页那句大标题背后的画面是**透明的**（故意让它和壁纸连成一片），所以换了壁纸首屏会一起变。
如果想让首屏跟全站壁纸**不一样**，改这两行：

```yaml
index_img: /img/hero.jpg      # 首页横幅专用图
default_top_img: /img/bg.svg  # 其它页面兜底
```

### 一键把「当前壁纸」同步成博客背景（支持 Wallpaper Engine）

想让自己电脑上的壁纸直接当博客背景，用这个脚本：

```powershell
cd F:\dsh-mcp\blog

# 先试一次：只生成素材、改配置，不提交
.\tools\update-wallpaper.ps1 -Preview

# 满意了就去掉 -Preview，它会自动 commit + push
.\tools\update-wallpaper.ps1
```

**它会自动判断你用的是什么壁纸：**

| 你的壁纸 | 脚本的做法 | 博客上的效果 |
|---|---|---|
| **Wallpaper Engine**（视频壁纸 `.mp4`） | 用 ffmpeg 压成 720p/24fps 循环视频（约 3~5 MB）+ 抽一张海报图 | **会动的背景** |
| **Wallpaper Engine**（图片壁纸） | 等比缩放成 JPEG | 静态背景 |
| **Windows 桌面壁纸**（静态图） | 等比缩放到不超过 2560 宽、转 JPEG | 静态背景 |

来源优先级：装了 Wallpaper Engine 就读它的 `config.json` 里**当前每台显示器在用的那张**（所以你在 WE 里换壁纸后跑一下脚本，博客就跟着变）；没有 WE 才回退到 Windows 注册表。
用 `-Source windows` 可以强制忽略 WE。

几个要留意的点：

- **不是实时同步**。你换了壁纸，博客不会自己变；想变就再跑一次脚本。
- 视频壁纸要 ffmpeg。本机没有的话脚本会**自动下载一份**到 `tools\bin\`（约 105 MB，只下一次，已被 `.gitignore` 排除，不会进仓库）。也可以自己装一个丢进 `tools\bin\ffmpeg.exe`。
- 视频太大就压狠一点：`.\tools\update-wallpaper.ps1 -VideoCrf 38 -VideoSeconds 30`（数字越大体积越小）
- 静态图太大首屏会慢：`.\tools\update-wallpaper.ps1 -MaxWidth 1920 -Quality 78`
- 想换回内置壁纸，把 `background:` 改回 `/img/bg.svg`（或 aurora / midnight），
  并把 `inject.bottom` 里 `# >>> wallpaper (managed) >>>` 到 `# <<< wallpaper (managed) <<<` 之间那段删掉再 push。
- 「幻灯片放映」时注册表里的路径可能和实际显示的不一致，脚本会回退去读 Windows 真正在用的
  `TranscodedWallpaper` 缓存文件。
- 那层压暗蒙版（`#ec-bg-veil`）是给白色标题保清晰度用的，壁纸很暗的话可以把
  `source/css/custom.css` 里它的透明度调低。
- 脚本需要系统里有 PowerShell 和 git；push 走的是仓库已经配好的凭据。

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
cover:            # 不填会自动分配一个渐变封面
top_img:          # 不填则用全站壁纸
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

改 `_config.butterfly.yml` 后要**重启** server；改 css / 文章 / 图片会自动热更新。

---

## 文件都管什么

| 文件 | 作用 |
|---|---|
| `_config.yml` | 站点本身：站名、网址、语言、永久链接 |
| `_config.butterfly.yml` | **外观全在这**：壁纸、头像、菜单、侧栏卡片、打字机、字数统计、暗色模式、评论、粒子特效 |
| `source/css/custom.css` | **定制美化层**：毛玻璃卡片、透明顶栏、渐变按钮、滚动条、暗色变量 |
| `source/js/canvas-nest.min.js` | 鼠标吸附粒子网（已内置，不走 CDN） |
| `source/img/bg*.svg` | 三张内置壁纸 |
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

### 关掉鼠标粒子特效
`_config.butterfly.yml` → `canvas_nest.enable: false`。
想调粗细疏密：`color`（RGB，逗号分隔）、`opacity`、`count`（粒子数，越多越密也越吃性能）。

### 关掉某个侧栏卡片
`_config.butterfly.yml` → `aside.card_xxx.enable: false`。

### 改整体配色
`source/css/custom.css` 开头的 `:root` 变量：
```css
--ec-accent: #6366f1;      /* 主色 */
--ec-accent-2: #22d3ee;    /* 辅色 */
--ec-card-bg: rgba(255, 255, 255, 0.9);  /* 卡片底色，越小越透 */
--ec-radius: 18px;         /* 圆角 */
```

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

> 当前仓库的 giscus **已经配好了**（repo_id / category_id 已填），这条留作参考。

---

## 页面里都有什么

- **首页** —— 文章卡片列表，带渐变封面
- **归档** —— 按时间分组
- **标签 / 分类** —— 自动从文章 front-matter 生成
- **搜索** —— 本地全文搜索，不依赖任何第三方服务
- **侧栏** —— 头像卡、公告、最近文章、归档、**站点概览**（字数 / 载入天数）
- **暗色模式** —— 右下角齿轮切换
- **粒子网** —— 鼠标移过去会被"吸"住连线
- **访问量** —— 不蒜子统计；如果连不上，那两行会自动隐藏（不会一直转圈）

---

## 技术栈

- [Hexo](https://hexo.io/) 7.3
- [hexo-theme-butterfly](https://www.npmjs.com/package/hexo-theme-butterfly) 5.7（npm 安装，无需 submodule）
- hexo-generator-searchdb（本地搜索）
- hexo-wordcount（字数 / 阅读时长）
- hexo-theme-butterfly-extsrc 的 canvas-nest（粒子吸附，已下载到本地）
- GitHub Actions + GitHub Pages
