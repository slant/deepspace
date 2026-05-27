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
- Labels on individual hexes are not yet implemented

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
