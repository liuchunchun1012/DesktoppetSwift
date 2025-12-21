#!/bin/bash

# ========================================
# DesktoppetSwift 一键安装脚本
# 傻瓜式安装，自动处理依赖
# ========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 表情符号
CHECK="✅"
CROSS="❌"
ARROW="➡️"
CAT="🐱"
SPARKLE="✨"

# 打印带颜色的消息
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $CAT DesktoppetSwift 安装程序 $CAT${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}${ARROW} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

# 检测 Command Line Tools
check_xcode_cli() {
    print_step "检测 Command Line Tools..."
    if xcode-select -p &>/dev/null; then
        print_success "Command Line Tools 已安装"
        return 0
    else
        return 1
    fi
}

# 安装 Command Line Tools
install_xcode_cli() {
    print_warning "Command Line Tools 未安装"
    echo ""
    echo "即将弹出安装窗口，请按照提示完成安装。"
    echo "安装完成后，请重新运行此脚本。"
    echo ""
    read -p "按 Enter 键开始安装..." 
    
    xcode-select --install
    
    echo ""
    print_warning "安装窗口已弹出，请完成安装后重新运行此脚本。"
    exit 0
}

# 检测 Homebrew
check_homebrew() {
    if command -v brew &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 安装 Homebrew (可选)
install_homebrew() {
    echo ""
    echo -e "${YELLOW}Homebrew 是 macOS 的包管理器，可以方便地安装 Ollama。${NC}"
    read -p "是否安装 Homebrew? (y/n): " install_brew
    
    if [[ "$install_brew" =~ ^[Yy]$ ]]; then
        print_step "正在安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 添加到 PATH (Apple Silicon)
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        print_success "Homebrew 安装完成"
    else
        print_warning "跳过 Homebrew 安装"
    fi
}

# 检测 Ollama
check_ollama() {
    if command -v ollama &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 安装 Ollama (可选)
install_ollama() {
    echo ""
    echo -e "${YELLOW}Ollama 是本地运行 AI 模型的工具。${NC}"
    echo "如果你只想使用云端 API (OpenAI/Claude/Gemini)，可以跳过此步骤。"
    echo ""
    read -p "是否安装 Ollama? (y/n): " install_ollama_choice
    
    if [[ "$install_ollama_choice" =~ ^[Yy]$ ]]; then
        if check_homebrew; then
            print_step "使用 Homebrew 安装 Ollama..."
            brew install ollama
        else
            print_step "下载 Ollama 安装包..."
            echo "请访问 https://ollama.ai 下载并安装 Ollama"
            echo "安装完成后，重新运行此脚本来下载模型。"
            open "https://ollama.ai"
            return 1
        fi
        print_success "Ollama 安装完成"
        return 0
    else
        print_warning "跳过 Ollama 安装"
        return 1
    fi
}

# 选择并安装 Ollama 模型
install_ollama_models() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  选择要安装的 AI 模型${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "推荐模型列表："
    echo ""
    echo "  1) gemma3:4b-it-qat   (~3GB) - 轻量通用，适合大多数电脑"
    echo "  2) gemma3:12b-it-qat  (~8GB) - 均衡性能，推荐 16GB+ 内存"
    echo "  3) qwen3:4b           (~3GB) - 中文优化"
    echo "  4) llava:7b           (~5GB) - 支持图片分析"
    echo "  5) 跳过，稍后手动安装"
    echo ""
    read -p "请选择 (1-5): " model_choice
    
    case $model_choice in
        1)
            print_step "正在下载 gemma3:4b-it-qat..."
            ollama pull gemma3:4b-it-qat
            print_success "gemma3:4b-it-qat 安装完成"
            ;;
        2)
            print_step "正在下载 gemma3:12b-it-qat..."
            ollama pull gemma3:12b-it-qat
            print_success "gemma3:12b-it-qat 安装完成"
            ;;
        3)
            print_step "正在下载 qwen3:4b..."
            ollama pull qwen3:4b
            print_success "qwen3:4b 安装完成"
            ;;
        4)
            print_step "正在下载 llava:7b..."
            ollama pull llava:7b
            print_success "llava:7b 安装完成"
            ;;
        5)
            print_warning "跳过模型安装"
            echo "稍后可以使用 'ollama pull <模型名>' 手动安装"
            ;;
        *)
            print_warning "无效选择，跳过模型安装"
            ;;
    esac
}

# 构建应用
build_app() {
    print_step "正在构建 DesktoppetSwift..."
    
    if [[ ! -f "package.sh" ]]; then
        print_error "找不到 package.sh，请确保在项目目录中运行此脚本"
        exit 1
    fi
    
    chmod +x package.sh
    ./package.sh
    
    print_success "构建完成"
}

# 打开应用
open_app() {
    if [[ -d "DesktoppetSwift.app" ]]; then
        print_step "正在启动 DesktoppetSwift..."
        open DesktoppetSwift.app
        print_success "应用已启动"
    else
        print_error "找不到 DesktoppetSwift.app"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  $SPARKLE 安装完成！$SPARKLE${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "使用提示："
    echo "  • Cmd+Shift+J - 打开聊天"
    echo "  • Cmd+Shift+T - 翻译剪贴板文字"
    echo "  • Cmd+Shift+L - 分析剪贴板截图"
    echo ""
    echo "如需更改 AI 提供商，请点击菜单栏图标 → 设置"
    echo ""
    echo -e "${CYAN}享受你的桌面宠物吧！$CAT${NC}"
}

# 主函数
main() {
    print_header
    
    # 1. 检测并安装 Command Line Tools
    if ! check_xcode_cli; then
        install_xcode_cli
    fi
    
    # 2. 检测 Homebrew
    print_step "检测 Homebrew..."
    if check_homebrew; then
        print_success "Homebrew 已安装"
    else
        install_homebrew
    fi
    
    # 3. 检测并安装 Ollama (可选)
    print_step "检测 Ollama..."
    ollama_installed=false
    if check_ollama; then
        print_success "Ollama 已安装"
        ollama_installed=true
    else
        if install_ollama; then
            ollama_installed=true
        fi
    fi
    
    # 4. 安装 Ollama 模型 (如果安装了 Ollama)
    if $ollama_installed; then
        # 启动 Ollama 服务
        print_step "启动 Ollama 服务..."
        ollama serve &>/dev/null &
        sleep 2
        
        install_ollama_models
    fi
    
    # 5. 构建应用
    echo ""
    build_app
    
    # 6. 打开应用
    open_app
    
    # 7. 显示完成信息
    show_completion
}

# 运行主函数
main "$@"
