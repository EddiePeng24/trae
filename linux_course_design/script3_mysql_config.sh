#!/bin/bash

# ============================================================
# 题目3：MySQL数据库安装与配置
# 功能：实现MySQL的自动安装、配置、初始化和数据操作
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

# MySQL配置变量
MYSQL_ROOT_PASSWORD="Root@123456"
MYSQL_VERSION="8.0"
MYSQL_INSTALL_LOG="/workspace/linux_course_design/mysql_install.log"
MYSQL_DATA_DIR="/var/lib/mysql"

# 初始化日志文件
init_mysql_log() {
    echo "========================================" > "$MYSQL_INSTALL_LOG"
    echo "MySQL安装日志" >> "$MYSQL_INSTALL_LOG"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$MYSQL_INSTALL_LOG"
    echo "========================================" >> "$MYSQL_INSTALL_LOG"
}

# 写入日志
mysql_log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" | tee -a "$MYSQL_INSTALL_LOG"
}

# ============================================
# 功能1：检查系统环境
# 逻辑说明：
#   1. 检测操作系统类型（CentOS/Ubuntu/其他）
#   2. 检查是否已安装MySQL（避免重复安装）
#   3. 检查系统资源（内存、磁盘空间）
#   4. 检查网络连接状态
# ============================================
check_environment() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}       系统环境检测${NC}"
    echo -e "${CYAN}============================================${NC}"

    mysql_log "[步骤1] 开始系统环境检测..."

    # 1.1 检测操作系统类型
    echo -e "\n${YELLOW}[检测] 操作系统类型...${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
        echo -e "${GREEN}  操作系统: $OS_NAME $OS_VERSION${NC}"
        mysql_log "操作系统: $OS_NAME $OS_VERSION"
    else
        echo -e "${RED}  [错误] 无法识别操作系统！${NC}"
        return 1
    fi

    # 1.2 检查是否已安装MySQL
    echo -e "${YELLOW}[检测] MySQL安装状态...${NC}"
    if command -v mysql &>/dev/null; then
        MYSQL_INSTALLED_VERSION=$(mysql --version)
        echo -e "${YELLOW}  MySQL已安装: $MYSQL_INSTALLED_VERSION${NC}"
        mysql_log "MySQL已安装: $MYSQL_INSTALLED_VERSION"

        read -p "是否需要重新安装MySQL？(y/n): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            echo -e "${YELLOW}跳过安装，直接进行配置...${NC}"
            return 0
        fi
    else
        echo -e "${GREEN}  MySQL未安装，准备进行安装${NC}"
        mysql_log "MySQL未安装，将进行全新安装"
    fi

    # 1.3 检查系统内存（MySQL建议至少512MB）
    echo -e "${YELLOW}[检测] 系统内存...${NC}"
    total_mem=$(free -m | awk '/Mem:/ {print $2}')
    echo -e "${GREEN}  总内存: ${total_mem}MB${NC}"
    if [ "$total_mem" -lt 512 ]; then
        echo -e "${RED}  [警告] 内存不足512MB，可能影响MySQL性能${NC}"
        mysql_log "警告: 内存不足 (${total_mem}MB)"
    fi
    mysql_log "系统内存: ${total_mem}MB"

    # 1.4 检查磁盘空间（MySQL安装至少需要500MB）
    echo -e "${YELLOW}[检测] 磁盘空间...${NC}"
    available_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    echo -e "${GREEN}  可用空间: ${available_space}GB${NC}"
    if [ "$available_space" -lt 1 ]; then
        echo -e "${RED}  [错误] 磁盘空间不足！${NC}"
        return 1
    fi
    mysql_log "可用磁盘空间: ${available_space}GB"

    # 1.5 测试网络连接
    echo -e "${YELLOW}[检测] 网络连接...${NC}"
    if ping -c 1 -W 3 mirrors.aliyun.com &>/dev/null; then
        echo -e "${GREEN}  网络连接正常${NC}"
        mysql_log "网络连接: 正常"
    else
        echo -e "${RED}  [警告] 网络连接异常，可能影响软件下载${NC}"
        mysql_log "警告: 网络连接异常"
    fi

    echo -e "\n${GREEN}[完成] 环境检测通过${NC}"
    return 0
}

