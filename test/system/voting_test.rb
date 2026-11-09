require "application_system_test_case"

class VotingTest < ApplicationSystemTestCase
  setup do
    @submission = submissions(:one)
    @comment = Comment.create!(submission: @submission, user: users(:one), body: "Comentari de prova de navegador")
    voter = users(:two)
    voter.update!(provider: "github", uid: "github-voting-system")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: voter.uid,
      info: { nickname: voter.username }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "votes and withdraws a submission vote through the browser" do
    visit "/auth/github/callback"
    visit root_url

    within "#submission_#{@submission.id}" do
      click_button "▲"
    end

    assert_current_path submission_path(@submission)
    within "#submission_#{@submission.id}" do
      assert_text "Points: 2"
      assert_button "unvote"
    end

    visit root_url
    within "#submission_#{@submission.id} + tr" do
      assert_text "2 points"
      click_button "unvote"
    end

    assert_current_path submission_path(@submission)
    visit root_url
    within "#submission_#{@submission.id}" do
      assert_button "▲"
    end
    assert_equal 1, @submission.reload.points
  end

  test "votes and withdraws a comment vote through the browser" do
    visit "/auth/github/callback"
    visit submission_url(@submission)

    within "#comment_#{@comment.id}" do
      click_button "▲"
    end

    assert_current_path submission_comment_path(@submission, @comment)
    within "#comment_#{@comment.id}" do
      assert_text "2 punts"
      assert_button "unvote"
    end

    visit comments_url
    within "#comment_#{@comment.id}" do
      assert_text "2 punts"
      click_button "unvote"
    end

    assert_current_path submission_comment_path(@submission, @comment)
    within "#comment_#{@comment.id}" do
      assert_text "1 punt"
      assert_button "▲"
    end
    assert_equal 1, @comment.reload.points
  end
end
