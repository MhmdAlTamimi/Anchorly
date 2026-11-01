#!/usr/bin/env python3
"""Undated planner templates for the reMarkable Paper Pro.

A four-page reusable pack (Cover, Month, time-block Week, Deadline tracker):
clear the Week page each week and the Month page each month. Each page is also
written as its own PDF and as a native-size PNG.

    python3 build.py
    python3 build.py --title "Term Planner" --start-hour 6 --end-hour 24 --week-start mon

Needs reportlab (pip install reportlab). PNGs also need pdftoppm (poppler).
"""

import argparse
import shutil
import subprocess
from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

HERE = Path(__file__).resolve().parent

# The Paper Pro screen is 1620 x 2160 px at 229 PPI. Sizing the page to the
# physical screen keeps it 1:1 on the device: 1 mm here is 1 mm under the pen.
PPI = 229
SCREEN_PX = (1620, 2160)
PAGE_W = SCREEN_PX[0] / PPI * 72
PAGE_H = SCREEN_PX[1] / PPI * 72

# Every y in this file is measured from the TOP of the page (reportlab's own
# origin is bottom-left; Y() converts at the last moment).
MARGIN_X = 9 * mm
MARGIN_TOP = 9 * mm
MARGIN_BOTTOM = 8 * mm
CONTENT_W = PAGE_W - 2 * MARGIN_X
CONTENT_TOP = MARGIN_TOP + 17 * mm
CONTENT_BOTTOM = PAGE_H - MARGIN_BOTTOM
LEFT, RIGHT = MARGIN_X, PAGE_W - MARGIN_X
GUTTER = 9 * mm  # left column: week numbers on Month, hours on Week
DAY_W = (CONTENT_W - GUTTER) / 7
ROW = 7 * mm  # handwriting line pitch

# Grayscale only. Lines stay light so your ink is always the darkest thing.
INK = HexColor("#1a1a1a")
TEXT = HexColor("#4d4d4d")
MUTED = HexColor("#8c8c8c")
LINE = HexColor("#a3a3a3")
FAINT = HexColor("#c8c8c8")
FILL = HexColor("#efefef")
WEEKEND_FILL = HexColor("#e2e2e2")

DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
WEEKEND = {"Sat", "Sun"}

FONT_FILES = {
    "regular": ("Inter-Regular", "Helvetica"),
    "bold": ("Inter-SemiBold", "Helvetica-Bold"),
    "display": ("InterDisplay-SemiBold", "Helvetica-Bold"),
}
F = {}


def register_fonts():
    for role, (name, fallback) in FONT_FILES.items():
        path = HERE / "fonts" / f"{name}.ttf"
        if path.exists():
            pdfmetrics.registerFont(TTFont(name, str(path)))
            F[role] = name
        else:
            F[role] = fallback


# --- drawing primitives -----------------------------------------------------

def Y(y):
    return PAGE_H - y


def stroke(c, color=LINE, width=0.6, dash=None):
    c.setStrokeColor(color)
    c.setLineWidth(width)
    c.setDash(dash or [])


def hline(c, x1, x2, y, **style):
    stroke(c, **style)
    c.line(x1, Y(y), x2, Y(y))


def vline(c, x, y1, y2, **style):
    stroke(c, **style)
    c.line(x, Y(y1), x, Y(y2))


def rect(c, x, y, w, h, fill=None, radius=0, **style):
    """Rectangle by its top-left corner; stroked only when a style is given."""
    if style:
        stroke(c, **style)
    if fill is not None:
        c.setFillColor(fill)
    flags = dict(stroke=1 if style else 0, fill=1 if fill is not None else 0)
    if radius:
        c.roundRect(x, Y(y + h), w, h, radius, **flags)
    else:
        c.rect(x, Y(y + h), w, h, **flags)


def text(c, x, y, s, size=8, font="regular", color=TEXT, align="left", spacing=0):
    """Draw s with its baseline at y and return its width."""
    w = pdfmetrics.stringWidth(s, F[font], size) + spacing * max(len(s) - 1, 0)
    if align == "center":
        x -= w / 2
    elif align == "right":
        x -= w
    t = c.beginText(x, Y(y))
    t.setFont(F[font], size)
    t.setCharSpace(spacing)
    t.setFillColor(color)
    t.textOut(s)
    c.drawText(t)
    return w


def label(c, x, y, s, size=6.5, color=MUTED, align="left"):
    """Small letterspaced caps: the voice of every printed label."""
    return text(c, x, y, s.upper(), size, "bold", color, align, spacing=0.8)


