# Esquema CommentTree d'api/api.yaml. Locals: comment, comments_by_parent, states (CommentUserStates).
json.extract! comment, :id, :submission_id, :parent_id

if comment.deleted?
  json.body nil
  json.author nil
else
  json.body comment.body
  json.author do
    json.extract! comment.user, :id, :username
  end
end

json.deleted comment.deleted?
json.points comment.points
json.created_at comment.created_at
json.voted states.voted?(comment)
json.favorited states.favorited?(comment)

replies = (comments_by_parent[comment.id] || []).select { |child| states.visible?(child, comments_by_parent) }
json.replies replies do |reply|
  json.partial! "api/comments/comment", comment: reply, comments_by_parent: comments_by_parent, states: states
end
