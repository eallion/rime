# Rime 五笔拼音跨平台自动化安装与部署套件

本目录（`rime/`）为独立的跨平台自动化安装与部署套件，支持在新电脑上一键配置 **Ubuntu 26.04 / Debian / macOS / Windows**。

## 目录结构说明

```text
rime/
├── install.sh              # Linux (Ubuntu/Debian/Arch/Fedora) 与 macOS 通用一键部署脚本
├── install.ps1             # Windows PowerShell 一键部署脚本
├── README.md               # 本套件使用说明文档
├── rime/                   # Rime 用户目录跨平台核心配置 (~/.local/share/fcitx5/rime / %APPDATA%\Rime / ~/Library/Rime)
│   ├── default.custom.yaml     # 全局方案选单补丁（锁定五笔拼音）
│   ├── wubi_pinyin.custom.yaml # 输入方案调优补丁（选词、反查、反引号、单键精准标点映射）
│   ├── custom_phrase.txt       # 个人专属短语词库（账号、邮箱、网址、税号及自建高频词）
│   ├── mysymbols.yaml          # 全量特殊符号与电脑键位表（支持 60+ 组 / 快捷输入）
│   ├── fcitx5.custom.yaml      # Linux 前端专属配置（Ghostty / VS Code / Claude / ChatGPT 等默认英文）
│   ├── squirrel.custom.yaml    # macOS 前端专属配置（按 Bundle ID 设定默认英文）
│   └── weasel.custom.yaml      # Windows 前端专属配置（小狼毫候选框排版与各进程默认英文）
└── fcitx5/                 # Linux Fcitx5 全局环境配置 (~/.config/fcitx5/)
    ├── config                  # Fcitx5 行为配置（程序级状态共享、防焦点强制重置）
    └── profile                 # Fcitx5 输入法列表（默认单 Rime 纯键盘模式）
```

---

## 新电脑一键安装方法

### 1. Ubuntu / Debian（主力推荐）

在新电脑上克隆或下载此套件，进入 `rime/` 目录后运行：

```bash
bash install.sh
```

脚本将自动执行：

1. 调用 `apt` 安装 `fcitx5`、`fcitx5-rime`、`rime-data-wubi`（五笔方案）及 `rime-data-pinyin-simp`（拼音依赖）。
2. 将 `rime/` 目录中的全部自定义配置文件写入 Rime 用户目录 `~/.local/share/fcitx5/rime/`。
3. 将 `fcitx5/` 目录中的配置文件写入 Fcitx5 系统全局配置目录 `~/.config/fcitx5/`（自动应用状态记忆与单输入法设置）。
4. 触发静态预编译与 fcitx5 热重载。

### 2. macOS

在终端中进入 `rime/` 目录运行：

```bash
bash install.sh
```

脚本将自动执行：

1. 检查并通过 Homebrew 安装鼠须管（`brew install --cask squirrel`）。
2. 通过东风破（Plum）拉取 `wubi` 与 `pinyin-simp` 官方方案。
3. 将 `rime/` 目录的配置文件复制至 `~/Library/Rime/` 并重启鼠须管生效。

### 3. Windows

在 PowerShell 中运行（推荐在项目根目录下）：

```powershell
.\install.ps1
# 或指定绕过执行策略：
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本将自动执行：

1. **小狼毫安装检测**：检测已安装的小狼毫，未安装时自动通过 `winget install Rime.Weasel` 安装（若弹出系统 UAC 权限请求请点击“是”允许）。
2. **方案依赖全自动拉取**：自动从官方仓库下载并提取 `rime-wubi` 与 `rime-pinyin-simp` 方案及词库依赖，无需手动在界面中“获取更多输入方案”。
3. **配置文件同步**：将 `rime/` 目录的全部核心自定义配置文件写入 `%APPDATA%\Rime`。
4. **全自动静默部署**：调用 `WeaselDeployer.exe /deploy` 执行静默编译与更新工作区（纯后台执行，无多余弹窗），自动生成棱镜二进制索引并生效。
