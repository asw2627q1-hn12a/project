require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @submission = submissions(:one)
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
    assert_select "#comment_#{newer.id} .recent-comment-context", text: /Fil sencer/
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
    assert_select ".comment-submission", text: /Publicació:/
    assert_select ".comment-submission a[href=?]", submission_path(@submission, anchor: "comments"),
                  text: @submission.title
    assert_select "#comment_#{selected.id}"
    assert_select "#comment_#{child.id}"
    assert_select "#comment_#{grandchild.id}"
    assert_select "#comment_#{root.id}", 0
  end

  test "does not show a comment belonging to another submission" do
    other_comment = Comment.create!(
      submission: submissions(:two), user: users(:two), body: "Comentari d'una altra submission"
    )

    get submission_comment_url(@submission, other_comment)

    assert_response :not_found
  end

  test "links the navigation to the recent comments page" do
    get submissions_url

    assert_response :success
    assert_select ".hn-nav a[href=?]", comments_path, text: "comentaris"
  end

  test "creates and displays a top-level comment" do
    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission), params: {
        comment: { body: "Comentari inicial", user_id: users(:one).id }
      }
    end

    comment = Comment.last
    assert_equal @submission, comment.submission
    assert_nil comment.parent
    assert_redirected_to submission_url(@submission, anchor: "comment_#{comment.id}")
    assert_equal "Comentari publicat.", flash[:notice]
    follow_redirect!
    assert_select ".comment-body", text: "Comentari inicial"
  end

  test "creates a comment with a JSON response" do
    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission, format: :json), params: {
        comment: { body: "Comentari JSON", user_id: users(:one).id }
      }
    end

    assert_response :created
    response_comment = response.parsed_body
    assert_equal "Comentari JSON", response_comment["body"]
    assert_equal @submission.id, response_comment["submission_id"]
    assert_nil response_comment["parent_id"]
  end

  test "creates a reply at any nesting depth" do
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Pare")
    grandparent = Comment.create!(
      submission: @submission, user: users(:one), body: "Fill", parent: parent
    )

    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission), params: {
        comment: { body: "Resposta niada", user_id: users(:two).id, parent_id: grandparent.id }
      }
    end

    reply = Comment.last
    assert_equal grandparent, reply.parent
    assert_equal @submission, reply.submission
    assert_equal parent, grandparent.parent

    get submission_url(@submission)
    assert_response :success
    assert_select "#comment_#{parent.id}"
    assert_select "#comment_#{grandparent.id}"
    assert_select "#comment_#{reply.id} .comment-body", text: "Resposta niada"
  end

  test "includes the parent id in the reply form" do
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Comentari pare")

    get new_submission_comment_url(@submission, parent_id: parent.id)

    assert_response :success
    assert_select "input[type=hidden][name='comment[parent_id]'][value='#{parent.id}']"
    assert_select ".reply-context .comment-body", text: "Comentari pare"
  end

  test "links each comment to its dedicated reply page" do
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Comentari pare")

    get submission_url(@submission)

    assert_response :success
    assert_select "#comments"
    assert_select "input[type=submit][value='Publica el comentari']"
    assert_select "a.comment-reply[href=?]", new_submission_comment_path(@submission, parent_id: parent.id), text: "Respon"
    assert_select "#comment_#{parent.id} .comment-meta", text: /menys d'un minut/
  end

  test "returns not found when the reply page parent belongs to another submission" do
    other_submission_comment = Comment.create!(
      submission: submissions(:two), user: users(:two), body: "D'una altra submission"
    )

    get new_submission_comment_url(@submission, parent_id: other_submission_comment.id)

    assert_response :not_found
  end

  test "returns bad request when the reply page has no parent id" do
    get new_submission_comment_url(@submission)

    assert_response :bad_request
  end

  test "renders validation errors when a comment is blank" do
    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: {
        comment: { body: "", user_id: users(:one).id }
      }
    end

    assert_response :unprocessable_content
    assert_select ".comment-errors", text: /no s'ha pogut publicar/i
  end

  test "returns validation errors as JSON when a comment is blank" do
    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission, format: :json), params: {
        comment: { body: "", user_id: users(:one).id }
      }
    end

    assert_response :unprocessable_content
    assert response.parsed_body.key?("body")
  end

  test "renders a reply form with its parent when a reply is invalid" do
    parent = Comment.create!(submission: @submission, user: users(:one), body: "Comentari pare")

    post submission_comments_url(@submission), params: {
      comment: { body: "", user_id: users(:one).id, parent_id: parent.id }
    }

    assert_response :unprocessable_content
    assert_select ".reply-context .comment-body", text: "Comentari pare"
    assert_select "input[type=hidden][name='comment[parent_id]'][value='#{parent.id}']"
    assert_select "input[type=submit][value='Publica la resposta']"
    assert_select ".comment-errors", text: /no s'ha pogut publicar/i
  end

  test "does not allow replying to a comment from another submission" do
    other_submission_comment = Comment.create!(
      submission: submissions(:two), user: users(:two), body: "D'una altra submission"
    )

    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: {
        comment: { body: "Resposta", user_id: users(:one).id, parent_id: other_submission_comment.id }
      }
    end

    assert_response :not_found
  end
end
