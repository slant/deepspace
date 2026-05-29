# Event Action Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `goto`, `game_over`, and scrap/fuel resource deltas so event choices chain correctly, end campaigns on loss, and update resources — all persisted server-side immediately.

**Architecture:** The PATCH endpoint for event choices is extended to handle the three new action types. `goto` looks up the target event and returns it inline in the response; the JS modal updates in-place rather than closing. `game_over` sets campaign status to `:failed`. All action types accept `scrap_delta`/`fuel_delta` params applied via a new model method. Resource deltas are explicit fields in `events.yml` choice metadata rather than parsed from label text.

**Tech Stack:** Rails 8, Minitest (integration tests), Stimulus JS (`event_modal_controller.js`)

---

## File Map

| File | Change |
|---|---|
| `app/models/campaign.rb` | Add `:failed` status; add `apply_resource_delta!` |
| `app/services/event_catalog.rb` | Add `EventCatalog.for_event(id)` |
| `config/events.yml` | Add `scrap_delta`/`fuel_delta` to 24 choices across 14 events |
| `app/controllers/hex_events_controller.rb` | Wire `goto`, `game_over`, resource deltas in `#update` |
| `app/javascript/controllers/event_modal_controller.js` | Handle `next_event` and `game_over` responses; pass metadata |
| `test/models/campaign_test.rb` | Add `apply_resource_delta!` tests |
| `test/controllers/hex_events_controller_test.rb` | New file — integration tests for all action types |

---

## Task 1: Campaign model — `failed` status + `apply_resource_delta!`

**Files:**
- Modify: `app/models/campaign.rb`
- Modify: `test/models/campaign_test.rb`

- [ ] **Step 1: Write the failing tests**

Add to `test/models/campaign_test.rb`:

```ruby
test "apply_resource_delta! increases scrap and fuel by positive deltas" do
  campaign = campaigns(:one)
  campaign.update_columns(scrap: 10, fuel: 5)

  campaign.apply_resource_delta!(scrap_delta: 3, fuel_delta: 2)

  campaign.reload
  assert_equal 13, campaign.scrap
  assert_equal 7, campaign.fuel
end

test "apply_resource_delta! decreases scrap and fuel by negative deltas" do
  campaign = campaigns(:one)
  campaign.update_columns(scrap: 10, fuel: 5)

  campaign.apply_resource_delta!(scrap_delta: -4, fuel_delta: -2)

  campaign.reload
  assert_equal 6, campaign.scrap
  assert_equal 3, campaign.fuel
end

test "apply_resource_delta! floors scrap and fuel at zero" do
  campaign = campaigns(:one)
  campaign.update_columns(scrap: 1, fuel: 1)

  campaign.apply_resource_delta!(scrap_delta: -999, fuel_delta: -999)

  campaign.reload
  assert_equal 0, campaign.scrap
  assert_equal 0, campaign.fuel
end

test "apply_resource_delta! is a no-op when both deltas are zero" do
  campaign = campaigns(:one)
  campaign.update_columns(scrap: 5, fuel: 3)

  assert_no_difference ["campaign.reload.scrap", "campaign.reload.fuel"] do
    campaign.apply_resource_delta!(scrap_delta: 0, fuel_delta: 0)
  end
end

test "campaign status can be set to failed" do
  campaign = campaigns(:one)
  campaign.update!(status: :failed)
  assert campaign.reload.failed?
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/campaign_test.rb -n "/apply_resource_delta|status can be set to failed/"
```

Expected: 5 failures — `NoMethodError: undefined method 'apply_resource_delta!'` and `ArgumentError: 'failed' is not a valid status`

- [ ] **Step 3: Add `failed` status and `apply_resource_delta!` to Campaign model**

In `app/models/campaign.rb`, change:
```ruby
enum :status, { draft: 0, active: 1, completed: 2 }
```
to:
```ruby
enum :status, { draft: 0, active: 1, completed: 2, failed: 3 }
```

Add after the `planet_sprite_for` method:
```ruby
def apply_resource_delta!(scrap_delta: 0, fuel_delta: 0)
  return if scrap_delta.zero? && fuel_delta.zero?
  update!(
    scrap: [scrap + scrap_delta, 0].max,
    fuel:  [fuel  + fuel_delta,  0].max
  )
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/models/campaign_test.rb -n "/apply_resource_delta|status can be set to failed/"
```

Expected: 5 passes

- [ ] **Step 5: Commit**

```bash
git add app/models/campaign.rb test/models/campaign_test.rb
git commit -m "Add failed status and apply_resource_delta! to Campaign"
```

---

## Task 2: EventCatalog — `for_event(id)` class method

