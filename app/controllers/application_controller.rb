class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :return_to_here
  # Permet utilitzar current_user i return_to_here també dins les vistes.

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

  # Ruta de la pàgina actual (amb la query, p. ex. /search?q=rails) per tornar-hi després d'una acció
  def return_to_here
    request.fullpath
  end

  # Només accepta rutes internes de l'app: evita redireccions a altres webs (open redirect)
  def safe_return_path(value)
    return if value.blank? || value.to_s.include?("\\")

    uri = URI.parse(value.to_s)
    return if uri.host.present? && uri.host != request.host

    path = uri.path.to_s
    return unless path.start_with?("/") && !path.start_with?("//")
    return if path.start_with?("/auth", "/logout")

    uri.query.present? ? "#{path}?#{uri.query}" : path
  rescue URI::InvalidURIError
    nil
  end

  def return_path_or(fallback)
    safe_return_path(params[:return_to]) || fallback
  end

  # Després d'eliminar: si l'origen era la pàgina del recurs eliminat (detall o edició),
  # prova el return_to que portava aquella pàgina i, si no, el fallback
  def return_path_after_destroy(resource_path, fallback)
    path = safe_return_path(params[:return_to])
    return fallback unless path
    return path unless inside_path?(path, resource_path)

    nested = safe_return_path(Rack::Utils.parse_query(URI.parse(path).query)["return_to"])
    nested && !inside_path?(nested, resource_path) ? nested : fallback
  end

  def inside_path?(path, resource_path)
    bare = path.split("?").first
    bare == resource_path || bare.start_with?("#{resource_path}/")
  end
end
