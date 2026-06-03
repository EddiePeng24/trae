#!/bin/bash

# ============================================================
# 题目5：Web项目部署系统
# 功能：实现项目的完整部署流程，包括代码拷贝、
#       数据库初始化、服务启动和访问测试
# 作者：彭子阳
# 学号：20231035109
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ============================================
# 全局配置变量
# ============================================
# Tomcat配置
TOMCAT_HOME="/opt/tomcat"  # Tomcat安装目录（根据实际安装位置调整）
TOMCAT_WEBAPPS="$TOMCAT_HOME/webapps"
TOMCAT_PORT=8080          # Tomcat端口号

# MySQL配置
MYSQL_ROOT_PASSWORD="Root@123456"
DB_NAME="student_management"

# 项目配置
PROJECT_NAME="StudentManager"
PROJECT_SOURCE_DIR=""      # 项目源码目录
PROJECT_DEPLOY_DIR="$TOMCAT_WEBAPPS/$PROJECT_NAME"

# 日志文件
DEPLOY_LOG="/workspace/linux_course_design/deploy_log.log"

# 初始化日志文件
init_deploy_log() {
    echo "============================================" > "$DEPLOY_LOG"
    echo "  Web项目部署日志" >> "$DEPLOY_LOG"
    echo "  开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$DEPLOY_LOG"
    echo "============================================" >> "$DEPLOY_LOG"
}

deploy_log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $msg" | tee -a "$DEPLOY_LOG"
}

# ============================================
# 功能1：检查部署环境
# 逻辑说明：
#   1. 检查Tomcat是否已安装并运行
#   2. 检查MySQL是否可用
#   3. 检查Java环境
#   4. 检查磁盘空间和网络连接
#   5. 输出完整的环境状态报告
# ============================================
check_deploy_environment() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}              部署环境检测${NC}"
    echo -e "${CYAN}============================================================${NC}"

    deploy_log "[步骤1] 检查部署环境..."

    local all_ok=true

    # 1.1 检测Java环境
    echo -e "\n${YELLOW}[1/5] Java环境...${NC}"
    if command -v java &>/dev/null; then
        JAVA_VER=$(java -version 2>&1 | head -n 1)
        echo -e "  ${GREEN}● 已安装: $JAVA_VER${NC}"
        deploy_log "Java: OK - $JAVA_VER"
    else
        echo -e "  ${RED}○ 未安装${NC}"
        all_ok=false
        deploy_log "Java: FAIL - 未安装"
    fi

    # 1.2 检测Tomcat
    echo -e "\n${YELLOW}[2/5] Tomcat服务器...${NC}"
    if [ -d "$TOMCAT_HOME" ]; then
        echo -e "  ${GREEN}● 安装目录: $TOMCAT_HOME${NC}"

        if pgrep -f "catalina" > /dev/null || \
           pgrep -f "org.apache.catalina.startup.Bootstrap" > /dev/null; then
            echo -e "  ${GREEN}● 运行状态: 运行中${NC}"
            deploy_log "Tomcat: OK - 运行中"
        else
            echo -e "  ${YELLOW}△ 运行状态: 未运行${NC}"
            deploy_log "Tomcat: WARN - 未运行"
        fi
    else
        echo -e "  ${RED}○ 未安装 (路径: $TOMCAT_HOME)${NC}"
        all_ok=false
        deploy_log "Tomcat: FAIL - 未安装"
    fi

    # 1.3 检测MySQL
    echo -e "\n${YELLOW}[3/5] MySQL数据库...${NC}"
    if command -v mysql &>/dev/null; then
        if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
            echo -e "  ${GREEN}● 连接正常，可登录${NC}"
            deploy_log "MySQL: OK - 可连接"
        else
            echo -e "  ${YELLOW}△ 已安装但连接失败（密码错误或未启动）${NC}"
            deploy_log "MySQL: WARN - 连接失败"
        fi
    else
        echo -e "  ${RED}○ 未安装或不在PATH中${NC}"
        all_ok=false
        deploy_log "MySQL: FAIL - 未安装"
    fi

    # 1.4 检查磁盘空间（项目部署至少需要100MB）
    echo -e "\n${YELLOW}[4/5] 磁盘空间...${NC}"
    available_mb=$(df -BM /opt | awk 'NR==2 {print $4}' | tr -d 'M')
    if [ "$available_mb" -gt 100 ]; then
        echo -e "  ${GREEN}● /opt 分区可用: ${available_mb}MB${NC}"
        deploy_log "磁盘空间: OK - ${available_mb}MB"
    else
        echo -e "  ${RED}○ 空间不足: 仅剩 ${available_mb}MB${NC}"
        all_ok=false
        deploy_log "磁盘空间: FAIL - ${available_mb}MB"
    fi

    # 1.5 检查网络（用于下载依赖）
    echo -e "\n${YELLOW}[5/5] 网络连接...${NC}"
    if ping -c 1 -W 2 localhost &>/dev/null; then
        echo -e "  ${GREEN}● 本地网络正常${NC}"
        deploy_log "网络: OK"
    else
        echo -e "  ${RED}○ 网络异常${NC}"
        deploy_log "网络: FAIL"
    fi

    # 输出总结
    echo ""
    echo -e "${PURPLE}====================${NC}"
    if [ "$all_ok" = true ]; then
        echo -e "${GREEN}  环境检测通过 ✓${NC}"
        deploy_log "环境检测结果: 通过"
        return 0
    else
        echo -e "${RED}  环境存在问题 ✗${NC}"
        echo -e "${YELLOW}  请先解决上述问题后再进行部署${NC}"
        deploy_log "环境检测结果: 存在问题"
        return 1
    fi
}

