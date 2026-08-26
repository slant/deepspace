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

  test "for_hex with blank label rolls the sector chart" do
    hex = { "q" => 0, "r" => 0, "sector" => "tau", "label" => nil }

    result = EventCatalog.for_hex(hex, campaign: nil)

    assert_equal "Open Space", result[:title]
    assert_equal "Return to Orbit", result[:choices].first["label"]
    assert_equal "orbit", result[:choices].first["action"]
    assert_not result[:resolvable]
  end

  test "tau sector never has encounters regardless of roll" do
    hex = { "q" => 0, "r" => 0, "sector" => "tau", "label" => nil }

    (1..6).each do |roll|
      with_die_roll(roll) do
        result = EventCatalog.for_hex(hex, campaign: nil)
        assert_no_match(/Hostile contact/, result[:body])
        assert_equal({}, result[:choices].first["metadata"])
      end
    end
  end

  test "alpha roll 6 grants scrap on top of the combat outcome" do
    hex = { "q" => 0, "r" => 0, "sector" => "alpha", "label" => nil }

    with_die_roll(6) do
      result = EventCatalog.for_hex(hex, campaign: nil)
      assert_match(/Hostile contact/, result[:body])
      assert_equal({ "scrap_delta" => 2 }, result[:choices].first["metadata"])
    end
  end

  test "alpha roll 1 is empty with no scrap" do
    hex = { "q" => 0, "r" => 0, "sector" => "alpha", "label" => nil }

    with_die_roll(1) do
      result = EventCatalog.for_hex(hex, campaign: nil)
      assert_no_match(/Hostile contact/, result[:body])
      assert_equal({}, result[:choices].first["metadata"])
    end
  end

  test "beta roll 3 grants scrap without combat" do
    hex = { "q" => 0, "r" => 0, "sector" => "beta", "label" => nil }

    with_die_roll(3) do
      result = EventCatalog.for_hex(hex, campaign: nil)
      assert_no_match(/Hostile contact/, result[:body])
      assert_match(/Gain 3 scrap/, result[:body])
      assert_equal({ "scrap_delta" => 3 }, result[:choices].first["metadata"])
    end
  end

  test "zeta combat rolls (2-6) are treated as ignored/empty (Endless-gated, no card data)" do
    hex = { "q" => 0, "r" => 0, "sector" => "zeta", "label" => nil }

    (2..6).each do |roll|
      with_die_roll(roll) do
        result = EventCatalog.for_hex(hex, campaign: nil)
        assert_no_match(/Hostile contact/, result[:body], "roll #{roll} should be ignored")
        assert_equal({}, result[:choices].first["metadata"], "roll #{roll} should grant no scrap")
      end
    end
  end

  test "zeta roll 1 is empty" do
    hex = { "q" => 0, "r" => 0, "sector" => "zeta", "label" => nil }

    with_die_roll(1) do
      result = EventCatalog.for_hex(hex, campaign: nil)
      assert_no_match(/Hostile contact/, result[:body])
    end
  end

  test "delta roll 6 grants the largest scrap reward" do
    hex = { "q" => 0, "r" => 0, "sector" => "delta", "label" => nil }

    with_die_roll(6) do
      result = EventCatalog.for_hex(hex, campaign: nil)
      assert_equal({ "scrap_delta" => 5 }, result[:choices].first["metadata"])
    end
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
