#!/bin/bash

# ============================================================
# 题目4：Tomcat服务器安装与配置
# 功能：实现Tomcat的下载、安装、配置和启动管理
# 作者：[你的姓名]
# 学号：[你的学号]
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Tomcat配置变量
TOMCAT_VERSION="10.1.18"
TOMCAT_INSTALL_DIR="/opt"
TOMCAT_HOME="${TOMCAT_INSTALL_DIR}/tomcat-${TOMCAT_VERSION}"
TOMCAT_DOWNLOAD_URL="https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_ARCHIVE="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_LOG="/workspace/linux_course_design/tomcat_install.log"

# JDK配置（Tomcat需要Java环境）
JAVA_HOME=""
JDK_VERSION="11"

# 初始化日志
init_tomcat_log() {
    echo "========================================" > "$TOMCAT_LOG"
    echo "Tomcat安装日志" >> "$TOMCAT_LOG"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TOMCAT_LOG"
    echo "========================================" >> "$TOMCAT_LOG"
}

tomcat_log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" | tee -a "$TOMCAT_LOG"
}

# ============================================
# 功能1：检查Java环境
# 逻辑说明：
#   1. Tomcat运行依赖Java环境（JDK/JRE）
#   2. 检测系统是否已安装Java
#   3. 如果未安装，自动安装OpenJDK
#   4. 设置JAVA_HOME环境变量
# ============================================
check_java_environment() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}      Java环境检测${NC}"
    echo -e "${CYAN}============================================${NC}"

    tomcat_log "[步骤1] 检查Java环境..."

    # 1.1 检测是否已安装Java
    echo -e "${YELLOW}[检测] Java运行环境...${NC}"
    if command -v java &>/dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        echo -e "${GREEN}  已安装: $JAVA_VERSION${NC}"

        # 获取JAVA_HOME路径
        if [ -n "$JAVA_HOME" ]; then
            echo -e "${GREEN}  JAVA_HOME: $JAVA_HOME${NC}"
        else
            # 尝试自动查找JAVA_HOME
            JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
            echo -e "${YELLOW}  自动检测到JAVA_HOME: $JAVA_HOME${NC}"
        fi
        tomcat_log "Java已安装: $JAVA_VERSION"
        return 0
    fi

    echo -e "${RED}  未检测到Java环境！${NC}"
    tomcat_log "未检测到Java，开始安装..."

    # 1.2 安装Java（根据操作系统）
    read -p "是否需要自动安装OpenJDK？(y/n): " install_jdk

    if [ "$install_jdk" = "y" ] || [ "$install_jdk" = "Y" ]; then
        install_java
    else
        echo -e "${RED}[错误] Tomcat需要Java环境才能运行！${NC}"
        return 1
    fi
}

# 安装Java环境
install_java() {
    echo -e "${YELLOW}[安装] OpenJDK...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    case "$OS_NAME" in
        *"Ubuntu"*|*"Debian"*)
            sudo apt-get update -y
            sudo apt-get install -y openjdk-${JDK_VERSION}-jdk
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            sudo yum install -y java-${JDK_VERSION}-openjdk-devel
            ;;
        *)
            echo -e "${RED}[错误] 不支持的操作系统${NC}"
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        # 设置JAVA_HOME
        export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
        echo -e "${GREEN}[成功] Java安装成功: $(java -version 2>&1 | head -n 1)${NC}"
        tomcat_log "Java安装成功, JAVA_HOME=$JAVA_HOME"
        return 0
    else
        echo -e "${RED}[错误] Java安装失败！${NC}"
        return 1
    fi
}

