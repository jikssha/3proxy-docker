#!/bin/bash
# =========================================================
# Gost Proxy Manager Pro (v1.7 - GCP 专项版)
# 对 GitHub 官方源进行了文件名修正，专为 GCP 等海外环境设计
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
        echo ">>> [v1.7] GCP 环境检测通过，正在从 GitHub 官方下载..."
        
        # 安装必要组件
        apt-get update -qq && apt-get install -y curl wget jq ufw net-tools gzip > /dev/null 2>&1
        
        # 精准检测架构
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GOST_ARCH="linux-amd64" ;;
            aarch64) GOST_ARCH="linux-arm64" ;;
            *) GOST_ARCH="linux-amd64" ;;
        esac
        
        # ⚠️ 修正文件名：Tag=v2.11.5, 但文件名=2.11.5
        GOST_TAG="v2.11.5"
        GOST_VER="2.11.5"
        
        # 构建官方下载链接
        OFFICIAL_URL="https://github.com/ginuerzh/gost/releases/download/${GOST_TAG}/gost-${GOST_ARCH}-${GOST_VER}.gz"
        
        echo ">>> 下载链接: $OFFICIAL_URL"
        rm -f /tmp/gost.gz /tmp/gost
        
        # GCP 直连下载 (增加 SSL 容错和重试)
        if wget --no-check-certificate -q --show-progress --timeout=30 --tries=3 "$OFFICIAL_URL" -O /tmp/gost.gz; then
            if gzip -t /tmp/gost.gz > /dev/null 2>&1; then
                echo ">>> 下载成功，正在解压..."
                gunzip -f /tmp/gost.gz && mv /tmp/gost "$GOST_BIN" && chmod +x "$GOST_BIN"
            else
                echo "❌ 错误：下载的文件损坏或非压缩格式。" && exit 1
            fi
        else
            echo "❌ 错误：无法从 GitHub 下载。请检查 GCP 防火墙是否阻止了 443 端口出站。"
            exit 1
        fi
        
        if ! "$GOST_BIN" -V >/dev/null 2>&1; then
            echo "❌ 核心文件不可运行。" && rm -f "$GOST_BIN" && exit 1
        fi
        echo ">>> ✅ Gost 安装成功！"
    fi
    mkdir -p "$CONFIG_DIR" && [ ! -f "$CONFIG_FILE" ] && echo -e '{\n  "Debug": false,\n  "ServeNodes": []\n}' > "$CONFIG_FILE"
    setup_systemd
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
    systemctl daemon-reload && systemctl restart gost && sleep 2
    systemctl is-active --quiet gost && echo ">>> ✅ 服务已启动" || echo ">>> 启动失败，请检查日志"
}

generate_nodes() {
    local n=$1; local p=$2; local type=$3
    get_public_ip
    [ ! -s "$EXPORT_FILE" ] && echo "--- Gost Proxy List ---" > "$EXPORT_FILE"
    for ((i=0; i<n; i++)); do
        local u="u$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
        local pw="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)"
        local rp=$((p + i))
        local node="${type}://${u}:${pw}@:${rp}"
        jq ".ServeNodes += [\"$node\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo "$PUB_IP:$rp:$u:$pw:$type" >> "$EXPORT_FILE"
    done
    ufw allow $p:$((p + n))/tcp > /dev/null 2>&1
    reload_service
}

# --- 菜单控制 ---
show_menu() {
    while true; do
        clear
        echo "=== Gost Manager Pro v1.7 (GCP-Edition) ==="
        echo "1. ➕ 创建节点 (HTTP/SOCKS5)"
        echo "2. 📜 查看节点列表"
        echo "3. 🧹 清空所有配置"
        echo "4. 📋 系统日志"
        echo "5. 🗑️  卸载脚本"
        echo "0. 退出"
        read -p "选择: " opt
        case $opt in
            1) 
                echo "1. SOCKS5 / 2. HTTP"; read -p "协议: " pr
                [ "$pr" == "2" ] && local t="http" || local t="socks5"
                read -p "数量: " num; read -p "起始端口: " sport
                generate_nodes "$num" "$sport" "$t"
                read -p "回车继续..." ;;
            2) clear; cat "$EXPORT_FILE"; read -p "回车继续..." ;;
            3) echo -e '{\n  "Debug": false,\n  "ServeNodes": []\n}' > "$CONFIG_FILE"
               : > "$EXPORT_FILE"; reload_service; read -p "已清空..." ;;
            4) journalctl -u gost -n 20 --no-pager; read -p "回车继续..." ;;
            5) systemctl stop gost; rm -rf "$GOST_BIN" "$CONFIG_DIR" "$SYSTEMD_SERVICE" "$SHORTCUT_PATH" "$SCRIPT_PATH"; exit 0 ;;
            0) exit 0 ;;
        esac
    done
}

# --- 执行入口 ---
check_root; install_gost;
# 集成快捷命令
wget -q "$RAW_URL" -O "$SCRIPT_PATH" || curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
[ ! -f "$SHORTCUT_PATH" ] && echo -e "#!/bin/bash\nexec $SCRIPT_PATH \"\$@\"" > "$SHORTCUT_PATH" && chmod +x "$SHORTCUT_PATH"
show_menu
