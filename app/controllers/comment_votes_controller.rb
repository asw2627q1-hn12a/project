class CommentVotesController < ApplicationController
  before_action :require_login
  before_action :set_comment

  def create
    @comment.with_lock do
      return head :forbidden if @comment.user_id == current_user.id || @comment.deleted?

      @comment.comment_votes.find_or_create_by!(user: current_user)
    end

    redirect_back_or_to submission_comment_path(@comment.submission, @comment),
                        allow_other_host: false, status: :see_other
  end

  def destroy
    @comment.with_lock do
      current_user.comment_votes.find_by(comment_id: @comment.id)&.destroy!
    end

    redirect_back_or_to submission_comment_path(@comment.submission, @comment),
                        allow_other_host: false, status: :see_other
  end

  private

  def set_comment
    submission = Submission.find(params.expect(:submission_id))
    @comment = submission.comments.find(params.expect(:comment_id))
  end
end
