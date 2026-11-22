# Esquema CommentTree: el comentari i les seves respostes visibles, recursivament.
json.partial! "api/comments/comment", comment: comment, states: states
json.replies comment.visible_replies do |reply|
  json.partial! "api/comments/comment_tree", comment: reply, states: states
end
