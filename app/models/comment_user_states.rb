# Estat de voted/favorited dels comentaris per a un usuari, en 2 consultes en total.
# Inclou tots els comentaris de les submissions indicades, també les respostes dels arbres.
class CommentUserStates
  def initialize(user, submission_ids)
    submission_ids = Array(submission_ids).compact.uniq
    if user && submission_ids.any?
      @voted_ids = ids_for(user.comment_votes, submission_ids)
      @favorited_ids = ids_for(user.comment_favorites, submission_ids)
    else
      @voted_ids = Set.new
      @favorited_ids = Set.new
    end
  end

  def voted?(comment) = @voted_ids.include?(comment.id)
  def favorited?(comment) = @favorited_ids.include?(comment.id)

  private

  def ids_for(relation, submission_ids)
    relation.joins(:comment).where(comments: { submission_id: submission_ids }).pluck(:comment_id).to_set
  end
end
