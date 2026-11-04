require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-callback",
      info: { nickname: "callback_user", email: "callback@example.com" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "OAuth callback creates a session" do
    get "/auth/github/callback"

    assert_redirected_to root_url
    assert_equal User.find_by!(uid: "github-callback").id, session[:user_id]
  end

  test "OAuth failure redirects to root" do
    get "/auth/failure", params: { message: "access_denied" }

    assert_redirected_to root_url
  end

  test "logout redirects to root" do
    post logout_url

    assert_redirected_to root_url
  end
end