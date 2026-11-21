class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    # Recupera les dades que OmniAuth ha obtingut del proveïdor.

    origin = safe_return_path(request.env["omniauth.origin"])
    # Pàgina des d'on s'ha iniciat sessió (OmniAuth la desa a partir del Referer o del paràmetre origin).
    # Es llegeix abans del reset_session.

    user = User.from_omniauth(auth)
    # Busca o crea l'usuari a partir de provider i uid.

    reset_session
    # Regenera la sessió per evitar session fixation.

    session[:user_id] = user.id
    # Desa només l'identificador intern de User.

    redirect_to origin || root_path
    # Torna a la pàgina on era l'usuari; si no és una ruta interna vàlida, a la portada.
  end

  def failure
    message = params[:message].presence || "OAuth login failed"
    # Utilitza un missatge genèric si el proveïdor no n'envia cap.

    redirect_to root_path, alert: message
    # Retorna l'usuari a una pàgina segura.
  end

  def destroy
    reset_session
    # Elimina la identitat de la sessió.

    redirect_to root_path, notice: "Logged out"
    # Finalitza el logout amb una redirecció normal.
  end
end
