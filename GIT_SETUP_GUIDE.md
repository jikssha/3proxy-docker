# 🔧 Git 初始化和推送完整指南

## 问题诊断

错误信息：`fatal: not a git repository`

**原因**：项目文件夹还没有初始化为 Git 仓库。

---

## 📝 完整操作步骤

### 第一步：初始化 Git 仓库

在 VSCode 终端（当前目录：`C:\Users\zzz\Desktop\3proxy-docker`）执行：

```bash
git init
```

**预期输出**：
```
Initialized empty Git repository in C:/Users/zzz/Desktop/3proxy-docker/.git/
```

---

### 第二步：配置 Git 用户信息（如果是首次使用）

```bash
# 设置用户名（替换为您的 GitHub 用户名）
git config --global user.name "your-github-username"

# 设置邮箱（替换为您的 GitHub 邮箱）
git config --global user.email "your-email@example.com"
```

**检查配置**：
```bash
git config --global user.name
git config --global user.email
```

---

### 第三步：添加所有文件到暂存区

```bash
git add .
```

---

### 第四步：提交更改

```bash
git commit -m "Initial commit: 3proxy with GitHub Actions"
```

**预期输出**：
```
[main (root-commit) xxxxxx] Initial commit: 3proxy with GitHub Actions
 X files changed, XXX insertions(+)
 create mode 100644 Dockerfile
 create mode 100755 entrypoint.sh
 ...
```

---

### 第五步：连接到 GitHub 远程仓库

**重要**：您需要先在 GitHub 上创建一个新仓库。

#### 5.1 在 GitHub 创建仓库

1. 访问 [GitHub](https://github.com/)
2. 点击右上角 **+** → **New repository**
3. 填写：
   - **Repository name**: `3proxy-docker`
   - **Description**: `3proxy SOCKS5 零配置 Docker 镜像`
   - **Public** 或 **Private**（推荐 Public 用于公开发布）
4. **不要**勾选 "Initialize this repository with a README"
5. 点击 **Create repository**

#### 5.2 添加远程仓库地址

复制 GitHub 显示的仓库地址，然后执行：

```bash
# 方式 A：使用 HTTPS（推荐新手）
git remote add origin https://github.com/your-username/3proxy-docker.git

# 方式 B：使用 SSH（如果已配置 SSH 密钥）
git remote add origin git@github.com:your-username/3proxy-docker.git
```

**替换 `your-username`** 为您的 GitHub 用户名。

**验证远程仓库**：
```bash
git remote -v
```

预期输出：
```
origin  https://github.com/your-username/3proxy-docker.git (fetch)
origin  https://github.com/your-username/3proxy-docker.git (push)
```

---

### 第六步：重命名默认分支（可选但推荐）

```bash
git branch -M main
```

---

### 第七步：推送到 GitHub

```bash
git push -u origin main
```

#### 可能遇到的情况：

**情况 A：需要登录 GitHub**

系统会弹出窗口要求登录，输入您的：
- GitHub 用户名
- GitHub 密码或个人访问令牌（Personal Access Token）

**情况 B：需要个人访问令牌（PAT）**

如果提示需要 token：

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 勾选权限：`repo`（完整的仓库控制权限）
4. 生成并复制令牌
5. 在命令行推送时，用令牌替代密码

**情况 C：推送成功**

预期输出：
```
Enumerating objects: XX, done.
Counting objects: 100% (XX/XX), done.
...
To https://github.com/your-username/3proxy-docker.git
 * [new branch]      main -> main
Branch 'main' set up to track remote branch 'main' from 'origin'.
```

---

## ✅ 验证推送成功

1. 打开浏览器访问您的 GitHub 仓库
2. 应该看到所有文件已上传
3. 点击 **Actions** 标签
4. 应该看到 "Build and Push Docker Image" workflow 正在运行

---

## 🔄 后续更新文件时的操作

完成初始推送后，以后修改文件只需：

```bash
# 1. 添加更改
git add .

# 2. 提交
git commit -m "描述您的更改"

# 3. 推送
git push
```

---

## 📋 完整命令清单（复制粘贴版）

```bash
# 1. 初始化仓库
git init

# 2. 配置用户信息（首次使用）
git config --global user.name "your-github-username"
git config --global user.email "your-email@example.com"

# 3. 添加文件
git add .

# 4. 提交
git commit -m "Initial commit: 3proxy with GitHub Actions"

# 5. 添加远程仓库（替换 your-username）
git remote add origin https://github.com/your-username/3proxy-docker.git

# 6. 重命名分支
git branch -M main

# 7. 推送
git push -u origin main
```

---

## ❓ 常见问题

### Q1: 推送时要求输入用户名密码？

**A**: 这是正常的首次认证。输入您的：
- 用户名：GitHub 用户名
- 密码：GitHub 密码或个人访问令牌（PAT）

GitHub 已不再支持密码登录，建议使用 PAT。

### Q2: `error: remote origin already exists`？

**A**: 说明已经添加过远程仓库，删除后重新添加：

```bash
git remote remove origin
git remote add origin https://github.com/your-username/3proxy-docker.git
```

### Q3: `error: failed to push some refs`？

**A**: 可能是远程仓库有您本地没有的内容，先拉取：

```bash
git pull origin main --allow-unrelated-histories
git push -u origin main
```

### Q4: 如何检查当前 Git 状态？

**A**: 使用以下命令：

```bash
# 查看文件状态
git status

# 查看远程仓库
git remote -v

# 查看提交历史
git log --oneline
```

---

## 🎯 下一步

推送成功后：

1. ✅ 在 GitHub Actions 查看构建进度
2. ✅ 修改 `.github/workflows/docker-publish.yml` 中的 Docker Hub 用户名
3. ✅ 配置 GitHub Secrets（DOCKER_USERNAME 和 DOCKER_PASSWORD）
4. ✅ 再次推送触发自动构建

---

## 📚 参考资源

- [GitHub 创建仓库文档](https://docs.github.com/en/get-started/quickstart/create-a-repo)
- [Git 基础教程](https://git-scm.com/book/zh/v2)
- [GitHub Personal Access Token 创建](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

---

**按照此指南逐步操作，您就能成功推送代码到 GitHub！** 🚀