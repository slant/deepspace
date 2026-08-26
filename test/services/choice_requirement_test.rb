require "test_helper"

class ChoiceRequirementTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:one)
    @officer = officers(:one)
  end

  test "blank requires is always satisfied" do
    assert ChoiceRequirement.satisfied?(nil, campaign: @campaign)
    assert ChoiceRequirement.satisfied?({}, campaign: @campaign)
  end

  test "specialty_or_attribute is satisfied when an officer has a matching specialty" do
    @officer.update!(specialty: "Hacker")

    assert ChoiceRequirement.satisfied?({ "specialty_or_attribute" => [ "HACKER" ] }, campaign: @campaign)
  end

  test "specialty_or_attribute matches attribute_a" do
    @officer.update!(attribute_a: "Coward")
    assert ChoiceRequirement.satisfied?({ "specialty_or_attribute" => [ "COWARD" ] }, campaign: @campaign)
  end

  test "specialty_or_attribute matches attribute_b" do
    @officer.update!(attribute_b: "Observant")
    assert ChoiceRequirement.satisfied?({ "specialty_or_attribute" => [ "OBSERVANT" ] }, campaign: @campaign)
  end

  test "specialty_or_attribute is an OR match against the list" do
    @officer.update!(specialty: "Chef")

    assert ChoiceRequirement.satisfied?(
      { "specialty_or_attribute" => [ "ARTISAN", "CHEF", "MUSICIAN" ] }, campaign: @campaign
    )
  end

  test "specialty_or_attribute is not satisfied when no officer matches" do
    @officer.update!(specialty: "Pilot", attribute_a: "MyString", attribute_b: "MyString")

    assert_not ChoiceRequirement.satisfied?({ "specialty_or_attribute" => [ "HACKER" ] }, campaign: @campaign)
  end

  test "an unreal specialty (PDF authoring error, e.g. ASTRONOMER) never matches" do
    @officer.update!(specialty: "Chemist")

    assert ChoiceRequirement.satisfied?(
      { "specialty_or_attribute" => [ "ASTRONOMER", "CHEMIST", "DOCTOR", "PILOT" ] }, campaign: @campaign
    )
    assert_not ChoiceRequirement.satisfied?({ "specialty_or_attribute" => [ "ASTRONOMER" ] }, campaign: @campaign)
  end

  test "excludes_specialty_or_attribute is satisfied when no officer has the trait" do
    @officer.update!(attribute_a: "MyString")
    assert ChoiceRequirement.satisfied?({ "excludes_specialty_or_attribute" => [ "COWARD" ] }, campaign: @campaign)
  end

  test "excludes_specialty_or_attribute is not satisfied when an officer has the trait" do
    @officer.update!(attribute_a: "Coward")
    assert_not ChoiceRequirement.satisfied?({ "excludes_specialty_or_attribute" => [ "COWARD" ] }, campaign: @campaign)
  end

  test "item requirement checks has_item?" do
    assert_not ChoiceRequirement.satisfied?({ "item" => "AI-System" }, campaign: @campaign)

    @campaign.gain_item!("AI-System")
    assert ChoiceRequirement.satisfied?({ "item" => "AI-System" }, campaign: @campaign)
  end

  test "excludes_item is satisfied only when the item is not held" do
    assert ChoiceRequirement.satisfied?({ "excludes_item" => "SYS-PUMP" }, campaign: @campaign)

    @campaign.gain_item!("SYS-PUMP")
    assert_not ChoiceRequirement.satisfied?({ "excludes_item" => "SYS-PUMP" }, campaign: @campaign)
  end

  test "item requirement is not satisfied by a lost item" do
    @campaign.gain_item!("Vortex")
    @campaign.lose_item!("Vortex")

    assert_not ChoiceRequirement.satisfied?({ "item" => "Vortex" }, campaign: @campaign)
  end

  test "items_all requires every listed item" do
    @campaign.gain_item!("Lux Food")
    assert_not ChoiceRequirement.satisfied?(
      { "items_all" => [ "Lux Food", "Fluffy Creature" ] }, campaign: @campaign
    )

    @campaign.gain_item!("Fluffy Creature")
    assert ChoiceRequirement.satisfied?(
      { "items_all" => [ "Lux Food", "Fluffy Creature" ] }, campaign: @campaign
    )
  end

  test "sequence requirement without state matches any mark" do
    assert_not ChoiceRequirement.satisfied?({ "sequence" => "711" }, campaign: @campaign)

    @campaign.mark_sequence!("711", "underline")
    assert ChoiceRequirement.satisfied?({ "sequence" => "711" }, campaign: @campaign)
  end

  test "sequence requirement with state only matches the specific mark type" do
    @campaign.mark_sequence!("000", "underline")

    assert ChoiceRequirement.satisfied?(
      { "sequence" => "000", "state" => "underlined" }, campaign: @campaign
    )
    assert_not ChoiceRequirement.satisfied?(
      { "sequence" => "000", "state" => "circled" }, campaign: @campaign
    )
  end

  test "sequence_all requires every listed token marked" do
    @campaign.mark_sequence!("L", "underline")
    assert_not ChoiceRequirement.satisfied?({ "sequence_all" => [ "L", "711" ] }, campaign: @campaign)

    @campaign.mark_sequence!("711", "underline")
    assert ChoiceRequirement.satisfied?({ "sequence_all" => [ "L", "711" ] }, campaign: @campaign)
  end

  test "exclude_sequence is satisfied only when the token is unmarked" do
    assert ChoiceRequirement.satisfied?({ "exclude_sequence" => "711" }, campaign: @campaign)

    @campaign.mark_sequence!("711", "underline")
    assert_not ChoiceRequirement.satisfied?({ "exclude_sequence" => "711" }, campaign: @campaign)
  end

  test "exclude_sequence_any (14-C 'no qualifying sequences' fallback)" do
    assert ChoiceRequirement.satisfied?({ "exclude_sequence_any" => [ "L", "711" ] }, campaign: @campaign)

    @campaign.mark_sequence!("L", "underline")
    assert_not ChoiceRequirement.satisfied?({ "exclude_sequence_any" => [ "L", "711" ] }, campaign: @campaign)
  end

  test "multiple requirement keys combine with AND" do
    @officer.update!(specialty: "Hacker")
    requires = { "specialty_or_attribute" => [ "HACKER" ], "item" => "Vortex" }

    assert_not ChoiceRequirement.satisfied?(requires, campaign: @campaign)

    @campaign.gain_item!("Vortex")
    assert ChoiceRequirement.satisfied?(requires, campaign: @campaign)
  end
end
