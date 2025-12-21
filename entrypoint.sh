#!/bin/bash
# =========================================================
# Gost Proxy Manager Pro (v1.0)
# 支持 HTTP / SOCKS5 协议，基于现代化的 Gost 代理工具
# =========================================================

# --- 核心配置 ---
GOST_BIN="/usr/local/bin/gost"
CONFIG_DIR="/etc/gost"
CONFIG_FILE="$CONFIG_DIR/config.json"
EXPORT_FILE="/root/gost_nodes.txt"
SYSTEMD_SERVICE="/etc/systemd/system/gost.service"
SHORTCUT_PATH="/usr/bin/gost-manager"

# --- 1. 环境检测与安装 ---
check_root() {
    [ $(id -u) != "0" ] && { echo "Error: 请使用 root 运行"; exit 1; }
}

get_public_ip() {
    PUB_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ident.me)
}

install_gost() {
    if [ ! -f "$GOST_BIN" ]; then
        echo ">>> 正在安装 Gost 代理工具..."
        
        # 安装依赖
        apt-get update -qq
        apt-get install -y curl wget jq ufw net-tools > /dev/null 2>&1
        
        # 检测系统架构
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GOST_ARCH="linux-amd64" ;;
            aarch64) GOST_ARCH="linux-arm64" ;;
            armv7l) GOST_ARCH="linux-armv7" ;;
            *) echo "不支持的架构: $ARCH"; exit 1 ;;
        esac
        
        # 下载最新版本 Gost
        GOST_VERSION=$(curl -s https://api.github.com/repos/ginuerzh/gost/releases/latest | jq -r .tag_name)
        DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/gost-${GOST_ARCH}-${GOST_VERSION}.gz"
        
        echo ">>> 下载 Gost ${GOST_VERSION} for ${GOST_ARCH}..."
        wget -q "$DOWNLOAD_URL" -O /tmp/gost.gz || {
            echo "下载失败，使用备用镜像..."
            wget -q "https://mirror.ghproxy.com/$DOWNLOAD_URL" -O /tmp/gost.gz
        }
        
        # 解压安装
        gunzip /tmp/gost.gz
        chmod +x /tmp/gost
        mv /tmp/gost "$GOST_BIN"
        
        echo ">>> Gost 安装完成！"
    fi
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    # 初始化配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        init_config
    fi
    
    # 设置 Systemd 服务
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
    echo ">>> 已初始化空配置文件"
}

# --- 3. Systemd 服务管理 ---
setup_systemd() {
    if [ ! -f "$SYSTEMD_SERVICE" ]; then
        cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Gost Proxy Service
Documentation=https://github.com/ginuerzh/gost
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
        echo ">>> Systemd 服务已配置并启用自动启动"
    fi
}

reload_service() {
    echo ">>> 正在重载 Gost 服务..."
    systemctl restart gost
    sleep 2
    if systemctl is-active --quiet gost; then
        echo ">>> 服务启动成功！"
    else
        echo ">>> [错误] Gost 启动失败，请检查配置："
        journalctl -u gost -n 20 --no-pager
    fi
}

# --- 4. 节点管理 ---
generate_nodes() {
    local count=$1
    local start_port=$2
    local mode=$3
    local protocol=$4
    
    get_public_ip
    
    # 检查配置文件是否为空
    local current_nodes=$(jq '.ServeNodes | length' "$CONFIG_FILE")
    if [ "$current_nodes" -eq 0 ]; then
        : > "$EXPORT_FILE"
        echo "--- Gost Proxy List ---" > "$EXPORT_FILE"
    fi
    
    echo ">>> 正在添加 $count 个 $protocol 节点..."
    
    for ((i=0; i<count; i++)); do
        local user="u$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
        local pass="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)"
        local real_port=$((start_port + i))
        [ "$mode" == "1" ] && real_port=$start_port
        
        # 构建 Gost 节点配置
        if [ "$protocol" == "http" ]; then
            local node="http://${user}:${pass}@:${real_port}"
        else
            local node="socks5://${user}:${pass}@:${real_port}"
        fi
        
        # 使用 jq 添加到配置文件
        jq ".ServeNodes += [\"$node\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        
        # 记录到导出文件
        echo "$PUB_IP:$real_port:$user:$pass:$protocol" >> "$EXPORT_FILE"
    done
    
    # 批量开放防火墙
    local end_port=$((start_port + count - 1))
    [ "$mode" == "1" ] && end_port=$start_port
    ufw allow $start_port:$end_port/tcp > /dev/null 2>&1
    
    reload_service
    
    echo "========================================================"
    cat "$EXPORT_FILE"
    echo "========================================================"
    echo "提示: 请确保在云服务商后台开放了 $start_port:$end_port 的入站权限。"
}

