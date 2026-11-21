# frozen_string_literal: true

require "securerandom"
require "fileutils"
require "find"
require "set"

module RailwayConfig
  def self.file_manifest(root)
    Find.find(root).filter_map { |path| path.delete_prefix("#{root}/") unless path == root }.sort
  end

  def self.prune_tree(root, manifest)
    allowed = manifest.to_set
    removed = []
    visit = lambda do |directory|
      Dir.children(directory).each do |name|
        path = File.join(directory, name)
        relative = path.delete_prefix("#{root}/")
        if !allowed.include?(relative)
          # Remove obsolete image files only. Never traverse volume symlinks.
          FileUtils.rm_rf(path)
          removed << relative
        elsif File.directory?(path) && !File.symlink?(path)
          visit.call(path)
        end
      end
    end
    visit.call(root)
    removed
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
  manifest = "/opt/railway/application.list"
  if File.file?(manifest)
    removed = RailwayConfig.prune_tree("/var/www/discourse", File.readlines(manifest, chomp: true))
    warn "railway: removed #{removed.length} obsolete image-layer paths" unless removed.empty?
  end
  normalized = RailwayConfig.normalize(ENV)
  ENV.delete("RAILWAY_ADMIN_LOCKED")
  ENV.update(normalized)
  exec "/sbin/boot"
end
