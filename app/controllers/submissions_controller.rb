class SubmissionsController < ApplicationController
  before_action :set_submission, only: %i[ show edit update destroy ]
  before_action :require_login_for_submit, only: %i[new create]

  # GET /submissions or /news or /
  def index
    @submissions = Submission.where(submission_type: "url").includes(:user).by_relevance
    set_voted_submission_ids
  end

  # GET /search
  def search
    @query = params[:q].to_s.strip
    @submissions = if @query.present?
      Submission.with_title_containing(@query).includes(:user).by_relevance
    else
      Submission.none
    end
    set_voted_submission_ids
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
    @submissions = Submission.includes(:user).order(created_at: :desc)
    set_voted_submission_ids
    render :index
  end

  # GET /submissions/1/edit
  def edit
  end

  # GET /ask
  def ask
    @submissions = Submission.where(submission_type: "ask").includes(:user).by_relevance
    set_voted_submission_ids
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
        redirect_to submission_path(existing_submission), notice: "Esta URL ya había sido publicada."
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
    def set_voted_submission_ids
      @voted_submission_ids = if current_user
        current_user.submission_votes
                    .where(submission_id: @submissions.select(:id))
                    .pluck(:submission_id).to_set
      else
        Set.new
      end
    end

    def require_login_for_submit
      return if current_user

      redirect_to root_path(anchor: "login"), alert: "Cal iniciar sessió per publicar una submission."
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_submission
      @submission = Submission.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def submission_params
      params.expect(submission: [ :title, :url, :text ])
    end
end
