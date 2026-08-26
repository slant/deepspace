# Deep Space D-6 — Base Game Reference (narrative-relevant facts only)

**This app does not reimplement, simulate, or track the base game's combat
system in any form.** No ship boards, station abilities, threat decks, dice
rolls, or hull/shield tracking are modeled in code. When an event's body
text says `COMBAT: N threats, draw deck of M`, the player resolves that
combat on their own physical copy of the game and the app only needs to
know the *narrative* outcome (which branch/choice applies), exactly like
any other event — see the "Events YAML" sections of `CLAUDE.md` and
`docs/reference/events-yaml-pdf-deviations.md`'s 34-B/58-C entry for the
"defeat with no stated consequence → game_over" default. Per `CLAUDE.md`'s
"Dice Roll Scope": full combat and R&D dice are rolled on the player's
physical dice; the app never rolls them and never re-simulates the fight.

This doc keeps only the background facts that actually inform *narrative*
decisions (which events to show/gate, what "crew dice" means elsewhere in
the app). Source for anything not directly user-supplied: a detailed BGG
review (https://boardgamegeek.com/thread/2127056/deep-space-d-6-a-detailed-review
by Neil Thomson, "Destination Geek"), summarized/paraphrased in our own
words — not reproduced verbatim, and no game components (card text, art,
full rules) are copied here.

## Crew dice (confirmed — user-supplied photo of the physical dice, 2026-08-26)

The 6 crew dice are identical: each die has one of each of these 6 faces
(uniform 1/6 per face per die). This is real, confirmed data — not from the
PDF (which assumes ownership of the physical dice and never states it) or
the BGG review (which only described icon *types*, not the exact face set).
Used narratively by `app/services/crew_dice.rb` for the app's own simple
story-check rolls (fatigue checks, 22-A's threat-die table) — unrelated to
base-game combat.

| Color | Face |
|---|---|
| Silver | Threat Detected! |
| Blue (shield) | Commander |
| Green (hexagon) | Science |
| Orange (gears) | Engineering |
| Red (arrow) | Tactical |
| Purple (square) | Medical |

**There is no skull face.** Several events in `events.yml` referenced
"skull" for an icon `pdftotext` couldn't extract as text — a previous
session guessed at it without visual confirmation. Corrected to "Threat
Detected" throughout; see `docs/reference/events-yaml-pdf-deviations.md`.

## Engine Repair / Jump Drive (corrected 2026-08-26)

An earlier version of this doc and `TODO.md` conflated this with a
hypothetical "jump point" hex type needing map coordinate data — that was
wrong, and no such thing exists (checked `config/map.yml`/`events.yml`
directly, neither has any "jump" reference at all). The real mechanic,
per the user directly quoting rulebook page 4: **Engine Repair** is an R&D
upgrade (see the character sheet's R&D tracks) that, once complete, lets
the player move 2 spaces per turn instead of 1. **Jump Drive** requires
Engine Repair and has two separate uses, both costing 1 fuel:
- *In combat*: leave a combat encounter (resolved physically, per the
  no-simulation note above) by assigning 3 Engineering crew. No Open Space
  encounter triggers on return.
- *On the starmap*: "Return to the previous point" — i.e. undo your last
  move, not travel to a special map location. Needs the campaign to track
  its immediately-previous hex position.

Both uses are gated on Engine Repair being unlocked via R&D, which needs
the exact per-track box requirements (see "Blocked" note in `CLAUDE.md`) —
zoomed into the R&D section of the character sheet (page 6) and could read
gear-icon counts per box, but didn't want to build on an error-prone visual
pixel-count without confirmation.

## The Ouroboros (base game, optional) — narrative reference only

A base-game final-boss encounter, referenced in the narrative but never run
by any Long Way Home event's mechanics. Event **63-C** ("Ouroboros
Defeated") is post-battle narration ("The Ouroboros lies in wreckage...")
that awards item `[DATALOG-9]`. No Long Way Home event actually *runs* an
Ouroboros fight — the narrative assumes the player fought and beat it at
some point off-page, resolved entirely on the physical game, same as every
other `COMBAT:` line.

## The Endless Expansion — what it means for event gating

The rulebook marks expansion content with a printed "EE" icon — a small
rasterized graphic that `pdftotext` silently drops, so a text-only
extraction of the PDF misses it entirely. Confirmed by rendering the actual
pages as images. There are two unrelated categories of Endless-related
content in the 170 Long Way Home events, and they behave completely
differently for gating purposes:

### Category 1 — unmarked, always resolvable: event 44-E only

**44-E** ("The Endless Advance") carries **no EE icon** — verified visually,
not just missing from text extraction. Its text explicitly says "Use the
cards found on page 74," and its notation `Combat: 3+6` (3 threats already
placed + 6 in the draw deck = 9 cards) matches the page-74 demo deck's 9
cards exactly (4× Spore: Attack, 2× Swarmling, Spore: Guard, Mothership,
Infecter — captioned "Use only if you do not have The Endless Expansion
available"). 44-E is fully, correctly resolvable with just the page-74 set,
for every player, expansion-owned or not. No gating needed for this event.

### Category 2 — EE-marked, gated: events 16-A and 17-A, and Zeta Open Space rolls 2–6

**16-A** ("Heart of the Swarm," `Combat: 2+15`) and **17-A** ("Resistance,"
`Combat: 1+10`) both carry the printed EE icon next to their title *and*
their Combat line. Per rulebook pages 2 & 5: "Events marked with a [EE]
symbol denote the use of expansion content... If you do not have the
expansion, ignore these events." The Open Space Encounter Chart (page 8)
confirms the same pattern at the sector level: **Sector Zeta ("The Endless
Space")** has the EE icon on all 5 of its combat rows (rolls 2–6); only roll
1 (Empty Space) is unmarked. So every combat encounter anywhere in Sector
Zeta — both its two numbered story events and its Open Space rolls — is
expansion-gated, not just flavor-themed.

We have no need for real Endless Expansion card data (see the top of this
doc — the app never runs combat). The correct behavior for Category 2
content is to ignore it outright — treat it as if the encounter never
happened. See `config/events.yml`'s `expansion: endless` field and
TODO.md's "Expansion content flag" item.

## Licensing note

The base *Deep Space D-6* game (all of the above) is a separate commercial
product, not covered by the CC BY-SA license that applies only to the *Long
Way Home* narrative supplement text (per `CLAUDE.md`). This app should keep
reflecting only campaign/narrative state — fuel, scrap, cargo, choices,
journal — not reimplement or redistribute the base game's own rules,
components, or card text.

`public/docs/DSD6v061.pdf` and `public/ships/*.jpeg` are base-game physical
component references (Threat deck, Quick Rules, ship boards) the user
photographed/collected — not used as engine source data (the app doesn't
have a combat engine), just kept for the user's own reference. The user has
explicitly decided (2026-08-26) to keep these in `public/` despite being
web-servable, on the basis that this content is already publicly
distributed by the game's publisher. Do not re-flag this.
