# 🌐 SOCKS5 代理服务器

一个轻量级、开箱即用的 SOCKS5 代理服务器，专为 Railway 和 ClawCloud 等云平台设计。

## ✨ 特性

- 🚀 **自动化部署**：推送代码到 GitHub，自动构建 Docker 镜像
- 🔐 **多用户支持**：每次启动自动生成 5 个随机用户账号
- 🌍 **单端口多用户**：所有用户共享一个端口
- 📱 **平台适配**：完美支持 Railway、ClawCloud 等云平台
- 🏗️ **多架构支持**：支持 `linux/amd64` 和 `linux/arm64`
- 📋 **自动显示节点信息**：启动时在日志中显示完整连接信息

## 🎯 技术栈

- **代理服务器**：[gost](https://github.com/go-gost/gost) v3.0.0
- **容器化**：Docker 多阶段构建
- **CI/CD**：GitHub Actions
- **镜像仓库**：GitHub Container Registry (ghcr.io)

## 📦 快速开始

### 1️⃣ 推送代码到 GitHub

```bash
git clone <your-repo-url>
cd socks5-proxy
git add .
git commit -m "Initial commit"
git push origin main
```

### 2️⃣ 等待 GitHub Actions 构建

访问仓库的 **Actions** 标签，等待 "Docker Image CI/CD" 完成构建。

### 3️⃣ 获取镜像地址

构建完成后，你的镜像地址为：

```
ghcr.io/<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>:latest
```

### 4️⃣ 部署到云平台

#### Railway 部署

1. 访问 [Railway](https://railway.app/)
2. 创建新项目 → Deploy from Docker Image
3. 填入你的镜像地址
4. 等待部署完成，查看日志获取节点信息

#### ClawCloud 部署

1. 登录 ClawCloud 控制面板
2. 创建新容器实例
3. 填入你的镜像地址
4. 启动容器，查看日志获取节点信息

## 📊 日志示例

容器启动后会显示：

```
========================================
  🎉 SOCKS5 节点信息
========================================

节点 1:
  服务器: 123.45.67.89
  端口: 10000
  用户名: user_a8Kj9mNp
  密码: xY3kL9mP4qR8sT2v
  协议: SOCKS5

  连接链接: socks5://user_a8Kj9mNp:xY3kL9mP4qR8sT2v@123.45.67.89:10000

----------------------------------------
```

⚠️ **重要**：请立即保存这些信息，容器重启后会生成新的随机账号！

## 🔧 项目结构

```
.
├── Dockerfile                      # Docker 镜像构建配置
├── entrypoint.sh                   # 容器启动脚本
├── .github/
│   └── workflows/
│       └── docker-publish.yml      # GitHub Actions 自动构建
├── DEPLOYMENT_GUIDE.md             # 详细部署指南
└── README.md                       # 本文档
```

## 🛠️ 自定义配置

### 修改用户数量

编辑 `entrypoint.sh`，修改循环范围：

```bash
# 生成 10 个用户
for i in {1..10}; do
```

### 固定端口（本地测试）

```bash
docker run -e PORT=1080 -p 1080:1080 ghcr.io/<username>/<repo>:latest
```

## 📱 客户端配置

### 使用 curl 测试

```bash
curl --socks5 username:password@server_ip:port https://ipinfo.io
```

### 浏览器插件 (SwitchyOmega)

- **协议**：SOCKS5
- **服务器**：从日志获取
- **端口**：从日志获取
- **用户名**：从日志获取
- **密码**：从日志获取

## 🐛 故障排除

### GitHub Actions 构建失败

确保仓库设置正确：
- Settings → Actions → General
- Workflow permissions: "Read and write permissions"

### 容器无法启动

检查日志输出，确保：
- `entrypoint.sh` 有执行权限
- gost 进程正常启动

### 镜像拉取权限问题

将包设置为公开：
- GitHub → Packages → 你的包 → Package settings
- Change visibility → Public

## 📚 详细文档

查看 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) 获取完整的部署说明和高级配置。

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**注意**：本项目仅供学习和合法用途，请遵守当地法律法规。
