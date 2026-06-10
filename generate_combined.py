#!/usr/bin/env python3
# 5个Shell脚本合并为一个PDF

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

try:
    pdfmetrics.registerFont(TTFont('SimSun', '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc'))
    FONT_NAME = 'SimSun'
except:
    FONT_NAME = 'Helvetica'

def create_combined_pdf(output_pdf):
    doc = SimpleDocTemplate(
        output_pdf,
        pagesize=A4,
        rightMargin=1.5*cm,
        leftMargin=1.5*cm,
        topMargin=2*cm,
        bottomMargin=1.5*cm
    )

    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name='CodeBlock',
        fontName='Courier',
        fontSize=7.5,
        leading=9.5,
        leftIndent=0,
    ))
    styles.add(ParagraphStyle(
        name='TitleCn',
        fontName=FONT_NAME,
        fontSize=14,
        leading=18,
        alignment=TA_LEFT,
        spaceAfter=8,
    ))
    styles.add(ParagraphStyle(
        name='SubTitleCn',
        fontName=FONT_NAME,
        fontSize=11,
        leading=14,
        alignment=TA_LEFT,
        spaceBefore=12,
        spaceAfter=6,
    ))

    story = []

    # 封面标题
    story.append(Spacer(1, 3*cm))
    story.append(Paragraph("<b>Linux系统开发课程设计</b>", styles['TitleCn']))
    story.append(Paragraph("源码文档", styles['TitleCn']))
    story.append(Spacer(1, 0.3*cm))
    story.append(Paragraph("学号：20231035109", styles['TitleCn']))
    story.append(Paragraph("姓名：彭子阳", styles['TitleCn']))
    story.append(PageBreak())

    scripts = [
        ('/workspace/linux_course_design/script1_user_manage.sh', '题目一：用户管理系统'),
        ('/workspace/linux_course_design/script2_file_operation.sh', '题目二：文件操作系统'),
        ('/workspace/linux_course_design/script3_mysql_config.sh', '题目三：MySQL安装与配置'),
        ('/workspace/linux_course_design/script4_tomcat_config.sh', '题目四：Tomcat安装与配置'),
        ('/workspace/linux_course_design/script5_project_deploy.sh', '题目五：Web项目部署'),
    ]

    for i, (script_file, title) in enumerate(scripts):
        # 题目标题
        story.append(Paragraph(f"<b>{title}</b>", styles['SubTitleCn']))
        story.append(Spacer(1, 0.3*cm))

        with open(script_file, 'r', encoding='utf-8') as f:
            content = f.read()

        for line in content.split('\n'):
            line = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            if not line:
                line = " "
            story.append(Paragraph(line, styles['CodeBlock']))

        # 每个题目之间加分页（最后一个不加）
        if i < len(scripts) - 1:
            story.append(PageBreak())

    doc.build(story)
    print(f"生成完成: {output_pdf}")

create_combined_pdf('/workspace/linux_course_design/20231035109_彭子阳_全部源码.pdf')
