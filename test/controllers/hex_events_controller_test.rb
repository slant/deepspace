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

  # --- Open Space encounters (end-to-end) ---
  # Rolling is an explicit "Roll Dice" button (action_type: roll_dice) — GET
  # just exposes the dice_roll descriptor, unrolled. See CLAUDE.md "Crew Dice".

  test "GET an Open Space hex exposes a dice_roll descriptor and costs 1 fuel to move there" do
    @campaign.update_columns(scrap: 0, fuel: 5)

    get campaign_hex_event_path(campaign_id: @campaign.public_id, q: 2, r: 1), as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal "Open Space", json["title"]
    assert_equal "open_space_chart", json["dice_roll"]["kind"]
    assert_equal 4, @campaign.reload.fuel
  end

  test "PATCH roll_dice on an Open Space combat hex returns Victory/Defeat choices; Victory applies the scrap reward" do
    @campaign.update_columns(scrap: 0, fuel: 5, ship_q: 2, ship_r: 1)

    with_die_roll(6) do
      patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 2, r: 1),
        params: { action_type: "roll_dice", dice_roll_kind: "open_space_chart", dice_roll_sector: "alpha" },
        as: :json
    end

    assert_response :ok
    json = response.parsed_body
    assert_match(/Hostile contact/, json["dice_result"])
    assert_equal 0, @campaign.reload.scrap
    victory = json["choices"].find { |c| c["label"].start_with?("Victory") }
    assert_equal 2, victory["metadata"]["scrap_delta"]

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 2, r: 1),
      params: { action_type: "orbit", scrap_delta: victory["metadata"]["scrap_delta"] },
      as: :json

    assert_response :ok
    assert_equal 2, @campaign.reload.scrap
  end

  test "PATCH roll_dice for Zeta combat rolls never auto-grants scrap and clearly labels the Endless deck requirement" do
    @campaign.update_columns(scrap: 0, fuel: 5)

    (2..6).each do |roll|
      with_die_roll(roll) do
        patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
          params: { action_type: "roll_dice", dice_roll_kind: "open_space_chart", dice_roll_sector: "zeta" },
          as: :json
      end

      assert_response :ok
      json = response.parsed_body
      assert_match(/ENDLESS EXPANSION/, json["dice_result"], "roll #{roll} should flag the Endless deck")
      assert_equal 0, @campaign.reload.scrap
    end
  end

  # --- Items & cargo sequence marks (end-to-end) ---

  test "PATCH orbit with gain_item adds the item to the campaign" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", gain_item: "AI-System" },
      as: :json

    assert_response :ok
    assert @campaign.reload.has_item?("AI-System")
    assert_equal [ { "name" => "AI-System", "lost" => false } ], response.parsed_body["campaign"]["items"]
  end

  test "PATCH orbit with lose_item marks a held item lost" do
    @campaign.gain_item!("Vortex")

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", lose_item: "Vortex" },
      as: :json

    assert_response :ok
    assert_not @campaign.reload.has_item?("Vortex")
  end

  test "PATCH orbit with lose_item_unless skips the loss when the officer condition is met" do
    @campaign.gain_item!("Vortex")
    officers(:one).update!(specialty: "Assassin")

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: {
        action_type: "orbit",
        lose_item: "Vortex",
        lose_item_unless: { specialty_or_attribute: [ "DARK MATTER SPECIALIST", "ASSASSIN", "LOYAL" ] }
      },
      as: :json

    assert_response :ok
    assert @campaign.reload.has_item?("Vortex"), "item should survive — officer qualifies for the exemption"
  end

  test "PATCH orbit with lose_item_unless applies the loss when the officer condition is not met" do
    @campaign.gain_item!("Vortex")
    officers(:one).update!(specialty: "Pilot", attribute_a: "MyString", attribute_b: "MyString")

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: {
        action_type: "orbit",
        lose_item: "Vortex",
        lose_item_unless: { specialty_or_attribute: [ "DARK MATTER SPECIALIST", "ASSASSIN", "LOYAL" ] }
      },
      as: :json

    assert_response :ok
    assert_not @campaign.reload.has_item?("Vortex")
  end

  test "PATCH orbit with mark_sequence marks the cargo token" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", mark_sequence: "711", mark_type: "underline" },
      as: :json

    assert_response :ok
    assert_equal "underline", @campaign.reload.sequence_state("711")
    assert_equal({ "711" => "underline" }, response.parsed_body["campaign"]["cargo_marks"])
  end

  test "PATCH orbit with gain_random_officer_attribute grants it to a living officer" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", gain_random_officer_attribute: "Restless" },
      as: :json

    assert_response :ok
    assert_includes @campaign.character.officers.reload.first.bonus_attributes, "Restless"
  end

  test "PATCH orbit with gain_random_officer_attribute_count grants it to that many officers" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", gain_random_officer_attribute: "Mistrusting", gain_random_officer_attribute_count: 1 },
      as: :json

    assert_response :ok
    assert_includes @campaign.character.officers.reload.first.bonus_attributes, "Mistrusting"
  end

  test "PATCH orbit with gain_all_officers_attribute grants it to every officer" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", gain_all_officers_attribute: "Lucky" },
      as: :json

    assert_response :ok
    @campaign.character.officers.reload.each do |officer|
      assert_includes officer.bonus_attributes, "Lucky"
    end
  end

  test "PATCH orbit with kill_random_officer marks an officer dead" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", kill_random_officer: true },
      as: :json

    assert_response :ok
    assert @campaign.character.officers.reload.first.dead?
  end

  test "PATCH goto to a gated event returns locked:false for a choice whose requirement is met" do
    officers(:one).update!(specialty: "Greedy")

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "48-A" },
      as: :json

    assert_response :ok
    choices = response.parsed_body["next_event"]["choices"]
    gated = choices.find { |c| c["label"].include?("GREEDY") }
    assert_equal false, gated["locked"]
  end

  test "PATCH goto to a gated event returns locked:true for a choice whose requirement is not met" do
    officers(:one).update!(specialty: "Pilot", attribute_a: "MyString", attribute_b: "MyString")

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "48-A" },
      as: :json

    assert_response :ok
    choices = response.parsed_body["next_event"]["choices"]
    gated = choices.find { |c| c["label"].include?("GREEDY") }
    assert_equal true, gated["locked"]
    ungated = choices.find { |c| c["label"].start_with?("Destroy the AI") }
    assert_equal false, ungated["locked"]
  end

  # --- Store UI (20-A/B/C, multi-action stay-open purchases) ---

  test "PATCH buying SYS-PUMP applies the cost and item, and GET afterward shows it locked" do
    @campaign.update_columns(scrap: 10)

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", scrap_delta: -5, gain_item: "SYS-PUMP" },
      as: :json

    assert_response :ok
    assert_equal 5, @campaign.reload.scrap
    assert @campaign.has_item?("SYS-PUMP")

    get campaign_hex_event_path(campaign_id: @campaign.public_id, q: 1, r: 1), as: :json
    # simulate visiting 20-A again to check the choice is now locked
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "20-A" },
      as: :json

    choices = response.parsed_body["next_event"]["choices"]
    pump_choice = choices.find { |c| c["label"].include?("SYS-PUMP") }
    assert_equal true, pump_choice["locked"], "SYS-PUMP purchase should be locked out after buying it once"
  end

  test "PATCH buying fuel repeatedly accumulates fuel and spends scrap each time" do
    @campaign.update_columns(scrap: 20, fuel: 0)

    3.times do
      patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
        params: { action_type: "orbit", scrap_delta: -4, fuel_delta: 1 },
        as: :json
      assert_response :ok
    end

    @campaign.reload
    assert_equal 3, @campaign.fuel
    assert_equal 8, @campaign.scrap
  end

  test "PATCH completing the Luxury Food mission requires the item and consumes it" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "20-C" },
      as: :json

    choices = response.parsed_body["next_event"]["choices"]
    mission = choices.find { |c| c["label"].include?("Luxury Food") }
    assert_equal true, mission["locked"], "should be locked without [Lux Food]"

    @campaign.gain_item!("Lux Food")
    @campaign.update_columns(scrap: 0)

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", scrap_delta: 15, lose_item: "Lux Food" },
      as: :json

    assert_response :ok
    @campaign.reload
    assert_equal 15, @campaign.scrap
    assert_not @campaign.has_item?("Lux Food")
  end

  # --- Crew dice fatigue check (39-B/42-A/51-B/61-B/70-A/72-A pattern, 43-A threshold) ---

  test "PATCH goto to a Rising Waters event exposes a crew_dice_fatigue_check dice_roll, then rolling applies marks" do
    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "goto", goto_target: "42-A" },
      as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal "crew_dice_fatigue_check", json["next_event"]["dice_roll"]["kind"]

    original = CrewDice.method(:roll)
    CrewDice.define_singleton_method(:roll) { |_count| [ "threat_detected", "commander" ] }

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "roll_dice", dice_roll_kind: "crew_dice_fatigue_check" },
      as: :json

    assert_response :ok
    assert_match(/Threat Detected/, response.parsed_body["dice_result"])
    assert_equal 1, @campaign.character.officers.reload.first.fatigue_marks
  ensure
    CrewDice.define_singleton_method(:roll, original)
  end

  test "PATCH reaching 43-A applies the fatigue threshold and crosses out an over-threshold officer" do
    officer = @campaign.character.officers.first
    officer.update!(attribute_a: "MyString", attribute_b: "MyString")
    4.times { officer.add_fatigue_mark! }

    patch campaign_hex_event_update_path(campaign_id: @campaign.public_id, q: 1, r: 1),
      params: { action_type: "orbit", apply_fatigue_threshold: true },
      as: :json

    assert_response :ok
    assert officer.reload.dead?
  end

  private

  def with_die_roll(value)
    original = EventCatalog.method(:roll_die)
    EventCatalog.define_singleton_method(:roll_die) { value }
    yield
  ensure
    EventCatalog.define_singleton_method(:roll_die, original)
    EventCatalog.singleton_class.send(:private, :roll_die)
  end
end