# --- 5. 交互菜单 ---
select_protocol_ui() {
    echo "------------------------------------------------"
    echo "请选择代理协议:"
    echo " [1] SOCKS5 (更稳定，推荐)"
    echo " [2] HTTP/HTTPS (适合浏览器环境)"
    read -p "选择 [1-2]: " p_choice
    [ "$p_choice" == "2" ] && PROTO_TYPE="http" || PROTO_TYPE="socks5"
}

action_create_or_append() {
    local current_nodes=$(jq '.ServeNodes | length' "$CONFIG_FILE")
    
    if [ "$current_nodes" -gt 0 ]; then
        echo "================================================"
        echo "检测到已有 $current_nodes 个节点。"
        echo " [1] 追加新节点（保留现有）"
        echo " [2] 覆盖所有节点（清空重建）"
        echo " [0] 返回上一级"
        read -p "请选择: " mode
        case $mode in
            0) submenu_node_manage; return ;;
            2) init_config ;;
            1) ;; # 继续追加
            *) action_create_or_append; return ;;
        esac
    else
        echo "当前无节点配置，将创建新节点。"
    fi
    
    read -p "节点数量: " count
    [ -z "$count" ] || [ "$count" -le 0 ] && { echo "数量无效"; read -p "回车继续..."; action_create_or_append; return; }
    
    select_protocol_ui
    
    # 获取起始端口
    local last_port=$(jq -r '.ServeNodes[]' "$CONFIG_FILE" 2>/dev/null | grep -oP ':\K[0-9]+$' | sort -nr | head -n1)
    if [ -z "$last_port" ]; then
        read -p "起始端口 (建议10000-60000): " start_port
        port_mode=2
    else
        echo "检测到最后使用端口: $last_port"
        echo " [1] 复用端口 $last_port (单端口多用户)"
        echo " [2] 从端口 $((last_port + 1)) 开始 (多端口)"
        read -p "选择: " port_mode
        if [ "$port_mode" == "1" ]; then
            start_port=$last_port
        else
            start_port=$((last_port + 1))
            port_mode=2
        fi
    fi
    
    generate_nodes "$count" "$start_port" "$port_mode" "$PROTO_TYPE"
    read -p "回车继续..."
    submenu_node_manage
}

action_delete_single() {
    if [ ! -f "$EXPORT_FILE" ] || [ ! -s "$EXPORT_FILE" ]; then
        echo "当前无节点记录。"
        read -p "回车返回..."
        submenu_reset
        return
    fi
    
    echo "========== 节点列表 =========="
    nl -w2 -s'. ' "$EXPORT_FILE" | grep -v "Proxy List"
    echo "=============================="
    read -p "请输入要删除的节点序号（0 返回）: " num
    
    [ "$num" == "0" ] && submenu_reset && return
    
    # 验证输入
    local total_lines=$(grep -c ":" "$EXPORT_FILE")
    if [ "$num" -lt 1 ] || [ "$num" -gt "$total_lines" ]; then
        echo "无效序号"
        read -p "回车继续..."
        action_delete_single
        return
    fi
    
    # 获取目标节点信息
    local target_line=$(sed -n "$((num + 1))p" "$EXPORT_FILE")  # +1 因为第一行是标题
    local target_port=$(echo "$target_line" | cut -d':' -f2)
    
    echo "准备删除: $target_line"
    read -p "确认删除？(y/n): " confirm
    [ "$confirm" != "y" ] && action_delete_single && return
    
    # 备份配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # 从 JSON 配置中删除（匹配端口）
    jq ".ServeNodes = [.ServeNodes[] | select(test(\":${target_port}$\") | not)]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    # 从导出文件删除
    sed -i "$((num + 1))d" "$EXPORT_FILE"
    
    reload_service
    echo "节点已删除。"
    read -p "回车继续..."
    submenu_reset
}

action_reset_all() {
    read -p "确认清除所有节点？(y/n): " confirm
    [ "$confirm" != "y" ] && submenu_reset && return
    
    init_config
    : > "$EXPORT_FILE"
    reload_service
    echo "已清空所有节点。"
    read -p "回车继续..."
    submenu_reset
}