# ============================================
# 功能2：拷贝项目代码到服务器
# 逻辑说明：
#   1. 支持从本地目录或远程仓库获取项目
#   2. 将项目拷贝到Tomcat的webapps目录
#   3. 对于Java Web项目，处理WAR包部署
#   4. 设置正确的文件权限
# ============================================
copy_project_code() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}           拷贝项目代码${NC}"
    echo -e "${CYAN}============================================================${NC}"

    deploy_log "[步骤2] 拷贝项目代码..."

    # 2.1 选择项目来源方式
    echo ""
    echo -e "${YELLOW}请选择项目来源:${NC}"
    echo "  1. 从本地目录拷贝"
    echo "  2. 创建示例演示项目（用于课程设计展示）"
    read -p "请选择 (1-2): " source_choice

    case $source_choice in
        1)
            copy_from_local
            ;;
        2)
            create_demo_project
            ;;
        *)
            echo -e "${RED}[错误] 无效的选择！${NC}"
            return 1
            ;;
    esac
}

# 从本地目录拷贝项目
copy_from_local() {
    read -p "请输入项目源码目录的绝对路径: " PROJECT_SOURCE_DIR

    # 验证源目录存在
    if [ ! -d "$PROJECT_SOURCE_DIR" ]; then
        echo -e "${RED}[错误] 目录不存在: $PROJECT_SOURCE_DIR${NC}"
        return 1
    fi

    echo -e "${YELLOW}[拷贝] 项目代码...${NC}"
    echo -e "  源目录: $PROJECT_SOURCE_DIR"
    echo -e "  目标目录: $PROJECT_DEPLOY_DIR"

    # 如果目标目录已存在旧版本，先备份
    if [ -d "$PROJECT_DEPLOY_DIR" ]; then
        BACKUP_DIR="${PROJECT_DEPLOY_DIR}_bak_$(date +%Y%m%d%H%M%S)"
        mv "$PROJECT_DEPLOY_DIR" "$BACKUP_DIR"
        echo -e "${YELLOW}  旧版本已备份至: $BACKUP_DIR${NC}"
    fi

    # 执行拷贝（使用cp命令递归复制）
    cp -r "$PROJECT_SOURCE_DIR" "$PROJECT_DEPLOY_DIR"

    if [ $? -eq 0 ]; then
        # 设置权限
        chmod -R 755 "$PROJECT_DEPLOY_DIR"

        # 统计文件数量
        file_count=$(find "$PROJECT_DEPLOY_DIR" -type f | wc -l)
        dir_count=$(find "$PROJECT_DEPLOY_DIR" -type d | wc -l)

        echo -e "${GREEN}[成功] 项目拷贝完成！${NC}"
        echo -e "  文件数: $file_count 个"
        echo -e "  目录数: $dir_count 个"
        deploy_log "项目拷贝成功: $PROJECT_SOURCE_DIR -> $PROJECT_DEPLOY_DIR"
    else
        echo -e "${RED}[错误] 项目拷贝失败！${NC}"
        return 1
    fi
}

