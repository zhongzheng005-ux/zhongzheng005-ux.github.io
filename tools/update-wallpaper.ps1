<#
.SYNOPSIS
    把「当前正在用的壁纸」同步成博客背景，并发布上线。

.DESCRIPTION
    自动识别两种来源：
      1. Wallpaper Engine —— 读它的 config.json，拿到当前每台显示器在用的那张壁纸。
         如果是视频（.mp4/.webm/.mkv…），会用 ffmpeg 压成 720p 循环视频 + 一张海报图，
         博客背景就是「动」的。
      2. Windows 桌面壁纸 —— 读注册表（幻灯片时回退到 TranscodedWallpaper 缓存），
         等比缩放成 JPEG，博客背景是静态图。

    然后自动改 _config.butterfly.yml、git add/commit/push。
    GitHub Actions 大约 1~2 分钟后重新构建，之后所有访客看到的就是这张壁纸。

.PARAMETER Preview
    只生成素材和改配置，不 commit、不 push。先看效果用。

.PARAMETER Source
    auto（默认）/ wallpaper-engine / windows —— 强制指定来源。

.PARAMETER MaxWidth
    静态图最大宽度，默认 2560。

.PARAMETER Quality
    静态 JPEG 质量，默认 86。

.PARAMETER VideoCrf
    视频压缩质量，默认 24。数字越小越清晰、文件越大；20~26 很清晰，30~38 体积小但会糊。

.PARAMETER VideoHeight
    背景视频的高度，默认 1080（宽 1920）。想要更清晰可以用 1440（2560x1440，体积大约翻倍），
    想省流量用 720。

.PARAMETER VideoFps
    背景视频帧率，默认 30（和绝大多数壁纸源一致）。降到 24 能省一点体积但会显得卡。

.PARAMETER VideoSeconds
    视频最多截取多少秒，默认 60。壁纸太长会让背景视频变得很重。

.EXAMPLE
    .\update-wallpaper.ps1 -Preview
    .\update-wallpaper.ps1
    .\update-wallpaper.ps1 -VideoHeight 1440 -VideoCrf 22
    .\update-wallpaper.ps1 -VideoHeight 720 -VideoCrf 30 -VideoSeconds 30

.NOTES
    「同步」不是实时的：你换了壁纸，博客不会自己变，想变就再跑一次这个脚本。
    视频壁纸需要 ffmpeg；本机没有的话脚本会自动下载一份到 tools\bin\（约 90 MB，只下一次）。
#>

[CmdletBinding()]
param(
    [switch]$Preview,
    [ValidateSet('auto', 'wallpaper-engine', 'windows')]
    [string]$Source = 'auto',
    [int]$MaxWidth = 2560,
    [int]$Quality = 86,
    [int]$VideoCrf = 24,
    [int]$VideoHeight = 1080,
    [int]$VideoFps = 30,
    [int]$VideoSeconds = 60
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ConfigPath = Join-Path $RepoRoot '_config.butterfly.yml'
$ImgDir     = Join-Path $RepoRoot 'source\img'
$BinDir     = Join-Path $RepoRoot 'tools\bin'

if (-not (Test-Path $ConfigPath)) {
    throw "找不到 _config.butterfly.yml。这个脚本必须放在 <博客仓库>\tools\ 目录下。"
}
if (-not (Test-Path $ImgDir)) { New-Item -ItemType Directory -Path $ImgDir -Force | Out-Null }

# ============================================================
# 1. 找壁纸来源
# ============================================================
Write-Host '[1/5] 查找当前壁纸…' -ForegroundColor Cyan

function Find-WallpaperEngineConfig {
    $roots = @()
    foreach ($d in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        if ($d.Root -match '^[A-Za-z]:\\$') { $roots += $d.Root }
    }
    foreach ($r in $roots) {
        foreach ($rel in @(
            'SteamLibrary\steamapps\common\wallpaper_engine\config.json',
            'Steam\steamapps\common\wallpaper_engine\config.json',
            'Program Files (x86)\Steam\steamapps\common\wallpaper_engine\config.json',
            'Program Files\Steam\steamapps\common\wallpaper_engine\config.json',
            'Games\SteamLibrary\steamapps\common\wallpaper_engine\config.json'
        )) {
            $p = Join-Path $r $rel
            if (Test-Path -LiteralPath $p) { return $p }
        }
    }
    return $null
}

function Get-WallpaperEngineCurrent {
    param([string]$ConfigFile)
    $j = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $j.PSObject.Properties) {
        $general = $prop.Value.general
        if (-not $general) { continue }
        $wc = $general.wallpaperconfig
        if (-not $wc -or -not $wc.selectedwallpapers) { continue }
        foreach ($mon in $wc.selectedwallpapers.PSObject.Properties) {
            $f = $mon.Value.file
            if ($f -and (Test-Path -LiteralPath $f)) {
                return [pscustomobject]@{ Path = $f; Monitor = $mon.Name }
            }
        }
    }
    return $null
}

