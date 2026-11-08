class SubmissionVotesController < ApplicationController
  before_action :require_login
  before_action :set_submission

  def create
    return head :forbidden if @submission.user_id == current_user.id

    @submission.with_lock do
      @submission.submission_votes.find_or_create_by!(user: current_user)
    end

    redirect_to @submission, status: :see_other
  end

  def destroy
    @submission.with_lock do
      current_user.submission_votes.find_by(submission_id: @submission.id)&.destroy!
    end

    redirect_to @submission, status: :see_other
  end

  private

  def set_submission
    @submission = Submission.find(params.expect(:submission_id))
  end
end
