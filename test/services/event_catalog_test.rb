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