# ============================================
# 功能2：下载并安装MySQL
# 逻辑说明：
#   1. 根据操作系统类型选择对应的包管理器
#   2. 配置MySQL官方YUM/APT源（获取最新版本）
#   3. 使用包管理器下载并安装MySQL Server
#   4. 处理依赖关系和可能的冲突
# ============================================
install_mysql() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}      安装MySQL服务器${NC}"
    echo -e "${CYAN}============================================${NC}"

    mysql_log "[步骤2] 开始安装MySQL..."

    # 根据操作系统类型执行不同的安装命令
    case "$OS_NAME" in
        *"Ubuntu"*|*"Debian"*)
            install_mysql_ubuntu
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            install_mysql_centos
            ;;
        *)
            echo -e "${RED}[错误] 不支持的操作系统: $OS_NAME${NC}"
            echo -e "${YELLOW}请手动安装MySQL后继续配置${NC}"
            return 1
            ;;
    esac
}

# Ubuntu/Debian系统的MySQL安装
install_mysql_ubuntu() {
    echo -e "${YELLOW}[Ubuntu/Debian] 更新软件源...${NC}"

    # 更新apt缓存
    sudo apt-get update -y

    echo -e "${YELLOW}[正在安装MySQL Server...]${NC}"
    mysql_log "使用apt安装MySQL..."

    # 使用DEBIAN_FRONTEND=noninteractive避免交互式提示
    # 设置root密码为预设值
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mysql-server mysql-client

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] MySQL安装成功！${NC}"
        mysql_log "MySQL安装成功 (Ubuntu/Debian)"
    else
        echo -e "${RED}[错误] MySQL安装失败！${NC}"
        mysql_log "MySQL安装失败"
        return 1
    fi
}

# CentOS/RHEL系统的MySQL安装
install_mysql_centos() {
    echo -e "${YELLOW}[CentOS/RHEL] 配置MySQL YUM源...${NC}"

    # 下载并安装MySQL官方仓库
    # 对于CentOS 7+，可以使用社区版MySQL
    if [ ! -f /etc/yum.repos.d/mysql-community.repo ]; then
        # 安装MySQL仓库（以MySQL 8.0为例）
        sudo yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm 2>/dev/null || \
        {
            echo -e "${YELLOW}尝试使用系统默认源安装MariaDB...${NC}"
            # 如果无法访问MySQL官方源，使用系统自带的MariaDB替代
            sudo yum install -y mariadb-server mariadb
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[成功] MariaDB（MySQL兼容）安装成功！${NC}"
                mysql_log "MariaDB安装成功 (CentOS)"
                return 0
            fi
        }
    fi

    echo -e "${YELLOW}[正在安装MySQL Server...]${NC}"
    mysql_log "使用yum安装MySQL..."

    # 安装MySQL Server
    sudo yum install -y mysql-server mysql

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] MySQL安装成功！${NC}"
        mysql_log "MySQL安装成功 (CentOS)"
    else
        echo -e "${RED}[错误] MySQL安装失败！${NC}"
        mysql_log "MySQL安装失败"
        return 1
    fi
}

