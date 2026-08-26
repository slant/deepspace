#!/usr/bin/env python3
"""Extract starmap hex coordinates from the official PDF into config/map.yml."""
import math
import re
import sys
from pathlib import Path

import fitz
import yaml

PDF = Path("public/docs/Deep Space D6 - The Long Way Home RPG v1.43.pdf")
OUT = Path("config/map.yml")

REGION = {
    "19-A": "tau", "20-C": "tau", "20-B": "tau", "20-A": "tau", "18-A": "tau", "18-B": "tau",
    "17-D": "alpha", "17-C": "alpha", "17-B": "alpha", "17-A": "alpha", "16-A": "alpha",
    "12-A": "alpha", "12-C": "alpha", "12-D": "alpha", "12-B": "alpha",
    "11-A": "alpha", "10-A": "alpha", "11-D": "alpha", "10-B": "alpha",
    "14-A": "zeta", "14-B": "zeta", "14-C": "zeta", "13-A": "zeta",
    "13-B": "beta", "13-C": "beta", "15-A": "beta", "15-B": "beta",
    "10-C": "delta", "11-C": "delta", "11-B": "delta",
}
ICONS = {
    "19-A": "home", "20-C": "square", "20-B": "square", "20-A": "square", "13-B": "jump",
}
CIRCLES = {
    "17-D", "17-C", "17-B", "17-A", "16-A", "12-A", "12-C", "12-D", "12-B",
    "11-A", "10-A", "11-D", "10-B", "11-B", "18-A",
}


def main():
    page = fitz.open(PDF)[7]
    event_re = re.compile(r"^\d{1,2}-[A-D]$")
    note_re = re.compile(r"^(\d{1,2})(?:-(\d{1,2}))?$")
    events, notes = [], []

    for b in page.get_text("dict")["blocks"]:
        if b.get("type") != 0:
            continue
        for line in b["lines"]:
            for span in line["spans"]:
                t = span["text"].strip()
                x0, y0, x1, y1 = span["bbox"]
                x, y = (x0 + x1) / 2, (y0 + y1) / 2
                if event_re.match(t):
                    events.append({"label": t, "x": x, "y": y})
                elif m := note_re.match(t):
                    note = f"{m.group(1)}-{m.group(2)}" if m.group(2) else m.group(1)
                    notes.append({"note": note, "x": x, "y": y})

    size = 41.5
    anchor = next(e for e in events if e["label"] == "19-A")
    ox = anchor["x"] - size * math.sqrt(3) * (2 + 0 / 2)
    oy = anchor["y"] - size * 1.5 * 0

    def pixel_to_axial(x, y):
        x, y = x - ox, y - oy
        r = y / (1.5 * size)
        q = x / (math.sqrt(3) * size) - r / 2
        return round(q), round(r)

    candidates = []
    for q in range(-5, 6):
        for r in range(-1, 12):
            px = size * math.sqrt(3) * (q + r / 2) + ox
            py = size * 1.5 * r + oy
            if 40 < px < 560 and 50 < py < 650:
                candidates.append((q, r, px, py))

    used = set()
    hexes = []
    for e in sorted(events, key=lambda x: x["y"]):
        best = min(
            ((px - e["x"]) ** 2 + (py - e["y"]) ** 2, q, r)
            for q, r, px, py in candidates
            if (q, r) not in used
        )
        _, q, r = best
        used.add((q, r))
        label = e["label"]
        h = {"q": q, "r": r, "label": label, "region": REGION.get(label, "alpha")}
        if label in ICONS:
            h["icon"] = ICONS[label]
        elif label in CIRCLES:
            h["icon"] = "circle"
        hexes.append(h)

    note_map = {}
    for n in notes:
        q, r = pixel_to_axial(n["x"], n["y"])
        note_map.setdefault((q, r), []).append(n["note"])

    for h in hexes:
        ns = note_map.get((h["q"], h["r"]), [])
        if ns:
            h["note"] = ns[0]

    assigned = {(h["q"], h["r"]) for h in hexes}
    for q, r in sorted(
        {(q + dq, r + dr) for q, r in assigned for dq, dr in [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]}
        - assigned
    ):
        px = size * math.sqrt(3) * (q + r / 2) + ox
        py = size * 1.5 * r + oy
        if 40 < px < 560 and 50 < py < 650:
            hexes.append({"q": q, "r": r, "region": "alpha", "blank": True})

    OUT.write_text(yaml.dump({"grid": {"orientation": "pointy-top", "hex_size": 60}, "hexes": hexes}, sort_keys=False))
    print(f"Wrote {len(hexes)} hexes to {OUT}")


if __name__ == "__main__":
    main()
