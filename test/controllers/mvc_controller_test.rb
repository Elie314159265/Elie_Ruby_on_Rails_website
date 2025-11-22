require "test_helper"

class MvcControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get mvc_index_url
    assert_response :success
  end

  test "should get controller" do
    get mvc_controller_url
    assert_response :success
  end

  test "should get model" do
    get mvc_model_url
    assert_response :success
  end

  test "should get view" do
    get mvc_view_url
    assert_response :success
  end
end
