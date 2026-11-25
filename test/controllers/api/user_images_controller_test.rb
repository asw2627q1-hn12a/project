require "test_helper"

class Api::UserImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other = users(:two)
  end

  test "without API key returns 401" do
    put "/api/users/#{@user.id}/avatar", params: { image: png("avatar.png") }

    assert_response :unauthorized
    assert_not @user.reload.avatar.attached?
  end

  test "owner uploads an avatar and a banner with multipart" do
    put "/api/users/#{@user.id}/avatar", headers: api_headers, params: { image: png("avatar.png") }

    assert_response :success
    assert_match %r{/rails/active_storage/blobs/redirect/.+/avatar\.png\z}, response.parsed_body["avatar_url"]
    assert_equal "one@example.com", response.parsed_body["email"]
    assert @user.reload.avatar.attached?

    put "/api/users/#{@user.id}/banner", headers: api_headers, params: { image: png("landscape_red.png") }

    assert_response :success
    assert_match %r{/landscape_red\.png\z}, response.parsed_body["banner_url"]
    assert @user.reload.banner.attached?
  end

  test "changing the images of another user returns 403" do
    put "/api/users/#{@other.id}/avatar", headers: api_headers, params: { image: png("avatar.png") }
    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body.fetch("error")

    delete "/api/users/#{@other.id}/banner", headers: api_headers
    assert_response :forbidden
    assert_not @other.reload.avatar.attached?
  end

  test "a file that is not an image returns 422 and keeps the default" do
    put "/api/users/#{@user.id}/avatar", headers: api_headers,
      params: { image: fixture_file_upload("not_an_image.txt", "text/plain") }

    assert_response :unprocessable_content
    assert response.parsed_body.dig("details", "avatar").present?
    assert_not @user.reload.avatar.attached?
  end

  test "missing image or a text instead of a file returns 400" do
    put "/api/users/#{@user.id}/avatar", headers: api_headers
    assert_response :bad_request

    # Un text s'interpretaria com el signed_id d'un fitxer que ja és al storage.
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("avatar.png").open, filename: "avatar.png")
    put "/api/users/#{@user.id}/avatar", headers: api_headers, params: { image: blob.signed_id }
    assert_response :bad_request
    assert_not @user.reload.avatar.attached?
  end

  test "delete brings back the default image" do
    @user.avatar.attach(png("avatar.png"))

    delete "/api/users/#{@user.id}/avatar", headers: api_headers

    assert_response :success
    assert_match %r{/assets/default-avatar.*\.svg\z}, response.parsed_body["avatar_url"]
    assert_not @user.reload.avatar.attached?
  end

  private

  def api_headers
    { "X-API-Key" => @user.api_key }
  end

  def png(name)
    fixture_file_upload(name, "image/png")
  end
end
