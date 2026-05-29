# Sector Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Procedurally generate each sector's trigger hexes when a player first enters it, using d12 rolls to determine which hexes activate.

**Architecture:** New `activated_hexes` JSON column on campaigns stores activated trigger hex coordinates. `MapLoader` gains trigger-parsing helpers. `Campaign#generate_sector!` does the rolls and stores results. `discover_sector!` (already called at the right moments) delegates to `generate_sector!`. `HexMapComponent` renders activated trigger hexes as planet icons.

**Tech Stack:** Rails 8, PostgreSQL, ViewComponents, Minitest fixtures

---

## File Map

| File | Change |
|------|--------|
| `db/migrate/TIMESTAMP_add_activated_hexes_to_campaigns.rb` | New — adds `activated_hexes` column |
| `test/fixtures/campaigns.yml` | Add `activated_hexes: "[]"` to both fixtures |
| `app/services/map_loader.rb` | Add `trigger_hexes_for_sector`, `parse_trigger`, `hex_for_roll` |
| `test/services/map_loader_test.rb` | New — tests for trigger parsing and hex lookup |
| `app/models/campaign.rb` | Add `generate_sector!`, `hex_active?`; update `discover_sector!`, `ensure_defaults` |
| `test/models/campaign_test.rb` | Add tests for `generate_sector!`, `hex_active?`, `discover_sector!` integration |
| `app/components/hex_map_component.rb` | Add private `icon_for(hex)` method |
| `app/components/hex_map_component.html.erb` | Use `icon_for(hex)` instead of `hex["icon"]` |

---

## Task 1: Migration — add activated_hexes column

**Files:**
- Create: `db/migrate/TIMESTAMP_add_activated_hexes_to_campaigns.rb`
- Modify: `test/fixtures/campaigns.yml`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration AddActivatedHexesToCampaigns activated_hexes:json
```

- [ ] **Step 2: Edit the generated migration to add default and null constraint**

Open the newly created file in `db/migrate/` and replace its `change` body:

```ruby
def change
  add_column :campaigns, :activated_hexes, :json, default: [], null: false
end
```

- [ ] **Step 3: Run migration**

```bash
bin/rails db:migrate
```

Expected output: `== AddActivatedHexesToCampaigns: migrated`

- [ ] **Step 4: Add activated_hexes to both campaign fixtures**

In `test/fixtures/campaigns.yml`, add `activated_hexes: "[]"` to both `one:` and `two:` fixtures so they look like:

```yaml
one:
  user: one
  character: one
  name: MyString
  public_id: aaaa
  status: 1
  ship_q: 1
  ship_r: 1
  fuel: 1
  scrap: 1
  cargo_sequence: MyString
  discovered_sectors: "[]"
  researched_upgrades: "{}"
  resolved_events: "[]"
  planet_sprites: "{}"
  activated_hexes: "[]"
  draft_step: 1

two:
  user: two
  character: two
  name: MyString
  public_id: bbbb
  status: 1
  ship_q: 1
  ship_r: 1
  fuel: 1
  scrap: 1
  cargo_sequence: MyString
  discovered_sectors: "[]"
  researched_upgrades: "{}"
  resolved_events: "[]"
  planet_sprites: "{}"
  activated_hexes: "[]"
  draft_step: 1
```

- [ ] **Step 5: Verify existing tests still pass**

```bash
bin/rails test
```

Expected: `5 runs, 20 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 6: Commit**

```bash
git add db/migrate/ db/schema.rb test/fixtures/campaigns.yml
git commit -m "Add activated_hexes column to campaigns"
```

---

## Task 2: MapLoader — trigger parsing and hex lookup

**Files:**
- Modify: `app/services/map_loader.rb`
- Create: `test/services/map_loader_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/services/map_loader_test.rb`:

