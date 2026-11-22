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

      comments = @submission.comments.includes(:user).order(created_at: :asc, id: :asc).to_a
      @comments_by_parent = comments.group_by(&:parent_id)
      @comment_states = CommentUserStates.new(current_user, comments)
      @root_comments = (@comments_by_parent[nil] || []).select { |c| @comment_states.visible?(c, @comments_by_parent) }

      render "api/submissions/show"
    end
  end
end
