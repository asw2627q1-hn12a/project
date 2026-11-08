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
    visit submission_url(@submission)
    click_on "Edit", exact: true

    fill_in "title", with: "Updated system test submission"
    fill_in "url", with: "https://system-updated.example.test/submission"
    click_button "submit"

    assert_text "Submission was successfully updated"
    click_on "Back to submissions", exact: true
  end

  test "should destroy Submission" do
    visit submission_url(@submission)
    click_on "Delete", exact: true

    assert_text "Submission was successfully destroyed"
  end

  private

  def sign_in
    visit "/auth/github/callback"
  end
end
