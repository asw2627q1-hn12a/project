class CommentsController < ApplicationController
  before_action :set_submission, only: %i[ show new create edit update destroy ]
  before_action :require_login, only: %i[ create edit update destroy threads ]
  before_action :set_comment, only: %i[ show edit update destroy ]
  before_action :authorize_comment, only: %i[ edit update destroy ]

  def index
    @comments = Comment.includes(:user, :submission, parent: :user).order(created_at: :desc).limit(30)
  end

  def show
    @thread_root = @comment
    @thread_path_ids = [ @comment.id ]

    while @thread_root.parent
      @thread_root = @thread_root.parent
      @thread_path_ids << @thread_root.id
    end
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
          redirect_to "#{return_path_or(submission_comment_path(@submission, @comment))}##{helpers.dom_id(@comment)}",
                      notice: "Changes saved."
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
        thread_path = @comment.parent ? submission_comment_path(@submission, @comment.parent) : submission_path(@submission, anchor: "comments")
        redirect_to return_path_after_destroy(submission_comment_path(@submission, @comment), thread_path),
                    notice: "Comment deleted. Replies have been preserved."
      end
      format.json { head :no_content }
    end
  end

  def threads
    @comments = Comment.thread_roots_for(current_user)
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
end
