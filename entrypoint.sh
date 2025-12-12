#!/bin/bash

set -e

#============================================================
# 3proxy 智能启动脚本
# 功能：智能端口选择、自动多用户生成、零配置启动
#============================================================

CONFIG_FILE="/app/config/3proxy.cfg"
USER_COUNT=5

echo "========================================"
echo "  🚀 3proxy SOCKS5 代理服务启动中..."
echo "========================================"

#------------------------------------------------------------
# 1. 获取服务器公网 IP
#------------------------------------------------------------
get_public_ip() {
    local ip=""
    
    # 尝试方法1: ipify
    ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || true)
    if [ -n "$ip" ] && [ "$ip" != "" ]; then
        echo "$ip"
        return
    fi
    
    # 尝试方法2: ifconfig.me
    ip=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || true)
    if [ -n "$ip" ] && [ "$ip" != "" ]; then
        echo "$ip"
        return
    fi
    
    # 尝试方法3: icanhazip
    ip=$(curl -s --max-time 5 https://icanhazip.com 2>/dev/null || true)
    if [ -n "$ip" ] && [ "$ip" != "" ]; then
        echo "$ip"
        return
    fi
    
    # 如果都失败，返回占位符
    echo "YOUR_SERVER_IP"
}

echo ""
echo "🌐 正在获取服务器公网 IP..."
SERVER_IP=$(get_public_ip)
echo "✅ 服务器 IP: $SERVER_IP"

#------------------------------------------------------------
# 2. 端口配置（完全依赖环境变量）
#------------------------------------------------------------
if [ -n "$PORT" ]; then
    # 使用环境变量指定的端口
    PROXY_PORT=$PORT
    echo "✅ 使用环境变量端口: $PROXY_PORT"
else
    # 使用默认固定端口（标准代理端口）
    PROXY_PORT=3128
    echo "⚠️  未设置 PORT 环境变量，使用默认端口: $PROXY_PORT"
fi

#------------------------------------------------------------
# 3. 自动生成多用户凭证
#------------------------------------------------------------
echo ""
echo "🔐 正在生成 $USER_COUNT 组随机用户凭证..."
USERS=()

for i in $(seq 1 $USER_COUNT); do
    # 生成随机用户名（8字符）和密码（16字符）
    USERNAME=$(openssl rand -hex 4)
    PASSWORD=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)
    USERS+=("$USERNAME:$PASSWORD")
done

#------------------------------------------------------------
# 4. 动态生成 3proxy 配置文件
#------------------------------------------------------------
echo ""
echo "📝 生成配置文件: $CONFIG_FILE"

cat > "$CONFIG_FILE" <<EOF
# 3proxy 配置文件 - 自动生成

# 日志输出到 stdout（利用 Docker logs）
log /dev/stdout D
logformat "- +_L%t.%.  %N.%p %E %U %C:%c %R:%r %O %I %h %T"

# DNS 服务器
nserver 1.1.1.1
nserver 8.8.8.8
nscache 65536

# 设置超时时间
timeouts 1 5 30 60 180 1800 15 60

# 多用户认证
EOF

# 添加所有用户
for user in "${USERS[@]}"; do
    echo "users $user" >> "$CONFIG_FILE"
done

cat >> "$CONFIG_FILE" <<EOF

# 访问控制
auth strong

# 允许所有源 IP
allow *

# SOCKS5 代理监听
socks -p$PROXY_PORT
EOF

#------------------------------------------------------------
# 5. 打印关键信息 Banner
#------------------------------------------------------------
echo ""
echo "========================================"
echo "  ✨ 3proxy 服务配置完成"
echo "========================================"
echo ""
echo "📌 容器内监听端口: $PROXY_PORT"
echo "📌 服务器IP: $SERVER_IP"
echo ""
echo "⚠️  ClawCloud 用户重要提示："
echo "   1. 3proxy 在容器内监听端口: $PROXY_PORT"
echo "   2. 请在 ClawCloud 后台查看【端口映射】中的【公网端口】"
echo "   3. 使用节点时必须使用【公网端口】，不是 $PROXY_PORT"
echo ""
echo "📋 节点格式: IP:公网端口:用户名:密码"
echo "========================================"
for i in "${!USERS[@]}"; do
    USER_INFO="${USERS[$i]}"
    USERNAME="${USER_INFO%%:*}"
    PASSWORD="${USER_INFO##*:}"
    echo "# 节点 $((i+1)): 将 <PUBLIC_PORT> 替换为 ClawCloud 显示的公网端口"
    echo "${SERVER_IP}:<PUBLIC_PORT>:${USERNAME}:${PASSWORD}"
    echo ""
done
echo "========================================"
echo ""
echo "💡 示例："
echo "   如果 ClawCloud 显示公网端口为 32145，则实际节点为："
FIRST_USER="${USERS[0]}"
FIRST_USERNAME="${FIRST_USER%%:*}"
FIRST_PASSWORD="${FIRST_USER##*:}"
echo "   ${SERVER_IP}:32145:${FIRST_USERNAME}:${FIRST_PASSWORD}"
echo ""
echo "========================================"
echo "  🎯 服务正在启动..."
echo "========================================"
echo ""

#------------------------------------------------------------
# 6. 启动 3proxy（前台运行）
#------------------------------------------------------------
exec /app/bin/3proxy "$CONFIG_FILE"
