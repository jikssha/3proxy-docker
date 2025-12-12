# 🚀 快速部署指南

## 📋 部署前检查清单

- [ ] 已安装 Docker（本地测试）
- [ ] 已注册 Railway 或 ClawCloud 账号（云部署）
- [ ] 已创建 GitHub 仓库（可选，用于 Railway 部署）

---

## 🖥️ 本地部署（5分钟）

### 步骤 1：构建镜像

```bash
cd 3proxy-docker
docker build -t 3proxy-socks5 .
```

### 步骤 2：启动容器

```bash
# 方式 A：使用随机端口
docker run -d --name my-proxy 3proxy-socks5

# 方式 B：映射到指定端口（例如 40000）
docker run -d --name my-proxy -p 40000:40000 3proxy-socks5

# 方式 C：使用环境变量指定端口
docker run -d --name my-proxy -e PORT=35000 -p 35000:35000 3proxy-socks5
```

### 步骤 3：获取连接信息

```bash
docker logs my-proxy
```

**输出示例：**
```
========================================
  🚀 3proxy SOCKS5 代理服务启动中...
========================================
🎲 自动生成随机端口: 42356

🔐 正在生成 5 组随机用户凭证...

📝 生成配置文件: /app/config/3proxy.cfg

========================================
  ✨ 3proxy 服务配置完成
========================================

📌 监听端口: 42356

👥 用户列表:
   [1] 用户名: 7a3f2b1c | 密码: kL9mP4nQ2wE5tY8u
   [2] 用户名: 9e4d6a8b | 密码: xR7vC3bN6mK9pL2s
   [3] 用户名: 2c5f8e1a | 密码: qW4eR7tY9uI2oP5a
   [4] 用户名: 6b9d2f4e | 密码: aS8dF3gH6jK9lZ2x
   [5] 用户名: 8a1c4e7b | 密码: zX5cV8bN3mQ6wE9r

🔗 连接串示例 (请替换 <服务器IP>):
   socks5://7a3f2b1c:kL9mP4nQ2wE5tY8u@<服务器IP>:42356
```

### 步骤 4：测试连接

```bash
# 使用 curl 测试（替换为实际的用户名、密码和端口）
curl -x socks5://7a3f2b1c:kL9mP4nQ2wE5tY8u@localhost:42356 https://api.ipify.org
```

---

## ☁️ Railway 部署（3分钟）

### 方法 1：GitHub 一键部署 ⭐ 推荐

#### 步骤 1：推送到 GitHub

```bash
cd 3proxy-docker
git init
git add .
git commit -m "Initial commit: 3proxy SOCKS5"
git remote add origin https://github.com/your-username/3proxy-socks5.git
git push -u origin main
```

#### 步骤 2：在 Railway 部署

