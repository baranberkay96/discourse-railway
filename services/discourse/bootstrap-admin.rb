# frozen_string_literal: true

require "securerandom"

# SiteSetting works only after db:migrate. No web server starts before this file
# finishes, preventing a visitor from becoming the first owner.
SiteSetting.force_https = ENV.fetch("RAILWAY_FORCE_HTTPS", "true") != "false"

if User.real.exists?
  puts "railway: existing users preserved; admin credentials are not changed on redeploy"
else
  email = ENV.fetch("DISCOURSE_ADMIN_EMAIL")
  owner = User.new(
    email: email,
    username: UserNameSuggester.suggest(email),
    name: "Forum owner",
    password: ENV.fetch("DISCOURSE_ADMIN_PASSWORD"),
    admin: true,
    active: true,
    approved: true
  )

  # Apply Discourse's own validators, including its common-password list. Invalid
  # deploy-form values must not crash-loop or create an account with a weak key.
  owner.valid?
  if owner.errors.attribute_names.include?(:password) || owner.user_password.errors.any?
    owner.password = SecureRandom.hex(32)
    ENV["RAILWAY_ADMIN_LOCKED"] = "true"
    warn "railway: Discourse rejected the admin password; a random unknown password locks the owner"
  end
  owner.valid?
  if owner.errors.attribute_names.any? { |key| %i[email primary_email].include?(key) } || owner.primary_email.errors.any?
    owner.email = "admin@example.com"
    warn "railway: Discourse rejected the email; using admin@example.com"
  end
  owner.save!
  owner.activate
  owner.email_tokens.update_all(confirmed: true)
  owner.change_trust_level!(TrustLevel[4])
  puts "railway: first administrator created; use DISCOURSE_ADMIN_EMAIL and DISCOURSE_ADMIN_PASSWORD"
  if ENV["RAILWAY_ADMIN_LOCKED"] == "true"
    warn "railway: owner login is locked; recover in a Railway shell with rake admin:create, then set a strong password"
  end
end
