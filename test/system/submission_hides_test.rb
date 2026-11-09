require "application_system_test_case"

class SubmissionHidesTest < ApplicationSystemTestCase
  setup do
    @submission = submissions(:one)
    @user = users(:two)
    @user.update!(provider: "github", uid: "hide-system-user")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: @user.uid,
      info: { nickname: @user.username }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "hide persists and unhide from the private list restores the submission" do
    sign_in
    visit news_url
    within "form[action='#{submission_hide_path(@submission)}']" do
      click_button "hide", exact: true
    end
    assert_current_path news_path
    assert_no_selector "tr#submission_#{@submission.id}"

    visit news_url
    assert_no_selector "tr#submission_#{@submission.id}"
    click_link @user.username, match: :first
    click_link "hidden", exact: true
    assert_current_path hidden_submissions_path
    assert_selector "tr#submission_#{@submission.id}"

    within "form[action='#{submission_hide_path(@submission)}']" do
      click_button "unhide", exact: true
    end
    assert_current_path hidden_submissions_path
    assert_text "No hidden submissions."
    visit news_url
    assert_selector "tr#submission_#{@submission.id}"
  end

  test "hide and unhide in the detail stay on the detail without changing content" do
    sign_in
    visit submission_url(@submission)
    click_button "hide", exact: true
    assert_current_path submission_path(@submission)
    assert_button "unhide", exact: true
    visit submission_url(@submission)
    assert_button "unhide", exact: true
    click_button "unhide", exact: true
    assert_current_path submission_path(@submission)
    assert_button "hide", exact: true
    assert_equal 1, @submission.reload.points
    assert_selector ".submission-heading-title", text: @submission.title
  end

  test "anonymous visitors still see submissions hidden by another user" do
    sign_in
    visit news_url
    within "form[action='#{submission_hide_path(@submission)}']" do
      click_button "hide", exact: true
    end
    assert_no_selector "tr#submission_#{@submission.id}"
    click_button "logout", exact: true

    visit news_url
    assert_selector "tr#submission_#{@submission.id}"
    assert_no_selector "form.submission-hide-form"
  end

  private

  def sign_in
    visit "/auth/github/callback"
  end
end
