require "test_helper"

class Api::CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other = users(:two)
    @submission = submissions(:one)
  end

  test "without API key returns 401" do
    get "/api/comments"
    assert_response :unauthorized

    get "/api/threads"
    assert_response :unauthorized
  end

  test "recent comments follow the Comment schema, newest first" do
    old = Comment.create!(submission: @submission, user: @other, body: "Old", created_at: 1.hour.ago)
    recent = Comment.create!(submission: @submission, user: @other, body: "Recent")
    CommentVote.create!(user: @user, comment: recent)

    get "/api/comments", headers: api_headers

    assert_response :success
    first = response.parsed_body.first
    assert_equal [ recent.id, old.id ], response.parsed_body.first(2).map { |c| c["id"] }
    assert_equal %w[id submission_id parent_id body deleted points created_at author voted favorited].sort, first.keys.sort
    assert_equal({ "id" => @other.id, "username" => @other.username }, first["author"])
    assert_equal true, first["voted"]
  end

  test "deleted comments have null body and author" do
    comment = Comment.create!(submission: @submission, user: @other, body: "Gone")
    comment.soft_delete!

    get "/api/comments", headers: api_headers

    deleted = response.parsed_body.find { |c| c["id"] == comment.id }
    assert_equal [ nil, nil, true ], deleted.values_at("body", "author", "deleted")
  end

  test "threads returns own comments as trees without repeating nested own comments" do
    a = Comment.create!(submission: @submission, user: @user, body: "A")
    b = Comment.create!(submission: @submission, user: @other, body: "B", parent: a)
    c = Comment.create!(submission: @submission, user: @user, body: "C", parent: b)
    Comment.create!(submission: @submission, user: @other, body: "Not mine")

    get "/api/threads", headers: api_headers

    assert_response :success
    assert_equal [ a.id ], response.parsed_body.map { |t| t["id"] }
    tree = response.parsed_body.first
    assert_equal b.id, tree["replies"].first["id"]
    assert_equal c.id, tree["replies"].first["replies"].first["id"]
    assert_equal [], tree["replies"].first["replies"].first["replies"]
  end

  private

  def api_headers
    { "X-API-Key" => @user.api_key }
  end
end
