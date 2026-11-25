module Api
  class SubmissionFavoritesController < BaseController
    before_action :set_submission

    def create
      @submission.with_lock do
        return render_conflict if favorites.exists?

        favorites.create!
        render json: { id: @submission.id, favorited: true }, status: :created
      end
    end

    def destroy
      @submission.with_lock do
        favorite = favorites.first
        return render_conflict unless favorite

        favorite.destroy!
        head :no_content
      end
    end

    private

    def set_submission
      @submission = Submission.find(params.expect(:submission_id))
    end

    def favorites
      current_user.submission_favorites.where(submission: @submission)
    end
  end
end
