module UsersHelper
  # URL de l'avatar o el banner: el fitxer pujat (object storage) o, si no n'hi ha, la imatge per defecte.
  def profile_image_url(user, kind)
    image = user.public_send(kind)
    return url_for(image) if image.attached? && image.blob.persisted?

    image_path("default-#{kind}.svg")
  end

  def custom_profile_image?(user, kind)
    image = user.public_send(kind)
    image.attached? && image.blob.persisted?
  end
end
