require "test_helper"

class CrewDiceTest < ActiveSupport::TestCase
  test "roll returns the requested number of results" do
    assert_equal 5, CrewDice.roll(5).size
  end

  test "roll only ever returns known faces" do
    100.times do
      CrewDice.roll(6).each { |face| assert_includes CrewDice::FACES, face }
    end
  end

  test "FACES has exactly the 6 known crew die faces, no skull" do
    assert_equal %w[threat_detected commander science engineering tactical medical], CrewDice::FACES
    assert_not_includes CrewDice::FACES, "skull"
  end

  test "roll(0) returns an empty array" do
    assert_equal [], CrewDice.roll(0)
  end
end
