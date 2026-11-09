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

  test "submission detail hides voting controls without a session" do
    get submission_url(@submission)

    assert_response :success
    assert_select "form[action=?]", submission_vote_path(@submission), count: 0
  end

  test "lists hide voting controls without a session" do
    [ root_url, newest_url, search_url(q: "MyString"), ask_url ].each do |url|
      get url

      assert_response :success
      assert_select ".hn-vote-form", count: 0
    end
  end

  test "lists show vote controls only for other users submissions" do
    sign_in
    own_submission = submissions(:two)

    [ root_url, newest_url, search_url(q: "MyString") ].each do |url|
      get url

      assert_vote_form "vote"
      assert_select "form[action=?]", submission_vote_path(own_submission), count: 0
    end
  end

  test "list uses an upvote triangle and places unvote beside the metadata" do
    sign_in
    get root_url

    assert_select "tr#submission_#{@submission.id} .votelinks button[aria-label=vote]", text: "▲"
    assert_select "tr#submission_#{@submission.id} + tr .subtext button[aria-label=unvote]", count: 0

    post submission_vote_url(@submission)
    get root_url

    assert_select "tr#submission_#{@submission.id} .votelinks button", count: 0
    assert_select "tr#submission_#{@submission.id} + tr .subtext button[aria-label=unvote]", text: "unvote"
  end

  test "Ask list supports voting and withdrawing" do
    sign_in
    @submission = Submission.create!(title: "Voting Ask", user: users(:one))

    get ask_url
    assert_vote_form "vote"

    post submission_vote_url(@submission)
    get ask_url
    assert_vote_form "unvote", deleting: true

    delete submission_vote_url(@submission)
    get ask_url
    assert_vote_form "vote"
  end

  test "lists reflect votes after reload and agree with the detail" do
    sign_in
    post submission_vote_url(@submission)

    [ root_url, newest_url, search_url(q: "MyString") ].each do |url|
      get url
      assert_vote_form "unvote", deleting: true
      assert_select "tr#submission_#{@submission.id} + tr .score", text: "2 points"
    end

    delete submission_vote_url(@submission)

    [ root_url, newest_url, search_url(q: "MyString") ].each do |url|
      get url
      assert_vote_form "vote"
      assert_select "tr#submission_#{@submission.id} + tr .score", text: "1 points"
    end

    get submission_url(@submission)
    assert_vote_form "vote"
  end

  test "loads vote states in one query for the entire list" do
    sign_in
    4.times do |index|
      Submission.create!(title: "Voting link #{index}", url: "https://voting.example/#{index}", user: users(:one))
    end
    SubmissionVote.create!(user: @voter, submission: @submission)
    vote_queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      vote_queries << payload[:sql] if payload[:sql].match?(/FROM ["`]?submission_votes/i)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get root_url
    end

    assert_response :success
    assert_select ".hn-vote-form", count: 5
    assert_equal 1, vote_queries.size
  end

  test "submission detail hides voting controls on own submissions" do
    sign_in
    own_submission = submissions(:two)

    get submission_url(own_submission)

    assert_response :success
    assert_select "form[action=?]", submission_vote_path(own_submission), count: 0
  end

  test "submission detail keeps the vote button and points correct after reload" do
    sign_in
    get submission_url(@submission)
    assert_vote_form "vote"

    post submission_vote_url(@submission)
    follow_redirect!
    assert_vote_form "unvote", deleting: true

    get submission_url(@submission)
    assert_vote_form "unvote", deleting: true
    assert_select "#submission_#{@submission.id}", text: /Points:\s*2/

    delete submission_vote_url(@submission)
    follow_redirect!
    assert_vote_form "vote"

    get submission_url(@submission)
    assert_vote_form "vote"
    assert_select "#submission_#{@submission.id}", text: /Points:\s*1/
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

  def assert_vote_form(label, deleting: false)
    assert_response :success
    assert_select "form[action=?][method=post]", submission_vote_path(@submission), count: 1 do
      assert_select "button[type=submit][aria-label=?]", label, count: 1
      assert_select "input[name=_method][value=delete]", count: deleting ? 1 : 0
      assert_select "input[name=user_id]", count: 0
    end
  end

  def sign_in
    get "/auth/github/callback"
  end
end