```ruby
require "test_helper"

class MapLoaderTest < ActiveSupport::TestCase
  test "parse_trigger handles a single value" do
    assert_equal [10], MapLoader.parse_trigger("10")
  end

  test "parse_trigger handles a two-digit single value" do
    assert_equal [12], MapLoader.parse_trigger("12")
  end

  test "parse_trigger handles a short range" do
    assert_equal [3, 4, 5, 6], MapLoader.parse_trigger("3-6")
  end

  test "parse_trigger handles a multi-digit range" do
    assert_equal [10, 11, 12], MapLoader.parse_trigger("10-12")
  end

  test "hex_for_roll returns the trigger hex matching the roll in a sector" do
    hex = MapLoader.hex_for_roll("alpha", 5)

    assert_not_nil hex
    assert_equal "alpha", hex["sector"]
    assert_equal "3-6", hex["trigger"]
  end

  test "hex_for_roll returns a different hex for a different roll" do
    hex = MapLoader.hex_for_roll("alpha", 11)

    assert_not_nil hex
    assert_equal "11", hex["trigger"]
  end

  test "hex_for_roll returns nil when no trigger covers the roll" do
    # Tau sector only has trigger "4-6"; roll 1 matches nothing
    assert_nil MapLoader.hex_for_roll("tau", 1)
  end

  test "hex_for_roll returns nil for a roll in a different sector's trigger" do
    # Roll 5 activates alpha's "3-6" hex, not anything in tau
    # tau's only trigger is "4-6" — roll 5 should still match that
    # Use roll 1 which matches nothing in tau
    assert_nil MapLoader.hex_for_roll("tau", 12)
  end

  test "trigger_hexes_for_sector returns only hexes with trigger field in that sector" do
    hexes = MapLoader.trigger_hexes_for_sector("alpha")

    assert hexes.all? { |h| h["sector"] == "alpha" }
    assert hexes.all? { |h| h["trigger"].present? }
    assert hexes.size > 0
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/services/map_loader_test.rb
```

Expected: errors with `NoMethodError: undefined method 'parse_trigger'`

- [ ] **Step 3: Add methods to MapLoader**

In `app/services/map_loader.rb`, add three methods inside the `class << self` block, after the existing `reload!` method:

```ruby
def trigger_hexes_for_sector(sector)
  hexes.select { |h| h["sector"] == sector && h["trigger"].present? }
end

def parse_trigger(str)
  parts = str.split("-").map(&:to_i)
  parts.size == 1 ? [parts.first] : (parts.first..parts.last).to_a
end

def hex_for_roll(sector, roll)
  trigger_hexes_for_sector(sector).find { |h| parse_trigger(h["trigger"]).include?(roll) }
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/services/map_loader_test.rb
```

Expected: `8 runs, 8 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: Run full test suite to confirm no regressions**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add app/services/map_loader.rb test/services/map_loader_test.rb
git commit -m "Add trigger parsing and hex lookup to MapLoader"
```

---

## Task 3: Campaign#generate_sector! and Campaign#hex_active?

**Files:**
- Modify: `app/models/campaign.rb`
- Modify: `test/models/campaign_test.rb`

- [ ] **Step 1: Write failing tests**

Append to `test/models/campaign_test.rb` (after the existing tests):

```ruby
test "generate_sector! populates activated_hexes with coordinates from that sector" do
  campaign = campaigns(:one)
  campaign.update_column(:activated_hexes, [])

  campaign.generate_sector!("alpha")

  alpha_trigger_coords = MapLoader.trigger_hexes_for_sector("alpha")
    .map { |h| "#{h['q']},#{h['r']}" }
  campaign.reload.activated_hexes.each do |coord|
    assert_includes alpha_trigger_coords, coord,
      "#{coord} is not a trigger hex in alpha"
  end
end

test "generate_sector! produces no duplicate coordinates" do
  campaign = campaigns(:one)
  campaign.update_column(:activated_hexes, [])

  campaign.generate_sector!("alpha")

  activated = campaign.reload.activated_hexes
  assert_equal activated.uniq, activated
end

test "generate_sector! makes at most sector_rolls activations" do
  campaign = campaigns(:one)
  campaign.update_column(:activated_hexes, [])

  campaign.generate_sector!("alpha")

  # Alpha has 6 rolls; can activate at most 6 trigger hexes
  assert campaign.reload.activated_hexes.size <= 6
end

test "hex_active? returns true for an activated hex" do
  campaign = campaigns(:one)
  campaign.update_column(:activated_hexes, ["2,6"])

  assert campaign.hex_active?(2, 6)
end

test "hex_active? returns false for a hex not in activated_hexes" do
  campaign = campaigns(:one)
  campaign.update_column(:activated_hexes, [])

  assert_not campaign.hex_active?(2, 6)
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/campaign_test.rb
```

Expected: `NoMethodError: undefined method 'generate_sector!'` and `undefined method 'hex_active?'`

- [ ] **Step 3: Add methods to Campaign model**

In `app/models/campaign.rb`:

1. Add `activated_hexes` to `ensure_defaults` (in the private section):

```ruby
def ensure_defaults
  self.discovered_sectors ||= []
  self.researched_upgrades ||= {}
  self.resolved_events ||= []
  self.planet_sprites ||= {}
  self.activated_hexes ||= []
  self.fuel ||= 10
  self.scrap ||= 0
  self.draft_step ||= 1
  self.name ||= "New Campaign"
end
```

2. Add two public methods after `planet_sprite_for`:

