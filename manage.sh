#!/bin/bash

# Nginx Web 应用管理脚本
# 用于启动、停止、重启和管理基于 Docker 的 Nginx Web 服务

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# 默认配置
DEFAULT_CONTAINER_NAME="nginx_web_app"
DEFAULT_PORT="8080:80"
DEFAULT_WEB_ROOT="/data/www"
DEFAULT_NGINX_VERSION="latest"
DEFAULT_LOG_MAX_SIZE="10m"
DEFAULT_LOG_MAX_FILE="3"

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_info "加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        print_warning "配置文件不存在，使用默认配置"
        print_warning "请复制 config.env.example 为 config.env 并修改配置"
    fi

    # 设置默认值
    CONTAINER_NAME="${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}"
    PORT="${PORT:-$DEFAULT_PORT}"
    WEB_ROOT="${WEB_ROOT:-$DEFAULT_WEB_ROOT}"
    NGINX_VERSION="${NGINX_VERSION:-$DEFAULT_NGINX_VERSION}"
    LOG_MAX_SIZE="${LOG_MAX_SIZE:-$DEFAULT_LOG_MAX_SIZE}"
    LOG_MAX_FILE="${LOG_MAX_FILE:-$DEFAULT_LOG_MAX_FILE}"

    # 使用自定义镜像或默认 nginx 镜像
    if [ -n "$CUSTOM_IMAGE" ]; then
        NGINX_IMAGE="$CUSTOM_IMAGE"
    else
        NGINX_IMAGE="nginx:${NGINX_VERSION}"
    fi
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行，请启动 Docker"
        exit 1
    fi
}

# 检查容器是否存在
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# 检查容器是否运行
container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# 验证配置
validate_config() {
    local error=0

    if [ -z "$CONTAINER_NAME" ]; then
        print_error "CONTAINER_NAME 未设置"
        error=1
    fi

    if [ -z "$PORT" ]; then
        print_error "PORT 未设置"
        error=1
    fi

    if [ -z "$WEB_ROOT" ]; then
        print_error "WEB_ROOT 未设置"
        error=1
    elif [ ! -d "$WEB_ROOT" ]; then
        print_warning "WEB_ROOT 目录不存在: $WEB_ROOT"
        read -p "是否创建该目录? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$WEB_ROOT"
            print_info "已创建目录: $WEB_ROOT"
        else
            print_error "无法启动：WEB_ROOT 目录不存在"
            error=1
        fi
    fi

    if [ $error -eq 1 ]; then
        exit 1
    fi
}

# 启动容器
start_container() {
    print_info "准备启动 Web 服务..."
    
    load_config
    validate_config

    if container_running; then
        print_warning "容器 '$CONTAINER_NAME' 已经在运行"
        return 0
    fi

    if container_exists; then
        print_info "容器已存在，正在启动..."
        docker start "$CONTAINER_NAME"
        print_info "容器 '$CONTAINER_NAME' 已启动"
    else
        print_info "创建并启动新容器..."
        
        docker run -d \
            --name "$CONTAINER_NAME" \
            --restart always \
            --log-driver json-file \
            --log-opt max-size="$LOG_MAX_SIZE" \
            --log-opt max-file="$LOG_MAX_FILE" \
            -p "$PORT" \
            -v "${SCRIPT_DIR}/dockerfiles/config/nginx/conf.d:/etc/nginx/conf.d" \
            -v "${SCRIPT_DIR}/dockerfiles/config/nginx/nginx.conf:/etc/nginx/nginx.conf" \
            -v "${WEB_ROOT}:/data" \
            "$NGINX_IMAGE"

        if [ $? -eq 0 ]; then
            print_info "容器 '$CONTAINER_NAME' 已成功创建并启动"
            print_info "访问地址: http://localhost:${PORT%%:*}"
        else
            print_error "容器启动失败"
            exit 1
        fi
    fi
}

