class RemoveAvatarAndBannerFromUsers < ActiveRecord::Migration[8.1]
  # Les columnes eren provisionals (vegeu AddOauthFieldsToUsers): ara l'avatar i el banner
  # són fitxers d'Active Storage guardats a l'object storage.
  def change
    remove_column :users, :avatar, :string, default: "default-avatar.png"
    remove_column :users, :banner, :string, default: "default-banner.png"
  end
end
