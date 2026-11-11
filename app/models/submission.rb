require "uri"

class Submission < ApplicationRecord
  belongs_to :user
  has_many :submission_votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :submission_hides, dependent: :destroy
  has_many :submission_favorites, dependent: :destroy

  scope :visible_to, ->(user) {
    user ? where.not(id: user.submission_hides.select(:submission_id)) : all
  }
  scope :by_relevance, -> { order(points: :desc, created_at: :desc) }
  scope :with_title_containing, ->(query) {
    where("LOWER(title) LIKE ? ESCAPE '!'", "%#{sanitize_sql_like(query.downcase, "!")}%")
  }
  scope :with_comments_count, -> {
    left_joins(:comments)
      .select("submissions.*, COUNT(comments.id) AS comments_count")
      .group("submissions.id")
  }

  # Antes de validar, limpiamos espacios y asignamos el tipo automáticamente
  before_validation :normalize_fields

  # 1. El título es obligatorio (el texto queda opcional al no exigir presence)
  validates :title, presence: true

  # 2. Tipo de submission válido
  validates :submission_type, inclusion: { in: %w[url ask] }

  # 3. Si se informa una URL, validar formato y unicidad (ignorando URLs vacías de las Ask)
  validates :url,
            uniqueness: { case_sensitive: false },
            allow_blank: true
  validate :url_is_valid

  validates :url, presence: true, if: -> { submission_type == "url" }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def domain
    return nil if url.blank?
    uri = URI.parse(url)
    uri.host&.sub(/^www\./, "")
  rescue URI::InvalidURIError
    nil
  end

  # Nombre de comentaris: usa el recompte agrupat de la BD si ve de with_comments_count
  def comments_total
    has_attribute?(:comments_count) ? self[:comments_count] : comments.count
  end

  private

  def url_is_valid
    return if url.blank?

    uri = URI.parse(url)
    return if %w[http https].include?(uri.scheme&.downcase) && uri.host.present?

    errors.add(:url, "must be a valid URL starting with http:// or https://")
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid URL starting with http:// or https://")
  end

  def normalize_fields
    self.url = url.strip if url.present?
    self.url = nil if url.blank? # Evita que dos strings vacíos "" choquen en BD
    self.submission_type = url.present? ? "url" : "ask"
  end
end