# 停止容器
stop_container() {
    print_info "停止 Web 服务..."
    
    load_config

    if ! container_exists; then
        print_warning "容器 '$CONTAINER_NAME' 不存在"
        return 0
    fi

    if ! container_running; then
        print_warning "容器 '$CONTAINER_NAME' 未运行"
        return 0
    fi

    docker stop "$CONTAINER_NAME"
    print_info "容器 '$CONTAINER_NAME' 已停止"
}

# 重启容器
restart_container() {
    print_info "重启 Web 服务..."
    
    load_config

    if ! container_exists; then
        print_warning "容器不存在，将创建新容器"
        start_container
        return
    fi

    docker restart "$CONTAINER_NAME"
    print_info "容器 '$CONTAINER_NAME' 已重启"
}

# 删除容器
remove_container() {
    print_info "删除容器..."
    
    load_config

    if ! container_exists; then
        print_warning "容器 '$CONTAINER_NAME' 不存在"
        return 0
    fi

    if container_running; then
        print_info "先停止容器..."
        docker stop "$CONTAINER_NAME"
    fi

    docker rm "$CONTAINER_NAME"
    print_info "容器 '$CONTAINER_NAME' 已删除"
}

# 查看日志
view_logs() {
    load_config

    if ! container_exists; then
        print_error "容器 '$CONTAINER_NAME' 不存在"
        exit 1
    fi

    # 如果有额外参数，传递给 docker logs
    if [ $# -gt 0 ]; then
        docker logs "$@" "$CONTAINER_NAME"
    else
        docker logs -f "$CONTAINER_NAME"
    fi
}

# 查看状态
show_status() {
    load_config

    echo "======================================"
    echo "容器名称: $CONTAINER_NAME"
    echo "======================================"

    if ! container_exists; then
        print_warning "容器不存在"
        return 0
    fi

    if container_running; then
        print_info "容器正在运行"
        echo ""
        docker ps --filter "name=^${CONTAINER_NAME}$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        print_info "访问地址: http://localhost:${PORT%%:*}"
    else
        print_warning "容器已停止"
    fi
}

# 进入容器
exec_container() {
    load_config

    if ! container_running; then
        print_error "容器 '$CONTAINER_NAME' 未运行"
        exit 1
    fi

    print_info "进入容器 '$CONTAINER_NAME'..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

# 重新加载 Nginx 配置
reload_nginx() {
    load_config

    if ! container_running; then
        print_error "容器 '$CONTAINER_NAME' 未运行"
        exit 1
    fi

    print_info "重新加载 Nginx 配置..."
    docker exec "$CONTAINER_NAME" nginx -t
    if [ $? -eq 0 ]; then
        docker exec "$CONTAINER_NAME" nginx -s reload
        print_info "Nginx 配置已重新加载"
    else
        print_error "Nginx 配置检查失败，请修正后再试"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
Nginx Web 应用管理脚本

用法: $0 <command> [options]

命令:
    start       启动 Web 服务
    stop        停止 Web 服务
    restart     重启 Web 服务
    status      查看服务状态
    logs        查看服务日志 (Ctrl+C 退出)
                可选参数: -n <行数> 查看最后N行
                         --tail <行数> 同上
    reload      重新加载 Nginx 配置（不重启容器）
    exec        进入容器命令行
    remove      删除容器（停止服务并删除）
    help        显示此帮助信息

示例:
    $0 start              # 启动服务
    $0 logs               # 查看实时日志
    $0 logs -n 100        # 查看最后100行日志
    $0 reload             # 重新加载配置
    $0 status             # 查看状态

配置文件: $CONFIG_FILE

EOF
}

# 主函数
main() {
    check_docker

    case "${1:-}" in
        start)
            start_container
            ;;
        stop)
            stop_container
            ;;
        restart)
            restart_container
            ;;
        remove|rm)
            remove_container
            ;;
        logs)
            shift
            view_logs "$@"
            ;;
        status)
            show_status
            ;;
        exec|shell)
            exec_container
            ;;
        reload)
            reload_nginx
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            print_error "请指定命令"
            echo ""
            show_help
            exit 1
            ;;
        *)
            print_error "未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
