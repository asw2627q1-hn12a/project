require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-users-controller",
      info: { nickname: "users_controller_user", email: "users@example.com" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "should get index" do
    get users_url
    assert_response :success
  end

  test "should show user" do
    get user_url(@user)
    assert_response :success
  end

  test "should get edit" do
    sign_in
    get edit_user_url(current_user)
    assert_response :success
  end

  test "should update user" do
    sign_in
    user = current_user
    patch user_url(user), params: { user: { email: user.email, username: user.username } }
    assert_redirected_to user_url(user)
  end

  test "should destroy user" do
    sign_in
    user = current_user
    assert_difference("User.count", -1) do
      delete user_url(user)
    end

    assert_redirected_to users_url
    assert_nil session[:user_id]
  end

  test "should reject editing another user" do
    sign_in

    get edit_user_url(@user)

    assert_redirected_to root_url
  end

  private

  def sign_in
    get "/auth/github/callback"
  end

  def current_user
    User.find_by!(uid: "github-users-controller")
  end
end
