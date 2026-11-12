class SubmissionsController < ApplicationController
  before_action :require_login, only: %i[ edit update destroy ]
  before_action :set_submission, only: %i[ show edit update destroy ]
  before_action :require_login_for_submit, only: %i[new create]
  before_action :authorize_submission, only: %i[ edit update destroy ]

  # GET /submissions or /news or /
  def index
    @submissions = Submission.visible_to(current_user).with_comments_count.includes(:user).by_relevance
  end

  # GET /search
  def search
    @query = params[:q].to_s.strip
    @submissions = if @query.present?
      Submission.visible_to(current_user).with_title_containing(@query).with_comments_count.includes(:user).by_relevance
    else
      Submission.none
    end
    render :index
  end

  # GET /submissions/1 or /submissions/1.json
  def show
    @comments = @submission.comments.where(parent_id: nil).includes(:user).order(:created_at)
    @comment = @submission.comments.new
  end

  # GET /submissions/new
  def new
    @submission = Submission.new
  end

  # GET /newest
  def newest
    @submissions = Submission.visible_to(current_user).with_comments_count.includes(:user).order(created_at: :desc, id: :desc)
    render :index
  end

  # GET /submissions/1/edit
  def edit
  end

  # GET /ask
  def ask
    @submissions = Submission.visible_to(current_user).where(submission_type: "ask").with_comments_count.includes(:user).by_relevance
    render :index
  end

  # POST /submissions
  def create
    @submission = Submission.new(submission_params)
    @submission.user = current_user

    # 1. Comprobar si la URL informada ya existe en la BD
    if @submission.url.present?
      existing_submission = Submission.find_by("LOWER(url) = ?", @submission.url.strip.downcase)
      if existing_submission
        redirect_to submission_path(existing_submission), notice: "This URL has already been submitted."
        return
      end
    end

    # 2. Si no existe duplicado, validar formato/título y guardar
    respond_to do |format|
      if @submission.save
        # Redirigir a Newest con la nueva submission al principio
        format.html { redirect_to newest_path, notice: "Submission was successfully created." }
        format.json { render :show, status: :created, location: @submission }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @submission.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /submissions/1 or /submissions/1.json
  def update
    respond_to do |format|
      if @submission.update(submission_params)
        format.html { redirect_to @submission, notice: "Submission was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @submission }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @submission.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /submissions/1 or /submissions/1.json
  def destroy
    @submission.destroy!

    respond_to do |format|
      format.html { redirect_to submissions_path, notice: "Submission was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def require_login_for_submit
      return if current_user

      redirect_to root_path(anchor: "login"), alert: "Please log in to submit a post."
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_submission
      @submission = Submission.find(params.expect(:id))
    end

    def authorize_submission
      head :forbidden unless @submission.user == current_user
    end

    # Only allow a list of trusted parameters through.
    def submission_params
      params.expect(submission: [ :title, :url, :text ])
    end
end
