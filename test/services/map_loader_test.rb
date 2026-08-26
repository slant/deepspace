require "test_helper"

class MapLoaderTest < ActiveSupport::TestCase
  test "parse_trigger handles a single value" do
    assert_equal [ 10 ], MapLoader.parse_trigger("10")
  end

  test "parse_trigger handles a two-digit single value" do
    assert_equal [ 12 ], MapLoader.parse_trigger("12")
  end

  test "parse_trigger handles a short range" do
    assert_equal [ 3, 4, 5, 6 ], MapLoader.parse_trigger("3-6")
  end

  test "parse_trigger handles a multi-digit range" do
    assert_equal [ 10, 11, 12 ], MapLoader.parse_trigger("10-12")
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

  test "hex_for_roll returns nil for roll 12 in tau" do
    # Tau's only trigger is "4-6"; roll 12 matches nothing
    assert_nil MapLoader.hex_for_roll("tau", 12)
  end

  test "trigger_hexes_for_sector returns only hexes with trigger field in that sector" do
    hexes = MapLoader.trigger_hexes_for_sector("alpha")

    assert hexes.all? { |h| h["sector"] == "alpha" }
    assert hexes.all? { |h| h["trigger"].present? }
    assert hexes.size > 0
  end
end
