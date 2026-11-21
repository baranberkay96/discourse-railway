# frozen_string_literal: true

require "securerandom"
require "fileutils"

module RailwayConfig
  def self.plugin_names(root)
    Dir.children(root).select { |name| File.file?(File.join(root, name, "plugin.rb")) }.sort
  end

  def self.prune_plugins(root, allowed)
    Dir.children(root).filter_map do |name|
      path = File.join(root, name)
      next if allowed.include?(name) || (!File.directory?(path) && !File.symlink?(path))

      # Some container runtimes resurrect directories deleted by earlier image
      # layers. Remove only plugin entries absent from the build's exact list.
      # rm_rf removes a symlink itself, never the target outside this tree.
      FileUtils.rm_rf(path)
      name
    end
  end

  HOSTNAME = /\A(?=.{1,253}\z)[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i
  EMAIL = /\A[^\s@,]+@[^\s@,]+\.[^\s@,]+\z/

  def self.normalize(input, warn: ->(message) { Kernel.warn(message) })
    env = input.to_h.dup
    fallback = env["RAILWAY_PUBLIC_DOMAIN"].to_s
    fallback = "localhost" unless HOSTNAME.match?(fallback)
    hostname = env["DISCOURSE_HOSTNAME"].to_s.strip
    unless HOSTNAME.match?(hostname)
      warn.call("railway: invalid forum hostname; using Railway's domain or localhost") unless hostname.empty?
      hostname = fallback
    end
    env["DISCOURSE_HOSTNAME"] = hostname

    email = env["DISCOURSE_ADMIN_EMAIL"].to_s.strip
    unless email.bytesize <= 254 && EMAIL.match?(email)
      warn.call("railway: invalid admin email; using admin@example.com; update it after login")
      email = "admin@example.com"
    end
    env["DISCOURSE_ADMIN_EMAIL"] = email

    password = env["DISCOURSE_ADMIN_PASSWORD"].to_s
    if password.length < 15 || password.bytesize > 200
      warn.call("railway: unusable admin password; bootstrap will be locked; recover with rake admin:create in a Railway shell")
      env["DISCOURSE_ADMIN_PASSWORD"] = SecureRandom.hex(32)
      env["RAILWAY_ADMIN_LOCKED"] = "true"
    else
      env.delete("RAILWAY_ADMIN_LOCKED")
    end

    { "UNICORN_WORKERS" => 1..4, "UNICORN_SIDEKIQS" => 1..2 }.each do |key, range|
      raw = env.fetch(key, "1").to_s
      value = raw.match?(/\A\d+\z/) ? raw.to_i : 0
      unless range.cover?(value)
        warn.call("railway: invalid #{key}; using 1")
        value = 1
      end
      env[key] = value.to_s
    end
    env["PORT"] = "80"
    env["RAILS_ENV"] = "production"
    env["MIGRATE_ON_BOOT"] = "0"
    env["PRECOMPILE_ON_BOOT"] = "0"
    env
  end
end

if $PROGRAM_NAME == __FILE__
  plugin_list = "/opt/railway/plugins.list"
  if File.file?(plugin_list)
    RailwayConfig.prune_plugins("/var/www/discourse/plugins", File.readlines(plugin_list, chomp: true)).each do |name|
      warn "railway: removed obsolete image-layer plugin #{name}"
    end
  end
  normalized = RailwayConfig.normalize(ENV)
  ENV.delete("RAILWAY_ADMIN_LOCKED")
  ENV.update(normalized)
  exec "/sbin/boot"
end
