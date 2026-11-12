require "test_helper"
require "erb"
require "yaml"

class DatabaseConfigurationTest < ActiveSupport::TestCase
  test "production uses external PostgreSQL for primary and all Solid databases" do
    with_database_urls("DATABASE_URL" => "postgresql://user:password@localhost/hn12a?sslmode=require") do
      production = read_configuration.fetch("production")

      %w[primary cache queue cable].each do |name|
        config = production.fetch(name)
        suffix = name == "primary" ? "" : "_#{name}"
        assert_equal "postgresql", config.fetch("adapter")
        assert_equal "postgresql://user:password@localhost/hn12a#{suffix}?sslmode=require", config.fetch("url")
        assert_equal false, config.fetch("seeds")
      end
    end
  end

  test "auxiliary database URLs can be configured independently" do
    with_database_urls(
      "DATABASE_URL" => "postgresql://localhost/primary",
      "CACHE_DATABASE_URL" => "postgresql://localhost/cache",
      "QUEUE_DATABASE_URL" => "postgresql://localhost/queue",
      "CABLE_DATABASE_URL" => "postgresql://localhost/cable"
    ) do
      production = read_configuration.fetch("production")
      %w[cache queue cable].each do |name|
        assert_equal "postgresql://localhost/#{name}", production.fetch(name).fetch("url")
      end
    end
  end

  private

  def read_configuration
    YAML.safe_load(ERB.new(Rails.root.join("config/database.yml").read).result, aliases: true)
  end

  def with_database_urls(values)
    keys = %w[DATABASE_URL CACHE_DATABASE_URL QUEUE_DATABASE_URL CABLE_DATABASE_URL]
    previous = ENV.to_h.slice(*keys)
    keys.each { |key| ENV.delete(key) }
    ENV.update(values)
    yield
  ensure
    keys.each { |key| ENV.delete(key) }
    ENV.update(previous)
  end
end
