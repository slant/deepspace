# Deep Space D6 — TODO

Items are grouped by game system. Checked items are already implemented.

## Priority Order

1. Event action wiring (`goto`, `game_over`, scrap/fuel side-effects on choices)
2. Open Space encounters (real d6 roll + sector chart)
3. Resources & lose conditions (fuel depletion → game over)
4. Conditional choice enforcement (officer skills, items, cargo sequences)
5. Items & cargo sequence (tracking, UI, persistence)
6. Officer panel (visibility during play + permanent state changes)
7. Store UI (multi-action hub events 20-A/B/C)
8. In-event dice rolls (mid-event branching on roll results)
9. Research & Development (upgrade tracks + effects)
10. ~~Combat system (core mechanics)~~ — done; app never simulates combat, see Combat section
11. ~~Special combat variants (Dreadship, The Shadow, Endless, etc.)~~ — done, see Combat section
12. Starmap extras (jump points, Jump Drive, engine repair movement bonus)
13. Win/loss screens (end-game presentation)
14. ~~Expansion content flag (Endless Expansion gating)~~ — done; re-scoped to clear labeling, not gating
15. Quality of life (journal notes, undo)

---

## Character Creation
- [x] **Add "Project Union" as a 5th ship option** (2026-08-26): `Character::SHIP_TYPES`/`CrewOptions::SHIP_LABELS` — no other app code references specific ship types (grepped `events.yml` and `app/` — combat/ship mechanics are entirely player-managed physically, per the Combat section), so this was the entire scope.
- [x] Captain name, ship name, ship type selection (4 ships)
- [x] 4 officers with name, title, specialty, attribute A, attribute B
- [x] Officer randomize button
- [x] Lock character on campaign start
- [x] Display character sheet (officers + attributes) during play — sidebar "Officers" section, live-synced (name, effective title, specialty, all attributes including gained ones; dead officers shown struck through).

## Starmap & Navigation
- [x] SVG hex map rendered (flat-top, axial coordinates)
- [x] Ship token moves to adjacent hex, costs 1 fuel
- [x] Sector discovery: d12 rolled the correct number of times per sector, trigger hexes activated
- [x] Hex icon types: home, start, circle (planet), square (store), beacon_store, jump
- [x] Planet sprites from spritesheet, deterministic per hex
- [x] ~~**Jump points**~~ — corrected: this was never a real thing. Earlier sessions wrongly assumed a "jump point" hex type needing map coordinate/pairing data (no such hex exists anywhere in `map.yml`/`events.yml`). There is no jump-point mechanic at all — see Engine Repair/Jump Drive below, which is what "jump" actually refers to. See `docs/reference/deep-space-d6-mechanics.md`.
- [x] **Engine Repair upgrade effect**: `Campaign#move_range`/`#within_move_range?` (2026-08-26) — once researched, any hex up to 2 away is a valid move target, still 1 fuel flat. `HexGrid.distance` added for the axial math. `HexMapComponent`/`HexEventsController` updated to use the range-aware check instead of literal adjacency.
- [x] **Jump Drive** (requires Engine Repair upgrade): `Campaign#can_jump_drive?`/`#jump_drive!` (2026-08-26) — costs 1 fuel, returns to the immediately-previous hex position (tracked via new `previous_ship_q`/`previous_ship_r` columns, swapped on every move/jump). HUD button (`campaign_hud_controller.js#jumpDrive`) shown only when available. Bypasses `EventCatalog` entirely — no Open Space encounter on return. *Combat escape* (assigning 3 Engineering crew mid-fight) happens entirely on the player's physical copy — nothing for the app to do there, see Combat section.

## Open Space
- [x] Blank/unactivated hexes are recognized as Open Space
- [x] **Roll d6 and consult sector-specific encounter chart**: implemented in `EventCatalog::OPEN_SPACE_CHARTS`/`open_space_event`. **Combat rows (2026-08-26)**: resolved on the player's physical copy, same as any other combat (see Combat section) — after rolling, the player reports Victory/Defeat via choices the roll response supplies, which the app applies via the normal `scrap_delta` mechanism. Zeta's rows (2-6, EE-marked) clearly label that they require the Endless Expansion's own threat deck rather than being silently skipped — see "Expansion content flag" below.
- [x] **Long Range Scanners upgrade effect**: `EventCatalog.roll_open_space_chart` (2026-08-26) — when `Campaign#upgrade_researched?("lr_scanners")`, the rolled d6 is reduced by 2 (min 1) before consulting the chart; the roll result text says so explicitly.