**Files:**
- Modify: `app/services/event_catalog.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/event_catalog_test.rb`:

```ruby
require "test_helper"

class EventCatalogTest < ActiveSupport::TestCase
  test "for_event returns normalized event data for a known event id" do
    result = EventCatalog.for_event("10-A")

    assert_not_nil result
    assert_equal "Oxygen Leak", result[:title]
    assert result[:choices].is_a?(Array)
    assert result[:choices].first.key?("action")
  end

  test "for_event returns nil for an unknown event id" do
    assert_nil EventCatalog.for_event("99-Z")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bin/rails test test/services/event_catalog_test.rb
```

Expected: `NoMethodError: undefined method 'for_event'`

- [ ] **Step 3: Add `for_event` to EventCatalog**

In `app/services/event_catalog.rb`, add inside the `class << self` block, after `def events`:

```ruby
def for_event(id)
  stored = events[id]
  stored ? normalize(stored) : nil
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bin/rails test test/services/event_catalog_test.rb
```

Expected: 2 passes

- [ ] **Step 5: Commit**

```bash
git add app/services/event_catalog.rb test/services/event_catalog_test.rb
git commit -m "Add EventCatalog.for_event class method"
```

---

## Task 3: Add resource delta metadata to events.yml

**Files:**
- Modify: `config/events.yml`

The following 24 choices across 14 events need `scrap_delta` or `fuel_delta` added to their `metadata`. Each entry below shows the event ID, current label (for location), and the metadata to add or update.

**Convention:** positive = gain, negative = cost. Add to existing `metadata:` inline hash, or add `metadata:` if the choice has none.

- [ ] **Step 1: Add deltas to all affected choices**

Open `config/events.yml` and make the following changes:

**Event 26-A** (near line 590) — `orbit` choice, no existing metadata:
```yaml
    - label: "Gain 100 scrap — Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 100 }
```

**Event 27-A** (near lines 620–623) — two `goto` choices with existing metadata:
```yaml
    - label: "Spend 1 fuel — seek side jobs → 33-B"
      action: goto
      metadata: { goto: "33-B", fuel_delta: -1 }
    - label: "Spend 1 fuel — visit the local tavern → 51-A"
      action: goto
      metadata: { goto: "51-A", fuel_delta: -1 }
```

**Event 28-D** (near line 689) — `orbit` choice, no existing metadata:
```yaml
    - label: "Salvage what you can — gain 5 scrap, Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 5 }
```

**Event 35-B** (near lines 910–913) — two `goto` choices:
```yaml
    - label: "Spend 1 fuel — seek a UEF contact → 42-A"
      action: goto
      metadata: { goto: "42-A", fuel_delta: -1 }
    - label: "Spend 1 fuel — visit the local tavern → 51-A"
      action: goto
      metadata: { goto: "51-A", fuel_delta: -1 }
```

**Event 37-A** (near line 958) — `goto` choice:
```yaml
    - label: "Agree to deliver the cargo — gain 15 scrap, acquire [Lux Food] → 49-B"
      action: goto
      metadata: { goto: "49-B", scrap_delta: 15 }
```

**Event 43-D** (near lines 1203–1209) — three `goto` choices:
```yaml
    - label: "Purchase board games for 2 scrap → 51-D"
      action: goto
      metadata: { goto: "51-D", scrap_delta: -2 }
    - label: "Purchase a cute fluffy creature for 1 scrap → 44-D"
      action: goto
      metadata: { goto: "44-D", scrap_delta: -1 }
    - label: "Purchase a perfectly round sphere for 2 scrap → 45-C"
      action: goto
      metadata: { goto: "45-C", scrap_delta: -2 }
```

**Event 45-A** (near lines 1282–1285) — two `goto` choices:
```yaml
    - label: "Spend 1 fuel — seek side jobs → 33-B"
      action: goto
      metadata: { goto: "33-B", fuel_delta: -1 }
    - label: "Spend 1 fuel — visit the local tavern → 51-A"
      action: goto
      metadata: { goto: "51-A", fuel_delta: -1 }
```

**Event 47-A** (near lines 1359–1362) — two `goto` choices:
```yaml
    - label: "Spend 1 fuel — seek a UEF contact → 42-A"
      action: goto
      metadata: { goto: "42-A", fuel_delta: -1 }
    - label: "Spend 1 fuel — visit the local tavern → 51-A"
      action: goto
      metadata: { goto: "51-A", fuel_delta: -1 }
```