# ============================================
# 功能3：配置MySQL环境变量
# 逻辑说明：
#   1. 将MySQL的bin目录添加到PATH环境变量
#   2. 创建/etc/profile.d/mysql.sh使所有用户生效
#   3. 配置MySQL客户端默认字符集为UTF-8
#   4. 设置MySQL服务开机自启动
# ============================================
configure_mysql_env() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}     配置MySQL环境${NC}"
    echo -e "${CYAN}============================================${NC}"

    mysql_log "[步骤3] 配置MySQL环境变量..."

    # 3.1 获取MySQL安装路径
    if command -v mysql &>/dev/null; then
        MYSQL_BIN_DIR=$(dirname $(which mysql))
        echo -e "${GREEN}MySQL路径: $MYSQL_BIN_DIR${NC}"
    else
        MYSQL_BIN_DIR="/usr/bin"
        echo -e "${YELLOW}使用默认MySQL路径: $MYSQL_BIN_DIR${NC}"
    fi

    # 3.2 创建全局环境变量配置文件
    # 写入/etc/profile.d/使得对所有用户生效，登录时自动加载
    ENV_FILE="/etc/profile.d/mysql.sh"

    echo -e "${YELLOW}[配置] 设置环境变量...${NC}"
    sudo tee "$ENV_FILE" > /dev/null << EOF
#!/bin/bash
# MySQL环境变量配置
# 文件创建时间: $(date '+%Y-%m-%d %H:%M:%S')

# 将MySQL添加到PATH
export PATH=\$PATH:$MYSQL_BIN_DIR:$MYSQL_BIN_DIR/../sbin

# MySQL相关环境变量
export MYSQL_HOME=${MYSQL_BIN_DIR%/bin}
export DATADIR=$MYSQL_DATA_DIR

# MySQL客户端默认选项
export MYSQL_PAGER=less
export MYSQL_EDITOR=vim
EOF

    # 设置文件可执行权限
    sudo chmod +x "$ENV_FILE"

    # 3.3 使环境变量立即生效
    source "$ENV_FILE"
    export PATH=$PATH:$MYSQL_BIN_DIR

    echo -e "${GREEN}[成功] 环境变量配置完成${NC}"
    echo -e "  配置文件: $ENV_FILE"
    mysql_log "环境变量配置完成: $ENV_FILE"

    # 3.4 配置MySQL服务开机自启动
    echo -e "${YELLOW}[配置] 设置MySQL开机自启...${NC}"
    sudo systemctl enable mysqld 2>/dev/null || sudo systemctl enable mariadb 2>/dev/null
    echo -e "${GREEN}[成功] MySQL已设置为开机自启动${NC}"
    mysql_log "MySQL已设置开机自启动"
}

# ============================================
# 功能4：初始化MySQL并设置root密码
# 逻辑说明：
#   1. 启动MySQL服务
#   2. 执行安全初始化脚本（mysql_secure_installation）
#   3. 设置root账户密码
#   4. 移除匿名用户和测试数据库
# ============================================
initialize_mysql() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}    初始化MySQL配置${NC}"
    echo -e "${CYAN}============================================${NC}"

    mysql_log "[步骤4] 初始化MySQL..."

    # 4.1 启动MySQL服务
    echo -e "${YELLOW}[启动] MySQL服务...${NC}"
    sudo systemctl start mysqld 2>/dev/null || sudo systemctl start mariadb 2>/dev/null

    sleep 3  # 等待服务完全启动

    # 检查服务状态
    if sudo systemctl is-active --quiet mysqld 2>/dev/null || \
       sudo systemctl is-active --quiet mariadb 2>/dev/null; then
        echo -e "${GREEN}[成功] MySQL服务已启动${NC}"
        mysql_log "MySQL服务启动成功"
    else
        echo -e "${RED}[错误] MySQL服务启动失败！${NC}"
        mysql_log "MySQL服务启动失败"
        return 1
    fi

    # 4.2 获取初始密码（MySQL 8.0首次安装会生成临时密码）
    INITIAL_PASSWORD=""
    if [ -f /var/log/mysqld.log ]; then
        INITIAL_PASSWORD=$(sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
        if [ -n "$INITIAL_PASSWORD" ]; then
            echo -e "${YELLOW}[信息] 获取到初始临时密码${NC}"
        fi
    fi

    # 4.3 设置root密码
    echo -e "${YELLOW}[配置] 设置root账户密码...${NC}"

    if [ -n "$INITIAL_PASSWORD" ]; then
        # MySQL 8.0：使用临时密码登录后修改
        mysql -u root -p"$INITIAL_PASSWORD" --connect-expired-password \
            -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';" 2>/dev/null
    else
        # MariaDB或无密码情况
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';" 2>/dev/null || \
        mysqladmin -u root password "$MYSQL_ROOT_PASSWORD" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] root密码设置成功${NC}"
        echo -e "  root密码: $MYSQL_ROOT_PASSWORD"
        mysql_log "root密码设置成功"
    else
        echo -e "${YELLOW}[信息] 尝试其他方式设置密码...${NC}"
        # 备用方案：直接更新mysql.user表
        sudo mysqld --skip-grant-tables --user=mysql &
        sleep 2
        mysql -u root -e "UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || \
        mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_ROOT_PASSWORD');" 2>/dev/null
        sudo pkill -9 mysqld
        sudo systemctl start mysqld 2>/dev/null || sudo systemctl start mariadb 2>/dev/null
        mysql_log "使用备用方式设置密码"
    fi

    # 4.4 安全加固（移除测试数据）
    echo -e "${YELLOW}[安全] 执行安全配置...${NC}"
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null << EOF
-- 删除匿名用户
DELETE FROM mysql.user WHERE User='';

-- 禁止root远程登录（可选，根据需求调整）
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- 删除测试数据库
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- 刷新权限
FLUSH PRIVILEGES;
EOF

    echo -e "${GREEN}[完成] MySQL安全配置完成${NC}"
    mysql_log "MySQL安全配置完成"
}

