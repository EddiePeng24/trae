#!/bin/bash
LOG_FILE="/var/log/user_management.log"
write_log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"|sudo tee -a "$LOG_FILE">/dev/null;}
create_user(){
read -p "用户名: " username
[ -z "$username" ]&&echo "不能为空"&&return 1
id "$username"&>/dev/null&&echo "用户已存在"&&return 1
read -s -p "密码: " pwd;echo ""
sudo useradd -m -s /bin/bash "$username"
echo "$username:$pwd"|sudo chpasswd
echo "创建成功";write_log "创建:$username"}
change_password(){
read -p "用户名: " username
id "$username"&>/dev/null||(echo "不存在"&return 1)
read -s -p "新密码: " pwd;echo ""
echo "$username:$pwd"|sudo chpasswd
echo "修改成功"}
user_login(){
read -p "用户名: " username
id "$username"&>/dev/null||(echo "不存在"&return 1)
for i in 1 2 3;do
read -s -p "密码($i/3): " pwd;echo ""
echo "$pwd"|su -c "exit" "$username"&>/dev/null&&(echo "登录成功";return 0)||echo "错误"
done;echo "锁定";return 1}
delete_user(){
read -p "删除用户: " username
[ "$username"="root" ]&&echo "禁止删除root"&&return 1
id "$username"&>/dev/null||(echo "不存在"&return 1)
read -p "确认? " c;[ "$c"="y" ]&&sudo userdel -r "$username"&&echo "已删除"&&write_log "删除:$username"}
list_users(){
echo "---用户列表---"
awk -F: '$3>=1000&&$3!=65534{printf "%-12s UID:%s\n",$1,$3}' /etc/passwd}
while true;do
echo "1创建 2改密 3登录 4删除 5列表 0退出"
read -p "选择: " ch
case $ch in 1)create_user;;2)change_password;;3)user_login;;4)delete_user;;5)list_users;;0)exit 0;;esac
done

#!/bin/bash
create_folder(){
read -p "路径: " p
[ -z "$p" ]&&return 1
[ -d "$p" ]&&echo "已存在"&&return 1
read -p "创建父目录? " c;[ "$c"="y" ]&&mkdir -p "$p"||mkdir "$p"
chmod 755 "$p";echo "OK";ls -ld "$p"}
create_file(){
read -p "路径: " f
[ -z "$f" ]&&return 1
read -p "写内容? " c
[ "$c"="y" ]&&cat>"$f"||touch "$f"
chmod 644 "$f";echo "OK"}
modify_file(){
echo "1追加 2覆盖 3替换"
read -p "选择: " m;read -p "文件: " f
[ ! -f "$f" ]&&echo "不存在"&return 1
case $m in 1)cat>>"$f";;2)cat>"$f";;3)read -p "查: " o;read -p "换: " n;sed -i "s|$o|$n|g" "$f";;esac
echo "完成"}
delete_file(){
read -p "路径: " p
[ ! -e "$p" ]&&echo "不存在"&return 1
case "$p" in /|/bin|/etc|/root)echo "禁止";return 1;;esac
read -p "确认? " c;[ "$c"="y" ]&&rm -rf "$p"&&echo "已删除"}
browse_dir(){
read -p "目录: " d;d=${d:-.}
[ ! -d "$d" ]&&echo "不存在"&return 1
ls -lah "$d";echo "文件:$(find "$d" -type f|wc -l) 目录:$(find "$d" -type d|wc -l) 大小:$(du -sh "$d"|cut -f1)"}
while true;do
echo "1文件夹 2文件 3修改 4删除 5浏览 0退出"
read -p "选择: " ch
case $ch in 1)create_folder;;2)create_file;;3)modify_file;;4)delete_file;;5)browse_dir;;0)exit 0;;esac
done

