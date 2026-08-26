require "test_helper"

class UpgradesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @campaign = campaigns(:one)
    sign_in @user
  end

  test "PATCH toggle_box marks a box and returns updated progress" do
    patch campaign_upgrade_toggle_box_path(campaign_id: @campaign.public_id, track: "promotion", box: 0), as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal [ true, false, false ], json["campaign"]["researched_upgrades"]["promotion"]["marked_boxes"]
  end

  test "PATCH toggle_box returns 404 for an unknown track" do
    patch campaign_upgrade_toggle_box_path(campaign_id: @campaign.public_id, track: "warp_core", box: 0), as: :json

    assert_response :not_found
  end

  test "PATCH complete deducts scrap and marks the track researched" do
    @campaign.update_columns(scrap: 30)
    6.times { |i| @campaign.toggle_upgrade_box!("cloaking_device", i) }

    patch campaign_upgrade_complete_path(campaign_id: @campaign.public_id, track: "cloaking_device"), as: :json

    assert_response :ok
    json = response.parsed_body
    assert json["campaign"]["researched_upgrades"]["cloaking_device"]["researched"]
    assert_equal 5, json["campaign"]["scrap"]
  end

  test "PATCH complete fails with 422 when boxes aren't all marked" do
    patch campaign_upgrade_complete_path(campaign_id: @campaign.public_id, track: "cloaking_device"), as: :json

    assert_response :unprocessable_entity
  end

  test "PATCH toggle_box for another user's campaign is not found" do
    other_campaign = campaigns(:two)

    patch campaign_upgrade_toggle_box_path(campaign_id: other_campaign.public_id, track: "promotion", box: 0), as: :json

    assert_response :not_found
  end
end
