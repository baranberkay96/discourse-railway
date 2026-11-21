# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../railway-config"

class RailwayConfigTest < Minitest::Test
  def test_manifest_removes_resurrected_files_inside_existing_directories
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p([File.join(root, "lib"), File.join(root, "plugins/blog")])
      File.write(File.join(root, "plugins/blog", "assets.js"), "// current assets")
      manifest = RailwayConfig.file_manifest(root)
      File.write(File.join(root, "plugins/blog", "plugin.rb"), "raise :obsolete")
      File.write(File.join(root, "lib", "html_to_markdown.rb"), "require 'removed_gem'")
      assert_equal %w[lib/html_to_markdown.rb plugins/blog/plugin.rb], RailwayConfig.prune_tree(root, manifest).sort
      assert File.file?(File.join(root, "plugins/blog/assets.js"))
    end
  end

  def test_manifest_cleanup_preserves_volume_symlinks_without_traversing_targets
    Dir.mktmpdir do |directory|
      root = File.join(directory, "app")
      outside = File.join(directory, "outside")
      FileUtils.mkdir_p([File.join(root, "current"), outside])
      File.symlink(outside, File.join(root, "log"))
      manifest = RailwayConfig.file_manifest(root)
      File.write(File.join(outside, "keep"), "persistent")
      FileUtils.mkdir_p(File.join(root, "obsolete"))
      File.symlink(outside, File.join(root, "stale-link"))
      removed = RailwayConfig.prune_tree(root, manifest)
      assert_equal %w[obsolete stale-link], removed.sort
      assert File.directory?(File.join(root, "current"))
      refute File.exist?(File.join(root, "obsolete"))
      assert_equal "persistent", File.read(File.join(outside, "keep"))
    end
  end

  def normalize(overrides = {})
    warnings = []
    input = {
      "RAILWAY_PUBLIC_DOMAIN" => "forum.up.railway.app",
      "DISCOURSE_ADMIN_EMAIL" => "owner@example.org",
      "DISCOURSE_ADMIN_PASSWORD" => "dK28rN7bQ6xM4zP9wF3sT5vH"
    }.merge(overrides)
    [RailwayConfig.normalize(input, warn: ->(message) { warnings << message }), warnings]
  end

  def test_valid_owner_and_custom_domain_are_preserved
    config, warnings = normalize("DISCOURSE_HOSTNAME" => "community.example.org")
    assert_equal "community.example.org", config["DISCOURSE_HOSTNAME"]
    assert_equal "owner@example.org", config["DISCOURSE_ADMIN_EMAIL"]
    assert_equal "dK28rN7bQ6xM4zP9wF3sT5vH", config["DISCOURSE_ADMIN_PASSWORD"]
    assert_empty warnings
  end

  def test_bad_email_and_host_fall_back_without_shell_injection
    config, warnings = normalize("DISCOURSE_HOSTNAME" => "https://evil.test/\nlisten 1;", "DISCOURSE_ADMIN_EMAIL" => "bad\naddress")
    assert_equal "forum.up.railway.app", config["DISCOURSE_HOSTNAME"]
    assert_equal "admin@example.com", config["DISCOURSE_ADMIN_EMAIL"]
    assert_equal 2, warnings.size
    refute_includes warnings.join, "evil.test"
  end

  def test_missing_railway_domain_uses_localhost
    config, = normalize("RAILWAY_PUBLIC_DOMAIN" => nil, "DISCOURSE_HOSTNAME" => "")
    assert_equal "localhost", config["DISCOURSE_HOSTNAME"]
  end

  def test_unusable_password_locks_bootstrap_without_logging_a_secret
    ["", "short", "x" * 301].each do |password|
      config, warnings = normalize("DISCOURSE_ADMIN_PASSWORD" => password)
      assert_equal "true", config["RAILWAY_ADMIN_LOCKED"]
      assert_match(/\A[a-f0-9]{64}\z/, config["DISCOURSE_ADMIN_PASSWORD"])
      refute_includes warnings.join, config["DISCOURSE_ADMIN_PASSWORD"]
      assert_match(/recover/i, warnings.join)
    end
  end

  def test_worker_counts_are_bounded_and_invalid_values_do_not_break_boot
    config, = normalize("UNICORN_WORKERS" => "0", "UNICORN_SIDEKIQS" => "999", "PORT" => "nonsense")
    assert_equal "1", config["UNICORN_WORKERS"]
    assert_equal "1", config["UNICORN_SIDEKIQS"]
    assert_equal "80", config["PORT"]
    config, = normalize("UNICORN_WORKERS" => "2")
    assert_equal "2", config["UNICORN_WORKERS"]
  end
end