$resolved = $null
$weConfig = if ($Source -ne 'windows') { Find-WallpaperEngineConfig } else { $null }

if ($weConfig) {
    $we = Get-WallpaperEngineCurrent -ConfigFile $weConfig
    if ($we) {
        $resolved = [pscustomobject]@{ Path = $we.Path; Kind = 'wallpaper-engine'; Detail = $we.Monitor }
        Write-Host "      Wallpaper Engine：$($we.Path)" -ForegroundColor Green
        Write-Host "      （$($weConfig)）"
    }
}

if (-not $resolved -and $Source -ne 'wallpaper-engine') {
    $reg = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).WallPaper
    $trans = Join-Path $env:APPDATA 'Microsoft\Windows\Themes\TranscodedWallpaper'
    $cand = $null
    if ($reg -and (Test-Path -LiteralPath $reg)) { $cand = $reg }
    elseif (Test-Path -LiteralPath $trans) { $cand = $trans }
    elseif (Test-Path -LiteralPath "${trans}.jpg") { $cand = "${trans}.jpg" }
    if ($cand) {
        $resolved = [pscustomobject]@{ Path = $cand; Kind = 'windows'; Detail = '注册表' }
        Write-Host "      Windows 桌面壁纸：$cand" -ForegroundColor Green
    }
}

if (-not $resolved) {
    throw '找不到任何壁纸来源。可能 Wallpaper Engine 没运行、Windows 也没设静态壁纸。'
}

$srcPath = $resolved.Path
$ext = [System.IO.Path]::GetExtension($srcPath).ToLowerInvariant()
$videoExts = @('.mp4', '.webm', '.mkv', '.mov', '.avi', '.wmv', '.flv')
$isVideo = $videoExts -contains $ext
$srcInfo = Get-Item -LiteralPath $srcPath
Write-Host ("      类型：{0}  大小：{1:N1} MB" -f ($(if ($isVideo) { '视频' } else { '图片' })), ($srcInfo.Length / 1MB))

# ============================================================
# 2a. 视频：找 ffmpeg
# ============================================================
function Resolve-Ffmpeg {
    $local = Join-Path $BinDir 'ffmpeg.exe'
    if (Test-Path -LiteralPath $local) { return $local }

    $cmd = Get-Command 'ffmpeg.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    Write-Host '      本机没有 ffmpeg，自动下载一份（约 90 MB，只下一次）…' -ForegroundColor Yellow
    if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir -Force | Out-Null }

    $zip = Join-Path $BinDir 'ffmpeg.zip'
    $url = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
    $ok = $false
    try {
        & curl.exe -L --fail --silent --show-error -o $zip $url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $zip)) { $ok = $true }
    } catch { }
    if (-not $ok) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
            $ok = $true
        } catch { }
    }
    if (-not $ok) { throw '下载 ffmpeg 失败。可以自己装一个 ffmpeg 放进 tools\bin\ffmpeg.exe 再跑。' }

    $tmp = Join-Path $BinDir '_unzip'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
    $found = Get-ChildItem $tmp -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
    if (-not $found) { throw 'ffmpeg 压缩包里没找到 ffmpeg.exe。' }
    Copy-Item $found.FullName (Join-Path $BinDir 'ffmpeg.exe') -Force
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Write-Host "      已就绪：$(Join-Path $BinDir 'ffmpeg.exe')" -ForegroundColor Green
    return (Join-Path $BinDir 'ffmpeg.exe')
}