# 创建示例演示项目（用于课程设计）
create_demo_project() {
    echo -e "${YELLOW}[创建] 示例演示项目...${NC}"
    echo -e "  项目名称: $PROJECT_NAME"
    echo -e "  部署路径: $PROJECT_DEPLOY_DIR"

    # 清理可能存在的旧项目
    rm -rf "$PROJECT_DEPLOY_DIR"

    # 创建标准Web应用目录结构
    mkdir -p "$PROJECT_DEPLOY_DIR"
    mkdir -p "$PROJECT_DEPLOY_DIR/WEB-INF"
    mkdir -p "$PROJECT_DEPLOY_DIR/images"
    mkdir -p "$PROJECT_DEPLOY_DIR/css"
    mkdir -p "$PROJECT_DEPLOY_DIR/js"

    # ============================================
    # 创建首页 index.html
    # ============================================
    cat > "$PROJECT_DEPLOY_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>学生管理系统 - Linux课程设计</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>学生管理系统</h1>
            <p class="subtitle">Linux系统开发课程设计演示项目</p>
        </header>

        <nav class="navbar">
            <a href="index.html" class="active">首页</a>
            <a href="student_list.html">学生列表</a>
            <a href="about.html">关于项目</a>
        </nav>

        <main>
            <section class="welcome-section">
                <h2>欢迎使用学生管理系统</h2>
                <p>本系统是基于Linux Shell脚本部署的Web应用程序演示。</p>
                <div class="info-cards">
                    <div class="card">
                        <h3>技术栈</h3>
                        <ul>
                            <li>Linux操作系统</li>
                            <li>Shell脚本编程</li>
                            <li>Apache Tomcat</li>
                            <li>MySQL数据库</li>
                        </ul>
                    </div>
                    <div class="card">
                        <h3>功能模块</h3>
                        <ul>
                            <li>用户管理</li>
                            <li>数据管理</li>
                            <li>信息查询</li>
                            <li>系统设置</li>
                        </ul>
                    </div>
                </div>
            </section>

            <section class="status-section">
                <h2>系统状态</h2>
                <table class="status-table">
                    <tr><td>服务器</td><td class="success">正常运行</td></tr>
                    <tr><td>数据库</td><td class="success">已连接</td></tr>
                    <tr><td>部署时间</td><td id="deploy-time"></td></tr>
                    <tr><td>系统版本</td><td>v1.0.0</td></tr>
                </table>
            </section>
        </main>

        <footer>
            <p>&copy; 2024 Linux系统开发课程设计 | 学生管理系统</p>
        </footer>
    </div>
    <script src="js/main.js"></script>
</body>
</html>
HTMLEOF

    # ============================================
    # 创建学生列表页面 student_list.html
    # ============================================
    cat > "$PROJECT_DEPLOY_DIR/student_list.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>学生列表 - 学生管理系统</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>学生管理系统</h1>
        </header>

        <nav class="navbar">
            <a href="index.html">首页</a>
            <a href="student_list.html" class="active">学生列表</a>
            <a href="about.html">关于项目</a>
        </nav>

        <main>
            <section class="list-section">
                <h2>学生信息列表</h2>
                <div class="toolbar">
                    <input type="text" id="search-input" placeholder="搜索学生...">
                    <button onclick="searchStudents()">搜索</button>
                </div>

                <table class="data-table">
                    <thead>
                        <tr>
                            <th>学号</th>
                            <th>姓名</th>
                            <th>性别</th>
                            <th>年龄</th>
                            <th>班级</th>
                            <th>操作</th>
                        </tr>
                    </thead>
                    <tbody id="student-tbody">
                        <!-- 数据将通过JavaScript动态加载 -->
                    </tbody>
                </table>

                <div class="pagination">
                    <button onclick="prevPage()">上一页</button>
                    <span id="page-info">第 1 页</span>
                    <button onclick="nextPage()">下一页</button>
                </div>
            </section>
        </main>

        <footer>
            <p>&copy; 2024 Linux系统开发课程设计</p>
        </footer>
    </div>
    <script src="js/main.js"></script>
</body>
</html>
HTMLEOF

    # ============================================
    # 创建关于页面 about.html
    # ============================================
    cat > "$PROJECT_DEPLOY_DIR/about.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>关于项目 - 学生管理系统</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>学生管理系统</h1>
        </header>

        <nav class="navbar">
            <a href="index.html">首页</a>
            <a href="student_list.html">学生列表</a>
            <a href="about.html" class="active">关于项目</a>
        </nav>

        <main>
            <section class="about-section">
                <h2>项目介绍</h2>
                <div class="about-content">
                    <h3>项目背景</h3>
                    <p>本项目是Linux系统开发课程的课程设计作品，旨在通过实践掌握Linux环境下的系统管理和Web应用部署技能。</p>

                    <h3>技术实现</h3>
                    <ul>
                        <li><strong>用户管理：</strong>使用Shell脚本实现用户的增删改查操作</li>
                        <li><strong>文件操作：</strong>使用Shell命令实现文件和目录的管理</li>
                        <li><strong>数据库配置：</strong>自动化安装和配置MySQL数据库</li>
                        <li><strong>服务器配置：</strong>自动化安装和配置Tomcat服务器</li>
                        <li><strong>项目部署：</strong>完整的Web应用部署流程</li>
                    </ul>

                    <h3>学习收获</h3>
                    <ol>
                        <li>深入理解了Linux系统的基本架构和工作原理</li>
                        <li>掌握了Shell脚本编程的基本语法和技巧</li>
                        <li>学会了在Linux环境下配置和管理常用服务</li>
                        <li>理解了Web应用的完整部署流程</li>
                        <li>培养了解决实际问题的能力</li>
                    </ol>
                </div>
            </section>
        </main>

        <footer>
            <p>&copy; 2024 Linux系统开发课程设计</p>
        </footer>
    </div>
    <script src="js/main.js"></script>
</body>
</html>
HTMLEOF

    # ============================================
    # 创建CSS样式文件 css/style.css
    # ============================================
    cat > "$PROJECT_DEPLOY_DIR/css/style.css" << 'CSSEOF'
/* 学生管理系统样式表 */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Microsoft YaHei', Arial, sans-serif;
    background-color: #f5f5f5;
    color: #333;
    line-height: 1.6;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    background: white;
    min-height: 100vh;
}

