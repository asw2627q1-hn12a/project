require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-system-user",
      info: { nickname: "system_user", email: "system@example.com" }
    )

    visit "/auth/github/callback"
    @user = User.find_by!(uid: "github-system-user")
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "visiting the index" do
    visit users_url
    assert_selector "h1", text: "Users"
  end

  test "should update User" do
    # Com a la captura de l'enunciat, el perfil propi ja és el formulari.
    visit user_url(@user)

    fill_in "about:", with: "Hello from the system test"
    fill_in "email:", with: @user.email
    click_on "update"

    assert_text "User was successfully updated"
    assert_field "about:", with: "Hello from the system test"
  end

  test "should destroy User" do
    visit user_url(@user)
    accept_confirm do
      click_on "delete account"
    end

    assert_text "User was successfully destroyed"
  end
end
