class User < ApplicationRecord
  has_many :submissions, dependent: :destroy

  validates :username, presence: true, uniqueness: true
end