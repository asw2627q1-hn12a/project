module CommentsHelper
  def comment_voted?(comment)
    return false unless current_user

    @voted_comment_ids ||= current_user.comment_votes.pluck(:comment_id).to_set
    @voted_comment_ids.include?(comment.id)
  end
end
