# Deep Space D-6 — Base Game & Endless Expansion Mechanics Reference

Background notes on the base *Deep Space D-6* board game and its *Endless*
expansion, for context when building this app's combat system (TODO priority
#10) and the game's "Endless"-themed encounters (44-E, 16-A, 17-A, and Sector
Zeta's Open Space rolls). Source: a detailed BGG review
(https://boardgamegeek.com/thread/2127056/deep-space-d-6-a-detailed-review by
Neil Thomson, "Destination Geek"), summarized/paraphrased in our own words —
not reproduced verbatim, and no game components (card text, art, full rules)
are copied here. This app does not reimplement the base game; it only tracks
narrative campaign state (fuel, scrap, cargo, choices) per `CLAUDE.md`. This
doc exists purely so future combat-system work has real mechanical grounding
instead of guessing.

## Core round structure (base game)

1. **Roll crew dice** — 6 custom icon dice (Tactical/weapons, Engineering/hull
   repair, Science/shields, Medical, Commander) represent available crew.
2. **Scan for threats** — a subset of results lock into "Scanner" slots. When
   all scanner slots fill, a new Threat card is drawn immediately (possibly
   more than one per roll).
3. **Assign crew** — remaining dice are placed on ship stations or on Threat
   cards to activate abilities / deal with threats. This is the core
   worker-placement decision each round.
4. **Deal damage** — Tactical results damage External Threats, tracked via a
   Damage Track with strength slots (1–4); a Threat at 1 health that takes
   damage is destroyed.
5. **Draw a new threat** — always happens *after* crew assignment, so a fresh
   threat can't be dealt with for at least one full round.
6. **Threat phase** — roll a plain d6; any Threat card whose listed value
   matches activates its effect. Multiple threats can share a value and all
   trigger off one roll.
7. **Shields/Hull** — damage hits Shields first, then Hull.
8. **Gather crew** — free dice return to the pool. Dice stay locked if
   they're mid-scan, in the Infirmary, or attached to an unresolved Threat.

**Win**: Hull > 0, Threat deck empty, and all External Threats destroyed.
**Lose**: Hull hits 0, or all dice become permanently unavailable.

If the Threat deck runs out before win/lose and a full scan completes, the
ship takes 1 damage instead of drawing a card (there's nothing left to draw).

## Ship classes (4, matching `CLAUDE.md`'s character-creation options)

Each class has different Hull/Shield stats and turns the 5 crew icons into
different abilities. Rough shape, for future reference (not exhaustive —
consult a rules copy before implementing combat):

- **Halcyon** ("Old Reliable") — Hull 8 / Shield 4. Lasers can split damage
  across multiple targets; has a Stasis Beam to nullify a threat for a round.
- **Athena Mk. II** ("The Enforcer") — Hull 5 / Shield 6. Rockets hit a single
  target hard; Quantum Cannon can return a threat to the deck and reshuffle.
- **AG-8** ("The Tin Can") — Hull 10 / Shield 2. Fights via reprogrammable
  Drones instead of direct crew actions; can't lose while a Drone is active.
- **Mononoaware** ("Roswell") — Hull 5 / Shield 5. Flexible alien weapon tech;
  can swap Shield/Hull values at a critical moment (Ablative Armor).

## The Ouroboros (base game, optional)

A 6-card mega-ship final boss, **not part of the Endless Expansion** — it's
an optional add-on to the *base* game's own Threat deck. Either shuffled into
the deck (arrives as a surprise) or set aside to appear once the deck is
exhausted (arrives as the guaranteed final fight). Has defensive components
that must be cleared before its 4-Health Core can be destroyed; destroying
the Core removes the whole thing.

Correction: an earlier version of this doc claimed the Ouroboros is never
referenced in the Long Way Home events — that was wrong. Event **63-C**
("Ouroboros Defeated") is post-battle narration ("The Ouroboros lies in
wreckage...") that awards item `[DATALOG-9]`. No Long Way Home event actually
*runs* an Ouroboros fight (no event references its cards or Core mechanic),
but the narrative does assume the player fought and beat it at some point
off-page. Worth keeping in mind if/when the combat system is built.

## The Endless Expansion

Three additions on top of the base game:
1. A full replacement Threat deck (different enemies, not mixed with the base
   deck).
2. Research/Upgrade tracks — crew must be assigned to upgrade tracks in a
   specific required order to unlock permanent ship upgrades. This lines up
   with the `researched_upgrades` column and the upgrade list already in
   `CLAUDE.md` (Engine Repair, Promotion, Kinetic Recycler, LR Scanners,
   Bio-Manipulator, Cloaking Device).
3. **The Apex** — the expansion's final boss, a *different* 6-card encounter
   from the Ouroboros. Its 6 cards are placed 2 each on the 4/3/2 Damage
   Track spots; the card art is illustrated so adjacent cards visually
   "connect," and a Threat-die roll can trigger chained/combo attacks across
   connected cards. As it takes damage, cards shift position on the track,
   changing which cards are connected — a genuinely clever mutating-boss
   mechanic. It can't be attacked until every other External Threat is
   destroyed, and only enters play once the (expansion) Threat deck is
   exhausted.

## What this actually means for our events — two distinct categories

The rulebook marks expansion content with a printed "EE" icon — a small
rasterized graphic that `pdftotext` silently drops, so a text-only extraction
of the PDF misses it entirely. Confirmed by rendering the actual pages as
images. There are two unrelated categories of Endless-related combat content
in the 170 Long Way Home events, and they behave completely differently:

### Category 1 — unmarked, always resolvable: event 44-E only

**44-E** ("The Endless Advance") carries **no EE icon** — verified visually,
not just missing from text extraction. Its text explicitly says "Use the
cards found on page 74," and its notation `Combat: 3+6` (3 threats already
placed + 6 in the draw deck = 9 cards) matches the page-74 demo deck's 9
cards exactly (4× Spore: Attack, 2× Swarmling, Spore: Guard, Mothership,
Infecter — captioned "Use only if you do not have The Endless Expansion
available"). 44-E is fully, correctly resolvable with just the page-74 set,
for every player, expansion-owned or not. No gating, no toggle, no Apex data
needed for this event.

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

These do **not** use the page-74 demo deck (that's captioned specifically as
a fallback the rulebook offers for 44-E, not a general-purpose substitute)
and do **not** use the Apex (that's a completely separate mechanic tied to
exhausting the *expansion's own* Threat deck during full base-game play, not
referenced anywhere in the Long Way Home narrative content). We have no real
Endless Expansion card data. Until we do, the correct behavior for
Category 2 content is to ignore it outright — treat it as if the encounter
never happened — regardless of whether a future "owns the expansion" toggle
exists, since there's nothing to actually run for an owner either without
the real cards. See `config/events.yml`'s `expansion: endless` field and
TODO.md's "Expansion content flag" item.

## Licensing note

The base *Deep Space D-6* game (all of the above) is a separate commercial
product, not covered by the CC BY-SA license that applies only to the *Long
Way Home* narrative supplement text (per `CLAUDE.md`). This app should keep
reflecting only campaign/narrative state — fuel, scrap, cargo, choices,
journal — not reimplement or redistribute the base game's own rules,
components, or card text. Any base-game PDF (e.g. a rules quick-reference)
should not be committed under `public/` or anywhere web-servable, since that
would make copyrighted content directly downloadable regardless of whether a
visitor owns the game.
