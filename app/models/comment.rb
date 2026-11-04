class Comment < ApplicationRecord
  belongs_to :submission, optional: true
  belongs_to :user, optional: true
  belongs_to :parent, class_name: "Comment", optional: true, inverse_of: :replies
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  validates :body, presence: { message: "no pot estar buit" }
  validates :submission, presence: { message: "no és vàlida" }
  validates :user, presence: { message: "no és vàlid" }
  validate :parent_belongs_to_submission

  private
    def parent_belongs_to_submission
      return if parent.nil? || parent.submission_id == submission_id

      errors.add(:parent, "ha de pertànyer a la mateixa submission")
    end
end
