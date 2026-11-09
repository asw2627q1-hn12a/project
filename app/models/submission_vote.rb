class SubmissionVote < ApplicationRecord
  belongs_to :user
  belongs_to :submission

  validates :user_id, uniqueness: { scope: :submission_id }
  validate :cannot_vote_own_submission

  after_create :add_submission_point
  after_destroy :remove_submission_point

  private

  def add_submission_point
    Submission.increment_counter(:points, submission_id)
  end

  def remove_submission_point
    Submission.decrement_counter(:points, submission_id)
  end

  def cannot_vote_own_submission
    return if submission.nil? || user_id.nil?
    return unless submission.user_id == user_id

    errors.add(:submission, "no pot ser pròpia")
  end
end
