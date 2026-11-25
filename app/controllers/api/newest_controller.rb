module Api
  class NewestController < BaseController
    # GET /api/newest
    # Mateix filtre i ordre que la pàgina web /newest (SubmissionsController#newest).
    def index
      @submissions = Submission.visible_to(current_user)
        .with_comments_count.includes(:user)
        .order(created_at: :desc, id: :desc).to_a
      @states = SubmissionUserStates.new(current_user, @submissions)
      render "api/submissions/index"
    end
  end
end