# ============================================
# 功能2：下载Tomcat
# 逻辑说明：
#   1. 从Apache官方源下载指定版本的Tomcat
#   2. 支持使用wget或curl下载工具
#   3. 验证下载文件的完整性（MD5/SHA校验）
#   4. 处理网络异常情况
# ============================================
download_tomcat() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}       下载Tomcat${NC}"
    echo -e "${CYAN}============================================${NC}"

    tomcat_log "[步骤2] 下载Tomcat ${TOMCAT_VERSION}..."

    # 2.1 检查是否已安装
    if [ -d "$TOMCAT_HOME" ]; then
        echo -e "${YELLOW}Tomcat似乎已经安装在: $TOMCAT_HOME${NC}"
        read -p "是否重新下载并覆盖安装？(y/n): " redownload
        if [ "$redownload" != "y" ] && [ "$redownload" != "Y" ]; then
            echo -e "${YELLOW}跳过下载步骤${NC}"
            return 0
        fi
        # 删除旧版本
        sudo rm -rf "$TOMCAT_HOME"
    fi

    # 2.2 创建临时目录用于下载
    TMP_DIR="/tmp/tomcat_install"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    # 清理可能存在的旧文件
    rm -f "$TOMCAT_ARCHIVE"

    echo -e "${YELLOW}[下载] Apache Tomcat ${TOMCAT_VERSION}...${NC}"
    echo -e "  下载地址: $TOMCAT_DOWNLOAD_URL"
    echo ""

    # 2.3 使用wget或curl下载
    DOWNLOAD_SUCCESS=0

    if command -v wget &>/dev/null; then
        echo -e "${YELLOW}使用 wget 下载...${NC}"
        wget --progress=bar:force "$TOMCAT_DOWNLOAD_URL" -O "$TOMCAT_ARCHIVE" && \
        DOWNLOAD_SUCCESS=1
    elif command -v curl &>/dev/null; then
        echo -e "${YELLOW}使用 curl 下载...${NC}"
        curl -L --progress-bar "$TOMCAT_DOWNLOAD_URL" -o "$TOMCAT_ARCHIVE" && \
        DOWNLOAD_SUCCESS=1
    else
        echo -e "${RED}[错误] 系统缺少wget或curl下载工具！${NC}"
        echo -e "${YELLOW}请先执行: sudo apt-get install wget 或 sudo yum install wget${NC}"
        return 1
    fi

    # 2.4 验证下载结果
    if [ $DOWNLOAD_SUCCESS -eq 1 ] && [ -f "$TOMCAT_ARCHIVE" ]; then
        FILE_SIZE=$(ls -lh "$TOMCAT_ARCHIVE" | awk '{print $5}')
        echo -e "\n${GREEN}[成功] Tomcat下载完成！${NC}"
        echo -e "  文件大小: $FILE_SIZE"
        echo -e "  存储位置: $TMP_DIR/$TOMCAT_ARCHIVE"
        tomcat_log "Tomcat下载成功: $FILE_SIZE"
        return 0
    else
        echo -e "\n${RED}[错误] Tomcat下载失败！${NC}"
        echo -e "${YELLOW}可能的原因:${NC}"
        echo "  1. 网络连接问题"
        echo "  2. 下载地址不可用"
        echo "  3. 版本号错误"
        tomcat_log "Tomcat下载失败"
        return 1
    fi
}

