module SubmissionsHelper
  def submission_voted?(submission)
    return false unless current_user

    @voted_submission_ids ||= current_user.submission_votes
      .where(submission_id: (@submissions || [ submission ]).map(&:id))
      .pluck(:submission_id).to_set
    @voted_submission_ids.include?(submission.id)
  end
end
