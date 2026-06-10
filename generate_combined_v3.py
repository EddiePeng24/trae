#!/usr/bin/env python3
# 5个Shell脚本合并PDF - 中文支持版

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# 注册中文字体
pdfmetrics.registerFont(TTFont('WQY', '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc', subfontIndex=0))

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
        fontSize=7,
        leading=9,
        leftIndent=0,
    ))
    styles.add(ParagraphStyle(
        name='TitleCn',
        fontName='WQY',
        fontSize=16,
        leading=20,
        alignment=TA_LEFT,
        spaceAfter=8,
    ))
    styles.add(ParagraphStyle(
        name='SubTitleCn',
        fontName='WQY',
        fontSize=12,
        leading=15,
        alignment=TA_LEFT,
        spaceBefore=12,
        spaceAfter=6,
    ))
    styles.add(ParagraphStyle(
        name='InfoCn',
        fontName='WQY',
        fontSize=11,
        leading=14,
        alignment=TA_LEFT,
        spaceAfter=4,
    ))

    story = []

    # 封面
    story.append(Spacer(1, 3*cm))
    story.append(Paragraph("<b>Linux系统开发课程设计</b>", styles['TitleCn']))
    story.append(Paragraph("源码文档", styles['TitleCn']))
    story.append(Spacer(1, 0.5*cm))
    story.append(Paragraph("学号：20231035109", styles['InfoCn']))
    story.append(Paragraph("姓名：彭子阳", styles['InfoCn']))
    story.append(PageBreak())

    scripts = [
        ('/workspace/linux_course_design/script1_user_manage.sh', '题目一：用户管理系统'),
        ('/workspace/linux_course_design/script2_file_operation.sh', '题目二：文件操作系统'),
        ('/workspace/linux_course_design/script3_mysql_config.sh', '题目三：MySQL安装与配置'),
        ('/workspace/linux_course_design/script4_tomcat_config.sh', '题目四：Tomcat安装与配置'),
        ('/workspace/linux_course_design/script5_project_deploy.sh', '题目五：Web项目部署'),
    ]

    for i, (script_file, title) in enumerate(scripts):
        story.append(Paragraph(f"<b>{title}</b>", styles['SubTitleCn']))
        story.append(Spacer(1, 0.3*cm))

        with open(script_file, 'r', encoding='utf-8') as f:
            content = f.read()

        for line in content.split('\n'):
            escaped = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            if not line:
                escaped = " "
            story.append(Paragraph(escaped, styles['CodeBlock']))

        if i < len(scripts) - 1:
            story.append(PageBreak())

    doc.build(story)
    print(f"Done: {output_pdf}")

create_combined_pdf('/workspace/linux_course_design/20231035109_彭子阳_全部源码.pdf')
