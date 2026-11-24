module Api
  class SubmissionsController < BaseController
    # GET /api/submissions[?q=text]
    # Mateix filtre i ordre que la pàgina principal i la cerca web (SubmissionsController#index i #search).
    def index
      submissions = Submission.visible_to(current_user)

      if params.key?(:q)
        query = params[:q].to_s.strip
        if query.empty?
          return render_api_error("bad_request", "The search text cannot be blank", status: :bad_request)
        end

        submissions = submissions.with_title_containing(query)
      end

      @submissions = submissions.with_comments_count.includes(:user).by_relevance.to_a
      @states = SubmissionUserStates.new(current_user, @submissions)
      render "api/submissions/index"
    end

    def show
      @submission = Submission.with_comments_count.includes(:user).find(params.expect(:id))
      render_detail
    end

    def create
      @submission = current_user.submissions.new(submission_params)
      return if render_duplicate_url

      if @submission.save
        response.set_header("Location", api_submission_path(@submission))
        render_detail(status: :created)
      else
        render_validation_errors
      end
    end

    def update
      @submission = Submission.find(params[:id])
      return unless authorize_owner

      @submission.assign_attributes(submission_params)
      return if render_duplicate_url

      if @submission.save
        render_detail
      else
        render_validation_errors
      end
    end

    def destroy
      @submission = Submission.find(params[:id])
      return unless authorize_owner

      @submission.destroy!
      head :no_content
    end

    private

    def submission_params
      params.permit(:title, :url, :text)
    end

    def authorize_owner
      return true if @submission.user_id == current_user.id

      render_api_error("forbidden", "You can only modify your own content", status: :forbidden)
      false
    end

    def render_duplicate_url
      return false if @submission.url.blank?

      existing = Submission.where("LOWER(url) = ?", @submission.url.strip.downcase)
                           .where.not(id: @submission.id).first
      return false unless existing

      response.set_header("Location", api_submission_path(existing))
      render json: {
        error: "conflict", message: "This URL has already been submitted",
        existing_submission_id: existing.id
      }, status: :conflict
      true
    end

    def render_validation_errors
      render_api_error("validation_failed", "Validation failed", status: :unprocessable_content,
        details: @submission.errors.to_hash)
    end

    def render_detail(status: :ok)
      @submission = Submission.with_comments_count.includes(:user).find(@submission.id) unless @submission.has_attribute?(:comments_count)
      @states = SubmissionUserStates.new(current_user, [ @submission ])
      comments = @submission.comments.includes(:user).to_a
      Comment.preload_replies(comments)
      @comment_states = CommentUserStates.new(current_user, [ @submission.id ])
      @root_comments = comments.select { |comment| comment.parent_id.nil? && comment.visible_in_thread? }
                               .sort_by(&:created_at)
      render "api/submissions/show", status: status
    end
  end
end
