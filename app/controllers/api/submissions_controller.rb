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
  end
end
