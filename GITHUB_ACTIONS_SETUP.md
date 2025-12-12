# 🚀 GitHub Actions 自动构建 Docker 镜像指南

## 📋 方案概述

对于 **ClawCloud 公开发布** 场景，推荐使用以下方案：

```
GitHub 仓库 → GitHub Actions 自动构建 → 推送到 Docker Hub → ClawCloud 拉取镜像
```

**优势：**
- ✅ 用户可直接使用镜像地址，无需自己构建
- ✅ 每次代码更新自动构建新镜像
- ✅ 支持版本标签管理（latest、v1.0.0 等）
- ✅ ClawCloud 部署简单，直接填写镜像地址

---

## 🛠️ 第一步：创建 GitHub Actions Workflow

### 1.1 创建文件

在您的 GitHub 仓库中创建文件：`.github/workflows/docker-publish.yml`

### 1.2 Workflow 文件内容

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main
      - master
    tags:
      - 'v*'
  workflow_dispatch:

env:
  DOCKER_IMAGE: your-dockerhub-username/3proxy-socks5

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout 代码
        uses: actions/checkout@v4

      - name: 设置 Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: 登录 Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: 提取 Docker 元数据
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.DOCKER_IMAGE }}
          tags: |
            type=raw,value=latest,enable={{is_default_branch}}
            type=semver,pattern={{version}}

      - name: 构建并推送 Docker 镜像
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**重要**：将第 12 行的 `your-dockerhub-username` 替换为您的 Docker Hub 用户名。

---

## 🔐 第二步：配置 Docker Hub 凭证

### 2.1 获取 Docker Hub 访问令牌

1. 登录 [Docker Hub](https://hub.docker.com/)
2. 头像 → **Account Settings** → **Security**
3. 点击 **New Access Token**
4. 描述：`GitHub Actions`
5. 权限：**Read, Write, Delete**
6. **复制令牌**（只显示一次）

### 2.2 配置 GitHub Secrets

进入 GitHub 仓库 → **Settings** → **Secrets and variables** → **Actions**

添加两个密钥：

| Name | Value |
|------|-------|
| `DOCKER_USERNAME` | 您的 Docker Hub 用户名 |
| `DOCKER_PASSWORD` | Docker Hub 访问令牌 |

---

## 🚀 第三步：触发构建

推送代码到 GitHub：

```bash
git add .
git commit -m "Add GitHub Actions workflow"
git push origin main
```

或手动触发：**Actions** → **Build and Push Docker Image** → **Run workflow**

---

## 🌐 第四步：在 ClawCloud 部署

### 镜像地址

构建成功后，您的镜像地址为：

```
your-dockerhub-username/3proxy-socks5:latest
```

### ClawCloud 配置

1. 登录 ClawCloud 控制台
2. 创建新应用 → **从镜像部署**
3. **镜像地址**填写：`your-dockerhub-username/3proxy-socks5:latest`
4. **端口**：留空（脚本自动适配）
5. 点击部署

### 查看日志获取凭证

部署成功后，进入应用 → **日志**，复制显示的用户名和密码：

```
========================================
  ✨ 3proxy 服务配置完成
========================================

📌 监听端口: 8080

👥 用户列表:
   [1] 用户名: 7a3f2b1c | 密码: kL9mP4nQ2wE5tY8u
   [2] 用户名: 9e4d6a8b | 密码: xR7vC3bN6mK9pL2s
   ...
```

---

## 📝 快速参考

### 完整步骤清单

1. ✅ 创建 `.github/workflows/docker-publish.yml`
2. ✅ 修改 DOCKER_IMAGE 为您的用户名
3. ✅ 在 Docker Hub 创建访问令牌
4. ✅ 在 GitHub 配置 Secrets
5. ✅ 推送代码触发构建
6. ✅ 在 ClawCloud 填写镜像地址
7. ✅ 查看日志获取凭证

### ClawCloud 镜像地址填写示例

```
johndoe/3proxy-socks5:latest
```

替换 `johndoe` 为您的 Docker Hub 用户名。

---

## ❓ 常见问题

**Q: workflow 运行失败？**  
A: 检查 GitHub Secrets 是否正确配置，DOCKER_PASSWORD 应该是访问令牌，不是密码。

**Q: ClawCloud 无法拉取镜像？**  
A: 确保 Docker Hub 仓库设置为公开（Public）。

**Q: 如何更新镜像？**  
A: 推送新代码到 GitHub，自动构建新镜像。ClawCloud 重启容器即可获取最新版本。

---

## 🎯 总结

使用此方案，您的用户只需要：

1. 知道镜像地址：`your-username/3proxy-socks5:latest`
2. 在任何支持 Docker 的平台部署
3. 查看日志获取随机生成的用户凭证

完全实现了**零配置、一键部署**的目标！
