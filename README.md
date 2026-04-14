# 毒舌老友 🎭

基于《老友记》六位角色的AI吐槽助手，陪你一起吐槽生活中的不爽！

![毒舌老友](https://img.shields.io/badge/Friends-AI%E5%90%90%E6%A7%BD-blue)
![Flask](https://img.shields.io/badge/Flask-3.0-green)
![Python](https://img.shields.io/badge/Python-3.12-yellow)

## 功能特点

- 🎭 **六位老友角色**：罗斯、瑞秋、莫妮卡、钱德勒、乔伊、菲比
- 💬 **四种毒舌等级**：温和 → 直白 → 毒舌 → 疯狂
- 🎨 **赛博朋克UI**：炫酷的暗色主题界面
- 🚀 **简单易用**：纯HTML前端，无需复杂配置

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/dancepower22/toxic-friends.git
cd toxic-friends
```

### 2. 配置环境

```bash
# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

### 3. 配置API

```bash
# 复制配置文件
cp data/config.json.example data/config.json

# 编辑配置，填入你的API密钥
vim data/config.json
```

配置示例：
```json
{
  "provider": "deepseek",
  "api_key": "your-api-key-here",
  "model": "deepseek-chat",
  "api_url": "https://api.deepseek.com/v1/chat/completions"
}
```

> 支持任何OpenAI格式的API（DeepSeek、OpenAI、兼容Ollama的本地模型等）

### 4. 启动服务

```bash
python app.py
```

访问 http://localhost:5004

## 部署到服务器

### Docker部署

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f
```

### 手动部署到Linux服务器

```bash
# 1. 打包项目
tar -czf toxic-friends.tar.gz --exclude='venv' --exclude='*.log' .

# 2. 上传到服务器
scp toxic-friends.tar.gz root@YOUR_SERVER:/opt/

# 3. 解压并部署
ssh root@YOUR_SERVER "cd /opt && tar -xzf toxic-friends.tar.gz && cd toxic-friends && ./deploy.sh"
```

## 项目结构

```
toxic-friends/
├── app.py              # Flask应用主文件
├── requirements.txt    # Python依赖
├── data/
│   ├── config.json.example  # 配置示例
│   └── friends.json    # 角色数据
├── templates/
│   └── index.html      # 前端页面
├── static/             # 静态资源
├── nginx/              # Nginx配置
└── Dockerfile          # Docker构建文件
```

## 毒舌等级说明

| 等级 | 名称 | 风格 |
|------|------|------|
| 1级 | 温和 | 知心老友，温柔理解 |
| 2级 | 直白 | 直接吐槽，不客气 |
| 3级 | 毒舌 | 火力全开，人身攻击 |
| 4级 | 疯狂 | 往死里骂，脏话输出 |

## 技术栈

- **后端**：Flask + Python 3.12
- **前端**：纯HTML/CSS/JS + SSE
- **AI**：DeepSeek/OpenAI API
- **部署**：Docker + Nginx

## 环境变量

```bash
# 可选的环境变量配置
FLASK_ENV=production
SECRET_KEY=your-secret-key
PORT=5004
```

## 贡献

欢迎提交Issue和PR！

## 许可证

MIT License

---

> **免责声明**：本项目仅供娱乐，AI生成的内容不代表开发者观点，请文明使用。