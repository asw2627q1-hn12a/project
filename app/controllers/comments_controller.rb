class CommentsController < ApplicationController
  before_action :set_submission, only: %i[ show new create edit update destroy ]
  before_action :require_login, only: %i[ create edit update destroy threads ]
  before_action :set_comment, only: %i[ show edit update destroy ]
  before_action :authorize_comment, only: %i[ edit update destroy ]

  def index
    @comments = Comment.includes(:user, :submission, parent: :user).order(created_at: :desc).limit(30)
  end

  def show
  end

  def new
    @parent_comment = @submission.comments.find(params.expect(:parent_id))
    @comment = @parent_comment.replies.new(submission: @submission, user: current_user)
  end

  def create
    comment_attributes = comment_params
    @comment = @submission.comments.new(body: comment_attributes[:body], user: current_user)

    if comment_attributes[:parent_id].present?
      @parent_comment = @submission.comments.find(comment_attributes[:parent_id])
      @comment.parent = @parent_comment
    end

    respond_to do |format|
      if @comment.save
        format.html do
          redirect_to submission_path(@submission, anchor: helpers.dom_id(@comment)),
                      notice: "Comment posted."
        end
        format.json { render json: @comment, status: :created }
      else
        format.html do
          if @parent_comment
            render :new, status: :unprocessable_content
          else
            @comments = @submission.comments.where(parent_id: nil).includes(:user).order(:created_at)
            render "submissions/show", status: :unprocessable_content
          end
        end
        format.json { render json: @comment.errors, status: :unprocessable_content }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @comment.update(edit_comment_params)
        format.html do
          redirect_to submission_comment_path(@submission, @comment), notice: "Changes saved."
        end
        format.json { render json: @comment, status: :ok }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @comment.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @comment.soft_delete!

    respond_to do |format|
      format.html do
        redirect_to submission_comment_path(@submission, @comment),
                    notice: "Comment deleted. Replies have been preserved."
      end
      format.json { head :no_content }
    end
  end

  def threads
    comments = current_user.comments
                 .where(deleted_at: nil)
                 .includes(:submission, :user, replies: :user)
                 .order(created_at: :desc)
    own_ids = comments.map(&:id).to_set
    # Mapa id => parent_id de tots els comentaris de les submissions afectades (una sola consulta)
    parent_ids = Comment.where(submission_id: comments.map(&:submission_id).uniq).pluck(:id, :parent_id).to_h
    # Evita repetir un comentari que ja surt dins del fil d'un comentari propi (a qualsevol nivell)
    @comments = comments.reject { |comment| own_ancestor?(comment, own_ids, parent_ids) }
  end

  private
    def set_submission
      @submission = Submission.find(params.expect(:submission_id))
    end

    def comment_params
      params.expect(comment: [ :body, :parent_id ])
    end

    def edit_comment_params
      params.expect(comment: [ :body ])
    end

    def set_comment
      @comment = @submission.comments.includes(:user).find(params.expect(:id))
    end

    def authorize_comment
      return if @comment.user == current_user && !@comment.deleted?

      head :forbidden
    end

    def own_ancestor?(comment, own_ids, parent_ids)
      ancestor_id = comment.parent_id
      while ancestor_id
        return true if own_ids.include?(ancestor_id)

        ancestor_id = parent_ids[ancestor_id]
      end
      false
    end
end
