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

  # --- Open Space encounter chart ---
  # Rolling is an explicit player action (the "Roll Dice" button) — see
  # CLAUDE.md "Crew Dice" for why the app never auto-rolls story checks.
  # for_hex just exposes the dice_roll descriptor; roll_dice_for performs it.

  test "for_hex with blank label exposes an open_space_chart dice_roll descriptor" do
    hex = { "q" => 0, "r" => 0, "sector" => "tau", "label" => nil }

    result = EventCatalog.for_hex(hex, campaign: nil)

    assert_equal "Open Space", result[:title]
    assert_equal({ "kind" => "open_space_chart", "sector" => "tau" }, result[:dice_roll])
    assert_equal "Return to Orbit", result[:choices].first["label"]
    assert_equal({}, result[:choices].first["metadata"])
    assert_not result[:resolvable]
  end

  test "tau sector never has encounters regardless of roll" do
    (1..6).each do |roll|
      with_die_roll(roll) do
        result = EventCatalog.roll_dice_for("open_space_chart", sector: "tau")
        assert_no_match(/Hostile contact/, result[:text])
        assert_equal 0, result[:scrap_delta]
      end
    end
  end

  test "alpha roll 6 is a combat encounter resolved physically, with Victory/Defeat choices reported back" do
    with_die_roll(6) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "alpha")
      assert_match(/Hostile contact/, result[:text])
      assert_equal 0, result[:scrap_delta]
      assert_equal "Victory — Return to Orbit", result[:choices][0]["label"]
      assert_equal 2, result[:choices][0]["metadata"]["scrap_delta"]
      assert_equal "Defeat — Return to Orbit", result[:choices][1]["label"]
      assert_nil result[:choices][1]["metadata"]["scrap_delta"]
    end
  end

  test "alpha roll 1 is empty with no scrap" do
    with_die_roll(1) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "alpha")
      assert_no_match(/Hostile contact/, result[:text])
      assert_equal 0, result[:scrap_delta]
    end
  end

  test "beta roll 3 grants scrap without combat" do
    with_die_roll(3) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "beta")
      assert_no_match(/Hostile contact/, result[:text])
      assert_match(/Gain 3 scrap/, result[:text])
      assert_equal 3, result[:scrap_delta]
    end
  end

  test "zeta combat rolls (2-6) clearly label the Endless Expansion deck requirement (Endless-gated, no card data)" do
    (2..6).each do |roll|
      with_die_roll(roll) do
        result = EventCatalog.roll_dice_for("open_space_chart", sector: "zeta")
        assert_match(/ENDLESS EXPANSION/, result[:text], "roll #{roll} should clearly flag the Endless deck")
        assert_match(/if you don.t own the expansion, treat this as empty space/i, result[:text])
        assert_equal 0, result[:scrap_delta], "roll #{roll} should grant no scrap (no real Endless card data)"
      end
    end
  end

  test "zeta roll 1 is empty" do
    with_die_roll(1) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "zeta")
      assert_no_match(/Hostile contact/, result[:text])
    end
  end

  test "delta roll 6 grants the largest scrap reward on Victory" do
    with_die_roll(6) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "delta")
      assert_equal 5, result[:choices][0]["metadata"]["scrap_delta"]
    end
  end

  test "LR Scanners reduces the open space roll by 2 (min 1) when researched" do
    scanner_campaign = Campaign.new(researched_upgrades: { "lr_scanners" => { "researched" => true } })

    with_die_roll(6) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "alpha", campaign: scanner_campaign)
      # raw roll 6 -> reduced to 4, alpha's row 4 is empty (row 6 would have been combat)
      assert_no_match(/Hostile contact/, result[:text])
      assert_match(/Long Range Scanners reduce the threat \(rolled 6 → 4\)/, result[:text])
    end
  end

  test "LR Scanners has no effect without the upgrade researched" do
    with_die_roll(6) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "alpha", campaign: campaigns(:one))
      assert_no_match(/Long Range Scanners/, result[:text])
    end
  end

  test "LR Scanners floors the reduced roll at 1" do
    scanner_campaign = Campaign.new(researched_upgrades: { "lr_scanners" => { "researched" => true } })

    with_die_roll(2) do
      result = EventCatalog.roll_dice_for("open_space_chart", sector: "alpha", campaign: scanner_campaign)
      assert_match(/rolled 2 → 1/, result[:text])
    end
  end

  # --- threat_die_table (single-roll-then-choose events, e.g. 22-A) ---
  # Same principle: for_event exposes the descriptor only; roll_dice_for
  # performs the actual roll when the player clicks "Roll Dice".

  test "for_event with a threat_die_table exposes the dice_roll descriptor, unrolled" do
    result = EventCatalog.for_event("22-A")

    assert_equal({ "kind" => "threat_die_table", "label" => "22-A" }, result[:dice_roll])
    assert_no_match(/Threat die:/, result[:body])
    result[:choices].each { |choice| assert_not (choice["metadata"] || {}).key?("scrap_delta") }
  end

  test "roll_dice_for threat_die_table rolls once and returns the outcome text" do
    with_die_roll(2) do
      result = EventCatalog.roll_dice_for("threat_die_table", label: "22-A")
      assert_match(/Threat die: 2 — An asteroid hits your cargo bay/, result[:text])
      assert_equal(-5, result[:scrap_delta])
    end
  end

  test "roll_dice_for threat_die_table with no delta (roll 1) returns zero deltas" do
    with_die_roll(1) do
      result = EventCatalog.roll_dice_for("threat_die_table", label: "22-A")
      assert_equal 0, result[:scrap_delta]
      assert_equal 0, result[:fuel_delta]
    end
  end

  test "roll_dice_for threat_die_table (roll 5) returns both scrap and fuel deltas" do
    with_die_roll(5) do
      result = EventCatalog.roll_dice_for("threat_die_table", label: "22-A")
      assert_equal(-5, result[:scrap_delta])
      assert_equal(-1, result[:fuel_delta])
    end
  end

  test "events without a threat_die_table have no dice_roll descriptor" do
    result = EventCatalog.for_event("10-A")
    assert_nil result[:dice_roll]
  end

  test "roll_dice_for returns nil for an unknown kind" do
    assert_nil EventCatalog.roll_dice_for("something_else")
  end

  private

  # EventCatalog.roll_die wraps Kernel#rand(1..6) for exactly this purpose —
  # minitest 6 no longer bundles minitest/mock, so stub it via a temporary
  # singleton method instead of Object#stub, restoring the original after.
  def with_die_roll(value)
    original = EventCatalog.method(:roll_die)
    EventCatalog.define_singleton_method(:roll_die) { value }
    yield
  ensure
    EventCatalog.define_singleton_method(:roll_die, original)
    EventCatalog.singleton_class.send(:private, :roll_die)
  end
end
