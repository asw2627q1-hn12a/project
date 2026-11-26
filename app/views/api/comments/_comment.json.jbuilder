# Esquema Comment de public/api/api.yaml. Locals: comment, states (CommentUserStates).
json.extract! comment, :id, :submission_id, :parent_id
json.body comment.deleted? ? nil : comment.body
json.deleted comment.deleted?
json.points comment.points
json.created_at comment.created_at
if comment.deleted?
  json.author nil
else
  json.author { json.extract! comment.user, :id, :username }
end
json.voted states.voted?(comment)
json.favorited states.favorited?(comment)
