require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "karma adds submission and comment points" do
    user = User.create!(username: "karma_user")
    submission = Submission.create!(title: "Karma", user: user, points: 4)
    Comment.create!(submission: submission, user: user, body: "Hi", points: 2)

    assert_equal 6, user.karma
  end

  test "about is limited to 2000 characters" do
    user = users(:one)
    user.about = "a" * 2001

    assert_not user.valid?
    assert user.errors.of_kind?(:about, :too_long)
  end

  # test "the truth" do
  #   assert true
  # end

  test "creates a user from GitHub auth data" do
    auth = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-123",
      info: {
        nickname: "new_user",
        name: "New User",
        email: "new@example.com"
      }
    )

    assert_difference("User.count", 1) do
      @user = User.from_omniauth(auth)
    end

    assert_equal "github", @user.provider
    assert_equal "github-123", @user.uid
    assert_equal "new_user", @user.username
    assert_equal "new@example.com", @user.email
  end

  test "reuses an existing OAuth user" do
    auth = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-existing",
      info: {
        nickname: "existing_user",
        email: "existing@example.com"
      }
    )

    first_user = User.from_omniauth(auth)

    assert_no_difference("User.count") do
      second_user = User.from_omniauth(auth)
      assert_equal first_user.id, second_user.id
    end
  end

  test "adds a suffix when the OAuth username already exists" do
    User.create!(username: "collision_user", email: "existing@example.com")
    auth = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-collision",
      info: { nickname: "collision_user", email: "new@example.com" }
    )

    user = User.from_omniauth(auth)

    assert_equal "collision_user_2", user.username
  end

  test "recovers when a concurrent OAuth create wins the unique index" do
    existing_user = User.create!(
      provider: "github",
      uid: "github-concurrent",
      username: "concurrent_user",
      email: "existing@example.com"
    )
    auth = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-concurrent",
      info: { nickname: "concurrent_user", email: "new@example.com" }
    )
    pending_user = User.new

    original_find_or_initialize_by = User.method(:find_or_initialize_by)
    User.define_singleton_method(:find_or_initialize_by) { |_attributes| pending_user }

    pending_user.define_singleton_method(:save!) do
      raise ActiveRecord::RecordNotUnique
    end

    assert_equal existing_user, User.from_omniauth(auth)
  ensure
    User.define_singleton_method(:find_or_initialize_by, original_find_or_initialize_by)
  end

  test "retries after a username unique violation" do
    User.create!(username: "retry_user", email: "existing@example.com")
    auth = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "github-retry",
      info: { nickname: "retry_user", email: "retry@example.com" }
    )
    pending_users = [ User.new, User.new(provider: auth.provider, uid: auth.uid) ]
    original_find_or_initialize_by = User.method(:find_or_initialize_by)
    User.define_singleton_method(:find_or_initialize_by) { |_attributes| pending_users.shift }
    pending_users.first.define_singleton_method(:save!) do
      raise ActiveRecord::RecordNotUnique
    end

    user = User.from_omniauth(auth)

    assert_equal "retry_user_2", user.username
    assert_equal "github-retry", user.uid
  ensure
    User.define_singleton_method(:find_or_initialize_by, original_find_or_initialize_by)
  end
end
