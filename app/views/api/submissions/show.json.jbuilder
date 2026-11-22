# Esquema SubmissionDetail d'api/api.yaml. Locals: @submission, @states, @root_comments, @comment_states.
json.partial! "api/submissions/submission", submission: @submission, states: @states
json.comments @root_comments do |comment|
  json.partial! "api/comments/comment_tree", comment: comment, states: @comment_states
end
