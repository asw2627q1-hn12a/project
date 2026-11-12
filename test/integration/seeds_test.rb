require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds add missing examples and can be repeated without changing existing records" do
    assert_difference "User.count", 5 do
      assert_difference "Submission.count", 15 do
        run_seeds
      end
    end

    users_before = User.order(:id).map(&:attributes)
    voted = Submission.find_by!(url: "https://www.kernel.org/")
    original_points = voted.points
    SubmissionVote.create!(user: users(:one), submission: voted)
    submissions_before = Submission.order(:id).map(&:attributes)

    assert_no_difference [ "User.count", "Submission.count", "SubmissionVote.count" ] do
      run_seeds
    end

    assert_equal users_before, User.order(:id).map(&:attributes)
    assert_equal submissions_before, Submission.order(:id).map(&:attributes)
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

  private

  def run_seeds
    capture_io { load Rails.root.join("db/seeds.rb") }
  end
end
