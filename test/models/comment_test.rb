require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "requires points to be a nonnegative integer" do
    comment = Comment.new(submission: submissions(:one), user: users(:one), body: "Comment")

    [ nil, -1, 1.5 ].each do |points|
      comment.points = points

      assert_not comment.valid?
      assert comment.errors[:points].present?
    end
  end

  test "accepts a reply to a comment on the same submission" do
    parent = Comment.create!(submission: submissions(:one), user: users(:one), body: "Comentari pare")
    reply = Comment.new(submission: submissions(:one), user: users(:two), body: "Resposta", parent: parent)

    assert_predicate reply, :valid?
  end

  test "rejects a reply to a comment on another submission" do
    parent = Comment.create!(submission: submissions(:one), user: users(:one), body: "Comentari pare")
    reply = Comment.new(submission: submissions(:two), user: users(:two), body: "Resposta", parent: parent)

    assert_not reply.valid?
    assert_includes reply.errors[:parent], "must belong to the same submission"
  end

  test "requires a comment body" do
    comment = Comment.new(submission: submissions(:one), user: users(:one), body: "")

    assert_not comment.valid?
    assert_includes comment.errors[:body], "can't be blank"
  end

  test "soft deletion clears the text and keeps replies attached" do
    parent = Comment.create!(submission: submissions(:one), user: users(:one), body: "Text privat")
    reply = Comment.create!(submission: submissions(:one), user: users(:two), body: "Resposta", parent: parent)

    parent.soft_delete!
    parent.reload

    assert_predicate parent, :deleted?
    assert_empty parent.body
    assert_equal parent, reply.reload.parent
  end
end
