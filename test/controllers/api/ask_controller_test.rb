require "test_helper"

class Api::AskControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @author = users(:two)
    @low = Submission.create!(title: "Ask low", text: "Low", points: 2, user: @author, created_at: 1.hour.ago)
    @old_tie = Submission.create!(title: "Ask old tie", points: 5, user: @author, created_at: 3.hours.ago)
    @new_tie = Submission.create!(title: "Ask new tie", points: 5, user: @author, created_at: 2.hours.ago)
  end

  test "does not allow requests from an unapproved origin" do
    options "/api/ask", headers: {
      "Origin" => "https://evil.example",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "x-api-key"
    }

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "allows Swagger Editor to send the API key header" do
    options "/api/ask", headers: {
      "Origin" => "https://editor.swagger.io",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "x-api-key"
    }

    assert_response :ok
    assert_equal "https://editor.swagger.io", response.headers["Access-Control-Allow-Origin"]
    allowed_headers = response.headers.fetch("Access-Control-Allow-Headers").downcase.split(",").map(&:strip)
    assert_includes allowed_headers, "x-api-key"
  end

  test "without API key returns 401 with CORS headers for Swagger Editor" do
    get "/api/ask", headers: { "Origin" => "https://editor.swagger.io" }

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.fetch("error")
    assert_equal "https://editor.swagger.io", response.headers["Access-Control-Allow-Origin"]
  end

  test "returns only ask submissions ordered by points and then newest" do
    get "/api/ask", headers: api_headers

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal [ @new_tie.id, @old_tie.id, @low.id ], response.parsed_body.map { |s| s["id"] }
    assert response.parsed_body.all? { |s| s["submission_type"] == "ask" }
  end

  test "does not include submissions hidden by the API key user" do
    SubmissionHide.create!(user: @user, submission: @low)
    SubmissionHide.create!(user: @author, submission: @old_tie)

    get "/api/ask", headers: api_headers

    ids = response.parsed_body.map { |s| s["id"] }
    assert_not_includes ids, @low.id
    assert_includes ids, @old_tie.id
  end

  test "follows the Submission schema with the state of the API key user" do
    SubmissionVote.create!(user: @user, submission: @low)
    SubmissionFavorite.create!(user: @user, submission: @new_tie)
    Comment.create!(submission: @low, user: @user, body: "Hi")

    get "/api/ask", headers: api_headers

    by_id = response.parsed_body.index_by { |s| s["id"] }
    low = by_id.fetch(@low.id)
    assert_equal %w[id title url text submission_type domain points comments_count created_at author voted hidden favorited].sort,
      low.keys.sort
    assert_equal({ "id" => @author.id, "username" => @author.username }, low["author"])
    assert_nil low["url"]
    assert_nil low["domain"]
    assert_equal "Low", low["text"]
    assert_equal 3, low["points"]
    assert_equal 1, low["comments_count"]
    assert_equal [ true, false, false ], low.values_at("voted", "hidden", "favorited")
    assert_equal [ false, false, true ], by_id.fetch(@new_tie.id).values_at("voted", "hidden", "favorited")
    assert_equal [ false, false, false ], by_id.fetch(@old_tie.id).values_at("voted", "hidden", "favorited")
  end

  private

  def api_headers
    { "X-API-Key" => @user.api_key }
  end
end
