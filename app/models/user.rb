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

    user.username ||= info.nickname.presence || info.name.presence || "user-#{auth.uid}"
    # Prefereix el nickname i usa fallbacks si el perfil no té nom.

    user.email = info.email if info.email.present?
    # Actualitza el correu només quan GitHub el retorna.

    user.save!
    # Crea o actualitza l'usuari.

    user
    # Retorna la instància que usarà SessionsController.
  end
end