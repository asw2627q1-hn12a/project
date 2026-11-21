class Comment < ApplicationRecord
  belongs_to :submission
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true, inverse_of: :replies
  has_many :comment_votes, dependent: :destroy
  has_many :comment_favorites, dependent: :destroy
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  validates :body, presence: { message: "can't be blank" }, unless: :deleted?
  validate :parent_belongs_to_submission
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    timestamp = Time.current
    update_columns(body: "", deleted_at: timestamp, updated_at: timestamp)
  end

  # Un comentari esborrat només es mostra si té alguna resposta visible (a qualsevol nivell)
  def visible_in_thread?
    !deleted? || replies.any?(&:visible_in_thread?)
  end

  # Respostes que es mostren dins del fil (amaga les esborrades sense respostes visibles)
  def visible_replies
    replies.includes(:user).order(:created_at).select(&:visible_in_thread?)
  end

  # Comentaris de l'usuari que encapçalen un fil a Threads (web i API): els no esborrats,
  # del més nou al més antic, sense els que ja surten dins del fil d'un altre comentari propi.
  def self.thread_roots_for(user)
    comments = user.comments.where(deleted_at: nil)
                   .includes(:submission, :user, replies: :user)
                   .order(created_at: :desc).to_a
    own_ids = comments.map(&:id).to_set
    parent_ids = where(submission_id: comments.map(&:submission_id).uniq).pluck(:id, :parent_id).to_h
    comments.reject { |comment| own_ancestor?(comment, own_ids, parent_ids) }
  end

  def self.own_ancestor?(comment, own_ids, parent_ids)
    ancestor_id = comment.parent_id
    while ancestor_id
      return true if own_ids.include?(ancestor_id)

      ancestor_id = parent_ids[ancestor_id]
    end
    false
  end
  private_class_method :own_ancestor?

  private
    def parent_belongs_to_submission
      return if parent.nil? || parent.submission_id == submission_id

      errors.add(:parent, "must belong to the same submission")
    end
end
