#!/bin/bash

# 设置错误处理
set -e

echo "========================================"
echo "  SOCKS5 代理服务器启动中..."
echo "========================================"

# 获取端口（Railway 会设置 PORT 环境变量）
PORT=${PORT:-1080}
echo "监听端口: $PORT"

# 生成随机字符串函数
generate_random_string() {
    local length=$1
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# 生成 5 个随机用户
echo ""
echo "正在生成 5 个 SOCKS5 用户..."
echo "========================================"

# 存储认证信息
AUTH_STRING=""
USERS=()

for i in {1..5}; do
    USERNAME="user_$(generate_random_string 8)"
    PASSWORD="$(generate_random_string 16)"
    
    # 添加到认证字符串
    if [ -z "$AUTH_STRING" ]; then
        AUTH_STRING="${USERNAME}:${PASSWORD}"
    else
        AUTH_STRING="${AUTH_STRING},${USERNAME}:${PASSWORD}"
    fi
    
    # 保存用户信息用于后续输出
    USERS+=("${USERNAME}:${PASSWORD}")
    
    echo "用户 $i: $USERNAME / $PASSWORD"
done

echo "========================================"
echo ""

# 等待一下，确保网络初始化完成
sleep 2

# 获取公网 IP（尝试多个服务）
echo "正在获取服务器公网 IP..."
PUBLIC_IP=""

# 尝试多个 IP 查询服务
IP_SERVICES=(
    "https://api.ipify.org"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
    "https://ident.me"
)

for service in "${IP_SERVICES[@]}"; do
    PUBLIC_IP=$(curl -s --connect-timeout 5 "$service" 2>/dev/null | tr -d '\n' || echo "")
    if [ ! -z "$PUBLIC_IP" ] && [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        break
    fi
done

if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP="YOUR_SERVER_IP"
    echo "⚠️  无法自动获取公网 IP，请手动替换"
else
    echo "✓ 检测到公网 IP: $PUBLIC_IP"
fi

echo ""
echo "========================================"
echo "  🎉 SOCKS5 节点信息"
echo "========================================"
echo ""

# 输出每个用户的连接信息
for i in "${!USERS[@]}"; do
    IFS=':' read -r username password <<< "${USERS[$i]}"
    node_num=$((i + 1))
    
    echo "节点 $node_num:"
    echo "  服务器: $PUBLIC_IP"
    echo "  端口: $PORT"
    echo "  用户名: $username"
    echo "  密码: $password"
    echo "  协议: SOCKS5"
    echo ""
    echo "  连接链接: socks5://${username}:${password}@${PUBLIC_IP}:${PORT}"
    echo ""
    echo "----------------------------------------"
done

echo ""
echo "提示: 请保存上述信息，容器重启后会生成新的随机账号"
echo "========================================"
echo ""
echo "🚀 正在启动 GOST SOCKS5 服务器..."
echo "配置: 端口=$PORT, 用户数=5"
echo ""

# 启动 gost（前台运行，支持多用户认证）
exec gost -L "socks5://${AUTH_STRING}@:${PORT}"
