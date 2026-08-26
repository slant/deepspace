require "test_helper"

class OfficerTest < ActiveSupport::TestCase
  test "effective_title returns the titleized enum value by default" do
    officer = officers(:one)
    officer.update!(title: :lieutenant_commander)

    assert_equal "Lieutenant Commander", officer.effective_title
  end

  test "effective_title prefers title_override when set" do
    officer = officers(:one)
    officer.update!(title: :commander, title_override: "GLADIATOR")

    assert_equal "GLADIATOR", officer.effective_title
  end

  test "all_attributes includes attribute_a, attribute_b, and bonus_attributes" do
    officer = officers(:one)
    officer.update!(attribute_a: "Coward", attribute_b: "Observant")
    officer.add_attribute!("Restless")

    assert_equal [ "Coward", "Observant", "Restless" ], officer.all_attributes
  end

  test "add_attribute! does not duplicate an already-held attribute" do
    officer = officers(:one)
    officer.add_attribute!("Lucky")

    officer.add_attribute!("Lucky")

    assert_equal [ "Lucky" ], officer.reload.bonus_attributes
  end

  test "kill! marks the officer dead" do
    officer = officers(:one)
    assert_not officer.dead?

    officer.kill!

    assert officer.reload.dead?
  end

  # --- Fatigue ---

  test "fatigue_threshold defaults to 4" do
    officer = officers(:one)
    officer.update!(attribute_a: "MyString", attribute_b: "MyString")

    assert_equal 4, officer.fatigue_threshold
  end

  test "fatigue_threshold is 3 for WEAK/IMPULSIVE/STUBBORN" do
    officer = officers(:one)
    officer.update!(attribute_a: "Impulsive", attribute_b: "MyString")

    assert_equal 3, officer.fatigue_threshold
  end

  test "fatigue_threshold is 5 for OPTIMISTIC/IMPROVISER/PERSISTENT" do
    officer = officers(:one)
    officer.update!(attribute_a: "MyString", attribute_b: "Persistent")

    assert_equal 5, officer.fatigue_threshold
  end

  test "fatigue_threshold checks bonus_attributes too" do
    officer = officers(:one)
    officer.update!(attribute_a: "MyString", attribute_b: "MyString")
    officer.add_attribute!("Optimistic")

    assert_equal 5, officer.fatigue_threshold
  end

  test "fatigued? compares fatigue_marks to the threshold" do
    officer = officers(:one)
    officer.update!(attribute_a: "MyString", attribute_b: "MyString")

    3.times { officer.add_fatigue_mark! }
    assert_not officer.reload.fatigued?

    officer.add_fatigue_mark!
    assert officer.reload.fatigued?
  end

  test "add_fatigue_mark! increments the counter" do
    officer = officers(:one)

    officer.add_fatigue_mark!
    officer.add_fatigue_mark!

    assert_equal 2, officer.reload.fatigue_marks
  end
end
