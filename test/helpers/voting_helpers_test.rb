require "test_helper"

class VotingHelpersTest < ActiveSupport::TestCase
  include SubmissionsHelper
  include CommentsHelper

  setup do
    @user = users(:two)
    @submission = submissions(:one)
  end

  test "submission state works without controller initialization" do
    vote = SubmissionVote.create!(user: @user, submission: @submission)

    assert submission_voted?(@submission)
    assert_equal @user, vote.user
  end

  test "grouped submission lists support extra selected columns and one vote query" do
    @submissions = Submission.left_joins(:comments)
      .select("submissions.*, COUNT(comments.id) AS comments_count").group("submissions.id")
    SubmissionVote.create!(user: @user, submission: @submission)
    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] if payload[:sql].match?(/FROM ["`]?submission_votes/i)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      @submissions.each do |submission|
        assert_equal submission.id == @submission.id, submission_voted?(submission)
      end
    end

    assert_equal 1, queries.size
  end

  test "flat comment lists load only votes for the displayed comments" do
    shown = @submission.comments.create!(body: "Shown", user: users(:one))
    outside = @submission.comments.create!(body: "Outside", user: users(:one))
    [ shown, outside ].each { |comment| CommentVote.create!(user: @user, comment: comment) }

    assert_equal Set[shown.id], prepare_comment_votes([ shown ])
    assert comment_voted?(shown)
  end

  test "comment trees include deep replies but exclude other trees on the same submission" do
    root = @submission.comments.create!(body: "Root", user: users(:one))
    reply = @submission.comments.create!(body: "Reply", user: users(:one), parent: root)
    deep = @submission.comments.create!(body: "Deep reply", user: users(:one), parent: reply)
    outside = @submission.comments.create!(body: "Another root", user: users(:one))
    [ root, deep, outside ].each { |comment| CommentVote.create!(user: @user, comment: comment) }
    deep.soft_delete!

    assert_equal Set[root.id, deep.id], prepare_comment_votes([ root ], include_replies: true)
    assert comment_voted?(root)
    assert comment_voted?(deep)
    assert_not comment_voted?(reply)
  end

  test "single comment previews resolve their own vote without loading an entire history" do
    comment = @submission.comments.create!(body: "Reply context", user: users(:one))
    assert_not comment_voted?(comment)
    CommentVote.create!(user: @user, comment: comment)
    assert comment_voted?(comment)
  end

  test "anonymous visitors have no votes" do
    @user = nil
    assert_not submission_voted?(@submission)
    comment = @submission.comments.create!(body: "Anonymous context", user: users(:one))
    assert_nil prepare_comment_votes([ comment ], include_replies: true)
    assert_not comment_voted?(comment)
  end

  private

  def current_user
    @user
  end
end