action_view_list() {
    clear
    if [ ! -f "$EXPORT_FILE" ] || [ ! -s "$EXPORT_FILE" ]; then
        echo "========================================================"
        echo "   无节点记录"
        echo "========================================================"
        return
    fi
    
    echo "========================================================"
    echo "   节点列表 (按协议分组)"
    echo "========================================================"
    
    echo ""
    echo "【SOCKS5 节点】"
    echo "------------------------------------------------"
    grep "socks5" "$EXPORT_FILE" 2>/dev/null || echo "(无)"
    
    echo ""
    echo "【HTTP 节点】"
    echo "------------------------------------------------"
    grep "http" "$EXPORT_FILE" 2>/dev/null | grep -v "socks5" || echo "(无)"
    
    echo "========================================================"
}

action_monitor() {
    trap 'show_menu; return' INT
    
    echo "========================================================"
    echo "   实时监控 (按 Ctrl+C 返回主菜单)"
    echo "========================================================"
    while true; do
        clear
        echo "--- Gost 服务状态 ---"
        systemctl status gost --no-pager -l | head -n 15
        echo ""
        echo "--- 活动连接 ---"
        netstat -tnp 2>/dev/null | grep gost | grep ESTABLISHED || echo "(暂无活动连接)"
        echo ""
        echo "按 Ctrl+C 返回主菜单"
        sleep 2
    done
    
    trap - INT
}

action_uninstall() {
    read -p "确认卸载 Gost 及所有配置？(y/n): " confirm
    [ "$confirm" != "y" ] && show_menu && return
    
    systemctl stop gost 2>/dev/null
    systemctl disable gost 2>/dev/null
    rm -rf "$CONFIG_DIR" "$GOST_BIN" "$SYSTEMD_SERVICE" "$EXPORT_FILE" "$SHORTCUT_PATH"
    systemctl daemon-reload
    echo "已卸载。"
    exit 0
}

action_view_logs() {
    echo "========================================================"
    echo "   Gost 服务日志（最近50行）"
    echo "========================================================"
    journalctl -u gost -n 50 --no-pager
    read -p "回车返回..."
    show_menu
}

# --- 子菜单 ---
submenu_node_manage() {
    clear
    echo "========================================================"
    echo "   节点管理"
    echo "========================================================"
    echo " 1. 创建/新增节点"
    echo " 2. 查看已有节点"
    echo " 0. 返回主菜单"
    echo "========================================================"
    read -p "请选择: " choice
    case $choice in
        1) action_create_or_append ;;
        2) action_view_list; read -p "回车继续..." ; submenu_node_manage ;;
        0) show_menu ;;
        *) submenu_node_manage ;;
    esac
}

submenu_reset() {
    clear
    echo "========================================================"
    echo "   重置节点"
    echo "========================================================"
    echo " 1. 清除所有节点"
    echo " 2. 删除单个节点"
    echo " 0. 返回主菜单"
    echo "========================================================"
    read -p "请选择: " choice
    case $choice in
        1) action_reset_all ;;
        2) action_delete_single ;;
        0) show_menu ;;
        *) submenu_reset ;;
    esac
}

# --- 主菜单 ---
show_menu() {
    clear
    echo "========================================================"
    echo "   Gost Proxy Manager Pro"
    echo "========================================================"
    echo " 1. 📦 节点管理"
    echo " 2. 🔄 重置节点"
    echo " 3. 📜 查看节点列表"
    echo " 4. 📋 查看服务日志"
    echo " 5. 👁️  实时监控"
    echo " 6. 🗑️  卸载脚本"
    echo " 0. 退出"
    echo "========================================================"
    read -p "请选择: " OPTION
    case $OPTION in
        1) submenu_node_manage ;;
        2) submenu_reset ;;
        3) action_view_list; read -p "回车继续..." ; show_menu ;;
        4) action_view_logs ;;
        5) action_monitor ;;
        6) action_uninstall ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
}

# --- 安装快捷方式 ---
install_shortcut() {
    if [ "$0" != "$SHORTCUT_PATH" ]; then
        cp "$0" "$SHORTCUT_PATH"
        chmod +x "$SHORTCUT_PATH"
        echo ">>> 快捷指令 'gost-manager' 已安装"
    fi
}

# --- 执行入口 ---
check_root
install_shortcut
install_gost
show_menu
