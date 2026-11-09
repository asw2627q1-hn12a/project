class CommentVote < ApplicationRecord
  belongs_to :user
  belongs_to :comment

  validates :user_id, uniqueness: { scope: :comment_id }
  validate :cannot_vote_own_comment
  validate :cannot_vote_deleted_comment

  after_create :add_comment_point
  after_destroy :remove_comment_point

  private

  def add_comment_point
    Comment.increment_counter(:points, comment_id)
  end

  def remove_comment_point
    Comment.decrement_counter(:points, comment_id)
  end

  def cannot_vote_own_comment
    return if comment.nil? || user_id.nil?
    return unless comment.user_id == user_id

    errors.add(:comment, "no pot ser propi")
  end

  def cannot_vote_deleted_comment
    errors.add(:comment, "no pot estar eliminat") if comment&.deleted?
  end
end