def checkbox(c, x, y, size=3.6 * mm):
    rect(c, x, y, size, size, radius=0.7 * mm, color=LINE, width=0.6)


def header(c, title, fields):
    """Title on the left; write-in fields right-aligned on the same baseline."""
    base = MARGIN_TOP + 9 * mm
    text(c, LEFT, base, title, 20, "display", INK)
    x = RIGHT
    for name, width in reversed(fields):
        hline(c, x - width, x, base + 0.6 * mm, color=LINE)
        x -= width + 2 * mm
        x -= label(c, x, base, name, align="right") + 5 * mm
    hline(c, LEFT, RIGHT, MARGIN_TOP + 13 * mm, color=INK, width=0.9)


def panel_title(c, x, y, w, title, note=None):
    """Caps title with a rule under it; returns the y of the rule."""
    label(c, x, y + 3 * mm, title, color=TEXT)
    if note:
        label(c, x + w, y + 3 * mm, note, align="right")
    hline(c, x, x + w, y + 4.6 * mm, color=TEXT, width=0.6)
    return y + 4.6 * mm


def write_lines(c, x, y, w, bottom, pitch=ROW):
    """Writing lines below y down to bottom; returns their y positions."""
    ys = []
    y += pitch
    while y <= bottom + 0.01:
        hline(c, x, x + w, y, color=FAINT, width=0.5)
        ys.append(y)
        y += pitch
    return ys


def day_header(c, y, h, days, date_boxes):
    hline(c, LEFT, RIGHT, y, color=LINE, width=0.6)
    for i, day in enumerate(days):
        x = LEFT + GUTTER + i * DAY_W
        rect(c, x, y, DAY_W, h, fill=WEEKEND_FILL if day in WEEKEND else FILL)
        label(c, x + 1.8 * mm, y + h / 2 + 1.1 * mm, day, size=7, color=INK)
        if date_boxes:
            s = 5 * mm
            rect(c, x + DAY_W - s - 1.2 * mm, y + (h - s) / 2, s, s,
                 fill=HexColor("#ffffff"), radius=0.8 * mm, color=LINE, width=0.5)


def day_dividers(c, y1, y2):
    for i in range(8):
        x = LEFT + GUTTER + i * DAY_W
        vline(c, x, y1, y2, color=LINE, width=0.6 if 0 < i < 7 else 0.8)


# --- pages ------------------------------------------------------------------

def draw_week(c, days, start_hour, end_hour):
    """The main planning view: an hour grid to block study/work sessions into."""
    header(c, "Week", [("From", 24 * mm), ("To", 24 * mm), ("Wk", 9 * mm)])
    hdr_h, due_h, gap = 7 * mm, 11 * mm, 4 * mm
    panel_rows, panel_pitch = 4, 6.5 * mm  # kept short so a full day fits the grid
    panel_h = 4.6 * mm + panel_rows * panel_pitch
    gx = LEFT + GUTTER

    y = CONTENT_TOP
    day_header(c, y, hdr_h, days, date_boxes=True)
    y += hdr_h

    # The DUE strip is the one obvious place for "this is due today".
    rect(c, gx, y, RIGHT - gx, due_h, fill=HexColor("#f6f6f6"))
    label(c, gx - 1.5 * mm, y + due_h / 2 + 1.1 * mm, "Due", color=INK, align="right")
    grid_top = y + due_h
    hline(c, LEFT, RIGHT, grid_top, color=TEXT, width=0.8)

    grid_bottom = CONTENT_BOTTOM - panel_h - gap
    hours = end_hour - start_hour
    row = (grid_bottom - grid_top) / hours
    for i in range(hours):
        ry = grid_top + i * row
        hour = (start_hour + i) % 24
        if i:  # noon is drawn darker so you can find midday at a glance
            hline(c, LEFT, RIGHT, ry, color=TEXT if hour == 12 else LINE,
                  width=0.7 if hour == 12 else 0.5)
        hline(c, gx, RIGHT, ry + row / 2, color=FAINT, width=0.5, dash=[0.5, 1.5])
        text(c, gx - 1.5 * mm, ry + 2.7 * mm, f"{hour:02d}", 6.5, "regular", MUTED, "right")
    hline(c, LEFT, RIGHT, grid_bottom, color=TEXT, width=0.8)
    day_dividers(c, CONTENT_TOP, grid_bottom)
    vline(c, LEFT, CONTENT_TOP, grid_bottom, color=LINE, width=0.6)

    # Bottom: this week's deadlines (left) and focus (right).
    y = grid_bottom + gap
    lw = CONTENT_W * 0.6
    rx, rw = LEFT + lw + 6 * mm, CONTENT_W - lw - 6 * mm
    due_col = 16 * mm
    top = panel_title(c, LEFT, y, lw, "Deadlines this week", note="Due")
    ys = write_lines(c, LEFT, top, lw, CONTENT_BOTTOM, pitch=panel_pitch)
    for ly in ys:
        checkbox(c, LEFT, ly - 5 * mm)
    vline(c, LEFT + lw - due_col, top, ys[-1], color=FAINT, width=0.5)

    top = panel_title(c, rx, y, rw, "Focus")
    for n, ly in enumerate(write_lines(c, rx, top, rw, CONTENT_BOTTOM, pitch=panel_pitch), 1):
        if n <= 3:
            text(c, rx, ly - 1.3 * mm, str(n), 8, "bold", MUTED)