## Events & Choices
- [x] 170 events loaded from `config/events.yml`, QA'd against PDF
- [x] Event modal: title, body, choice buttons
- [x] `orbit` action: close modal, return to map
- [x] `complete` action: mark campaign won
- [x] Conditional choice labels present (e.g. `[Requires: HACKER]`)
- [x] **`goto` action**: follows chain to next event inline (modal updates in-place); each step logged as "X → Y" entry type "event".
- [x] **`game_over` action**: sets campaign status to `:failed`, logs milestone, shows minimal "Mission Failed" modal state with redirect to campaign list.
- [x] **Conditional choice enforcement — officer attributes/specialties**: choices carry structured `requires: { specialty_or_attribute: [...] }` / `excludes_specialty_or_attribute: [...]` metadata (never label-text parsing). `ChoiceRequirement` evaluates against `campaign.character.officers`. The controller annotates every choice with `locked: true/false` on GET; the frontend disables locked buttons. Note: `ASTRONOMER` (used in one PDF requirement) isn't a real specialty per the official page-6 list — a PDF authoring error, so that branch correctly never satisfies via that word alone (the other OR-list options still work).
- [x] **Conditional choice enforcement — items**: `requires: { item: "X" }` / `items_all: [...]`, checked via `campaign.has_item?`.
- [x] **Conditional choice enforcement — cargo sequences**: `requires: { sequence: "X", state: "underlined"/"circled" }`, `sequence_all: [...]`, `exclude_sequence`/`exclude_sequence_any` (for 14-C's "L only" / "711 only" / "no qualifying sequences" branches). Checked via `campaign.sequence_marked?`/`sequence_state`.
- [x]/[ ] **Story flags**: officer-attribute flags (54-A's MISTRUSTING, 30-B's RESTLESS, 51-D's LUCKY) are done — see Officer State section. **Still open**: event 57-A's "you may now research the Cloaking Device... cross out the '?' box" is meant to gate Cloaking Device eligibility. R&D now exists (see R&D section), but this specific gate isn't wired — the Upgrades tab currently lets Cloaking Device be researched unconditionally, without checking whether 57-A has happened.
- [x] **Items**: `gain_item!`/`lose_item!`/`has_item?` on Campaign (new `items` json column: `[{name:, lost:}]`). Choices carry `gain_item`/`lose_item`/`lose_items` (array)/`lose_item_unless` (conditional loss, e.g. 64-B's "unless you have DARK MATTER SPECIALIST...") metadata; controller applies via `apply_item_and_sequence_effects!`. Rendered as a strikethrough-on-loss list in the sidebar "Cargo Manifest".
- [x] **Cargo sequence manipulation**: implemented as **automatic** marking (not manual tap-to-toggle as originally scoped) — choices carry `mark_sequence`/`mark_type` ("underline"/"circle") metadata and the controller applies it via `campaign.mark_sequence!` (new `cargo_marks` json column: `{token => state}`). This was a deliberate design change from the original plan (see prior design discussion): the PDF's "mark this token" instructions are consequences of choices, not freeform player annotation, so automating it removes bookkeeping burden and is what makes enforcement above possible at all. Rendered as small state-colored chips in the sidebar. The fancier "render marks directly on the visual cargo string" treatment discussed earlier is still future work.
- [x] **Scrap side-effects on choices**: `scrap_delta` metadata field added to all affected choices (26-A, 28-D, 37-A, 43-D, 48-A, 51-C, 56-A, 58-A, 67-A); controller applies via `apply_resource_delta!`.
- [x] **Fuel side-effects on choices**: `fuel_delta` metadata field added to all "Spend 1 fuel" choices (27-A, 35-B, 45-A, 47-A, 51-C, 52-A); controller applies via `apply_resource_delta!`. Note: event-body fuel gains (e.g. 73-A "Gain 2 fuel") are narrative instructions not yet wired.
- [x] **Multi-action store UI**: choices carry `stay_open: true` metadata — the event modal applies the choice's effects via the normal metadata pipeline, then re-fetches and re-renders the same event (fresh `locked` states) instead of closing/navigating away, so the player can perform any number of actions in one visit before clicking "Return to Orbit". Reuses the existing choice/requirement/metadata machinery entirely; no new interaction pattern needed.
- [x] **Fuel depot — buy fuel for scrap**: wired for 20-A (1 fuel/4 scrap), 20-B (1 fuel/6 scrap), 20-C (1 fuel/5 scrap), all repeatable `stay_open` choices. **Known simplification**: the "limit 5" per-visit caps on 20-A/20-C are not enforced (repeatable indefinitely, limited only by available scrap) — enforcing a true per-visit limit would need a way to reset a counter each time the player returns to the store, which isn't obviously well-defined for a hex you can revisit anytime; flagged in the event body text and left as a judgment call.
- [x] **Store — buy items for scrap**: 20-A sells `[SYS-PUMP]` for 5 scrap (`stay_open` choice, gated `requires: { excludes_item: "SYS-PUMP" }` so it locks itself out once bought — one-time purchase for free). 20-C's Luxury Food mission (lose `[Lux Food]`, gain 15 scrap) works the same way via its own `requires: { item: "Lux Food" }`.
- [x] **Expansion content flag** (re-scoped 2026-08-26): originally planned as a campaign-level
  "owns Endless Expansion" toggle that would hide `expansion: endless` content entirely for
  non-owners. Dropped that plan — with no real Endless card data, there'd be nothing to actually
  run for an owner either, and a silent toggle can't be inspected by the player to know why
  content vanished. Instead, per user direction, every relevant spot clearly states which threat
  deck applies rather than hiding anything:
  - **16-A, 17-A** (`events.yml`): body opens with a ⚠ notice ("this encounter uses the Endless
    Expansion's own threat deck") plus an explicit "Don't own the expansion — Return to Orbit"
    choice with no consequence.
  - **Zeta Open Space rolls 2–6** (`EventCatalog::OPEN_SPACE_CHARTS`): roll result text states
    the same, via `endless_open_space_body`.
  - **44-E** (unmarked, not expansion-gated): body explicitly names the page-74 demo card set so
    it's never confused with the standard or Endless deck. See
    `docs/reference/deep-space-d6-mechanics.md`.
- [x]/[ ] **Dice roll mechanics within events**: crew dice face data is now known (`CrewDice`, see CLAUDE.md), so the clean/repeatable pattern is done. The bespoke multi-stage mini-games below are NOT attempted — each needs real interactive UI (hand display, hidden opponent dice, re-roll boxes, multi-stage challenge selection) beyond a simple roll-and-apply, which is a much bigger scope than the data gap that used to block them:
  - [x] Event 22-A: threat die → asteroid outcome. Implemented generically via `EventCatalog`'s new `threat_die_table` support (declare a 1-6 outcome table in an event's YAML; rolls once, appends the outcome text to the body, merges scrap/fuel deltas into every choice) — reusable for any future single-roll-then-choose event, not a 22-A special case.
  - [x] Events 39-B, 42-A, 51-B, 61-B, 70-A, 72-A: "Rising Waters" pattern — roll 2 crew dice per living officer, any Threat Detected result adds an X (fatigue) mark. `Campaign#roll_fatigue_check!`, applied automatically via `crew_dice_fatigue_check: true` choice metadata on all of these events' path choices. 43-A's threshold check (`Officer#fatigue_threshold`/`#fatigued?`, 3/4/5 depending on attributes) is wired via `apply_fatigue_threshold: true` — an officer past their threshold is crossed out (reuses the existing dead/kill! exclusion).
  - [ ] Event 27-B: Roll 3 crew dice (player hand) vs 2 hidden dice (opponent) for card game. Not attempted — bespoke UI.
  - [ ] Event 31-A: Roll threat die +2 → place in RE-ROLLS box; then roll 6 crew dice, match symbols with re-roll mechanic. Not attempted — bespoke UI.
  - [ ] Event 47-A: Roll threat die to pick mining section, then roll crew dice (modified by attributes) for scrap yield. Not attempted — bespoke UI.
  - [ ] Event 52-B: Roll 3 crew dice vs defense system. Not attempted — bespoke UI.
  - [ ] Event 62-A: Multi-stage trap challenge using crew dice. Not attempted — bespoke UI.
  - [ ] Event 21-B: Gladiator fights — pick 1 of 6 challenges, roll all 6 crew dice, various win conditions (match N symbols, no Threat Detected, etc.), title override to GLADIATOR, cross out officer on failure. Not attempted — the biggest bespoke UI of the set. `Officer#title_override` data layer already exists and is ready for this whenever it's built.

## Resources & HUD
- [x] Fuel tracked, decremented on move, shown in HUD
- [x] Scrap tracked, shown in HUD
- [x] Cargo sequence displayed in HUD (read-only)
- [x] Activity journal (movement, events, milestones) shown in sidebar
- [x] **Fuel depletion = game over**: moving to an adjacent hex with 0 fuel triggers event 21-A ("Adrift") instead of silently blocking movement; ship does not move, `game_over` choice ends the campaign.
- [x] **Scrap gain/loss from events**: covered by the existing `scrap_delta` metadata pipeline plus the Open Space chart's `scrap_delta` on its "Return to Orbit" choice (Alpha/Beta/Delta rows; Zeta's combat rows are Endless-gated and ignored, see Open Space section) — live-synced in the HUD already.
- [x] **Cargo sequence interactions**: see Events & Choices section above (cargo marks + items system).

## Officer State
Officers can be permanently modified by events — this needs to be tracked in the DB and reflected in the UI.
- [x] ~~**Infirmary tracking**~~ — investigated (2026-08-26): grepped the entire app for "infirmary" and found zero code references. Only two mentions exist anywhere, both narrative body text in `events.yml` (52-D: "Start with 2 crew in the infirmary" as a physical-combat setup detail; 67-A Dreadship: "Infirmary system — sends a unit to the infirmary" as an attack description) — no later event ever checks infirmary status as a condition. It's crew-die state on the player's physical board during combat, same as hull/shield: narrated, not tracked. 52-D already just mentions it in prose, which is exactly right — nothing to build.
- [x] **Officer attribute additions**: `Officer#bonus_attributes` (json array) + `add_attribute!`, separate from the locked creation attributes. Wired for event 30-B (`gain_random_officer_attribute: "Restless"`, one random living officer), 51-D (`gain_all_officers_attribute: "Lucky"`, all officers), and 54-A's `[LIE]` branch (`gain_random_officer_attribute: "Mistrusting", gain_random_officer_attribute_count: 2`). `ChoiceRequirement` and conditional checks now see bonus attributes too, via `Officer#all_attributes`.
- [x] **Officer death / removal**: `Officer#dead` (boolean) + `kill!`. Wired for event 41-D (`kill_random_officer: true`, since the PDF doesn't specify which officer is lost). Dead officers are excluded from `ChoiceRequirement` matching and from random-selection for other officer mutations. Event 21-B's conditional kill (on a failed gladiator challenge) is still unwired — blocked on in-event dice rolls (priority #8) existing to know success/failure.
- [x] **Officer title change**: `Officer#title_override` (string) + `effective_title` (falls back to the titleized enum value). Data layer exists; not yet wired to event 21-B specifically, since that event's title change only matters alongside its (unbuilt) dice challenge.
- [x] ~~**Skill exchange at tavern**~~ — this item described a mechanic that doesn't exist. Checked the actual PDF text for event 51-A directly: it's "exchange your skillset for anything else useful" flavor text for the same `[Requires: SMUGGLER, PSYCHIC, or CHARMING]`-style OR-list gating pattern already implemented (see Events & Choices above) — no specialty-swap UI is described anywhere in the source. Removing as a stale/incorrect note from an earlier session.

## Combat
**Corrected scope (2026-08-26): this app does not reimplement or simulate combat at all.** An
earlier version of this TODO (and `docs/reference/deep-space-d6-mechanics.md`) wrongly framed
Combat as a subsystem to build — a ship board, threat deck, dice engine, hull/shield tracking,
per-ship station abilities, drone economies, etc. The user corrected this directly: the player
resolves `COMBAT: N threats, draw deck of M` on their own physical copy of the game; the app's
only job is the same thing it already does for every other event — show the narrative
instruction (already just body text) and let the player's choice of outcome (Victory/Defeat)
drive `goto`/`game_over`/`scrap_delta`/`fuel_delta` exactly like any other branching event. See
`docs/reference/deep-space-d6-mechanics.md`'s top note and CLAUDE.md's "Dice Roll Scope".
- [x] **Standard combat events wired**: checked all ~24 `COMBAT:` events in `events.yml` against
  their body text. 51-C, 69-A, 16-A, 25-A were already correctly wired. Fixed 15-A and 44-E
  (body stated an explicit defeat consequence that wasn't wired as a choice) and added a missing
  "Game Over" defeat choice to 34-B, 58-C, and 67-A (body stated no defeat consequence at all —
  user-confirmed default: silent-on-defeat combat events end the campaign). See
  `docs/reference/events-yaml-pdf-deviations.md`.
- [x] **Special combat — event 57-A (The Shadow)**: already correctly wired (Victory → 58-A,
  Defeat → game_over).
- [x] **Special combat — event 67-A (Dreadship)**: fixed, see above — no combat-layout UI needed,
  it's narrative body text like every other combat event.
- [x] **Special combat — event 58-C**: fixed, see above.
- [x] **Special combat — events 44-E / 16-A / 17-A (Endless)**: 44-E's body now explicitly names
  the page-74 demo card set so it's unmistakable it's not the standard or Endless deck. 16-A and
  17-A (both EE-marked) now open with a ⚠ notice that they require the Endless Expansion's own
  threat deck, plus an explicit "Don't own the expansion — Return to Orbit" choice alongside the
  real outcome choices (17-A's missing scrap_delta on its win path was also fixed). See
  "Expansion content flag" below.
- Kinetic Recycler / Promotion / Cloaking Device / Bio-Manipulator "track uses" effects
  (see R&D below) happen entirely during physical combat the app never sees — not app-tracked,
  same as hull/shield. Nothing to build here.

## Research & Development
Unblocked — the user supplied the exact per-track box requirements (see `Campaign::RND_TRACKS`). Per the dice-roll scope rule (CLAUDE.md "Crew Dice"), R&D dice are rolled physically during combat/Duty Phase — the app never rolls them. It only tracks progress: a collapsible "Upgrades" tab (`upgrades-panel` Stimulus controller) sits above the map, showing all 6 tracks as rows of tap-to-mark boxes. A box with more than one requirement (Bio-Manipulator's 3rd box) is a single box, marked as one unit, per the user's note that simultaneous requirements are paid together.
- [x] `researched_upgrades` column exists on campaigns table
- [x] **R&D UI**: collapsible "Upgrades" tab above the map (not the character sheet/sidebar as originally scoped — moved there deliberately to keep the sidebar uncluttered), all 6 tracks with tap-to-mark progress boxes.
- [x] **Research during combat** / **Research at store locations**: no context-specific flow was built — the Upgrades tab is available everywhere, at any time, and marking is the same self-reported tap regardless of when the dice were actually rolled. Treat these two TODO items as covered by that single always-available UI rather than as separate flows.
- [x] **Unlock upgrades**: `Campaign#toggle_upgrade_box!`/`#complete_upgrade!` — a zero-cost track (Promotion, Kinetic Recycler, LR Scanners, Bio-Manipulator) auto-completes the instant its last box is marked; a track with a scrap cost (Engine Repair: 10, Cloaking Device: 25) requires an explicit "Complete" button click once all boxes are marked (deliberately not automatic, since it's a resource spend). `Campaign::RND_TRACKS` is the single source of truth for box labels/costs, serialized into the panel's data attributes.
- [ ] ~~**Track uses**~~ — not applicable. Spending a *use* of a completed upgrade's effect happens entirely during physical combat the app never sees (see Combat section above) — nothing for the app to track here, same as hull/shield.
- [x] **Engine Repair cost**: 10 scrap, paid via the same explicit "Complete" button flow as Cloaking Device.

## Win / Loss Conditions
- [x] `complete` action sets campaign status to `:completed`
- [x] **Victory screen**: `Campaign#journey_summary` (moves, sectors discovered, items held/lost, sequences marked, officers lost, final position) shown in the existing status banner on the campaign page — expanded from a one-line banner into a small stats panel.
- [x] **Loss screen**: same summary panel, shown for `failed` campaigns too (fuel-out via 21-A, or any `game_over` event) — same banner, same stats.
- [x] **Completed campaigns gallery**: campaign list already shows a Victory/Failed badge and "Show Results" (from earlier work); `progress_summary` still just shows fuel/scrap/position for finished campaigns rather than the fuller `journey_summary` stats — could pull those in too, but the per-campaign summary panel covers the "show outcome and summary" ask once you open a campaign.

## Quality of Life
- [x] **Officer details visible during play**: sidebar "Officers" section (see Character Creation section above) — same feature, was tracked in two places.
- [x] **Freeform journal notes**: small form under the Journal list (active campaigns only) posts to `POST /campaigns/:id/journal_entries` (`JournalEntriesController`), logged as `entry_type: "note"`, live-synced like everything else in the sidebar.
- [ ] **Undo last action**: roll back the most recent game state change. Deliberately not attempted — would need state snapshotting across Campaign + Officer + JournalEntry, and interacts awkwardly with "everything auto-saved instantly" as a design principle (what does undoing a fuel-cost move even mean once sector generation/journal entries have already happened downstream?). Worth a real design discussion before building, not a quick add.
