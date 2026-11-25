module Api
  class HiddenSubmissionsController < BaseController
    before_action :set_submission

    def create
      @submission.with_lock do
        return render_conflict if hides.exists?

        hides.create!
        render json: { id: @submission.id, points: @submission.points, hidden: true }, status: :created
      end
    end

    def destroy
      @submission.with_lock do
        hide = hides.first
        return render_conflict unless hide

        hide.destroy!
        head :no_content
      end
    end

    private

    def set_submission
      @submission = Submission.find(params.expect(:submission_id))
    end

    def hides
      current_user.submission_hides.where(submission: @submission)
    end
  end
end
