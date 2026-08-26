require "application_system_test_case"

class LandingPageTest < ApplicationSystemTestCase
  test "visiting the landing page shows the Start Playing button" do
    visit root_path

    assert_text "Deep Space D-6"
    assert_text "The Long Way Home"
    assert_selector "button, a", text: "Start Playing"
  end
end
