#!/usr/bin/env python3
# 5个Shell脚本合并PDF - 使用fpdf2（原生支持中文）

from fpdf import FPDF

class PDF(FPDF):
    def __init__(self):
        super().__init__()
        self.add_font('Noto', '', '/usr/share/fonts/truetype/NotoSansCJKsc-Regular.otf', uni=True)

pdf = PDF()
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()

# 封面
pdf.set_font('Noto', '', 18)
pdf.cell(0, 12, 'Linux系统开发课程设计', ln=True)
pdf.cell(0, 12, '源码文档', ln=True)
pdf.ln(10)
pdf.set_font('Noto', '', 11)
pdf.cell(0, 8, '学号：20231035109', ln=True)
pdf.cell(0, 8, '姓名：彭子阳', ln=True)
pdf.ln(5)

scripts = [
    ('/workspace/linux_course_design/script1_user_manage.sh', '题目一：用户管理系统'),
    ('/workspace/linux_course_design/script2_file_operation.sh', '题目二：文件操作系统'),
    ('/workspace/linux_course_design/script3_mysql_config.sh', '题目三：MySQL安装与配置'),
    ('/workspace/linux_course_design/script4_tomcat_config.sh', '题目四：Tomcat安装与配置'),
    ('/workspace/linux_course_design/script5_project_deploy.sh', '题目五：Web项目部署'),
]

for i, (script_file, title) in enumerate(scripts):
    pdf.add_page()
    # 题目标题
    pdf.set_font('Noto', '', 13)
    pdf.set_fill_color(230, 240, 250)
    pdf.cell(0, 9, title, ln=True, fill=True)
    pdf.ln(3)

    # 代码内容 - 用等宽字体风格
    pdf.set_font_size(6.5)
    pdf.set_font('Noto', '', 6.5)  # 全部用中文字体

    with open(script_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for line in lines:
        # 替换特殊字符
        text = line.rstrip('\n').replace('&', '&amp;')
        if not text:
            text = ' '
        pdf.cell(0, 3.5, text, ln=True)

output = '/workspace/linux_course_design/20231035109_彭子阳_全部源码.pdf'
pdf.output(output)
print(f"Done: {output}")
