#!/usr/bin/env bash
# ==============================================================================
# Rime 五笔拼音一键部署脚本 (Linux / macOS)
# 优先级：Ubuntu / Debian > 其他 Linux 发行版 > macOS
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_TYPE="$(uname -s)"
RIME_SRC_DIR="${SCRIPT_DIR}/rime"
FCITX5_SRC_DIR="${SCRIPT_DIR}/fcitx5"

echo "=================================================="
echo " 开始安装与部署 Rime 五笔拼音输入法环境"
echo " 运行平台: ${OS_TYPE}"
echo " 配置文件源目录: ${SCRIPT_DIR}"
echo "=================================================="

# ------------------------------------------------------------------------------
# 1. 平台检测与依赖包安装
# ------------------------------------------------------------------------------
if [ "${OS_TYPE}" = "Linux" ]; then
    TARGET_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fcitx5/rime"
    FCITX5_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5"

    if command -v apt-get >/dev/null 2>&1; then
        echo "[+] 检测到 Debian / Ubuntu 系统，正在更新源并安装依赖包..."
        sudo apt-get update
        sudo apt-get install -y fcitx5 fcitx5-rime rime-data-wubi rime-data-pinyin-simp
    elif command -v pacman >/dev/null 2>&1; then
        echo "[+] 检测到 Arch Linux 系统，正在安装依赖包..."
        sudo pacman -S --needed --noconfirm fcitx5 fcitx5-rime rime-wubi rime-pinyin-simp
    elif command -v dnf >/dev/null 2>&1; then
        echo "[+] 检测到 Fedora 系统，正在安装依赖包..."
        sudo dnf install -y fcitx5 fcitx5-rime rime-wubi rime-pinyin-simp
    else
        echo "[!] 未识别的 Linux 包管理器，请手动确保已安装 fcitx5, fcitx5-rime, 五笔与拼音码表包。"
    fi

elif [ "${OS_TYPE}" = "Darwin" ]; then
    TARGET_DIR="$HOME/Library/Rime"

    if ! command -v brew >/dev/null 2>&1; then
        echo "[!] macOS 环境建议先安装 Homebrew: https://brew.sh/"
    else
        if [ ! -d "/Library/Input Methods/Squirrel.app" ] && [ ! -d "$HOME/Applications/Squirrel.app" ]; then
            echo "[+] 正在通过 Homebrew 安装鼠须管 (Squirrel)..."
            brew install --cask squirrel
        else
            echo "[+] 鼠须管 (Squirrel) 已安装。"
        fi
    fi

    # 检查并安装基础方案依赖（东风破 Plum）
    mkdir -p "${TARGET_DIR}"
    if [ ! -f "${TARGET_DIR}/wubi_pinyin.schema.yaml" ] && [ ! -f "/Library/Input Methods/Squirrel.app/Contents/SharedSupport/wubi_pinyin.schema.yaml" ]; then
        echo "[+] 正在通过东风破 (Plum) 获取五笔与拼音依赖方案..."
        curl -fsSL https://raw.githubusercontent.com/rime/plum/master/rime-install | bash -s -- wubi pinyin-simp
    fi
else
    echo "[!] 暂不支持的操作系统: ${OS_TYPE}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. 复制 Rime 用户目录自定义配置文件
# ------------------------------------------------------------------------------
echo "[+] 正在创建目标 Rime 配置目录: ${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

echo "[+] 正在复制 Rime 核心自定义配置文件..."
cp "${RIME_SRC_DIR}/default.custom.yaml" "${TARGET_DIR}/"
cp "${RIME_SRC_DIR}/wubi_pinyin.custom.yaml" "${TARGET_DIR}/"
cp "${RIME_SRC_DIR}/custom_phrase.txt" "${TARGET_DIR}/"
cp "${RIME_SRC_DIR}/mysymbols.yaml" "${TARGET_DIR}/"
cp "${RIME_SRC_DIR}/fcitx5.custom.yaml" "${TARGET_DIR}/"
cp "${RIME_SRC_DIR}/squirrel.custom.yaml" "${TARGET_DIR}/"
cp "${RIME_SRC_DIR}/weasel.custom.yaml" "${TARGET_DIR}/"

echo "[+] Rime 配置文件已成功写入 ${TARGET_DIR}："
ls -lh "${TARGET_DIR}"/*.custom.yaml "${TARGET_DIR}/custom_phrase.txt" "${TARGET_DIR}/mysymbols.yaml"

# ------------------------------------------------------------------------------
# 3. Linux 专属：复制 Fcitx5 全局环境配置文件
# ------------------------------------------------------------------------------
if [ "${OS_TYPE}" = "Linux" ] && [ -d "${FCITX5_SRC_DIR}" ]; then
    echo "[+] 正在配置 Fcitx5 全局设置目录: ${FCITX5_CONFIG_DIR}"
    mkdir -p "${FCITX5_CONFIG_DIR}"
    if [ -f "${FCITX5_SRC_DIR}/config" ]; then
        cp "${FCITX5_SRC_DIR}/config" "${FCITX5_CONFIG_DIR}/config"
        echo "[+] 已写入 Fcitx5 行为配置: ${FCITX5_CONFIG_DIR}/config"
    fi
    if [ -f "${FCITX5_SRC_DIR}/profile" ]; then
        cp "${FCITX5_SRC_DIR}/profile" "${FCITX5_CONFIG_DIR}/profile"
        echo "[+] 已写入 Fcitx5 输入法列表配置: ${FCITX5_CONFIG_DIR}/profile"
    fi
fi

# ------------------------------------------------------------------------------
# 4. 重新部署与生效
# ------------------------------------------------------------------------------
echo "--------------------------------------------------"
if [ "${OS_TYPE}" = "Linux" ]; then
    # 若存在 rime_deployer 则直接执行静态编译
    if command -v rime_deployer >/dev/null 2>&1; then
        echo "[+] 正在使用 rime_deployer 构建方案缓存..."
        rime_deployer --build "${TARGET_DIR}" /usr/share/rime-data "${TARGET_DIR}/build" >/dev/null 2>&1 || true
    fi

    if pgrep -x fcitx5 >/dev/null 2>&1; then
        echo "[+] 检测到 fcitx5 正在运行，正在重载配置..."
        fcitx5 -r -d >/dev/null 2>&1 || true
        echo "[+] fcitx5 重载命令已发送。"
    else
        echo "[*] fcitx5 当前未运行。在桌面环境中启动 fcitx5 或执行 'fcitx5 -d' 即可生效。"
    fi
elif [ "${OS_TYPE}" = "Darwin" ]; then
    echo "[+] 正在尝试重载鼠须管 (Squirrel)..."
    killall Squirrel 2>/dev/null || true
    if [ -d "/Library/Input Methods/Squirrel.app" ]; then
        open "/Library/Input Methods/Squirrel.app"
    fi
    echo "[+] 鼠须管已重新启动。亦可在右上角输入法菜单中点击'重新部署'。"
fi

echo "=================================================="
echo " 部署完成！"
echo " 1. 方案列表已锁定为: 五笔·拼音 (wubi_pinyin)"
echo " 2. 自定义短语与全量符号表已挂载"
echo " 3. 常用开发/AI/终端工具默认英文模式已配置"
echo " 4. 如未立即生效，可在输入状态下按 Ctrl + ~ 选择'重新部署'"
echo "=================================================="
