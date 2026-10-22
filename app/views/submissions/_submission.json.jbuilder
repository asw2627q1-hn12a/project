json.extract! submission, :id, :title, :url, :points, :submission_type, :user_id, :created_at, :updated_at
json.url submission_url(submission, format: :json)
