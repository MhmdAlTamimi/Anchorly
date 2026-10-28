# reMarkable Paper Pro planner

An undated, grayscale planner built around one workflow: **capture deadlines → map the month → block study/work time in the week → tick it off.**

| Page | What it's for |
|---|---|
| **Start here** | How the pages fit together, a subject key (1–2 letter codes for X, Y…), and a 5-step weekly reset |
| **Month** | 6×7 grid (Sunday first) with a box in each cell for the date, a week-number column, key deadlines and goals |
| **Deadlines** | The inbox: every deadline goes here the moment you hear about it. Columns: Done, Due, Deadline, Subject, Priority, Estimated hours, Planned |
| **Week** | The main planning view: a DUE strip for hand-ins, then a 07:00–23:00 hour grid (dotted half hours) to block sessions into, plus this week's deadlines and focus |

## Files

- `output/planner-pack-3-months.pdf` has the Start page, then **Month → Deadlines → 5 × Week** for each of 3 months (22 pages). It also has a PDF table of contents ("Month 2 › Week 3").
- `output/pages/*.pdf` holds each page on its own.
- `output/png/*.png` holds the same pages at the Paper Pro's native 1620×2160, 8-bit grayscale, for custom-template tools.

## Getting it onto the tablet

Drag the PDF into the reMarkable desktop app, upload it at my.remarkable.com, or send it from the mobile app. The page is sized to the Paper Pro screen (179.7 × 239.6 mm, 3:4), so it fills the display with no zoom or letterboxing.

## Rebuilding / customising

```sh
pip install reportlab          # pillow is optional, for grayscale PNGs
python3 build.py               # defaults: 3 months, 07–23, Sunday start
python3 build.py --months 6 --start-hour 6 --end-hour 24
python3 build.py --week-start mon
```

PNGs need `pdftoppm` (poppler). Layout constants (margins, row heights, grays) are at the top of `build.py`.

Fonts: Inter (SIL OFL 1.1, see `fonts/OFL.txt`), converted to TrueType so reportlab can embed it. Without the font files the script falls back to Helvetica.
