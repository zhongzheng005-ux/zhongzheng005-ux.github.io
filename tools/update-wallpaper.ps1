<#
.SYNOPSIS
    把「当前 Windows 桌面壁纸」同步成博客背景，并发布上线。

.DESCRIPTION
    流程：读注册表里当前桌面壁纸 → 等比缩放到不超过 2560 宽 → 存成
    source/img/wallpaper.jpg → 把 _config.butterfly.yml 的 background 指向它
    → git add/commit/push → GitHub Actions 自动重新构建（约 1~2 分钟）。

    注意：这是「手动触发的一次性同步」，不是实时镜像。
    你换了桌面壁纸但没跑这个脚本，博客上还是上一次同步的那张。

.PARAMETER Preview
    只生成图片、改配置文件，不提交也不推送。用来先看看效果。

.PARAMETER MaxWidth
    输出图最大宽度，默认 2560。调小可以加快首屏加载。

.PARAMETER Quality
    JPEG 质量 1-100，默认 86。

.EXAMPLE
    .\update-wallpaper.ps1 -Preview      # 先试一次，不上线
    .\update-wallpaper.ps1               # 同步并发布

.NOTES
    壁纸如果是「幻灯片放映」，注册表读到的会和当前显示的不一致，
    脚本会回退到 Windows 实际正在用的 TranscodedWallpaper 文件。
#>

[CmdletBinding()]
param(
    [switch]$Preview,
    [int]$MaxWidth = 2560,
    [int]$Quality = 86
)

$ErrorActionPreference = 'Stop'

# ---------- 定位仓库 ----------
$RepoRoot = $PSScriptRoot | Split-Path -Parent
if (-not (Test-Path (Join-Path $RepoRoot '_config.butterfly.yml'))) {
    throw "找不到 _config.butterfly.yml，这个脚本必须放在 <博客仓库>\tools\ 目录下。"
}

$ConfigPath = Join-Path $RepoRoot '_config.butterfly.yml'
$OutDir     = Join-Path $RepoRoot 'source\img'
$OutFile    = Join-Path $OutDir 'wallpaper.jpg'

# ---------- 找当前桌面壁纸 ----------
Write-Host '[1/4] 读取当前桌面壁纸…' -ForegroundColor Cyan
$candidate = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).WallPaper
$transcoded = Join-Path $env:APPDATA 'Microsoft\Windows\Themes\TranscodedWallpaper'

$Source = $null
if ($candidate -and (Test-Path -LiteralPath $candidate)) {
    $Source = $candidate
} elseif (Test-Path -LiteralPath $transcoded) {
    $Source = $transcoded
} elseif (Test-Path -LiteralPath "${transcoded}.jpg") {
    $Source = "${transcoded}.jpg"
}

if (-not $Source) {
    throw '读不到桌面壁纸路径。可能是「幻灯片放映」且缓存被清了，先手动设置一张静态壁纸再跑一次。'
}
Write-Host "      素材：$Source"

# ---------- 缩放并转 JPEG ----------
Write-Host "[2/4] 缩放（最大 ${MaxWidth}px 宽，质量 ${Quality}）…" -ForegroundColor Cyan
Add-Type -AssemblyName System.Drawing

$img = $null
$bmp = $null
$gfx = $null
try {
    # 用 FileStream 打开，避免 Image.FromFile 把文件句柄占住导致后面换壁纸失败
    $fs = [System.IO.File]::Open($Source, 'Open', 'Read', 'ReadWrite')
    $img = [System.Drawing.Image]::FromStream($fs, $true, $true)

    $ratio = [Math]::Min(1.0, $MaxWidth / [double]$img.Width)
    $w = [int][Math]::Round($img.Width  * $ratio)
    $h = [int][Math]::Round($img.Height * $ratio)
    if ($w -lt 1) { $w = 1 }
    if ($h -lt 1) { $h = 1 }

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gfx.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gfx.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gfx.DrawImage($img, 0, 0, $w, $h)

    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
             Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
    $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, [int]$Quality)

    if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
    $bmp.Save($OutFile, $codec, $encParams)
}
finally {
    if ($gfx) { $gfx.Dispose() }
    if ($bmp) { $bmp.Dispose() }
    if ($img) { $img.Dispose() }
    if ($fs)  { $fs.Dispose() }
}

$kb = [Math]::Round((Get-Item $OutFile).Length / 1KB, 1)
Write-Host "      输出：$OutFile （$kb KB）" -ForegroundColor Green
if ($kb -gt 2500) {
    Write-Warning "图片有 $kb KB，首屏可能会慢。可以加大压缩：.\update-wallpaper.ps1 -MaxWidth 1920 -Quality 78"
}

# ---------- 把配置指向 wallpaper.jpg ----------
Write-Host '[3/4] 更新 _config.butterfly.yml…' -ForegroundColor Cyan
$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
$target = 'background: /img/wallpaper.jpg'
if ($cfg -match '(?m)^background:\s*\S+') {
    $newCfg = [regex]::Replace($cfg, '(?m)^background:\s*\S+', $target, 1)
} else {
    throw '_config.butterfly.yml 里找不到 background: 这一行。'
}
if ($newCfg -ne $cfg) {
    [System.IO.File]::WriteAllText($ConfigPath, $newCfg, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host '      已改为 background: /img/wallpaper.jpg' -ForegroundColor Green
} else {
    Write-Host '      已经是 wallpaper.jpg，无需改动'
}

if ($Preview) {
    Write-Host ''
    Write-Host '预览模式：图片和配置都改好了，但没有提交。' -ForegroundColor Yellow
    Write-Host '想上线的话，去掉 -Preview 再跑一次。' -ForegroundColor Yellow
    Write-Host '想现在看效果：npx hexo server 然后打开 http://localhost:4000' -ForegroundColor Yellow
    return
}

# ---------- 提交 + 推送 ----------
Write-Host '[4/4] 提交并推送…' -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    $git = 'git'
    # 注意：git 会把正常进度写到 stderr，PowerShell 会误判成错误并中断脚本，
    # 所以统一用 2>&1 合并后再看 $LASTEXITCODE。
    & $git add 'source/img/wallpaper.jpg' '_config.butterfly.yml' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'git add 失败' }

    & $git diff --cached --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '      没有变化，跳过提交' -ForegroundColor Yellow
    } else {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        & $git -c core.quotepath=false commit -m "chore: sync desktop wallpaper ($stamp)" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git commit 失败' }

        & $git push origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git push 失败（检查网络/代理：git config --global http.proxy）' }
        Write-Host ''
        Write-Host '✅ 已推送。GitHub Actions 大概 1~2 分钟后重新构建完成，' -ForegroundColor Green
        Write-Host '   然后所有访客打开博客看到的就是这张壁纸。' -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
