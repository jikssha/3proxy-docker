#!/bin/bash
# =========================================================
# Gost Proxy Manager Pro (v1.2)
# GitHub: https://github.com/jikssha/Gost-Proxy-Manager
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
        echo ">>> 正在安装 Gost 代理工具..."
        
        # 安装必要组件
        apt-get update -qq
        apt-get install -y curl wget jq ufw net-tools gzip > /dev/null 2>&1
        
        # 检测系统架构
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GOST_ARCH="linux-amd64" ;;
            aarch64) GOST_ARCH="linux-arm64" ;;
            armv7l) GOST_ARCH="linux-armv7" ;;
            *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
        esac
        
        # 锁定稳定版本
        GOST_VERSION="v2.11.5"
        GOST_FILE="gost-${GOST_ARCH}-${GOST_VERSION}.gz"
        echo ">>> 目标版本: $GOST_VERSION ($GOST_ARCH)"
        
        # 加速下载镜像源列表
        MIRRORS=(
            "https://ghproxy.net/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://gh.ddlc.top/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://mirror.ghproxy.com/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://github.moeyy.xyz/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
        )
        
        rm -f /tmp/gost.gz /tmp/gost
        DOWNLOAD_SUCCESS=false

        for mirror in "${MIRRORS[@]}"; do
            echo ">>> 尝试下载源: $(echo $mirror | cut -d'/' -f3)"
            # 尝试 wget
            wget --no-check-certificate --timeout=15 --tries=2 "$mirror" -O /tmp/gost.gz > /dev/null 2>&1
            if [ -s /tmp/gost.gz ]; then
                DOWNLOAD_SUCCESS=true && break
            fi
            # 如果 wget 失败，尝试 curl
            curl -L -k --connect-timeout 15 --retry 2 "$mirror" -o /tmp/gost.gz > /dev/null 2>&1
            if [ -s /tmp/gost.gz ]; then
                DOWNLOAD_SUCCESS=true && break
            fi
            echo ">>> 该源连接超时，尝试下一个..."
            rm -f /tmp/gost.gz
        done

        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            echo "❌ 严重错误: 所有下载镜像均失效，请检查 VPS 的国际网络连接。"
            exit 1
        fi
        
        echo ">>> 下载成功，正在解压安装..."
        gunzip -f /tmp/gost.gz
        mv /tmp/gost "$GOST_BIN"
        chmod +x "$GOST_BIN"
        
        if ! "$GOST_BIN" -V >/dev/null 2>&1; then
            echo "❌ 错误: Gost 安装后无法执行，请检查系统兼容性。"
            rm -f "$GOST_BIN"
            exit 1
        fi
        echo ">>> ✅ Gost 二进制文件安装成功！"
    fi
    
    mkdir -p "$CONFIG_DIR"
    [ ! -f "$CONFIG_FILE" ] && init_config
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
        systemctl daemon-reload
        systemctl enable gost > /dev/null 2>&1
    fi
}

reload_service() {
    echo ">>> 正在应用配置并重载服务..."
    systemctl daemon-reload
    systemctl restart gost
    sleep 2
    if systemctl is-active --quiet gost; then
        echo ">>> ✅ 服务启动成功！"
    else
        echo ">>> ❌ [错误] 服务启动失败，相关日志如下："
        journalctl -u gost -n 15 --no-pager
    fi
}

# --- 3. 节点管理核心逻辑 ---
generate_nodes() {
    local count=$1
    local start_port=$2
    local mode=$3
    local protocol=$4
    
    get_public_ip
    
    local current_nodes=$(jq '.ServeNodes | length' "$CONFIG_FILE")
    [ "$current_nodes" -eq 0 ] && echo "--- Gost Proxy List ---" > "$EXPORT_FILE"
    
    echo ">>> 正在添加 $count 个 $protocol 节点..."
    
    for ((i=0; i<count; i++)); do
        local user="u$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
        local pass="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)"
        local real_port=$((start_port + i))
        [ "$mode" == "1" ] && real_port=$start_port
        
        # Gost 配置格式优化 (针对 HTTP 加强兼容性)
        if [ "$protocol" == "http" ]; then
            local node="http://${user}:${pass}@0.0.0.0:${real_port}"
        else
            local node="socks5://${user}:${pass}@0.0.0.0:${real_port}"
        fi
        
        jq ".ServeNodes += [\"$node\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo "$PUB_IP:$real_port:$user:$pass:$protocol" >> "$EXPORT_FILE"
    done
    
    local end_port=$((start_port + count - 1))
    [ "$mode" == "1" ] && end_port=$start_port
    ufw allow $start_port:$end_port/tcp > /dev/null 2>&1
    
    reload_service
    
    echo "========================================================"
    cat "$EXPORT_FILE"
    echo "========================================================"
}