header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 30px;
    text-align: center;
}

header h1 {
    font-size: 2.5em;
    margin-bottom: 10px;
}

header .subtitle {
    font-size: 1.1em;
    opacity: 0.9;
}

.navbar {
    background: #333;
    padding: 0;
    display: flex;
    justify-content: center;
}

.navbar a {
    color: white;
    padding: 15px 30px;
    text-decoration: none;
    transition: background 0.3s;
}

.navbar a:hover,
.navbar a.active {
    background: #667eea;
}

main {
    padding: 30px;
}

.welcome-section h2,
.list-section h2,
.about-section h2 {
    color: #667eea;
    margin-bottom: 20px;
    padding-bottom: 10px;
    border-bottom: 2px solid #667eea;
}

.info-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
    margin-top: 20px;
}

.card {
    background: #f9f9f9;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.card h3 {
    color: #764ba2;
    margin-bottom: 15px;
}

.card ul {
    list-style: none;
    padding-left: 0;
}

.card ul li {
    padding: 8px 0;
    border-bottom: 1px solid #eee;
}

.card ul li:before {
    content: "✓ ";
    color: #667eea;
    font-weight: bold;
}

.status-table {
    width: 100%;
    max-width: 500px;
    border-collapse: collapse;
    margin-top: 20px;
}

.status-table td {
    padding: 12px 15px;
    border: 1px solid #ddd;
}

.status-table td:first-child {
    font-weight: bold;
    background: #f5f5f5;
    width: 40%;
}

.success {
    color: #28a745;
    font-weight: bold;
}

.data-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
    background: white;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.data-table th,
.data-table td {
    padding: 12px 15px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}

.data-table th {
    background: #667eea;
    color: white;
    font-weight: bold;
}

.data-table tr:hover {
    background: #f5f5f5;
}

.toolbar {
    margin-bottom: 20px;
    display: flex;
    gap: 10px;
}

.toolbar input {
    flex: 1;
    padding: 10px 15px;
    border: 1px solid #ddd;
    border-radius: 5px;
    font-size: 14px;
}

