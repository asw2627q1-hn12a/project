Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,                         # Activa el proveïdor GitHub.
           ENV["GITHUB_CLIENT_ID"],          # Client ID, no és un secret.
           ENV["GITHUB_CLIENT_SECRET"],      # Secret només disponible al servidor.
           scope: "read:user user:email"     # Permet llegir perfil i correu.
end

OmniAuth.config.on_failure = proc do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end
