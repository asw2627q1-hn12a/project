require "test_helper"

class UserApiKeyTest < ActiveSupport::TestCase
  test "new users receive different persisted random keys" do
    first = User.create!(username: "first_api_user")
    second = User.create!(username: "second_api_user")

    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{32}\z/, first.api_key)
    assert_not_equal first.api_key, second.api_key
    assert_equal first.api_key, first.reload.api_key
  end

  test "updating and reloading an existing user preserves the key" do
    user = users(:one)
    original_key = user.api_key

    user.update!(about: "Updated profile")

    assert_equal original_key, user.reload.api_key
  end

  test "OAuth registration and subsequent logins preserve the key" do
    auth = OmniAuth::AuthHash.new(
      provider: "github", uid: "api-key-user",
      info: { nickname: "api_key_user", email: "api@example.test" }
    )
    user = User.from_omniauth(auth)
    original_key = user.api_key
    assert original_key.present?

    auth.info.email = "updated@example.test"
    signed_in = User.from_omniauth(auth)

    assert_equal user.id, signed_in.id
    assert_equal original_key, signed_in.reload.api_key
    assert_equal "updated@example.test", signed_in.email
  end

  test "model rejects duplicate and missing keys" do
    duplicate = User.new(username: "duplicate_api_user", api_key: users(:one).api_key)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:api_key, :taken)

    user = users(:one)
    user.api_key = nil
    assert_not user.valid?
    assert user.errors.of_kind?(:api_key, :blank)
  end

  test "database rejects duplicate keys without validations" do
    assert_raises ActiveRecord::RecordNotUnique do
      User.transaction(requires_new: true) do
        users(:two).update_columns(api_key: users(:one).api_key)
      end
    end
  end

  test "database rejects null keys without validations" do
    assert_raises ActiveRecord::NotNullViolation do
      User.transaction(requires_new: true) do
        users(:one).update_columns(api_key: nil)
      end
    end
  end

  test "generic serialization excludes the key even when explicitly selected" do
    user = users(:one)

    assert_not user.serializable_hash.key?("api_key")
    assert_not user.as_json.key?("api_key")
    assert_not user.as_json(only: [ :id, :api_key ]).key?("api_key")
    assert_equal user.id, user.as_json.fetch("id")
  end

  test "inspection and configured parameter filters hide the key" do
    user = users(:one)
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_not_includes user.inspect, user.api_key
    assert_equal "[FILTERED]", filter.filter("api_key" => user.api_key).fetch("api_key")
    assert_equal "[FILTERED]", filter.filter("HTTP_X_API_KEY" => user.api_key).fetch("HTTP_X_API_KEY")
  end

  test "SQL logs redact generated keys" do
    output = StringIO.new
    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)

    user = User.create!(username: "logged_api_user")

    assert_includes output.string, "[FILTERED]"
    assert_not_includes output.string, user.api_key
  ensure
    ActiveRecord::Base.logger = previous_logger
  end
end
