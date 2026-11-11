require "application_system_test_case"

# Retall de l'avatar al navegador (TG-49): el formulari no s'ha d'enviar abans que
# el retall estigui exportat, i una exportació d'una imatge anterior no pot
# trepitjar la imatge triada després.
class ProfileImagesTest < ApplicationSystemTestCase
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-images-user",
      info: { nickname: "images_user", email: "images@example.com" }
    )

    visit "/auth/github/callback"
    @user = User.find_by!(uid: "github-images-user")
    visit edit_user_url(@user)
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "submitting right after choosing an image waits for the crop" do
    attach_file "user[avatar]", file_fixture("landscape_red.png").to_s
    click_on "update"

    assert_text "User was successfully updated"
    assert_equal [ 400, 400 ], png_size(@user.reload.avatar)
    assert_equal "landscape_red.png", @user.avatar.filename.to_s
  end

  test "switching images quickly keeps only the last one" do
    attach_file "user[avatar]", file_fixture("landscape_red.png").to_s
    attach_file "user[avatar]", file_fixture("portrait_blue.png").to_s
    click_on "update"

    assert_text "User was successfully updated"
    assert_equal "portrait_blue.png", @user.reload.avatar.filename.to_s
    assert_equal [ 400, 400 ], png_size(@user.avatar)
  end

  private

  # Amplada i alçada que diu la capçalera IHDR del PNG desat.
  def png_size(attachment)
    attachment.download[16, 8].unpack("NN")
  end
end
