require "test_helper"

# Només existeix als tests; no afegeix cap endpoint al router de l'aplicació.
module Api
  class AuthenticationProbeController < BaseController
    def show
      render json: { user_id: current_user.id }
    end

    def create
      render json: { user_id: current_user.id }, status: :created
    end

    def missing_record
      User.find(-1)
    end

    def required_parameter
      params.require(:submission)
      head :no_content
    end

    def invalid_record
      User.create!(username: nil)
    end

    def conflict
      raise ActiveRecord::RecordNotUnique, "Internal SQL diagnostic"
    end

    def forbidden
      render_api_error("forbidden", "You can only modify your own content", status: :forbidden)
    end
  end
end

class Api::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: "api-session-user",
      info: { nickname: "api_session_user", email: "session@example.test" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "valid header authenticates its user without a web session" do
    with_api_probe do
      user = users(:one)
      get "/api/authentication_probe", headers: { "X-API-Key" => user.api_key }

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal({ "user_id" => user.id }, response.parsed_body)
      assert_nil session[:user_id]
      assert_not_includes response.body, user.api_key
    end
  end

  test "missing empty and invalid keys return the same JSON 401" do
    with_api_probe do
      [ nil, "", " ", "invalid-test-key" ].each do |key|
        headers = key.nil? ? {} : { "X-API-Key" => key }
        get "/api/authentication_probe", headers: headers

        assert_unauthorized_json
        assert_not_includes response.body, "invalid-test-key"
      end
    end
  end

  test "query and body parameters cannot replace the authentication header" do
    with_api_probe do
      get "/api/authentication_probe", params: { api_key: users(:one).api_key }
      assert_unauthorized_json

      post "/api/authentication_probe", params: { api_key: users(:one).api_key }, as: :json
      assert_unauthorized_json
    end
  end

  test "a web session does not authenticate API requests" do
    with_api_probe do
      sign_in_to_web

      get "/api/authentication_probe"
      assert_unauthorized_json

      get "/api/authentication_probe", headers: { "X-API-Key" => "invalid-test-key" }
      assert_unauthorized_json
    end
  end

  test "the key determines the user even with another user session and forged parameters" do
    with_api_probe do
      web_user = sign_in_to_web
      api_user = users(:two)

      get "/api/authentication_probe", params: { user_id: web_user.id },
        headers: { "X-API-Key" => api_user.api_key }

      assert_response :success
      assert_equal({ "user_id" => api_user.id }, response.parsed_body)
      assert_equal web_user.id, session[:user_id]
    end
  end

  test "the key must be sent on every request" do
    with_api_probe do
      get "/api/authentication_probe", headers: { "X-API-Key" => users(:one).api_key }
      assert_response :success

      get "/api/authentication_probe"
      assert_unauthorized_json
    end
  end

  test "API POST uses the header without a CSRF token while web CSRF remains enabled" do
    original_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    with_api_probe do
      post "/api/authentication_probe", headers: { "X-API-Key" => users(:one).api_key }, as: :json

      assert_response :created
      assert_equal users(:one).id, response.parsed_body.fetch("user_id")
      assert ActionController::Base.allow_forgery_protection
    end
  ensure
    ActionController::Base.allow_forgery_protection = original_protection
  end

  test "missing resources and database conflicts use common errors without internal details" do
    with_api_probe do
      get "/api/authentication_probe/missing_record", headers: api_headers
      assert_response :not_found
      assert_equal({ "error" => "not_found", "message" => "Resource not found" }, response.parsed_body)

      get "/api/authentication_probe/conflict", headers: api_headers
      assert_response :conflict
      assert_equal "conflict", response.parsed_body.fetch("error")
      assert_not_includes response.body, "Internal SQL diagnostic"
    end
  end

  test "missing parameters and malformed JSON return JSON 400" do
    with_api_probe do
      post "/api/authentication_probe/required_parameter", headers: api_headers, as: :json
      assert_response :bad_request
      assert_equal "bad_request", response.parsed_body.fetch("error")

      post "/api/authentication_probe/required_parameter", params: '{"submission":',
        headers: api_headers.merge("CONTENT_TYPE" => "application/json")
      assert_response :bad_request
      assert_equal "application/json", response.media_type
      assert_equal "bad_request", response.parsed_body.fetch("error")
    end
  end

  test "validation errors include messages grouped by field" do
    with_api_probe do
      assert_no_difference "User.count" do
        post "/api/authentication_probe/invalid_record", headers: api_headers, as: :json
      end

      assert_response :unprocessable_content
      assert_equal "validation_failed", response.parsed_body.fetch("error")
      assert_equal [ "can't be blank" ], response.parsed_body.fetch("details").fetch("username")
    end
  end

  test "endpoints can render business errors with the shared helper" do
    with_api_probe do
      get "/api/authentication_probe/forbidden", headers: api_headers

      assert_response :forbidden
      assert_equal({ "error" => "forbidden", "message" => "You can only modify your own content" }, response.parsed_body)
    end
  end

  private

  def api_headers
    { "X-API-Key" => users(:one).api_key }
  end

  def assert_unauthorized_json
    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_equal({ "error" => "unauthorized", "message" => "Missing or invalid API key" }, response.parsed_body)
    assert_nil response.headers["Location"]
  end

  def sign_in_to_web
    get "/auth/github/callback"
    user = User.find_by!(uid: "api-session-user")
    assert_equal user.id, session[:user_id]
    user
  end

  def with_api_probe
    with_routing do |routes|
      routes.draw do
        get "/api/authentication_probe", to: "api/authentication_probe#show"
        post "/api/authentication_probe", to: "api/authentication_probe#create"
        get "/api/authentication_probe/missing_record", to: "api/authentication_probe#missing_record"
        get "/api/authentication_probe/conflict", to: "api/authentication_probe#conflict"
        get "/api/authentication_probe/forbidden", to: "api/authentication_probe#forbidden"
        post "/api/authentication_probe/required_parameter", to: "api/authentication_probe#required_parameter"
        post "/api/authentication_probe/invalid_record", to: "api/authentication_probe#invalid_record"
        get "/auth/github/callback", to: "sessions#create"
        root "submissions#index"
      end
      yield
    end
  end
end