def draw_month(c, days):
    header(c, "Month", [("Month", 34 * mm), ("Year", 14 * mm)])
    hdr_h, panel_h = 6.5 * mm, 52 * mm

    y = CONTENT_TOP
    day_header(c, y, hdr_h, days, date_boxes=False)
    label(c, LEFT + GUTTER / 2, y + hdr_h / 2 + 1.1 * mm, "Wk", size=6, align="center")
    grid_top = y + hdr_h
    hline(c, LEFT, RIGHT, grid_top, color=TEXT, width=0.8)

    grid_bottom = CONTENT_BOTTOM - panel_h - 5 * mm
    row = (grid_bottom - grid_top) / 6  # six rows fit every month layout
    s = 4.6 * mm
    for r in range(6):
        ry = grid_top + r * row
        if r:
            hline(c, LEFT, RIGHT, ry, color=LINE, width=0.6)
        for i in range(7):
            # A small box for the date number keeps it from colliding with notes.
            rect(c, LEFT + GUTTER + i * DAY_W + 1.2 * mm, ry + 1.2 * mm, s, s,
                 radius=0.8 * mm, color=FAINT, width=0.5)
    hline(c, LEFT, RIGHT, grid_bottom, color=TEXT, width=0.8)
    day_dividers(c, CONTENT_TOP, grid_bottom)
    vline(c, LEFT, CONTENT_TOP, grid_bottom, color=LINE, width=0.6)

    y = grid_bottom + 5 * mm
    lw = CONTENT_W * 0.6
    rx, rw = LEFT + lw + 6 * mm, CONTENT_W - lw - 6 * mm
    date_col = 16 * mm
    top = panel_title(c, LEFT, y, lw, "Key deadlines", note="Date")
    ys = write_lines(c, LEFT, top, lw, CONTENT_BOTTOM)
    vline(c, LEFT + lw - date_col, top, ys[-1], color=FAINT, width=0.5)

    top = panel_title(c, rx, y, rw, "Goals")
    for n, ly in enumerate(write_lines(c, rx, top, rw, CONTENT_BOTTOM), 1):
        if n <= 3:
            text(c, rx, ly - 1.3 * mm, str(n), 8, "bold", MUTED)


DEADLINE_COLUMNS = [  # (label, width or None to take the rest, has checkbox)
    ("Done", 10 * mm, True),
    ("Due", 17 * mm, False),
    ("Deadline / deliverable", None, False),
    ("Subject", 27 * mm, False),
    ("Pri", 10 * mm, False),
    ("Est. h", 12 * mm, False),
    ("Planned", 15 * mm, True),
]


