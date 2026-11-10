require "application_system_test_case"

class FavoritesSystemTest < ApplicationSystemTestCase
  setup do
    @submission = submissions(:one)
    @comment = @submission.comments.create!(user: users(:one), body: "Save this comment")
    @user = users(:two)
    @user.update!(provider: "github", uid: "favorites-system-user")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: @user.uid, info: { nickname: @user.username }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end

  test "favorite a submission beside its title and remove it after reloading" do
    page.current_window.resize_to(1400, 1000)
    visit "/auth/github/callback"
    visit news_url
    assert_no_selector "form.favorite-form"
    visit submission_url(@submission)
    control = find(".submission-title-row form[action='#{submission_favorite_path(@submission)}'] button")
    control.hover
    assert_selector "[role=tooltip]", text: "Add to favorites"
    page.save_screenshot(Rails.root.join("tmp/favorite-star-desktop.png"))
    within "form[action='#{submission_favorite_path(@submission)}']" do
      find("button[aria-label=favorite]").click
      assert_selector "button[aria-label=unfavorite][aria-pressed=true] svg[fill=currentColor]"
    end
    find("form[action='#{submission_favorite_path(@submission)}'] button").send_keys(:tab)
    find("form[action='#{submission_favorite_path(@submission)}'] button").send_keys([ :shift, :tab ])
    assert_selector "[role=tooltip]", text: "Remove from favorites"
    page.current_window.resize_to(390, 844)
    page.save_screenshot(Rails.root.join("tmp/favorite-star-mobile.png"))
    visit submission_url(@submission)
    within "form[action='#{submission_favorite_path(@submission)}']" do
      assert_selector "button[aria-label=unfavorite]"
      find("button[aria-label=unfavorite]").click
      assert_selector "button[aria-label=favorite]"
    end
    assert_not @user.submission_favorites.exists?(submission: @submission)
  end

  test "favorite a reply and remove it from its thread after reloading" do
    page.current_window.resize_to(1400, 1000)
    reply = @comment.replies.create!(user: users(:one), submission: @submission, body: "Save this reply")
    path = submission_comment_favorite_path(@submission, reply)
    visit "/auth/github/callback"
    visit submission_url(@submission)
    within "form[action='#{path}']" do
      find("button[aria-label=favorite]").hover
    end
    assert_selector "#comment_#{reply.id}_favorite_tooltip", text: "Add to favorites"
    within "form[action='#{path}']" do
      find("button[aria-label=favorite]").click
      assert_selector "button[aria-label=unfavorite] svg[fill=currentColor]"
    end
    visit submission_comment_url(@submission, reply)
    within "form[action='#{path}']" do
      assert_selector "button[aria-label=unfavorite]"
      find("button[aria-label=unfavorite]").click
      assert_selector "button[aria-label=favorite] svg[fill=none]"
    end
    assert_not @user.comment_favorites.exists?(comment: reply)
    page.save_screenshot(Rails.root.join("tmp/favorites-desktop.png"))
    page.current_window.resize_to(390, 844)
    page.save_screenshot(Rails.root.join("tmp/favorites-mobile.png"))
  end
end
