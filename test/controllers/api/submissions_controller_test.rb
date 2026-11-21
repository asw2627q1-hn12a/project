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

  private

  def api_headers
    { "X-API-Key" => @user.api_key }
  end
end
