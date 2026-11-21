Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://editor.swagger.io"

    resource "/api/*",
      headers: %w[X-API-Key Content-Type],
      methods: %i[get post patch put delete]
  end
end
