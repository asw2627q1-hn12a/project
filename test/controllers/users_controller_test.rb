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

  test "edit form crops avatar and banner to their final size" do
    sign_in
    get edit_user_url(current_user)

    assert_select "[data-controller=image-cropper][data-image-cropper-width-value='400'][data-image-cropper-height-value='400'] input[name='user[avatar]']"
    assert_select "[data-controller=image-cropper][data-image-cropper-width-value='1200'][data-image-cropper-height-value='200'] input[name='user[banner]']"
    assert_select "label", text: "about:"
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

  test "profile shows user data and karma to anonymous visitors without private fields" do
    @user.update!(about: "Hello from user one")
    Submission.create!(title: "Karma one", url: "https://karma.example/one", user: @user, points: 7)
    Submission.create!(title: "Karma two", user: @user, points: 3)

    get user_url(@user)

    assert_response :success
    assert_select ".hn-profile", text: /user_one/
    assert_select ".hn-profile", text: /karma:\s*#{submissions(:one).points + 10}/
    assert_select ".hn-profile-about", text: /Hello from user one/
    assert_select ".hn-profile", text: /one@example\.com/, count: 0
    assert_select "a[href=?]", edit_user_path(@user), count: 0
  end

  test "own profile shows email and edit links" do
    sign_in
    user = current_user

    get user_url(user)

    assert_select ".hn-profile", text: /users@example\.com/
    assert_select "a[href=?]", edit_user_path(user)
    assert_select "a[href=?]", hidden_submissions_path
  end

  test "owner can update about and email but not username" do
    sign_in
    user = current_user

    patch user_url(user), params: { user: { about: "New about", email: "new@example.com", username: "hacked" } }

    assert_redirected_to user_url(user)
    user.reload
    assert_equal "New about", user.about
    assert_equal "new@example.com", user.email
    assert_equal "users_controller_user", user.username
  end

  test "too long about is rejected and errors are shown" do
    sign_in
    user = current_user

    patch user_url(user), params: { user: { about: "a" * 2001 } }

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /About/
    assert_nil user.reload.about
  end

  test "email is private in the users list and in JSON" do
    get users_url
    assert_no_match "one@example.com", response.body

    get users_url(format: :json)
    assert_no_match "one@example.com", response.body

    get user_url(@user, format: :json)
    assert_response :success
    assert_not response.parsed_body.key?("email")
  end

  test "another user cannot see the email but the owner can" do
    sign_in

    get user_url(@user, format: :json)
    assert_not response.parsed_body.key?("email")
    get users_url
    assert_no_match "one@example.com", response.body

    get user_url(current_user, format: :json)
    assert_equal "users@example.com", response.parsed_body["email"]
  end

  test "should reject updating another user" do
    sign_in

    patch user_url(@user), params: { user: { about: "Not mine" } }

    assert_redirected_to root_url
    assert_nil @user.reload.about
  end

  test "anyone can list a user's submissions and comments" do
    submission = Submission.create!(title: "Own list item", user: @user)
    Comment.create!(submission: submission, user: @user, body: "Public comment")
    deleted = Comment.create!(submission: submission, user: @user, body: "Gone")
    deleted.soft_delete!

    get submissions_user_url(@user)
    assert_response :success
    assert_select ".titleline a[href=?]", submission_path(submission), text: "Own list item"

    get comments_user_url(@user)
    assert_response :success
    assert_select ".comment-body", text: /Public comment/
    assert_select "##{ActionView::RecordIdentifier.dom_id(deleted)}", count: 0
  end

  test "profile links public lists for visitors and private lists only for the owner" do
    get user_url(@user)
    assert_select "a[href=?]", submissions_user_path(@user)
    assert_select "a[href=?]", comments_user_path(@user)
    assert_select "a[href=?]", upvoted_user_path(@user), count: 0

    sign_in
    get user_url(current_user)
    assert_select "a[href=?]", upvoted_user_path(current_user)
    assert_select "a[href=?]", upvoted_comments_user_path(current_user)
  end

  test "owner sees upvoted submissions and comments" do
    sign_in
    user = current_user
    submission = Submission.create!(title: "Liked submission", user: @user)
    comment = Comment.create!(submission: submission, user: @user, body: "Liked comment")
    SubmissionVote.create!(user: user, submission: submission)
    CommentVote.create!(user: user, comment: comment)

    get upvoted_user_url(user)
    assert_response :success
    assert_select ".titleline a[href=?]", submission_path(submission), text: "Liked submission"

    get upvoted_comments_user_url(user)
    assert_response :success
    assert_select ".comment-body", text: /Liked comment/
  end

  test "upvoted shows unhide for a submission the owner also hid" do
    sign_in
    user = current_user
    submission = Submission.create!(title: "Voted then hidden", user: @user)
    SubmissionVote.create!(user: user, submission: submission)
    SubmissionHide.create!(user: user, submission: submission)

    get upvoted_user_url(user)

    assert_select "form[action=?]", submission_hide_path(submission) do
      assert_select "button, input[type=submit]", text: "unhide"
    end
  end

  test "upvoted lists are private on the server" do
    get upvoted_user_url(@user)
    assert_redirected_to root_url

    sign_in
    get upvoted_user_url(@user)
    assert_redirected_to root_url
    get upvoted_comments_user_url(@user)
    assert_redirected_to root_url
  end

  test "profile shows default avatar and banner when none are uploaded" do
    get user_url(@user)

    assert_select "img.hn-profile-avatar[src*=?]", "default-avatar"
    assert_select "img.hn-profile-banner[src*=?]", "default-banner"
  end

  test "owner uploads and then removes an avatar and a banner" do
    sign_in
    user = current_user

    patch user_url(user), params: { user: {
      avatar: fixture_file_upload("avatar.png", "image/png"),
      banner: fixture_file_upload("avatar.png", "image/png")
    } }

    assert_redirected_to user_url(user)
    assert user.reload.avatar.attached?
    assert user.banner.attached?
    get user_url(user)
    assert_select "img.hn-profile-avatar[src*=?]", "/rails/active_storage/"

    patch user_url(user), params: { user: { remove_avatar: "1", remove_banner: "1" } }

    assert_redirected_to user_url(user)
    assert_not user.reload.avatar.attached?
    assert_not user.banner.attached?
    get user_url(user)
    assert_select "img.hn-profile-avatar[src*=?]", "default-avatar"
  end

  test "non image avatar is rejected" do
    sign_in
    user = current_user

    patch user_url(user), params: { user: { avatar: fixture_file_upload("not_an_image.txt", "text/plain") } }

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /PNG, JPEG, GIF or WebP/
    assert_not user.reload.avatar.attached?
  end

  test "an existing non image blob attached by signed_id is rejected" do
    sign_in
    user = current_user
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("a" * 3.megabytes), filename: "big.txt", content_type: "text/plain")

    patch user_url(user), params: { user: { avatar: blob.signed_id } }

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /PNG, JPEG, GIF or WebP/
    assert_select "[role=alert]", text: /2 MB/
    assert_not user.reload.avatar.attached?
  end

  test "users cannot change another user's avatar" do
    sign_in

    patch user_url(@user), params: { user: { avatar: fixture_file_upload("avatar.png", "image/png") } }

    assert_redirected_to root_url
    assert_not @user.reload.avatar.attached?
  end

  private

  def sign_in
    get "/auth/github/callback"
  end

  def current_user
    User.find_by!(uid: "github-users-controller")
  end
end
