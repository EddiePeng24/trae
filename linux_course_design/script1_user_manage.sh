#!/bin/bash

# ============================================================
# 题目1：用户管理系统
# 功能：实现用户的创建、删除、密码修改、登录验证等功能
# 作者：[你的姓名]
# 学号：[你的学号]
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件路径
LOG_FILE="/var/log/user_management.log"

# 初始化日志文件
init_log() {
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi
}

# 写入日志函数
write_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | sudo tee -a "$LOG_FILE" > /dev/null
}

# ============================================
# 功能1：创建用户
# 逻辑说明：
#   1. 检查用户是否已存在，避免重复创建
#   2. 使用useradd命令创建系统用户
#   3. 设置用户主目录和默认shell
#   4. 记录操作日志
# 参数：$1-用户名, $2-密码(可选)
# ============================================
create_user() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}           创建新用户${NC}"
    echo -e "${BLUE}============================================${NC}"

    read -p "请输入要创建的用户名: " username

    # 检查用户名是否为空
    if [ -z "$username" ]; then
        echo -e "${RED}[错误] 用户名不能为空！${NC}"
        return 1
    fi

    # 检查用户是否已存在（核心逻辑）
    # id命令用于查看用户是否存在，$?为0表示存在
    if id "$username" &>/dev/null; then
        echo -e "${RED}[错误] 用户 '$username' 已存在！${NC}"
        write_log "尝试创建用户失败: 用户 $username 已存在"
        return 1
    fi

    # 输入密码
    read -s -p "请输入用户密码: " password
    echo ""
    read -s -p "请再次确认密码: " password2
    echo ""

    # 验证两次密码是否一致
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}[错误] 两次输入的密码不一致！${NC}"
        return 1
    fi

    # 创建用户（需要root权限）
    # -m参数：自动创建用户主目录
    # -s /bin/bash：指定用户的默认shell为bash
    echo -e "${YELLOW}[正在创建用户]...${NC}"
    sudo useradd -m -s /bin/bash "$username"

    # 检查用户创建是否成功
    if [ $? -eq 0 ]; then
        # 设置用户密码
        # echo "password" | passwd --stdin username 用于非交互式设置密码
        echo "$username:$password" | sudo chpasswd

        echo -e "${GREEN}[成功] 用户 '$username' 创建成功！${NC}"
        write_log "成功创建用户: $username"

        # 显示用户信息
        echo -e "\n${YELLOW}--- 用户信息 ---${NC}"
        id "$username"
        echo "主目录: /home/$username"
    else
        echo -e "${RED}[错误] 用户创建失败！${NC}"
        write_log "创建用户失败: $username"
        return 1
    fi
}

# ============================================
# 功能2：设置/修改用户密码
# 逻辑说明：
#   1. 验证目标用户是否存在
#   2. 提示输入新密码并进行确认
#   3. 使用chpasswd命令更新密码
#   4. 记录密码修改日志（不含明文密码）
# ============================================
change_password() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}         修改用户密码${NC}"
    echo -e "${BLUE}============================================${NC}"

    read -p "请输入要修改密码的用户名: " username

    # 检查用户是否存在
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}[错误] 用户 '$username' 不存在！${NC}"
        return 1
    fi

    # 输入新密码
    read -s -p "请输入新密码: " new_password
    echo ""
    read -s -p "请再次确认新密码: " confirm_password
    echo ""

    # 验证密码一致性
    if [ "$new_password" != "$confirm_password" ]; then
        echo -e "${RED}[错误] 两次输入的密码不一致！${NC}"
        return 1
    fi

    # 修改密码
    echo -e "${YELLOW}[正在修改密码]...${NC}"
    echo "$username:$new_password" | sudo chpasswd

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] 用户 '$username' 密码修改成功！${NC}"
        write_log "成功修改用户 $username 的密码"
    else
        echo -e "${RED}[错误] 密码修改失败！${NC}"
        return 1
    fi
}

# ============================================
# 功能3：用户登录验证（支持三次重试）
# 逻辑说明：
#   1. 提示输入用户名和密码
#   2. 使用/etc/shadow文件验证密码（模拟登录）
#   3. 最多允许尝试3次，超过则锁定
#   4. 登录成功显示欢迎信息
# ============================================
user_login() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}           用户登录系统${NC}"
    echo -e "${BLUE}============================================${NC}"

    read -p "请输入用户名: " username

    # 检查用户是否存在
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}[错误] 用户 '$username' 不存在！${NC}"
        return 1
    fi

    # 登录尝试次数限制（最多3次）
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}第 $attempt/$max_attempts 次尝试${NC}"
        read -s -p "请输入密码: " input_password
        echo ""

        # 验证密码逻辑
        # 将输入的密码与系统中的密码进行比对
        # 使用su命令测试密码是否正确（非root用户需要sudo）
        echo "$input_password" | sudo -S su - "$username" -c "echo 'success'" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}============================================${NC}"
            echo -e "${GREEN}       登录成功！欢迎回来，$username！${NC}"
            echo -e "${GREEN}============================================${NC}"
            write_log "用户 $username 成功登录系统 (第$attempt次尝试)"

            # 显示用户基本信息
            echo -e "\n${YELLOW}--- 当前用户信息 ---${NC}"
            echo "用户名: $username"
            echo "UID: $(id -u $username)"
            echo "组ID: $(id -g $username)"
            echo "主目录: $(grep "^$username:" /etc/passwd | cut -d: -f6)"
            echo "登录Shell: $(grep "^$username:" /etc/passwd | cut -d: -f7)"
            echo "登录时间: $(date '+%Y-%m-%d %H:%M:%S')"
            return 0
        else
            attempt=$((attempt + 1))
            remaining=$((max_attempts - attempt + 1))

            if [ $attempt -le $max_attempts ]; then
                echo -e "${RED}[失败] 密码错误！还剩 $remaining 次机会${NC}"
            fi
        fi
    done

    # 超过最大尝试次数
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}   登录失败！已超过最大尝试次数(3次)${NC}"
    echo -e "${RED}============================================${NC}"
    write_log "WARNING: 用户 $username 登录失败超过3次，账户可能被锁定"
    return 1
}

