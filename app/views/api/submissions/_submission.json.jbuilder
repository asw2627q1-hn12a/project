# Esquema Submission de public/api/api.yaml. Locals: submission, states (SubmissionUserStates).
json.extract! submission, :id, :title, :url, :text, :submission_type, :domain, :points
json.comments_count submission.comments_total
json.created_at submission.created_at
json.author do
  json.extract! submission.user, :id, :username
end
json.voted states.voted?(submission)
json.hidden states.hidden?(submission)
json.favorited states.favorited?(submission)
