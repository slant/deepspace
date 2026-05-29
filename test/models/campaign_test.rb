require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  test "assign_planet_sprites! populates planet_sprites for all planet hexes" do
    campaign = campaigns(:one)
    campaign.update_column(:planet_sprites, {})

    campaign.assign_planet_sprites!

    planet_hexes = MapLoader.hexes.select { |h| h["icon"].in?(%w[circle beacon_store]) }
    assert_equal planet_hexes.size, campaign.reload.planet_sprites.size
  end

  test "assign_planet_sprites! assigns valid sprite indexes" do
    campaign = campaigns(:one)
    campaign.assign_planet_sprites!

    campaign.planet_sprites.each_value do |idx|
      assert_includes 0...Campaign::PLANET_COUNT, idx
    end
  end

  test "assign_planet_sprites! produces different results across calls" do
    campaign = campaigns(:one)

    campaign.assign_planet_sprites!
    first = campaign.planet_sprites.dup

    campaign.assign_planet_sprites!
    second = campaign.planet_sprites

    assert_not_equal first, second, "Expected randomized sprites to differ between calls"
  end

  test "planet_sprite_for returns the stored sprite index" do
    campaign = campaigns(:one)
    campaign.update_column(:planet_sprites, { "2,7" => 13 })

    assert_equal 13, campaign.planet_sprite_for(2, 7)
  end

  test "planet_sprite_for falls back deterministically for hexes not in the hash" do
    campaign = campaigns(:one)
    campaign.update_column(:planet_sprites, {})

    result = campaign.planet_sprite_for(3, 5)

    assert_includes 0...Campaign::PLANET_COUNT, result
    assert_equal result, campaign.planet_sprite_for(3, 5)
  end

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
end
