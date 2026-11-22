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

    # GET /api/submissions/:id
    # Detall de la submission amb el subarbre complet de comentaris (SubmissionDetail).
    def show
      @submission = Submission.with_comments_count.includes(:user).find(params.expect(:id))
      @states = SubmissionUserStates.new(current_user, [ @submission ])

      comments = @submission.comments.includes(:user).to_a
      Comment.preload_replies(comments)
      @comment_states = CommentUserStates.new(current_user, [ @submission.id ])
      @root_comments = comments.select { |c| c.parent_id.nil? && c.visible_in_thread? }.sort_by(&:created_at)

      render "api/submissions/show"
    end
  end
end
