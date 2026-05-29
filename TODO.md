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
- [ ] Display character sheet (officers + attributes) somewhere accessible during play — the sidebar currently only shows ship name/captain, not officer details or their specialties

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
- [ ] **Roll d6 and consult sector-specific encounter chart** (currently just shows placeholder text; the actual chart from PDF page 8 needs to be implemented):
  - Alpha: 1–4 Empty, 5–6 Combat 2+5
  - Beta: 1–3 Empty, 4 Combat 2+4, 5 Combat 3+2, 6 Combat 3+5
  - Delta: 1–2 Empty, 3 Combat 2+6 +3 scrap, 4 Combat 4+5 +3 scrap, 5 Combat 2+6 +4 scrap, 6 Combat 4+5 +5 scrap
  - Zeta: 1 Gain 2 scrap, 2 Combat 3+0, 3 Combat 2+5, 4 Combat 2+5, 5 Combat 3+6, 6 Combat 4+7
  - Tau: No encounters
- [ ] **Long Range Scanners upgrade effect**: during Open Space roll, reduce the d6 result by 2 (min 1)

## Events & Choices
- [x] 170 events loaded from `config/events.yml`, QA'd against PDF
- [x] Event modal: title, body, choice buttons
- [x] `orbit` action: close modal, return to map
- [x] `complete` action: mark campaign won
- [x] Conditional choice labels present (e.g. `[Requires: HACKER]`)
- [ ] **`goto` action**: follow the chain to the next event, append each step to the event log (grouped/indented). See `memory/event_chain_ux.md`. This is the most commonly used action type.
- [ ] **`game_over` action**: wire in controller — currently unhandled. Should end campaign as a loss and show a loss screen.
- [ ] **Conditional choice enforcement — officer attributes/specialties**: `[Requires: HACKER]`, `[Requires: SMUGGLER, PSYCHIC, or CHARMING]` etc. are shown to all players but should be greyed out or hidden unless a matching officer exists on the campaign.
- [ ] **Conditional choice enforcement — items**: choices like `[Requires: AI-System]`, `[Requires: Flower Locket]`, `[Requires: Q-BOMB]`, `[Requires: SYS-PUMP]` require a named item in the cargo. Items must be tracked and checked.
- [ ] **Conditional choice enforcement — cargo sequences**: choices like `[Requires: Sequence L + Sequence 711]`, `[Requires: Sequence Z underlined]`, `[Circled sequence 000]` branch based on which substrings in the cargo string are underlined or circled. The enforcement layer must check the cargo state.
- [ ] **Story flags**: some events grant named flags (e.g., discovering the Cloaking Device, gaining RESTLESS). These need to be tracked in campaign state and checked during conditional choices.
- [ ] **Items**: events award bracketed items (e.g., `[Lux Food]`, `[AI-System]`, `[EE7]`, `[PandoraBox]`). Items need to be written into cargo, checked for conditionals, and crossed out when lost (e.g., event 69-A loses `[PandoraBox]`).
- [ ] **Cargo sequence manipulation**: some event choices instruct the player to underline or circle specific substrings in the cargo string (e.g., "underline sequence 99", "circle sequence 000"). Needs interactive UI — tap a token to toggle underline/circle state — and the state must persist in campaign.
- [ ] **Scrap side-effects on choices**: many `orbit` and `goto` choices say "gain X scrap" or "spend X scrap" in their label (e.g., event 26-A: "Gain 100 scrap", event 28-D: "gain 5 scrap", event 43-D: "Purchase board games for 2 scrap"). The controller currently does not apply these changes. Needs a `scrap_delta` metadata field (or label parsing) wired to `campaign.scrap`.
- [ ] **Fuel side-effects on choices**: choices in events 27-A, 35-B, 45-A, 47-A, 52-A say "Spend 1 fuel" and event 73-A gives 2 free fuel. The controller must decrement/increment `campaign.fuel` when these choices are selected.
- [ ] **Multi-action store UI**: events 20-A, 20-B, and 20-C are hub stores where the player can perform *any number* of independent actions in one visit (purchase items, buy fuel for scrap, research with crew dice). The current single-choice modal doesn't support this — needs a checklist/multi-step UI for these events.
- [ ] **Fuel depot — buy fuel for scrap**: 20-A sells 1 fuel per 4 scrap (limit 5); 20-B sells 1 fuel per 6 scrap (no limit); 20-C sells 1 fuel per 5 scrap (limit 5).
- [ ] **Store — buy items for scrap**: event 20-A sells `[SYS-PUMP]` for 5 scrap. Purchasing must add the item to cargo and deduct scrap.
- [ ] **Expansion content flag**: some events are marked for the Endless Expansion only. These events should be skippable (or flagged as unavailable) for players without the expansion. Needs a campaign setting and filtering in EventCatalog.
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
- [ ] **Fuel depletion = game over**: when fuel hits 0 and player tries to move, trigger event 21-A ("Out of Fuel") instead of silently blocking movement
- [ ] **Scrap gain/loss from events**: events that award or cost scrap (e.g. open space combat in Delta/Zeta sectors) need to update `campaign.scrap` and reflect in HUD
- [ ] **Cargo sequence interactions**: see Events section above (circling/underlining characters)

## Officer State
Officers can be permanently modified by events — this needs to be tracked in the DB and reflected in the UI.
- [ ] **Infirmary tracking**: crew dice can be sent to the infirmary during combat and some events (e.g., event 52-D places two crew in the infirmary before combat begins). Track which officers are in the infirmary per campaign.
- [ ] **Officer attribute additions**: events can permanently add attributes to officers (event 30-B adds RESTLESS to a random officer; event 51-D adds LUCKY to all officers). Needs a mutable attributes list per officer, separate from the initial locked attributes.
- [ ] **Officer death / removal**: events can permanently kill or remove an officer (event 41-D: cross out an officer; event 21-B: if GLADIATOR officer fails a challenge, cross out the entire officer). Need a `dead` or `removed` flag per officer and to exclude them from conditionals and dice rolls.
- [ ] **Officer title change**: event 21-B temporarily changes an officer's title to GLADIATOR. Needs a mutable title field (or override) tracked per officer.
- [ ] **Skill exchange at tavern**: event 51-A allows swapping an officer's specialty with another. Needs a UI step and must update the officer record.

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
- [ ] **Special combat — event 15-A / 44-E (Endless)**: uses Endless Expansion cards from page 74; only available with expansion. 10 threats, draw deck of 0.
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
