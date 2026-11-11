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
  has_many :upvoted_submissions, through: :submission_votes, source: :submission
  has_many :upvoted_comments, through: :comment_votes, source: :comment
  has_many :submissions, dependent: :destroy
  has_many :comments, dependent: :destroy

  IMAGE_TYPES = %w[ image/png image/jpeg image/gif image/webp ].freeze
  MAX_IMAGE_SIZE = 2.megabytes
  # Mida final (amplada, alçada) a la qual el navegador retalla cada imatge abans de pujar-la.
  IMAGE_DIMENSIONS = { avatar: [ 400, 400 ], banner: [ 1200, 200 ] }.freeze

  # Fitxers a l'object storage (Active Storage). Si no n'hi ha, es mostra la imatge per defecte.
  has_one_attached :avatar
  has_one_attached :banner

  # Caselles "eliminar" del formulari d'edició
  attribute :remove_avatar, :boolean, default: false
  attribute :remove_banner, :boolean, default: false

  validates :username, presence: true, uniqueness: true
  validates :about, length: { maximum: 2000 }
  validate :images_are_valid

  after_save :purge_removed_images

  # Karma estil HN: suma dels punts de les submissions i dels comentaris de l'usuari.
  def karma
    submissions.sum(:points) + comments.sum(:points)
  end

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

  private

  # Es valida tot fitxer que s'adjunti ara, tant si és una pujada nova com si és un blob
  # que ja existia al storage (p. ex. adjuntat amb el seu signed_id).
  def images_are_valid
    { avatar: avatar, banner: banner }.each do |name, image|
      next unless attachment_changes.key?(name.to_s) && image.attached?

      errors.add(name, "ha de ser PNG, JPEG, GIF o WebP") unless IMAGE_TYPES.include?(image.blob.content_type)
      errors.add(name, "no pot ocupar més de 2 MB") if image.blob.byte_size > MAX_IMAGE_SIZE
    end
  end

  # Eliminar una imatge = esborrar el fitxer del storage; aleshores torna a sortir la per defecte.
  def purge_removed_images
    avatar.purge_later if remove_avatar && avatar.attached? && !attachment_changes.key?("avatar")
    banner.purge_later if remove_banner && banner.attached? && !attachment_changes.key?("banner")
  end
end
