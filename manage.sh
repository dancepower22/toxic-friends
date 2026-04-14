#!/bin/bash

# 毒舌老友管理脚本
# 使用方法: ./manage.sh [command]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 函数：打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助
show_help() {
    echo "毒舌老友管理脚本"
    echo ""
    echo "使用方法: $0 [command]"
    echo ""
    echo "命令列表:"
    echo "  start         启动服务"
    echo "  stop          停止服务"
    echo "  restart       重启服务"
    echo "  status        查看服务状态"
    echo "  logs          查看日志"
    echo "  update        更新代码并重启"
    echo "  backup        备份数据"
    echo "  restore       恢复数据"
    echo "  shell         进入容器shell"
    echo "  build         重新构建镜像"
    echo "  clean         清理无用镜像和容器"
    echo "  help          显示此帮助信息"
    echo ""
}

# 检查Docker Compose
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose未安装"
        exit 1
    fi
}

# 启动服务
start_service() {
    print_info "启动毒舌老友服务..."
    docker-compose up -d
    print_success "服务启动完成"
    status_service
}

# 停止服务
stop_service() {
    print_info "停止毒舌老友服务..."
    docker-compose down
    print_success "服务停止完成"
}

# 重启服务
restart_service() {
    print_info "重启毒舌老友服务..."
    docker-compose restart
    print_success "服务重启完成"
    status_service
}

# 查看状态
status_service() {
    print_info "服务状态:"
    echo ""
    docker-compose ps
    echo ""
    
    # 检查健康状态
    print_info "健康检查:"
    if curl -s -f http://localhost:5004/health > /dev/null 2>&1; then
        print_success "应用运行正常"
        curl -s http://localhost:5004/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:5004/health
    else
        print_error "应用可能未运行"
    fi
}

# 查看日志
logs_service() {
    print_info "查看服务日志..."
    docker-compose logs -f --tail=100
}

# 更新代码
update_service() {
    print_info "更新服务..."
    
    # 拉取最新代码（如果有git）
    if [ -d ".git" ]; then
        print_info "拉取最新代码..."
        git pull
    fi
    
    # 重新构建镜像
    build_service
    
    # 重启服务
    restart_service
    
    print_success "更新完成"
}

# 备份数据
backup_data() {
    print_info "备份数据..."
    
    BACKUP_DIR="backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/toxic-friends-backup-${TIMESTAMP}.tar.gz"
    
    mkdir -p ${BACKUP_DIR}
    
    # 备份数据目录
    tar -czf ${BACKUP_FILE} data/ logs/ 2>/dev/null || true
    
    print_success "数据备份完成: ${BACKUP_FILE}"
    ls -lh ${BACKUP_FILE}
}

# 恢复数据
restore_data() {
    if [ -z "$1" ]; then
        print_error "请指定备份文件"
        echo "使用方法: $0 restore [backup_file.tar.gz]"
        exit 1
    fi
    
    BACKUP_FILE="$1"
    
    if [ ! -f "${BACKUP_FILE}" ]; then
        print_error "备份文件不存在: ${BACKUP_FILE}"
        exit 1
    fi
    
    print_warning "即将恢复数据，现有数据将被覆盖！"
    read -p "确认恢复? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "取消恢复"
        exit 0
    fi
    
    print_info "停止服务..."
    docker-compose down
    
    print_info "恢复数据..."
    tar -xzf ${BACKUP_FILE}
    
    print_info "启动服务..."
    docker-compose up -d
    
    print_success "数据恢复完成"
}

# 进入容器shell
enter_shell() {
    print_info "进入容器shell..."
    docker-compose exec toxic-friends /bin/bash || docker-compose exec toxic-friends /bin/sh
}

# 构建镜像
build_service() {
    print_info "构建Docker镜像..."
    docker-compose build --no-cache
    print_success "镜像构建完成"
}

# 清理
clean_service() {
    print_info "清理无用资源..."
    
    # 停止并删除容器
    docker-compose down
    
    # 删除无用镜像
    docker image prune -f
    
    # 删除无用容器
    docker container prune -f
    
    # 删除无用卷
    docker volume prune -f
    
    print_success "清理完成"
}

# 主函数
main() {
    cd ${PROJECT_DIR}
    check_docker_compose
    
    COMMAND="${1:-help}"
    
    case ${COMMAND} in
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            status_service
            ;;
        logs)
            logs_service
            ;;
        update)
            update_service
            ;;
        backup)
            backup_data
            ;;
        restore)
            restore_data "$2"
            ;;
        shell)
            enter_shell
            ;;
        build)
            build_service
            ;;
        clean)
            clean_service
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: ${COMMAND}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"