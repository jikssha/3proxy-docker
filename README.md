# 3proxy SOCKS5 零配置 Docker 镜像

## 🎯 特性

- ✅ **智能端口适配**：自动检测 `$PORT` 环境变量（Railway/ClawCloud），或随机生成 30000-50000 端口
- ✅ **自动多用户**：启动时自动生成 5 组随机强密码用户
- ✅ **零配置启动**：无需手动编辑配置文件
- ✅ **轻量镜像**：基于 Alpine Linux，体积最小化
- ✅ **日志友好**：输出到 stdout，利用 Docker logs 查看

---

## 🚀 快速开始

### 本地测试

```bash
# 1. 构建镜像
docker build -t 3proxy-socks5 .

# 2. 运行容器
docker run -d --name my-proxy -p 40000:40000 3proxy-socks5

# 3. 查看启动日志（包含用户名密码）
docker logs my-proxy
```

---

## ☁️ Railway 部署

### 方法 1：通过 GitHub 仓库部署

1. 将代码推送到 GitHub 仓库
2. 在 Railway 控制台点击 **"New Project"** → **"Deploy from GitHub repo"**
3. 选择您的仓库
4. Railway 会自动检测 Dockerfile 并构建
5. **查看服务日志**获取用户名和密码

### 方法 2：通过 Railway CLI

```bash
# 安装 Railway CLI
npm i -g @railway/cli

# 登录
railway login

# 初始化项目
railway init

# 部署
railway up
```

### ⚠️ Railway 特别注意

- Railway 会自动注入 `$PORT` 环境变量（通常是随机端口）
- **不需要**在 Railway 设置中手动指定端口
- 脚本会自动使用 Railway 提供的 `$PORT`
- 部署后在 **Settings → Networking** 中可以看到公网访问地址和端口

---

## ☁️ ClawCloud 部署

### 部署步骤

1. 登录 ClawCloud 控制台
2. 创建新容器实例
3. **镜像源**：选择 Dockerfile 或推送到 Docker Hub
4. **端口映射**：
   - 如果平台提供 `$PORT` 变量：无需配置
   - 如果需要手动指定：映射容器内随机端口到公网（查看启动日志获取实际端口）
5. 启动后查看日志获取凭证

---

## 🔧 自定义配置

### 修改用户数量

编辑 `entrypoint.sh` 第 11 行：

```bash
USER_COUNT=10  # 改为需要的数量
```

### 自定义端口范围

编辑 `entrypoint.sh` 第 27 行：

```bash
PROXY_PORT=$((30000 + RANDOM % 20001))  # 修改范围
```

---

## 📊 查看运行日志

```bash
# Docker 本地
docker logs -f <容器名>

# Railway
railway logs

# ClawCloud
在控制台查看实时日志
```

---

## 🔒 安全建议

1. **定期重启**容器以重新生成随机密码
2. 不要在公开场合分享启动日志（包含明文密码）
3. 建议配合防火墙限制访问源 IP
4. 生产环境建议使用环境变量传入固定密码

---

## 🐛 故障排查

### 问题：无法连接到代理

- 检查端口是否正确映射（`docker ps` 查看端口）
- 确认防火墙允许对应端口
- 使用 `docker logs` 查看是否有错误信息

### 问题：Railway 部署后无法访问

- 确认服务状态为 **Active**
- 检查 Railway 是否分配了公网域名
- Railway 免费版可能有网络限制

### 问题：容器启动后立即退出

- 检查是否正确安装了 bash：`docker run --rm <镜像> which bash`
- 查看容器日志：`docker logs <容器名>`

---

## 📦 Docker Hub 发布（可选）

```bash
# 1. 登录 Docker Hub
docker login

# 2. 构建并打标签
docker build -t your-username/3proxy-socks5:latest .

# 3. 推送到 Docker Hub
docker push your-username/3proxy-socks5:latest
```

---

## 📝 配置文件说明

### 3proxy.cfg 关键配置

```conf
daemon              # 前台运行（不后台化）
log /dev/stdout D   # 日志输出到标准输出
nserver 1.1.1.1     # DNS 服务器
users user:pass     # 用户认证
auth strong         # 强认证模式
socks -p40000       # SOCKS5 监听端口
```

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License