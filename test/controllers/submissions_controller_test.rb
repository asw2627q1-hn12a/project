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

  test "newest lists submissions from newest to oldest" do
    older = Submission.create!(
      title: "Older submission",
      url: "https://older.example.test",
      user: users(:one),
      created_at: 2.days.ago
    )
    newer = Submission.create!(
      title: "Newer submission",
      url: "https://newer.example.test",
      user: users(:one),
      created_at: 1.day.ago
    )

    get newest_url

    assert_response :success
    assert_select "tr.athing" do |rows|
      expected_ids = Submission.order(created_at: :desc).map { |submission| "submission_#{submission.id}" }
      assert_equal expected_ids, rows.map { |row| row["id"] }
    end
  end

  test "new navigation link opens the newest page" do
    get submissions_url

    assert_response :success
    assert_select ".hn-nav a[href=?]", newest_path, text: "new"
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

  test "ask lists only Ask submissions sorted by points then newest" do
    older = Submission.create!(title: "Ask older", user: users(:one), points: 5, created_at: 2.days.ago)
    newer = Submission.create!(title: "Ask newer", user: users(:two), points: 5, created_at: 1.day.ago)
    top = Submission.create!(title: "Ask top", text: "Some question", user: users(:one), points: 20)

    get ask_url

    assert_response :success
    assert_select "tr.athing" do |rows|
      assert_equal [ top, newer, older ].map { |submission| "submission_#{submission.id}" }, rows.map { |row| row["id"] }
    end
    [ top, newer, older ].each do |submission|
      assert_select ".titleline a[href=?]", submission_path(submission), text: submission.title
    end
    assert_select "nav a[href=?]", ask_path, text: "ask"
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
    sign_in_as_owner
    get edit_submission_url(@submission)
    assert_response :success
    assert_select "input[name='submission[title]'][value=?]", @submission.title
    assert_select "input[name='submission[url]'][value=?]", @submission.url
    assert_select "textarea[name='submission[text]']", text: @submission.text.to_s
    assert_select "input[type=submit][value='update']"
    assert_select ".submission-edit-page .hn-itemlist .titleline", text: /#{Regexp.escape(@submission.title)}/
  end

  test "should update submission" do
    sign_in_as_owner
    patch submission_url(@submission), params: {
      submission: {
        title: "Updated submission",
        url: "https://updated.example.test/submission",
        text: "Updated text",
        user_id: users(:two).id,
        points: 999
      }
    }
    assert_redirected_to submission_url(@submission)
    @submission.reload
    assert_equal "Updated submission", @submission.title
    assert_equal "https://updated.example.test/submission", @submission.url
    assert_equal "Updated text", @submission.text
    assert_equal users(:one), @submission.user
    assert_equal 1, @submission.points
  end

  test "should destroy submission" do
    sign_in_as_owner
    assert_difference("Submission.count", -1) do
      delete submission_url(@submission)
    end

    assert_redirected_to submissions_url
  end

  test "anonymous users cannot edit update or destroy submissions" do
    get edit_submission_url(@submission)
    assert_redirected_to root_url

    original_attributes = @submission.attributes
    patch submission_url(@submission), params: { submission: { title: "Unauthorized" } }
    assert_redirected_to root_url
    assert_equal original_attributes, @submission.reload.attributes

    assert_no_difference("Submission.count") { delete submission_url(@submission) }
    assert_redirected_to root_url
  end

  test "other users cannot edit update or destroy submissions including JSON requests" do
    sign_in
    [ :html, :json ].each do |format|
      get edit_submission_url(@submission, format: format)
      assert_response :forbidden

      original_attributes = @submission.attributes
      patch submission_url(@submission, format: format), params: {
        submission: { title: "Unauthorized", user_id: users(:two).id }
      }
      assert_response :forbidden
      assert_equal original_attributes, @submission.reload.attributes

      assert_no_difference("Submission.count") { delete submission_url(@submission, format: format) }
      assert_response :forbidden
    end
  end

  test "management controls are visible only to the author" do
    get submission_url(@submission)
    assert_select "a[href=?]", edit_submission_path(@submission), count: 0
    assert_select "form[action=?] input[name=_method][value=delete]", submission_path(@submission), count: 0

    sign_in
    get submission_url(@submission)
    assert_select "a[href=?]", edit_submission_path(@submission), count: 0
    assert_select "form[action=?] input[name=_method][value=delete]", submission_path(@submission), count: 0

    sign_in_as_owner
    get submission_url(@submission)
    assert_select "a[href=?]", edit_submission_path(@submission), count: 1
    assert_select "form[action=?][data-turbo-confirm] input[name=_method][value=delete]", submission_path(@submission), count: 1
    assert_select "p", text: "Deleting this submission permanently deletes all its comments and replies."
  end

  test "editing with the unchanged URL succeeds" do
    sign_in_as_owner
    patch submission_url(@submission), params: { submission: { title: "New title", url: @submission.url } }

    assert_redirected_to submission_url(@submission)
    assert_equal "New title", @submission.reload.title
  end

  test "list management controls are available only on own submissions across all lists" do
    lists = [ root_url, newest_url, search_url(q: @submission.title) ]

    lists.each do |url|
      get url
      assert_select ".subtext a[href=?]", edit_submission_path(@submission), count: 0
      assert_select ".subtext .submission-delete-form", count: 0
    end

    sign_in_as_owner
    lists.each do |url|
      get url
      assert_select ".subtext a[href=?]", edit_submission_path(@submission), text: "edit", count: 1
      assert_select ".subtext form[action=?][data-turbo-confirm]", submission_path(@submission) do
        assert_select "input[name=_method][value=delete]"
        assert_select "button", text: "delete", count: 1
      end
      assert_select ".subtext a[href=?]", edit_submission_path(submissions(:two)), count: 0
      assert_select ".subtext form[action=?]", submission_path(submissions(:two)), count: 0
    end
  end

  test "invalid edit keeps entered fields and does not change the stored submission" do
    sign_in_as_owner
    original_attributes = @submission.attributes
    patch submission_url(@submission), params: {
      submission: { title: "", url: "https://", text: "Draft changes" }
    }

    assert_response :unprocessable_content
    assert_select "input[name='submission[title]'][value='']"
    assert_select "input[name='submission[url]'][value='https://']"
    assert_select "textarea[name='submission[text]']", text: "Draft changes"
    assert_select "li", text: /URL válida/
    assert_equal original_attributes, @submission.reload.attributes
  end

  test "editing rejects another submission URL after trimming and ignoring case" do
    sign_in_as_owner
    original_attributes = @submission.attributes
    duplicate_url = "  #{submissions(:two).url.upcase}  "
    patch submission_url(@submission), params: {
      submission: { title: "Changed title", url: duplicate_url, text: "Draft" }
    }

    assert_response :unprocessable_content
    assert_select "input[name='submission[title]'][value='Changed title']"
    assert_select "input[name='submission[url]'][value=?]", duplicate_url.strip
    assert_select "li", text: /already been taken/
    assert_equal original_attributes, @submission.reload.attributes
  end

  test "author can edit an Ask and change between Ask and URL submissions" do
    sign_in_as_owner
    patch submission_url(@submission), params: { submission: { url: "", text: "A question" } }
    assert_redirected_to submission_url(@submission)
    assert_equal "ask", @submission.reload.submission_type
    assert_nil @submission.url

    get edit_submission_url(@submission)
    assert_response :success
    assert_select "textarea[name='submission[text]']", text: "A question"

    patch submission_url(@submission), params: { submission: { text: "Updated question" } }
    assert_redirected_to submission_url(@submission)
    assert_equal "Updated question", @submission.reload.text

    patch submission_url(@submission), params: { submission: { url: "https://ask-edited.example.test" } }
    assert_redirected_to submission_url(@submission)
    assert_equal "url", @submission.reload.submission_type
  end

  test "deleting a submission removes all its comments replies and soft deleted comments only" do
    sign_in_as_owner
    parent = @submission.comments.create!(body: "Parent", user: users(:two))
    reply = @submission.comments.create!(body: "Reply", parent: parent, user: users(:one))
    @submission.comments.create!(body: "Nested reply", parent: reply, user: users(:two))
    parent.soft_delete!
    other_comment = submissions(:two).comments.create!(body: "Keep me", user: users(:two))

    assert_difference({ "Submission.count" => -1, "Comment.count" => -3 }) do
      delete submission_url(@submission)
    end

    assert_redirected_to submissions_url
    assert_not Comment.exists?(submission_id: @submission.id)
    assert_equal "Keep me", other_comment.reload.body
  end

  private

  def sign_in_as_owner
    OmniAuth.config.mock_auth[:github].uid = "github-submission-owner"
    users(:one).update!(provider: "github", uid: "github-submission-owner")
    sign_in
  end

  def sign_in
    get "/auth/github/callback"
  end
end
