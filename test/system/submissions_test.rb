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
    click_on "Edit this submission", match: :first

    fill_in "title", with: "Updated system test submission"
    fill_in "url", with: "https://system-updated.example.test/submission"
    click_button "submit"

    assert_text "Submission was successfully updated"
    click_on "Back"
  end

  test "should destroy Submission" do
    visit submission_url(@submission)
    click_on "Destroy this submission", match: :first

    assert_text "Submission was successfully destroyed"
  end

  private

  def sign_in
    visit "/auth/github/callback"
  end
end