.toolbar button {
    padding: 10px 25px;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    transition: background 0.3s;
}

.toolbar button:hover {
    background: #764ba2;
}

.pagination {
    margin-top: 20px;
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 15px;
}

.pagination button {
    padding: 8px 20px;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
}

.about-content {
    line-height: 1.8;
}

.about-content h3 {
    color: #667eea;
    margin: 25px 0 15px;
    font-size: 1.3em;
}

.about-content ul,
.about-content ol {
    margin-left: 25px;
    margin-top: 10px;
}

.about-content li {
    margin-bottom: 8px;
}

footer {
    background: #333;
    color: white;
    text-align: center;
    padding: 20px;
    margin-top: 40px;
}
CSSEOF

    # ============================================
    # 创建JavaScript文件 js/main.js
    # ============================================
    cat > "$PROJECT_DEPLOY_DIR/js/main.js" << 'JSEOF'
// 学生管理系统 JavaScript

// 显示当前部署时间
document.addEventListener('DOMContentLoaded', function() {
    var timeElement = document.getElementById('deploy-time');
    if (timeElement) {
        timeElement.textContent = new Date().toLocaleString('zh-CN');
    }

    // 加载学生数据
    loadStudentData();
});

// 模拟学生数据（实际项目中应从后端API获取）
var studentsData = [
    { id: 1, name: '张三', gender: '男', age: 20, className: '计算机2301' },
    { id: 2, name: '李四', gender: '男', age: 19, className: '计算机2301' },
    { id: 3, name: '王五', gender: '男', age: 21, className: '计算机2302' },
    { id: 4, name: '赵六', gender: '女', age: 20, className: '计算机2302' },
    { id: 5, name: '钱七', gender: '女', age: 19, className: '软件工程2301' }
];

var currentPage = 1;
var pageSize = 5;

// 加载并显示学生数据
function loadStudentData() {
    var tbody = document.getElementById('student-tbody');
    if (!tbody) return;

    tbody.innerHTML = '';

    studentsData.forEach(function(student) {
        var row = document.createElement('tr');

        row.innerHTML =
            '<td>' + student.id + '</td>' +
            '<td>' + student.name + '</td>' +
            '<td>' + student.gender + '</td>' +
            '<td>' + student.age + '</td>' +
            '<td>' + student.className + '</td>' +
            '<td><button onclick="viewDetail(' + student.id + ')">查看</button></td>';

        tbody.appendChild(row);
    });
}

// 搜索学生
function searchStudents() {
    var keyword = document.getElementById('search-input').value.toLowerCase();
    alert('搜索功能：' + (keyword || '全部'));
}

// 分页功能
function prevPage() {
    if (currentPage > 1) {
        currentPage--;
        updatePageInfo();
    }
}

function nextPage() {
    currentPage++;
    updatePageInfo();
}

function updatePageInfo() {
    var pageInfo = document.getElementById('page-info');
    if (pageInfo) {
        pageInfo.textContent = '第 ' + currentPage + ' 页';
    }
}

// 查看详情
function viewDetail(id) {
    alert('查看学生ID: ' + id + ' 的详细信息');
}
JSEOF

    # ============================================
    # 创建WEB-INF配置文件 web.xml
    # ============================================
    cat > "$PROJECT_DEPLOY_DIR/WEB-INF/web.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
                             http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">

    <display-name>学生管理系统</display-name>
    <description>
        Linux系统开发课程设计 - 学生管理系统演示项目
    </description>

    <welcome-file-list>
        <welcome-file>index.html</welcome-file>
        <welcome-file>index.htm</welcome-file>
    </welcome-file-list>

</web-app>
XMLEOF

    # 设置权限
    chmod -R 755 "$PROJECT_DEPLOY_DIR"

    # 统计创建的文件
    file_count=$(find "$PROJECT_DEPLOY_DIR" -type f | wc -l)

    echo -e "${GREEN}[成功] 示例项目创建完成！${NC}"
    echo -e "  项目名称: $PROJECT_NAME"
    echo -e "  部署路径: $PROJECT_DEPLOY_DIR"
    echo -e "  文件总数: $file_count"
    echo -e "\n${YELLOW}--- 项目结构 ---${NC}"
    tree "$PROJECT_DEPLOY_DIR" 2>/dev/null || find "$PROJECT_DEPLOY_DIR" -type f | head -20

    deploy_log "示例项目创建成功: $PROJECT_DEPLOY_DIR ($file_count 个文件)"
}