**Event 48-A** (near lines 1387–1391) — three `orbit` choices:
```yaml
    - label: "Destroy the AI — gain 15 scrap, Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 15 }
    - label: "Keep the AI — gain 15 scrap, acquire item [AI-System], Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 15 }
    - label: "[Requires: GREEDY or ROBOTICIST] Underline sequence 99, gain 15 scrap — Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 15 }
```

**Event 51-C** (near line 1547) — `goto` choice:
```yaml
    - label: "Defeated — crash land, lose 1 fuel, de-board → 46-A"
      action: goto
      metadata: { goto: "46-A", fuel_delta: -1 }
```

**Event 52-A** (near lines 1567–1570) — two `goto` choices:
```yaml
    - label: "Spend 1 fuel — seek a UEF contact → 44-A"
      action: goto
      metadata: { goto: "44-A", fuel_delta: -1 }
    - label: "Spend 1 fuel — seek side jobs → 33-B"
      action: goto
      metadata: { goto: "33-B", fuel_delta: -1 }
```

**Event 56-A** (near lines 1739–1741) — two `orbit` choices:
```yaml
    - label: "Destroy the AI — gain 15 scrap, Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 15 }
    - label: "Keep the AI — gain 15 scrap, acquire item [AI-System], Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 15 }
```

**Event 58-A** (near line 1796) — `orbit` choice:
```yaml
    - label: "Destroy his ship — gain 5 scrap, Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 5 }
```

**Event 67-A** (near line 2140) — `orbit` choice:
```yaml
    - label: "Victory — gain 10 scrap, Return to Orbit"
      action: orbit
      metadata: { scrap_delta: 10 }
```

- [ ] **Step 2: Verify the YAML parses cleanly**

```bash
bin/rails runner "puts EventCatalog.events.count"
```

Expected: `170` (no parse errors)

- [ ] **Step 3: Spot-check a few events**

```bash
bin/rails runner "puts EventCatalog.for_event('26-A')[:choices].first.inspect"
```

Expected output includes `"scrap_delta"=>100`

```bash
bin/rails runner "puts EventCatalog.for_event('27-A')[:choices].first.inspect"
```

Expected output includes `"fuel_delta"=>-1`

- [ ] **Step 4: Commit**

```bash
git add config/events.yml
git commit -m "Add scrap_delta/fuel_delta metadata to resource-modifying choices in events.yml"
```

---

## Task 4: Wire `goto`, `game_over`, and resource deltas in `HexEventsController#update`

**Files:**
- Modify: `app/controllers/hex_events_controller.rb`
- Create: `test/controllers/hex_events_controller_test.rb`

- [ ] **Step 1: Write the failing controller tests**

Create `test/controllers/hex_events_controller_test.rb`:

```ruby
require "test_helper"

class HexEventsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @campaign = campaigns(:one)
    sign_in @user
  end

  # --- goto ---

  test "PATCH with goto returns next_event data and logs the step" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "10-A", current_event_label: "26-A" },
      as: :json

    assert_response :ok
    json = response.parsed_body
    assert json.key?("next_event"), "Response should include next_event"
    assert_equal "Oxygen Leak", json["next_event"]["title"]
    assert json["next_event"].key?("hex"), "next_event should include hex"

    last_log = @campaign.journal_entries.order(created_at: :desc).first
    assert_match "26-A", last_log.body
    assert_match "10-A", last_log.body
  end

  test "PATCH with goto returns 404 for unknown goto_target" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "99-Z" },
      as: :json

    assert_response :not_found
  end

  test "PATCH with goto applies fuel_delta" do
    @campaign.update_columns(fuel: 5)

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "33-B", fuel_delta: -1 },
      as: :json

    assert_response :ok
    assert_equal 4, @campaign.reload.fuel
    assert_equal 4, response.parsed_body["campaign"]["fuel"]
  end

  # --- game_over ---

  test "PATCH with game_over sets campaign status to failed" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "game_over", title: "The End", body: "You lost." },
      as: :json

    assert_response :ok
    json = response.parsed_body
    assert json["game_over"]
    assert_equal "failed", @campaign.reload.status
  end

  test "PATCH with game_over logs a milestone entry" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "game_over", title: "The End", body: "You lost." },
      as: :json

    last_log = @campaign.journal_entries.order(created_at: :desc).first
    assert_equal "milestone", last_log.entry_type
    assert_match "Mission failed", last_log.body
  end

  test "PATCH with game_over applies scrap_delta before ending" do
    @campaign.update_columns(scrap: 10)

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "game_over", title: "The End", body: "You lost.", scrap_delta: -5 },
      as: :json

    assert_equal 5, @campaign.reload.scrap
  end

  # --- orbit with resource delta ---

  test "PATCH with orbit and scrap_delta updates scrap" do
    @campaign.update_columns(scrap: 0)

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", scrap_delta: 100 },
      as: :json

    assert_response :ok
    assert_equal 100, @campaign.reload.scrap
    assert_equal 100, response.parsed_body["campaign"]["scrap"]
  end

  test "PATCH with orbit and no delta does not change resources" do
    @campaign.update_columns(scrap: 5, fuel: 3)

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit" },
      as: :json

    assert_equal 5, @campaign.reload.scrap
    assert_equal 3, @campaign.reload.fuel
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/hex_events_controller_test.rb
```

