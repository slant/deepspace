require "test_helper"

class JournalEntriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @campaign = campaigns(:one)
    sign_in @user
  end

  test "POST create adds a note-type journal entry" do
    assert_difference "@campaign.journal_entries.count", 1 do
      post campaign_journal_entries_path(@campaign), params: { body: "Left a beacon for later." }, as: :json
    end

    assert_response :ok
    entry = @campaign.journal_entries.order(created_at: :desc).first
    assert_equal "Left a beacon for later.", entry.body
    assert_equal "note", entry.entry_type
  end

  test "POST create with blank body is a no-op" do
    assert_no_difference "@campaign.journal_entries.count" do
      post campaign_journal_entries_path(@campaign), params: { body: "   " }, as: :json
    end

    assert_response :ok
  end

  test "POST create for another user's campaign is not found" do
    other_campaign = campaigns(:two)

    post campaign_journal_entries_path(other_campaign), params: { body: "hi" }, as: :json

    assert_response :not_found
  end
end
