require "application_system_test_case"

class SubmissionsTest < ApplicationSystemTestCase
  setup do
    @submission = submissions(:one)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-submissions-system",
      info: { nickname: "submissions_system_user", email: "submissions-system@example.com" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "visiting the index" do
    visit submissions_url
    assert_selector "table.hn-itemlist"
  end

  test "searching from the header and opening a submission" do
    visit root_url
    within "header" do
      fill_in "Search submissions by title", with: @submission.title
    end
    click_button "Search"

    within "#submission_#{@submission.id}" do
      click_link @submission.title
    end

    assert_current_path submission_path(@submission)
    assert_text @submission.title
  end

  test "should create submission" do
    sign_in
    visit new_submission_url

    fill_in "title", with: "A system test submission"
    fill_in "url", with: "https://system-created.example.test/submission"
    click_button "submit"

    assert_text "Submission was successfully created"
  end

  test "should update Submission" do
    sign_in_as_owner
    visit root_url
    click_on "edit", exact: true

    assert_field "title", with: @submission.title
    assert_field "url", with: @submission.url
    fill_in "title", with: "Updated system test submission"
    fill_in "url", with: "https://system-updated.example.test/submission"
    click_button "update"

    assert_text "Submission was successfully updated"
    assert_text "Updated system test submission"
  end

  test "should destroy Submission" do
    sign_in_as_owner
    visit root_url
    accept_confirm "Delete this submission and all its comments and replies? This cannot be undone." do
      click_on "delete", exact: true
    end

    assert_text "Submission was successfully destroyed"
  end

  test "cancelling deletion keeps the submission" do
    sign_in_as_owner
    visit submission_url(@submission)

    dismiss_confirm do
      click_on "Delete", exact: true
    end

    assert_current_path submission_path(@submission)
    assert_text @submission.title
    assert Submission.exists?(@submission.id)
  end

  private

  def sign_in_as_owner
    users(:one).update!(provider: "github", uid: "github-submissions-system")
    sign_in
  end

  def sign_in
    visit "/auth/github/callback"
  end
end
