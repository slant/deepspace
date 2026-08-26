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

  # --- fuel depletion → Adrift ---

  test "GET adjacent hex with zero fuel returns Adrift event" do
    @campaign.update_columns(fuel: 0)

    get campaign_hex_event_path(campaign_id: @campaign.public_id, q: 1, r: 0),
      as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal "Adrift", json["title"]
    assert_equal 1, json["choices"].size
    assert_equal "game_over", json["choices"].first["action"]
  end

  test "GET adjacent hex with zero fuel does not move the ship" do
    @campaign.update_columns(fuel: 0)

    get campaign_hex_event_path(campaign_id: @campaign.public_id, q: 1, r: 0),
      as: :json

    @campaign.reload
    assert_equal 0, @campaign.fuel
    assert_equal 1, @campaign.ship_q
    assert_equal 1, @campaign.ship_r
  end

  test "GET non-adjacent hex with zero fuel still returns forbidden" do
    @campaign.update_columns(fuel: 0)

    # (3,3) is not adjacent to ship at (1,1)
    get campaign_hex_event_path(campaign_id: @campaign.public_id, q: 3, r: 3),
      as: :json

    assert_response :forbidden
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
