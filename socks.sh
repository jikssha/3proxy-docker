#!/bin/bash
# =========================================================
# Gost Proxy Manager Pro (v2.0 - 终极效率版)
# 生成即打印，纯净格式导出，修复 HTTP GCP 绑定
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
        echo ">>> [v2.0] 正在从官方源下载核心组件..."
        apt-get update -qq && apt-get install -y curl wget jq ufw net-tools gzip > /dev/null 2>&1
        
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GOST_ARCH="linux-amd64" ;;
            aarch64) GOST_ARCH="linux-arm64" ;;
            *) GOST_ARCH="linux-amd64" ;;
        esac
        
        GOST_TAG="v2.11.5"
        GOST_VER="2.11.5"
        OFFICIAL_URL="https://github.com/ginuerzh/gost/releases/download/${GOST_TAG}/gost-${GOST_ARCH}-${GOST_VER}.gz"
        
        rm -f /tmp/gost.gz /tmp/gost
        wget --no-check-certificate -q --show-progress --timeout=30 "$OFFICIAL_URL" -O /tmp/gost.gz
        
        if [ ! -s /tmp/gost.gz ] || ! gzip -t /tmp/gost.gz > /dev/null 2>&1; then
            echo "❌ 官方源下载失败。" && exit 1
        fi
        gunzip -f /tmp/gost.gz && mv /tmp/gost "$GOST_BIN" && chmod +x "$GOST_BIN"
    fi
    [ ! -f "$CONFIG_FILE" ] && init_config
    setup_systemd
}

init_config() {
    mkdir -p "$CONFIG_DIR"
    echo -e '{\n  "Debug": true,\n  "ServeNodes": []\n}' > "$CONFIG_FILE"
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
}

# --- 2. 节点生成 (即时打印 & 纯净格式) ---
generate_nodes() {
    local n=$1; local p=$2; local type=$3
    get_public_ip
    [ ! -f "$CONFIG_FILE" ] && init_config
    [ ! -s "$EXPORT_FILE" ] && echo "--- Gost Proxy List ---" > "$EXPORT_FILE"
    
    local new_start_line=$(wc -l < "$EXPORT_FILE")
    ((new_start_line++))

    for ((i=0; i<n; i++)); do
        local u="u$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
        local pw="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)"
        local rp=$((p + i))
        
        # 强制显式绑定 0.0.0.0 解决 GCP HTTP 失败问题
        local node="${type}://${u}:${pw}@0.0.0.0:${rp}"
        
        jq ".ServeNodes += [\"$node\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        # 纯净格式导出: IP:端口:账号:密码
        echo "$PUB_IP:$rp:$u:$pw" >> "$EXPORT_FILE"
    done
    
    ufw allow $p:$((p + n))/tcp > /dev/null 2>&1
    reload_service
    
    echo -e "\n✅ 节点生成成功！当前新增列表如下："
    echo "--------------------------------------------------------"
    sed -n "${new_start_line},\$p" "$EXPORT_FILE"
    echo "--------------------------------------------------------"
}

# --- 3. 菜单控制 ---
show_menu() {
    while true; do
        clear
        echo "=== Gost Manager Pro v2.0 (终极版) ==="
        echo " 1. ➕ 创建新节点 (HTTP/SOCKS5)"
        echo " 2. 📜 查看所有节点"
        echo " 3. 🧹 清空所有配置"
        echo " 4. 📋 查看 Debug 日志"
        echo " 5. 🗑️  卸载脚本"
        echo " 0. 退出"
        read -p "选择: " opt
        case $opt in
            1)
                echo "1. SOCKS5 / 2. HTTP"; read -p "协议: " pr
                [ "$pr" == "2" ] && local t="http" || local t="socks5"
                read -p "数量: " num; read -p "起始端口: " sport
                generate_nodes "$num" "$sport" "$t"
                read -p "按回车继续..." ;;
            2)
                clear
                echo "--- 全部节点导出列表 (IP:端口:账号:密码) ---"
                [ ! -s "$EXPORT_FILE" ] && echo "无可用节点。" || grep ":" "$EXPORT_FILE"
                read -p "按回车继续..." ;;
            3) init_config; : > "$EXPORT_FILE"; reload_service; read -p "已清空。" ;;
            4) journalctl -u gost -n 50 --no-pager; read -p "按回车继续..." ;;
            5) systemctl stop gost; rm -rf "$GOST_BIN" "$CONFIG_DIR" "$SYSTEMD_SERVICE" "$SHORTCUT_PATH" "$SCRIPT_PATH"; exit 0 ;;
            0) exit 0 ;;
        esac
    done
}

# --- 执行入口 ---
check_root; install_gost;
wget -q "$RAW_URL" -O "$SCRIPT_PATH" || curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
[ ! -f "$SHORTCUT_PATH" ] && echo -e "#!/bin/bash\nexec $SCRIPT_PATH \"\$@\"" > "$SHORTCUT_PATH" && chmod +x "$SHORTCUT_PATH"
show_menu
