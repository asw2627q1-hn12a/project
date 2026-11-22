require "test_helper"

class Api::CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @author = users(:two)
    @submission = Submission.create!(title: "Submission for comments", url: "https://comments.example.com", points: 10, user: @author)
    @root_comment = @submission.comments.create!(body: "Root comment text", user: @author, points: 5)
    @reply_comment = @submission.comments.create!(body: "First reply text", parent: @root_comment, user: @user, points: 2)
  end

  # --- Authentication ---

  test "requests without API key return 401 unauthorized" do
    post "/api/submissions/#{@submission.id}/comments", params: { body: "Test" }
    assert_api_error :unauthorized, "unauthorized"

    get "/api/comments/#{@root_comment.id}"
    assert_api_error :unauthorized, "unauthorized"

    put "/api/comments/#{@root_comment.id}", params: { body: "Updated" }
    assert_api_error :unauthorized, "unauthorized"

    delete "/api/comments/#{@root_comment.id}"
    assert_api_error :unauthorized, "unauthorized"

    get "/api/submissions/#{@submission.id}"
    assert_api_error :unauthorized, "unauthorized"
  end

  test "requests with invalid API key return 401 unauthorized" do
    get "/api/comments/#{@root_comment.id}", headers: { "X-API-Key" => "invalid_token" }
    assert_api_error :unauthorized, "unauthorized"
  end

  # --- POST /api/submissions/:submission_id/comments ---

  test "creates a root comment successfully" do
    assert_difference -> { @submission.comments.count }, 1 do
      post "/api/submissions/#{@submission.id}/comments",
           params: { body: "A new root comment" },
           headers: api_headers
    end

    assert_response :created
    assert_equal "application/json", response.media_type
    body = response.parsed_body
    assert_equal "A new root comment", body["body"]
    assert_equal @submission.id, body["submission_id"]
    assert_nil body["parent_id"]
    assert_equal false, body["deleted"]
    assert_equal @user.id, body.dig("author", "id")
    assert_equal @user.username, body.dig("author", "username")
    assert_equal [], body["replies"]
  end

  test "creates a nested reply comment with parent_id" do
    assert_difference -> { @submission.comments.count }, 1 do
      post "/api/submissions/#{@submission.id}/comments",
           params: { body: "A nested reply", parent_id: @root_comment.id },
           headers: api_headers
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "A nested reply", body["body"]
    assert_equal @root_comment.id, body["parent_id"]
    assert_equal @submission.id, body["submission_id"]
  end

  test "accepts nested parameters under comment key" do
    post "/api/submissions/#{@submission.id}/comments",
         params: { comment: { body: "Nested param comment" } },
         headers: api_headers

    assert_response :created
    assert_equal "Nested param comment", response.parsed_body["body"]
  end

  test "create comment returns 404 when submission does not exist" do
    post "/api/submissions/-1/comments",
         params: { body: "Missing submission" },
         headers: api_headers

    assert_api_error :not_found, "not_found"
  end

  test "create comment returns 404 when parent comment belongs to different submission" do
    other_submission = Submission.create!(title: "Other", url: "https://other.example.com", user: @author)
    other_comment = other_submission.comments.create!(body: "Other comment", user: @author)

    post "/api/submissions/#{@submission.id}/comments",
         params: { body: "Cross-submission reply", parent_id: other_comment.id },
         headers: api_headers

    assert_api_error :not_found, "not_found"
  end

  test "create comment returns 422 when body is blank" do
    assert_no_difference -> { Comment.count } do
      post "/api/submissions/#{@submission.id}/comments",
           params: { body: "   " },
           headers: api_headers
    end

    assert_api_error :unprocessable_content, "validation_failed"
    assert response.parsed_body.dig("details", "body").present?
  end

  # --- GET /api/comments/:id ---

  test "gets comment and its recursive replies tree" do
    child_reply = @submission.comments.create!(body: "Second level reply", parent: @reply_comment, user: @author)

    get "/api/comments/#{@root_comment.id}", headers: api_headers

    assert_response :ok
    assert_equal "application/json", response.media_type
    body = response.parsed_body

    assert_equal @root_comment.id, body["id"]
    assert_equal "Root comment text", body["body"]
    assert_equal 1, body["replies"].length

    first_reply = body["replies"].first
    assert_equal @reply_comment.id, first_reply["id"]
    assert_equal "First reply text", first_reply["body"]
    assert_equal 1, first_reply["replies"].length

    second_reply = first_reply["replies"].first
    assert_equal child_reply.id, second_reply["id"]
    assert_equal "Second level reply", second_reply["body"]
    assert_equal 0, second_reply["replies"].length
  end

  test "reflects voted and favorited state for API user" do
    CommentVote.create!(user: @user, comment: @root_comment)
    CommentFavorite.create!(user: @user, comment: @root_comment)

    get "/api/comments/#{@root_comment.id}", headers: api_headers

    assert_response :ok
    body = response.parsed_body
    assert_equal true, body["voted"]
    assert_equal true, body["favorited"]
  end

  test "gets soft-deleted comment directly with deleted true and null author and body" do
    @root_comment.soft_delete!

    get "/api/comments/#{@root_comment.id}", headers: api_headers

    assert_response :ok
    body = response.parsed_body
    assert_equal true, body["deleted"]
    assert_nil body["body"]
    assert_nil body["author"]
    assert_equal 1, body["replies"].length
  end

  test "get comment returns 404 for nonexistent comment" do
    get "/api/comments/-1", headers: api_headers
    assert_api_error :not_found, "not_found"
  end

  # --- PUT/PATCH /api/comments/:id ---

  test "author can edit own comment" do
    put "/api/comments/#{@reply_comment.id}",
        params: { body: "Edited reply text" },
        headers: api_headers

    assert_response :ok
    body = response.parsed_body
    assert_equal "Edited reply text", body["body"]
    assert_equal "Edited reply text", @reply_comment.reload.body
  end

  test "author can edit own comment using PATCH" do
    patch "/api/comments/#{@reply_comment.id}",
          params: { comment: { body: "Patched reply text" } },
          headers: api_headers

    assert_response :ok
    assert_equal "Patched reply text", response.parsed_body["body"]
    assert_equal "Patched reply text", @reply_comment.reload.body
  end

  test "non-author cannot edit comment and receives 403 forbidden" do
    put "/api/comments/#{@root_comment.id}",
        params: { body: "Hacked root text" },
        headers: api_headers

    assert_api_error :forbidden, "forbidden"
    assert_equal "Root comment text", @root_comment.reload.body
  end

  test "editing a deleted comment is forbidden" do
    @reply_comment.soft_delete!

    put "/api/comments/#{@reply_comment.id}",
        params: { body: "Revived text" },
        headers: api_headers

    assert_api_error :forbidden, "forbidden"
  end

  test "edit comment returns 422 when body is blank" do
    put "/api/comments/#{@reply_comment.id}",
        params: { body: "" },
        headers: api_headers

    assert_api_error :unprocessable_content, "validation_failed"
    assert response.parsed_body.dig("details", "body").present?
  end

  test "edit comment returns 404 for nonexistent comment" do
    put "/api/comments/-1",
        params: { body: "Any" },
        headers: api_headers

    assert_api_error :not_found, "not_found"
  end

  # --- DELETE /api/comments/:id ---

  test "author can soft delete own comment returning 204 no content" do
    delete "/api/comments/#{@reply_comment.id}", headers: api_headers

    assert_response :no_content
    assert_empty response.body
    @reply_comment.reload
    assert @reply_comment.deleted?
    assert_empty @reply_comment.body
  end

  test "non-author cannot delete comment and receives 403 forbidden" do
    delete "/api/comments/#{@root_comment.id}", headers: api_headers

    assert_api_error :forbidden, "forbidden"
    assert_not @root_comment.reload.deleted?
  end

  test "deleting an already deleted comment receives 403 forbidden" do
    @reply_comment.soft_delete!

    delete "/api/comments/#{@reply_comment.id}", headers: api_headers

    assert_api_error :forbidden, "forbidden"
  end

  test "delete comment returns 404 for nonexistent comment" do
    delete "/api/comments/-1", headers: api_headers
    assert_api_error :not_found, "not_found"
  end

  # --- GET /api/submissions/:id ---

  test "returns submission detail with full recursive comment tree" do
    get "/api/submissions/#{@submission.id}", headers: api_headers

    assert_response :ok
    assert_equal "application/json", response.media_type
    body = response.parsed_body

    assert_equal @submission.id, body["id"]
    assert_equal @submission.title, body["title"]
    assert_equal 1, body["comments"].length

    root = body["comments"].first
    assert_equal @root_comment.id, root["id"]
    assert_equal "Root comment text", root["body"]
    assert_equal 1, root["replies"].length
    assert_equal @reply_comment.id, root["replies"].first["id"]
  end

  test "deleted comment with visible child is retained in submission tree" do
    @root_comment.soft_delete!

    get "/api/submissions/#{@submission.id}", headers: api_headers

    assert_response :ok
    body = response.parsed_body
    assert_equal 1, body["comments"].length
    root = body["comments"].first
    assert_equal true, root["deleted"]
    assert_nil root["body"]
    assert_nil root["author"]
    assert_equal 1, root["replies"].length
    assert_equal @reply_comment.id, root["replies"].first["id"]
  end

  test "deleted comment with no visible child is excluded from submission tree" do
    @reply_comment.soft_delete!
    @root_comment.soft_delete!

    get "/api/submissions/#{@submission.id}", headers: api_headers

    assert_response :ok
    body = response.parsed_body
    assert_equal 0, body["comments"].length
  end

  test "get submission returns 404 when submission does not exist" do
    get "/api/submissions/-1", headers: api_headers
    assert_api_error :not_found, "not_found"
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