# ============================================
# 功能5：登录MySQL验证
# 逻辑说明：
#   1. 使用设置的root密码尝试连接MySQL
#   2. 显示MySQL版本信息和当前状态
#   3. 显示现有数据库列表
# ============================================
login_mysql_test() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}     登录MySQL测试${NC}"
    echo -e "${CYAN}============================================${NC}"

    mysql_log "[步骤5] 测试MySQL登录..."

    echo -e "${YELLOW}[测试] 连接MySQL服务器...${NC}"

    # 尝试连接MySQL
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" 2>/dev/null; then
        echo -e "\n${GREEN}[成功] MySQL登录成功！${NC}"
        mysql_log "MySQL登录测试成功"

        # 显示MySQL版本信息
        echo -e "\n${YELLOW}--- MySQL版本信息 ---${NC}"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION() AS 'MySQL版本';" 2>/dev/null

        # 显示当前用户
        echo -e "\n${YELLOW}--- 当前用户 ---${NC}"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT USER() AS '当前用户';" 2>/dev/null

        # 显示端口信息
        echo -e "\n${YELLOW}--- 服务状态 ---${NC}"
        sudo systemctl status mysqld 2>/dev/null | head -5 || sudo systemctl status mariadb 2>/dev/null | head -5

        return 0
    else
        echo -e "${RED}[错误] MySQL登录失败！请检查密码和服务状态。${NC}"
        mysql_log "MySQL登录测试失败"
        return 1
    fi
}

# ============================================
# 功能6：创建数据库和表结构
# 逻辑说明：
#   1. 创建课程设计示例数据库（如学生管理系统）
#   2. 设计合理的表结构（学生表、课程表、成绩表）
#   3. 设置主键、外键约束
#   4. 插入示例数据用于演示
# ============================================
create_database_and_tables() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}   创建数据库和表${NC}"
    echo -e "${CYAN}============================================${NC}"

    mysql_log "[步骤6] 创建数据库和表结构..."

    # 数据库名称
    DB_NAME="student_management"

    echo -e "${YELLOW}[创建] 数据库: $DB_NAME${NC}"

    # 执行SQL脚本创建数据库和表
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null << EOSQL
-- ============================================
-- 学生管理系统数据库
-- 创建时间: $(date '+%Y-%m-%d %H:%M:%S')
-- ============================================

-- 如果数据库已存在则先删除（用于重新初始化）
DROP DATABASE IF EXISTS $DB_NAME;

