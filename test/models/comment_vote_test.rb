require "test_helper"

class CommentVoteTest < ActiveSupport::TestCase
  setup do
    @comment = Comment.create!(submission: submissions(:one), user: users(:one), body: "Comentari de prova")
    @voter = users(:two)
  end

  test "comments start with one point and no author vote" do
    assert_equal 1, @comment.points
    assert_empty @comment.comment_votes
  end

  test "voting another user's comment adds one point" do
    vote = CommentVote.new(user: @voter, comment: @comment)

    assert_difference("CommentVote.count", 1) do
      assert vote.save
    end

    assert_equal 2, @comment.reload.points
  end

  test "rejects duplicate votes without adding another point" do
    CommentVote.create!(user: @voter, comment: @comment)
    duplicate = CommentVote.new(user: @voter, comment: @comment)

    assert_not duplicate.save
    assert duplicate.errors[:user_id].present?
    assert_equal 2, @comment.reload.points
  end

  test "allows different users to vote the same comment" do
    other_voter = User.create!(username: "another_comment_voter")
    CommentVote.create!(user: @voter, comment: @comment)
    CommentVote.create!(user: other_voter, comment: @comment)

    assert_equal 3, @comment.reload.points
  end

  test "rejects voting own comment" do
    vote = CommentVote.new(user: @comment.user, comment: @comment)

    assert_not vote.save
    assert_includes vote.errors[:comment], "no pot ser propi"
    assert_equal 1, @comment.reload.points
  end

  test "requires a user and a comment" do
    vote = CommentVote.new

    assert_not vote.valid?
    assert vote.errors[:user].present?
    assert vote.errors[:comment].present?
  end

  test "database rejects duplicate votes without model validations" do
    CommentVote.create!(user: @voter, comment: @comment)
    duplicate = CommentVote.new(user: @voter, comment: @comment)

    assert_raises ActiveRecord::RecordNotUnique do
      CommentVote.transaction(requires_new: true) do
        duplicate.save!(validate: false)
      end
    end

    assert_equal 2, @comment.reload.points
  end

  test "withdrawing a vote restores the initial point" do
    vote = CommentVote.create!(user: @voter, comment: @comment)

    assert_difference("CommentVote.count", -1) do
      vote.destroy!
    end

    assert_equal 1, @comment.reload.points
  end

  test "rejects new votes on deleted comments" do
    @comment.soft_delete!
    vote = CommentVote.new(user: @voter, comment: @comment)

    assert_not vote.save
    assert_includes vote.errors[:comment], "no pot estar eliminat"
    assert_equal 1, @comment.reload.points
  end

  test "soft deletion preserves votes and allows their withdrawal" do
    vote = CommentVote.create!(user: @voter, comment: @comment)

    @comment.soft_delete!

    assert CommentVote.exists?(vote.id)
    assert_equal 2, @comment.reload.points

    vote.destroy!

    assert_equal 1, @comment.reload.points
    assert_predicate @comment, :deleted?
  end

  test "rolling back a vote also rolls back its point" do
    assert_no_difference("CommentVote.count") do
      CommentVote.transaction do
        CommentVote.create!(user: @voter, comment: @comment)
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 1, @comment.reload.points
  end

  test "removing a voter removes their vote and point" do
    CommentVote.create!(user: @voter, comment: @comment)

    @voter.destroy!

    assert_not CommentVote.exists?(user_id: @voter.id)
    assert_equal 1, @comment.reload.points
  end

  test "physically deleting a comment removes its votes" do
    vote = CommentVote.create!(user: @voter, comment: @comment)

    @comment.destroy!

    assert_not CommentVote.exists?(vote.id)
  end
end
