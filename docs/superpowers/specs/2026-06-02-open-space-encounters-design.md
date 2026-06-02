# Open Space Encounters — Design Spec

**Date:** 2026-06-02  
**Status:** Approved

## Problem

When the player moves to a blank/unactivated hex (Open Space), the modal currently shows a static placeholder: "Open space. Consult the encounter chart on page 8 of the rulebook." No d6 is rolled, no encounter is resolved, and no scrap is applied.

## Goal

Roll a d6 server-side, look up the sector-specific encounter chart, and return meaningful event data. Empty results show flavour text. Combat results show the setup instructions for manual resolution (combat system is a separate future feature). Scrap gains are applied automatically via the existing `scrap_delta` mechanism.

## Out of Scope

- Full combat system (separate major feature)
- Long Range Scanners upgrade effect (wire up when upgrades are tackled holistically)
- Open Space journal logging

## Encounter Chart (PDF page 9)

| Roll | Alpha | Beta | Delta | Zeta | Tau |
|------|-------|------|-------|------|-----|
| 1 | Empty | Empty | Empty | Gain 2 scrap | — |
| 2 | Empty | Empty | Empty | Combat 3+0 | — |
| 3 | Empty | Empty | Combat 2+6 +3 scrap | Combat 2+5 | — |
| 4 | Empty | Combat 2+4 | Combat 4+5 +3 scrap | Combat 2+5 | — |
| 5 | Combat 2+5 | Combat 3+2 | Combat 2+6 +4 scrap | Combat 3+6 | — |
| 6 | Combat 2+5 | Combat 3+5 | Combat 4+5 +5 scrap | Combat 4+7 | — |

Combat notation: `X+Y` = draw X threat cards, draw deck size Y.  
Tau has no encounters (UEF Homeworld space).

## Architecture

### New: `app/services/open_space_encounter.rb`

Single responsibility: encounter table lookup + event-hash generation.

**Public interface:**
```ruby
OpenSpaceEncounter.for_hex(hex, roll: nil)
# roll: injected integer 1–6 for tests; defaults to rand(1..6)
# Returns a complete event hash: { title:, body:, choices:, resolvable: }
```

**Private constants:**
- `ENCOUNTER_TABLE` — hash keyed by sector name (lowercase), value is an array of `{ rolls: Range, type: :empty | :combat | :scrap, threat: N, draw: N, scrap: N }` entries.
- Looked up with `entries.find { |e| e[:rolls].cover?(roll) }`.

**Result types and event shape:**

*Empty:*
```ruby
{
  title: "Open Space",
  body: "Empty space. Nothing on scanners.",
  choices: [{ "label" => "Return to Orbit", "action" => "orbit" }],
  resolvable: false
}
```

*Combat (no scrap):*
```ruby
{
  title: "Combat Encounter",
  body: "Draw 2 threat cards and place them on the scanners.\nThe draw deck consists of 5 additional threat cards.\n\nResolve combat using the standard Deep Space D-6 rules.",
  choices: [{ "label" => "Combat resolved — Return to Orbit", "action" => "orbit" }],
  resolvable: false
}
```

*Combat with scrap (Delta):*
```ruby
{
  title: "Combat Encounter",
  body: "Draw 2 threat cards and place them on the scanners.\nThe draw deck consists of 6 additional threat cards.\n\nResolve combat using the standard Deep Space D-6 rules.\nGain 3 scrap after combat.",
  choices: [{ "label" => "Combat resolved — Return to Orbit", "action" => "orbit", "metadata" => { "scrap_delta" => 3 } }],
  resolvable: false
}
```

*Scrap gain only (Zeta roll 1):*
```ruby
{
  title: "Open Space",
  body: "You salvage debris drifting through the void. Gain 2 scrap.",
  choices: [{ "label" => "Return to Orbit", "action" => "orbit", "metadata" => { "scrap_delta" => 2 } }],
  resolvable: false
}
```

*Tau / unknown sector:*
```ruby
{
  title: "Open Space",
  body: "Quiet space. No threats detected.",
  choices: [{ "label" => "Return to Orbit", "action" => "orbit" }],
  resolvable: false
}
```

### Modified: `app/services/event_catalog.rb`

Replace `open_space_event` body entirely:

```ruby
def open_space_event(hex)
  OpenSpaceEncounter.for_hex(hex)
end
```

Remove the `OPEN_SPACE` constant (no longer needed).

### No changes to:
- `HexEventsController` — already passes hex + campaign to `EventCatalog.for_hex`; the orbit PATCH action already applies `scrap_delta` from choice metadata
- JS modal controller — already reads `choice.metadata?.scrap_delta`
- Database schema

## Testing

`test/services/open_space_encounter_test.rb`

Cover:
- Alpha roll 1 → empty
- Alpha roll 4 → empty (boundary)
- Alpha roll 5 → combat, no scrap
- Alpha roll 6 → combat, no scrap (boundary)
- Beta roll 3 → empty
- Beta roll 4 → combat 2+4
- Beta roll 5 → combat 3+2
- Beta roll 6 → combat 3+5
- Delta roll 2 → empty
- Delta roll 3 → combat with 3 scrap
- Delta roll 6 → combat with 5 scrap
- Zeta roll 1 → scrap gain, scrap_delta in choice metadata
- Zeta roll 2 → combat 3+0 (draw deck 0)
- Tau → no encounter body, no scrap_delta
- Unknown sector → fallback (quiet space, no scrap_delta)
- Default roll is random (smoke test: result is a valid event hash)
