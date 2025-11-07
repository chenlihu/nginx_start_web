# Nginx Web 快速部署工具

一个基于 Docker 和 Nginx 的 Web 应用快速部署工具，帮助你在几分钟内部署静态网站或前端应用。

## 功能特性

- 🚀 **快速部署**：一键启动 Web 服务
- 🐳 **Docker 容器化**：隔离环境，易于管理
- 🔄 **反向代理支持**：内置 API 代理配置
- 📝 **日志管理**：自动轮转，防止日志文件过大
- 🔧 **灵活配置**：支持自定义 Nginx 配置
- 📦 **开箱即用**：预配置常用优化项

## 前置要求

- Docker 已安装并运行
- 基本的 Linux/Unix 命令行知识

## 快速开始

### 1. 克隆项目

```bash
git clone <repository-url>
cd nginx_start_web
```

### 2. 配置项目

编辑 `config.env` 文件，设置你的项目参数：

```bash
# 容器名称
CONTAINER_NAME=my_web_app

# 映射端口（宿主机:容器）
PORT=8080:80

# 静态文件路径（你的网站文件所在目录）
WEB_ROOT=/path/to/your/web/files
```

### 3. 配置 Nginx（可选）

如果需要自定义配置，编辑 `dockerfiles/config/nginx/conf.d/` 目录下的配置文件。

默认配置适用于：
- 静态网站托管
- SPA 单页应用（React、Vue 等）
- API 反向代理

### 4. 启动服务

```bash
# 启动服务
./manage.sh start

# 查看日志
./manage.sh logs

# 停止服务
./manage.sh stop

# 重启服务
./manage.sh restart

# 查看状态
./manage.sh status
```

## 目录结构

```
nginx_start_web/
├── README.md              # 项目文档
├── config.env            # 配置文件
├── config.env.example    # 配置示例
├── manage.sh             # 管理脚本
├── start_web.sh          # 启动脚本（已被 manage.sh 集成）
├── .gitignore           # Git 忽略文件
├── Dockerfile           # 自定义镜像构建（可选）
└── dockerfiles/
    └── config/
        └── nginx/
            ├── nginx.conf              # Nginx 主配置
            └── conf.d/
                ├── default.conf        # 默认站点配置
                └── site.conf.example   # 配置示例
```

## 配置说明

### 基本配置 (config.env)

```bash
# 容器名称（必填）
CONTAINER_NAME=nginx_web_app

# 端口映射（必填）
# 格式：宿主机端口:容器端口
PORT=8080:80

# 网站根目录（必填）
# 你的静态文件所在的本地路径
WEB_ROOT=/data/www/myapp

# Nginx 镜像版本（可选，默认 latest）
NGINX_VERSION=latest

# 日志配置（可选）
LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
```

### Nginx 站点配置

在 `dockerfiles/config/nginx/conf.d/` 目录下创建 `.conf` 文件：

```nginx
server {
    listen 80;
    server_name example.com;
    root /data;
    index index.html;

    # SPA 应用路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理示例
    location /api/ {
        proxy_pass http://backend-server:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
    }
}
```

## 使用场景

### 1. 部署静态网站

```bash
# 1. 将你的 HTML/CSS/JS 文件放到某个目录
# 2. 在 config.env 中设置 WEB_ROOT 为该目录
# 3. 启动服务
./manage.sh start
```

### 2. 部署 React/Vue 等 SPA 应用

```bash
# 1. 构建你的前端项目
npm run build

# 2. 设置 WEB_ROOT 为 build/dist 目录
WEB_ROOT=/path/to/your/project/build

# 3. 使用 SPA 配置文件（确保包含 try_files 配置）
# 4. 启动服务
./manage.sh start
```

### 3. 带 API 代理的前端应用

在 Nginx 配置文件中添加：

```nginx
location /api/ {
    proxy_pass http://your-backend:port/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

## 常见问题

### Q: 如何查看运行日志？

```bash
./manage.sh logs          # 查看实时日志
./manage.sh logs -n 100   # 查看最后100行
```

### Q: 如何修改配置后重新加载？

```bash
./manage.sh restart
```

### Q: 端口被占用怎么办？

修改 `config.env` 中的 `PORT` 配置，使用其他端口。

### Q: 如何部署多个项目？

1. 复制整个项目目录
2. 修改 `config.env` 中的 `CONTAINER_NAME` 和 `PORT`
3. 设置不同的 `WEB_ROOT`
4. 分别启动

或者在同一个 Nginx 容器中配置多个 server 块（推荐）。

### Q: 如何配置 HTTPS？

1. 准备 SSL 证书文件
2. 在 Nginx 配置中添加 SSL 配置
3. 挂载证书目录到容器
4. 修改 `manage.sh` 添加证书卷挂载

示例：
```nginx
server {
    listen 443 ssl;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    # 其他配置...
}
```

## 高级用法

### 自定义 Docker 镜像

如果你需要安装额外的 Nginx 模块或工具：

```bash
# 构建自定义镜像
docker build -t my-nginx:latest -f Dockerfile .

# 在 config.env 中设置
CUSTOM_IMAGE=my-nginx:latest
```

### 性能优化

编辑 `dockerfiles/config/nginx/nginx.conf`：

```nginx
worker_processes auto;  # 自动检测 CPU 核心数
worker_connections 2048;  # 增加连接数

# 启用 gzip 压缩
gzip on;
gzip_vary on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 更新日志

### v1.0.0 (2025-11-07)
- 初始版本发布
- 支持基本的静态网站部署
- 支持 API 反向代理
- 添加管理脚本