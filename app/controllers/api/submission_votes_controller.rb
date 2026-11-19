module Api
  class SubmissionVotesController < BaseController
    before_action :set_submission

    def create
      @submission.with_lock do
        if @submission.user_id == current_user.id
          return render_api_error("forbidden", "You cannot vote for your own submission", status: :forbidden)
        end

        return render_conflict if votes.exists?

        votes.create!
        render json: { id: @submission.id, points: @submission.reload.points, voted: true }, status: :created
      end
    end

    def destroy
      @submission.with_lock do
        vote = votes.first
        return render_conflict unless vote

        vote.destroy!
        head :no_content
      end
    end

    private

    def set_submission
      @submission = Submission.find(params.expect(:submission_id))
    end

    def votes
      current_user.submission_votes.where(submission: @submission)
    end
  end
end
