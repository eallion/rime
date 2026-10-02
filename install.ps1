# ==============================================================================
# Rime 小狼毫五笔拼音一键部署脚本 (Windows PowerShell)
# ==============================================================================

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RimeSrcDir = Join-Path $ScriptDir "rime"
$TargetDir = "$env:APPDATA\Rime"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " 开始部署 Rime 小狼毫 (Weasel) 五笔拼音环境" -ForegroundColor Cyan
Write-Host " 配置文件源目录: $RimeSrcDir" -ForegroundColor Cyan
Write-Host " 目标用户文件夹: $TargetDir" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. 检查或安装 Weasel 小狼毫
# ------------------------------------------------------------------------------
$WeaselInstalled = $false
$WeaselProgramPaths = @(
    "$env:ProgramFiles\Rime",
    "${env:ProgramFiles(x86)}\Rime"
)

foreach ($path in $WeaselProgramPaths) {
    if (Test-Path $path) {
        $WeaselInstalled = $true
        break
    }
}

if (-not $WeaselInstalled) {
    Write-Host "[+] 未检测到已安装的小狼毫，尝试通过 winget 安装..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Rime.Weasel --accept-package-agreements --accept-source-agreements
        # 重新检测是否成功安装
        foreach ($path in $WeaselProgramPaths) {
            if (Test-Path $path) {
                $WeaselInstalled = $true
                break
            }
        }
        if ($WeaselInstalled) {
            Write-Host "[+] 小狼毫安装完成。" -ForegroundColor Green
        } else {
            Write-Warning "winget 自动安装未成功完成。请手动下载安装包: https://rime.im/download/"
        }
    } else {
        Write-Warning "未找到 winget 包管理器，请手动下载并安装小狼毫: https://rime.im/download/"
    }
} else {
    Write-Host "[+] 检测到已安装的小狼毫 (Weasel)。" -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 2. 检查并自动安装基础方案依赖 (wubi & pinyin-simp)
# ------------------------------------------------------------------------------
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$WubiPinyinExists = (Test-Path "$TargetDir\wubi_pinyin.schema.yaml") -and (Test-Path "$TargetDir\wubi86.dict.yaml")
if (-not $WubiPinyinExists) {
    foreach ($basePath in $WeaselProgramPaths) {
        if ((Test-Path "$basePath\data\wubi_pinyin.schema.yaml") -and (Test-Path "$basePath\data\wubi86.dict.yaml")) {
            $WubiPinyinExists = $true
            break
        }
    }
}

if (-not $WubiPinyinExists) {
    Write-Host "[+] 正在自动下载并部署五笔与拼音依赖方案 (rime-wubi, rime-pinyin-simp)..." -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $packages = @(
            @{ Name = "rime-wubi"; Url = "https://github.com/rime/rime-wubi/archive/refs/heads/master.zip" },
            @{ Name = "rime-pinyin-simp"; Url = "https://github.com/rime/rime-pinyin-simp/archive/refs/heads/master.zip" }
        )
        foreach ($pkg in $packages) {
            $zipPath = Join-Path $env:TEMP "$($pkg.Name).zip"
            Write-Host "  -> 下载 $($pkg.Name) ..." -ForegroundColor Gray
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                curl.exe -s -L -o $zipPath $pkg.Url
            } else {
                Invoke-WebRequest -Uri $pkg.Url -OutFile $zipPath -UseBasicParsing
            }
            if (Test-Path $zipPath) {
                $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
                foreach ($entry in $archive.Entries) {
                    if ($entry.Name -and ($entry.Name.EndsWith(".yaml") -or $entry.Name.EndsWith(".txt"))) {
                        $destFile = Join-Path $TargetDir $entry.Name
                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destFile, $true)
                    }
                }
                $archive.Dispose()
                Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "[+] 五笔与拼音方案依赖安装就绪。" -ForegroundColor Green
    } catch {
        Write-Warning "自动下载依赖方案遇到网络问题 ($($_.Exception.Message))。可稍后通过小狼毫内置的'获取更多输入方案'安装。"
    }
}

# ------------------------------------------------------------------------------
# 3. 复制核心自定义配置文件
# ------------------------------------------------------------------------------
Write-Host "[+] 正在复制核心配置文件到 $TargetDir ..." -ForegroundColor Cyan

$FilesToCopy = @(
    "default.custom.yaml",
    "wubi_pinyin.custom.yaml",
    "custom_phrase.txt",
    "mysymbols.yaml",
    "weasel.custom.yaml",
    "fcitx5.custom.yaml",
    "squirrel.custom.yaml"
)

foreach ($file in $FilesToCopy) {
    $src = Join-Path $RimeSrcDir $file
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $TargetDir -Force
        Write-Host "  -> 已复制: $file" -ForegroundColor Gray
    }
}

# ------------------------------------------------------------------------------
# 4. 执行自动编译与部署
# ------------------------------------------------------------------------------
Write-Host "[+] 查找 Weasel 部署器以自动编译配置..." -ForegroundColor Cyan

$Deployer = $null
foreach ($path in $WeaselProgramPaths) {
    if (Test-Path $path) {
        $found = Get-ChildItem -Path $path -Filter "WeaselDeployer.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $Deployer = $found.FullName
            break
        }
    }
}

if ($Deployer) {
    Write-Host "[+] 正在静默执行方案编译与部署..." -ForegroundColor Cyan
    # 使用 ProcessStartInfo 精确传递参数 /deploy，避免多余空格导致弹出方案选单界面
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Deployer
    $psi.Arguments = "/deploy"
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()

    $compiledPrism = Join-Path $TargetDir "build\wubi_pinyin.prism.bin"
    if (Test-Path $compiledPrism) {
        Write-Host "[+] 小狼毫配置与五笔拼音方案静默编译完成！" -ForegroundColor Green
    } else {
        Write-Host "[+] 小狼毫部署指令已发送。" -ForegroundColor Green
    }
} else {
    if (-not $WeaselInstalled) {
        Write-Warning "小狼毫尚未安装。核心配置文件已复制就绪，请在安装小狼毫后重新运行本脚本或手动部署。"
    } else {
        Write-Host "[*] 未能直接调用 WeaselDeployer.exe，请在 Windows 托盘小狼毫图标右键菜单中点击'重新部署'。" -ForegroundColor Yellow
    }
}

$statusColor = if ($WeaselInstalled) { "Green" } else { "Yellow" }
Write-Host "==================================================" -ForegroundColor $statusColor
Write-Host $(if ($WeaselInstalled) { " Windows 部署完成！" } else { " 配置文件已复制，等待安装小狼毫后部署！" }) -ForegroundColor $statusColor
Write-Host "==================================================" -ForegroundColor $statusColor
