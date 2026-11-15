# Estat de voted/hidden/favorited d'una llista de submissions per a un usuari.
# Fa 3 consultes en total (una per taula), sigui quina sigui la mida de la llista,
# en lloc de 3 per submission (N+1). Ho fa servir la vista api/submissions/_submission.
class SubmissionUserStates
  def initialize(user, submissions)
    ids = submissions.map(&:id)
    @voted_ids = user.submission_votes.where(submission_id: ids).pluck(:submission_id).to_set
    @hidden_ids = user.submission_hides.where(submission_id: ids).pluck(:submission_id).to_set
    @favorited_ids = user.submission_favorites.where(submission_id: ids).pluck(:submission_id).to_set
  end

  def voted?(submission) = @voted_ids.include?(submission.id)
  def hidden?(submission) = @hidden_ids.include?(submission.id)
  def favorited?(submission) = @favorited_ids.include?(submission.id)
end
