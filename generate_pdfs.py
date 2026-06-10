#!/usr/bin/env python3
# 生成5个Shell脚本的PDF

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os

# 尝试加载中文字体
try:
    pdfmetrics.registerFont(TTFont('SimSun', '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc'))
    FONT_NAME = 'SimSun'
except:
    FONT_NAME = 'Helvetica'

def create_pdf(script_file, title, output_pdf):
    doc = SimpleDocTemplate(
        output_pdf,
        pagesize=A4,
        rightMargin=1.5*cm,
        leftMargin=1.5*cm,
        topMargin=1.5*cm,
        bottomMargin=1.5*cm
    )

    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name='CodeBlock',
        fontName='Courier',
        fontSize=8,
        leading=10,
        leftIndent=0,
    ))
    styles.add(ParagraphStyle(
        name='TitleCn',
        fontName=FONT_NAME,
        fontSize=16,
        leading=20,
        alignment=TA_LEFT,
    ))

    story = []

    # 标题
    story.append(Paragraph(f"<b>{title}</b>", styles['TitleCn']))
    story.append(Spacer(1, 0.5*cm))

    # 读取脚本内容
    with open(script_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 分行处理，保持代码格式
    for line in content.split('\n'):
        # 转义HTML特殊字符
        line = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        story.append(Paragraph(line, styles['CodeBlock']))

    doc.build(story)
    print(f"生成: {output_pdf}")

# 脚本列表
scripts = [
    ('/workspace/linux_course_design/script1_user_manage.sh', '题目一：用户管理系统', '/workspace/linux_course_design/题目一_用户管理系统.pdf'),
    ('/workspace/linux_course_design/script2_file_operation.sh', '题目二：文件操作系统', '/workspace/linux_course_design/题目二_文件操作系统.pdf'),
    ('/workspace/linux_course_design/script3_mysql_config.sh', '题目三：MySQL配置', '/workspace/linux_course_design/题目三_MySQL配置.pdf'),
    ('/workspace/linux_course_design/script4_tomcat_config.sh', '题目四：Tomcat配置', '/workspace/linux_course_design/题目四_Tomcat配置.pdf'),
    ('/workspace/linux_course_design/script5_project_deploy.sh', '题目五：项目部署', '/workspace/linux_course_design/题目五_项目部署.pdf'),
]

for script_file, title, output_pdf in scripts:
    create_pdf(script_file, title, output_pdf)

print("\n全部PDF生成完成！")
