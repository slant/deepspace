# events.yml — PDF Deviations Log

Running list of every way `config/events.yml` intentionally or knowingly
deviates from the original PDF rulebook. Faithful reproduction of the source
material is a project non-negotiable (see `CLAUDE.md`), so any deviation must
be justified and documented here.

**How to apply:** before making any change to `events.yml` that alters PDF
content (not just fixing our own earlier mistake), add an entry here. When
asked for the deviation list, present this file in full.

Migrated into the repo on 2026-08-25 from Claude's local session memory,
where it previously lived only on one machine and was never actually
committed — `CLAUDE.md` referenced it as a repo-relative path
(`memory/events_yaml_pdf_deviations.md`) that didn't exist in git.

---

## Corrections to our own past mistakes

| Entry | Description |
|-------|-------------|
| **16-A** | Removed an unsourced line, "Use the Endless cards from page 74 of the rulebook," that a previous session added to the body. The actual PDF page has no such instruction — 16-A carries the rulebook's printed "EE" (Endless Expansion) icon instead (missed originally because `pdftotext` silently drops that icon graphic; confirmed by rendering the page as an image). 16-A is expansion-gated content (see `docs/reference/deep-space-d6-mechanics.md`), unrelated to the page-74 demo deck, which is specific to event 44-E. Fixed 2026-08-25. |
| **21-B, 39-B, 42-A, 51-B, 61-B, 70-A, 72-A** | "skull" → "Threat Detected result" throughout. A previous session wrote "skull" for an icon `pdftotext` couldn't extract (rendered as a blank gap in the text), guessing at the icon without visual confirmation. Rendered the actual page as a high-resolution crop and confirmed the icon is the gray "Threat Detected!" crew die face (per the user's photo of the physical dice), not a skull — the crew dice have no skull face at all. Fixed 2026-08-26. |

## PDF Error Corrections (wrong/missing content in the PDF itself)

| Entry | Description |
|-------|-------------|
| **49-B** | "Visit the refueling depot" destination changed from `44-D` (PDF) to `72-B`. PDF value points to "Fluffy Creature" entry — apparent authoring typo. 72-B is the actual refueling depot used throughout all other Manaport entries. |
| **56-A** | PDF body is an exact duplicate of 48-A (AI containment puzzle). YAML preserves the content and adds a note flagging the apparent authoring error. No destination correction made — treated as same outcome as 48-A. |
| **28-C** | PDF sends to 78-B (success) and 24-C (failure) — neither entry exists in the rulebook. YAML collapses to Return to Orbit with a dead-end note. |
| **30-A** | PDF sends to 06-B and 07-A — neither exists. YAML collapses to Return to Orbit with a dead-end note. |

## Content Added (missing from YAML, present in PDF)

| Entry | Description |
|-------|-------------|
| **18-A** | Added missing sentence: *"The distress beacon originates from the Magnolia Foundation, one of the original settling dynasties."* Was in the PDF body but absent from the original YAML. Fixed 2026-05-27. |

## PDF Typo / Grammar Corrections

Minor authoring errors in the PDF corrected silently in the YAML:

| Entry | PDF text | YAML text |
|-------|----------|-----------|
| 11-C | "on of the planet's many islands" | "on one of the planet's many islands" |
| 14-A choice | "Advanced to the attack" | "Advance to the attack" |
| 14-C body | "emblems are avian insignia" | "emblems with avian insignia" |
| 15-A body | "all our war" | "all-out war" |
| 28-A body | "Overtime the planet's natural resources" | "Over time the planet's natural resources" |
| 28-D body | "small group up humans" | "small group of humans" |
| 33-C body | "citizens turns on you" | "citizens turn on you" |
| 38-B | "court marshal" | "court martial" |
| 44-E body | "single hive mine" | "single hive mind" |
| 58-B body | "April says he family" | "April says her family" |

## Terminology Normalization

| Entry | PDF text | YAML text | Reason |
|-------|----------|-----------|--------|
| 44-A body | "FLUE Sanctioned Goods" | "UEF-sanctioned goods" | PDF inconsistently uses "FLUE" in two places; YAML normalizes to "UEF" throughout |
| 64-A body | "FLUE standard issue boot" | "UEF standard issue boot" | Same as above |

## Structural / Presentation Decisions

Intentional re-presentations of PDF content that change structure but not meaning:

| Entry | Description |
|-------|-------------|
| **10-A** | PDF presents SYS-PUMP as an inline condition inside "buy replacement parts." YAML splits it into a separate choice for UI clarity. |
| **12-C body** | YAML adds `"COMBAT: see Patrol route A (→ 44-E)."` to the body. The PDF body has only story text; the combat reference is purely a choice label in the PDF. |
| **19-A** | PDF lists sequence/item endings as a text block under "THE END." YAML converts each into a discrete choice for UI routing. Instruction line added: *"Check your sequences and items below for additional endings before choosing Journey Complete."* |
| **37-A choice** | YAML choice label says "acquire [Lux Food]" but in the PDF the item is acquired at 49-B, not 37-A. The 15 scrap is gained at 37-A. Choice label is slightly premature about item acquisition. |
| **55-A title** | PDF title is **"Nice."** YAML uses **"The Spa"** for clarity. Content is identical. |
| **37-B title** | PDF titles both 37-A and 37-B "Odd Jobs." YAML titles 37-B "The Card Game Resolution" for clarity. |
| **73-C** | PDF uses lowercase `[vortex]`. YAML uses `[Vortex]` for consistency with item name conventions throughout the file. |
| **16-A, 17-A** | Added `expansion: endless` field (not present in the PDF's own data model, since the PDF just prints an icon). Represents the printed "EE" icon programmatically. See `docs/reference/deep-space-d6-mechanics.md`. |
| **34-B, 58-C, 67-A** | Added a "Game Over" choice for combat defeat. The PDF body states no defeat consequence for either event (unlike e.g. 15-A/44-E/51-C, which explicitly state one) — user-confirmed default (2026-08-26): a combat event silent on defeat ends the campaign, consistent with the physical game's own "Hull hits 0 = lose" rule. Apply this same default to any future combat event found to be silent on defeat. |

## Minor Phrasing Differences (low priority)

| Entry | PDF text | YAML text |
|-------|----------|-----------|
| 12-D body | "warm human greeting" | "warm greeting" (dropped "human") |
| 17-B body | "the doomsday ship was headed towards" | "the doomsday ship is headed towards" (tense change) |
| 17-D body | "It could be a trap?" | "It could be a trap." (punctuation) |
| 18-B choice | "Send both children back to the pirate colony" | "Send both children to the pirate colony" (missing "back") |
| 23-B body | "somewhat of a utopia" | "something of a utopia" |