-- 创建数据库，指定UTF-8字符集
CREATE DATABASE $DB_NAME
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 使用该数据库
USE $DB_NAME;

-- ------------------------------------------
-- 表1: students（学生信息表）
-- 字段说明:
--   student_id: 学号（主键，自增）
--   name: 姓名
--   gender: 性别
--   age: 年龄
--   class_name: 班级
--   phone: 联系电话
--   create_time: 记录创建时间
-- ------------------------------------------
CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '学号',
    name VARCHAR(50) NOT NULL COMMENT '姓名',
    gender ENUM('男', '女') DEFAULT '男' COMMENT '性别',
    age INT CHECK (age BETWEEN 15 AND 30) COMMENT '年龄',
    class_name VARCHAR(50) COMMENT '班级',
    phone VARCHAR(20) COMMENT '联系电话',
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生信息表';

-- ------------------------------------------
-- 表2: courses（课程信息表）
-- 字段说明:
--   course_id: 课程编号（主键）
--   course_name: 课程名称
--   credit: 学分
--   teacher: 授课教师
-- ------------------------------------------
CREATE TABLE courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '课程编号',
    course_name VARCHAR(100) NOT NULL COMMENT '课程名称',
    credit DECIMAL(3,1) NOT NULL DEFAULT 1.0 COMMENT '学分',
    teacher VARCHAR(50) NOT NULL COMMENT '授课教师'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='课程信息表';

-- ------------------------------------------
-- 表3: scores（成绩表）
-- 字段说明:
--   score_id: 成绩记录ID（主键）
--   student_id: 学号（外键关联students表）
--   course_id: 课程编号（外键关联courses表）
--   score: 分数（0-100）
--   exam_time: 考试日期
-- 外键约束确保数据完整性
-- ------------------------------------------
CREATE TABLE scores (
    score_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '记录ID',
    student_id INT NOT NULL COMMENT '学号',
    course_id INT NOT NULL COMMENT '课程编号',
    score DECIMAL(5,2) CHECK (score BETWEEN 0 AND 100) COMMENT '分数',
    exam_time DATE COMMENT '考试日期',

    -- 外键约束
    CONSTRAINT fk_student FOREIGN KEY (student_id)
        REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_course FOREIGN KEY (course_id)
        REFERENCES courses(course_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成绩表';

EOSQL

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] 数据库 '$DB_NAME' 和表结构创建成功！${NC}"
        mysql_log "数据库 $DB_NAME 创建成功"
    else
        echo -e "${RED}[错误] 数据库创建失败！${NC}"
        mysql_log "数据库创建失败"
        return 1
    fi
}

# ============================================
# 功能7：插入示例数据
# 逻辑说明：
#   1. 向学生表插入多条学生记录
#   2. 向课程表插入课程数据
#   3. 向成绩表插入学生成绩
#   4. 验证数据插入结果
# ============================================
insert_sample_data() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}    插入示例数据${NC}"
    echo -e "${CYAN}============================================${NC}"

    mysql_log "[步骤7] 插入示例数据..."

    DB_NAME="student_management"

    echo -e "${YELLOW}[插入] 学生数据...${NC}"

    # 执行数据插入SQL
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$DB_NAME" 2>/dev/null << EOSQL
-- ============================================
-- 示例数据插入
-- ============================================

USE $DB_NAME;

-- 插入学生数据
INSERT INTO students (name, gender, age, class_name, phone) VALUES
    ('张三', '男', 20, '计算机2301', '13800138001'),
    ('李四', '男', 19, '计算机2301', '13800138002'),
    ('王五', '男', 21, '计算机2302', '13800138003'),
    ('赵六', '女', 20, '计算机2302', '13800138004'),
    ('钱七', '女', 19, '软件工程2301', '13800138005'),
    ('孙八', '男', 22, '软件工程2301', '13800138006');

