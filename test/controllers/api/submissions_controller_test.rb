require "test_helper"

class Api::SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @author = users(:two)
    @top = Submission.create!(title: "Rails top", url: "https://api-main.example/top", points: 50, user: @author)
    @ask = Submission.create!(title: "Ask HN: rails tie", points: 30, user: @author, created_at: 2.hours.ago)
    @tie = Submission.create!(title: "Newer tie", url: "https://api-main.example/tie", points: 30, user: @author, created_at: 1.hour.ago)
  end

  test "without API key returns 401" do
    get "/api/submissions"

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.fetch("error")
  end

  test "main page returns URL and Ask submissions by points and then newest" do
    get "/api/submissions", headers: api_headers

    assert_response :success
    assert_equal [ @top.id, @tie.id, @ask.id ], response.parsed_body.first(3).map { |s| s["id"] }
  end

  test "does not include submissions hidden by the API key user" do
    SubmissionHide.create!(user: @user, submission: @top)

    get "/api/submissions", headers: api_headers

    assert_not_includes response.parsed_body.map { |s| s["id"] }, @top.id
  end

  test "search filters titles case insensitively with the same order" do
    get "/api/submissions", params: { q: "RAILS" }, headers: api_headers

    assert_response :success
    assert_equal [ @top.id, @ask.id ], response.parsed_body.map { |s| s["id"] }
  end

  test "blank search returns 400" do
    get "/api/submissions", params: { q: "   " }, headers: api_headers

    assert_response :bad_request
    assert_equal "bad_request", response.parsed_body.fetch("error")
  end

  test "creates URL and Ask submissions for the API key user" do
    post "/api/submissions", params: { title: "A link", url: " https://new.example/page " }.to_json, headers: json_headers

    assert_response :created
    link = response.parsed_body
    assert_equal @user.id, link.dig("author", "id")
    assert_equal "https://new.example/page", link["url"]
    assert_equal "url", link["submission_type"]
    assert_equal [], link["comments"]
    assert_equal "/api/submissions/#{link['id']}", response.headers["Location"]

    post "/api/submissions", params: { title: "Ask HN", text: "Question" }.to_json, headers: json_headers
    assert_response :created
    assert_equal "ask", response.parsed_body["submission_type"]
    assert_nil response.parsed_body["url"]
  end

  test "duplicate URL returns the existing submission reference" do
    post "/api/submissions", params: { title: "Again", url: "  HTTPS://API-MAIN.EXAMPLE/TOP " }.to_json, headers: json_headers

    assert_response :conflict
    assert_equal @top.id, response.parsed_body["existing_submission_id"]
    assert_equal "/api/submissions/#{@top.id}", response.headers["Location"]
  end

  test "invalid fields return validation details" do
    post "/api/submissions", params: { title: "", url: "javascript:bad" }.to_json, headers: json_headers

    assert_response :unprocessable_content
    assert_equal "validation_failed", response.parsed_body["error"]
    assert response.parsed_body.dig("details", "title").present?
    assert response.parsed_body.dig("details", "url").present?
  end

  test "detail contains the complete visible comment tree and user states" do
    root = Comment.create!(submission: @top, user: @author, body: "Root")
    reply = Comment.create!(submission: @top, user: @user, body: "Reply", parent: root)
    leaf = Comment.create!(submission: @top, user: @author, body: "Leaf", parent: reply)
    hidden_root = Comment.create!(submission: @top, user: @author, body: "Deleted")
    hidden_root.soft_delete!
    SubmissionHide.create!(submission: @top, user: @user)
    SubmissionVote.create!(submission: @top, user: @user)

    get "/api/submissions/#{@top.id}", headers: api_headers

    assert_response :success
    detail = response.parsed_body
    assert_equal true, detail["hidden"]
    assert_equal true, detail["voted"]
    assert_equal 3, detail["comments_count"]
    assert_equal [ root.id ], detail["comments"].map { |comment| comment["id"] }
    assert_equal reply.id, detail["comments"][0]["replies"][0]["id"]
    assert_equal leaf.id, detail["comments"][0]["replies"][0]["replies"][0]["id"]
  end

  test "updates only own submissions and can switch between URL and Ask" do
    put "/api/submissions/#{@top.id}", params: { title: "No" }.to_json, headers: json_headers
    assert_response :forbidden

    own = Submission.create!(title: "Mine", url: "https://mine.example", user: @user)
    put "/api/submissions/#{own.id}", params: { title: "My Ask", url: "", text: "Body", points: 99 }.to_json, headers: json_headers

    assert_response :success
    assert_equal "ask", response.parsed_body["submission_type"]
    assert_equal "My Ask", response.parsed_body["title"]
    assert_equal 1, response.parsed_body["points"]
  end

  test "update rejects another submission's URL and keeps the original data" do
    own = Submission.create!(title: "Mine", url: "https://mine.example", user: @user)

    put "/api/submissions/#{own.id}", params: { title: "Changed", url: @top.url }.to_json, headers: json_headers

    assert_response :conflict
    assert_equal @top.id, response.parsed_body["existing_submission_id"]
    assert_equal "Mine", own.reload.title
    assert_equal "https://mine.example", own.url
  end

  test "deletes own submissions with their comments" do
    own = Submission.create!(title: "Mine", user: @user)
    comment = Comment.create!(submission: own, user: @author, body: "Gone")

    delete "/api/submissions/#{@top.id}", headers: api_headers
    assert_response :forbidden

    delete "/api/submissions/#{own.id}", headers: api_headers
    assert_response :no_content
    assert_not Submission.exists?(own.id)
    assert_not Comment.exists?(comment.id)
  end

  test "missing submission returns 404 and mutation requires an API key" do
    get "/api/submissions/0", headers: api_headers
    assert_response :not_found

    post "/api/submissions", params: { title: "No auth" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  private

  def api_headers
    { "X-API-Key" => @user.api_key }
  end

  def json_headers
    api_headers.merge("Content-Type" => "application/json")
  end
end