def draw_deadlines(c):
    """Inbox for every deadline, the moment you hear about it."""
    header(c, "Deadlines", [("For", 42 * mm)])
    text(c, LEFT, CONTENT_TOP + 0.5 * mm,
         "Capture it here the moment you hear it  →  block time for it on a Week page, "
         "tick Planned  →  tick Done", 7, color=MUTED)

    fixed = sum(w for _, w, _ in DEADLINE_COLUMNS if w)
    widths = [w or CONTENT_W - fixed for _, w, _ in DEADLINE_COLUMNS]
    xs = [LEFT + sum(widths[:i]) for i in range(len(widths) + 1)]

    y, hdr_h = CONTENT_TOP + 4.5 * mm, 7 * mm
    rect(c, LEFT, y, CONTENT_W, hdr_h, fill=FILL)
    hline(c, LEFT, RIGHT, y, color=LINE)
    for (name, _, centered), x, w in zip(DEADLINE_COLUMNS, xs, widths):
        if centered:
            label(c, x + w / 2, y + hdr_h / 2 + 1 * mm, name, size=6, color=INK, align="center")
        else:
            label(c, x + 1.8 * mm, y + hdr_h / 2 + 1 * mm, name, size=6, color=INK)
    top = y + hdr_h
    hline(c, LEFT, RIGHT, top, color=TEXT, width=0.8)

    rows = int((CONTENT_BOTTOM - top) // (8.5 * mm))
    row = (CONTENT_BOTTOM - top) / rows
    box = 3.8 * mm
    for r in range(rows):
        ry = top + (r + 1) * row
        last = r == rows - 1
        hline(c, LEFT, RIGHT, ry, color=TEXT if last else FAINT, width=0.8 if last else 0.5)
        for (_, _, has_box), x, w in zip(DEADLINE_COLUMNS, xs, widths):
            if has_box:
                checkbox(c, x + (w - box) / 2, ry - row / 2 - box / 2, box)
    for x in xs[1:-1]:
        vline(c, x, y, CONTENT_BOTTOM, color=FAINT, width=0.5)


def draw_cover(c, title, days):
    """Minimal cover: a stacked title, a short rule and what's inside."""
    size = 54
    y = PAGE_H * 0.36
    for word in title.split():
        text(c, LEFT, y, word, size, "display", INK)
        y += size * 1.02
    y -= size * 0.45
    hline(c, LEFT, LEFT + 22 * mm, y, color=INK, width=2)
    label(c, LEFT, y + 9 * mm, "Month  ·  Week  ·  Deadlines", size=8, color=TEXT)
    first = "Monday" if days[0] == "Mon" else "Sunday"
    label(c, LEFT, CONTENT_BOTTOM - 2 * mm, f"Undated  ·  weeks start {first}")


# --- output -----------------------------------------------------------------

def new_canvas(path, title):
    c = canvas.Canvas(str(path), pagesize=(PAGE_W, PAGE_H))
    c.setTitle(title)
    c.setAuthor("Anchorly")
    c.setSubject("Undated planner template for reMarkable Paper Pro")
    return c


def build(args):
    register_fonts()
    days = DAYS if args.week_start == "sun" else DAYS[1:] + DAYS[:1]
    pages = {
        "month": ("Month", lambda c: draw_month(c, days)),
        "week": ("Week", lambda c: draw_week(c, days, args.start_hour, args.end_hour)),
        "deadlines": ("Deadlines", draw_deadlines),
    }

    out = Path(args.out)
    (out / "pages").mkdir(parents=True, exist_ok=True)
    for key, (title, draw) in pages.items():
        c = new_canvas(out / "pages" / f"{key}.pdf", f"{args.title} – {title}")
        draw(c)
        c.save()

    # The pack holds one of each page and is reused: clear the Week page each
    # week and the Month page each month; Deadlines carries what's still ahead.
    pack = out / f"{args.title.lower().replace(' ', '-')}.pdf"
    c = new_canvas(pack, args.title)
    cover = ("Cover", lambda c: draw_cover(c, args.title, days))
    for title, draw in [cover, *pages.values()]:
        c.bookmarkPage(title)
        c.addOutlineEntry(title, title)
        draw(c)
        c.showPage()
    c.save()

    if shutil.which("pdftoppm"):
        (out / "png").mkdir(exist_ok=True)
        for key in pages:
            subprocess.run(
                ["pdftoppm", "-png", "-gray", "-singlefile",
                 "-scale-to-x", str(SCREEN_PX[0]), "-scale-to-y", str(SCREEN_PX[1]),
                 str(out / "pages" / f"{key}.pdf"), str(out / "png" / key)],
                check=True)
            try:  # some poppler builds ignore -gray for PNG output
                from PIL import Image
                png = out / "png" / f"{key}.png"
                Image.open(png).convert("L").save(png, optimize=True)
            except ImportError:
                pass
    print(f"Wrote {pack} and single pages to {out}")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--title", default="Monthly Calendar", help="title on the cover")
    p.add_argument("--start-hour", type=int, default=0, help="first hour on the Week grid")
    p.add_argument("--end-hour", type=int, default=24, help="hour the Week grid ends at")
    p.add_argument("--week-start", choices=["sun", "mon"], default="sun")
    p.add_argument("--out", default=str(HERE / "output"))
    build(p.parse_args())
