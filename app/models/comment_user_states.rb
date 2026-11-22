# Estat de voted/favorited d'una llista de comentaris per a un usuari.
# Fa 2 consultes en total (una per taula) sigui quina sigui la mida del subarbre,
# evitant consultes N+1 durant el renderitzat de la jerarquia.
class CommentUserStates
  def initialize(user, comments)
    ids = comments.map(&:id)
    if user && ids.any?
      @voted_ids = user.comment_votes.where(comment_id: ids).pluck(:comment_id).to_set
      @favorited_ids = user.comment_favorites.where(comment_id: ids).pluck(:comment_id).to_set
    else
      @voted_ids = Set.new
      @favorited_ids = Set.new
    end
    @visible_cache = {}
  end

  def voted?(comment)
    @voted_ids.include?(comment.id)
  end

  def favorited?(comment)
    @favorited_ids.include?(comment.id)
  end

  # Un comentari és visible si no està esborrat, o si té algun descendent visible.
  def visible?(comment, comments_by_parent)
    @visible_cache[comment.id] ||= begin
      if !comment.deleted?
        true
      else
        children = comments_by_parent[comment.id] || []
        children.any? { |child| visible?(child, comments_by_parent) }
      end
    end
  end
end
