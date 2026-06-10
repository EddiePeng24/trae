#!/usr/bin/env python3
# 5个Shell脚本合并为一个PDF（无中文字体版本）

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT

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
        name='TitleEn',
        fontName='Helvetica-Bold',
        fontSize=16,
        leading=20,
        alignment=TA_LEFT,
        spaceAfter=8,
    ))
    styles.add(ParagraphStyle(
        name='SubTitleEn',
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=15,
        alignment=TA_LEFT,
        spaceBefore=12,
        spaceAfter=6,
    ))
    styles.add(ParagraphStyle(
        name='Info',
        fontName='Helvetica',
        fontSize=11,
        leading=14,
        alignment=TA_LEFT,
        spaceAfter=4,
    ))

    story = []

    # Cover page
    story.append(Spacer(1, 3*cm))
    story.append(Paragraph("<b>Linux System Development Course Design</b>", styles['TitleEn']))
    story.append(Paragraph("Source Code Document", styles['TitleEn']))
    story.append(Spacer(1, 0.5*cm))
    story.append(Paragraph("Student ID: 20231035109", styles['Info']))
    story.append(Paragraph("Name: Peng Ziyang", styles['Info']))
    story.append(PageBreak())

    scripts = [
        ('/workspace/linux_course_design/script1_user_manage.sh', 'Problem 1: User Management System'),
        ('/workspace/linux_course_design/script2_file_operation.sh', 'Problem 2: File Operation System'),
        ('/workspace/linux_course_design/script3_mysql_config.sh', 'Problem 3: MySQL Installation & Configuration'),
        ('/workspace/linux_course_design/script4_tomcat_config.sh', 'Problem 4: Tomcat Installation & Configuration'),
        ('/workspace/linux_course_design/script5_project_deploy.sh', 'Problem 5: Web Project Deployment'),
    ]

    for i, (script_file, title) in enumerate(scripts):
        story.append(Paragraph(f"<b>{title}</b>", styles['SubTitleEn']))
        story.append(Spacer(1, 0.3*cm))

        with open(script_file, 'r', encoding='utf-8') as f:
            content = f.read()

        line_num = 0
        for line in content.split('\n'):
            line_num += 1
            # Escape HTML special chars
            escaped = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            # Show line numbers
            display = f"{line_num:>4}  {escaped}"
            if not line:
                display = " "
            story.append(Paragraph(display, styles['CodeBlock']))

        if i < len(scripts) - 1:
            story.append(PageBreak())

    doc.build(story)
    print(f"Done: {output_pdf}")

create_combined_pdf('/workspace/linux_course_design/20231035109_彭子阳_全部源码.pdf')