# --- 4. 交互菜单系统 ---
action_create_or_append() {
    local current_num=$(jq '.ServeNodes | length' "$CONFIG_FILE")
    if [ "$current_num" -gt 0 ]; then
        echo "检测到已有 $current_num 个节点: [1] 追加 [2] 清空重建 [0] 返回"
        read -p "选择: " m
        [ "$m" == "0" ] && return
        [ "$m" == "2" ] && init_config && : > "$EXPORT_FILE"
    fi
    
    read -p "请输入要生成的节点数量: " count
    echo "选择协议: [1] SOCKS5 [2] HTTP"
    read -p "协议序号: " p_idx
    [ "$p_idx" == "2" ] && local proto="http" || local proto="socks5"
    
    local last_port=$(jq -r '.ServeNodes[]' "$CONFIG_FILE" 2>/dev/null | grep -oP ':\K[0-9]+$' | sort -nr | head -n1)
    if [ -z "$last_port" ]; then
        read -p "请输入起始端口 (10000-60000): " s_port
        local p_mode=2
    else
        echo "最后使用端口: $last_port. [1] 复用(单端口多用户) [2] 新增端口"
        read -p "选择: " p_match
        if [ "$p_match" == "1" ]; then s_port=$last_port; p_mode=1; else s_port=$((last_port+1)); p_mode=2; fi
    fi
    
    generate_nodes "$count" "$s_port" "$p_mode" "$proto"
    read -p "按回车继续..."
}

action_view_list() {
    clear
    [ ! -s "$EXPORT_FILE" ] && echo "当前无任何节点。" || cat "$EXPORT_FILE"
    read -p "按回车继续..."
}

action_delete_single() {
    [ ! -s "$EXPORT_FILE" ] && echo "无可用节点。" && return
    nl -w2 -s'. ' "$EXPORT_FILE" | grep -v "Proxy List"
    read -p "请输入要删除的序号: " num
    local total=$(grep -c ":" "$EXPORT_FILE")
    [ "$num" -ge 1 ] && [ "$num" -le "$total" ] || return
    
    local line=$(sed -n "$((num+1))p" "$EXPORT_FILE")
    local port=$(echo "$line" | cut -d':' -f2)
    
    jq ".ServeNodes = [.ServeNodes[] | select(test(\":${port}$\") | not)]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    sed -i "$((num+1))d" "$EXPORT_FILE"
    
    reload_service
    echo "已成功删除序号 $num 的节点。"
    read -p "按回车继续..."
}

action_uninstall() {
    read -p "确认卸载整个 Gost 管理系统？(y/n): " confirm
    if [ "$confirm" == "y" ]; then
        systemctl stop gost 2>/dev/null && systemctl disable gost 2>/dev/null
        rm -rf "$CONFIG_DIR" "$GOST_BIN" "$SYSTEMD_SERVICE" "$EXPORT_FILE" "$SHORTCUT_PATH" "$SCRIPT_PATH"
        echo "已彻底卸载。" && exit 0
    fi
}

# --- 5. 系统集成 ---
install_shortcut() {
    # 如果检测到是管道运行，自动下载脚本保存
    if [[ "$0" == *"/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
        wget -q "$RAW_URL" -O "$SCRIPT_PATH" || curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
    else
        cp "$0" "$SCRIPT_PATH"
    fi
    chmod +x "$SCRIPT_PATH"
    
    # 修改软链接名为 gost
    if [ ! -f "$SHORTCUT_PATH" ]; then
        cat > "$SHORTCUT_PATH" <<EOF
#!/bin/bash
exec $SCRIPT_PATH "\$@"
EOF
        chmod +x "$SHORTCUT_PATH"
        echo ">>> 快捷命令 'gost' 安装成功"
    fi
}

show_menu() {
    while true; do
        clear
        echo "========================================================"
        echo "   Gost Proxy Manager Pro (加固版)"
        echo "========================================================"
        echo " 1. ➕ 创建/新增节点 (HTTP/SOCKS5)"
        echo " 2. 📜 查看节点列表"
        echo " 3. ❌ 删除单个节点"
        echo " 4. 🧹 清空所有节点"
        echo " 5. 📋 查看日志 / 6. 👁️ 实时监控"
        echo " 7. 🗑️  卸载脚本"
        echo " 0. 退出"
        echo "========================================================"
        read -p "请选择 [0-7]: " OPT
        case $OPT in
            1) action_create_or_append ;;
            2) action_view_list ;;
            3) action_delete_single ;;
            4) init_config && : > "$EXPORT_FILE" && reload_service ;;
            5) journalctl -u gost -n 30 --no-pager ; read -p "回车继续..." ;;
            6) clear && echo "正在监控日志 (Ctrl+C 退出)..." && journalctl -u gost -f ;;
            7) action_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

# --- 执行入口 ---
check_root
install_gost
install_shortcut
show_menu