-- 插入课程数据
INSERT INTO courses (course_name, credit, teacher) VALUES
    ('Linux系统开发', 3.5, '张老师'),
    ('数据库原理', 4.0, '李老师'),
    ('计算机网络', 3.0, '王老师'),
    ('Java程序设计', 4.0, '赵老师'),
    ('数据结构与算法', 3.5, '刘老师');

-- 插入成绩数据
INSERT INTO scores (student_id, course_id, score, exam_time) VALUES
    (1, 1, 92.50, '2024-01-15'),
    (1, 2, 88.00, '2024-01-16'),
    (1, 3, 76.50, '2024-01-17'),
    (2, 1, 85.00, '2024-01-15'),
    (2, 2, 91.50, '2024-01-16'),
    (2, 4, 78.00, '2024-01-18'),
    (3, 1, 95.00, '2024-01-15'),
    (3, 3, 82.50, '2024-01-17'),
    (3, 5, 89.00, '2024-01-19'),
    (4, 2, 93.00, '2024-01-16'),
    (4, 4, 86.50, '2024-01-18'),
    (5, 1, 79.00, '2024-01-15'),
    (5, 5, 94.50, '2024-01-19'),
    (6, 2, 87.00, '2024-01-16'),
    (6, 3, 90.00, '2024-01-17');

EOSQL

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功] 示例数据插入成功！${NC}"
        mysql_log "示例数据插入成功"

        # 显示统计信息
        echo -e "\n${YELLOW}--- 数据统计 ---${NC}"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$DB_NAME" -e "
            SELECT 'students' AS '表名', COUNT(*) AS '记录数' FROM students
            UNION ALL
            SELECT 'courses', COUNT(*) FROM courses
            UNION ALL
            SELECT 'scores', COUNT(*) FROM scores;
        " 2>/dev/null

        # 显示部分数据预览
        echo -e "\n${YELLOW}--- 学生列表预览 ---${NC}"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$DB_NAME" -e "SELECT * FROM students LIMIT 5;" 2>/dev/null

    else
        echo -e "${RED}[错误] 数据插入失败！${NC}"
        mysql_log "数据插入失败"
        return 1
    fi
}

# ============================================
# 主菜单界面
# ============================================
main_menu() {
    init_mysql_log

    while true; do
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║     MySQL 安装与配置管理系统 v1.0         ║${NC}"
        echo -e "${GREEN}╠════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}║   1. 系统环境检测                        ║${NC}"
        echo -e "${GREEN}║   2. 下载安装MySQL                       ║${NC}"
        echo -e "${GREEN}║   3. 配置环境变量                        ║${NC}"
        echo -e "${GREEN}║   4. 初始化MySQL（设置root密码）          ║${NC}"
        echo -e "${GREEN}║   5. 登录MySQL测试                       ║${NC}"
        echo -e "${GREEN}║   6. 创建数据库和表                      ║${NC}"
        echo -e "${GREEN}║   7. 插入示例数据                        ║${NC}"
        echo -e "${GREEN}║   8. 一键完整安装                        ║${NC}"
        echo -e "${GREEN}║   0. 退出系统                            ║${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
        echo ""

        read -p "请选择功能 (0-8): " choice

        case $choice in
            1)
                check_environment
                ;;
            2)
                install_mysql
                ;;
            3)
                configure_mysql_env
                ;;
            4)
                initialize_mysql
                ;;
            5)
                login_mysql_test
                ;;
            6)
                create_database_and_tables
                ;;
            7)
                insert_sample_data
                ;;
            8)
                # 一键完整安装流程
                echo -e "${YELLOW}[一键安装] 开始完整安装流程...${NC}"
                check_environment && \
                install_mysql && \
                configure_mysql_env && \
                initialize_mysql && \
                login_mysql_test && \
                create_database_and_tables && \
                insert_sample_data
                echo -e "${GREEN}[完成] 一键安装流程结束${NC}"
                ;;
            0)
                echo -e "${YELLOW}感谢使用MySQL配置工具，再见！${NC}"
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
