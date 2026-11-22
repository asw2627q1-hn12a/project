# Esquema User d'api/api.yaml. L'email només surt al perfil propi, com a la web.
json.extract! @user, :id, :username, :created_at, :karma, :about
json.email @user.email if @user == current_user
# La imatge pujada (Active Storage) o, si no n'hi ha, la per defecte. URL absoluta.
json.avatar_url @user.avatar.attached? ? rails_blob_url(@user.avatar) : image_url("default-avatar.svg")
json.banner_url @user.banner.attached? ? rails_blob_url(@user.banner) : image_url("default-banner.svg")
