class CommentsController < ApplicationController
  before_action :set_submission, only: %i[ show new create edit update destroy ]
  before_action :require_login, only: %i[ create edit update destroy ]
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
                      notice: "Comentari publicat."
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
          redirect_to submission_comment_path(@submission, @comment), notice: "Canvis desats."
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
                    notice: "Comentari eliminat. Les respostes es conserven."
      end
      format.json { head :no_content }
    end
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
