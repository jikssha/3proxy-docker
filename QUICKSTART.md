# ⚡ 快速开始指南

## 🎯 ClawCloud 部署（推荐）

### 方案对比

| 方案 | 适用场景 | 优点 | 缺点 |
|------|----------|------|------|
| **GitHub Actions + Docker Hub** | 公开发布 | 用户一键部署，自动更新 | 需要配置 CI/CD |
| **直接使用 Dockerfile** | 个人使用 | 简单直接 | 用户需要自己构建 |

---

## 📦 方案一：使用 Docker Hub 镜像（推荐公开发布）

### 步骤概览

```
配置 GitHub Actions → 自动构建镜像 → 推送到 Docker Hub → 用户直接使用
```

### 1. 配置自动构建

#### 修改 workflow 文件

编辑 `.github/workflows/docker-publish.yml` 第 13 行：

```yaml
DOCKER_IMAGE: your-dockerhub-username/3proxy-socks5
```

替换为您的 Docker Hub 用户名，例如：

```yaml
DOCKER_IMAGE: johndoe/3proxy-socks5
```

#### 配置 Docker Hub 凭证

1. 访问 [Docker Hub](https://hub.docker.com/) → Security → New Access Token
2. 复制生成的令牌
3. 进入 GitHub 仓库 → Settings → Secrets and variables → Actions
4. 添加两个 Secret：
   - `DOCKER_USERNAME`: 您的 Docker Hub 用户名
   - `DOCKER_PASSWORD`: 刚才复制的访问令牌

#### 推送代码触发构建

```bash
git add .
git commit -m "Setup GitHub Actions"
git push origin main
```

等待 3-5 分钟，在 **Actions** 标签查看构建进度。

### 2. 用户在 ClawCloud 部署

构建成功后，用户只需：

1. 登录 ClawCloud
2. 创建应用 → 从镜像部署
3. **镜像地址填写**：`your-dockerhub-username/3proxy-socks5:latest`
4. 点击部署
5. 查看日志获取用户名和密码

**示例镜像地址：**
```
johndoe/3proxy-socks5:latest
```

---

## 🔧 方案二：直接使用 Dockerfile

适合个人使用或内部部署。

### ClawCloud 部署步骤

#### 情况 A：ClawCloud 支持 Git 仓库

1. 在 ClawCloud 选择 **从 Git 仓库部署**
2. 连接您的 GitHub 仓库
3. ClawCloud 会自动检测 Dockerfile 并构建
4. 查看日志获取凭证

#### 情况 B：需要手动构建

1. 本地构建并推送到 Docker Hub：

```bash
# 构建镜像
docker build -t your-username/3proxy-socks5:latest .

# 登录 Docker Hub
docker login

# 推送镜像
docker push your-username/3proxy-socks5:latest
```

2. 在 ClawCloud 使用镜像地址：`your-username/3proxy-socks5:latest`

---

## 📋 ClawCloud 配置参考

### 基础配置

| 配置项 | 填写内容 |
|--------|----------|
| **镜像地址** | `your-username/3proxy-socks5:latest` |
| **端口** | 留空（自动适配） |
| **环境变量** | 无需配置 |
| **资源** | 最小配置即可（512MB 内存） |

### 高级配置（可选）

#### 指定固定端口

添加环境变量：

```
PORT=8080
```

然后映射端口：`8080:8080`

#### 增加资源配置

```
内存：1GB
CPU：0.5 核
```

---

## 🔍 查看连接信息

部署成功后，在 ClawCloud 应用详情页点击 **日志**，您将看到：

```
========================================
  ✨ 3proxy 服务配置完成
========================================

📌 监听端口: 8080

👥 用户列表:
   [1] 用户名: 7a3f2b1c | 密码: kL9mP4nQ2wE5tY8u
   [2] 用户名: 9e4d6a8b | 密码: xR7vC3bN6mK9pL2s
   [3] 用户名: 2c5f8e1a | 密码: qW4eR7tY9uI2oP5a
   [4] 用户名: 6b9d2f4e | 密码: aS8dF3gH6jK9lZ2x
   [5] 用户名: 8a1c4e7b | 密码: zX5cV8bN3mQ6wE9r

🔗 连接串示例 (请替换 <服务器IP>):
   socks5://7a3f2b1c:kL9mP4nQ2wE5tY8u@<服务器IP>:8080
```

### 获取服务器 IP

在 ClawCloud 应用详情中查找：
- **公网访问地址** 或
- **域名** 或
- **TCP 代理地址**

最终连接串示例：
```
socks5://7a3f2b1c:kL9mP4nQ2wE5tY8u@your-app.clawcloud.com:8080
```

---

## 🧪 测试连接

### 使用 curl 测试

```bash
curl -x socks5://username:password@host:port https://api.ipify.org
```

### 使用浏览器

1. 打开浏览器代理设置
2. 配置 SOCKS5 代理：
   - 主机：`your-app.clawcloud.com`
   - 端口：`8080`
   - 用户名：`7a3f2b1c`
   - 密码：`kL9mP4nQ2wE5tY8u`
3. 访问 [https://api.ipify.org](https://api.ipify.org) 查看代理 IP

---

## 📊 方案选择建议

### 选择方案一（GitHub Actions）如果：

- ✅ 需要公开发布给他人使用
- ✅ 希望自动化构建和更新
- ✅ 支持多平台架构（amd64/arm64）
- ✅ 方便版本管理

### 选择方案二（直接 Dockerfile）如果：

- ✅ 仅自己使用
- ✅ 不想配置 CI/CD
- ✅ 平台支持直接从 Git 构建

---

## 🆘 故障排查

### 问题：ClawCloud 无法拉取镜像

**解决：**
- 确认镜像地址正确
- 确认 Docker Hub 仓库为公开（Public）
- 本地测试：`docker pull your-username/3proxy-socks5:latest`

### 问题：容器启动后无日志输出

**解决：**
- 等待 30 秒后刷新日志
- 检查容器状态是否为 Running
- 查看 ClawCloud 错误日志

### 问题：代理无法连接

**解决：**
- 确认用户名密码正确
- 确认端口未被防火墙拦截
- 检查 ClawCloud 网络配置

---

## 📚 详细文档

- **完整功能说明**：`README.md`
- **GitHub Actions 详细配置**：`GITHUB_ACTIONS_SETUP.md`
- **多平台部署指南**：`DEPLOY.md`

---

## ✅ 部署检查清单

### 方案一检查清单

- [ ] 修改 workflow 中的 Docker Hub 用户名
- [ ] 配置 GitHub Secrets（DOCKER_USERNAME 和 DOCKER_PASSWORD）
- [ ] 推送代码触发构建
- [ ] 在 Actions 标签确认构建成功
- [ ] 记录镜像地址供用户使用

### 方案二检查清单

- [ ] 确认 Dockerfile 和 entrypoint.sh 已上传
- [ ] ClawCloud 正确选择部署方式
- [ ] 容器成功启动
- [ ] 从日志获取连接信息

---

**部署愉快！** 🚀