require "test_helper"

class SubmissionVoteTest < ActiveSupport::TestCase
  setup do
    @submission = submissions(:one)
    @voter = users(:two)
  end

  test "allows voting another user's submission" do
    vote = SubmissionVote.new(user: @voter, submission: @submission)

    assert_difference("SubmissionVote.count", 1) do
      assert vote.save
    end
  end

  test "rejects duplicate votes" do
    SubmissionVote.create!(user: @voter, submission: @submission)
    duplicate = SubmissionVote.new(user: @voter, submission: @submission)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "allows different users to vote the same submission" do
    other_voter = User.create!(username: "another_voter")
    SubmissionVote.create!(user: @voter, submission: @submission)

    vote = SubmissionVote.new(user: other_voter, submission: @submission)

    assert vote.save
  end

  test "rejects voting own submission" do
    vote = SubmissionVote.new(
      user: @submission.user,
      submission: @submission
    )

    assert_not vote.valid?
    assert_includes vote.errors[:submission], "cannot belong to you"
  end

  test "requires a user and a submission" do
    vote = SubmissionVote.new

    assert_not vote.valid?
    assert vote.errors[:user].present?
    assert vote.errors[:submission].present?
  end

  test "database rejects duplicate votes without model validations" do
    SubmissionVote.create!(user: @voter, submission: @submission)
    duplicate = SubmissionVote.new(user: @voter, submission: @submission)

    assert_raises ActiveRecord::RecordNotUnique do
      SubmissionVote.transaction(requires_new: true) do
        duplicate.save!(validate: false)
      end
    end
  end

  test "updates points when a vote is created and destroyed" do
    vote = SubmissionVote.create!(user: @voter, submission: @submission)
    assert_equal 2, @submission.reload.points

    vote.destroy!

    assert_equal 1, @submission.reload.points
  end

  test "rolling back a vote also rolls back its point" do
    assert_no_difference("SubmissionVote.count") do
      SubmissionVote.transaction do
        SubmissionVote.create!(user: @voter, submission: @submission)
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 1, @submission.reload.points
  end

  test "removing a voter removes their vote and point" do
    SubmissionVote.create!(user: @voter, submission: @submission)

    @voter.destroy!

    assert_not SubmissionVote.exists?(user_id: @voter.id)
    assert_equal 1, @submission.reload.points
  end
end