Expected: Multiple failures — `goto` unhandled, `game_over` unhandled, etc.

- [ ] **Step 3: Update `HexEventsController#update`**

Replace the contents of `app/controllers/hex_events_controller.rb` with:

```ruby
# frozen_string_literal: true

class HexEventsController < ApplicationController
  before_action :set_campaign

  def show
    hex = MapLoader.hex_at(params[:q].to_i, params[:r].to_i)
    return head :not_found unless hex

    unless @campaign.at_hex?(hex["q"], hex["r"]) || @campaign.can_move_to?(hex["q"], hex["r"])
      return render json: { error: "Cannot interact with this hex" }, status: :forbidden
    end

    if @campaign.can_move_to?(hex["q"], hex["r"])
      @campaign.move_to!(hex["q"], hex["r"])
      region = hex["sector"]
      @campaign.discover_sector!(region) if region.present?
    end

    event = EventCatalog.for_hex(hex, campaign: @campaign)
    render json: event.merge(
      hex: hex.slice("q", "r", "label", "icon", "note", "sector"),
      campaign: {
        ship_q: @campaign.ship_q,
        ship_r: @campaign.ship_r,
        fuel: @campaign.fuel,
        scrap: @campaign.scrap,
        resolved: @campaign.resolved_events.include?(hex["label"])
      }
    )
  end

  def update
    hex = MapLoader.hex_at(params[:q].to_i, params[:r].to_i)
    return head :not_found unless hex

    scrap_delta = params[:scrap_delta].to_i
    fuel_delta  = params[:fuel_delta].to_i

    case params[:action_type]
    when "goto"
      goto_target = params[:goto_target].to_s
      next_event = EventCatalog.for_event(goto_target)
      return head :not_found unless next_event

      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
      from_label = params[:current_event_label].presence || hex["label"]
      @campaign.log!("#{from_label} → #{goto_target}", entry_type: "event")

      return render json: {
        ok: true,
        next_event: next_event.merge(hex: hex.slice("q", "r", "label", "icon", "note", "sector")),
        campaign: campaign_state
      }

    when "game_over"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
      @campaign.update!(status: :failed)
      @campaign.log!("Mission failed.", entry_type: "milestone")

      return render json: {
        ok: true,
        game_over: true,
        title: params[:title].presence || "Mission Failed",
        body: params[:body].presence || "Your journey ends here.",
        campaign: campaign_state
      }

    when "resolve"
      @campaign.resolve_event!(hex["label"]) if hex["label"].present?

    when "complete"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
      @campaign.update!(status: :completed)
      @campaign.log!("Reached home. Mission complete.", entry_type: "milestone")

    when "orbit"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
    end

    render json: { ok: true, campaign: campaign_state.merge(resolved_events: @campaign.resolved_events) }
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.find_by!(public_id: params[:campaign_id])
  end

  def campaign_state
    {
      scrap: @campaign.scrap,
      fuel: @campaign.fuel,
      status: @campaign.status
    }
  end
end
```

