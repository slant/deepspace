# CLAUDE.md - Deep Space D-6: The Long Way Home

## Project Overview
A full digital companion web application for the solo RPG **Deep Space D-6 - The Long Way Home**. The goal is to provide an immersive, high-quality digital experience that faithfully recreates and enhances the original PDF adventure while adding modern conveniences (persistent saves, interactive map, clean UI, etc.).

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

## Local Development
- `bin/rails server` does **not** rebuild Tailwind CSS on its own — `Procfile.dev` defines a separate `css: bin/rails tailwindcss:watch` process that must be running alongside it. If a newly-added Tailwind utility class isn't showing up live, run `bin/rails tailwindcss:build` once before assuming there's a real bug — this has caused real confusion mid-session (a sized `<div>` silently collapsing because its `h-3 w-16` classes weren't in the compiled CSS yet).
- New game-system UI panels (R&D's Upgrades tab, and future ones like Combat) go in a collapsible tab above the map, not stacked into the left HUD sidebar (`aside` in `campaigns/show.html.erb`) — the sidebar is meant to stay a fixed, always-visible readout (Officers, Fuel/Scrap/Position/Cargo, Journal), not grow with every new system.

## Key Models & Relationships
- `User` → has many `Campaigns`
- `Campaign` → belongs to one `Character` (locked after creation)
- `Character` → has one `Ship` configuration + exactly **4 Officers**
- `Officer` → name, title, specialty, attribute_a, attribute_b
- Campaign also tracks: current position, discovered sectors, fuel, scrap, cargo sequence, upgrades, journal entries, story flags, etc.

## Character Creation Rules (from PDF page 6)
**Captain**: Only name  
**Ship**: Ship name + one of: `Halcyon`, `Athena Mk. II`, `AG-8`, `Mononoaware`, `Project Union`

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
- Event labels (e.g. `"10-A"`) live in `map.yml` for `EventCatalog` lookups **and are rendered above each hex's icon** (small monospace text, `.hex-label` in `application.css`) — an earlier session removed this for visual cleanliness, but event body text routinely tells the player to navigate to a specific labeled hex (e.g. "go to 20-A and purchase..."), which is unfollowable without labels on the map. A label only renders when the hex's icon is showing (see `icon_for` in `HexMapComponent`) — an unactivated trigger hex shows neither, so this can't spoil undiscovered content.
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
- `/public/planets.png` is a **500×600px** spritesheet: 5 columns × 6 rows of 100×100px cells, all 30 used (`Campaign::PLANET_COUNT = 30`).
- Planet selection is assigned once per campaign in `Campaign#assign_planet_sprites!` (random sample across all planet/beacon_store hexes, stored in `planet_sprites`); `Campaign#planet_sprite_for` falls back to a deterministic `(q * 7 + r * 11).abs % 30` for any hex not yet assigned.
- In SVG, a spritesheet `<image>` renders the **full sheet** unless clipped. Always pair it with an inline `<clipPath>`. Use pixel coordinates (`cx.round`, `cy.round`) to generate unique clip IDs per hex.
- **The sheet is not square.** The `<image>` element's `width`/`height` must preserve the real 5:6 aspect ratio (`HexIconComponent::SHEET_COLS`/`SHEET_ROWS`), not a single square size — SVG's default `preserveAspectRatio="xMidYMid meet"` letterboxes/offsets non-square sources scaled into a square box, which misaligns every cell's clip and bleeds in neighboring sprites.

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
- All intentional deviations from the source material are tracked in `docs/reference/events-yaml-pdf-deviations.md`. Any future change to `events.yml` that deviates from the PDF must be appended there.
- `expansion: endless` is a top-level field on an event marking it as gated behind the Endless Expansion (the rulebook's printed "EE" icon). See `docs/reference/deep-space-d6-mechanics.md` for what that means and which events carry it.

## Events YAML — Resource Deltas
- Choice-level resource changes use explicit `scrap_delta` and `fuel_delta` integer fields in the choice's `metadata` hash (positive = gain, negative = cost). Example: `metadata: { goto: "33-B", fuel_delta: -1 }`.
- The controller reads these automatically via `campaign.apply_resource_delta!` — never parse label text for amounts.
- **Event-body resource instructions** (e.g. event 73-A body: "Gain 2 fuel") are narrative text the player reads. They are NOT currently wired as automatic side-effects. Do not add `fuel_delta`/`scrap_delta` to the *choices* of such events unless the choice itself causes the change — the body text is informational only.

## Events YAML — Items, Cargo Marks, and Conditional Requirements
- **Items**: choice metadata `gain_item: "Name"` / `lose_item: "Name"` / `lose_items: ["A", "B"]` (plural, for multi-item loss). Applied via `campaign.gain_item!`/`lose_item!` (new `items` json column: `[{"name" =>, "lost" =>}]`). An item's bracket name (e.g. `[AI-System]`) is the canonical identifier used everywhere — keep it exact and consistent between the gaining choice and any `requires`/`lose_item` reference to it.
- **Conditional loss**: `lose_item_unless: { specialty_or_attribute: [...] }` skips the loss if the officer condition is met (e.g. 64-B: lose `[Vortex]` unless you have DARK MATTER SPECIALIST/ASSASSIN/LOYAL).
- **Cargo sequence marks**: choice metadata `mark_sequence: "711"` + `mark_type: "underline"` (or `"circle"`) applied via `campaign.mark_sequence!` (new `cargo_marks` json column: `{token => "underline"/"circle"}`). Marking is automatic (a consequence of the choice), never a manual player tap — this was a deliberate design decision, see `docs/reference/` design history.
- **Conditional requirements**: any choice can carry `requires:` in its metadata, evaluated by `ChoiceRequirement.satisfied?` — **never parse `[Requires: ...]` label text at runtime**, the bracket text is flavor only. Supported keys: `specialty_or_attribute`/`excludes_specialty_or_attribute` (officer specialty, attribute_a, or attribute_b, case-insensitive OR-list), `item`/`excludes_item`/`items_all`, `sequence` (+ optional `state: "underlined"/"circled"`), `sequence_all`, `exclude_sequence`/`exclude_sequence_any`. The controller annotates every choice in a GET response with `locked: true/false`; the event modal disables locked buttons client-side. There is no server-side re-verification on PATCH (a solo narrative game — not worth the complexity for a self-play trust boundary).
- **Multi-action / store choices**: `stay_open: true` in a choice's metadata (used by the 20-A/B/C stores) tells the event modal to apply the choice's effects and re-fetch+re-render the same event afterward instead of closing/navigating away — lets a player perform several store actions in one visit. Combine with `requires: { excludes_item: "X" }` to make a one-time purchase self-lock after buying.
- Event 51-A's "[Requires: ASTRONOMER, CHEMIST, DOCTOR, or PILOT]" references a specialty that doesn't exist in the real 23-option list (page 6) — a PDF authoring error, not a bug on our end. It correctly never matches via ASTRONOMER; the other three options in that OR-list still work.
- **Officer mutations**: choice metadata `gain_random_officer_attribute: "Name"` (+ optional `gain_random_officer_attribute_count: N`, default 1), `gain_all_officers_attribute: "Name"`, `kill_random_officer: true`. Applied via `campaign.add_random_officer_attribute!`/`add_all_officers_attribute!`/`kill_random_officer!`. "Random" selection happens server-side (Campaign is the source of truth for what already happened), and always excludes already-dead officers. These are distinct from an officer's locked creation fields (name/specialty/attribute_a/attribute_b) — see `Officer#bonus_attributes`/`#dead`/`#title_override` and `#all_attributes`/`#effective_title`.

## Crew Dice (resolved 2026-08-26)
- Crew dice face composition is known — user supplied a photo of the physical dice. All 6 dice are identical, one of each face: Threat Detected (silver), Commander (blue), Science (green), Engineering (orange), Tactical (red), Medical (purple). **No skull face** — a previous session had guessed "skull" for an icon `pdftotext` couldn't extract; corrected throughout `events.yml`. Implemented in `app/services/crew_dice.rb` (`CrewDice.roll(n)`, uniform random per face). See `docs/reference/deep-space-d6-mechanics.md`.
- This unblocked `Campaign#roll_fatigue_check!`/`#apply_fatigue_threshold!` + `Officer#fatigue_marks`/`#fatigue_threshold`/`#fatigued?` (events 39-B/42-A/51-B/61-B/70-A/72-A's "any Threat Detected → X mark" pattern, and 43-A's threshold check) — rolled via the explicit "Roll Dice" button pattern, see "Dice Roll Scope" below.
- Threat-die rolls (plain d6, e.g. event 22-A's asteroid outcome) were never blocked by this — they're a separate plain die, not a crew die.

## Dice Roll Scope — app rolls story checks, never combat/R&D
This is a narrative companion, not a full reimplementation of Deep Space D-6. Simple, one-off story checks (crew-dice fatigue checks, 22-A's threat die table, Open Space encounter rolls) are rolled by the app, but only via an explicit player-triggered **"Roll Dice" button** — never silently as a side effect of a choice. `EventCatalog` exposes a `dice_roll` descriptor on `for_hex`/`for_event` (unrolled); `EventCatalog.roll_dice_for(kind, ...)` performs the actual roll when `HexEventsController#roll_dice` (`action_type: "roll_dice"`) is hit; `event_modal_controller.js`'s `renderRollButton`/`rollDice` render the button and reveal choices after the result. Full combat and R&D dice are rolled on the player's physical dice during combat/Duty Phase — the app never rolls them, it only lets the player report progress they already made (see Research & Development below). Current gap: this pattern only supports a single roll before revealing choices — a genuinely multi-roll event (button stays after each roll) isn't built yet.

## Research & Development (unblocked 2026-08-26)
- `Campaign::RND_TRACKS` is the single source of truth for the 6 upgrade tracks (Engine Repair, Promotion, Kinetic Recycler, LR Scanners, Bio-Manipulator, Cloaking Device) — box labels (the exact crew-die result(s) required, user-supplied from the physical character sheet) and `scrap_cost`. A box with more than one requirement (Bio-Manipulator's 3rd box, "1 Medical + 1 Engineering") is modeled as a single box and marked as one unit — the user confirmed simultaneous requirements are paid together, not split into two boxes.
- Progress lives in `researched_upgrades` (existing json column): `{ track_id => { "marked_boxes" => [Boolean], "researched" => Boolean } }`. `Campaign#toggle_upgrade_box!`/`#upgrade_researched?`/`#complete_upgrade!` — a zero-cost track auto-completes the instant its last box is marked; a track with a scrap cost needs an explicit `complete_upgrade!` call (the player confirms the spend) even once every box is marked.
- UI is a collapsible **"Upgrades" tab** sitting above the map (not the sidebar — deliberately kept out of the always-visible HUD to avoid clutter), `upgrades_panel_controller.js` + `UpgradesController` (`PATCH /campaigns/:id/upgrades/:track/boxes/:box`, `PATCH /campaigns/:id/upgrades/:track/complete`). Boxes are tap-to-mark, self-reported — the app never validates that a marked box's crew-die result was actually rolled, per the Dice Roll Scope rule above.
- **Not yet wired**: the *effects* of completed upgrades (Engine Repair's 2-space movement, Jump Drive, LR Scanners' Open Space roll reduction, combat-only effects for Kinetic Recycler/Promotion/Cloaking Device/Bio-Manipulator). `Campaign#upgrade_researched?("engine_repair")` etc. exists for any future code to gate on. Also not wired: event 57-A's Cloaking Device eligibility flag (currently researchable unconditionally) and "track uses" (consuming a completed upgrade's effect — blocked on Combat existing at all).
- **Jump Drive/Engine Repair — do NOT confuse with a "jump point" hex type.** An earlier session wrongly assumed jump points were map hexes needing coordinate/pairing data (they aren't — no such hex exists anywhere in `map.yml`/`events.yml`). Engine Repair grants 2-space movement; Jump Drive (requires Engine Repair) costs 1 fuel to either flee combat (assign 3 Engineering crew) or return to your immediately-previous map position. See `docs/reference/deep-space-d6-mechanics.md`.

## PDF Tooling
- The Read tool's PDF support does not resolve correctly in this environment.
- Use `pdftotext -f <start> -l <end> "path/to/file.pdf" -` via Bash for all PDF extraction work.
- **`pdftotext` silently drops small rasterized icon graphics** (e.g. the rulebook's "EE" Endless Expansion marker) — they don't appear as text at all, not even as garbled characters, so a text-only pass can miss meaningful markers with no error. When icon/symbol presence matters, render the page as an image (`pdftoppm -png -r 200 -f <page> -l <page> "file.pdf" out`) and inspect it visually instead of trusting text extraction alone.
- `pdftoppm`'s page numbers don't match the rulebook's own printed footer numbers — there's a fixed +1 offset (footer page N is `pdftoppm` page N+1) because of the unnumbered cover page. Confirm against the visible footer, don't assume.

## TODO List
- `TODO.md` in the project root tracks all pending and future work items. Add new items there when they come up during a session.

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
