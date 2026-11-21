# frozen_string_literal: true

require "sidekiq/api"
require "base64"

owner = User.find_by_email("owner@example.org")
raise "Owner is not active admin" unless owner&.admin? && owner.active? && owner.approved?
raise "Generated owner credential does not authenticate" unless owner.user_password.confirm_password?(ENV.fetch("DISCOURSE_ADMIN_PASSWORD"))
raise "Unexpected additional real users" unless User.real.count == 1

extensions = DB.query_single("SELECT extname FROM pg_extension")
raise "Missing required database extensions" unless %w[hstore pg_trgm vector].all? { |extension| extensions.include?(extension) }
raise "No Sidekiq process is registered" unless Sidekiq::ProcessSet.new.size.positive?

marker = "railway-smoke-persistence"
unless Topic.where(title: marker).exists?
  raise "Post did not survive recreation" if ENV["EXPECT_PERSISTED"] == "1"
  post = PostCreator.create!(owner, title: marker, raw: "A persistence check for the Railway Discourse package.", skip_validations: true)
  raise "Post was not saved" unless post.persisted?
end
raise "Persistent post is missing" unless Topic.where(title: marker).exists?

directory = Rails.root.join("public/uploads/default/original/1X")
FileUtils.mkdir_p(directory)
pixel = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
path = directory.join("railway-smoke.png")
if path.exist?
  raise "Upload bytes changed" unless path.binread == pixel
else
  raise "Upload did not survive recreation" if ENV["EXPECT_PERSISTED"] == "1"
  path.binwrite(pixel)
end
puts "PASS: owner credential, preserved users, database extensions, Sidekiq registration, post and upload persistence"