```ruby
def generate_sector!(sector)
  roll_count = MapLoader.sector_rolls[sector].to_i
  activated = activated_hexes.dup

  roll_count.times do
    roll = rand(1..12)
    hex = MapLoader.hex_for_roll(sector, roll)
    next unless hex
    key = "#{hex['q']},#{hex['r']}"
    next if activated.include?(key)
    activated << key
  end

  update!(activated_hexes: activated)
end

def hex_active?(q, r)
  activated_hexes.include?("#{q},#{r}")
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/models/campaign_test.rb
```

Expected: `10 runs, 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: Run full suite**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add app/models/campaign.rb test/models/campaign_test.rb
git commit -m "Add Campaign#generate_sector! and Campaign#hex_active?"
```

---

## Task 4: Wire discover_sector! to generate_sector!

**Files:**
- Modify: `app/models/campaign.rb`
- Modify: `test/models/campaign_test.rb`

- [ ] **Step 1: Write failing tests**

Append to `test/models/campaign_test.rb`:

```ruby
test "discover_sector! populates activated_hexes for the sector" do
  campaign = campaigns(:one)
  campaign.update_column(:activated_hexes, [])
  campaign.update_column(:discovered_sectors, [])

  campaign.discover_sector!("alpha")

  alpha_trigger_coords = MapLoader.trigger_hexes_for_sector("alpha")
    .map { |h| "#{h['q']},#{h['r']}" }
  campaign.reload.activated_hexes.each do |coord|
    assert_includes alpha_trigger_coords, coord
  end
end

test "discover_sector! called twice for the same sector does not re-roll" do
  campaign = campaigns(:one)
  campaign.update_column(:activated_hexes, [])
  campaign.update_column(:discovered_sectors, [])

  campaign.discover_sector!("alpha")
  first_result = campaign.reload.activated_hexes.dup

  campaign.discover_sector!("alpha")
  second_result = campaign.reload.activated_hexes

  assert_equal first_result, second_result
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/campaign_test.rb
```

Expected: both new tests fail — `discover_sector!` doesn't call `generate_sector!` yet, so `activated_hexes` stays empty.

- [ ] **Step 3: Update discover_sector! in campaign.rb**

Replace the existing `discover_sector!` method:

```ruby
def discover_sector!(sector)
  sectors = discovered_sectors.dup
  return if sectors.include?(sector)

  generate_sector!(sector)
  update!(discovered_sectors: sectors + [sector])
  log!("Entered #{sector.titleize} sector", entry_type: "sector")
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/models/campaign_test.rb
```

Expected: `12 runs, 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: Run full suite**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add app/models/campaign.rb test/models/campaign_test.rb
git commit -m "Wire discover_sector! to generate_sector! for procedural sector population"
```

---

## Task 5: HexMapComponent — render activated trigger hexes as planets

**Files:**
- Modify: `app/components/hex_map_component.rb`
- Modify: `app/components/hex_map_component.html.erb`

- [ ] **Step 1: Add icon_for method to HexMapComponent**

In `app/components/hex_map_component.rb`, add a private method after `planet_index_for`:

```ruby
def icon_for(hex)
  return hex["icon"] if hex["icon"].present?
  return "circle" if hex["trigger"].present? && campaign.hex_active?(hex["q"].to_i, hex["r"].to_i)
end
```

- [ ] **Step 2: Update the template to use icon_for**

In `app/components/hex_map_component.html.erb`, replace:

```erb
<% if hex["icon"].present? %>
  <%= render HexIconComponent.new(icon: hex["icon"], cx: cx, cy: cy, size: size, planet_index: planet_index_for(hex)) %>
<% end %>
```

with:

```erb
<% if (hex_icon = icon_for(hex)) %>
  <%= render HexIconComponent.new(icon: hex_icon, cx: cx, cy: cy, size: size, planet_index: planet_index_for(hex)) %>
<% end %>
```

- [ ] **Step 3: Run full test suite to confirm no regressions**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 4: Start the server and verify visually**

```bash
bin/dev
```

1. Open the app and create a new campaign (or use an existing active one).
2. Confirm the alpha sector shows some planet icons on trigger hexes (not all, just those whose ranges were hit by the 6 rolls).
3. Move the ship into a new sector and confirm that sector's trigger hexes appear on the map after the move.
4. Reload the page and confirm planets persist.
5. Check that blank trigger hexes (not activated) show nothing.

- [ ] **Step 5: Commit**

```bash
git add app/components/hex_map_component.rb app/components/hex_map_component.html.erb
git commit -m "Render activated trigger hexes as planet icons in HexMapComponent"
```
