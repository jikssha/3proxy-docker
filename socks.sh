#!/bin/bash
# =========================================================
# Gost Proxy Manager Pro (v1.3 - 深度加固版)
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
        echo ">>> [v1.3] 正在安装 Gost 代理工具..."
        
        # 安装必要组件
        apt-get update -qq && apt-get install -y curl wget jq ufw net-tools gzip > /dev/null 2>&1
        
        # 检测系统架构
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GOST_ARCH="linux-amd64" ;;
            aarch64) GOST_ARCH="linux-arm64" ;;
            *) GOST_ARCH="linux-amd64" ;; # 默认 amd64
        esac
        
        GOST_VERSION="v2.11.5"
        GOST_FILE="gost-${GOST_ARCH}-${GOST_VERSION}.gz"
        echo ">>> 目标版本: $GOST_VERSION ($GOST_ARCH)"
        
        # 重新排序的加速镜像 (moeyy 优先)
        MIRRORS=(
            "https://github.moeyy.xyz/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://mirror.ghproxy.com/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://ghproxy.net/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
        )
        
        DOWNLOAD_SUCCESS=false
        for mirror in "${MIRRORS[@]}"; do
            echo ">>> 尝试下载源: $(echo $mirror | cut -d'/' -f3)"
            rm -f /tmp/gost.gz /tmp/gost
            
            # 使用 curl/wget 组合下载
            if curl -L -k --connect-timeout 10 --retry 1 "$mirror" -o /tmp/gost.gz > /dev/null 2>&1 || \
               wget --no-check-certificate --timeout=10 --tries=1 "$mirror" -O /tmp/gost.gz > /dev/null 2>&1; then
                
                # 严格校验：文件大小 + Gzip 格式
                local fsize=$(stat -c%s "/tmp/gost.gz" 2>/dev/null || echo 0)
                if [ "$fsize" -gt 1000000 ] && gzip -t /tmp/gost.gz > /dev/null 2>&1; then
                    echo ">>> [校验通过] 正在安装程序..."
                    DOWNLOAD_SUCCESS=true && break
                else
                    echo ">>> [跳过] 该源返回的数据无效或非压缩包。"
                fi
            fi
        done

        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            echo "❌ 严重错误: 所有下载镜像均失效，请更换 VPS 或手动上传程序。"
            exit 1
        fi
        
        gunzip -f /tmp/gost.gz && mv /tmp/gost "$GOST_BIN" && chmod +x "$GOST_BIN"
        
        if ! "$GOST_BIN" -V >/dev/null 2>&1; then
            echo "❌ 错误: 程序无法执行。"
            rm -f "$GOST_BIN" && exit 1
        fi
        echo ">>> ✅ Gost 安装成功！"
    fi
    mkdir -p "$CONFIG_DIR" && [ ! -f "$CONFIG_FILE" ] && init_config
    setup_systemd
}

# --- 2. 配置文件管理 ---
init_config() {
    cat > "$CONFIG_FILE" <<EOF
{
  "Debug": false,
  "ServeNodes": []
}
EOF
}

setup_systemd() {
    if [ ! -f "$SYSTEMD_SERVICE" ]; then
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
    fi
}

reload_service() {
    echo ">>> 正在重载服务..."
    systemctl daemon-reload && systemctl restart gost
    sleep 2
    systemctl is-active --quiet gost && echo ">>> ✅ 服务已启动" || { echo ">>> ❌ 启动失败"; journalctl -u gost -n 10 --no-pager; }
}

# --- 3. 节点管理逻辑 ---
generate_nodes() {
    local count=$1; local port=$2; local mode=$3; local proto=$4
    get_public_ip
    [ $(jq '.ServeNodes | length' "$CONFIG_FILE") -eq 0 ] && echo "--- Gost Proxy List ---" > "$EXPORT_FILE"
    
    for ((i=0; i<count; i++)); do
        local u="u$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
        local p="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)"
        local rp=$((port + i)); [ "$mode" == "1" ] && rp=$port
        
        local node="${proto}://${u}:${p}@0.0.0.0:${rp}"
        jq ".ServeNodes += [\"$node\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo "$PUB_IP:$rp:$u:$p:$proto" >> "$EXPORT_FILE"
    done
    ufw allow $port:$((port + count))/tcp > /dev/null 2>&1
    reload_service
    echo "========================================================"
    cat "$EXPORT_FILE"
    echo "========================================================"
}

# --- 4. 交互菜单 ---
action_create() {
    echo "创建节点: [1] SOCKS5 [2] HTTP"
    read -p "选择: " pidx; [ "$pidx" == "2" ] && local type="http" || local type="socks5"
    read -p "数量: " num; read -p "起始端口: " sport
    generate_nodes "$num" "$sport" "2" "$type"
    read -p "按回车继续..."
}

action_uninstall() {
    read -p "确认卸载？(y/n): " cf; [ "$cf" != "y" ] && return
    systemctl stop gost 2>/dev/null; systemctl disable gost 2>/dev/null
    rm -rf "$CONFIG_DIR" "$GOST_BIN" "$SYSTEMD_SERVICE" "$EXPORT_FILE" "$SHORTCUT_PATH" "$SCRIPT_PATH"
    echo "已卸载。" && exit 0
}

install_shortcut() {
    # 强制重新下载当前脚本保存
    wget -q "$RAW_URL" -O "$SCRIPT_PATH" || curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    if [ ! -f "$SHORTCUT_PATH" ]; then
        echo -e "#!/bin/bash\nexec $SCRIPT_PATH \"\$@\"" > "$SHORTCUT_PATH"
        chmod +x "$SHORTCUT_PATH"
    fi
}

show_menu() {
    while true; do
        clear
        echo "=== Gost Proxy Manager Pro v1.3 ==="
        echo " 1. ➕ 创建新节点"
        echo " 2. 📜 查看节点列表"
        echo " 3. 🧹 清空所有节点"
        echo " 4. 📋 查看系统日志"
        echo " 5. 🗑️  卸载脚本"
        echo " 0. 退出"
        read -p "请选择: " OPT
        case $OPT in
            1) action_create ;;
            2) clear; cat "$EXPORT_FILE"; read -p "回车继续..." ;;
            3) init_config; : > "$EXPORT_FILE"; reload_service; read -p "已清空..." ;;
            4) journalctl -u gost -n 20 --no-pager; read -p "回车继续..." ;;
            5) action_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

# --- 入口 ---
check_root; install_gost; install_shortcut; show_menu
