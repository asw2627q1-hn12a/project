module Api
  class CommentVotesController < BaseController
    before_action :set_comment

    def create
      @comment.with_lock do
        if @comment.user_id == current_user.id || @comment.deleted?
          return render_api_error("forbidden", "You cannot vote for your own comment or a deleted comment", status: :forbidden)
        end

        return render_conflict if votes.exists?

        votes.create!
        render json: { id: @comment.id, points: @comment.reload.points, voted: true }, status: :created
      end
    end

    def destroy
      @comment.with_lock do
        vote = votes.first
        return render_conflict unless vote

        vote.destroy!
        head :no_content
      end
    end

    private

    def set_comment
      @comment = Comment.find(params.expect(:comment_id))
    end

    def votes
      current_user.comment_votes.where(comment: @comment)
    end
  end
end
