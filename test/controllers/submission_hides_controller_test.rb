require "test_helper"

class SubmissionHidesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    @submission = submissions(:one)
    @user.update!(provider: "github", uid: "hide-controller-user")
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

  test "hide uses the session and returns to the originating list" do
    sign_in
    original_attributes = @submission.attributes

    assert_difference "SubmissionHide.count", 1 do
      post submission_hide_url(@submission), params: { user_id: users(:one).id },
        headers: { "HTTP_REFERER" => newest_url }
    end

    assert_response :see_other
    assert_redirected_to newest_url
    assert @user.submission_hides.exists?(submission: @submission)
    assert_not users(:one).submission_hides.exists?(submission: @submission)
    assert_equal original_attributes, @submission.reload.attributes
  end

  test "repeated hide and unhide are idempotent" do
    sign_in
    post submission_hide_url(@submission)
    assert_no_difference "SubmissionHide.count" do
      post submission_hide_url(@submission)
    end

    assert_difference "SubmissionHide.count", -1 do
      delete submission_hide_url(@submission), headers: { "HTTP_REFERER" => hidden_submissions_url }
    end
    assert_redirected_to hidden_submissions_url
    assert_no_difference "SubmissionHide.count" do
      delete submission_hide_url(@submission)
    end
    assert_redirected_to root_url
    assert_equal 1, @submission.reload.points
  end

  test "unhide only removes the logged in users relation" do
    other_hide = users(:one).submission_hides.create!(submission: @submission)
    sign_in

    assert_no_difference "SubmissionHide.count" do
      delete submission_hide_url(@submission), params: { user_id: users(:one).id, id: other_hide.id }
    end
    assert SubmissionHide.exists?(other_hide.id)

    @user.submission_hides.create!(submission: @submission)
    assert_difference "SubmissionHide.count", -1 do
      delete submission_hide_url(@submission), params: { user_id: users(:one).id, id: other_hide.id }
    end
    assert SubmissionHide.exists?(other_hide.id)
  end

  test "anonymous users cannot hide unhide or read the private list" do
    hide = @user.submission_hides.create!(submission: @submission)

    assert_no_difference "SubmissionHide.count" do
      post submission_hide_url(submissions(:two))
      assert_redirected_to root_url
      delete submission_hide_url(@submission)
      assert_redirected_to root_url
    end
    assert SubmissionHide.exists?(hide.id)
    get hidden_submissions_url
    assert_redirected_to root_url
  end

  test "all normal submission lists exclude the users hidden URL and Ask submissions" do
    ask = Submission.create!(title: "MyString Ask", user: users(:one))
    sign_in
    post submission_hide_url(@submission)
    post submission_hide_url(ask)

    [ root_url, news_url, submissions_url, newest_url, search_url(q: "MyString"), ask_url ].each do |url|
      get url
      assert_response :success
      assert_select "tr#submission_#{@submission.id}", count: 0
      assert_select "tr#submission_#{ask.id}", count: 0
    end

    get newest_url
    assert_select "tr#submission_#{submissions(:two).id}", count: 1
    delete submission_hide_url(@submission)
    get news_url
    assert_select "tr#submission_#{@submission.id}", count: 1
  end

  test "other accounts and anonymous visitors can still see the hidden submission" do
    @user.submission_hides.create!(submission: @submission)
    get news_url
    assert_select "tr#submission_#{@submission.id}", count: 1

    users(:one).update!(provider: "github", uid: "other-hide-user")
    OmniAuth.config.mock_auth[:github].uid = "other-hide-user"
    sign_in
    get news_url
    assert_select "tr#submission_#{@submission.id}", count: 1
  end

  test "private list contains only own hidden submissions even with a forged user parameter" do
    @user.submission_hides.create!(submission: @submission)
    users(:one).submission_hides.create!(submission: submissions(:two))
    sign_in

    get hidden_submissions_url, params: { user_id: users(:one).id }
    assert_response :success
    assert_select "tr#submission_#{@submission.id}", count: 1
    assert_select "tr#submission_#{submissions(:two).id}", count: 0
  end

  test "private list has an empty state and orders hidden submissions by relevance" do
    sign_in
    get hidden_submissions_url
    assert_select "p[role=status]", text: "No hidden submissions."
    assert_select "a[href=?]", user_path(@user), text: "back to #{@user.username}"

    top = Submission.create!(title: "Top hidden", user: users(:one), points: 20)
    [ @submission, top ].each { |submission| @user.submission_hides.create!(submission: submission) }
    get hidden_submissions_url
    assert_select "tr.athing" do |rows|
      assert_equal [ top, @submission ].map { |submission| "submission_#{submission.id}" }, rows.map { |row| row["id"] }
    end
  end

  test "hidden submissions remain accessible by their direct URL" do
    @user.submission_hides.create!(submission: @submission)
    sign_in

    get submission_url(@submission)
    assert_response :success
    assert_select "#submission_#{@submission.id}"
  end

  test "hidden list preserves vote state and allows voting and withdrawing without unhiding" do
    sign_in
    post submission_hide_url(@submission)
    get hidden_submissions_url
    assert_select "tr#submission_#{@submission.id} button[aria-label=vote]"

    post submission_vote_url(@submission), headers: { "HTTP_REFERER" => hidden_submissions_url }
    assert_redirected_to hidden_submissions_url
    follow_redirect!
    assert_select "tr#submission_#{@submission.id} + tr .score", text: "2 points"
    assert_select "form[action=?] button", submission_vote_path(@submission), text: "unvote"
    assert_select "form[action=?] button", submission_hide_path(@submission), text: "unhide"
    assert @user.submission_hides.exists?(submission: @submission)

    get hidden_submissions_url
    assert_select "form[action=?] input[name=_method][value=delete]", submission_vote_path(@submission)
    delete submission_vote_url(@submission), headers: { "HTTP_REFERER" => hidden_submissions_url }
    assert_redirected_to hidden_submissions_url
    follow_redirect!
    assert_select "tr#submission_#{@submission.id} + tr .score", text: "1 points"
    assert_select "tr#submission_#{@submission.id} button[aria-label=vote]"
    assert @user.submission_hides.exists?(submission: @submission)
  end

  test "hide and unhide preserve existing submission and comment votes" do
    comment = @submission.comments.create!(user: users(:one), body: "Keep my vote")
    SubmissionVote.create!(user: @user, submission: @submission)
    CommentVote.create!(user: @user, comment: comment)
    sign_in

    assert_no_difference [ "SubmissionVote.count", "CommentVote.count", "Comment.count" ] do
      post submission_hide_url(@submission)
      get submission_url(@submission)
      assert_response :success
      assert_select "#submission_#{@submission.id} .score", text: "2 points"
      assert_select "#comment_#{comment.id} .comment-score", text: "2 points"
      delete submission_hide_url(@submission)
    end
    get news_url
    assert_select "form[action=?] button", submission_vote_path(@submission), text: "unvote"
    assert_equal 2, @submission.reload.points
    assert_equal 2, comment.reload.points
  end

  test "forms show persisted hide state and use POST and DELETE" do
    get news_url
    assert_select "form.submission-hide-form", count: 0
    sign_in
    get news_url
    assert_select "form[action=?][method=post]", submission_hide_path(@submission) do
      assert_select "button", text: "hide"
      assert_select "input[name=_method]", count: 0
    end

    post submission_hide_url(@submission)
    [ submission_url(@submission), hidden_submissions_url ].each do |url|
      get url
      assert_select "form[action=?][method=post]", submission_hide_path(@submission) do
        assert_select "input[name=_method][value=delete]"
        assert_select "button", text: "unhide"
      end
    end
    delete submission_hide_url(@submission)
    get submission_url(@submission)
    assert_select "form[action=?] button", submission_hide_path(@submission), text: "hide"
  end

  test "hidden list is linked only from the logged in users own profile" do
    get user_url(@user)
    assert_select "a[href=?]", hidden_submissions_path, count: 0
    sign_in
    get user_url(users(:one))
    assert_select "a[href=?]", hidden_submissions_path, count: 0
    get user_url(@user)
    assert_select "a[href=?]", hidden_submissions_path, text: "hidden"
    assert_select "header a.hn-user[href=?]", user_path(@user)
  end

  test "hidden own submission can also be unhidden from the edit page" do
    sign_in
    submission = submissions(:two)
    @user.submission_hides.create!(submission: submission)

    get edit_submission_url(submission)
    assert_response :success
    assert_select "form[action=?]", submission_hide_path(submission) do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", text: "unhide"
    end
  end

  test "authors can hide their own submissions without deleting them" do
    sign_in
    own_submission = submissions(:two)

    assert_no_difference [ "Submission.count", "Comment.count" ] do
      post submission_hide_url(own_submission)
    end
    assert @user.submission_hides.exists?(submission: own_submission)
  end

  test "missing submissions return not found" do
    sign_in
    assert_no_difference "SubmissionHide.count" do
      post submission_hide_url(Submission.maximum(:id) + 1)
      assert_response :not_found
      delete submission_hide_url(Submission.maximum(:id) + 1)
      assert_response :not_found
    end
  end

  test "GET cannot modify hidden state" do
    sign_in
    assert_no_difference "SubmissionHide.count" do
      get submission_hide_url(@submission)
      assert_response :not_found
    end
  end

  test "external return locations fall back to the home page" do
    sign_in
    post submission_hide_url(@submission), headers: { "HTTP_REFERER" => "https://attacker.example/" }
    assert_redirected_to root_url
    delete submission_hide_url(@submission), headers: { "HTTP_REFERER" => "https://attacker.example/" }
    assert_redirected_to root_url
  end

  test "CSRF protection rejects hide and unhide without a token when enabled" do
    sign_in
    @user.submission_hides.create!(submission: @submission)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference "SubmissionHide.count" do
      post submission_hide_url(submissions(:two))
      assert_response :unprocessable_content
      delete submission_hide_url(@submission)
      assert_response :unprocessable_content
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "server rendered form tokens allow hide and unhide with CSRF protection enabled" do
    sign_in
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get news_url
    token = css_select("form[action='#{submission_hide_path(@submission)}'] input[name=authenticity_token]").first["value"]
    assert_difference "SubmissionHide.count", 1 do
      post submission_hide_url(@submission), params: { authenticity_token: token }
    end
    assert_response :see_other

    get hidden_submissions_url
    token = css_select("form[action='#{submission_hide_path(@submission)}'] input[name=authenticity_token]").first["value"]
    assert_difference "SubmissionHide.count", -1 do
      delete submission_hide_url(@submission), params: { authenticity_token: token }
    end
    assert_response :see_other
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "private list shows the comment count of hidden submissions" do
    sign_in
    post submission_hide_url(@submission)
    2.times { |i| Comment.create!(submission: @submission, user: users(:one), body: "Comentari #{i}") }

    get hidden_submissions_url

    assert_response :success
    assert_select "tr#submission_#{@submission.id}"
    assert_select "a[href=?]", submission_path(@submission, anchor: "comments"), text: "2 comments"
  end

  private

  def sign_in
    get "/auth/github/callback"
  end
end
