module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_user

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, ActionDispatch::Http::Parameters::ParseError, with: :render_bad_request
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed
    rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict

    private

    attr_reader :current_user

    def authenticate_api_user
      api_key = request.headers["X-API-Key"]
      @current_user = User.find_by(api_key: api_key) if api_key.present?
      return if current_user

      render_api_error("unauthorized", "Missing or invalid API key", status: :unauthorized)
    end

    # Els endpoints també poden reutilitzar-lo per a errors de negoci (p. ex. 403).
    def render_api_error(code, message, status:, details: nil)
      body = { error: code, message: message }
      body[:details] = details if details
      render json: body, status: status
    end

    def render_not_found
      render_api_error("not_found", "Resource not found", status: :not_found)
    end

    def render_bad_request
      render_api_error("bad_request", "Missing or invalid parameter or JSON body", status: :bad_request)
    end

    def render_validation_failed(error)
      render_api_error("validation_failed", "Validation failed", status: :unprocessable_content,
        details: error.record.errors.to_hash)
    end

    def render_conflict
      render_api_error("conflict", "Request conflicts with the current state", status: :conflict)
    end
  end
end
