# Event Action Wiring — Design Spec
**Date:** 2026-05-29  
**Scope:** `goto`, `game_over`, and scrap/fuel side-effects on event choices

---

## Overview

Three action types in `events.yml` are currently unhandled in the controller:
- `goto` (208 of 307 choices) — navigates to a chained event
- `game_over` (9 choices) — ends the campaign as a loss
- Scrap/fuel deltas (~15 choices) — modify resources when a choice is made

The goal is to wire all three so the event modal correctly chains events, ends campaigns on loss, and updates resources — all with immediate server persistence.

---

## 1. Data Changes

### 1a. Campaign model — add `failed` status

Add `:failed` (value 3) to the `status` enum:

```ruby
enum :status, { draft: 0, active: 1, completed: 2, failed: 3 }
```

Add a `apply_resource_delta!` method:

```ruby
def apply_resource_delta!(scrap_delta: 0, fuel_delta: 0)
  return if scrap_delta.zero? && fuel_delta.zero?
  update!(
    scrap: [scrap + scrap_delta, 0].max,
    fuel:  [fuel  + fuel_delta,  0].max
  )
end
```

Resource values are floored at 0 (cannot go negative).

### 1b. events.yml — add metadata fields to affected choices

Add `scrap_delta` and/or `fuel_delta` integer fields to the `metadata` of each choice that modifies resources. Sign convention: positive = gain, negative = cost.

Examples:
```yaml
- label: "Spend 1 fuel — seek side jobs → 33-B"
  action: goto
  metadata: { goto: "33-B", fuel_delta: -1 }

- label: "Gain 100 scrap — Return to Orbit"
  action: orbit
  metadata: { scrap_delta: 100 }

- label: "Purchase board games for 2 scrap → 51-D"
  action: goto
  metadata: { goto: "51-D", scrap_delta: -2 }
```

Choices that mention items (e.g. `acquire [Lux Food]`) get the delta only; item tracking is deferred.

Choices without resource side effects need no change.

**Choices requiring metadata updates** (complete audit required during implementation):
- All `"Spend 1 fuel — ..."` choices (events 27-A, 35-B, 45-A, 47-A, 52-A): `fuel_delta: -1`
- Event 73-A fuel gain: `fuel_delta: 2`
- Event 26-A "Gain 100 scrap": `scrap_delta: 100`
- Event 28-D "gain 5 scrap": `scrap_delta: 5`
- Events 43-D "2 scrap", 44-D "1 scrap", 45-C "2 scrap" purchases: `scrap_delta: -2 / -1 / -2`
- Any other choice label containing "gain X scrap" or "spend X scrap" patterns

---

## 2. Server (`HexEventsController#update`)

### 2a. Accepted params

All action types now accept:
- `action_type` (string, required)
- `goto_target` (string, required when `action_type == "goto"`)
- `scrap_delta` (integer, default 0)
- `fuel_delta` (integer, default 0)
- `current_event_label` (string, optional — used for logging the "from" side of a goto chain)

### 2b. Action handling

```
case params[:action_type]
when "goto"
  apply resource deltas
  log "Event #{current_event_label} → #{goto_target}" (entry_type: "event")
  look up goto_target in EventCatalog
  return { ok: true, next_event: <event data + original hex>, campaign: <updated resources> }

when "game_over"
  apply resource deltas
  campaign.update!(status: :failed)
  log "Mission failed." (entry_type: "milestone")
  return { game_over: true, title: <event title>, body: <event body>, campaign: { ... } }

when "orbit"
  apply resource deltas
  (no-op otherwise)

when "complete"
  apply resource deltas
  campaign.update!(status: :completed)
  log "Reached home. Mission complete." (entry_type: "milestone")

when "resolve"
  campaign.resolve_event!(hex label)
end

render json: { ok: true, campaign: { ... } }
```

`next_event` response shape (for `goto`):
```json
{
  "ok": true,
  "next_event": {
    "title": "...",
    "body": "...",
    "choices": [...],
    "hex": { "q": ..., "r": ..., "label": "...", "icon": "...", "sector": "..." }
  },
  "campaign": { "scrap": ..., "fuel": ..., "status": "active" }
}
```

The `hex` in `next_event` is always the **original** hex (where the ship is docked), not the goto target event's hex. This ensures the modal's choice buttons continue to PATCH the correct URL.

### 2c. EventCatalog

No changes required — `EventCatalog.for_hex` is already callable with arbitrary hex data. For `goto`, we call `EventCatalog.events[goto_target]` directly (the normalized hash) rather than `for_hex`, since there's no hex context for chained events.

Add a `EventCatalog.for_event(event_id)` class method that normalizes and returns a single event by ID, returning `nil` for unknown IDs.

---

## 3. Frontend (`event_modal_controller.js`)

### 3a. `choose(hex, choice)` updates

Send additional fields from `choice.metadata`:
```js
body: JSON.stringify({
  action_type: choice.action,
  goto_target:  choice.metadata?.goto      || null,
  scrap_delta:  choice.metadata?.scrap_delta || 0,
  fuel_delta:   choice.metadata?.fuel_delta  || 0,
  current_event_label: this.currentEventLabel  // tracked on show()
})
```

### 3b. Response routing after PATCH

```
if response.game_over
  → show game over state in modal (see below)
else if response.next_event
  → this.show(response.next_event)   // modal updates in-place
else
  → this.close()
  → Turbo.visit(...)
end
→ dispatch "campaign:updated" (always, so HUD re-renders)
```

### 3c. Game over modal state

When `game_over: true` is received, transform the modal:
- Title: "Mission Failed"
- Body: the `body` from the response
- Choices replaced with a single button: "Return to Main Menu" — navigates to `/campaigns`

### 3d. `this.currentEventLabel` tracking

Add a `currentEventLabel` instance variable set in `show()` from `data.hex?.label`. This is passed in each PATCH for logging purposes.

### 3e. `campaign:updated` dispatch

Already dispatched in the existing `choose()`. Ensure it fires after all action types, including `goto` chains (fire after each step so HUD stays in sync as resources change mid-chain).

---

## Out of Scope (this session)

- Full loss screen (just minimal modal state for now)
- Item tracking (`[Lux Food]`, `[AI-System]`, etc.)
- Cargo sequence manipulation
- Conditional choice enforcement (officer attributes, items, flags)
- Fuel depletion → game over (event 21-A trigger)

---

## Testing Notes

- Unit test `Campaign#apply_resource_delta!`: gain, spend, floor at zero
- Controller test for `goto`: response includes `next_event`, log entry created, resource delta applied
- Controller test for `game_over`: campaign status set to `:failed`, log entry created
- Controller test for `orbit` with `scrap_delta`: scrap updated correctly
- Frontend: manual testing of a multi-step goto chain (e.g. 10-A → 41-A → ...) to verify modal updates in-place
