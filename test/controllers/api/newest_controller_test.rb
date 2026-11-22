require "test_helper"

class Api::NewestControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @author = users(:two)
    # Submission més antiga però amb més punts
    @old_top = Submission.create!(title: "Old high points", url: "https://newest.example/old", points: 100, user: @author, created_at: 3.hours.ago)
    # Submissions de la mateixa hora per provar desempat per id desc
    @mid_a = Submission.create!(title: "Mid A", points: 10, user: @author, created_at: 2.hours.ago)
    @mid_b = Submission.create!(title: "Mid B", url: "https://newest.example/mid-b", points: 5, user: @author, created_at: 2.hours.ago)
    # Submission més recent
    @newest = Submission.create!(title: "Newest submission", url: "https://newest.example/new", points: 1, user: @author, created_at: 10.minutes.ago)
  end

  test "without API key returns 401" do
    get "/api/newest"

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.fetch("error")
  end

  test "with invalid API key returns 401" do
    get "/api/newest", headers: { "X-API-Key" => "invalid_key" }

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.fetch("error")
  end

  test "returns submissions ordered by newest created_at and id descending on ties" do
    get "/api/newest", headers: api_headers

    assert_response :success
    assert_equal "application/json", response.media_type
    ids = response.parsed_body.map { |s| s["id"] }
    expected_order = [ @newest.id, [ @mid_a.id, @mid_b.id ].max, [ @mid_a.id, @mid_b.id ].min, @old_top.id ]
    assert_equal expected_order, ids.first(4)
  end

  test "includes both url and ask submissions" do
    get "/api/newest", headers: api_headers

    assert_response :success
    types = response.parsed_body.map { |s| s["submission_type"] }
    assert_includes types, "url"
    assert_includes types, "ask"
  end

  test "does not include submissions hidden by the API key user" do
    SubmissionHide.create!(user: @user, submission: @newest)

    get "/api/newest", headers: api_headers

    assert_response :success
    ids = response.parsed_body.map { |s| s["id"] }
    assert_not_includes ids, @newest.id
    assert_includes ids, @old_top.id
  end

  test "follows the Submission schema with user states" do
    SubmissionVote.create!(user: @user, submission: @newest)
    SubmissionFavorite.create!(user: @user, submission: @newest)
    Comment.create!(submission: @newest, user: @author, body: "Comment on newest")

    get "/api/newest", headers: api_headers

    assert_response :success
    first = response.parsed_body.find { |s| s["id"] == @newest.id }
    assert_equal %w[id title url text submission_type domain points comments_count created_at author voted hidden favorited].sort,
      first.keys.sort
    assert_equal @newest.title, first["title"]
    assert_equal @newest.url, first["url"]
    assert_equal "newest.example", first["domain"]
    assert_nil first["text"]
    assert_equal "url", first["submission_type"]
    assert_equal 2, first["points"]
    assert_equal 1, first["comments_count"]
    assert_equal({ "id" => @author.id, "username" => @author.username }, first["author"])
    assert_equal true, first["voted"]
    assert_equal false, first["hidden"]
    assert_equal true, first["favorited"]
  end

  test "returns empty array when there are no visible submissions" do
    Submission.destroy_all

    get "/api/newest", headers: api_headers

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "allows Swagger Editor to send the API key header" do
    options "/api/newest", headers: {
      "Origin" => "https://editor.swagger.io",
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "x-api-key"
    }

    assert_response :ok
    assert_equal "https://editor.swagger.io", response.headers["Access-Control-Allow-Origin"]
    allowed_headers = response.headers.fetch("Access-Control-Allow-Headers").downcase.split(",").map(&:strip)
    assert_includes allowed_headers, "x-api-key"
  end

  private

  def api_headers
    { "X-API-Key" => @user.api_key }
  end
end
