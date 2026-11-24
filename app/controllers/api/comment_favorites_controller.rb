module Api
  class CommentFavoritesController < BaseController
    before_action :set_comment

    def create
      @comment.with_lock do
        return render_api_error("conflict", "Deleted comments cannot be favorited", status: :conflict) if @comment.deleted?
        return render_conflict if favorites.exists?

        favorites.create!
        render json: { id: @comment.id, favorited: true }, status: :created
      end
    end

    def destroy
      @comment.with_lock do
        favorite = favorites.first
        return render_conflict unless favorite

        favorite.destroy!
        head :no_content
      end
    end

    private

    def set_comment
      @comment = Comment.find(params.expect(:comment_id))
    end

    def favorites
      current_user.comment_favorites.where(comment: @comment)
    end
  end
end
