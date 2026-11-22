# Esquema CommentTree d'api/api.yaml. Locals: @comment, @comments_by_parent, @comment_states.
json.partial! "api/comments/comment", comment: @comment, comments_by_parent: @comments_by_parent, states: @comment_states
