require 'uri'

class Submission < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :submission_type, inclusion: { in: %w[url ask] }
  validates :url, presence: true, if: -> { submission_type == 'url' }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Extrae el host limpio de la URL para mostrarlo al estilo HN: (news.ycombinator.com)
  def domain
    return nil if url.blank?
    uri = URI.parse(url)
    uri.host&.sub(/^www\./, '')
  rescue URI::InvalidURIError
    nil
  end
end