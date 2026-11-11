json.extract! user, :id, :username, :created_at, :updated_at
# El correu és privat: només el veu el mateix usuari.
json.email user.email if user == current_user
json.url user_url(user, format: :json)
