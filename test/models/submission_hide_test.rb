require "test_helper"

class SubmissionHideTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
    @submission = submissions(:one)
  end

  test "hiding creates a personal relation without changing the submission" do
    original_attributes = @submission.attributes
    assert_no_difference [ "Submission.count", "Comment.count" ] do
      @user.submission_hides.create!(submission: @submission)
    end

    assert_equal original_attributes, @submission.reload.attributes
    assert_includes @user.hidden_submissions, @submission
    assert_not_includes users(:one).hidden_submissions, @submission
  end

  test "requires a user and a submission" do
    hide = SubmissionHide.new
    assert_not hide.valid?
    assert hide.errors[:user].any?
    assert hide.errors[:submission].any?
  end

  test "rejects duplicates in the model" do
    @user.submission_hides.create!(submission: @submission)
    duplicate = @user.submission_hides.new(submission: @submission)

    assert_not duplicate.valid?
    assert duplicate.errors[:submission_id].any?
  end

  test "database rejects duplicates even without validation" do
    @user.submission_hides.create!(submission: @submission)

    assert_raises ActiveRecord::RecordNotUnique do
      SubmissionHide.new(user: @user, submission: @submission).save!(validate: false)
    end
  end

  test "database rejects missing and nonexistent references" do
    assert_raises ActiveRecord::NotNullViolation do
      SubmissionHide.new(submission: @submission).save!(validate: false)
    end
    assert_raises ActiveRecord::InvalidForeignKey do
      SubmissionHide.new(user_id: User.maximum(:id) + 1, submission: @submission).save!(validate: false)
    end
  end

  test "different users can hide the same submission including its author" do
    @user.submission_hides.create!(submission: @submission)
    users(:one).submission_hides.create!(submission: @submission)

    assert_equal 2, @submission.submission_hides.count
  end

  test "visibility is personal and anonymous visitors see all submissions" do
    @user.submission_hides.create!(submission: @submission)

    assert_not_includes Submission.visible_to(@user), @submission
    assert_includes Submission.visible_to(users(:one)), @submission
    assert_includes Submission.visible_to(nil), @submission
    assert_includes Submission.visible_to(@user), submissions(:two)
  end

  test "unhiding restores visibility" do
    hide = @user.submission_hides.create!(submission: @submission)
    hide.destroy!

    assert_includes Submission.visible_to(@user), @submission
    assert_empty @user.hidden_submissions
  end

  test "destroying a submission removes its hides" do
    @user.submission_hides.create!(submission: @submission)

    assert_difference "SubmissionHide.count", -1 do
      @submission.destroy!
    end
  end

  test "destroying a user removes their hides" do
    @user.submission_hides.create!(submission: @submission)

    assert_difference "SubmissionHide.count", -1 do
      @user.destroy!
    end
    assert Submission.exists?(@submission.id)
  end
end
