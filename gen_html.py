#!/usr/bin/env python3
# 生成HTML文件（浏览器打开后可打印为PDF，中文完美显示）

import html

scripts = [
    ('/workspace/linux_course_design/script1_user_manage.sh', '题目一：用户管理系统'),
    ('/workspace/linux_course_design/script2_file_operation.sh', '题目二：文件操作系统'),
    ('/workspace/linux_course_design/script3_mysql_config.sh', '题目三：MySQL安装与配置'),
    ('/workspace/linux_course_design/script4_tomcat_config.sh', '题目四：Tomcat安装与配置'),
    ('/workspace/linux_course_design/script5_project_deploy.sh', '题目五：Web项目部署'),
]

output = '/workspace/linux_course_design/源码_打印版.html'

with open(output, 'w', encoding='utf-8') as f:
    f.write('''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Linux课程设计-源码</title>
<style>
body{font-family:"Microsoft YaHei","PingFang SC",sans-serif;padding:20px;background:#fff}
.cover{text-align:center;padding-top:100px;page-break-after:always}
.cover h1{font-size:26px;margin-bottom:10px}.cover h2{font-size:20px;color:#666;margin-bottom:40px}
.cover p{font-size:15px;line-height:2.2}
.problem{page-break-before:always;padding-top:5px}
.title{background:#eef2f7;padding:8px 12px;font-size:14px;font-weight:bold;border-left:4px solid #4a90d9;margin-bottom:8px}
pre{font-family:"Consolas","Courier New",monospace;font-size:6.5pt;line-height:1.35;background:#fafafa;border:1px solid #ddd;padding:8px;white-space:pre-wrap;word-break:break-all;color:#222}
</style></head><body>
<div class="cover">
<h1>Linux系统开发课程设计</h1>
<h2>源码文档</h2>
<p>学号：20231035109</p>
<p>姓名：彭子阳</p>
</div>
''')

    for script_file, title in scripts:
        with open(script_file, 'r', encoding='utf-8') as sf:
            content = sf.read()
        
        escaped = html.escape(content)
        f.write(f'<div class="problem">\n')
        f.write(f'<div class="title">{html.escape(title)}</div>\n')
        f.write(f'<pre>{escaped}</pre>\n')
        f.write(f'</div>\n\n')

    f.write('</body></html>')

print(f"Done: {output}")
