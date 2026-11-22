# Esquema SubmissionDetail d'api/api.yaml. Locals: @submission, @states, @root_comments, @comments_by_parent, @comment_states.
json.partial! "api/submissions/submission", submission: @submission, states: @states
json.comments @root_comments do |comment|
  json.partial! "api/comments/comment", comment: comment, comments_by_parent: @comments_by_parent, states: @comment_states
end
