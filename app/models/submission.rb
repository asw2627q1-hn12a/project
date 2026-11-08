require "uri"

class Submission < ApplicationRecord
  belongs_to :user
  has_many :submission_votes, dependent: :destroy
  has_many :comments, dependent: :destroy

  scope :by_relevance, -> { order(points: :desc, created_at: :desc) }
  scope :with_title_containing, ->(query) {
    where("LOWER(title) LIKE ? ESCAPE '!'", "%#{sanitize_sql_like(query.downcase, "!")}%")
  }

  # Antes de validar, limpiamos espacios y asignamos el tipo automáticamente
  before_validation :normalize_fields

  # 1. El título es obligatorio (el texto queda opcional al no exigir presence)
  validates :title, presence: true

  # 2. Tipo de submission válido
  validates :submission_type, inclusion: { in: %w[url ask] }

  # 3. Si se informa una URL, validar formato y unicidad (ignorando URLs vacías de las Ask)
  validates :url,
            format: {
              with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
              message: "debe ser una URL válida (empezando por http:// o https://)"
            },
            uniqueness: { case_sensitive: false },
            allow_blank: true

  validates :url, presence: true, if: -> { submission_type == "url" }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def domain
    return nil if url.blank?
    uri = URI.parse(url)
    uri.host&.sub(/^www\./, "")
  rescue URI::InvalidURIError
    nil
  end

  private

  def normalize_fields
    self.url = url.strip if url.present?
    self.url = nil if url.blank? # Evita que dos strings vacíos "" choquen en BD
    self.submission_type = url.present? ? "url" : "ask"
  end
end
