module Api
  class AskController < BaseController
    # GET /api/ask
    # Mateix filtre i ordre que la pàgina web /ask (SubmissionsController#ask).
    def index
      @submissions = Submission.visible_to(current_user).where(submission_type: "ask")
        .with_comments_count.includes(:user).by_relevance.to_a
      @states = SubmissionUserStates.new(current_user, @submissions)
      render "api/submissions/index"
    end
  end
end
