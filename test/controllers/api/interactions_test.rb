require "test_helper"

class Api::InteractionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @author = users(:two)
    @submission = Submission.create!(title: "Ask about votes", user: @author)
    @comment = @submission.comments.create!(body: "A reply", user: @author)
  end

  {
    submission_vote: [ :submissions, :vote, :submission, "voted", 1 ],
    comment_vote: [ :comments, :vote, :comment, "voted", 1 ],
    submission_hide: [ :submissions, :hide, :submission, "hidden", 0 ]
  }.each do |name, (collection, action, record_name, flag, delta)|
    test "#{name} can be created and removed, and repeated requests return 409" do
      record = instance_variable_get("@#{record_name}")
      path = "/api/#{collection}/#{record.id}/#{action}"
      initial_points = record.points

      post path, headers: api_headers
      assert_response :created
      assert_equal({ "id" => record.id, "points" => initial_points + delta, flag => true }, response.parsed_body)
      assert_equal initial_points + delta, record.reload.points

      post path, headers: api_headers
      assert_api_error :conflict, "conflict"
      assert_equal initial_points + delta, record.reload.points

      delete path, headers: api_headers
      assert_response :no_content
      assert_empty response.body
      assert_equal initial_points, record.reload.points

      delete path, headers: api_headers
      assert_api_error :conflict, "conflict"
      assert_equal initial_points, record.reload.points
    end

    test "#{name} requires an API key and an existing resource for both verbs" do
      record = instance_variable_get("@#{record_name}")
      [ :post, :delete ].each do |verb|
        public_send(verb, "/api/#{collection}/#{record.id}/#{action}")
        assert_api_error :unauthorized, "unauthorized"

        public_send(verb, "/api/#{collection}/-1/#{action}", headers: api_headers)
        assert_api_error :not_found, "not_found"
      end
    end

    test "#{name} cannot be removed by a different user" do
      record = instance_variable_get("@#{record_name}")
      path = "/api/#{collection}/#{record.id}/#{action}"
      other_user = User.create!(username: "other_api_user")

      post path, headers: api_headers
      assert_response :created

      delete path, headers: api_headers(other_user)
      assert_api_error :conflict, "conflict"

      delete path, headers: api_headers
      assert_response :no_content
    end
  end

  test "voting own content or a deleted comment is forbidden" do
    post api_submission_vote_path(@submission), headers: api_headers(@author)
    assert_api_error :forbidden, "forbidden"

    post api_comment_vote_path(@comment), headers: api_headers(@author)
    assert_api_error :forbidden, "forbidden"

    @comment.soft_delete!
    post api_comment_vote_path(@comment), headers: api_headers
    assert_api_error :forbidden, "forbidden"
    assert_empty @comment.comment_votes
    assert_empty @submission.submission_votes
  end

  test "an existing vote can be removed from a deleted comment" do
    CommentVote.create!(user: @user, comment: @comment)
    @comment.soft_delete!

    delete api_comment_vote_path(@comment), headers: api_headers

    assert_response :no_content
    assert_empty @comment.comment_votes
    assert_equal 1, @comment.reload.points
  end

  { submission: :submissions, comment: :comments }.each do |kind, collection|
    test "#{kind} favorites belong to the API key user and cannot be duplicated" do
      record = instance_variable_get("@#{kind}")
      path = "/api/#{collection}/#{record.id}/favorite"
      other_user = User.create!(username: "other_favorite_user")
      favorites = record.public_send("#{kind}_favorites")

      post path, params: { user_id: other_user.id }, headers: api_headers
      assert_response :created
      assert_equal({ "id" => record.id, "favorited" => true }, response.parsed_body)
      assert favorites.exists?(user: @user)
      assert_not favorites.exists?(user: other_user)

      post path, headers: api_headers
      assert_api_error :conflict, "conflict"
      assert_equal 1, favorites.count

      delete path, headers: api_headers(other_user)
      assert_api_error :conflict, "conflict"
      assert favorites.exists?(user: @user)

      delete path, headers: api_headers
      assert_response :no_content
      assert_empty response.body
      assert_empty favorites

      delete path, headers: api_headers
      assert_api_error :conflict, "conflict"
    end

    test "#{kind} favorites require an API key and an existing resource" do
      record = instance_variable_get("@#{kind}")
      [ :post, :delete ].each do |verb|
        public_send(verb, "/api/#{collection}/#{record.id}/favorite")
        assert_api_error :unauthorized, "unauthorized"

        public_send(verb, "/api/#{collection}/-1/favorite", headers: api_headers)
        assert_api_error :not_found, "not_found"
      end
    end
  end

  test "deleted comments cannot gain favorites but existing favorites can be removed" do
    path = api_comment_favorite_path(@comment)
    post path, headers: api_headers
    assert_response :created
    @comment.soft_delete!

    post path, headers: api_headers
    assert_api_error :conflict, "conflict"
    assert_equal 1, @comment.comment_favorites.count

    delete path, headers: api_headers
    assert_response :no_content
    assert_empty @comment.comment_favorites
  end

  test "users can favorite their own content" do
    post api_submission_favorite_path(@submission), headers: api_headers(@author)
    assert_response :created
    post api_comment_favorite_path(@comment), headers: api_headers(@author)
    assert_response :created
  end

  test "hiding changes only the API key user's Ask list" do
    post api_submission_hide_path(@submission), headers: api_headers
    assert_response :created

    get api_ask_path, headers: api_headers
    assert_not_includes response.parsed_body.pluck("id"), @submission.id
    get api_ask_path, headers: api_headers(@author)
    assert_includes response.parsed_body.pluck("id"), @submission.id

    delete api_submission_hide_path(@submission), headers: api_headers
    assert_response :no_content
    get api_ask_path, headers: api_headers
    assert_includes response.parsed_body.pluck("id"), @submission.id
  end

  private

  def api_headers(user = @user)
    { "X-API-Key" => user.api_key }
  end

  def assert_api_error(status, code)
    assert_response status
    assert_equal "application/json", response.media_type
    assert_equal code, response.parsed_body.fetch("error")
    assert response.parsed_body.fetch("message").present?
  end
end
