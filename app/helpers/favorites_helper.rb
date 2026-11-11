module FavoritesHelper
  def favorited?(record)
    return false unless current_user

    @favorite_ids ||= {}
    @favorite_ids[record.class] ||= if record.is_a?(Submission)
      current_user.submission_favorites.pluck(:submission_id).to_set
    else
      current_user.comment_favorites.pluck(:comment_id).to_set
    end
    @favorite_ids[record.class].include?(record.id)
  end
end
