require "test_helper"

class FavoriteModelsTest < ActiveSupport::TestCase
  [ SubmissionFavorite, CommentFavorite ].each do |model|
    test "#{model} validates uniqueness and the database enforces it" do
      attributes = { user: users(:one) }
      if model == SubmissionFavorite
        attributes[:submission] = submissions(:one)
      else
        attributes[:comment] = Comment.create!(user: users(:one), submission: submissions(:one), body: "Saved")
      end
      model.create!(attributes)
      duplicate = model.new(attributes)
      assert_not duplicate.valid?
      assert_raises ActiveRecord::RecordNotUnique do
        duplicate.save!(validate: false)
      end
      assert model.create!(attributes.merge(user: users(:two))).persisted?
    end
  end

  test "deleting content cleans up favorites" do
    submission = submissions(:one)
    comment = submission.comments.create!(user: users(:one), body: "Saved")
    SubmissionFavorite.create!(user: users(:two), submission: submission)
    CommentFavorite.create!(user: users(:two), comment: comment)
    assert_difference [ "SubmissionFavorite.count", "CommentFavorite.count" ], -1 do
      submission.destroy!
    end
  end

  test "deleting a user cleans up their favorites on other users content" do
    user = users(:two)
    submission = submissions(:one)
    comment = submission.comments.create!(user: users(:one), body: "Saved")
    SubmissionFavorite.create!(user: user, submission: submission)
    CommentFavorite.create!(user: user, comment: comment)
    assert_difference [ "SubmissionFavorite.count", "CommentFavorite.count" ], -1 do
      user.destroy!
    end
    assert Submission.exists?(submission.id)
    assert Comment.exists?(comment.id)
  end
end
