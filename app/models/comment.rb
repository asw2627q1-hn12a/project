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

  # Respostes que es mostren dins del fil, de la més antiga a la més nova.
  # Ordena en memòria per aprofitar les respostes ja carregades (preload_replies), sense consulta nova.
  def visible_replies
    replies.sort_by(&:created_at).select(&:visible_in_thread?)
  end

  # Comentaris de l'usuari que encapçalen un fil a Threads (web i API): els no esborrats,
  # del més nou al més antic, sense els que ja surten dins del fil d'un altre comentari propi.
  # Carrega tots els comentaris de les submissions afectades en una consulta i munta l'arbre en memòria.
  def self.thread_roots_for(user)
    own = user.comments.where(deleted_at: nil).order(created_at: :desc).to_a
    return [] if own.empty?

    tree = where(submission_id: own.map(&:submission_id).uniq).includes(:user, :submission).index_by(&:id)
    preload_replies(tree.values)

    own_ids = own.map(&:id).to_set
    parent_ids = tree.transform_values(&:parent_id)
    own.map { |comment| tree[comment.id] }.reject { |comment| own_ancestor?(comment, own_ids, parent_ids) }
  end

  # Assigna a cada comentari les seves respostes ja carregades, perquè `replies` no torni a consultar la BD.
  def self.preload_replies(comments)
    children = comments.group_by(&:parent_id)
    comments.each do |comment|
      comment.association(:replies).target = children.fetch(comment.id, [])
    end
  end
  private_class_method :preload_replies

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