#!/bin/bash
MYSQL_ROOT_PASSWORD="Root@123456"
check_env(){
echo "系统: $(cat /etc/os-release|grep "^NAME="|cut -d'"' -f2)"
echo "内存: $(free -m|awk '/Mem:/{print $2MB}')"
command -v mysql&>/dev/null&&echo "MySQL已安装"||echo "未安装"}
install_mysql(){
if command -v yum&>/dev/null;then
sudo yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-7.noarch.rpm
sudo yum install -y mysql-community-server
elif command -v apt&>/dev/null;then
sudo apt-get update -qq;sudo apt-get install -y mysql-server;fi
sudo systemctl start mysqld 2>/dev/null||sudo systemctl start mysql
sudo systemctl enable mysqld 2>/dev/null||sudo systemctl enable mysql
echo "MySQL安装完成"}
create_db(){
sudo mysql<<'EOF'
CREATE DATABASE IF NOT EXISTS student_management CHARACTER SET utf8mb4;
USE student_management;
CREATE TABLE students(id INT PRIMARY KEY AUTO_INCREMENT,name VARCHAR(50),gender ENUM('男','女'),age INT,phone VARCHAR(20),email VARCHAR(100));
CREATE TABLE courses(id INT PRIMARY KEY AUTO_INCREMENT,course_name VARCHAR(100),credit DECIMAL(3,1));
CREATE TABLE scores(id INT PRIMARY KEY AUTO_INCREMENT,student_id INT,course_id INT,score DECIMAL(5,2),exam_date DATE,FOREIGN KEY(student_id) REFERENCES students(id),FOREIGN KEY(course_id) REFERENCES courses(id));
EOF
echo "数据库创建完成"}
insert_data(){
sudo mysql student_management<<'EOF'
INSERT INTO students(name,gender,age,email)VALUES('张三','男',20,'zhangsan@example.com'),('李四','女',19,'lisi@example.com'),('王五','男',21,'wangwu@example.com'),('赵六','女',20,'zhaoliu@example.com');
INSERT INTO courses(course_name,credit)VALUES('高等数学',4),('线性代数',3),('大学英语',3),('程序设计',4);
INSERT INTO scores(student_id,course_id,score,exam_date)VALUES(1,1,85.5,'2024-01-15'),(1,2,90,'2024-01-16'),(2,1,78,'2024-01-15'),(2,3,92,'2024-01-18'),(3,1,95.5,'2024-01-15'),(3,4,88,'2024-01-17'),(4,2,88.5,'2024-01-16'),(4,3,90,'2024-01-18');
EOF
echo "数据插入完成"}
verify(){
sudo mysql -e "USE student_management;SELECT*FROM students;SELECT*FROM courses;SELECT s.name,c.course_name,sc.score FROM scores sc JOIN students s ON sc.student_id=s.id JOIN courses c ON sc.course_id=c.id;"}
echo "MySQL安装配置开始"
check_env
command -v mysql&>/dev/null||install_mysql
create_db
insert_data
verify
echo "完成！数据库:student_management 密码:$MYSQL_ROOT_PASSWORD"

