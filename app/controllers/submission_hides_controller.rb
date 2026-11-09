class SubmissionHidesController < ApplicationController
  before_action :require_login
  before_action :set_submission, only: %i[create destroy]

  def index
    @submissions = current_user.hidden_submissions.includes(:user).by_relevance
  end

  def create
    @submission.with_lock do
      current_user.submission_hides.find_or_create_by!(submission: @submission)
    end

    redirect_back_or_to root_path, allow_other_host: false, status: :see_other
  end

  def destroy
    @submission.with_lock do
      current_user.submission_hides.find_by(submission: @submission)&.destroy!
    end

    redirect_back_or_to root_path, allow_other_host: false, status: :see_other
  end

  private

  def set_submission
    @submission = Submission.find(params.expect(:submission_id))
  end
end