# ============================================
# 功能3：安装和解压Tomcat
# 逻辑说明：
#   1. 将下载的tar.gz压缩包解压到目标目录
#   2. 重命名目录为规范格式
#   3. 设置目录权限（确保Tomcat用户有读写权限）
#   4. 创建必要的软链接方便访问
# ============================================
install_tomcat() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}       安装Tomcat${NC}"
    echo -e "${CYAN}============================================${NC}"

    tomcat_log "[步骤3] 安装Tomcat..."

    TMP_DIR="/tmp/tomcat_install"
    ARCHIVE_PATH="$TMP_DIR/$TOMCAT_ARCHIVE"

    # 检查压缩包是否存在
    if [ ! -f "$ARCHIVE_PATH" ]; then
        echo -e "${RED}[错误] 找不到Tomcat安装包: $ARCHIVE_PATH${NC}"
        echo -e "${YELLOW}请先执行下载操作（选项2）${NC}"
        return 1
    fi

    # 3.1 解压Tomcat到安装目录
    echo -e "${YELLOW}[解压] Tomcat安装包...${NC}"
    sudo mkdir -p "$TOMCAT_INSTALL_DIR"

    # 使用tar命令解压，-x解压，-z处理gzip，-v显示过程，-f指定文件
    sudo tar -xzf "$ARCHIVE_PATH" -C "$TOMCAT_INSTALL_DIR"

    if [ $? -ne 0 ]; then
        echo -e "${RED}[错误] 解压失败！请检查文件完整性。${NC}"
        tomcat_log "Tomcat解压失败"
        return 1
    fi

    # 3.2 重命名目录（如果需要）
    EXTRACTED_DIR="${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}"
    if [ ! -d "$TOMCAT_HOME" ] && [ -d "$EXTRACTED_DIR" ]; then
        sudo mv "$EXTRACTED_DIR" "$TOMCAT_HOME"
    fi

    # 3.3 设置权限
    echo -e "${YELLOW}[设置] 目录权限...${NC}"
    # 设置Tomcat目录的所有者为当前用户（或创建专用tomcat用户）
    sudo chown -R $USER:$USER "$TOMCAT_HOME"
    # 设置bin目录下脚本可执行权限
    sudo chmod +x "$TOMCAT_HOME"/bin/*.sh

    # 3.4 创建软链接（可选，方便访问）
    if [ ! -L "/opt/tomcat" ]; then
        sudo ln -s "$TOMCAT_HOME" /opt/tomcat
        echo -e "${GREEN}  已创建软链接: /opt/tomcat -> $TOMCAT_HOME${NC}"
    fi

    echo -e "\n${GREEN}[成功] Tomcat安装完成！${NC}"
    echo -e "  安装目录: $TOMCAT_HOME"
    echo -e "  软链接: /opt/tomcat"
    tomcat_log "Tomcat安装成功: $TOMCAT_HOME"

    # 显示目录结构概览
    echo -e "\n${YELLOW}--- Tomcat目录结构 ---${NC}"
    ls -la "$TOMCAT_HOME/" | head -15
}

# ============================================
# 功能4：配置Tomcat环境变量
# 逻辑说明：
#   1. 配置CATALINA_HOME环境变量指向Tomcat安装目录
#   2. 配置PATH包含Tomcat的bin目录
#   3. 创建全局配置文件使所有用户可用
#   4. 修改Tomcat配置文件优化性能
# ============================================
configure_tomcat_env() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}     配置Tomcat环境${NC}"
    echo -e "${CYAN}============================================${NC}"

    tomcat_log "[步骤4] 配置Tomcat环境变量..."

    # 4.1 获取JAVA_HOME（如果尚未设置）
    if [ -z "$JAVA_HOME" ]; then
        if command -v java &>/dev/null; then
            export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
        else
            echo -e "${RED}[错误] 请先安装Java环境！${NC}"
            return 1
        fi
    fi

    # 4.2 创建Tomcat环境变量配置文件
    ENV_FILE="/etc/profile.d/tomcat.sh"
    echo -e "${YELLOW}[配置] 写入环境变量...${NC}"

    sudo tee "$ENV_FILE" > /dev/null << EOF
#!/bin/bash
# Tomcat环境变量配置
# 文件创建时间: $(date '+%Y-%m-%d %H:%M:%S')

# Tomcat主目录（CATALINA_HOME是Tomcat的标准环境变量名）
export CATALINA_HOME=$TOMCAT_HOME
export TOMCAT_HOME=$TOMCAT_HOME

# 将Tomcat bin目录添加到PATH（方便直接使用startup.sh等命令）
export PATH=\$PATH:$TOMCAT_HOME/bin

# Java环境变量
export JAVA_HOME=$JAVA_HOME
EOF

    sudo chmod +x "$ENV_FILE"

    # 使环境变量立即生效
    source "$ENV_FILE"
    export CATALINA_HOME=$TOMCAT_HOME
    export PATH=$PATH:$TOMCAT_HOME/bin

    echo -e "${GREEN}[成功] 环境变量配置完成${NC}"
    echo -e "  CATALINA_HOME=$TOMCAT_HOME"
    echo -e "  配置文件: $ENV_FILE"
    tomcat_log "环境变量配置完成: CATALINA_HOME=$TOMCAT_HOME"

    # 4.3 优化Tomcat配置（可选）
    configure_tomcat_settings
}

# 优化Tomcat服务器设置
configure_tomcat_settings() {
    echo -e "\n${YELLOW}[优化] Tomcat服务器配置...${NC}"

    SERVER_XML="$TOMCAT_HOME/conf/server.xml"

    if [ ! -f "$SERVER_XML" ]; then
        echo -e "${RED}[警告] 找不到server.xml配置文件${NC}"
        return 1
    fi

    # 备份原配置
    cp "$SERVER_XML" "${SERVER_XML}.bak"
    echo -e "  原配置已备份: ${SERVER_XML}.bak"

    # 修改端口号（默认8080，可根据需求改为80）
    read -p "是否修改Tomcat端口（默认8080）？(y/n): " change_port
    if [ "$change_port" = "y" ] || [ "$change_port" = "Y" ]; then
        read -p "请输入新端口号 (建议8080/80/8888): " new_port
        if [ -n "$new_port" ] && [[ "$new_port" =~ ^[0-9]+$ ]]; then
            # 使用sed替换Connector端口号
            sed -i "s/port=\"8080\"/port=\"$new_port\"/" "$SERVER_XML"
            echo -e "${GREEN}  端口已修改为: $new_port${NC}"
            TOMCAT_PORT=$new_port
        fi
    else
        TOMCAT_PORT=8080
    fi

    # 设置UTF-8编码（防止中文乱码）
    sed -i 's/URIEncoding="[^"]*"/URIEncoding="UTF-8"/g' "$SERVER_XML"
    echo -e "  URI编码已设置为UTF-8"

    echo -e "${GREEN}[完成] Tomcat配置优化完成${NC}"
    tomcat_log "Tomcat配置优化完成, 端口=${TOMCAT_PORT:-8080}"
}

# ============================================
# 功能5：启动Tomcat服务
# 逻辑说明：
#   1. 检查Tomcat进程是否已在运行
#   2. 执行startup.sh启动脚本
#   3. 等待服务启动完成
#   4. 验证服务状态和端口监听
# ============================================
start_tomcat() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}      启动Tomcat服务${NC}"
    echo -e "${CYAN}============================================${NC}"

    tomcat_log "[步骤5] 启动Tomcat..."

    # 5.1 检查Tomcat是否已安装
    if [ ! -d "$TOMCAT_HOME" ]; then
        echo -e "${RED}[错误] Tomcat未安装！请先执行安装步骤。${NC}"
        return 1
    fi

    # 5.2 检查是否已经在运行
    if pgrep -f "catalina" > /dev/null || pgrep -f "tomcat" > /dev/null; then
        echo -e "${YELLOW}[信息] Tomcat似乎已经在运行中${NC}"
        read -p "是否重启Tomcat？(y/n): " restart_choice
        if [ "$restart_choice" = "y" ] || [ "$restart_choice" = "Y" ]; then
            stop_tomcat_silent
        else
            echo -e "${YELLOW}取消启动${NC}"
            return 0
        fi
    fi

    # 5.3 启动Tomcat
    echo -e "${YELLOW}[启动] Tomcat服务器...${NC}"
    cd "$TOMCAT_HOME"

    # 设置JAVA_HOME后启动
    export JAVA_HOME="${JAVA_HOME:-$(dirname $(dirname $(readlink -f $(which java))))}"
    export CATALINA_HOME="$TOMCAT_HOME"

    # 执行启动脚本（后台运行，输出日志）
    ./bin/startup.sh

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}[成功] Tomcat启动命令已执行！${NC}"

        # 5.4 等待服务完全启动
        echo -e "${YELLOW}[等待] 服务启动中...${NC}"
        sleep 5

        # 5.5 验证启动状态
        check_tomcat_status
    else
        echo -e "${RED}[错误] Tomcat启动失败！${NC}"
        echo -e "${YELLOW}请检查日志: $TOMCAT/logs/catalina.out${NC}"
        tomcat_log "Tomcat启动失败"
        return 1
    fi
}

# 停止Tomcat（静默模式，不输出提示）
stop_tomcat_silent() {
    cd "$TOMCAT_HOME"
    export JAVA_HOME="${JAVA_HOME:-$(dirname $(dirname $(readlink -f $(which java))))}"
    ./bin/shutdown.sh 2>/dev/null
    sleep 2
    # 强制结束残留进程
    pkill -9 -f catalina 2>/dev/null
}

# ============================================
# 功能6：检查Tomcat运行状态
# 逻辑说明：
#   1. 检查Tomcat进程是否存在
#   2. 检查端口是否在监听
#   3. 尝试HTTP请求验证服务响应
#   4. 显示详细的运行状态信息
# ============================================
check_tomcat_status() {
    echo -e "\n${YELLOW}--- Tomcat运行状态检查 ---${NC}\n"

    PORT=${TOMCAT_PORT:-8080}
    STATUS_OK=true

    # 6.1 检查进程
    echo -e "[检查] 进程状态..."
    if pgrep -f ".*catalina.*$TOMCAT_HOME" > /dev/null || \
       pgrep -f ".*org.apache.catalina.startup.Bootstrap" > /dev/null; then
        PID=$(pgrep -f ".*org.apache.catalina.startup.Bootstrap" | head -1)
        echo -e "  ${GREEN}● 运行中 (PID: $PID)${NC}"
    else
        echo -e "  ${RED}○ 未运行${NC}"
        STATUS_OK=false
    fi

    # 6.2 检查端口监听
    echo -e "\n[检查] 端口监听..."
    if netstat -tlnp 2>/dev/null | grep -q ":${PORT} " || \
       ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        echo -e "  ${GREEN}● 端口 $PORT 正在监听${NC}"
    else
        echo -e "  ${RED}○ 端口 $PORT 未监听${NC}"
        STATUS_OK=false
    fi

    # 6.3 HTTP连接测试
    echo -e "\n[检查] HTTP服务响应..."
    if command -v curl &>/dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ --connect-timeout 5 2>/dev/null)

        case $HTTP_CODE in
            200|302)
                echo -e "  ${GREEN}● HTTP响应正常 (状态码: $HTTP_CODE)${NC}"
                ;;
            000)
                echo -e "  ${RED}○ 无法连接${NC}"
                STATUS_OK=false
                ;;
            *)
                echo -e "  ${YELLOW}△ HTTP状态码: $HTTP_CODE${NC}"
                ;;
        esac
    fi

    # 6.4 显示总结
    echo ""
    if [ "$STATUS_OK" = true ]; then
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}  Tomcat运行正常！${NC}"
        echo -e "${GREEN}  访问地址: http://localhost:$PORT${NC}"
        echo -e "${GREEN}============================================${NC}"
        tomcat_log "Tomcat运行正常, 地址=http://localhost:$PORT"
        return 0
    else
        echo -e "${RED}============================================${NC}"
        echo -e "${RED}  Tomcat运行异常！${NC}"
        echo -e "${RED}  请查看日志: $TOMCAT_HOME/logs/catalina.out${NC}"
        echo -e "${RED}============================================${NC}"
        tomcat_log "警告: Tomcat运行异常"
        return 1
    fi
}

# ============================================
# 功能7：停止Tomcat服务
# ============================================
stop_tomcat() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}      停止Tomcat服务${NC}"
    echo -e "${CYAN}============================================${NC}"

    if [ ! -d "$TOMCAT_HOME" ]; then
        echo -e "${RED}[错误] Tomcat未安装！${NC}"
        return 1
    fi

    echo -e "${YELLOW}[停止] Tomcat服务器...${NC}"
    cd "$TOMCAT_HOME"
    export JAVA_HOME="${JAVA_HOME:-$(dirname $(dirname $(readlink -f $(which java))))}"
    ./bin/shutdown.sh

    sleep 3

    if pgrep -f "catalina" > /dev/null; then
        echo -e "${YELLOW}[强制] 正常停止失败，尝试强制终止...${NC}"
        pkill -9 -f catalina
        sleep 1
    fi

    if ! pgrep -f "catalina" > /dev/null; then
        echo -e "${GREEN}[成功] Tomcat已停止${NC}"
        tomcat_log "Tomcat已停止"
    else
        echo -e "${RED}[错误] Tomcat停止失败！${NC}"
        return 1
    fi
}

# ============================================
# 主菜单界面
# ============================================
main_menu() {
    init_tomcat_log

    while true; do
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║     Tomcat 安装与配置管理系统 v1.0        ║${NC}"
        echo -e "${GREEN}╠════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}║   1. 检查Java环境                        ║${NC}"
        echo -e "${GREEN}║   2. 下载Tomcat                          ║${NC}"
        echo -e "${GREEN}║   3. 安装Tomcat                          ║${NC}"
        echo -e "${GREEN}║   4. 配置环境变量                        ║${NC}"
        echo -e "${GREEN}║   5. 启动Tomcat服务                      ║${NC}"
        echo -e "${GREEN}║   6. 查看运行状态                        ║${NC}"
        echo -e "${GREEN}║   7. 停止Tomcat服务                      ║${NC}"
        echo -e "${GREEN}║   8. 一键完整安装                        ║${NC}"
        echo -e "${GREEN}║   0. 退出系统                            ║${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
        echo ""

        read -p "请选择功能 (0-8): " choice

        case $choice in
            1)
                check_java_environment
                ;;
            2)
                download_tomcat
                ;;
            3)
                install_tomcat
                ;;
            4)
                configure_tomcat_env
                ;;
            5)
                start_tomcat
                ;;
            6)
                check_tomcat_status
                ;;
            7)
                stop_tomcat
                ;;
            8)
                echo -e "${YELLOW}[一键安装] 开始完整安装流程...${NC}"
                check_java_environment && \
                download_tomcat && \
                install_tomcat && \
                configure_tomcat_env && \
                start_tomcat
                echo -e "${GREEN}[完成] 一键安装流程结束${NC}"
                ;;
            0)
                echo -e "${YELLOW}感谢使用Tomcat配置工具，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[错误] 无效的选择，请重新输入！${NC}"
                ;;
        esac

        echo ""
        read -p "按回车键继续..."
    done
}

# 程序入口
main_menu