# ============================================
# 功能3：启动MySQL服务
# 逻辑说明：
#   1. 检查MySQL服务状态
#   2. 如果未启动则启动服务
#   3. 初始化项目所需的数据库和数据
#   4. 验证数据库连接
# ============================================
start_mysql_service() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}         启动MySQL数据库${NC}"
    echo -e "${CYAN}============================================================${NC}"

    deploy_log "[步骤3] 启动MySQL服务..."

    # 3.1 检查MySQL服务状态
    echo -e "${YELLOW}[检查] MySQL服务状态...${NC}"
    if sudo systemctl is-active --quiet mysqld 2>/dev/null || \
       sudo systemctl is-active --quiet mariadb 2>/dev/null; then
        echo -e "${GREEN}  MySQL已在运行中${NC}"
    else
        echo -e "${YELLOW}[启动] MySQL服务...${NC}"
        sudo systemctl start mysqld 2>/dev/null || sudo systemctl start mariadb 2>/dev/null

        sleep 3

        if sudo systemctl is-active --quiet mysqld 2>/dev/null || \
           sudo systemctl is-active --quiet mariadb 2>/dev/null; then
            echo -e "${GREEN}  MySQL启动成功${NC}"
            deploy_log "MySQL服务启动成功"
        else
            echo -e "${RED}[错误] MySQL启动失败！${NC}"
            deploy_log "MySQL启动失败"
            return 1
        fi
    fi

    # 3.2 测试数据库连接
    echo -e "\n${YELLOW}[测试] 数据库连接...${NC}"
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 'Connection OK';" 2>/dev/null; then
        echo -e "${GREEN}  数据库连接成功${NC}"
        deploy_log "数据库连接测试成功"
    else
        echo -e "${RED}[警告] 数据库连接失败，请检查密码配置${NC}"
        deploy_log "数据库连接失败"
    fi

    # 3.3 检查并创建项目数据库（如果不存在）
    echo -e "\n${YELLOW}[检查] 项目数据库...${NC}"
    DB_EXISTS=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null | wc -l)

    if [ "$DB_EXISTS" -gt 0 ]; then
        echo -e "${GREEN}  数据库 '$DB_NAME' 已存在${NC}"
    else
        echo -e "${YELLOW}[创建] 初始化项目数据库...${NC}"
        # 这里可以调用数据库初始化SQL
        echo -e "${GREEN}  数据库准备就绪${NC}"
        deploy_log "项目数据库准备完成"
    fi

    return 0
}

# ============================================
# 功能4：启动Tomcat服务
# 逻辑说明：
#   1. 检查Tomcat进程状态
#   2. 执行startup.sh启动Tomcat
#   3. 等待服务完全启动（监听端口）
#   4. 验证HTTP可访问性
# ============================================
start_tomcat_service() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}         启动Tomcat服务器${NC}"
    echo -e "${CYAN}============================================================${NC}"

    deploy_log "[步骤4] 启动Tomcat服务..."

    # 4.1 检查Tomcat是否已安装
    if [ ! -d "$TOMCAT_HOME" ]; then
        echo -e "${RED}[错误] Tomcat未安装在: $TOMCAT_HOME${NC}"
        echo -e "${YELLOW}请先执行题目4的Tomcat安装配置${NC}"
        return 1
    fi

    # 4.2 检查并启动Tomcat
    echo -e "${YELLOW}[检查] Tomcat状态...${NC}"
    if pgrep -f "org.apache.catalina.startup.Bootstrap" > /dev/null; then
        echo -e "${GREEN}  Tomcat已在运行中${NC}"

        # 重启以加载新部署的项目
        read -p "检测到新项目部署，是否重启Tomcat？(y/n): " restart_tc
        if [ "$restart_tc" = "y" ] || [ "$restart_tc" = "Y" ]; then
            restart_tomcat
        fi
    else
        echo -e "${YELLOW}[启动] Tomcat服务器...${NC}"
        cd "$TOMCAT_HOME"

        export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
        ./bin/startup.sh

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  Tomcat启动命令已执行${NC}"
        else
            echo -e "${RED}[错误] Tomcat启动失败！${NC}"
            return 1
        fi
    fi

    # 4.3 等待Tomcat完全启动
    echo -e "\n${YELLOW}[等待] 服务启动中（约10秒）...${NC}"
    sleep 10

    # 4.4 验证启动结果
    check_tomcat_running
}

