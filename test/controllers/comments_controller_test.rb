require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @submission = submissions(:one)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-comments-controller",
      info: { nickname: "comments_controller_user", email: "comments@example.com" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "shows recent comments and their submission links" do
    older = Comment.create!(submission: @submission, user: users(:one), body: "Comentari antic")
    newer = Comment.create!(submission: submissions(:two), user: users(:two), body: "Comentari recent")

    get comments_url

    assert_response :success
    assert_select ".recent-comment", 2
    assert_select "#comment_#{older.id} .comment-body", text: "Comentari antic"
    assert_select "#comment_#{newer.id} .comment-body", text: "Comentari recent"
    assert_select "#comment_#{newer.id} a[href='#{submission_path(newer.submission, anchor: "comments")}']",
                  text: newer.submission.title
    assert_operator response.body.index("Comentari recent"), :<, response.body.index("Comentari antic")
  end

  test "shows a comment and its complete descendant subtree" do
    root = Comment.create!(submission: @submission, user: users(:one), body: "Arrel del fil")
    selected = Comment.create!(
      submission: @submission, user: users(:two), body: "Comentari seleccionat", parent: root
    )
    child = Comment.create!(
      submission: @submission, user: users(:one), body: "Resposta filla", parent: selected
    )
    grandchild = Comment.create!(
      submission: @submission, user: users(:two), body: "Resposta neta", parent: child
    )

    get submission_comment_url(@submission, selected)

    assert_response :success
    assert_select "#comment_#{selected.id}"
    assert_select "#comment_#{child.id}"
    assert_select "#comment_#{grandchild.id}"
    assert_select "#comment_#{root.id}", 0
  end

  test "does not show a comment belonging to another submission" do
    other_comment = Comment.create!(
      submission: submissions(:two), user: users(:two), body: "Comentari d'una altra publicació"
    )

    get submission_comment_url(@submission, other_comment)

    assert_response :not_found
  end

  test "shows the submission comment tree and a login prompt to anonymous visitors" do
    comment = Comment.create!(submission: @submission, user: users(:one), body: "Comentari visible")

    get submission_url(@submission)

    assert_response :success
    assert_select "#comments"
    assert_select "#comment_#{comment.id}"
    assert_select ".comment-login-prompt", text: /cal iniciar sessió/
    assert_select ".comment-form", 0
  end

  test "links the navigation to the recent comments page" do
    get submissions_url

    assert_response :success
    assert_select ".hn-nav a[href=?]", comments_path, text: "comentaris"
  end

  test "creates a comment as the logged in user and ignores a submitted user id" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")

    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission), params: {
        comment: { body: "Comentari meu", user_id: users(:two).id }
      }
    end

    comment = Comment.last
    assert_equal logged_in_user, comment.user
    assert_redirected_to submission_url(@submission, anchor: "comment_#{comment.id}")
  end

  test "does not allow anonymous users to create comments" do
    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: {
        comment: { body: "Comentari anònim" }
      }
    end

    assert_redirected_to root_url
    assert_equal "Cal iniciar sessió per continuar.", flash[:alert]
  end

  test "renders the logged in user in the comment form without an author selector" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")

    get submission_url(@submission)

    assert_response :success
    assert_select ".comment-current-user", text: /#{logged_in_user.username}/
    assert_select "select[name='comment[user_id]']", 0
    assert_select "input[name='comment[user_id]']", 0
  end

  test "creates a comment with a JSON response and the logged in user" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")

    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission, format: :json), params: {
        comment: { body: "Comentari JSON" }
      }
    end

    assert_response :created
    response_comment = response.parsed_body
    assert_equal "Comentari JSON", response_comment["body"]
    assert_equal @submission.id, response_comment["submission_id"]
    assert_equal logged_in_user.id, response_comment["user_id"]
    assert_nil response_comment["parent_id"]
  end

  test "creates a reply at any nesting depth as the logged in user" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Pare")
    child = Comment.create!(submission: @submission, user: users(:two), body: "Fill", parent: parent)

    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission), params: {
        comment: { body: "Resposta niada", parent_id: child.id }
      }
    end

    reply = Comment.last
    assert_equal child, reply.parent
    assert_equal logged_in_user, reply.user
    assert_equal @submission, reply.submission

    get submission_url(@submission)
    assert_response :success
    assert_select "#comment_#{reply.id} .comment-body", text: "Resposta niada"
  end

  test "includes the parent id in the reply form" do
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Comentari pare")

    get new_submission_comment_url(@submission, parent_id: parent.id)

    assert_response :success
    assert_select ".reply-context .comment-body", text: "Comentari pare"
    assert_select "button", text: /Inicia sessió amb GitHub/
  end

  test "renders a reply form for the logged in user" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Comentari pare")

    get new_submission_comment_url(@submission, parent_id: parent.id)

    assert_response :success
    assert_select ".comment-current-user", text: /#{logged_in_user.username}/
    assert_select "input[type=hidden][name='comment[parent_id]'][value='#{parent.id}']"
  end

  test "returns not found when the reply page parent belongs to another submission" do
    other_comment = Comment.create!(
      submission: submissions(:two), user: users(:two), body: "D'una altra publicació"
    )

    get new_submission_comment_url(@submission, parent_id: other_comment.id)

    assert_response :not_found
  end

  test "returns bad request when the reply page has no parent id" do
    get new_submission_comment_url(@submission)

    assert_response :bad_request
  end

  test "renders validation errors when a comment is blank" do
    sign_in

    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: {
        comment: { body: "" }
      }
    end

    assert_response :unprocessable_content
    assert_select ".comment-errors", text: /no s'ha pogut publicar/i
  end

  test "returns validation errors as JSON when a comment is blank" do
    sign_in

    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission, format: :json), params: {
        comment: { body: "" }
      }
    end

    assert_response :unprocessable_content
    assert response.parsed_body.key?("body")
  end

  test "renders a reply form with its parent when a reply is invalid" do
    sign_in
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Comentari pare")

    post submission_comments_url(@submission), params: {
      comment: { body: "", parent_id: parent.id }
    }

    assert_response :unprocessable_content
    assert_select ".reply-context .comment-body", text: "Comentari pare"
    assert_select "input[type=hidden][name='comment[parent_id]'][value='#{parent.id}']"
    assert_select ".comment-errors", text: /no s'ha pogut publicar/i
  end

  test "does not allow replying to a comment from another submission" do
    sign_in
    other_comment = Comment.create!(
      submission: submissions(:two), user: users(:two), body: "D'una altra publicació"
    )

    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: {
        comment: { body: "Resposta", parent_id: other_comment.id }
      }
    end

    assert_response :not_found
  end

  test "allows the author to edit a comment and reports the saved changes" do
    sign_in
    author = User.find_by!(uid: "github-comments-controller")
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Comentari pare")
    comment = Comment.create!(submission: @submission, user: author, body: "Text original", parent: parent)

    get submission_url(@submission)
    assert_response :success
    assert_select "#comment_#{comment.id} a.comment-action", text: "Edita"
    assert_select "#comment_#{comment.id} button.comment-action", text: "Elimina"

    get edit_submission_comment_url(@submission, comment)
    assert_response :success
    assert_select "textarea[name='comment[body]']", text: "Text original"

    patch submission_comment_url(@submission, comment), params: {
      comment: { body: "Text editat", user_id: users(:two).id }
    }

    assert_redirected_to submission_comment_url(@submission, comment)
    assert_equal "Canvis desats.", flash[:notice]
    assert_equal "Text editat", comment.reload.body
    assert_equal author, comment.user
    assert_equal parent, comment.parent

    follow_redirect!
    assert_select "#comment_#{comment.id} .comment-body", text: "Text editat"
  end

  test "does not let another user edit or delete a comment" do
    sign_in
    comment = Comment.create!(submission: @submission, user: users(:one), body: "Comentari d'un altre")

    get edit_submission_comment_url(@submission, comment)
    assert_response :forbidden

    patch submission_comment_url(@submission, comment), params: {
      comment: { body: "Canvi no autoritzat" }
    }
    assert_response :forbidden

    delete submission_comment_url(@submission, comment)
    assert_response :forbidden
    assert_equal "Comentari d'un altre", comment.reload.body
    assert_not_predicate comment, :deleted?
  end

  test "does not let anonymous users edit or delete comments" do
    comment = Comment.create!(submission: @submission, user: users(:one), body: "Comentari existent")

    get edit_submission_comment_url(@submission, comment)
    assert_redirected_to root_url

    delete submission_comment_url(@submission, comment)
    assert_redirected_to root_url
    assert_equal "Comentari existent", comment.reload.body
    assert_not_predicate comment, :deleted?
  end

  test "deletes own comment text but keeps its replies in the thread" do
    sign_in
    author = User.find_by!(uid: "github-comments-controller")
    ancestor = Comment.create!(submission: @submission, user: users(:one), body: "Comentari arrel")
    comment = Comment.create!(
      submission: @submission, user: author, body: "Text que s'eliminarà", parent: ancestor
    )
    reply = Comment.create!(submission: @submission, user: users(:one), body: "Resposta conservada", parent: comment)

    assert_no_difference("Comment.count") do
      delete submission_comment_url(@submission, comment)
    end

    assert_redirected_to submission_comment_url(@submission, comment)
    assert_equal "Comentari eliminat. Les respostes es conserven.", flash[:notice]
    assert_empty comment.reload.body
    assert_predicate comment, :deleted?
    assert_equal ancestor, comment.parent
    assert_equal comment, reply.reload.parent

    follow_redirect!
    assert_select "#comment_#{comment.id} .comment-deleted", text: "[Comentari eliminat]"
    assert_select "#comment_#{reply.id} .comment-body", text: "Resposta conservada"
    assert_select "#comment_#{comment.id} .comment-action", 0
    assert_no_match "Text que s'eliminarà", response.body
  end

  test "rejects editing a comment with blank text" do
    sign_in
    author = User.find_by!(uid: "github-comments-controller")
    comment = Comment.create!(submission: @submission, user: author, body: "Text original")

    patch submission_comment_url(@submission, comment), params: {
      comment: { body: "" }
    }

    assert_response :unprocessable_content
    assert_select ".comment-errors"
    assert_equal "Text original", comment.reload.body
  end

  test "redirects anonymous users away from threads" do
    get threads_url

    assert_redirected_to root_url
    assert_equal "Cal iniciar sessió per continuar.", flash[:alert]
  end

  test "shows the logged in user's comments with their replies in threads" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")
    mine = Comment.create!(submission: @submission, user: logged_in_user, body: "El meu comentari")
    reply = Comment.create!(
      submission: @submission, user: users(:two), body: "Resposta d'un altre", parent: mine
    )
    other = Comment.create!(submission: submissions(:two), user: users(:two), body: "Comentari aliè")

    get threads_url

    assert_response :success
    assert_select "#comment_#{mine.id}"
    assert_select "#comment_#{mine.id} #comment_#{reply.id}"
    assert_select "#comment_#{other.id}", 0
  end

  test "does not repeat own replies or show deleted own comments in threads" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")
    root = Comment.create!(submission: @submission, user: logged_in_user, body: "Arrel pròpia")
    own_reply = Comment.create!(
      submission: @submission, user: logged_in_user, body: "Resposta pròpia", parent: root
    )
    deleted = Comment.create!(submission: @submission, user: logged_in_user, body: "Comentari esborrat")
    deleted.soft_delete!

    get threads_url

    assert_response :success
    assert_select "#comment_#{own_reply.id}", 1
    assert_select "#comment_#{deleted.id}", 0
  end

  test "does not repeat own comments nested at any depth under another own comment in threads" do
    sign_in
    logged_in_user = User.find_by!(uid: "github-comments-controller")
    a = Comment.create!(submission: @submission, user: logged_in_user, body: "A propi")
    b = Comment.create!(submission: @submission, user: users(:two), body: "B d'un altre", parent: a)
    c = Comment.create!(submission: @submission, user: logged_in_user, body: "C propi", parent: b)

    deleted_root = Comment.create!(submission: @submission, user: logged_in_user, body: "Arrel esborrada")
    other_reply = Comment.create!(
      submission: @submission, user: users(:two), body: "Resposta d'un altre", parent: deleted_root
    )
    under_deleted = Comment.create!(
      submission: @submission, user: logged_in_user, body: "Sota un esborrat", parent: other_reply
    )
    deleted_root.soft_delete!

    get threads_url

    assert_response :success
    assert_select "#comment_#{c.id}", 1
    assert_select "#comment_#{a.id} #comment_#{b.id} #comment_#{c.id}"
    assert_select "#comment_#{under_deleted.id}", 1
    assert_select "#comment_#{deleted_root.id}", 0
  end

  private

  def sign_in
    get "/auth/github/callback"
  end
end