# ---------- 生成素材 ----------
$assetsToAdd    = @()
$assetsToRemove = @()
$bgValue        = $null
$mode           = $null

if ($isVideo) {
    Write-Host '[2/5] 压缩视频壁纸…' -ForegroundColor Cyan
    $ff = Resolve-Ffmpeg

    $outMp4 = Join-Path $ImgDir 'wallpaper-bg.mp4'
    $outJpg = Join-Path $ImgDir 'wallpaper-poster.jpg'

    & $ff -y -hide_banner -loglevel error -i $srcPath -an -sn -t $VideoSeconds `
        -vf "scale=-2:$VideoHeight`:flags=lanczos,fps=$VideoFps" `
        -c:v libx264 -preset medium -crf $VideoCrf -pix_fmt yuv420p `
        -profile:v high -level 4.2 -movflags +faststart $outMp4
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outMp4)) { throw '视频压缩失败（ffmpeg 返回非 0）。' }

    $posterW = [int]($VideoHeight * 16 / 9)
    & $ff -y -hide_banner -loglevel error -ss 00:00:03 -i $srcPath -frames:v 1 `
        -vf "scale=${posterW}:$VideoHeight`:flags=lanczos" -q:v 2 $outJpg
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outJpg)) { throw '海报图抽取失败。' }

    $mp4MB = (Get-Item $outMp4).Length / 1MB
    Write-Host ("      wallpaper-bg.mp4    {0:N1} MB  ({1}p{2})" -f $mp4MB, $VideoHeight, $VideoFps) -ForegroundColor Green
    Write-Host ("      wallpaper-poster.jpg {0:N0} KB" -f ((Get-Item $outJpg).Length / 1KB)) -ForegroundColor Green
    if ($mp4MB -gt 40) {
        Write-Warning "背景视频 $([math]::Round($mp4MB,1)) MB 偏大（访客要下这么多）。可以降一档：-VideoHeight 720 -VideoCrf 28"
    }

    $mode = 'video'
    $bgValue = '/img/wallpaper-poster.jpg'
    $assetsToAdd = @('source/img/wallpaper-bg.mp4', 'source/img/wallpaper-poster.jpg')
    $assetsToRemove = @('source/img/wallpaper.jpg')
}
else {
    Write-Host "[2/5] 缩放图片壁纸（最大 ${MaxWidth}px 宽，质量 ${Quality}）…" -ForegroundColor Cyan
    Add-Type -AssemblyName System.Drawing

    $outJpg = Join-Path $ImgDir 'wallpaper.jpg'
    $img = $null; $bmp = $null; $gfx = $null; $fs = $null
    try {
        $fs = [System.IO.File]::Open($srcPath, 'Open', 'Read', 'ReadWrite')
        $img = [System.Drawing.Image]::FromStream($fs, $true, $true)
        $ratio = [Math]::Min(1.0, $MaxWidth / [double]$img.Width)
        $w = [Math]::Max(1, [int][Math]::Round($img.Width * $ratio))
        $h = [Math]::Max(1, [int][Math]::Round($img.Height * $ratio))
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gfx.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $gfx.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $gfx.DrawImage($img, 0, 0, $w, $h)

        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                 Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
        $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality, [int]$Quality)
        if (Test-Path $outJpg) { Remove-Item $outJpg -Force }
        $bmp.Save($outJpg, $codec, $encParams)
    }
    finally {
        if ($gfx) { $gfx.Dispose() }
        if ($bmp) { $bmp.Dispose() }
        if ($img) { $img.Dispose() }
        if ($fs)  { $fs.Dispose() }
    }
    Write-Host ("      wallpaper.jpg {0:N0} KB" -f ((Get-Item $outJpg).Length / 1KB)) -ForegroundColor Green

    $mode = 'image'
    $bgValue = '/img/wallpaper.jpg'
    $assetsToAdd = @('source/img/wallpaper.jpg')
    $assetsToRemove = @('source/img/wallpaper-bg.mp4', 'source/img/wallpaper-poster.jpg')
}

