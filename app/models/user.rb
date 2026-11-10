class User < ApplicationRecord
  MAX_OAUTH_CREATE_ATTEMPTS = 3

  has_many :submission_hides, dependent: :destroy
  has_many :submission_favorites, dependent: :destroy
  has_many :favorite_submissions, through: :submission_favorites, source: :submission
  has_many :comment_favorites, dependent: :destroy
  has_many :favorite_comments, through: :comment_favorites, source: :comment
  has_many :hidden_submissions, through: :submission_hides, source: :submission
  has_many :comment_votes, dependent: :destroy
  has_many :submission_votes, dependent: :destroy
  has_many :submissions, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :username, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    attempts = 0

    begin
      attempts += 1
      user = find_or_initialize_by(
        provider: auth.provider,
        uid: auth.uid
      )
      # Busca el compte extern; si no existeix, prepara un usuari nou.

      info = auth.info
      # Agrupa les dades retornades pel proveïdor.

      if user.username.blank?
        base_username = info.nickname.presence || info.name.presence || "user-#{auth.uid}"
        user.username = unique_username(base_username)
      end
      # Prefereix el nickname i afegeix un sufix si ja existeix.

      user.email = info.email if info.email.present?
      # Actualitza el correu només quan GitHub el retorna.

      user.save!
      # Crea o actualitza l'usuari.

      user
      # Retorna la instància que usarà SessionsController.
    rescue ActiveRecord::RecordNotUnique
      existing_user = find_by(provider: auth.provider, uid: auth.uid)
      return existing_user if existing_user
      raise if attempts >= MAX_OAUTH_CREATE_ATTEMPTS

      retry
      # Torna a provar si la col·lisió era del username.
    end
  end

  def self.unique_username(base_username)
    username = base_username
    suffix = 2

    while exists?(username: username)
      username = "#{base_username}_#{suffix}"
      suffix += 1
    end

    username
  end
  private_class_method :unique_username
end