1. 访问 [railway.app](https://railway.app)
2. 点击 **"New Project"**
3. 选择 **"Deploy from GitHub repo"**
4. 选择您的 `3proxy-socks5` 仓库
5. Railway 自动检测 Dockerfile 并开始构建

#### 步骤 3：获取连接信息

1. 等待部署完成（约 2-3 分钟）
2. 点击服务名称进入详情页
3. 点击 **"View Logs"** 查看启动日志
4. 复制用户名、密码和端口信息

#### 步骤 4：获取公网地址

1. 进入 **Settings → Networking**
2. 点击 **"Generate Domain"** 生成公网域名
3. 或查看 **Public Networking** 中的 TCP Proxy 地址

**连接示例：**
```
socks5://7a3f2b1c:kL9mP4nQ2wE5tY8u@your-app.railway.app:12345
```

---

### 方法 2：Railway CLI 部署

```bash
# 安装 CLI
npm i -g @railway/cli

# 登录
railway login

# 在项目目录中初始化
cd 3proxy-docker
railway init

# 部署
railway up

# 查看日志
railway logs
```

---

## ☁️ ClawCloud 部署

### 步骤 1：准备镜像

#### 选项 A：使用 Docker Hub

```bash
# 构建并推送到 Docker Hub
docker build -t your-dockerhub-username/3proxy-socks5:latest .
docker push your-dockerhub-username/3proxy-socks5:latest
```

#### 选项 B：使用 Dockerfile（如果平台支持）

直接上传 Dockerfile 和 entrypoint.sh

### 步骤 2：在 ClawCloud 创建实例

1. 登录 ClawCloud 控制台
2. 创建新的容器实例
3. **镜像设置**：
   - 使用 Docker Hub：输入 `your-dockerhub-username/3proxy-socks5:latest`
   - 使用 Dockerfile：上传项目文件
4. **端口配置**：
   - 如果平台自动注入 `$PORT`：无需配置
   - 如果需要手动配置：暴露任意端口（如 40000）
5. 点击创建并启动

### 步骤 3：查看日志获取凭证

在控制台查看实时日志，复制用户名和密码

---

## 🔧 高级配置

### 自定义用户数量

编辑 `entrypoint.sh` 第 11 行：

```bash
USER_COUNT=10  # 生成 10 个用户
```

重新构建镜像：

```bash
docker build -t 3proxy-socks5 .
```

### 使用固定用户名密码

创建自定义启动脚本或直接修改 `entrypoint.sh`：

```bash
# 替换第 36-41 行的随机生成逻辑
USERS=(
    "user1:password1"
    "user2:password2"
    "user3:password3"
)
```

### 自定义端口范围

编辑 `entrypoint.sh` 第 27 行：

```bash
# 改为 10000-20000 范围
PROXY_PORT=$((10000 + RANDOM % 10001))
```

---

## 📊 监控与管理

### 查看容器状态

```bash
docker ps -a | grep 3proxy
```

### 实时日志

```bash
docker logs -f my-proxy
```

### 重启容器（重新生成密码）

```bash
docker restart my-proxy
docker logs my-proxy  # 查看新密码
```

### 停止并删除

```bash
docker stop my-proxy
docker rm my-proxy
```

---

## 🧪 测试代理

### 使用 curl

```bash
curl -x socks5://username:password@host:port https://api.ipify.org
```

### 使用 Python

```python
import requests

proxies = {
    'http': 'socks5://username:password@host:port',
    'https': 'socks5://username:password@host:port'
}

response = requests.get('https://api.ipify.org', proxies=proxies)
print(f"代理IP: {response.text}")
```

### 浏览器配置

**Chrome/Edge：**
1. 设置 → 系统 → 打开代理设置
2. 手动代理配置
3. SOCKS Host: `host`，端口: `port`
4. SOCKS v5

---

## ⚠️ 常见问题

### Q1: Railway 部署后无法连接？

**A:** Railway 免费版可能不支持自定义 TCP 端口，建议：
- 检查是否生成了公网域名
- 查看 Networking 设置中的端口映射
- 尝试使用 Railway Pro 计划

### Q2: 容器启动后立即退出？

**A:** 检查日志：
```bash
docker logs my-proxy
```
常见原因：
- 端口被占用
- 配置文件生成失败
- 权限问题

### Q3: 如何保存用户凭证？

**A:** 启动时将日志重定向到文件：
```bash
docker logs my-proxy > proxy-credentials.txt
```

### Q4: 可以使用 Docker Compose 吗？

**A:** 可以！创建 `docker-compose.yml`：

```yaml
version: '3.8'

services:
  3proxy:
    build: .
    ports:
      - "40000:40000"
    environment:
      - PORT=40000
    restart: unless-stopped
```

运行：
```bash
docker-compose up -d
docker-compose logs
```

---

## 📞 技术支持

- 查看完整文档：`README.md`
- 提交问题：GitHub Issues
- 配置参考：`entrypoint.sh` 脚本注释

---

## ✅ 部署检查表

完成部署后，请确认：

- [ ] 容器正常运行（`docker ps`）
- [ ] 可以查看日志（`docker logs`）
- [ ] 已保存用户名和密码
- [ ] 已记录监听端口
- [ ] 代理连接测试成功
- [ ] （可选）已配置自动重启

---

**祝您部署顺利！** 🎉