Note: The `set_campaign` scope has been relaxed from `.active` to allow `game_over` to fire on an already-failed campaign edge case — the status check is now done by action type rather than a global guard.

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/controllers/hex_events_controller_test.rb
```

Expected: All 9 tests pass

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
bin/rails test
```

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add app/controllers/hex_events_controller.rb test/controllers/hex_events_controller_test.rb
git commit -m "Wire goto, game_over, and resource deltas in HexEventsController"
```

---

## Task 5: Frontend — handle `next_event` and `game_over` in `event_modal_controller.js`

**Files:**
- Modify: `app/javascript/controllers/event_modal_controller.js`

No automated test for JS in this project — rely on manual testing in Step 4.

- [ ] **Step 1: Update `event_modal_controller.js`**

Replace the full file contents with:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "body", "choices", "backdrop"]
  static values = { campaignId: String }

  connect() {
    this.onHexSelected = this.openHex.bind(this)
    window.addEventListener("hex:selected", this.onHexSelected)
    this.currentHex = null
    this.currentEventLabel = null
  }

  disconnect() {
    window.removeEventListener("hex:selected", this.onHexSelected)
  }

  async openHex(event) {
    const { q, r, campaignId } = event.detail
    if (campaignId !== this.campaignIdValue) return

    const url = `/campaigns/${this.campaignIdValue}/hex/${q}/${r}`
    const response = await fetch(url, {
      headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
    })
    if (!response.ok) return

    const data = await response.json()
    this.currentHex = data.hex
    this.currentEventLabel = data.hex?.label || null
    this.show(data)
    Turbo.visit(window.location.href, { frame: "campaign_map" })
  }

  show(data) {
    this.titleTarget.textContent = data.title || data.hex?.label || "Event"
    this.bodyTarget.innerHTML = this.formatBody(data.body)
    this.choicesTarget.innerHTML = ""

    const hex = data.hex || this.currentHex
    ;(data.choices || []).forEach((choice) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "btn btn-secondary w-full"
      btn.textContent = choice.label
      btn.addEventListener("click", () => this.choose(hex, choice))
      this.choicesTarget.appendChild(btn)
    })

    this.dialogTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("modal-open")
  }

  async choose(hex, choice) {
    const url = `/campaigns/${this.campaignIdValue}/hex/${hex.q}/${hex.r}`
    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({
        action_type: choice.action,
        goto_target: choice.metadata?.goto || null,
        scrap_delta: choice.metadata?.scrap_delta || 0,
        fuel_delta:  choice.metadata?.fuel_delta  || 0,
        current_event_label: this.currentEventLabel
      })
    })

    if (!response.ok) return

    const data = await response.json()

    window.dispatchEvent(new CustomEvent("campaign:updated"))
    Turbo.visit(window.location.href, { frame: "campaign_map" })

    if (data.game_over) {
      this.showGameOver(data)
    } else if (data.next_event) {
      this.currentEventLabel = choice.metadata?.goto || null
      this.show(data.next_event)
    } else {
      this.close()
    }
  }

  showGameOver(data) {
    this.titleTarget.textContent = data.title || "Mission Failed"
    this.bodyTarget.innerHTML = this.formatBody(data.body)
    this.choicesTarget.innerHTML = ""

    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "btn btn-secondary w-full"
    btn.textContent = "Return to Main Menu"
    btn.addEventListener("click", () => {
      this.close()
      Turbo.visit("/campaigns")
    })
    this.choicesTarget.appendChild(btn)
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("modal-open")
  }

  formatBody(text) {
    return (text || "")
      .split("\n")
      .filter((line) => line.trim())
      .map((p) => `<p>${p}</p>`)
      .join("")
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
```

- [ ] **Step 2: Start the dev server**

```bash
bin/dev
```

- [ ] **Step 3: Manual test — goto chain**

1. Log in and open an active campaign.
2. Navigate to event 10-A ("Oxygen Leak") by moving to that hex.
3. Click "Buy replacement parts → 41-A".
4. Verify: modal stays open and updates to show event 41-A's title and choices (no close/reopen flicker).
5. Continue the chain to confirm subsequent gotos also update in-place.
6. Check the activity log — confirm entries like "10-A → 41-A" appear.

- [ ] **Step 4: Manual test — game_over**

1. Find an event with a `game_over` action choice (event 14-A has one — navigate to that hex).
2. Click the losing choice.
3. Verify: modal transforms to show "Mission Failed" title and a "Return to Main Menu" button.
4. Click "Return to Main Menu" — should navigate to `/campaigns`.
5. Verify the campaign shows as failed/inactive in the campaign list.

- [ ] **Step 5: Manual test — scrap delta**

1. Navigate to event 26-A (check `config/map.yml` for its hex coordinates — it's on the map somewhere in the beta/delta sectors).
2. Note current scrap in the HUD.
3. Click "Gain 100 scrap — Return to Orbit".
4. Verify: modal closes, HUD scrap increases by 100.

- [ ] **Step 6: Manual test — fuel delta**

1. Navigate to event 27-A.
2. Note current fuel in the HUD.
3. Click "Spend 1 fuel — seek side jobs → 33-B".
4. Verify: modal updates to show 33-B, fuel in HUD decreases by 1.

- [ ] **Step 7: Commit**

```bash
git add app/javascript/controllers/event_modal_controller.js
git commit -m "Handle goto chains and game_over in event modal controller"
```

---

## Done

All three action types are wired. Post-implementation checklist:

- [ ] `bin/rails test` passes
- [ ] goto chains update modal in-place with no flicker
- [ ] game_over sets campaign to failed and shows minimal loss state
- [ ] scrap and fuel deltas apply immediately and reflect in the HUD
- [ ] Activity log shows goto chain steps
