class Comment < ApplicationRecord
  belongs_to :submission
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true, inverse_of: :replies
  has_many :comment_votes, dependent: :destroy
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  validates :body, presence: { message: "no pot estar buit" }, unless: :deleted?
  validate :parent_belongs_to_submission
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    timestamp = Time.current
    update_columns(body: "", deleted_at: timestamp, updated_at: timestamp)
  end

  private
    def parent_belongs_to_submission
      return if parent.nil? || parent.submission_id == submission_id

      errors.add(:parent, "ha de pertànyer a la mateixa publicació")
    end
end