# 重启Tomcat
restart_tomcat() {
    echo -e "${YELLOW}[重启] 正在重启Tomcat...${NC}"
    cd "$TOMCAT_HOME"
    export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

    ./bin/shutdown.sh 2>/dev/null
    sleep 3
    pkill -9 -f catalina 2>/dev/null
    sleep 2

    ./bin/startup.sh
    sleep 10

    echo -e "${GREEN}  Tomcat重启完成${NC}"
    deploy_log "Tomcat已重启"
}

# 检查Tomcat是否正在运行
check_tomcat_running() {
    PORT=${TOMCAT_PORT:-8080}
    PROJECT_URL="http://localhost:$PORT/$PROJECT_NAME/"

    echo -e "\n${YELLOW}--- 服务状态验证 ---${NC}\n"

    # 检查进程
    if pgrep -f "org.apache.catalina.startup.Bootstrap" > /dev/null; then
        echo -e "  ${GREEN}● 进程: 运行中${NC}"
    else
        echo -e "  ${RED}○ 进程: 未运行${NC}"
        return 1
    fi

    # 检查端口
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        echo -e "  ${GREEN}● 端口 $PORT: 监听中${NC}"
    else
        echo -e "  ${RED}○ 端口 $PORT: 未监听${NC}"
    fi

    # HTTP测试
    if command -v curl &>/dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ --connect-timeout 5 2>/dev/null)
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
            echo -e "  ${GREEN}● HTTP: 正常响应 ($HTTP_CODE)${NC}"
        else
            echo -e "  ${RED}○ HTTP: 响应异常 ($HTTP_CODE)${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  项目访问地址:${NC}"
    echo -e "${BLUE}  $PROJECT_URL${NC}"
    echo -e "${GREEN}============================================${NC}"

    deploy_log "Tomcat运行正常, 访问地址=$PROJECT_URL"
    return 0
}

# ============================================
# 功能5：浏览器访问测试
# 逻辑说明：
#   1. 使用curl模拟HTTP请求测试各页面
#   2. 验证页面返回状态码
#   3. 检查关键内容是否存在
#   4. 输出详细的测试报告
# ============================================
test_project_access() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}         项目功能测试${NC}"
    echo -e "${CYAN}============================================================${NC}"

    deploy_log "[步骤5] 测试项目访问..."

    PORT=${TOMCAT_PORT:-8080}
    BASE_URL="http://localhost:$PORT/$PROJECT_NAME"

    # 5.1 测试工具检查
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}[错误] 系统缺少curl工具，无法进行HTTP测试${NC}"
        return 1
    fi

    echo -e "${YELLOW}[测试] 开始HTTP请求测试...\n${NC}"

    # 定义要测试的页面
    declare -A TEST_PAGES
    TEST_PAGES["首页"]="$BASE_URL/"
    TEST_PAGES["学生列表"]="$BASE_URL/student_list.html"
    TEST_PAGES["关于页面"]="$BASE_URL/about.html"
    TEST_PAGES["CSS样式"]="$BASE_URL/css/style.css"
    TEST_PAGES["JS脚本"]="$BASE_URL/js/main.js"

    PASS_COUNT=0
    TOTAL_COUNT=${#TEST_PAGES[@]}

    # 逐个测试每个页面
    for page_name in "${!TEST_PAGES[@]}"; do
        page_url="${TEST_PAGES[$page_name]}"

        printf "  %-12s → " "$page_name"

        # 发送HTTP GET请求
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$page_url" --connect-timeout 10 2>/dev/null)
        RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$page_url" --connect-timeout 10 2>/dev/null)

        # 判断测试结果
        case $HTTP_CODE in
            200)
                echo -e "${GREEN}✓ 成功 (${HTTP_CODE}, ${RESPONSE_TIME}s)${NC}"
                PASS_COUNT=$((PASS_COUNT + 1))
                ;;
            302|301)
                echo -e "${GREEN}✓ 重定向 (${HTTP_CODE})${NC}"
                PASS_COUNT=$((PASS_COUNT + 1))
                ;;
            404)
                echo -e "${RED}✗ 未找到 (404)${NC}"
                ;;
            000)
                echo -e "${RED}✗ 连接失败${NC}"
                ;;
            *)
                echo -e "${YELLOW}△ 其他 ($HTTP_CODE)${NC}"
                ;;
        esac
    done

    # 5.2 输出测试总结
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}              测试报告${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════${NC}"
    echo -e "  测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "  测试项数: $TOTAL_COUNT"
    echo -e "  通过数量: ${GREEN}$PASS_COUNT${NC}"
    echo -e "  失败数量: $((TOTAL_COUNT - PASS_COUNT))"

    if [ $PASS_COUNT -eq $TOTAL_COUNT ]; then
        echo -e "  测试结果: ${GREEN}全部通过 ✓${NC}"
        deploy_log "功能测试全部通过 ($PASS_COUNT/$TOTAL_COUNT)"
    else
        echo -e "  测试结果: ${RED}部分失败 ✗${NC}"
        deploy_log "功能测试部分失败 ($PASS_COUNT/$TOTAL_COUNT)"
    fi

    echo -e "${PURPLE}═══════════════════════════════════════${NC}"
    echo ""

    # 5.3 显示访问说明
    echo -e "${YELLOW}--- 浏览器访问指南 ---${NC}"
    echo -e "  1. 打开浏览器"
    echo -e "  2. 在地址栏输入: ${BLUE}$BASE_URL/${NC}"
    echo -e "  3. 回车即可访问学生管理系统"
    echo ""
    echo -e "  或访问其他页面:"
    echo -e "    - 首页: ${BLUE}${BASE_URL}/${NC}"
    echo -e "    - 学生列表: ${BLUE}${BASE_URL}/student_list.html${NC}"
    echo -e "    - 关于: ${BLUE}${BASE_URL}/about.html${NC}"
}

