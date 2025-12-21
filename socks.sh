#!/bin/bash
# =========================================================
# Gost Proxy Manager Pro (v1.5 - 稳定版)
# 基于 Gost 的现代化代理管理脚本，支持 HTTP / SOCKS5
# =========================================================

# --- 核心路径配置 ---
GOST_BIN="/usr/local/bin/gost"
CONFIG_DIR="/etc/gost"
CONFIG_FILE="$CONFIG_DIR/config.json"
EXPORT_FILE="/root/gost_nodes.txt"
SYSTEMD_SERVICE="/etc/systemd/system/gost.service"
SHORTCUT_PATH="/usr/bin/gost"
SCRIPT_PATH="/usr/local/bin/gost-manager.sh"
RAW_URL="https://raw.githubusercontent.com/jikssha/Gost-Proxy-Manager/main/socks.sh"

# --- 1. 环境检测与安装 ---
check_root() {
    [ $(id -u) != "0" ] && { echo "❌ 错误: 请使用 root 权限运行此脚本"; exit 1; }
}

get_public_ip() {
    PUB_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ident.me || echo "VPS_IP")
}

install_gost() {
    if [ ! -f "$GOST_BIN" ]; then
        echo ">>> [v1.5] 正在安装 Gost 代理工具..."
        
        # 安装必要组件
        apt-get update -qq && apt-get install -y curl wget jq ufw net-tools gzip > /dev/null 2>&1
        
        # 检测系统架构
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GOST_ARCH="linux-amd64" ;;
            aarch64) GOST_ARCH="linux-arm64" ;;
            *) GOST_ARCH="linux-amd64" ;;
        esac
        
        # 修正：Gost 的 tag 带有 v，但文件名通常不带 v
        GOST_TAG="v2.11.5"
        GOST_VER="2.11.5"
        GOST_FILE="gost-${GOST_ARCH}-${GOST_VER}.gz"
        
        echo ">>> 目标版本: $GOST_TAG ($GOST_ARCH)"
        
        # 优化镜像列表
        MIRRORS=(
            "https://ghp.ci/https://github.com/ginuerzh/gost/releases/download/${GOST_TAG}/${GOST_FILE}"
            "https://mirror.ghproxy.com/https://github.com/ginuerzh/gost/releases/download/${GOST_TAG}/${GOST_FILE}"
            "https://github.moeyy.xyz/https://github.com/ginuerzh/gost/releases/download/${GOST_TAG}/${GOST_FILE}"
            "https://gh-proxy.com/https://github.com/ginuerzh/gost/releases/download/${GOST_TAG}/${GOST_FILE}"
        )
        
        DOWNLOAD_SUCCESS=false
        for mirror in "${MIRRORS[@]}"; do
            echo -e "\n>>> 尝试源: $(echo $mirror | cut -d'/' -f3)"
            rm -f /tmp/gost.gz
            
            # 使用 wget 下载，展示进度
            if wget --no-check-certificate --timeout=60 --tries=2 "$mirror" -O /tmp/gost.gz; then
                local fsize=$(stat -c%s "/tmp/gost.gz" 2>/dev/null || echo 0)
                if [ "$fsize" -gt 3000000 ] && gzip -t /tmp/gost.gz > /dev/null 2>&1; then
                    echo ">>> [校验成功] 准备解压安装..."
                    DOWNLOAD_SUCCESS=true && break
                fi
            fi
            echo ">>> 该源无效 (可能是 404 或超时)，尝试下一个..."
        done

        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            echo -e "\n❌ 无法自动下载 Gost 程序。请确认以下链接是否可以手动访问："
            echo "https://github.com/ginuerzh/gost/releases/download/${GOST_TAG}/${GOST_FILE}"
            exit 1
        fi
        
        gunzip -f /tmp/gost.gz && mv /tmp/gost "$GOST_BIN" && chmod +x "$GOST_BIN"
        echo ">>> ✅ Gost 安装成功！"
    fi
    mkdir -p "$CONFIG_DIR" && [ ! -f "$CONFIG_FILE" ] && init_config
    setup_systemd
}

# --- 配置文件 ---
init_config() {
    cat > "$CONFIG_FILE" <<EOF
{
  "Debug": false,
  "ServeNodes": []
}
EOF
}

setup_systemd() {
    cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Gost Proxy Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$GOST_BIN -C $CONFIG_FILE
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable gost > /dev/null 2>&1
}

reload_service() {
    systemctl daemon-reload && systemctl restart gost
    sleep 2
    systemctl is-active --quiet gost && echo ">>> ✅ 服务已启动" || echo ">>> ❌ 启动失败"
}

# --- 节点管理 ---
generate_nodes() {
    local count=$1; local port=$2; local mode=$3; local proto=$4
    get_public_ip
    [ $(jq '.ServeNodes | length' "$CONFIG_FILE") -eq 0 ] && echo "--- Gost Proxy List ---" > "$EXPORT_FILE"
    
    for ((i=0; i<count; i++)); do
        local u="u$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
        local p="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)"
        local rp=$((port + i)); [ "$mode" == "1" ] && rp=$port
        
        local node="${proto}://${u}:${p}@:${rp}"
        jq ".ServeNodes += [\"$node\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo "$PUB_IP:$rp:$u:$p:$proto" >> "$EXPORT_FILE"
    done
    ufw allow $port:$((port + count))/tcp > /dev/null 2>&1
    reload_service
    echo "========================================================"
    cat "$EXPORT_FILE"
    echo "========================================================"
}

action_create() {
    echo -e "\n1. SOCKS5\n2. HTTP"
    read -p "选择协议: " p; [ "$p" == "2" ] && local t="http" || local t="socks5"
    read -p "生成数量: " n; read -p "起始端口: " s
    generate_nodes "$n" "$s" "2" "$t"
}

install_shortcut() {
    wget -q "$RAW_URL" -O "$SCRIPT_PATH" || curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    [ ! -f "$SHORTCUT_PATH" ] && echo -e "#!/bin/bash\nexec $SCRIPT_PATH \"\$@\"" > "$SHORTCUT_PATH" && chmod +x "$SHORTCUT_PATH"
}

# --- 主入口 ---
check_root
install_gost
install_shortcut
while true; do
    clear
    echo "=== Gost Manager Pro v1.5 ==="
    echo "1. ➕ 创建节点"
    echo "2. 📜 查看节点"
    echo "3. 🧹 清空配置"
    echo "4. 📋 系统日志"
    echo "5. 🗑️ 彻底卸载"
    echo "0. 退出"
    read -p "请选择: " o
    case $o in
        1) action_create; read -p "回车继续..." ;;
        2) clear; cat "$EXPORT_FILE"; read -p "回车继续..." ;;
        3) init_config; : > "$EXPORT_FILE"; reload_service; read -p "已清空..." ;;
        4) journalctl -u gost -n 20 --no-pager; read -p "回车继续..." ;;
        5) systemctl stop gost; rm -rf "$GOST_BIN" "$CONFIG_DIR" "$SYSTEMD_SERVICE" "$SHORTCUT_PATH" "$SCRIPT_PATH"; exit 0 ;;
        0) exit 0 ;;
    esac
done
