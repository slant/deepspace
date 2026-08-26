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
10. Combat system (core mechanics)
11. Special combat variants (Dreadship, The Shadow, Endless, etc.)
12. Starmap extras (jump points, Jump Drive, engine repair movement bonus)
13. Win/loss screens (end-game presentation)
14. Expansion content flag (Endless Expansion gating)
15. Quality of life (journal notes, undo)

---

## Character Creation
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
- [ ] **Jump points**: jump hex type exists on the map but the mechanic is not implemented — clicking a jump point should offer travel to another point on the map (see jump point events in events.yml)
- [ ] **Engine Repair upgrade effect**: when unlocked, allow moving 2 spaces per turn instead of 1
- [ ] **Jump Drive** (requires Engine Repair upgrade): activated by rolling crew dice and assigning 3 Engineering results, costs 1 fuel. Has two use contexts once unlocked:
  - *Map navigation*: return to previous hex. Needs a HUD button, and campaign must track the last position.
  - *Combat escape*: flee a combat encounter as a station action. Does NOT trigger an Open Space encounter on return.

## Open Space
- [x] Blank/unactivated hexes are recognized as Open Space
- [x] **Roll d6 and consult sector-specific encounter chart**: implemented in `EventCatalog::OPEN_SPACE_CHARTS`/`open_space_event`. Zeta's combat rows (2–6, all EE-marked) resolve as ignored/Empty per the "Expansion content flag" note below. **Combat rows for Alpha/Beta/Delta resolve as an automatic, unharmed win** (any listed scrap reward is still granted) — there's no Hull/Shield tracking on Campaign yet for real combat to apply damage to. Replace with real dice/threat-card resolution once the combat system (priority #10) exists.
- [ ] **Long Range Scanners upgrade effect**: during Open Space roll, reduce the d6 result by 2 (min 1)

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
- [ ] **Story flags**: some events grant named flags (e.g., discovering the Cloaking Device, gaining RESTLESS/MISTRUSTING as an officer attribute). Distinct from items/sequences — not implemented. Officer-attribute mutation in particular (54-A's "give two officers MISTRUSTING", 30-B's "gain RESTLESS") needs a mutable-attributes system per officer that doesn't exist yet (see Officer State section).
- [x] **Items**: `gain_item!`/`lose_item!`/`has_item?` on Campaign (new `items` json column: `[{name:, lost:}]`). Choices carry `gain_item`/`lose_item`/`lose_items` (array)/`lose_item_unless` (conditional loss, e.g. 64-B's "unless you have DARK MATTER SPECIALIST...") metadata; controller applies via `apply_item_and_sequence_effects!`. Rendered as a strikethrough-on-loss list in the sidebar "Cargo Manifest".
- [x] **Cargo sequence manipulation**: implemented as **automatic** marking (not manual tap-to-toggle as originally scoped) — choices carry `mark_sequence`/`mark_type` ("underline"/"circle") metadata and the controller applies it via `campaign.mark_sequence!` (new `cargo_marks` json column: `{token => state}`). This was a deliberate design change from the original plan (see prior design discussion): the PDF's "mark this token" instructions are consequences of choices, not freeform player annotation, so automating it removes bookkeeping burden and is what makes enforcement above possible at all. Rendered as small state-colored chips in the sidebar. The fancier "render marks directly on the visual cargo string" treatment discussed earlier is still future work.
- [x] **Scrap side-effects on choices**: `scrap_delta` metadata field added to all affected choices (26-A, 28-D, 37-A, 43-D, 48-A, 51-C, 56-A, 58-A, 67-A); controller applies via `apply_resource_delta!`.
- [x] **Fuel side-effects on choices**: `fuel_delta` metadata field added to all "Spend 1 fuel" choices (27-A, 35-B, 45-A, 47-A, 51-C, 52-A); controller applies via `apply_resource_delta!`. Note: event-body fuel gains (e.g. 73-A "Gain 2 fuel") are narrative instructions not yet wired.
- [ ] **Multi-action store UI**: events 20-A, 20-B, and 20-C are hub stores where the player can perform *any number* of independent actions in one visit (purchase items, buy fuel for scrap, research with crew dice). The current single-choice modal doesn't support this — needs a checklist/multi-step UI for these events.
- [ ] **Fuel depot — buy fuel for scrap**: 20-A sells 1 fuel per 4 scrap (limit 5); 20-B sells 1 fuel per 6 scrap (no limit); 20-C sells 1 fuel per 5 scrap (limit 5).
- [ ] **Store — buy items for scrap**: event 20-A sells `[SYS-PUMP]` for 5 scrap. Purchasing must add the item to cargo and deduct scrap.
- [ ] **Expansion content flag**: events tagged `expansion: endless` in `events.yml` (currently 16-A, 17-A) carry the rulebook's "EE" icon and per pages 2 & 5 should be ignored entirely for players without the Endless Expansion — not shown, not resolved, treated as if the hex/roll did nothing. Also applies to Open Space combat rolls 2–6 in Sector Zeta (see Open Space section). Needs a campaign setting ("owns Endless Expansion") and filtering in `EventCatalog`/`HexEventsController`. We do not have real Endless Expansion card data, so even when a campaign is flagged as owning it, there's currently nothing to actually run — until real card data is supplied, treat all `expansion: endless` content as ignored regardless of the flag. Do not confuse with 44-E, which is unmarked in the rulebook and always resolves against the page-74 demo deck for everyone — see `docs/reference/deep-space-d6-mechanics.md`.
- [ ] **Dice roll mechanics within events**: several events require rolling dice mid-event and branching on the result. These cannot be handled by simple choice buttons — they need an in-modal dice roll step:
  - Event 22-A: Roll threat die → asteroid outcome (1=no damage, 2=lose 5 scrap, 3=lose 1 fuel, 4–6=varying damage)
  - Event 27-B: Roll 3 crew dice (player hand) vs 2 hidden dice (opponent) for card game
  - Event 31-A: Roll threat die +2 → place in RE-ROLLS box; then roll 6 crew dice
  - Events 39-B, 42-A, 51-B, 61-B, 70-A, 72-A: Roll 2 crew dice per officer — any skull places an X on that officer
  - Event 47-A: Roll threat die to pick mining section, then roll crew dice (modified by attributes) for scrap yield
  - Event 52-B: Roll 3 crew dice vs defense system
  - Event 62-A: Multi-stage trap challenge using crew dice

## Resources & HUD
- [x] Fuel tracked, decremented on move, shown in HUD
- [x] Scrap tracked, shown in HUD
- [x] Cargo sequence displayed in HUD (read-only)
- [x] Activity journal (movement, events, milestones) shown in sidebar
- [x] **Fuel depletion = game over**: moving to an adjacent hex with 0 fuel triggers event 21-A ("Adrift") instead of silently blocking movement; ship does not move, `game_over` choice ends the campaign.
- [ ] **Scrap gain/loss from events**: events that award or cost scrap (e.g. open space combat in Delta/Zeta sectors) need to update `campaign.scrap` and reflect in HUD
- [ ] **Cargo sequence interactions**: see Events section above (circling/underlining characters)

## Officer State
Officers can be permanently modified by events — this needs to be tracked in the DB and reflected in the UI.
- [ ] **Infirmary tracking**: crew dice can be sent to the infirmary during combat and some events (e.g., event 52-D places two crew in the infirmary before combat begins). Track which officers are in the infirmary per campaign. Blocked on the combat system (priority #10) existing at all.
- [x] **Officer attribute additions**: `Officer#bonus_attributes` (json array) + `add_attribute!`, separate from the locked creation attributes. Wired for event 30-B (`gain_random_officer_attribute: "Restless"`, one random living officer), 51-D (`gain_all_officers_attribute: "Lucky"`, all officers), and 54-A's `[LIE]` branch (`gain_random_officer_attribute: "Mistrusting", gain_random_officer_attribute_count: 2`). `ChoiceRequirement` and conditional checks now see bonus attributes too, via `Officer#all_attributes`.
- [x] **Officer death / removal**: `Officer#dead` (boolean) + `kill!`. Wired for event 41-D (`kill_random_officer: true`, since the PDF doesn't specify which officer is lost). Dead officers are excluded from `ChoiceRequirement` matching and from random-selection for other officer mutations. Event 21-B's conditional kill (on a failed gladiator challenge) is still unwired — blocked on in-event dice rolls (priority #8) existing to know success/failure.
- [x] **Officer title change**: `Officer#title_override` (string) + `effective_title` (falls back to the titleized enum value). Data layer exists; not yet wired to event 21-B specifically, since that event's title change only matters alongside its (unbuilt) dice challenge.
- [ ] **Skill exchange at tavern**: event 51-A allows swapping an officer's specialty with another. Needs a UI step (pick officer, pick new specialty) and must update the officer record — `Officer#specialty` is currently locked-at-creation only; would need to become mutable too, unlike the other creation fields.

## Combat
The app currently has no combat system. Combat is triggered by Open Space encounters and many events.
- [ ] **Combat UI**: display the active threat cards in the scanner positions (Deep Space D6 board layout)
- [ ] **Draw deck**: randomly draw the specified number of cards from the main threat deck to form the combat draw deck
- [ ] **Threat card resolution**: step through the standard Deep Space D6 rules (draw → place → resolve)
- [ ] **Hull & shield tracking during combat**: show current hull and shield values, update as damage is taken
- [ ] **Crew dice assignment**: let player assign crew dice to ship stations and R&D tracks during step 3
- [ ] **No cards remaining rule**: if draw deck is empty, take 1 hull damage (shields first) until all external threats resolved
- [ ] **End of combat**: fully repair ship (hull + shields), return threat cards to deck, shuffle
- [ ] **Combat game over**: if ship destroyed, end campaign as a loss (unless event says otherwise)
- [ ] **Special combat — event 44-E (Endless)**: `Combat: 3+6` (9 cards total), always resolvable — uses the rulebook's own page-74 9-card demo deck (4× Spore: Attack, 2× Swarmling, Spore: Guard, Mothership, Infecter) for every player, expansion-owned or not. Not gated (no "EE" icon on this event). See `docs/reference/deep-space-d6-mechanics.md`.
- [ ] **Special combat — events 16-A / 17-A (Endless, expansion-gated)**: `Combat: 2+15` and `Combat: 1+10`. Both carry the rulebook's "EE" icon (`expansion: endless` in `events.yml`) — see "Expansion content flag" above. These are separate from 44-E and do not use the page-74 demo deck.
- [ ] **Special combat — event 67-A (Dreadship)**: scanner dice are placed on the Dreadship board, not the player's ship. Requires a different combat layout.
- [ ] **Special combat — event 57-A (The Shadow)**: 1-on-1 duel with special rules; if you lose, game over; if you win, he lets you go.
- [ ] **Special combat — event 58-C**: April gives a special weapon that modifies combat for this encounter.
- [ ] **Kinetic Recycler upgrade effect**: if 4+ hull lost in one round, gain 1 scrap
- [ ] **Promotion upgrade effect**: re-roll all available crew before step 3 (track uses)
- [ ] **Cloaking Device upgrade effect**: re-roll the threat die during step 5 (track uses; only available after discovered in an event)
- [ ] **Bio-Manipulator upgrade effect**: return a crew die from infirmary / prevent sending crew to infirmary (track uses)

## Research & Development
- [x] `researched_upgrades` column exists on campaigns table
- [ ] **R&D UI on character sheet / sidebar**: show all 6 upgrade tracks with their progress boxes
- [ ] **Research during combat**: assign crew dice to R&D tracks (crew must match the next required icon on the track)
- [ ] **Research at store locations**: roll all 6 crew dice and assign to tracks for the listed scrap cost
- [ ] **Unlock upgrades**: when all boxes on a track are filled, mark the upgrade as permanently unlocked and activate its effect
- [ ] **Track uses**: Promotion (6 uses), LR Scanners (4 uses), Bio-Manipulator (5 uses), Cloaking Device (6 uses)
- [ ] **Engine Repair cost**: costs 10 scrap to complete

## Win / Loss Conditions
- [x] `complete` action sets campaign status to `:completed`
- [ ] **Victory screen**: after reaching the Home hex and resolving the final event, show a proper end-game summary
- [ ] **Loss screen**: show when fuel runs out (21-A), ship is destroyed in combat, or a `game_over` event fires
- [ ] **Completed campaigns gallery**: show finished campaigns with outcome and summary on the campaign list page

## Quality of Life
- [ ] **Officer details visible during play**: a way to view officer names, titles, and specialties from the main map screen (needed to know which conditional choices apply)
- [ ] **Freeform journal notes**: let the player write their own narrative notes attached to the current campaign
- [ ] **Undo last action**: roll back the most recent game state change