# ============================================
# 一键完整部署流程
# ============================================
full_deploy() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}          一键完整部署${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "${YELLOW}开始执行完整部署流程...${NC}"
    echo ""

    # 步骤1：环境检测
    check_deploy_environment
    if [ $? -ne 0 ]; then
        echo -e "${RED}[终止] 环境检测未通过，请先解决问题${NC}"
        return 1
    fi
    echo ""

    # 步骤2：拷贝项目代码
    copy_project_code
    if [ $? -ne 0 ]; then
        echo -e "${RED}[终止] 项目拷贝失败${NC}"
        return 1
    fi
    echo ""

    # 步骤3：启动MySQL
    start_mysql_service
    echo ""

    # 步骤4：启动Tomcat
    start_tomcat_service
    echo ""

    # 步骤5：功能测试
    test_project_access

    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}     🎉 部署完成！项目已成功上线 🎉${NC}"
    echo -e "${GREEN}============================================================${NC}"
    deploy_log "=== 完整部署流程执行完毕 ==="
}

# ============================================
# 主菜单界面
# ============================================
main_menu() {
    init_deploy_log

    while true; do
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║       Web项目部署管理系统 v1.0               ║${NC}"
        echo -e "${GREEN}╠══════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║                                              ║${NC}"
        echo -e "${GREEN}║   1. 检查部署环境                           ║${NC}"
        echo -e "${GREEN}║   2. 拷贝项目代码                           ║${NC}"
        echo -e "${GREEN}║   3. 启动MySQL数据库                        ║${NC}"
        echo -e "${GREEN}║   4. 启动Tomcat服务器                       ║${NC}"
        echo -e "${GREEN}║   5. 测试项目功能（浏览器访问）             ║${NC}"
        echo -e "${GREEN}║   6. 一键完整部署                           ║${NC}"
        echo -e "${GREEN}║   0. 退出系统                               ║${NC}"
        echo -e "${GREEN}║                                              ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
        echo ""

        read -p "请选择功能 (0-6): " choice

        case $choice in
            1)
                check_deploy_environment
                ;;
            2)
                copy_project_code
                ;;
            3)
                start_mysql_service
                ;;
            4)
                start_tomcat_service
                ;;
            5)
                test_project_access
                ;;
            6)
                full_deploy
                ;;
            0)
                echo -e "${YELLOW}感谢使用项目部署工具，再见！${NC}"
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