#!/bin/bash
TOMCAT_VERSION="10.1.18"
TOMCAT_HOME="/opt/tomcat-${TOMCAT_VERSION}"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
check_java(){
if command -v java&>/dev/null;then echo "Java:$(java -version 2>&1|head -1)";return 0;fi
echo "安装Java..."
command -v apt&>/dev/null&&sudo apt-get install -y openjdk-11-jdk||sudo yum install -y java-11-openjdk}
download_tomcat(){
TMP="/tmp/tc_$$.tar.gz"
echo "下载Tomcat $TOMCAT_VERSION..."
command -v wget&>/dev/null&&wget -q "$TOMCAT_URL" -O "$TMP"||curl -sL "$TOMCAT_URL" -o "$TMP"
[ -s "$TMP" ]&&echo "下载完成"||return 1}
install_tomcat(){
sudo mkdir -p /opt
sudo tar -xzf /tmp/tc_*.tar.gz -C /opt
sudo ln -sfn "$TOMCAT_HOME" /opt/tomcat
sudo chmod +x /opt/tomcat/bin/*.sh
echo "安装完成: $TOMCAT_HOME"}
config_admin(){
sudo cp /opt/tomcat/conf/tomcat-users.xml /opt/tomcat/conf/tomcat-users.xml.bak
sudo sed -i '/<\/tomcat-users>/i<role rolename="manager-gui"/><user username="admin" password="admin123" roles="manager-gui"/>' /opt/tomcat/conf/tomcat-users.xml
echo "管理员: admin/admin123"}
start_tomcat(){
pgrep -f tomcat&>/dev/null&&(sudo /opt/tomcat/bin/shutdown.sh;sleep 2)
sudo /opt/tomcat/bin/startup.sh;sleep 3
pgrep -f tomcat&>/dev/null&&echo "Tomcat启动成功"||echo "启动失败"}
verify_tomcat(){
sleep 2
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
echo "HTTP状态: $CODE"
echo "访问: http://localhost:8080/ 管理界面: http://localhost:8080/manager/html"}
echo "Tomcat安装开始"
check_java
download_tomcat
install_tomcat
config_admin
start_tomcat
verify_tomcat

#!/bin/bash
TOMCAT_HOME="/opt/tomcat"
PROJECT_NAME="StudentManager"
PROJECT_DIR="$TOMCAT_HOME/webapps/$PROJECT_NAME"
check_env(){
echo "环境检测:"
command -v java&>/dev/null&&echo "[√]Java"||echo "[×]Java"
[ -d "$TOMCAT_HOME" ]&&echo "[√]Tomcat"||echo "[×]Tomcat"
command -v mysql&>/dev/null&&echo "[√]MySQL"||echo "[×]MySQL"
echo "磁盘:$(df -BG /|awk 'NR==2{print $4}')"}
create_project(){
sudo rm -rf "$PROJECT_DIR"
sudo mkdir -p "$PROJECT_DIR/css" "$PROJECT_DIR/js" "$PROJECT_DIR/WEB-INF"
sudo tee "$PROJECT_DIR/index.html">/dev/null<<'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>学生管理系统</title><style>body{font-family:Arial;background:#f5f5f5;margin:0;padding:20px}.c{max-width:900px;margin:0 auto;background:#fff;padding:20px;border-radius:8px}h1{color:#667eea;text-align:center}.nav{background:#667eea;padding:10px;border-radius:5px;text-align:center}.nav a{color:#fff;text-decoration:none;margin:0 15px}.card{background:#f8f9fa;padding:20px;margin:10px 0;border-radius:5px}.card h3{color:#667eea;margin-top:0}</style></head><body><div class="c"><h1>学生管理系统</h1><div class="nav"><a href="index.html">首页</a><a href="students.html">学生</a><a href="about.html">关于</a></div><div class="card"><h3>学生管理</h3><p>管理学生基本信息</p></div><div class="card"><h3>成绩管理</h3><p>记录学生各科成绩</p></div><div class="card"><h3>课程管理</h3><p>维护课程信息</p></div></div></body></html>
HTMLEOF
sudo tee "$PROJECT_DIR/students.html">/dev/null<<'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>学生列表</title><style>body{font-family:Arial;padding:20px;background:#f5f5f5}table{width:100%;background:#fff;border-collapse:collapse;border-radius:8px;overflow:hidden}th{background:#667eea;color:#fff;padding:12px;text-align:left}td{padding:12px;border-bottom:1px solid #eee}tr:hover{background:#f9f9f9}</style></head><body><h1 style="color:#667eea">学生信息</h1><table><tr><th>学号</th><th>姓名</th><th>性别</th><th>年龄</th><th>邮箱</th></tr><tr><td>1</td><td>张三</td><td>男</td><td>20</td><td>zhangsan@example.com</td></tr><tr><td>2</td><td>李四</td><td>女</td><td>19</td><td>lisi@example.com</td></tr><tr><td>3</td><td>王五</td><td>男</td><td>21</td><td>wangwu@example.com</td></tr><tr><td>4</td><td>赵六</td><td>女</td><td>20</td><td>zhaoliu@example.com</td></tr></table></body></html>
HTMLEOF
sudo tee "$PROJECT_DIR/about.html">/dev/null<<'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>关于</title><style>body{font-family:Arial;padding:20px;background:#f5f5f5}.c{max-width:800px;margin:0 auto;background:#fff;padding:20px;border-radius:8px}h1{color:#667eea}h2{border-left:4px solid #667eea;padding-left:10px}</style></head><body><div class="c"><h1>关于项目</h1><h2>项目背景</h2><p>Linux课程设计，演示从环境配置到Web应用部署的完整流程。</p><h2>技术栈</h2><p>HTML/CSS/JavaScript + Tomcat + MySQL + Bash Shell</p><h2>功能模块</h2><p>用户管理、文件操作、数据库配置、服务器部署</p></div></body></html>
HTMLEOF
sudo chmod -R 755 "$PROJECT_DIR"
echo "项目创建完成"}
start_services(){
echo "启动服务..."
pgrep -x mysqld>/dev/null||pgrep -x mysql>/dev/null||sudo systemctl start mysqld 2>/dev/null||sudo systemctl start mysql
echo "[√]MySQL"
pgrep -f tomcat>/dev/null&&(sudo /opt/tomcat/bin/shutdown.sh;sleep 2)
sudo /opt/tomcat/bin/startup.sh;sleep 3
echo "[√]Tomcat"}
verify_deploy(){
BASE="http://localhost:8080/$PROJECT_NAME"
for p in index.html students.html about.html;do
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/$p")
echo "[$([[ $CODE = 200 ]]&&echo √||echo ×)] $p ($CODE)"
done
echo "访问: $BASE/index.html"}
echo "===== Web项目部署 ====="
check_env
create_project
start_services
verify_deploy
echo "===== 部署完成 ====="
