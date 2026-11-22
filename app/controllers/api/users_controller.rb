module Api
  # Perfils i llistats d'usuari (Taiga #69). Mateixes consultes i ordre que les pàgines
  # web del perfil (UsersController i SubmissionHidesController).
  class UsersController < BaseController
    # Llistes que només pot veure el propietari, com a la web.
    PRIVATE_LISTS = %i[ upvoted upvoted_comments hidden ].freeze

    before_action :set_user
    before_action :require_owner, only: %i[ update ] + PRIVATE_LISTS

    # La vista show decideix si mostra l'email (només al perfil propi).
    helper_method :current_user

    # GET /api/users/:id
    def show
    end

    # PATCH /api/users/:id (només el propi). El username no es pot canviar.
    def update
      @user.update!(user_params)
      render :show
    end

    # GET /api/users/:id/submissions (públic)
    def submissions
      render_submissions @user.submissions.visible_to(current_user).with_comments_count.includes(:user)
        .order(created_at: :desc)
    end

    # GET /api/users/:id/comments (públic)
    def comments
      render_comments @user.comments.where(deleted_at: nil).includes(:user).order(created_at: :desc)
    end

    # GET /api/users/:id/favorites (públic). Primer els darrers que s'han marcat.
    def favorites
      render_submissions @user.favorite_submissions.visible_to(current_user).with_comments_count.includes(:user)
        .order(Arel.sql("MAX(submission_favorites.created_at) DESC"))
    end

    # GET /api/users/:id/favorite_comments (públic)
    def favorite_comments
      render_comments @user.favorite_comments.where(deleted_at: nil).includes(:user)
        .order(CommentFavorite.arel_table[:created_at].desc)
    end

    # GET /api/users/:id/upvoted (només el propietari)
    def upvoted
      render_submissions @user.upvoted_submissions.with_comments_count.includes(:user).by_relevance
    end

    # GET /api/users/:id/upvoted_comments (només el propietari)
    def upvoted_comments
      render_comments @user.upvoted_comments.where(deleted_at: nil).includes(:user).order(created_at: :desc)
    end

    # GET /api/users/:id/hidden (només el propietari)
    def hidden
      render_submissions @user.hidden_submissions.with_comments_count.includes(:user).by_relevance
    end

    private

    def set_user
      @user = User.find(params.expect(:id))
    end

    def require_owner
      return if @user == current_user

      render_api_error("forbidden", "Only the owner of this profile can do this", status: :forbidden)
    end

    def user_params
      params.expect(user: [ :about, :email ])
    end

    def render_submissions(submissions)
      @submissions = submissions.to_a
      @states = SubmissionUserStates.new(current_user, @submissions)
      render "api/submissions/index"
    end

    def render_comments(comments)
      @comments = comments.to_a
      @states = CommentUserStates.new(current_user, @comments.map(&:submission_id).uniq)
      render "api/comments/index"
    end
  end
end
