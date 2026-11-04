class User < ApplicationRecord
  has_many :submissions, dependent: :destroy

  validates :username, presence: true, uniqueness: true

  def self.from_omniauth(auth)
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