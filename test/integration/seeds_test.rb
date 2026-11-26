require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds add missing examples and can be repeated without changing existing records" do
    assert_difference "User.count", 5 do
      assert_difference "Submission.count", 39 do
        assert_difference "Comment.count", 105 do
          run_seeds
        end
      end
    end

    users_before = User.order(:id).map(&:attributes)
    voted = Submission.find_by!(url: "https://www.kernel.org/")
    original_points = voted.points
    SubmissionVote.create!(user: users(:one), submission: voted)
    submissions_before = Submission.order(:id).map(&:attributes)
    comments_before = Comment.order(:id).map(&:attributes)

    assert_no_difference [ "User.count", "Submission.count", "Comment.count", "SubmissionVote.count" ] do
      travel 1.day do
        run_seeds
      end
    end

    assert_equal users_before, User.order(:id).map(&:attributes)
    assert_equal submissions_before, Submission.order(:id).map(&:attributes)
    assert_equal comments_before, Comment.order(:id).map(&:attributes)
    assert_equal original_points + 1, voted.reload.points
  end

  test "seeds preserve matching users and URLs and all related user content" do
    existing_user = User.create!(username: "pg", email: "personal@example.test", about: "My profile")
    existing_submission = Submission.create!(
      user: existing_user, title: "My title", url: "https://WWW.KERNEL.ORG/", points: 7
    )
    comment = existing_submission.comments.create!(user: users(:one), body: "Keep this comment")
    vote = existing_submission.submission_votes.create!(user: users(:two))
    hide = users(:two).submission_hides.create!(submission: existing_submission)
    favorite = users(:one).submission_favorites.create!(submission: existing_submission)
    user_before = existing_user.attributes
    submission_before = existing_submission.reload.attributes

    run_seeds

    assert_equal user_before, existing_user.reload.attributes
    assert_equal submission_before, existing_submission.reload.attributes
    assert_equal "Keep this comment", comment.reload.body
    assert vote.reload.persisted?
    assert hide.reload.persisted?
    assert favorite.reload.persisted?
  end

  test "seeds create multi-level nested comment threads from diverse authors on URL and Ask submissions" do
    run_seeds

    # Submissions de tipus URL i Ask amb comentaris
    url_submission = Submission.find_by!(url: "https://rubyonrails.org/2024/11/7/rails-8-no-paas-required")
    ask_submission = Submission.find_by!(title: "Ask HN: How do you learn a new codebase quickly?", submission_type: "ask")

    assert_operator url_submission.comments.count, :>=, 5
    assert_operator ask_submission.comments.count, :>=, 5

    # Diversitat d'autors tant en submissions com en comentaris
    seed_usernames = %w[ pg dhh matz linus ada_lovelace ]
    comment_authors = Comment.joins(:user).distinct.pluck("users.username")
    submission_authors = Submission.joins(:user).distinct.pluck("users.username")

    assert_empty seed_usernames - comment_authors, "Tots els usuaris de prova han de tenir comentaris"
    assert_empty seed_usernames - submission_authors, "Tots els usuaris de prova han de tenir submissions"

    # Nivells de jerarquia de comentaris: arrel (0), resposta (1), niat (2) i profund (3)
    level_0 = Comment.where(parent_id: nil)
    level_1 = Comment.where(parent_id: level_0.select(:id))
    level_2 = Comment.where(parent_id: level_1.select(:id))
    level_3 = Comment.where(parent_id: level_2.select(:id))

    assert_operator level_0.count, :>=, 10, "Han d'haver-hi múltiples comentaris arrel"
    assert_operator level_1.count, :>=, 10, "Han d'haver-hi respostes directes"
    assert_operator level_2.count, :>=, 5, "Han d'haver-hi respostes niades de segon nivell"
    assert_operator level_3.count, :>=, 2, "Han d'haver-hi respostes de profunditat 3 o superior"

    # Integritat referencial: cada resposta pertany a la mateixa submission que el seu pare
    Comment.where.not(parent_id: nil).includes(:parent).find_each do |child|
      assert_equal child.submission_id, child.parent.submission_id
    end

    # Comentari esborrat lògicament amb respostes visibles (cas de prova per a la demo)
    fib_submission = Submission.find_by!(url: "https://fib.upc.edu/ca/estudis/graus/grau-en-enginyeria-informatica")
    deleted_comment = fib_submission.comments.find_by(deleted_at: ...Time.current)
    assert deleted_comment.present?, "Ha d'existir un comentari soft-deleted a la submission de la demo"
    assert_predicate deleted_comment, :deleted?
    assert_empty deleted_comment.body
    assert_predicate deleted_comment, :visible_in_thread?, "El comentari esborrat ha de ser visible perquè té respostes"
    assert_operator deleted_comment.replies.count, :>, 0, "El comentari esborrat ha de tenir respostes conservades"

    # Perfils d'usuari amb biografia i karma calculable
    User.where(username: seed_usernames).find_each do |user|
      assert_predicate user.about, :present?, "L'usuari #{user.username} ha de tenir biografia 'about'"
      assert_operator user.karma, :>, 0, "L'usuari #{user.username} ha de tenir karma positiu"
    end
  end

  test "additional demo submissions have text and discussions with multiple authors" do
    run_seeds

    seed_users = User.where(username: %w[ pg dhh matz linus ada_lovelace ])
    assert_equal 24, Submission.where(user: seed_users, submission_type: "url").count
    assert_equal 15, Submission.where(user: seed_users, submission_type: "ask").count

    titles = [
      "A practical guide to HTTP response codes",
      "Ask HN: What would you test before your first API demo?"
    ]
    titles.each do |title|
      submission = Submission.find_by!(title: title)

      assert_equal 4, submission.comments.count
      assert_equal 2, submission.comments.where(parent_id: nil).count
      assert_equal 4, submission.comments.distinct.count(:user_id)
      assert submission.comments.where.not(parent_id: nil).any? { |comment| comment.parent.parent_id.present? }
      submission.comments.each do |comment|
        assert_operator comment.created_at, :>=, submission.created_at
        assert_operator comment.created_at, :<=, Time.current
      end
      assert_predicate submission.text, :present? if submission.submission_type == "ask"
    end
  end

  private

  def run_seeds
    capture_io { load Rails.root.join("db/seeds.rb") }
  end
end
