module Api
  class CommentsController < BaseController
    before_action :set_comment, only: %i[show update destroy]

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

    # POST /api/submissions/:submission_id/comments
    def create
      submission_id = params[:submission_id] || params[:id]
      @submission = Submission.find(submission_id)

      attrs = comment_params
      @comment = @submission.comments.new(body: attrs[:body], user: current_user)

      if attrs[:parent_id].present?
        parent = @submission.comments.find(attrs[:parent_id])
        @comment.parent = parent
      end

      @comment.save!

      load_comment_tree(@submission)
      render "api/comments/show", status: :created
    end

    # GET /api/comments/:id
    def show
      load_comment_tree(@comment.submission)
      render "api/comments/show"
    end

    # PUT/PATCH /api/comments/:id
    def update
      return render_api_error("forbidden", "You can only modify your own content", status: :forbidden) unless @comment.user_id == current_user.id
      return render_api_error("forbidden", "Deleted comments cannot be modified", status: :forbidden) if @comment.deleted?

      attrs = update_comment_params
      @comment.update!(attrs)

      load_comment_tree(@comment.submission)
      render "api/comments/show", status: :ok
    end

    # DELETE /api/comments/:id
    def destroy
      return render_api_error("forbidden", "You can only modify your own content", status: :forbidden) unless @comment.user_id == current_user.id
      return render_api_error("forbidden", "Deleted comments cannot be modified", status: :forbidden) if @comment.deleted?

      @comment.soft_delete!
      head :no_content
    end

    private

    def set_comment
      @comment = Comment.find(params.expect(:id))
    end

    def load_comment_tree(submission)
      comments = submission.comments.includes(:user).to_a
      Comment.preload_replies(comments)
      @comment = comments.find { |c| c.id == @comment.id } || @comment
      @states = CommentUserStates.new(current_user, [ submission.id ])
    end

    def comment_params
      if params.key?(:comment) && params[:comment].is_a?(ActionController::Parameters)
        params.expect(comment: [ :body, :parent_id ])
      else
        params.permit(:body, :parent_id)
      end
    end

    def update_comment_params
      if params.key?(:comment) && params[:comment].is_a?(ActionController::Parameters)
        params.expect(comment: [ :body ])
      else
        params.permit(:body)
      end
    end
  end
end
