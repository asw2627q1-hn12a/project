class FavoritesController < ApplicationController
  before_action :require_login
  before_action :set_target

  def create
    return head :gone if @target.is_a?(Comment) && @target.deleted?

    @target.with_lock do
      @favorites.find_or_create_by!(user: current_user)
    end
    redirect_back_or_to @return_path, allow_other_host: false, status: :see_other
  end

  def destroy
    @target.with_lock do
      @favorites.find_by(user: current_user)&.destroy!
    end
    redirect_back_or_to @return_path, allow_other_host: false, status: :see_other
  end

  private

  def set_target
    submission = Submission.find(params.expect(:submission_id))
    if params[:comment_id]
      @target = submission.comments.find(params.expect(:comment_id))
      @favorites = @target.comment_favorites
      @return_path = submission_comment_path(submission, @target)
    else
      @target = submission
      @favorites = @target.submission_favorites
      @return_path = submission_path(submission)
    end
  end
end
