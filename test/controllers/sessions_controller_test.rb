require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "OAuth failure redirects to root" do
    get "/auth/failure", params: { message: "access_denied" }

    assert_redirected_to root_url
  end

  test "logout redirects to root" do
    post logout_url

    assert_redirected_to root_url
  end
end