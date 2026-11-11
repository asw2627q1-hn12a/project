class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user
  # Permet utilitzar current_user també dins les vistes.

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
    # Tradueix l'id de sessió a un usuari de la base de dades.
  end

  def require_login
    return if current_user
    # Continua si hi ha una sessió vàlida.

    redirect_to root_path, alert: "Please log in to continue."
    # Bloqueja usuaris anònims.
  end
end
