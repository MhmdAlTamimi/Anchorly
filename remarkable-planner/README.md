# reMarkable Paper Pro planner

An undated, grayscale, **reusable** 4-page planner. You don't flip forward to new pages; you clear and reuse the same ones:

| Page | What it's for | Clear it… |
|---|---|---|
| **Cover** | Minimal title page ("Monthly Calendar") | never |
| **Month** | 6×7 grid (Sunday first) with a box in each cell for the date, a week-number column, key deadlines and goals | at the start of each month |
| **Week** | The main planning view: a DUE strip for hand-ins, then a 07:00–23:00 hour grid (dotted half hours) to block study/work sessions into, plus this week's deadlines and focus | at the start of each week |
| **Deadlines** | The inbox: every deadline goes here the moment you hear about it. Columns: Done, Due, Deadline, Subject, Priority, Estimated hours, Planned | when it fills up (cross off done rows) |

The Deadlines page is what makes clearing safe. Anything that isn't finished or isn't due yet lives there, so clearing the Week page loses nothing.

## Weekly reset

1. Copy anything unfinished on the Week page into **Deadlines**.
2. Clear the Week page (on the tablet: the eraser's clear-page option).
3. Copy this week's due dates from Deadlines into the **DUE** strip.
4. Block sessions in the hour grid, then tick **Planned** in the tracker.

## Files

- `output/monthly-calendar.pdf` is the 4-page pack to put on the tablet.
- `output/pages/*.pdf` holds each page on its own.
- `output/png/*.png` holds the same pages at the Paper Pro's native 1620×2160, 8-bit grayscale, for custom-template tools.

## Getting it onto the tablet

Drag the PDF into the reMarkable desktop app, upload it at my.remarkable.com, or send it from the mobile app. The page is sized to the Paper Pro screen (179.7 × 239.6 mm, 3:4), so it fills the display with no zoom or letterboxing.

## Rebuilding / customising

```sh
pip install reportlab          # pillow is optional, for grayscale PNGs
python3 build.py               # defaults: "Monthly Calendar", 07–23, Sunday start
python3 build.py --title "Term Planner" --start-hour 6 --end-hour 24 --week-start mon
```

PNGs need `pdftoppm` (poppler). Layout constants (margins, row heights, grays) are at the top of `build.py`.

Fonts: Inter (SIL OFL 1.1, see `fonts/OFL.txt`), converted to TrueType so reportlab can embed it. Without the font files the script falls back to Helvetica.
