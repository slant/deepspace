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
end
