#!/bin/bash
# ============================================================
# romwe_game 构建脚本
# 功能: 打包 .love 文件、Linux 可执行文件
# 用法: ./build.sh [target]
#   target: love | linux | all (默认 all)
#
# 注意: 优先使用 ./run.sh 来运行游戏（绿色安装）
# ============================================================

set -e

# 项目配置
PROJECT_NAME="romwe_game"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
BUILD_DIR="$SCRIPT_DIR/dist"
RUNTIME_DIR="$SCRIPT_DIR/.runtime"
LOVE_APPIMAGE="$RUNTIME_DIR/love2d.AppImage"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}==>${NC} $1"; }

# ============================================================
# 步骤 0: 准备
# ============================================================
prepare() {
    mkdir -p "$BUILD_DIR"
}

# ============================================================
# 步骤 1: 打包 .love 文件
# ============================================================
build_love() {
    log_step "打包 .love 文件 (版本: ${VERSION})..."

    local love_file="$BUILD_DIR/${PROJECT_NAME}.love"
    rm -f "$love_file"

    # 打包核心文件（排除开发文档、测试、脚本等）
    cd "$SCRIPT_DIR"

    # 使用 zip 创建 .love 文件（.love 就是 zip）
    if command -v zip &> /dev/null; then
        zip -r -q "$love_file" \
            conf.lua main.lua \
            src/ assets/ \
            -x "*.DS_Store" "*.git*" "*.swp" "*~" "tests/*" "docs/*" ".runtime/*" "dist/*" \
            2>/dev/null
    else
        # 没有 zip 命令，用 tar 替代？不行，love 需要 zip
        # 用 python 创建 zip
        python3 -c "
import zipfile, os
with zipfile.ZipFile('$love_file', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in ['.git', '.runtime', 'dist', 'tests', 'docs']]
        for f in files:
            if f.endswith(('.swp', '~', '.pyc')) or f.startswith('.'):
                continue
            fp = os.path.join(root, f)
            arc = os.path.relpath(fp, '.')
            if arc.startswith('src/') or arc.startswith('assets/') or arc in ['conf.lua', 'main.lua']:
                zf.write(fp, arc)
"
    fi

    log_info ".love 文件已生成: $love_file"
    log_info "  大小: $(du -h "$love_file" | cut -f1)"
}

# ============================================================
# 步骤 2: Linux 可执行文件（融合 AppImage）
# ============================================================
build_linux() {
    log_step "构建 Linux 独立可执行文件..."

    local love_file="$BUILD_DIR/${PROJECT_NAME}.love"
    if [ ! -f "$love_file" ]; then
        build_love
    fi

    # 确保 love AppImage 存在
    if [ ! -x "$LOVE_APPIMAGE" ]; then
        log_info "下载 LÖVE2D runtime ..."
        bash "$SCRIPT_DIR/run.sh" install
    fi

    if [ -x "$LOVE_APPIMAGE" ]; then
        local output="$BUILD_DIR/${PROJECT_NAME}-linux-${VERSION}"
        cat "$LOVE_APPIMAGE" "$love_file" > "$output"
        chmod +x "$output"
        log_info "Linux 可执行文件: $output"
        log_info "  大小: $(du -h "$output" | cut -f1)"
    elif command -v love &> /dev/null; then
        local output="$BUILD_DIR/${PROJECT_NAME}-linux-${VERSION}"
        cat "$(which love)" "$love_file" > "$output"
        chmod +x "$output"
        log_info "Linux 可执行文件: $output (使用系统 love)"
        log_info "  大小: $(du -h "$output" | cut -f1)"
    else
        log_warn "无法构建独立可执行文件，请先运行 ./run.sh install 下载 runtime"
    fi
}

# ============================================================
# 主流程
# ============================================================
TARGET="${1:-all}"

echo ""
log_info "=========================================="
log_info "  romwe_game 构建脚本"
log_info "  版本: ${VERSION}"
log_info "  目标: ${TARGET}"
log_info "=========================================="
echo ""

prepare

case "${TARGET}" in
    love)
        build_love
        ;;
    linux)
        build_linux
        ;;
    all)
        build_love
        build_linux
        ;;
    *)
        log_error "未知目标: ${TARGET}"
        echo "用法: $0 [love|linux|all]"
        exit 1
        ;;
esac

echo ""
log_info "构建完成！"
log_info "输出目录: ${BUILD_DIR}/"
ls -lh "$BUILD_DIR/" 2>/dev/null || true
