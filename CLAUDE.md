# CLAUDE.md - Deep Space D6: The Long Way Home

## Project Overview
A full digital companion web application for the solo RPG **Deep Space D6 - The Long Way Home**. The goal is to provide an immersive, high-quality digital experience that faithfully recreates and enhances the original PDF adventure while adding modern conveniences (persistent saves, interactive map, clean UI, etc.).

This is a **solo-only** experience.

## Core Philosophy & Priorities
- **Faithful to the source material** — Respect the original rules, tone, and structure from the PDF.
- **Excellent User Experience** — Make setup and play feel rewarding and cinematic, not tedious.
- **Automatic persistence** — The user should never lose progress. Everything is saved server-side instantly.
- **Clean, maintainable architecture** — Data-driven where possible.
- **Modern Rails + Hotwire** — Prefer Turbo + Stimulus over heavy JS frameworks.

## Tech Stack
- **Rails 8** + PostgreSQL
- **Hotwire** (Turbo + Stimulus)
- Tailwind CSS
- Devise + OmniAuth (Google OAuth only)
- SVG for interactive hex map
- ViewComponents + ERB where appropriate

## Key Models & Relationships
- `User` → has many `Campaigns`
- `Campaign` → belongs to one `Character` (locked after creation)
- `Character` → has one `Ship` configuration + exactly **4 Officers**
- `Officer` → name, title, specialty, attribute_a, attribute_b
- Campaign also tracks: current position, discovered sectors, fuel, scrap, cargo sequence, upgrades, journal entries, story flags, etc.

## Character Creation Rules (from PDF page 6)
**Captain**: Only name  
**Ship**: Ship name + one of: `Halcyon`, `Athena Mk. II`, `AG-8`, `Mononoaware`

**Officers** (4 total):
- Name (free text)
- Title: Commander, Lieutenant Commander, Lieutenant, Lieutenant Junior Grade
- Specialty (23 options — see PDF page 6)
- Attribute A (23 options — see PDF page 6)
- Attribute B (23 options — see PDF page 6)

## Map Architecture
- **Flat-top** hex grid using **axial (q, r)** coordinates
- Data-driven via YAML (`config/map.yml`)
- Map hex data uses `sector:` field (not `region:`) for grouping hexes into named areas
- Rendered entirely with **SVG** — transparent hex polygons, edges drawn on top as dashed lines; boundary edges between sectors render as dashed cyan
- Ship token moves visually on click; `START_HEX` is `{ q: 2, r: 7 }` (alpha sector, bottom of map)
- Clicking a sector opens a modal with story content and choices
- Event labels (e.g. `"10-A"`) live in `map.yml` for `EventCatalog` lookups but are **never rendered visually** on the map
- `sectors:` section in `map.yml` stores per-sector d12 roll counts (tau:2, zeta:3, delta:4, beta:6, alpha:6)
- **Trigger hexes**: a hex with a `trigger: "4-6"` field only activates (shows its icon, enables its event) when a d12 roll during sector generation falls in that range; otherwise it is completely blank. Static hexes always show their icon.

### Hex Icon Types
- `home` — house SVG path (homeworld)
- `start` — up-arrow SVG path (starting hex)
- `circle` — planet sprite (see below)
- `square` — store (SVG rect)
- `beacon_store` — planet sprite (smaller, offset up) + square below
- `jump` — jump point (circle + ⇄ label)

### Planet Sprites
- `/public/planets.png` is a 500×500px spritesheet: 5×5 grid of 25 planet sprites, each 100×100px, transparent background.
- Planet selection is deterministic per hex position: `(q * 7 + r * 11).abs % 25`
- In SVG, a spritesheet `<image>` renders the **full sheet** unless clipped. Always pair it with an inline `<clipPath>`. Use pixel coordinates (`cx.round`, `cy.round`) to generate unique clip IDs per hex.

`public/map/index.html` + `public/map/style.css` are a JS prototype/reference implementation used for visual verification — do not delete.

## User Flow
1. Landing page → "Start Playing"
2. Google login
3. Campaign list (existing saves) or "New Campaign"
4. New Campaign → Character Creation wizard
5. Map generation + start adventure
6. Interactive map is the main hub

## Non-Negotiables
- All game state changes must be saved to the database immediately.
- No localStorage reliance for core campaign data.
- Mobile-friendly responsive design.
- Dark, atmospheric sci-fi aesthetic.
- Never guess story text or rules — pull from the original PDF content.
- **Never derive hex coordinate/event mappings analytically from PDF text extraction** — the PDF layout does not parse reliably enough. Always ask the user to provide this data directly.

## Events YAML
- `config/events.yml` contains all 170 story events from PDF pages 10–74, fully QA'd against the PDF (2026-05-27).
- All intentional deviations from the source material are tracked in `memory/events_yaml_pdf_deviations.md`. Any future change to `events.yml` that deviates from the PDF must be appended there.

## PDF Tooling
- The Read tool's PDF support does not resolve correctly in this environment.
- Use `pdftotext -f <start> -l <end> "path/to/file.pdf" -` via Bash for all PDF extraction work.

## Future Extensions (documented for later)
- Full Research & Development tracking
- Journal system
- Cargo sequence editor
- Multiple completed campaigns gallery
- Undo last action (per campaign)

# End of session
- Before I close this session, suggest any new rules or patterns we discovered thta should be added to CLAUDE.md.
- If you learned anything about how this project works that isn't documented, save it to memory.

---

**Project Mantra**:  
Build something you would love to use yourself as a solo RPG player — elegant, immersive, reliable, and respectful of the original game.
