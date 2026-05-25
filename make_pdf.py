from fpdf import FPDF
from pathlib import Path
import re

md_path  = Path(r"c:\Users\samri\Downloads\ingestion\BCP_INGESTION_PIPELINE_DEVOPS_REFERENCE.md")
pdf_path = Path(r"c:\Users\samri\Downloads\ingestion\BCP_INGESTION_PIPELINE_DEVOPS_REFERENCE.pdf")

FONT_DIR = r"C:\Windows\Fonts"

def clean(text):
    """Strip markdown syntax and normalise special chars."""
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'\*(.+?)\*',     r'\1', text)
    text = re.sub(r'`([^`]+)`',     r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    text = text.replace('—', '-').replace('–', '-') \
               .replace('’', "'").replace('“', '"').replace('”', '"') \
               .replace('•', '*').replace('≠', '!=').replace('→', '->') \
               .replace('✔', '[x]').replace('☐', '[ ]').replace('☑', '[x]') \
               .replace('⚠', '(!)')
    return text

class PDF(FPDF):
    def header(self):
        if self.page_no() > 1:
            self.set_font("Arial", "I", 7.5)
            self.set_text_color(130, 130, 130)
            self.cell(0, 5, "BCP Ingestion Pipeline -- Deployment Reference for DevOps", ln=False)
            self.set_x(-20)
            self.cell(0, 5, f"Page {self.page_no()}", align="R", ln=True)
            self.set_draw_color(210, 210, 210)
            self.line(12, self.get_y(), 198, self.get_y())
            self.ln(3)

    def footer(self):
        self.set_y(-13)
        self.set_font("Arial", "I", 7)
        self.set_text_color(160, 160, 160)
        self.cell(0, 5, "Confidential -- Equities First BCP  |  Samriddha Roy  |  2026-05-06", align="C")

pdf = PDF()
pdf.set_auto_page_break(auto=True, margin=20)
pdf.set_margins(12, 14, 12)
pdf.add_font("Arial",  "",  f"{FONT_DIR}\\arial.ttf",   uni=True)
pdf.add_font("Arial",  "B", f"{FONT_DIR}\\arialbd.ttf", uni=True)
pdf.add_font("Arial",  "I", f"{FONT_DIR}\\ariali.ttf",  uni=True)
pdf.add_font("Courier","",  f"{FONT_DIR}\\couri.ttf",   uni=True)
pdf.add_page()

lines = md_path.read_text(encoding="utf-8").splitlines()

in_code    = False
code_buf   = []
table_rows = []
i = 0

def flush_table(pdf, rows):
    real = [r for r in rows if not re.match(r'^\|[-| :]+\|$', r.strip())]
    if not real:
        return
    pdf.ln(2)
    col_count = max(r.count("|") - 1 for r in real)
    if col_count < 1:
        return
    usable = 186.0
    col_w  = usable / col_count

    for ridx, row in enumerate(real):
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        cells = cells[:col_count]
        while len(cells) < col_count:
            cells.append("")
        cells = [clean(c) for c in cells]

        if ridx == 0:
            pdf.set_fill_color(27, 79, 114)
            pdf.set_text_color(255, 255, 255)
            pdf.set_font("Arial", "B", 8)
        elif ridx % 2 == 0:
            pdf.set_fill_color(234, 244, 251)
            pdf.set_text_color(25, 25, 25)
            pdf.set_font("Arial", "", 8)
        else:
            pdf.set_fill_color(255, 255, 255)
            pdf.set_text_color(25, 25, 25)
            pdf.set_font("Arial", "", 8)

        x0 = pdf.get_x()
        y0 = pdf.get_y()

        # Calculate row height
        max_lines = 1
        for c in cells:
            n = max(1, len(pdf.multi_cell(col_w, 4.5, c, dry_run=True, output="LINES")))
            max_lines = max(max_lines, n)
        rh = max_lines * 4.5

        if y0 + rh > pdf.page_break_trigger:
            pdf.add_page()
            x0 = pdf.get_x()
            y0 = pdf.get_y()
            if ridx > 0:
                # reprint header style
                pdf.set_fill_color(27, 79, 114)
                pdf.set_text_color(255, 255, 255)
                pdf.set_font("Arial", "B", 8)
                hr = real[0]
                hcells = [clean(c.strip()) for c in hr.strip().strip("|").split("|")][:col_count]
                while len(hcells) < col_count: hcells.append("")
                hx, hy = pdf.get_x(), pdf.get_y()
                for ci, hc in enumerate(hcells):
                    pdf.set_xy(hx + ci*col_w, hy)
                    pdf.multi_cell(col_w, 4.5, hc, border=1, fill=True)
                pdf.set_xy(hx, hy + 4.5)
                y0 = pdf.get_y()
                # Restore row style
                if ridx % 2 == 0:
                    pdf.set_fill_color(234, 244, 251)
                else:
                    pdf.set_fill_color(255, 255, 255)
                pdf.set_text_color(25, 25, 25)
                pdf.set_font("Arial", "", 8)

        for ci, cell in enumerate(cells):
            pdf.set_xy(x0 + ci*col_w, y0)
            pdf.multi_cell(col_w, 4.5, cell, border=1, fill=True)

        pdf.set_xy(x0, y0 + rh)

    pdf.ln(3)
    pdf.set_text_color(25, 25, 25)

while i < len(lines):
    line = lines[i]

    # ── Code fence ──────────────────────────────────────────────────
    if line.strip().startswith("```"):
        if not in_code:
            in_code  = True
            code_buf = []
        else:
            in_code = False
            if code_buf:
                pdf.ln(2)
                pdf.set_fill_color(30, 39, 46)
                pdf.set_text_color(215, 219, 221)
                pdf.set_font("Courier", "", 7.5)
                for cl in code_buf:
                    pdf.set_x(12)
                    pdf.multi_cell(0, 4.5, cl if cl else " ", fill=True)
                code_buf = []
                pdf.set_text_color(25, 25, 25)
                pdf.ln(2)
        i += 1
        continue

    if in_code:
        code_buf.append(line)
        i += 1
        continue

    # ── Table row ───────────────────────────────────────────────────
    if line.strip().startswith("|"):
        table_rows.append(line)
        i += 1
        continue
    elif table_rows:
        flush_table(pdf, table_rows)
        table_rows = []
        # fall through to process current line

    # ── Blockquote ──────────────────────────────────────────────────
    if line.startswith(">"):
        content = clean(re.sub(r'^>\s*', '', line))
        pdf.ln(1)
        pdf.set_fill_color(253, 237, 236)
        pdf.set_text_color(120, 40, 40)
        pdf.set_font("Arial", "I", 8.5)
        pdf.set_x(12)
        pdf.multi_cell(0, 5, "  (!) " + content, fill=True)
        pdf.set_text_color(25, 25, 25)
        pdf.ln(1)
        i += 1
        continue

    # ── Headings ────────────────────────────────────────────────────
    if re.match(r'^# [^#]', line):
        pdf.ln(4)
        pdf.set_font("Arial", "B", 17)
        pdf.set_text_color(13, 27, 42)
        pdf.multi_cell(0, 9, clean(line[2:]))
        pdf.set_draw_color(13, 27, 42)
        pdf.set_line_width(0.7)
        pdf.line(12, pdf.get_y(), 198, pdf.get_y())
        pdf.set_line_width(0.2)
        pdf.ln(5)
        pdf.set_text_color(25, 25, 25)

    elif re.match(r'^## [^#]', line):
        pdf.ln(5)
        pdf.set_font("Arial", "B", 12)
        pdf.set_text_color(27, 79, 114)
        pdf.multi_cell(0, 7, clean(line[3:]))
        pdf.set_draw_color(174, 214, 241)
        pdf.line(12, pdf.get_y(), 198, pdf.get_y())
        pdf.set_line_width(0.2)
        pdf.ln(3)
        pdf.set_text_color(25, 25, 25)

    elif re.match(r'^### [^#]', line):
        pdf.ln(3)
        pdf.set_font("Arial", "B", 10.5)
        pdf.set_text_color(31, 97, 141)
        pdf.multi_cell(0, 6, clean(line[4:]))
        pdf.ln(2)
        pdf.set_text_color(25, 25, 25)

    elif re.match(r'^#### ', line):
        pdf.ln(2)
        pdf.set_font("Arial", "B", 9.5)
        pdf.set_text_color(50, 50, 50)
        pdf.multi_cell(0, 5.5, clean(line[5:]))
        pdf.ln(1)
        pdf.set_text_color(25, 25, 25)

    # ── HR ──────────────────────────────────────────────────────────
    elif line.strip() == "---":
        pdf.ln(3)
        pdf.set_draw_color(200, 200, 200)
        pdf.line(12, pdf.get_y(), 198, pdf.get_y())
        pdf.ln(3)

    # ── Checklist ───────────────────────────────────────────────────
    elif line.startswith("- [ ] ") or line.startswith("- [x] "):
        tick = "[x]" if "x]" in line[:6] else "[ ]"
        pdf.set_font("Arial", "", 9)
        pdf.set_x(16)
        pdf.multi_cell(0, 5.2, tick + "  " + clean(line[6:]))

    # ── Bullet ──────────────────────────────────────────────────────
    elif re.match(r'^- ', line):
        pdf.set_font("Arial", "", 9)
        pdf.set_x(16)
        pdf.multi_cell(0, 5.2, "*  " + clean(line[2:]))

    elif re.match(r'^\s{2,}- ', line):
        pdf.set_font("Arial", "", 8.5)
        pdf.set_x(22)
        pdf.multi_cell(0, 5, "- " + clean(line.lstrip().lstrip("- ")))

    # ── Numbered list ───────────────────────────────────────────────
    elif re.match(r'^\d+\. ', line):
        pdf.set_font("Arial", "", 9)
        pdf.set_x(16)
        pdf.multi_cell(0, 5.2, clean(line))

    # ── Empty ───────────────────────────────────────────────────────
    elif line.strip() == "":
        pdf.ln(2)

    # ── Normal paragraph ────────────────────────────────────────────
    else:
        pdf.set_font("Arial", "", 9)
        pdf.set_x(12)
        pdf.multi_cell(0, 5.2, clean(line))

    i += 1

# flush any trailing table
if table_rows:
    flush_table(pdf, table_rows)

pdf.output(str(pdf_path))
kb = pdf_path.stat().st_size / 1024
print(f"Done: {pdf_path}")
print(f"Pages: {pdf.page}  |  Size: {kb:.0f} KB")
