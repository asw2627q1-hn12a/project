require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  test "accepts full HTTP and HTTPS URLs" do
    [ "http://example.net/path?q=1#section", "https://example.net", "HTTPS://EXAMPLE.NET" ].each do |url|
      submission = Submission.new(title: "A link", url: url, user: users(:one))
      assert_predicate submission, :valid?, "Expected #{url} to be valid"
    end
  end

  test "rejects malformed URLs and URLs embedded in other text" do
    [ "https://", "http:///path", "https:example.net", "ftp://example.net", "javascript:alert(1)",
      "prefix https://example.net", "https://example.net trailing", "https://exa mple.net" ].each do |url|
      submission = Submission.new(title: "A link", url: url, user: users(:one))
      assert_not submission.valid?, "Expected #{url} to be invalid"
      assert_not_empty submission.errors[:url]
    end
  end

  test "URL uniqueness ignores case and surrounding spaces while allowing the same record" do
    submission = submissions(:one)
    submission.url = "  #{submission.url.upcase}  "
    assert_predicate submission, :valid?

    duplicate = Submission.new(title: "Duplicate", url: submission.url, user: users(:two))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:url], "has already been taken"
  end

  test "multiple Ask submissions can have blank URLs" do
    2.times do
      submission = Submission.create!(title: "A question", url: "  ", text: "Question text", user: users(:one))
      assert_equal "ask", submission.submission_type
      assert_nil submission.url
    end
  end
end
