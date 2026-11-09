module CommentsHelper
  def prepare_comment_votes(comments, include_replies: false)
    return unless current_user

    comments = comments.to_a
    ids = comments.map(&:id).to_set
    if include_replies && ids.any?
      children = Comment.where(submission_id: comments.map(&:submission_id).uniq)
                        .pluck(:id, :parent_id).group_by(&:last)
      pending = ids.to_a
      until pending.empty?
        children.fetch(pending.pop, []).each do |id, _parent_id|
          pending << id if ids.add?(id)
        end
      end
    end

    @voted_comment_ids = current_user.comment_votes.where(comment_id: ids.to_a).pluck(:comment_id).to_set
  end

  def comment_voted?(comment)
    return false unless current_user

    return @voted_comment_ids.include?(comment.id) if @voted_comment_ids

    current_user.comment_votes.exists?(comment_id: comment.id)
  end
end
