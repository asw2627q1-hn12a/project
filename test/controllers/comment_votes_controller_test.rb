require "test_helper"

class CommentVotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @submission = submissions(:one)
    @comment = Comment.create!(submission: @submission, user: users(:one), body: "Comentari per votar")
    @voter = users(:two)
    @voter.update!(provider: "github", uid: "github-comment-voter")
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

  test "voting and withdrawing return to the original local page" do
    sign_in

    [ submission_url(@submission), comments_url, threads_url ].each do |url|
      post vote_url, headers: { "HTTP_REFERER" => url }

      assert_response :see_other
      assert_redirected_to url
      follow_redirect!
      assert_response :success
      assert_equal 2, @comment.reload.points

      delete vote_url, headers: { "HTTP_REFERER" => url }

      assert_response :see_other
      assert_redirected_to url
      assert_equal 1, @comment.reload.points
    end
  end

  test "external referrers fall back to the comment detail" do
    sign_in
    headers = { "HTTP_REFERER" => "https://external.example/vote" }

    post vote_url, headers: headers
    assert_redirected_to submission_comment_url(@submission, @comment)

    delete vote_url, headers: headers
    assert_redirected_to submission_comment_url(@submission, @comment)
  end

  test "anonymous readers see points but no voting forms" do
    get submission_url(@submission)

    assert_response :success
    assert_select "#comment_#{@comment.id} .comment-score", text: "1 point"
    assert_select ".comment-vote-form", count: 0
    assert_select "#comment_#{@comment.id} form.hn-vote-login-form[action='/auth/github'][method=post][data-turbo=false]" do
      assert_select "button[aria-label='Log in to vote']"
    end
  end

  test "anonymous readers cannot use a deleted comment as a login vote target" do
    @comment.soft_delete!
    get submission_url(@submission)

    assert_select "#comment_#{@comment.id} .hn-vote-login-form", count: 0
  end

  test "own comments have no voting forms" do
    sign_in
    own_comment = Comment.create!(submission: @submission, user: @voter, body: "Comentari propi")

    get submission_url(@submission)

    assert_response :success
    assert_select "form[action=?]", submission_comment_vote_path(@submission, own_comment), count: 0
    assert_comment_vote_form "vote"
  end

  test "vote state and points persist across the tree detail and recent comments" do
    sign_in
    pages = [ submission_url(@submission), submission_comment_url(@submission, @comment), comments_url ]

    pages.each do |url|
      get url
      assert_comment_vote_form "vote"
      assert_select "#comment_#{@comment.id} .comment-score", text: "1 point"
    end

    post vote_url
    follow_redirect!
    assert_comment_vote_form "unvote", deleting: true

    pages.each do |url|
      get url
      assert_comment_vote_form "unvote", deleting: true
      assert_select "#comment_#{@comment.id} .comment-score", text: "2 points"
      assert_select "#comment_#{@comment.id} .hn-vote-button--arrow", count: 0
    end

    delete vote_url
    follow_redirect!
    assert_comment_vote_form "vote"

    pages.each do |url|
      get url
      assert_comment_vote_form "vote"
      assert_select "#comment_#{@comment.id} .comment-score", text: "1 point"
    end
  end

  test "deleted comments show only the withdrawal of an existing own vote" do
    sign_in
    CommentVote.create!(user: @voter, comment: @comment)
    @comment.soft_delete!

    get submission_comment_url(@submission, @comment)
    assert_comment_vote_form "unvote", deleting: true
    assert_select ".hn-vote-button--arrow", count: 0

    delete vote_url
    follow_redirect!

    assert_select ".comment-vote-form", count: 0
    assert_equal 1, @comment.reload.points
  end

  test "own threads allow voting other users replies at any depth" do
    sign_in
    parent = Comment.create!(submission: @submission, user: @voter, body: "El meu fil")
    reply = Comment.create!(submission: @submission, user: users(:one), body: "Resposta", parent: parent)
    @comment = Comment.create!(submission: @submission, user: users(:one), body: "Resposta profunda", parent: reply)

    get threads_url
    assert_comment_vote_form "vote"

    post vote_url
    get threads_url
    assert_comment_vote_form "unvote", deleting: true
  end

  test "loads comment vote states once for a full page" do
    sign_in
    4.times do |index|
      Comment.create!(submission: @submission, user: users(:one), body: "Resposta #{index}", parent: @comment)
    end
    CommentVote.create!(user: @voter, comment: @comment)

    [ submission_url(@submission), comments_url ].each do |url|
      vote_queries = []
      subscriber = lambda do |_name, _start, _finish, _id, payload|
        vote_queries << payload[:sql] if payload[:sql].match?(/FROM ["`]?comment_votes/i)
      end

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        get url
      end

      assert_response :success
      assert_select ".comment-vote-form", count: 5
      assert_equal 1, vote_queries.size
    end
  end

  test "votes as the logged in user and ignores forged author and points" do
    sign_in

    assert_difference("CommentVote.count", 1) do
      post vote_url, params: { user_id: @comment.user_id, points: 999 }
    end

    assert_equal @voter, CommentVote.last.user
    assert_equal @comment, CommentVote.last.comment
    assert_equal 2, @comment.reload.points
    assert_response :see_other
    assert_redirected_to submission_comment_url(@submission, @comment)
    follow_redirect!
    assert_response :success
  end

  test "duplicate requests do not add another vote or point" do
    sign_in
    post vote_url

    assert_no_difference("CommentVote.count") do
      post vote_url
    end

    assert_equal 2, @comment.reload.points
    assert_response :see_other
  end

  test "withdraws own vote and restores the initial point" do
    sign_in
    CommentVote.create!(user: @voter, comment: @comment)

    assert_difference("CommentVote.count", -1) do
      delete vote_url
    end

    assert_equal 1, @comment.reload.points
    assert_response :see_other
    assert_redirected_to submission_comment_url(@submission, @comment)
  end

  test "repeating a withdrawal does not subtract another point" do
    sign_in
    CommentVote.create!(user: @voter, comment: @comment)
    delete vote_url

    assert_no_difference("CommentVote.count") do
      delete vote_url
    end

    assert_equal 1, @comment.reload.points
  end

  test "anonymous users cannot vote" do
    assert_no_difference("CommentVote.count") do
      post vote_url
    end

    assert_redirected_to root_url
    assert_equal 1, @comment.reload.points
  end

  test "anonymous users cannot withdraw votes" do
    vote = CommentVote.create!(user: @voter, comment: @comment)

    assert_no_difference("CommentVote.count") do
      delete vote_url
    end

    assert_redirected_to root_url
    assert CommentVote.exists?(vote.id)
    assert_equal 2, @comment.reload.points
  end

  test "cannot vote own comment" do
    sign_in
    @comment = Comment.create!(submission: @submission, user: @voter, body: "Comentari propi")

    assert_no_difference("CommentVote.count") do
      post vote_url
    end

    assert_response :forbidden
    assert_equal 1, @comment.reload.points
  end

  test "cannot add votes to a deleted comment" do
    sign_in
    @comment.soft_delete!

    assert_no_difference("CommentVote.count") do
      post vote_url
    end

    assert_response :forbidden
    assert_equal 1, @comment.reload.points
  end

  test "can withdraw own vote after the comment is deleted" do
    sign_in
    CommentVote.create!(user: @voter, comment: @comment)
    @comment.soft_delete!

    assert_difference("CommentVote.count", -1) do
      delete vote_url
    end

    assert_equal 1, @comment.reload.points
    assert_predicate @comment, :deleted?
    assert_response :see_other
  end

  test "forged parameters cannot withdraw someone else's vote" do
    sign_in
    other_voter = User.create!(username: "another_comment_voter")
    other_vote = CommentVote.create!(user: other_voter, comment: @comment)

    assert_no_difference("CommentVote.count") do
      delete vote_url, params: { user_id: other_voter.id, vote_id: other_vote.id }
    end

    assert CommentVote.exists?(other_vote.id)
    assert_equal 2, @comment.reload.points
  end

  test "withdraws only the session user's vote when another vote exists" do
    sign_in
    other_voter = User.create!(username: "another_comment_voter")
    other_vote = CommentVote.create!(user: other_voter, comment: @comment)
    CommentVote.create!(user: @voter, comment: @comment)

    assert_difference("CommentVote.count", -1) do
      delete vote_url, params: { vote_id: other_vote.id }
    end

    assert CommentVote.exists?(other_vote.id)
    assert_not CommentVote.exists?(user: @voter, comment: @comment)
    assert_equal 2, @comment.reload.points
  end

  test "supports voting replies at any depth" do
    sign_in
    parent = Comment.create!(submission: @submission, user: @voter, body: "Resposta", parent: @comment)
    @comment = Comment.create!(submission: @submission, user: users(:one), body: "Reply to resposta", parent: parent)

    post vote_url

    assert_response :see_other
    assert_equal 2, @comment.reload.points
  end

  test "cannot vote or withdraw through the wrong submission" do
    sign_in
    vote = CommentVote.create!(user: @voter, comment: @comment)
    wrong_url = submission_comment_vote_url(submissions(:two), @comment)

    assert_no_difference("CommentVote.count") do
      post wrong_url
      assert_response :not_found

      delete wrong_url
      assert_response :not_found
    end

    assert CommentVote.exists?(vote.id)
    assert_equal 2, @comment.reload.points
  end

  test "GET does not modify votes" do
    sign_in

    assert_no_difference("CommentVote.count") do
      get vote_url
    end

    assert_response :not_found
    assert_equal 1, @comment.reload.points
  end

  test "requires a CSRF token when protection is enabled" do
    sign_in
    vote = CommentVote.create!(user: @voter, comment: @comment)
    original_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference("CommentVote.count") do
      post vote_url
      assert_response :unprocessable_content

      delete vote_url
      assert_response :unprocessable_content
    end

    assert CommentVote.exists?(vote.id)
    assert_equal 2, @comment.reload.points
  ensure
    ActionController::Base.allow_forgery_protection = original_protection
  end

  private

  def assert_comment_vote_form(label, deleting: false)
    assert_response :success
    assert_select "form[action=?][method=post]", submission_comment_vote_path(@submission, @comment), count: 1 do
      assert_select "button[type=submit][aria-label=?]", label, count: 1
      assert_select "input[name=_method][value=delete]", count: deleting ? 1 : 0
      assert_select "input[name=user_id]", count: 0
    end
  end

  def vote_url
    submission_comment_vote_url(@submission, @comment)
  end

  def sign_in
    get "/auth/github/callback"
  end
end
