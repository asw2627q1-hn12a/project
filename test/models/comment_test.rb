require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "accepts a reply to a comment on the same submission" do
    parent = Comment.create!(submission: submissions(:one), user: users(:one), body: "Comentari pare")
    reply = Comment.new(submission: submissions(:one), user: users(:two), body: "Resposta", parent: parent)

    assert_predicate reply, :valid?
  end

  test "rejects a reply to a comment on another submission" do
    parent = Comment.create!(submission: submissions(:one), user: users(:one), body: "Comentari pare")
    reply = Comment.new(submission: submissions(:two), user: users(:two), body: "Resposta", parent: parent)

    assert_not reply.valid?
    assert_includes reply.errors[:parent], "ha de pertànyer a la mateixa submission"
  end

  test "requires a comment body" do
    comment = Comment.new(submission: submissions(:one), user: users(:one), body: "")

    assert_not comment.valid?
    assert_includes comment.errors[:body], "no pot estar buit"
  end
end
