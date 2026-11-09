require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-navigation",
      info: { nickname: "navigation_user", email: "navigation@example.com" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "anonymous menu links the first delivery pages and hides threads" do
    get root_url

    assert_response :success
    assert_select ".hn-header a.hn-logo[href=?]", root_path
    assert_select ".hn-nav" do
      assert_select "a[href=?]", newest_path, text: "new"
      assert_select "a[href=?]", comments_path, text: "comments"
      assert_select "a[href=?]", ask_path, text: "ask"
      assert_select "a[href=?]", submit_path, text: "submit"
      assert_select "a[href=?]", threads_path, count: 0
      assert_select "a[href='#']", count: 0
      assert_select "a", text: /\A(past|show|jobs)\z/, count: 0
    end
  end

  test "logged in menu also links threads" do
    sign_in
    get root_url

    assert_select ".hn-nav a[href=?]", threads_path, text: "threads"
  end

  test "every menu page loads for a logged in user" do
    sign_in

    [ root_path, newest_path, threads_path, comments_path, ask_path, submit_path ].each do |path|
      get path
      assert_response :success, "#{path} hauria de carregar"
    end
  end

  test "the current page is highlighted in the menu" do
    get ask_url

    assert_select ".hn-nav a.hn-nav-active", count: 1
    assert_select ".hn-nav a.hn-nav-active[href=?][aria-current=page]", ask_path
  end

  private

  def sign_in
    get "/auth/github/callback"
  end
end
