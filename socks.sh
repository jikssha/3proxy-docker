#!/bin/bash
# =========================================================
# Gost Proxy Manager Pro (v1.1)
# 支持 HTTP / SOCKS5 协议，基于现代化的 Gost 代理工具
# =========================================================

# --- 核心配置 ---
GOST_BIN="/usr/local/bin/gost"
CONFIG_DIR="/etc/gost"
CONFIG_FILE="$CONFIG_DIR/config.json"
EXPORT_FILE="/root/gost_nodes.txt"
SYSTEMD_SERVICE="/etc/systemd/system/gost.service"
SHORTCUT_PATH="/usr/bin/gost"
SCRIPT_PATH="/usr/local/bin/gost-manager.sh"

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
        echo ">>> 安装依赖包..."
        apt-get update -qq
        apt-get install -y curl wget jq ufw net-tools gzip > /dev/null 2>&1
        
        # 检测系统架构
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GOST_ARCH="linux-amd64" ;;
            aarch64) GOST_ARCH="linux-arm64" ;;
            armv7l) GOST_ARCH="linux-armv7" ;;
            *) echo "不支持的架构: $ARCH"; exit 1 ;;
        esac
        
        # 获取最新版本
        echo ">>> 使用稳定版本 v2.11.5"
        GOST_VERSION="v2.11.5"
        
        echo ">>> 版本: $GOST_VERSION, 架构: $GOST_ARCH"
        
        # 构建文件名
        GOST_FILE="gost-${GOST_ARCH}-${GOST_VERSION}.gz"
        
        # 多个镜像源
        MIRRORS=(
            "https://ghproxy.com/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://gh.api.99988866.xyz/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://mirror.ghproxy.com/https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
            "https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/${GOST_FILE}"
        )
        
        # 下载文件
        echo ">>> 下载 Gost..."
        rm -f /tmp/gost.gz /tmp/gost
        
        DOWNLOAD_SUCCESS=false
        for mirror in "${MIRRORS[@]}"; do
            echo ">>> 尝试镜像: ${mirror%%/ginuerzh*}"
            if wget -q --timeout=30 --tries=2 "$mirror" -O /tmp/gost.gz 2>&1; then
                if [ -f /tmp/gost.gz ] && [ -s /tmp/gost.gz ]; then
                    echo ">>> 下载成功"
                    DOWNLOAD_SUCCESS=true
                    break
                fi
            fi
            echo ">>> 此镜像失败，尝试下一个..."
            rm -f /tmp/gost.gz
        done
        
        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            echo "❌ 错误: 所有镜像源下载失败"
            echo ""
            echo "请手动下载："
            echo "1. 访问: https://github.com/ginuerzh/gost/releases/tag/v2.11.5"
            echo "2. 下载: ${GOST_FILE}"
            echo "3. 上传到 /tmp/gost.gz"
            echo "4. 运行: gunzip /tmp/gost.gz && chmod +x /tmp/gost && mv /tmp/gost /usr/local/bin/gost"
            exit 1
        fi
        
        # 验证下载
        if [ ! -f /tmp/gost.gz ] || [ ! -s /tmp/gost.gz ]; then
            echo "错误: 下载的文件无效"
            exit 1
        fi
        
        echo ">>> 解压文件..."
        # 解压（使用 -f 强制覆盖）
        if ! gunzip -f /tmp/gost.gz 2>&1; then
            echo "错误: 解压失败"
            exit 1
        fi
        
        # 验证解压后的文件
        if [ ! -f /tmp/gost ]; then
            echo "错误: 解压后找不到 gost 文件"
            ls -la /tmp/gost*
            exit 1
        fi
        
        # 添加执行权限
        chmod +x /tmp/gost
        
        # 移动到目标位置
        mv /tmp/gost "$GOST_BIN"
        
        # 验证安装
        if [ ! -f "$GOST_BIN" ]; then
            echo "❌ 错误: Gost 安装失败 - 文件不存在"
            echo ""
            echo "请尝试手动安装："
            echo "1. 访问: https://github.com/ginuerzh/gost/releases"
            echo "2. 下载适合您系统的版本"
            echo "3. 解压后复制到: /usr/local/bin/gost"
            echo "4. 添加执行权限: chmod +x /usr/local/bin/gost"
            exit 1
        fi
        
        # 验证文件大小（不应该为空）
        local file_size=$(stat -c%s "$GOST_BIN" 2>/dev/null || stat -f%z "$GOST_BIN" 2>/dev/null)
        if [ -z "$file_size" ] || [ "$file_size" -lt 1000000 ]; then
            echo "❌ 错误: Gost 文件异常（大小: ${file_size} bytes）"
            echo "预期大小应该在 8-15 MB"
            rm -f "$GOST_BIN"
            exit 1
        fi
        
        # 测试可执行性
        if ! "$GOST_BIN" -V >/dev/null 2>&1; then
            echo "❌ 错误: Gost 无法执行"
            echo ""
            echo "可能原因："
            echo "1. 架构不匹配（当前: $ARCH, 下载: $GOST_ARCH）"
            echo "2. 文件损坏"
            echo ""
            echo "建议："
            echo "手动下载对应架构的版本："
            echo "  x86_64: linux-amd64"
            echo "  ARM64:  linux-arm64"
            echo "  ARMv7:  linux-armv7"
            rm -f "$GOST_BIN"
            exit 1
        fi
        
        echo ">>> ✅ Gost 安装成功！"
        echo ">>> 版本信息:"
        "$GOST_BIN" -V
        echo ">>> 文件大小: $(du -h "$GOST_BIN" | cut -f1)"
    else
        echo ">>> Gost 已安装: $GOST_BIN"
        # 验证已安装的文件
        if ! "$GOST_BIN" -V >/dev/null 2>&1; then
            echo "❌ 警告: 已安装的 Gost 无法执行，重新安装..."
            rm -f "$GOST_BIN"
            install_gost
            return
        fi
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
    
    # 验证 Gost 二进制文件
    if [ ! -f "$GOST_BIN" ]; then
        echo "错误: Gost 程序不存在: $GOST_BIN"
        return 1
    fi
    
    if [ ! -x "$GOST_BIN" ]; then
        echo "错误: Gost 程序没有执行权限"
        chmod +x "$GOST_BIN"
    fi
    
    # 验证配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "错误: 配置文件不存在: $CONFIG_FILE"
        init_config
    fi
    
    # 验证 JSON 格式
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo "错误: 配置文件 JSON 格式错误"
        cat "$CONFIG_FILE"
        return 1
    fi
    
    # 重启服务
    systemctl daemon-reload
    systemctl restart gost
    sleep 3
    
    if systemctl is-active --quiet gost; then
        echo ">>> ✅ 服务启动成功！"
        echo ">>> 监听端口:"
        netstat -tlnp | grep gost || echo "  (正在启动中...)"
    else
        echo ">>> ❌ [错误] Gost 启动失败"
        echo ""
        echo "--- 诊断信息 ---"
        echo "1. Gost 二进制文件:"
        ls -lh "$GOST_BIN"
        echo ""
        echo "2. 配置文件内容:"
        cat "$CONFIG_FILE"
        echo ""
        echo "3. 服务状态:"
        systemctl status gost --no-pager -l
        echo ""
        echo "4. 最近日志:"
        journalctl -u gost -n 30 --no-pager
        echo ""
        echo "5. 手动测试:"
        echo "   尝试运行: $GOST_BIN -C $CONFIG_FILE"
        return 1
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
            # HTTP 代理 - 尝试三种配置格式
            # 格式1：明确指定监听地址 0.0.0.0
            local node="http://${user}:${pass}@0.0.0.0:${real_port}"
        else
            # SOCKS5 代理 - 保持原有格式
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
    rm -rf "$CONFIG_DIR" "$GOST_BIN" "$SYSTEMD_SERVICE" "$EXPORT_FILE" "$SHORTCUT_PATH" "$SCRIPT_PATH"
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
    # 保存脚本到固定位置
    if [ ! -f "$SCRIPT_PATH" ]; then
        # 从 GitHub 下载或从当前运行的脚本复制
        if [[ "$0" == *"/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
            # 通过管道运行，从 GitHub 下载
            wget -q https://raw.githubusercontent.com/jikssha/Gost-Proxy-Manager/main/socks.sh -O "$SCRIPT_PATH" 2>/dev/null || {
                # 如果下载失败，尝试镜像
                wget -q https://mirror.ghproxy.com/https://raw.githubusercontent.com/jikssha/Gost-Proxy-Manager/main/socks.sh -O "$SCRIPT_PATH" 2>/dev/null
            }
        else
            # 从本地文件复制
            cp "$0" "$SCRIPT_PATH"
        fi
        chmod +x "$SCRIPT_PATH"
    fi
    
    # 创建快捷命令
    if [ ! -f "$SHORTCUT_PATH" ]; then
        cat > "$SHORTCUT_PATH" <<'EOF'
#!/bin/bash
exec /usr/local/bin/gost-manager.sh "$@"
EOF
        chmod +x "$SHORTCUT_PATH"
        echo ">>> 快捷指令 'gost' 已安装"
    fi
}

# --- 执行入口 ---
check_root
install_gost
install_shortcut
show_menu
