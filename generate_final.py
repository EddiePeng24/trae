#!/usr/bin/env python3
# 5个Shell脚本合并PDF - 全部用中文字体，彻底解决黑点

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# 注册中文字体（支持中文+英文）
pdfmetrics.registerFont(TTFont('WQY', '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc', subfontIndex=0))

def create_combined_pdf(output_pdf):
    doc = SimpleDocTemplate(
        output_pdf,
        pagesize=A4,
        rightMargin=1.5*cm,
        leftMargin=1.5*cm,
        topMargin=2*cm,
        bottomMargin=1.5*cm,
    )

    styles = getSampleStyleSheet()

    # 所有文字都用中文字体（支持中英文混排）
    styles.add(ParagraphStyle(
        name='CodeBlock',
        fontName='WQY',           # 关键：全部用中文字体
        fontSize=7,
        leading=9,
        leftIndent=0,
    ))
    styles.add(ParagraphStyle(
        name='TitleCn',
        fontName='WQY',
        fontSize=18,
        leading=24,
        alignment=TA_LEFT,
        spaceAfter=8,
    ))
    styles.add(ParagraphStyle(
        name='SubTitleCn',
        fontName='WQY',
        fontSize=13,
        leading=17,
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
    story.append(Spacer(1, 0.8*cm))
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
        # 题目标题
        story.append(Paragraph(f"<b>{title}</b>", styles['SubTitleCn']))
        story.append(Spacer(1, 0.3*cm))

        # 读取脚本内容
        with open(script_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # 每一行都用中文字体渲染
        for line in content.split('\n'):
            escaped = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            if not escaped.strip():
                escaped = "&nbsp;"
            story.append(Paragraph(escaped, styles['CodeBlock']))

        # 分页
        if i < len(scripts) - 1:
            story.append(PageBreak())

    doc.build(story)
    print(f"Done: {output_pdf}")

create_combined_pdf('/workspace/linux_course_design/20231035109_彭子阳_全部源码.pdf')
