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

  test "search is accessible from the header without login" do
    get root_url
    assert_select "header form[action=?][method=get][role=search]", search_path do
      assert_select "input[type=search][name=q][aria-label=?]", "Search submissions by title"
      assert_select "input[type=submit][value=Search]"
    end

    get search_url
    assert_response :success
    assert_select "header form[action=?][method=get][role=search]", search_path do
      assert_select "input[type=search][name=q]"
      assert_select "input[type=submit][value=Search]"
    end
    assert_select "tr.athing", count: 0
    assert_select "p", text: "Enter a word to search submission titles."
  end

  test "search matches URL and Ask titles and sorts by points then newest" do
    older = Submission.create!(title: "Rails guide", url: "https://search.example/older", user: users(:one), points: 10, created_at: 2.days.ago)
    newer = Submission.create!(title: "Ask about RAILS", user: users(:one), points: 10, created_at: 1.day.ago)
    lower = Submission.create!(title: "Learning rails today", user: users(:two), points: 2)
    Submission.create!(title: "Unrelated title", url: "https://search.example/rails", text: "rails", user: users(:one), points: 100)

    get search_url, params: { q: "  rAiLs  " }

    assert_response :success
    assert_select "input[name=q][value=?]", "rAiLs"
    assert_select "tr.athing" do |rows|
      assert_equal [ newer, older, lower ].map { |submission| "submission_#{submission.id}" }, rows.map { |row| row["id"] }
    end
    [ older, newer, lower ].each do |submission|
      assert_select ".titleline a[href=?]", submission_path(submission), text: submission.title
    end
  end

  test "search displays a message when no titles match" do
    get search_url, params: { q: "no-matching-title" }

    assert_response :success
    assert_select "tr.athing", count: 0
    assert_select "p[role=status]", text: "No submissions found for “no-matching-title”. Try another word."
  end

  test "blank search does not return every submission" do
    get search_url, params: { q: "   " }

    assert_response :success
    assert_select "tr.athing", count: 0
    assert_select "p", text: "Enter a word to search submission titles."
  end

  test "search treats SQL wildcard and escape characters literally" do
    [ "%", "_", "!", "\\" ].each do |character|
      match = Submission.create!(title: "Contains #{character} literally", user: users(:one))

      get search_url, params: { q: character }

      assert_response :success
      assert_select "tr.athing", count: 1
      assert_select "tr#submission_#{match.id}"
    end
  end

  test "search treats SQL injection text as a literal query" do
    get search_url, params: { q: "' OR 1=1 --" }

    assert_response :success
    assert_select "tr.athing", count: 0
  end

  test "should get new" do
    sign_in
    get new_submission_url
    assert_response :success
  end

  test "submit page requires login and shows title URL and text fields" do
    get submit_url
    assert_redirected_to root_url(anchor: "login")
    assert_equal "Cal iniciar sessió per publicar una submission.", flash[:alert]

    follow_redirect!
    assert_response :success
    assert_select "#login form[action='/auth/github'] button", text: "login"

    sign_in
    get submit_url

    assert_response :success
    assert_select "input[name='submission[title]']"
    assert_select "input[name='submission[url]'][type='url']"
    assert_select "textarea[name='submission[text]']"
    assert_select "input[name='submission[user_id]']", count: 0
    assert_select "input[name='submission[submission_type]']", count: 0
  end

  test "anonymous users cannot create a submission" do
    assert_no_difference("Submission.count") do
      post submissions_url, params: { submission: { title: "Anonymous", url: "", text: "A question" } }
    end

    assert_redirected_to root_url(anchor: "login")
  end

  test "blank URL creates an Ask submission with text by the logged in user" do
    sign_in

    assert_difference("Submission.count", 1) do
      post submissions_url, params: {
        submission: { title: "Ask the community", url: "", text: "What do you think?", submission_type: "url" }
      }
    end

    assert_redirected_to newest_url
    submission = Submission.order(:id).last
    assert_equal "ask", submission.submission_type
    assert_nil submission.url
    assert_equal "What do you think?", submission.text
    assert_equal "github-submissions-controller", submission.user.uid
  end

  test "invalid submit preserves fields and displays validation errors" do
    sign_in

    assert_no_difference("Submission.count") do
      post submissions_url, params: {
        submission: { title: "", url: "not a URL", text: "Draft text" }
      }
    end

    assert_response :unprocessable_content
    assert_select "input[name='submission[url]'][value='not a URL']"
    assert_select "textarea[name='submission[text]']", text: "Draft text"
    assert_select "li", minimum: 1
  end

  test "invalid URL is rejected even with a title" do
    sign_in

    assert_no_difference("Submission.count") do
      post submissions_url, params: {
        submission: { title: "A link", url: "not a URL", text: "Draft text" }
      }
    end

    assert_response :unprocessable_content
    assert_select "input[name='submission[url]'][value='not a URL']"
    assert_select "li", text: /URL válida/
  end

  test "duplicate URL redirects to the existing submission" do
    sign_in
    existing_submission = Submission.find_by!(url: "https://example.com")

    assert_no_difference("Submission.count") do
      post submissions_url, params: {
        submission: { title: "Another title", url: "  HTTPS://EXAMPLE.COM  ", text: "Another description" }
      }
    end

    assert_redirected_to submission_url(existing_submission)
    follow_redirect!
    assert_response :success
    assert_select ".hn-flash-notice", count: 0
    assert_select "p", text: "Esta URL ya había sido publicada.", count: 1
    assert_select "#submission_#{existing_submission.id}", text: /#{Regexp.escape(existing_submission.title)}/
    assert_select "#submission_#{existing_submission.id}", text: /Another title/, count: 0
  end

  test "should create submission" do
    sign_in

    assert_difference("Submission.count") do
      post submissions_url, params: {
        submission: {
          points: 999,
          submission_type: "ask",
          title: "A new submission",
          url: "https://created.example.test/submission",
          user_id: users(:two).id
        }
      }
    end

    assert_redirected_to newest_url
    follow_redirect!
    assert_select ".hn-notice", text: "Submission was successfully created.", count: 1
    assert_select ".hn-flash-notice", count: 0
    created_submission = Submission.find_by!(url: "https://created.example.test/submission")
    assert_equal "url", created_submission.submission_type
    assert_equal 1, created_submission.points
    assert_equal "github-submissions-controller", created_submission.user.uid
  end

  test "should show submission" do
    get submission_url(@submission)
    assert_response :success
    assert_select ".submission-heading-title > a[href=?]", @submission.url, text: @submission.title
    assert_select ".submission-heading-domain a[href=?]", @submission.url, text: @submission.domain
  end

  test "submission heading does not render executable URLs from stored data" do
    [ "javascript:alert(1)", "javascript://example.com/%0Aalert(1)", "data:text/html,<script>alert(1)</script>" ].each do |url|
      @submission.update_columns(url: url)

      get submission_url(@submission)

      assert_response :success
      assert_select ".submission-heading-title > a", text: @submission.title
      assert_select ".submission-heading a[href^='javascript:']", count: 0
      assert_select ".submission-heading a[href^='data:']", count: 0
    end
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
