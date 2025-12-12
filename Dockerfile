FROM golang:1.21-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache git

# 构建 gost
WORKDIR /build
RUN git clone --depth=1 --branch v3.0.0-rc10 https://github.com/go-gost/gost.git && \
    cd gost && \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o /gost ./cmd/gost

# 最终运行镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache bash curl ca-certificates

# 复制 gost 二进制文件
COPY --from=builder /gost /usr/local/bin/gost

# 复制启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 设置工作目录
WORKDIR /app

# 暴露端口（Railway 会动态分配）
EXPOSE 1080

# 启动脚本
ENTRYPOINT ["/entrypoint.sh"]