# ============================================================
# 3. 改 _config.butterfly.yml
# ============================================================
Write-Host '[3/5] 更新 _config.butterfly.yml…' -ForegroundColor Cyan
$cfg = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)

# 3.1 background: 指向兜底图
if ($cfg -notmatch '(?m)^background:') { throw '_config.butterfly.yml 里找不到 background: 这一行。' }
$cfg = [regex]::Replace($cfg, '(?m)^background:\s*\S+', "background: $bgValue", 1)

# 3.2 托管块
$block = @'
    # >>> wallpaper (managed) >>>
    # 这一段由 tools/update-wallpaper.ps1 自动维护，手改也可以，但脚本换壁纸时会被重写。
    # veil 是压暗蒙版（壁纸偏亮时保证白色标题看得清），video 是动态壁纸本体，
    # poster 是首屏兜底图：视频还没加载出来时先显示它。
    - <div id="ec-bg-veil" aria-hidden="true"></div>
    - <video id="ec-bg-video" autoplay muted loop playsinline preload="auto" poster="/img/wallpaper-poster.jpg" aria-hidden="true"><source src="/img/wallpaper-bg.mp4" type="video/mp4"></video>
    # <<< wallpaper (managed) <<<
'@ -split "`r?`n" | ForEach-Object { $_.TrimEnd() }
$dynamicBlock = ($block -join "`n")

if ($mode -eq 'video') {
    if ($cfg -match '(?s)# >>> wallpaper \(managed\) >>>.*?# <<< wallpaper \(managed\) <<<') {
        $cfg = [regex]::Replace($cfg, '(?s)[ \t]*# >>> wallpaper \(managed\) >>>.*?# <<< wallpaper \(managed\) <<<', { param($m) $dynamicBlock })
    } else {
        # 没有托管块就插到 inject.bottom 的第一行后面
        $cfg = [regex]::Replace($cfg, '(?m)^(  bottom:\s*)$', { param($m) $m.Groups[1].Value + "`n" + $dynamicBlock }, 1)
    }
    Write-Host '      已启用动态壁纸（视频 + 压暗蒙版）' -ForegroundColor Green
}
else {
    if ($cfg -match '(?s)# >>> wallpaper \(managed\) >>>.*?# <<< wallpaper \(managed\) <<<') {
        $cfg = [regex]::Replace($cfg, '(?s)[ \t]*# >>> wallpaper \(managed\) >>>.*?# <<< wallpaper \(managed\) <<<[ \t]*\r?\n', '')
    }
    Write-Host '      已切回静态壁纸（去掉视频层）' -ForegroundColor Green
}

[System.IO.File]::WriteAllText($ConfigPath, $cfg, (New-Object System.Text.UTF8Encoding($false)))

# 清掉上一模式遗留的素材
foreach ($rel in $assetsToRemove) {
    $p = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $p) { Remove-Item $p -Force; Write-Host "      删除不再需要的 $rel" }
}

# ============================================================
# 4/5 预览或提交
# ============================================================
if ($Preview) {
    Write-Host ''
    Write-Host '预览模式：素材和配置都改好了，但没有提交。' -ForegroundColor Yellow
    Write-Host '看效果：npx hexo server  然后打开 http://localhost:4000' -ForegroundColor Yellow
    Write-Host '想上线就再跑一次去掉 -Preview。' -ForegroundColor Yellow
    return
}

Write-Host '[4/5] 提交并推送…' -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    # git 会把正常进度写到 stderr，PowerShell 会误判成错误中断脚本，统一 2>&1
    & git add -A 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'git add 失败' }

    & git diff --cached --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '      没有变化，跳过提交' -ForegroundColor Yellow
    } else {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        $msg = if ($mode -eq 'video') { "chore: sync wallpaper-engine video background ($stamp)" }
               else { "chore: sync windows wallpaper background ($stamp)" }
        & git -c core.quotepath=false commit -m $msg 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git commit 失败' }

        & git push origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git push 失败（检查网络/代理：git config --global http.proxy）' }
        Write-Host ''
        Write-Host '✅ 已推送。GitHub Actions 大约 1~2 分钟后构建完成，' -ForegroundColor Green
        Write-Host '   之后所有访客打开博客看到的就是这张壁纸。' -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
