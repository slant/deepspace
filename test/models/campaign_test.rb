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
    campaign.update_column(:activated_hexes, [ "2,6" ])

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

    assert_no_difference [ "campaign.reload.scrap", "campaign.reload.fuel" ] do
      campaign.apply_resource_delta!(scrap_delta: 0, fuel_delta: 0)
    end
  end

  test "campaign status can be set to failed" do
    campaign = campaigns(:one)
    campaign.update!(status: :failed)
    assert campaign.reload.failed?
  end

  # --- Movement range (Engine Repair) / Jump Drive ---

  test "move_range is 1 without Engine Repair and 2 once researched" do
    campaign = campaigns(:one)
    assert_equal 1, campaign.move_range

    campaign.update!(researched_upgrades: { "engine_repair" => { "researched" => true } })
    assert_equal 2, campaign.move_range
  end

  test "within_move_range? allows distance 2 only with Engine Repair researched" do
    campaign = campaigns(:one)
    campaign.update!(ship_q: 1, ship_r: 1)

    assert campaign.within_move_range?(2, 1) # distance 1
    assert_not campaign.within_move_range?(3, 1) # distance 2

    campaign.update!(researched_upgrades: { "engine_repair" => { "researched" => true } })
    assert campaign.within_move_range?(3, 1)
    assert_not campaign.within_move_range?(4, 1) # distance 3
  end

  test "move_to! tracks the previous ship position" do
    campaign = campaigns(:one)
    campaign.update!(ship_q: 1, ship_r: 1, fuel: 5)

    campaign.move_to!(2, 1)

    assert_equal [ 1, 1 ], [ campaign.previous_ship_q, campaign.previous_ship_r ]
    assert_equal [ 2, 1 ], [ campaign.ship_q, campaign.ship_r ]
  end

  test "can_jump_drive? requires Engine Repair, fuel, and a previous position" do
    campaign = campaigns(:one)
    campaign.update!(ship_q: 1, ship_r: 1, fuel: 5, previous_ship_q: nil, previous_ship_r: nil)
    assert_not campaign.can_jump_drive?, "no previous position yet"

    campaign.update!(previous_ship_q: 0, previous_ship_r: 1)
    assert_not campaign.can_jump_drive?, "Engine Repair not researched"

    campaign.update!(researched_upgrades: { "engine_repair" => { "researched" => true } })
    assert campaign.can_jump_drive?

    campaign.update!(fuel: 0)
    assert_not campaign.can_jump_drive?, "no fuel"
  end

  test "jump_drive! returns to the previous position, costs 1 fuel, and swaps positions" do
    campaign = campaigns(:one)
    campaign.update!(
      ship_q: 2, ship_r: 1, previous_ship_q: 1, previous_ship_r: 1, fuel: 5,
      researched_upgrades: { "engine_repair" => { "researched" => true } }
    )

    campaign.jump_drive!

    assert_equal [ 1, 1 ], [ campaign.ship_q, campaign.ship_r ]
    assert_equal [ 2, 1 ], [ campaign.previous_ship_q, campaign.previous_ship_r ]
    assert_equal 4, campaign.fuel
  end

  test "jump_drive! raises when unavailable" do
    campaign = campaigns(:one)
    campaign.update!(previous_ship_q: nil, previous_ship_r: nil)

    assert_raises(RuntimeError) { campaign.jump_drive! }
  end

  # --- Items ---

  test "gain_item! adds a new item and has_item? becomes true" do
    campaign = campaigns(:one)

    campaign.gain_item!("AI-System")

    assert campaign.reload.has_item?("AI-System")
    assert_equal [ { "name" => "AI-System", "lost" => false } ], campaign.items
  end

  test "gain_item! is idempotent for an already-held item" do
    campaign = campaigns(:one)
    campaign.gain_item!("Vortex")

    assert_no_difference "campaign.reload.items.size" do
      campaign.gain_item!("Vortex")
    end
  end

  test "lose_item! marks an item lost and has_item? becomes false" do
    campaign = campaigns(:one)
    campaign.gain_item!("Q-BOMB")

    campaign.lose_item!("Q-BOMB")

    campaign.reload
    assert_not campaign.has_item?("Q-BOMB")
    assert_equal true, campaign.items.find { |i| i["name"] == "Q-BOMB" }["lost"]
  end

  test "lose_item! on an item never held is a no-op" do
    campaign = campaigns(:one)

    assert_no_difference "campaign.reload.items.size" do
      campaign.lose_item!("Nonexistent")
    end
  end

  test "gain_item! after lose_item! un-loses the same entry instead of duplicating" do
    campaign = campaigns(:one)
    campaign.gain_item!("Lux Food")
    campaign.lose_item!("Lux Food")

    campaign.gain_item!("Lux Food")

    campaign.reload
    assert campaign.has_item?("Lux Food")
    assert_equal 1, campaign.items.count { |i| i["name"] == "Lux Food" }
  end

  # --- Cargo sequence marks ---

  test "mark_sequence! sets the token's state" do
    campaign = campaigns(:one)

    campaign.mark_sequence!("711", "underline")

    campaign.reload
    assert campaign.sequence_marked?("711")
    assert_equal "underline", campaign.sequence_state("711")
  end

  test "sequence_marked? is false for an unmarked token" do
    campaign = campaigns(:one)
    assert_not campaign.sequence_marked?("000")
  end

  test "mark_sequence! can circle a token that was previously underlined" do
    campaign = campaigns(:one)
    campaign.mark_sequence!("000", "underline")

    campaign.mark_sequence!("000", "circle")

    assert_equal "circle", campaign.reload.sequence_state("000")
  end

  # --- Officer mutations ---

  test "add_random_officer_attribute! grants the attribute to a living officer" do
    campaign = campaigns(:one)

    campaign.add_random_officer_attribute!("Restless")

    officer = campaign.character.officers.reload.first
    assert_includes officer.bonus_attributes, "Restless"
  end

  test "add_random_officer_attribute! skips dead officers" do
    campaign = campaigns(:one)
    officer = campaign.character.officers.first
    officer.kill!

    campaign.add_random_officer_attribute!("Restless")

    assert_not officer.reload.bonus_attributes.include?("Restless")
  end

  test "add_all_officers_attribute! grants the attribute to every officer" do
    campaign = campaigns(:one)

    campaign.add_all_officers_attribute!("Lucky")

    campaign.character.officers.reload.each do |officer|
      assert_includes officer.bonus_attributes, "Lucky"
    end
  end

  test "kill_random_officer! marks a living officer dead" do
    campaign = campaigns(:one)

    campaign.kill_random_officer!

    assert campaign.character.officers.reload.first.dead?
  end

  test "kill_random_officer! is a no-op when all officers are already dead" do
    campaign = campaigns(:one)
    campaign.character.officers.each(&:kill!)

    assert_nothing_raised { campaign.kill_random_officer! }
  end

  # --- Journey summary ---

  test "journey_summary reflects items, marks, and officer losses" do
    campaign = campaigns(:one)
    campaign.gain_item!("Vortex")
    campaign.gain_item!("Q-BOMB")
    campaign.lose_item!("Q-BOMB")
    campaign.mark_sequence!("711", "underline")
    campaign.character.officers.first.kill!

    summary = campaign.reload.journey_summary

    assert_equal 1, summary[:items_collected]
    assert_equal 1, summary[:items_lost]
    assert_equal 1, summary[:sequences_marked]
    assert_equal 1, summary[:officers_lost]
  end

  # --- Crew dice fatigue check ---

  test "roll_fatigue_check! adds a mark to every officer when dice always hit Threat Detected" do
    campaign = campaigns(:one)

    with_crew_dice([ "threat_detected", "commander" ]) { campaign.roll_fatigue_check! }

    assert_equal 1, campaign.character.officers.reload.first.fatigue_marks
  end

  test "roll_fatigue_check! adds no marks when dice never hit Threat Detected" do
    campaign = campaigns(:one)

    with_crew_dice([ "commander", "science" ]) { campaign.roll_fatigue_check! }

    assert_equal 0, campaign.character.officers.reload.first.fatigue_marks
  end

  test "roll_fatigue_check! skips dead officers" do
    campaign = campaigns(:one)
    campaign.character.officers.first.kill!

    with_crew_dice([ "threat_detected", "commander" ]) { campaign.roll_fatigue_check! }

    assert_equal 0, campaign.character.officers.reload.first.fatigue_marks
  end

  test "apply_fatigue_threshold! crosses out officers at or past their threshold" do
    campaign = campaigns(:one)
    officer = campaign.character.officers.first
    officer.update!(attribute_a: "MyString", attribute_b: "MyString")
    4.times { officer.add_fatigue_mark! }

    campaign.apply_fatigue_threshold!

    assert officer.reload.dead?
  end

  test "apply_fatigue_threshold! leaves officers under their threshold alone" do
    campaign = campaigns(:one)
    officer = campaign.character.officers.first
    officer.update!(attribute_a: "MyString", attribute_b: "MyString")
    3.times { officer.add_fatigue_mark! }

    campaign.apply_fatigue_threshold!

    assert_not officer.reload.dead?
  end

  # --- Research & Development ---

  test "upgrade_marked_boxes defaults to all-false for an untouched track" do
    campaign = campaigns(:one)
    assert_equal [ false, false, false ], campaign.upgrade_marked_boxes("promotion")
  end

  test "toggle_upgrade_box! flips a single box and persists it" do
    campaign = campaigns(:one)

    campaign.toggle_upgrade_box!("promotion", 1)

    assert_equal [ false, true, false ], campaign.reload.upgrade_marked_boxes("promotion")
  end

  test "toggle_upgrade_box! toggling twice unmarks the box again" do
    campaign = campaigns(:one)

    campaign.toggle_upgrade_box!("kinetic_recycler", 0)
    campaign.toggle_upgrade_box!("kinetic_recycler", 0)

    assert_equal [ false, false, false ], campaign.reload.upgrade_marked_boxes("kinetic_recycler")
  end

  test "toggle_upgrade_box! auto-completes a zero-cost track once every box is marked" do
    campaign = campaigns(:one)

    3.times { |i| campaign.toggle_upgrade_box!("kinetic_recycler", i) }

    assert campaign.reload.upgrade_researched?("kinetic_recycler")
  end

  test "toggle_upgrade_box! does not auto-complete a track with a scrap cost" do
    campaign = campaigns(:one)
    campaign.update_columns(scrap: 100)

    9.times { |i| campaign.toggle_upgrade_box!("engine_repair", i) }

    assert_not campaign.reload.upgrade_researched?("engine_repair")
    assert_equal 100, campaign.scrap
  end

  test "complete_upgrade! deducts scrap and marks the track researched once all boxes are marked" do
    campaign = campaigns(:one)
    campaign.update_columns(scrap: 30)
    6.times { |i| campaign.toggle_upgrade_box!("cloaking_device", i) }

    assert campaign.complete_upgrade!("cloaking_device")

    campaign.reload
    assert campaign.upgrade_researched?("cloaking_device")
    assert_equal 5, campaign.scrap
  end

  test "complete_upgrade! fails without enough scrap" do
    campaign = campaigns(:one)
    campaign.update_columns(scrap: 5)
    6.times { |i| campaign.toggle_upgrade_box!("cloaking_device", i) }

    assert_not campaign.complete_upgrade!("cloaking_device")
    assert_not campaign.reload.upgrade_researched?("cloaking_device")
  end

  test "complete_upgrade! fails if not all boxes are marked" do
    campaign = campaigns(:one)
    campaign.update_columns(scrap: 100)
    campaign.toggle_upgrade_box!("cloaking_device", 0)

    assert_not campaign.complete_upgrade!("cloaking_device")
  end

  test "toggle_upgrade_box! is a no-op once a track is researched" do
    campaign = campaigns(:one)
    3.times { |i| campaign.toggle_upgrade_box!("kinetic_recycler", i) }
    assert campaign.reload.upgrade_researched?("kinetic_recycler")

    campaign.toggle_upgrade_box!("kinetic_recycler", 0)

    assert_equal [ true, true, true ], campaign.reload.upgrade_marked_boxes("kinetic_recycler")
  end

  private

  def with_crew_dice(faces)
    original = CrewDice.method(:roll)
    CrewDice.define_singleton_method(:roll) { |_count| faces }
    yield
  ensure
    CrewDice.define_singleton_method(:roll, original)
  end
end
