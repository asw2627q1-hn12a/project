class User < ApplicationRecord
  has_many :submissions, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :username, presence: true, uniqueness: true
end