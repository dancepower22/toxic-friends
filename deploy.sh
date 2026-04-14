#!/bin/bash

# 毒舌老友部署脚本
# 使用方法: ./deploy.sh [server_ip] [ssh_user] [ssh_port]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 参数
SERVER_IP="${1}"
SSH_USER="${2:-root}"
SSH_PORT="${3:-22}"
PROJECT_NAME="toxic-friends"
LOCAL_DIR="$(pwd)"
REMOTE_DIR="/opt/${PROJECT_NAME}"

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

# 检查参数
check_params() {
    if [ -z "$SERVER_IP" ]; then
        print_error "请提供服务器IP地址"
        echo "使用方法: $0 [server_ip] [ssh_user] [ssh_port]"
        echo "示例: $0 123.123.123.123 root 22"
        exit 1
    fi
}

# 检查SSH连接
check_ssh() {
    print_info "检查SSH连接到 ${SSH_USER}@${SERVER_IP}:${SSH_PORT}..."
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "echo 'SSH连接成功'" || {
        print_error "SSH连接失败"
        exit 1
    }
    print_success "SSH连接成功"
}

# 检查服务器环境
check_server_env() {
    print_info "检查服务器环境..."
    
    # 检查Docker
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "command -v docker" >/dev/null 2>&1 || {
        print_warning "Docker未安装，开始安装Docker..."
        install_docker
    }
    
    # 检查Docker Compose
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "command -v docker-compose" >/dev/null 2>&1 || {
        print_warning "Docker Compose未安装，开始安装Docker Compose..."
        install_docker_compose
    }
    
    print_success "服务器环境检查完成"
}

# 安装Docker
install_docker() {
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} << 'EOF'
        # 卸载旧版本
        sudo apt-get remove -y docker docker-engine docker.io containerd runc
        
        # 安装依赖
        sudo apt-get update
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # 添加Docker官方GPG密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # 设置稳定版仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 安装Docker引擎
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # 启动Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # 添加当前用户到docker组
        sudo usermod -aG docker $USER
EOF
    
    print_success "Docker安装完成"
}

# 安装Docker Compose
install_docker_compose() {
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} << 'EOF'
        # 下载Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        
        # 添加执行权限
        sudo chmod +x /usr/local/bin/docker-compose
        
        # 创建符号链接
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
EOF
    
    print_success "Docker Compose安装完成"
}

# 准备部署文件
prepare_deployment() {
    print_info "准备部署文件..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    
    # 复制项目文件
    cp -r ${LOCAL_DIR}/* ${TEMP_DIR}/
    
    # 移除不需要的文件
    rm -rf ${TEMP_DIR}/venv ${TEMP_DIR}/__pycache__ ${TEMP_DIR}/*.log 2>/dev/null || true
    
    # 创建部署包
    DEPLOY_PACKAGE="${PROJECT_NAME}-deploy.tar.gz"
    tar -czf ${DEPLOY_PACKAGE} -C ${TEMP_DIR} .
    
    # 清理临时目录
    rm -rf ${TEMP_DIR}
    
    print_success "部署文件准备完成: ${DEPLOY_PACKAGE}"
}

# 上传文件到服务器
upload_to_server() {
    print_info "上传文件到服务器..."
    
    # 创建远程目录
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "sudo mkdir -p ${REMOTE_DIR} && sudo chown -R ${SSH_USER}:${SSH_USER} ${REMOTE_DIR}"
    
    # 上传部署包
    scp -P ${SSH_PORT} ${DEPLOY_PACKAGE} ${SSH_USER}@${SERVER_IP}:${REMOTE_DIR}/
    
    # 解压部署包
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "cd ${REMOTE_DIR} && tar -xzf ${DEPLOY_PACKAGE} && rm ${DEPLOY_PACKAGE}"
    
    # 设置权限
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "chmod +x ${REMOTE_DIR}/deploy.sh"
    
    # 清理本地部署包
    rm ${DEPLOY_PACKAGE}
    
    print_success "文件上传完成"
}

# 在服务器上部署
deploy_on_server() {
    print_info "在服务器上部署应用..."
    
    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} << EOF
        cd ${REMOTE_DIR}
        
        # 停止现有容器
        echo "停止现有容器..."
        docker-compose down 2>/dev/null || true
        
        # 构建镜像
        echo "构建Docker镜像..."
        docker-compose build
        
        # 启动服务
        echo "启动服务..."
        docker-compose up -d
        
        # 等待服务启动
        echo "等待服务启动..."
        sleep 10
        
        # 检查服务状态
        echo "检查服务状态..."
        docker-compose ps
        
        # 检查健康状态
        echo "检查健康状态..."
        curl -f http://localhost:5004/health || echo "健康检查失败"
EOF
    
    print_success "部署完成"
}

# 显示部署信息
show_deployment_info() {
    print_info "部署完成！"
    echo ""
    echo "================================"
    echo "毒舌老友部署信息"
    echo "================================"
    echo "服务器: ${SERVER_IP}"
    echo "项目目录: ${REMOTE_DIR}"
    echo ""
    echo "访问地址:"
    echo "- 应用: http://${SERVER_IP}:5004"
    echo "- Nginx: http://${SERVER_IP}:80"
    echo ""
    echo "管理命令:"
    echo "1. 查看日志: ssh ${SSH_USER}@${SERVER_IP} 'cd ${REMOTE_DIR} && docker-compose logs -f'"
    echo "2. 重启服务: ssh ${SSH_USER}@${SERVER_IP} 'cd ${REMOTE_DIR} && docker-compose restart'"
    echo "3. 停止服务: ssh ${SSH_USER}@${SERVER_IP} 'cd ${REMOTE_DIR} && docker-compose down'"
    echo "4. 更新代码: 重新运行此部署脚本"
    echo "================================"
}

# 主函数
main() {
    print_info "开始部署毒舌老友到阿里云服务器..."
    
    check_params
    check_ssh
    check_server_env
    prepare_deployment
    upload_to_server
    deploy_on_server
    show_deployment_info
    
    print_success "部署流程完成！"
}

# 执行主函数
main "$@"