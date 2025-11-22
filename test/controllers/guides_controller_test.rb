require "test_helper"

class GuidesControllerTest < ActionDispatch::IntegrationTest
  test "should get ruby_overview" do
    get guides_ruby_overview_url
    assert_response :success
  end
end
