module Api
  class CommentsController < BaseController
    # GET /api/comments — els 30 comentaris més recents, com /newcomments a la web.
    def index
      @comments = Comment.includes(:user).order(created_at: :desc).limit(30).to_a
      @states = CommentUserStates.new(current_user, @comments.map(&:submission_id).uniq)
      render "api/comments/index"
    end

    # GET /api/threads — fils de l'usuari de l'API key, com /threads a la web.
    def threads
      @comments = Comment.thread_roots_for(current_user)
      @states = CommentUserStates.new(current_user, @comments.map(&:submission_id).uniq)
      render "api/comments/threads"
    end
  end
end
