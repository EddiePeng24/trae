#!/usr/bin/env python3
# 生成形势与政策报告HTML打印版

import html

input_file = '/workspace/linux_course_design/形势与政策报告.md'
output_file = '/workspace/linux_course_design/形势与政策报告_打印版.html'

with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

escaped = html.escape(content)
# Convert markdown headers to HTML
lines = escaped.split('\n')
html_lines = []
in_code_block = False
in_table = False

for line in lines:
    stripped = line.strip()
    
    # Code blocks (```)
    if stripped.startswith('```'):
        if not in_code_block:
            html_lines.append('<pre style="font-family:Consolas,Courier New,monospace;font-size:7pt;line-height:1.35;background:#f5f5f5;padding:8px;border:1px solid #ddd;white-space:pre-wrap;word-break:break-all;">')
            in_code_block = True
        else:
            html_lines.append('</pre>')
            in_code_block = False
        continue
    
    if in_code_block:
        html_lines.append(line)
        continue
    
    # Horizontal rules
    if stripped == '---':
        html_lines.append('<hr style="border:none;border-top:1px solid #ccc;margin:15px 0;">')
        continue
    
    # Headers
    if stripped.startswith('# '):
        html_lines.append(f'<h1 style="font-size:18px;font-weight:bold;margin:20px 0 10px;color:#1a1a1a;">{stripped[2:]}</h1>')
        continue
    if stripped.startswith('## '):
        html_lines.append(f'<h2 style="font-size:15px;font-weight:bold;margin:18px 0 8px;color:#333;border-left:4px solid #4a90d9;padding-left:10px;">{stripped[3:]}</h2>')
        continue
    if stripped.startswith('### '):
        html_lines.append(f'<h3 style="font-size:13px;font-weight:bold;margin:14px 0 6px;color:#444;">{stripped[4:]}</h3>')
        continue
    if stripped.startswith('#### '):
        html_lines.append(f'<h4 style="font-size:11.5px;font-weight:bold;margin:12px 0 5px;color:#555;">{stripped[5:]}</h4>')
        continue
    
    # Bold
    if stripped.startswith('**') and stripped.endswith('**'):
        html_lines.append(f'<p style="font-size:10pt;line-height:1.7;margin:6px 0;"><b>{stripped[2:-2]}</b></p>')
        continue
    
    # Table rows
    if '|' in stripped and not in_table:
        in_table = True
        html_lines.append('<table style="width:100%;border-collapse:collapse;font-size:8.5pt;margin:8px 0;">')
    if in_table:
        if '|-' in stripped or '-|' in stripped:
            continue  # skip separator lines
        cells = [c.strip() for c in stripped.split('|')]
        cells = [c for c in cells if c]  # remove empty
        if cells:
            tag = 'th' if all(c.startswith('**') for c in cells) else 'td'
            clean_cells = [c.replace('**','') for c in cells]
            cell_html = ''.join([f'<{tag} style="border:1px solid #ddd;padding:5px;text-align:left;">{c}</{tag}>' for c in clean_cells])
            html_lines.append(f'<tr>{cell_html}</tr>')
        continue
    elif in_table and '|' not in stripped:
        html_lines.append('</table>')
        in_table = False
    
    # Regular paragraphs
    if stripped:
        html_lines.append(f'<p style="font-size:10pt;line-height:1.75;margin:5px 0;text-align:justify;text-indent:2em;">{stripped}</p>')
    else:
        html_lines.append('<br>')

with open(output_file, 'w', encoding='utf-8') as f:
    f.write('''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>形势与政策学习报告</title>
<style>
@page { size: A4; margin: 2cm; }
body { font-family:"Microsoft YaHei","PingFang SC","Noto Sans CJK SC","SimSun",serif;
       color:#222; padding:20px; max-width:210mm; margin:0 auto; }
h1 { page-break-before: always; }
h1:first-of-type { page-break-before: auto; }
table { page-break-inside: avoid; }
pre { page-break-inside: avoid; }
</style></head><body>\n''')
    f.write('\n'.join(html_lines))
    f.write('\n</body></html>')

print(f"Done: {output_file}")
