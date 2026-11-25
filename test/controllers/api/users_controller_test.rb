require "test_helper"

class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  USER_KEYS = %w[id username created_at karma about avatar_url banner_url].freeze
  COMMENT_KEYS = %w[id submission_id parent_id body deleted points created_at author voted favorited].freeze

  setup do
    @user = users(:one)
    @author = User.create!(username: "api_author", email: "author@example.com", about: "Hello")
    @post = Submission.create!(title: "Author post", user: @author, points: 4)
  end

  test "without API key returns 401" do
    get "/api/users/#{@author.id}"
    assert_response :unauthorized

    get "/api/users/#{@author.id}/submissions"
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.fetch("error")
  end

  test "unknown user returns 404" do
    get "/api/users/0", headers: api_headers

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.fetch("error")
  end

  test "profile of another user follows the User schema without email" do
    Comment.create!(submission: @post, user: @author, body: "Mine", points: 2)

    get "/api/users/#{@author.id}", headers: api_headers

    assert_response :success
    body = response.parsed_body
    assert_equal USER_KEYS.sort, body.keys.sort
    assert_equal [ @author.id, "api_author", "Hello", 6 ], body.values_at("id", "username", "about", "karma")
    assert_match %r{\Ahttp://www\.example\.com/assets/default-avatar.*\.svg\z}, body["avatar_url"]
    assert_match %r{\Ahttp://www\.example\.com/assets/default-banner.*\.svg\z}, body["banner_url"]
  end

  test "own profile includes the email and the uploaded avatar" do
    @user.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")

    get "/api/users/#{@user.id}", headers: api_headers

    assert_equal "one@example.com", response.parsed_body["email"]
    assert_match %r{\Ahttp://www\.example\.com/rails/active_storage/blobs/redirect/.+/avatar\.png\z},
      response.parsed_body["avatar_url"]
  end

  test "owner can update about and email but not username" do
    patch "/api/users/#{@user.id}", headers: api_headers,
      params: { about: "New about", email: "new@example.com", username: "hacked" }, as: :json

    assert_response :success
    assert_equal [ "New about", "new@example.com", "user_one" ],
      response.parsed_body.values_at("about", "email", "username")
    @user.reload
    assert_equal [ "New about", "new@example.com", "user_one" ], [ @user.about, @user.email, @user.username ]
  end

  test "updating another user returns 403" do
    patch "/api/users/#{@author.id}", headers: api_headers, params: { about: "Not mine" }, as: :json

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body.fetch("error")
    assert_equal "Hello", @author.reload.about
  end

  test "too long about returns 422 with the field errors" do
    patch "/api/users/#{@user.id}", headers: api_headers, params: { about: "a" * 2001 }, as: :json

    assert_response :unprocessable_content
    assert_equal "validation_failed", response.parsed_body.fetch("error")
    assert response.parsed_body.dig("details", "about").present?
    assert_nil @user.reload.about
  end

  test "invalid email returns 422 with the field errors" do
    patch "/api/users/#{@user.id}", headers: api_headers, params: { email: "not-an-email" }, as: :json

    assert_response :unprocessable_content
    assert response.parsed_body.dig("details", "email").present?
    assert_equal "one@example.com", @user.reload.email
  end

  test "empty body, malformed JSON or only username returns 400" do
    patch "/api/users/#{@user.id}", headers: api_headers, params: {}, as: :json
    assert_response :bad_request

    patch "/api/users/#{@user.id}", headers: api_headers.merge("Content-Type" => "application/json"), params: "{not json"
    assert_response :bad_request

    patch "/api/users/#{@user.id}", headers: api_headers, params: { username: "hacked" }, as: :json
    assert_response :bad_request
    assert_equal "bad_request", response.parsed_body.fetch("error")
    assert_equal "user_one", @user.reload.username
  end

  test "submissions are public, newest first, without the ones hidden by the API key user" do
    older = Submission.create!(title: "Older", user: @author, created_at: 2.days.ago)
    hidden = Submission.create!(title: "Hidden by me", user: @author, created_at: 1.day.ago)
    SubmissionHide.create!(user: @user, submission: hidden)

    get "/api/users/#{@author.id}/submissions", headers: api_headers

    assert_response :success
    assert_equal [ @post.id, older.id ], ids
  end

  test "comments are public, newest first, without deleted ones, and follow the Comment schema" do
    old = Comment.create!(submission: @post, user: @author, body: "Old", created_at: 1.day.ago)
    reply = Comment.create!(submission: @post, user: @author, body: "Reply", parent: old)
    Comment.create!(submission: @post, user: @author, body: "Gone").soft_delete!
    CommentVote.create!(user: @user, comment: reply)
    CommentFavorite.create!(user: @user, comment: old)

    get "/api/users/#{@author.id}/comments", headers: api_headers

    assert_response :success
    assert_equal [ reply.id, old.id ], ids
    first = response.parsed_body.first
    assert_equal COMMENT_KEYS.sort, first.keys.sort
    assert_equal [ @post.id, old.id, "Reply", false, 2 ], first.values_at("submission_id", "parent_id", "body", "deleted", "points")
    assert_equal({ "id" => @author.id, "username" => "api_author" }, first["author"])
    assert_equal [ true, false ], first.values_at("voted", "favorited")
    assert_equal [ false, true ], response.parsed_body.last.values_at("voted", "favorited")
  end

  test "favorites are public, the most recently marked first" do
    first_marked = Submission.create!(title: "Marked first", user: @user)
    SubmissionFavorite.create!(user: @author, submission: first_marked, created_at: 1.day.ago)
    SubmissionFavorite.create!(user: @author, submission: @post)
    comment_marked_first = Comment.create!(submission: @post, user: @user, body: "Marked first")
    comment_marked_last = Comment.create!(submission: @post, user: @user, body: "Marked last")
    CommentFavorite.create!(user: @author, comment: comment_marked_first, created_at: 1.day.ago)
    CommentFavorite.create!(user: @author, comment: comment_marked_last)

    get "/api/users/#{@author.id}/favorites", headers: api_headers
    assert_response :success
    assert_equal [ @post.id, first_marked.id ], ids

    get "/api/users/#{@author.id}/favorite_comments", headers: api_headers
    assert_response :success
    assert_equal [ comment_marked_last.id, comment_marked_first.id ], ids
  end

  test "owner sees upvoted submissions, upvoted comments and hidden" do
    top = Submission.create!(title: "Top", user: @author, points: 10)
    comment = Comment.create!(submission: @post, user: @author, body: "Liked")
    SubmissionVote.create!(user: @user, submission: @post)
    SubmissionVote.create!(user: @user, submission: top)
    SubmissionHide.create!(user: @user, submission: @post)
    CommentVote.create!(user: @user, comment: comment)

    get "/api/users/#{@user.id}/upvoted", headers: api_headers
    assert_response :success
    assert_equal [ top.id, @post.id ], ids
    assert_equal [ true, true ], response.parsed_body.last.values_at("voted", "hidden")

    get "/api/users/#{@user.id}/upvoted_comments", headers: api_headers
    assert_response :success
    assert_equal [ comment.id ], ids

    get "/api/users/#{@user.id}/hidden", headers: api_headers
    assert_response :success
    assert_equal [ @post.id ], ids
  end

  test "upvoted and hidden lists of another user return 403" do
    %w[upvoted upvoted_comments hidden].each do |list|
      get "/api/users/#{@author.id}/#{list}", headers: api_headers

      assert_response :forbidden, list
      assert_equal "forbidden", response.parsed_body.fetch("error")
    end
  end

  private

  def api_headers
    { "X-API-Key" => @user.api_key }
  end

  def ids
    response.parsed_body.map { |item| item["id"] }
  end
end
