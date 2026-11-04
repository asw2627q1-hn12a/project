class CommentsController < ApplicationController
  before_action :set_submission, only: %i[ show new create ]

  def index
    @comments = Comment.includes(:user, :submission, parent: :user).order(created_at: :desc).limit(30)
  end

  def show
    @comment = @submission.comments.includes(:user).find(params.expect(:id))
  end

  def new
    @parent_comment = @submission.comments.find(params.expect(:parent_id))
    @comment = @parent_comment.replies.new(submission: @submission)
    @users = User.order(:username)
  end

  def create
    comment_attributes = comment_params
    @comment = @submission.comments.new(comment_attributes.except(:parent_id))
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
          @users = User.order(:username)
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

  private
    def set_submission
      @submission = Submission.find(params.expect(:submission_id))
    end

    def comment_params
      params.expect(comment: [ :body, :user_id, :parent_id ])
    end
end