# ============================================
# 功能4：删除用户
# 逻辑说明：
#   1. 确认目标用户存在
#   2. 二次确认防止误删（安全机制）
#   3. 可选是否同时删除用户主目录
#   4. 执行删除并记录日志
# ============================================
delete_user() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${_blue}           删除用户${NC}"
    echo -e "${BLUE}============================================${NC}"

    read -p "请输入要删除的用户名: " username

    # 检查用户是否存在
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}[错误] 用户 '$username' 不存在！${NC}"
        return 1
    fi

    # 安全提示：禁止删除当前登录用户和root用户
    current_user=$(whoami)
    if [ "$username" = "root" ] || [ "$username" = "$current_user" ]; then
        echo -e "${RED}[错误] 不允许删除系统关键用户或当前用户！${NC}"
        return 1
    fi

    # 二次确认（重要安全措施）
    echo -e "${YELLOW}[警告] 此操作不可恢复！${NC}"
    read -p "确定要删除用户 '$username' 吗？(yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}已取消删除操作。${NC}"
        return 0
    fi

    # 询问是否删除主目录
    read -p "是否同时删除用户主目录？(y/n): " del_home

    echo -e "${YELLOW}[正在删除用户]...${NC}"

    if [ "$del_home" = "y" ] || [ "$del_home" = "Y" ]; then
        # -r参数：递归删除用户的主目录和邮件池
        sudo userdel -r "$username"
        home_msg="及主目录"
    else
        # 仅删除用户账号，保留主目录
        sudo userdel "$username"
        home_msg="(保留主目录)"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] 用户 '$username' 删除成功 $home_msg${NC}"
        write_log "成功删除用户: $username $home_msg"
    else
        echo -e "${RED}[错误] 用户删除失败！${NC}"
        write_log "删除用户失败: $username"
        return 1
    fi
}

# ============================================
# 辅助功能：查看所有用户列表
# 逻辑说明：
#   1. 读取/etc/passwd文件获取UID>=1000的普通用户
#   2. 格式化输出用户信息
# ============================================
list_users() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}          系统用户列表${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    # 打印表头
    printf "%-15s %-8s %-20s %-15s\n" "用户名" "UID" "主目录" "Shell"
    printf "%-15s %-8s %-20s %-15\n" "---------------" "--------" "--------------------" "---------------"

    # 使用awk过滤普通用户（UID >= 1000）
    # /etc/passwd格式: 用户名:x:UID:GID:注释:主目录:Shell
    awk -F: '$3 >= 1000 {printf "%-15s %-8s %-20s %-15s\n", $1, $3, $6, $7}' /etc/passwd

    echo ""
    echo -e "${YELLOW}共 $(awk -F: '$3 >= 1000' /etc/passwd | wc -l) 个普通用户${NC}"
}

# ============================================
# 主菜单界面
# 逻辑说明：
#   1. 使用循环实现持续运行直到选择退出
#   2. 使用case语句处理不同的功能选项
#   3. 提供清晰的菜单导航
# ============================================
main_menu() {
    init_log

    while true; do
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║       Linux 用户管理系统 v1.0            ║${NC}"
        echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}║   1. 创建用户                            ║${NC}"
        echo -e "${GREEN}║   2. 修改用户密码                        ║${NC}"
        echo -e "${GREEN}║   3. 用户登录验证                        ║${NC}"
        echo -e "${GREEN}║   4. 删除用户                            ║${NC}"
        echo -e "${GREEN}║   5. 查看用户列表                        ║${NC}"
        echo -e "${GREEN}║   0. 退出系统                            ║${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
        echo ""

        read -p "请选择功能 (0-5): " choice

        # case多分支选择结构
        case $choice in
            1)
                create_user
                ;;
            2)
                change_password
                ;;
            3)
                user_login
                ;;
            4)
                delete_user
                ;;
            5)
                list_users
                ;;
            0)
                echo -e "${YELLOW}感谢使用用户管理系统，再见！${NC}"
                write_log "用户退出系统"
                exit 0
                ;;
            *)
                echo -e "${RED}[错误] 无效的选择，请重新输入！${NC}"
                ;;
        esac

        # 暂停，等待用户按回车继续
        echo ""
        read -p "按回车键继续..."
    done
}

# 程序入口：执行主菜单函数
main_menu
