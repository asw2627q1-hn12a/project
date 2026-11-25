module Api
  # Avatar i banner del perfil propi (Taiga #70). Reaprofita el que ja fa la web:
  # Active Storage (R2 a producció), la validació del model (tipus i mida màxima)
  # i les imatges per defecte quan no n'hi ha cap.
  class UserImagesController < BaseController
    before_action :set_user
    before_action :require_owner

    # La resposta és el perfil (vista api/users/show), que mostra l'email al propietari.
    helper_method :current_user

    # PUT /api/users/:user_id/avatar (o /banner), multipart/form-data amb el camp "image"
    def update
      image = params.require(:image)
      # Només fitxers pujats: un text seria un signed_id d'un fitxer que ja és al storage.
      return render_bad_request unless image.is_a?(ActionDispatch::Http::UploadedFile)

      @user.update!(kind => image)
      render "api/users/show"
    end

    # DELETE /api/users/:user_id/avatar (o /banner): torna a sortir la imatge per defecte.
    def destroy
      @user.update!("remove_#{kind}" => true)
      render "api/users/show"
    end

    private

    # "avatar" o "banner": ve de la ruta (defaults: { kind: ... }), no del client.
    def kind
      params.expect(:kind)
    end

    def set_user
      @user = User.find(params.expect(:user_id))
    end

    def require_owner
      return if @user == current_user

      render_api_error("forbidden", "Only the owner of this profile can do this", status: :forbidden)
    end
  end
end
