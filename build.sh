#!/bin/bash
# ============================================================
# 中国象棋 - 构建脚本
# 功能: 打包 .love 文件、Linux 可执行、Windows 可执行
# 用法: ./build.sh [target]
#   target: love | linux | windows | all (默认 all)
#
# 类比: 项目的 build 脚本 / makefile
# ============================================================

set -e  # 出错就退出

# 项目配置
PROJECT_NAME="ChineseChess"
GAME_TITLE="中国象棋"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")
SRC_DIR="."
BUILD_DIR="build"
LOVE_FILE="${BUILD_DIR}/${PROJECT_NAME}.love"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# 步骤 0: 准备构建目录
# ============================================================
prepare_build_dir() {
    log_info "准备构建目录..."
    mkdir -p "${BUILD_DIR}"
    rm -f "${LOVE_FILE}"
}

# ============================================================
# 步骤 1: 打包 .love 文件（跨平台）
# ============================================================
build_love() {
    log_info "打包 .love 文件 (版本: ${VERSION})..."

    # 需要包含的文件/目录
    # 注意: .love 文件本质是 zip 压缩包，LÖVE 引擎可以直接运行
    cd "${SRC_DIR}"

    zip -r "${LOVE_FILE}" \
        main.lua conf.lua \
        src/ \
        assets/ \
        README.md \
        -x "*.DS_Store" "*.git*" "*.swp" "*~" "build/*" "tests/*" "docs/*" \
        2>/dev/null || true

    log_info ".love 文件已生成: ${LOVE_FILE}"
    log_info "  大小: $(du -h "${LOVE_FILE}" | cut -f1)"
}

# ============================================================
# 步骤 2: Linux 可执行文件
# 说明: .love 文件 + love 可执行文件 合并 = Linux 可执行
# 需要系统安装了 love
# ============================================================
build_linux() {
    if ! command -v love &> /dev/null; then
        log_warn "未找到 love 命令，跳过 Linux 构建"
        return 1
    fi

    log_info "构建 Linux 可执行文件..."

    LOVE_BIN=$(which love)
    OUTPUT="${BUILD_DIR}/${PROJECT_NAME}-linux-${VERSION}"

    # 合并: love 二进制 + .love 文件
    cat "${LOVE_BIN}" "${LOVE_FILE}" > "${OUTPUT}"
    chmod +x "${OUTPUT}"

    log_info "Linux 可执行文件已生成: ${OUTPUT}"
    log_info "  大小: $(du -h "${OUTPUT}" | cut -f1)"
}

# ============================================================
# 步骤 3: Windows 可执行文件
# 说明: 需要下载 LÖVE for Windows 的 zip 包
# 由于我们在 Linux 环境下，这里只提供说明和模板
# 实际构建需要 Windows 或 wine
# ============================================================
build_windows() {
    log_warn "Windows 构建需要 LÖVE Windows 版本"
    log_warn "请参考 docs/08_deployment.md 手动构建"

    # 如果你安装了 wine 和 love 的 Windows 版本，可以取消注释下面的代码
    # WINE_LOVE="~/.wine/drive_c/Program Files/LOVE/love.exe"
    # ...

    return 0
}

# ============================================================
# 步骤 4: macOS 可执行
# 说明: macOS 需要在 macOS 环境下构建
# ============================================================
build_macos() {
    log_warn "macOS 构建需要在 macOS 环境下进行"
    log_warn "请参考 docs/08_deployment.md"
    return 0
}

# ============================================================
# 主流程
# ============================================================

TARGET="${1:-all}"

log_info "=========================================="
log_info "  ${GAME_TITLE} 构建脚本"
log_info "  版本: ${VERSION}"
log_info "  目标: ${TARGET}"
log_info "=========================================="
echo ""

prepare_build_dir

case "${TARGET}" in
    love)
        build_love
        ;;
    linux)
        build_love
        build_linux || true
        ;;
    windows)
        build_love
        build_windows || true
        ;;
    all)
        build_love
        build_linux || true
        build_windows || true
        build_macos || true
        ;;
    *)
        log_error "未知目标: ${TARGET}"
        echo "用法: $0 [love|linux|windows|all]"
        exit 1
        ;;
esac

echo ""
log_info "构建完成！"
log_info "输出目录: ${BUILD_DIR}/"
ls -lh "${BUILD_DIR}/" 2>/dev/null || true
