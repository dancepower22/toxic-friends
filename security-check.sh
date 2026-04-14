#!/bin/bash
# GitHub推送前安全检查脚本
# 使用: ./security-check.sh

echo "🔍 开始GitHub推送前安全检查..."
echo ""

FOUND=0

# 1. 检查敏感信息模式
echo "📋 步骤1: 检查敏感信息..."

# IP地址格式 (排除常见本地IP)
IP_MATCHES=$(grep -rE '\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' . \
    --include="*.py" --include="*.sh" --include="*.json" --include="*.txt" --include="*.md" \
    2>/dev/null | grep -v \"127.0.0.1\\|0.0.0.0\\|localhost\\|192.168\\|10.0\\|YOUR_\" || true)

if [ -n "$IP_MATCHES" ]; then
    echo "⚠️  发现可能的服务器IP地址:"
    echo "$IP_MATCHES" | head -5
    echo ""
    FOUND=1
fi

# API Keys / Tokens
API_MATCHES=$(grep -riE '(api[_-]?key|apikey|secret[_-]?key|token)\s*[=:]\s*["'\'''][a-zA-Z0-9]{16,}["'\''']' . \
    --include="*.py" --include="*.json" --include="*.txt" --include="*.sh" \
    2>/dev/null | grep -vi "example\\|placeholder\\|YOUR_\\|SAMPLE\\|test" || true)

if [ -n "$API_MATCHES" ]; then
    echo "⚠️  发现可能的API Key:"
    echo "$API_MATCHES" | head -5
    echo ""
    FOUND=1
fi

# 密码
PASS_MATCHES=$(grep -riE '(password|passwd|pwd)\s*[=:]\s*["'\'''][^"'\''']{3,}["'\''']' . \
    --include="*.py" --include="*.json" --include="*.txt" --include="*.sh" \
    2>/dev/null | grep -vi "example\\|placeholder\\|YOUR_\\|password=\"\"\\|getenv" || true)

if [ -n "$PASS_MATCHES" ]; then
    echo "⚠️  发现可能的密码:"
    echo "$PASS_MATCHES" | head -5
    echo ""
    FOUND=1
fi

# SSH用户@IP
SSH_MATCHES=$(grep -rE 'root@[0-9]|ubuntu@[0-9]|admin@[0-9]' . \
    --include="*.sh" --include="*.txt" --include="*.md" \
    2>/dev/null | grep -v "example\\|YOUR_" || true)

if [ -n "$SSH_MATCHES" ]; then
    echo "⚠️  发现可能的SSH连接信息:"
    echo "$SSH_MATCHES" | head -5
    echo ""
    FOUND=1
fi

# 中国手机号
PHONE_MATCHES=$(grep -rE '1[3-9][0-9]{9}' . \
    --include="*.py" --include="*.json" --include="*.txt" --include="*.md" \
    2>/dev/null | grep -v "example\\|YOUR_" || true)

if [ -n "$PHONE_MATCHES" ]; then
    echo "⚠️  发现可能的手机号:"
    echo "$PHONE_MATCHES" | head -3
    echo ""
    FOUND=1
fi

# 云服务商关键词
CLOUD_MATCHES=$(grep -riE '阿里云|腾讯云|华为云|aliyun|tencent.*cloud' . \
    --include="*.py" --include="*.sh" --include="*.txt" --include="*.md" \
    2>/dev/null | grep -v "README\\|example" || true)

if [ -n "$CLOUD_MATCHES" ]; then
    echo "⚠️  发现云服务商关键词（可能包含部署信息）:"
    echo "$CLOUD_MATCHES" | head -3
    echo ""
    FOUND=1
fi

# 2. 检查过程性文件
echo "📁 步骤2: 检查过程性/临时文件..."

TEMP_PATTERNS=(
    "*部署*.sh"
    "*部署*.txt"
    "*部署*.md"
    "*一键*.txt"
    "*一键*.sh"
    "*最简单*.txt"
    "*最终*.sh"
    "*最终*.txt"
    "*复制执行*"
    "*直接部署*"
    "*交互式部署*"
    "*手动上传*"
    "*安全自动部署*"
    "*修复*部署*"
    "*智能部署*"
    "*执行部署*"
    "*立即部署*"
    "*密钥*部署*"
    "*我的密钥*"
    "*auto-deploy*"
    "*direct-deploy*"
    "DEPLOYMENT.md"
    "部署密码说明.md"
    "阿里云部署步骤.md"
    "部署指南*.md"
)

for pattern in "${TEMP_PATTERNS[@]}"; do
    files=$(ls $pattern 2>/dev/null || true)
    if [ -n "$files" ]; then
        echo "⚠️  发现过程性文件: $pattern"
        echo "$files" | head -3
        echo ""
        FOUND=1
    fi
done

# 3. 检查配置文件
echo "⚙️  步骤3: 检查配置文件..."

if [ -f "data/config.json" ]; then
    echo "⚠️  发现 data/config.json（可能含真实API Key）"
    echo "   请确保已移除或替换为 config.json.example"
    FOUND=1
fi

if [ -f ".env" ]; then
    echo "⚠️  发现 .env 文件"
    echo "   确保 .env 已加入 .gitignore"
fi

if ls *.pem *.key 2>/dev/null | grep -q .; then
    echo "⚠️  发现密钥文件:"
    ls *.pem *.key 2>/dev/null
    FOUND=1
fi

if ls *.log 2>/dev/null | grep -q .; then
    echo "⚠️  发现日志文件:"
    ls *.log 2>/dev/null
    FOUND=1
fi

# 4. 检查Git状态
echo "📐 步骤4: 检查Git状态..."

UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ $UNCOMMITTED -gt 0 ]; then
    echo "   待提交文件数: $UNCOMMITTED"
    git status --short | head -10
fi

echo ""
echo "=========================================="
if [ $FOUND -eq 1 ]; then
    echo "❌ 安全检查未通过！"
    echo ""
    echo "请执行以下操作:"
    echo "1. 删除或移动过程性文件"
    echo "2. 将真实配置替换为示例配置 (.example)"
    echo "3. 更新 .gitignore 排除敏感文件"
    echo "4. 如已推送，重写Git历史: git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch 敏感文件' --prune-empty -- --all"
    echo ""
    exit 1
else
    echo "✅ 安全检查通过！可以安全推送到GitHub。"
    echo ""
    echo "推送命令:"
    echo "  git add ."
    echo "  git commit -m 'your message'"
    echo "  git push"
    exit 0
fi