require "test_helper"

class SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @submission = submissions(:one)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-submissions-controller",
      info: { nickname: "submissions_controller_user", email: "submissions@example.com" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "should get index" do
    get submissions_url
    assert_response :success
  end

  test "should get new" do
    sign_in
    get new_submission_url
    assert_response :success
  end

  test "should create submission" do
    sign_in

    assert_difference("Submission.count") do
      post submissions_url, params: {
        submission: {
          points: 999,
          submission_type: "url",
          title: "A new submission",
          url: "https://created.example.test/submission",
          user_id: users(:two).id
        }
      }
    end

    assert_redirected_to newest_url
    created_submission = Submission.find_by!(url: "https://created.example.test/submission")
    assert_equal 1, created_submission.points
    assert_equal "github-submissions-controller", created_submission.user.uid
  end

  test "should show submission" do
    get submission_url(@submission)
    assert_response :success
  end

  test "should get edit" do
    get edit_submission_url(@submission)
    assert_response :success
  end

  test "should update submission" do
    patch submission_url(@submission), params: {
      submission: {
        title: "Updated submission",
        url: "https://updated.example.test/submission"
      }
    }
    assert_redirected_to submission_url(@submission)
  end

  test "should destroy submission" do
    assert_difference("Submission.count", -1) do
      delete submission_url(@submission)
    end

    assert_redirected_to submissions_url
  end

  private

  def sign_in
    get "/auth/github/callback"
  end
end
