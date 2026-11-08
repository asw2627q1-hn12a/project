require "test_helper"

class SubmissionVotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @submission = submissions(:one)
    @voter = users(:two)
    @voter.update!(provider: "github", uid: "github-voter")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: @voter.uid,
      info: { nickname: @voter.username }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "creates a vote as the logged in user and adds one point" do
    sign_in

    assert_difference("SubmissionVote.count", 1) do
      post submission_vote_url(@submission), params: { user_id: @submission.user_id, points: 999 }
    end

    assert_equal @voter, SubmissionVote.last.user
    assert_equal 2, @submission.reload.points
    assert_response :see_other
    assert_redirected_to submission_url(@submission)
    follow_redirect!
    assert_select "#submission_#{@submission.id}", text: /Points:\s*2/
  end

  test "repeating a vote does not create a duplicate or add points" do
    sign_in
    post submission_vote_url(@submission)

    assert_no_difference("SubmissionVote.count") do
      post submission_vote_url(@submission)
    end

    assert_equal 2, @submission.reload.points
    assert_response :see_other
  end

  test "removes own vote and restores the initial point" do
    sign_in
    SubmissionVote.create!(user: @voter, submission: @submission)

    assert_difference("SubmissionVote.count", -1) do
      delete submission_vote_url(@submission)
    end

    assert_equal 1, @submission.reload.points
    assert_response :see_other
    follow_redirect!
    assert_select "#submission_#{@submission.id}", text: /Points:\s*1/
  end

  test "repeating a withdrawal does not subtract another point" do
    sign_in
    SubmissionVote.create!(user: @voter, submission: @submission)
    delete submission_vote_url(@submission)

    assert_no_difference("SubmissionVote.count") do
      delete submission_vote_url(@submission)
    end

    assert_equal 1, @submission.reload.points
  end

  test "anonymous users cannot vote" do
    assert_no_difference("SubmissionVote.count") do
      post submission_vote_url(@submission)
    end

    assert_redirected_to root_url
    assert_equal 1, @submission.reload.points
  end

  test "anonymous users cannot withdraw votes" do
    vote = SubmissionVote.create!(user: @voter, submission: @submission)

    assert_no_difference("SubmissionVote.count") do
      delete submission_vote_url(@submission)
    end

    assert_redirected_to root_url
    assert SubmissionVote.exists?(vote.id)
    assert_equal 2, @submission.reload.points
  end

  test "cannot vote own submission" do
    sign_in
    own_submission = submissions(:two)

    assert_no_difference("SubmissionVote.count") do
      post submission_vote_url(own_submission)
    end

    assert_response :forbidden
    assert_equal 1, own_submission.reload.points
  end

  test "cannot withdraw another user's vote using forged parameters" do
    sign_in
    other_voter = User.create!(username: "other_voter")
    other_vote = SubmissionVote.create!(user: other_voter, submission: @submission)

    assert_no_difference("SubmissionVote.count") do
      delete submission_vote_url(@submission), params: { user_id: other_voter.id, vote_id: other_vote.id }
    end

    assert SubmissionVote.exists?(other_vote.id)
    assert_equal 2, @submission.reload.points
  end

  test "withdraws only own vote when another vote also exists" do
    sign_in
    other_voter = User.create!(username: "other_voter")
    other_vote = SubmissionVote.create!(user: other_voter, submission: @submission)
    SubmissionVote.create!(user: @voter, submission: @submission)

    assert_difference("SubmissionVote.count", -1) do
      delete submission_vote_url(@submission), params: { vote_id: other_vote.id }
    end

    assert SubmissionVote.exists?(other_vote.id)
    assert_not SubmissionVote.exists?(user: @voter, submission: @submission)
    assert_equal 2, @submission.reload.points
  end

  test "GET cannot change votes" do
    sign_in

    assert_no_difference("SubmissionVote.count") do
      get submission_vote_url(@submission)
    end

    assert_response :not_found
    assert_equal 1, @submission.reload.points
  end

  test "rejects voting and withdrawing without a CSRF token when protection is enabled" do
    sign_in
    vote = SubmissionVote.create!(user: @voter, submission: @submission)
    original_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference("SubmissionVote.count") do
      post submission_vote_url(@submission)
      assert_response :unprocessable_content

      delete submission_vote_url(@submission)
      assert_response :unprocessable_content
    end

    assert SubmissionVote.exists?(vote.id)
    assert_equal 2, @submission.reload.points
  ensure
    ActionController::Base.allow_forgery_protection = original_protection
  end

  private

  def sign_in
    get "/auth/github/callback"
  end
end
