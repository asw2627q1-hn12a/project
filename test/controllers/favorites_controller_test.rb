require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    @other_user = users(:one)
    @submission = submissions(:one)
    @comment = @submission.comments.create!(user: @other_user, body: "A favorite comment")
    @user.update!(provider: "github", uid: "favorites-test-user")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: @user.uid, info: { nickname: @user.username }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  [ "submission", "comment" ].each do |kind|
    test "#{kind} favorites use session ownership and repeated requests are idempotent" do
      sign_in
      target, favorites, path = favorite_details(kind)
      original_attributes = target.attributes
      other_favorite = favorites.create!(user: @other_user)

      assert_difference "#{favorites.klass}.count", 1 do
        2.times do
          post path, params: { user_id: @other_user.id }, headers: { "HTTP_REFERER" => newest_url }
          assert_redirected_to newest_url
          assert_response :see_other
        end
      end
      assert favorites.exists?(user: @user)
      assert_equal original_attributes, target.reload.attributes

      assert_difference "#{favorites.klass}.count", -1 do
        2.times { delete path, params: { user_id: @other_user.id, id: other_favorite.id } }
      end
      assert favorites.exists?(other_favorite.id)
      assert_not favorites.exists?(user: @user)
    end

    test "anonymous users cannot modify #{kind} favorites" do
      _target, favorites, path = favorite_details(kind)
      favorite = favorites.create!(user: @user)
      assert_no_difference "#{favorites.klass}.count" do
        post path
        assert_redirected_to root_url
        delete path
        assert_redirected_to root_url
      end
      assert favorites.exists?(favorite.id)
    end

    test "#{kind} favorite state persists in all relevant views and is private to the session" do
      target, favorites, path = favorite_details(kind)
      views = kind == "submission" ? [ submission_url(@submission) ] :
        [ comments_url, submission_url(@submission), submission_comment_url(@submission, @comment) ]
      views.each do |url|
        get url
        assert_select "form.favorite-form", count: 0
      end
      sign_in
      if kind == "submission"
        get news_url
        assert_select "form.favorite-form", count: 0
      end
      views.each do |url|
        get url
        assert_select "form[action=?] button[aria-pressed=false]", path
      end
      post path
      views.each do |url|
        get url
        assert_select "form[action=?]", path do
          assert_select "input[name=_method][value=delete]"
          assert_select "button[aria-pressed=true]"
        end
      end
      delete path
      get views.first
      assert_select "form[action=?] button[aria-pressed=false]", path
      favorites.create!(user: @other_user)
      get views.first
      assert_select "form[action=?] button[aria-pressed=false]", path
    end

    test "#{kind} favorites reject GET mutation and unsafe return hosts" do
      sign_in
      target, favorites, path = favorite_details(kind)
      assert_no_difference "#{favorites.klass}.count" do
        get path
        assert_response :not_found
      end
      fallback = kind == "submission" ? submission_url(target) : submission_comment_url(@submission, target)
      post path, headers: { "HTTP_REFERER" => "https://attacker.example/" }
      assert_redirected_to fallback
      delete path, headers: { "HTTP_REFERER" => "https://attacker.example/" }
      assert_redirected_to fallback
    end

    test "#{kind} favorites require a CSRF token when protection is enabled" do
      sign_in
      _target, favorites, path = favorite_details(kind)
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      assert_no_difference "#{favorites.klass}.count" do
        post path
        assert_response :unprocessable_content
        delete path
        assert_response :unprocessable_content
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end
  end

  test "comments must belong to the submission in the URL" do
    sign_in
    post submission_comment_favorite_url(submissions(:two), @comment)
    assert_response :not_found
    delete submission_comment_favorite_url(submissions(:two), @comment)
    assert_response :not_found
  end

  test "deleted comments cannot be favorited but existing favorites can be removed" do
    sign_in
    path = submission_comment_favorite_path(@submission, @comment)
    post path
    @comment.soft_delete!
    assert_no_difference "CommentFavorite.count" do
      post path
      assert_response :gone
    end
    get submission_url(@submission)
    assert_select "form[action=?]", path do
      assert_select "input[name=_method][value=delete]"
      assert_select "button[aria-label=favorite][aria-pressed=true]"
    end
    assert_difference "CommentFavorite.count", -1 do
      delete path
    end
    @comment.comment_favorites.create!(user: @other_user)
    [ submission_url(@submission), submission_comment_url(@submission, @comment), comments_url ].each do |url|
      get url
      assert_select "form[action=?]", path, count: 0
    end
  end

  test "missing targets return not found" do
    sign_in
    post submission_favorite_url(Submission.maximum(:id) + 1)
    assert_response :not_found
    post submission_comment_favorite_url(@submission, Comment.maximum(:id) + 1)
    assert_response :not_found
  end

  test "users can favorite their own submissions and comments" do
    sign_in
    own_comment = @submission.comments.create!(user: @user, body: "My own comment")
    post submission_favorite_url(submissions(:two))
    post submission_comment_favorite_url(@submission, own_comment)
    assert @user.favorite_submissions.exists?(submissions(:two).id)
    assert @user.favorite_comments.exists?(own_comment.id)
  end

  private

  def sign_in
    get "/auth/github/callback"
  end

  def favorite_details(kind)
    if kind == "submission"
      [ @submission, @submission.submission_favorites, submission_favorite_path(@submission) ]
    else
      [ @comment, @comment.comment_favorites, submission_comment_favorite_path(@submission, @comment) ]
    end
  end
end
