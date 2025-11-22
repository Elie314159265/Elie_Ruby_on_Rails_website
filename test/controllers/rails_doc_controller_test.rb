require "test_helper"

class RailsDocControllerTest < ActionDispatch::IntegrationTest
  test "should get routing" do
    get rails_doc_routing_url
    assert_response :success
  end

  test "should get migration" do
    get rails_doc_migration_url
    assert_response :success
  end

  test "should get active_record" do
    get rails_doc_active_record_url
    assert_response :success
  end
end
