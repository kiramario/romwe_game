#!/bin/bash
# romwe_game 启动脚本
# 功能：绿色运行，自动检测/下载 love2D，不影响系统环境
# 用法：./run.sh [options]
#   无参数     - 直接运行游戏
#   --build    - 打包为 .love 文件
#   --package  - 打包为 Linux 可执行文件（包含 runtime）
#   --clean    - 清理下载的 runtime 文件

set -e

# 项目根目录（脚本所在目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 配置
RUNTIME_DIR="$SCRIPT_DIR/.runtime"
LOVE_VERSION="11.5"
LOVE_APPIMAGE_URL="https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-x86_64.AppImage"
LOVE_APPIMAGE="$RUNTIME_DIR/love2d.AppImage"
GAME_NAME="romwe_game"
DIST_DIR="$SCRIPT_DIR/dist"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

# ============================================================
# 检查并下载 Love2D runtime（绿色安装到 .runtime 目录）
# ============================================================
ensure_love2d() {
    # 如果系统已经有 love 命令，优先使用（但仍建议用绿色版以保证版本一致）
    if command -v love &> /dev/null; then
        local sys_ver
        sys_ver=$(love --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "unknown")
        log_info "检测到系统已安装 LÖVE2D (版本: $sys_ver)"
        if [ "$sys_ver" = "$LOVE_VERSION" ] || [[ "$sys_ver" == 11.* ]]; then
            LOVE_CMD="love"
            return 0
        fi
        log_warn "系统 LÖVE2D 版本 ($sys_ver) 与推荐版本 ($LOVE_VERSION) 不一致，将使用绿色版"
    fi

    # 绿色版已存在
    if [ -x "$LOVE_APPIMAGE" ]; then
        LOVE_CMD="$LOVE_APPIMAGE"
        return 0
    fi

    # 需要下载
    log_step "未找到 LÖVE2D，正在绿色安装到 $RUNTIME_DIR ..."
    mkdir -p "$RUNTIME_DIR"

    # 检查下载工具
    local downloader=""
    if command -v wget &> /dev/null; then
        downloader="wget -q --show-progress -O"
    elif command -v curl &> /dev/null; then
        downloader="curl -L -o"
    else
        log_error "未找到 wget 或 curl，请先安装其中一个"
        exit 1
    fi

    log_info "下载 LÖVE2D $LOVE_VERSION ..."
    log_info "URL: $LOVE_APPIMAGE_URL"

    # 下载
    if ! $downloader "$LOVE_APPIMAGE" "$LOVE_APPIMAGE_URL"; then
        log_error "下载失败，请检查网络连接"
        log_info "你也可以手动下载 AppImage 放到: $LOVE_APPIMAGE"
        rm -f "$LOVE_APPIMAGE"
        exit 1
    fi

    chmod +x "$LOVE_APPIMAGE"
    LOVE_CMD="$LOVE_APPIMAGE"
    log_info "LÖVE2D 绿色安装完成！"
}

# ============================================================
# 运行游戏
# ============================================================
run_game() {
    ensure_love2d
    log_step "启动 $GAME_NAME ..."
    log_info "Runtime: $LOVE_CMD"
    exec "$LOVE_CMD" "$SCRIPT_DIR"
}

# ============================================================
# 打包为 .love 文件（ZIP 格式，LÖVE2D 标准）
# ============================================================
build_love() {
    log_step "打包为 .love 文件 ..."
    mkdir -p "$DIST_DIR"

    local love_file="$DIST_DIR/${GAME_NAME}.love"

    # .love 文件本质是 ZIP 压缩包
    # 需要在项目根目录执行，保留 src/ assets/ conf.lua main.lua 结构
    if command -v zip &> /dev/null; then
        (cd "$SCRIPT_DIR" && zip -r -q "$love_file" \
            conf.lua main.lua src/ assets/ \
            -x "*.md" "tests/*" "docs/*" "build.sh" "run.sh" \
               ".runtime/*" "dist/*" "build/*" ".git/*")
    else
        # fallback: 使用 python 创建 zip
        log_warn "未找到 zip 命令，使用 Python 创建 zip..."
        python3 -c "
import zipfile, os
zf = zipfile.ZipFile('$love_file', 'w', zipfile.ZIP_DEFLATED)
os.chdir('$SCRIPT_DIR')
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in ('.git','.runtime','dist','build','tests','docs')]
    for f in files:
        if f in ('build.sh','run.sh') or f.endswith('.md'):
            continue
        fp = os.path.join(root, f)
        arc = os.path.relpath(fp, '.')
        zf.write(fp, arc)
zf.close()
        "
    fi

    local size
    size=$(du -h "$love_file" | cut -f1)
    log_info "打包完成: $love_file ($size)"
}

# ============================================================
# 打包为 Linux 可执行文件（融合 AppImage + .love）
# ============================================================
package_linux() {
    ensure_love2d
    build_love

    log_step "打包为 Linux 独立可执行文件 ..."

    local love_file="$DIST_DIR/${GAME_NAME}.love"
    local exe_file="$DIST_DIR/${GAME_NAME}"

    # 只有 AppImage 才能融合（系统安装的 love 可能不是 AppImage）
    if [[ "$LOVE_CMD" == *AppImage ]]; then
        cat "$LOVE_CMD" "$love_file" > "$exe_file"
        chmod +x "$exe_file"
        local size
        size=$(du -h "$exe_file" | cut -f1)
        log_info "独立可执行文件: $exe_file ($size)"
    else
        log_warn "当前使用系统安装的 LÖVE2D，无法融合"
        log_info ".love 文件已生成在: $love_file"
        log_info "如需独立可执行文件，请删除 $LOVE_APPIMAGE 后重新运行"
    fi
}

# ============================================================
# 清理
# ============================================================
clean() {
    log_step "清理运行时文件 ..."
    rm -rf "$RUNTIME_DIR"
    rm -rf "$DIST_DIR"
    log_info "清理完成"
}

# ============================================================
# 主入口
# ============================================================
case "${1:-run}" in
    run|--run|-r|"")
        run_game
        ;;
    build|--build|-b)
        build_love
        ;;
    package|--package|-p)
        package_linux
        ;;
    clean|--clean|-c)
        clean
        ;;
    install|--install|-i)
        ensure_love2d
        log_info "LÖVE2D 已就绪，运行 ./run.sh 启动游戏"
        ;;
    help|--help|-h)
        echo "用法: $0 [命令]"
        echo ""
        echo "命令:"
        echo "  (无)   run       运行游戏（默认）"
        echo "  -b     build     打包为 .love 文件"
        echo "  -p     package   打包为 Linux 独立可执行文件"
        echo "  -c     clean     清理下载的 runtime 和构建产物"
        echo "  -i     install   仅安装/检查 runtime"
        echo "  -h     help      显示帮助"
        echo ""
        echo "说明: 首次运行会自动下载 LÖVE2D 到 .runtime 目录"
        echo "      不会修改系统环境，完全绿色便携"
        ;;
    *)
        log_error "未知命令: $1"
        echo "用法: $0 [run|build|package|clean|help]"
        exit 1
        ;;
esac
