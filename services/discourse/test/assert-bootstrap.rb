# frozen_string_literal: true

# Run with `bundle exec rails runner` inside the disposable smoke environment.
# Rollbacks keep the normal owner and persistence fixtures unchanged.
original_env = ENV.to_h
baseline = User.real.count

begin
  [
    ["a" * 65 + "@example.org", ENV.fetch("DISCOURSE_ADMIN_PASSWORD"), "admin@example.com", true],
    ["owner@bad..example", ENV.fetch("DISCOURSE_ADMIN_PASSWORD"), "admin@example.com", true],
    ["newowner@example.org", "a" * 20, "newowner@example.org", false]
  ].each do |email, password, expected_email, authenticates|
    ActiveRecord::Base.transaction(requires_new: true) do
      User.singleton_class.alias_method(:railway_original_real, :real)
      User.define_singleton_method(:real) { railway_original_real.none }
      begin
        ENV["DISCOURSE_ADMIN_EMAIL"] = email
        ENV["DISCOURSE_ADMIN_PASSWORD"] = password
        load "/opt/railway/bootstrap-admin.rb"
        account = User.find_by_email(expected_email)
        raise "Fallback account missing" unless account&.admin? && account.active?
        confirmed = account.user_password.confirm_password?(password)
        raise "Password fallback did not fail closed" unless confirmed == authenticates
      ensure
        User.singleton_class.alias_method(:real, :railway_original_real)
        User.singleton_class.remove_method(:railway_original_real)
      end
      raise ActiveRecord::Rollback
    end
    ENV.replace(original_env)
  end

  ENV["DISCOURSE_ADMIN_EMAIL"] = "different@example.org"
  load "/opt/railway/bootstrap-admin.rb"
  raise "Existing account was replaced" unless User.real.count == baseline && User.find_by_email("different@example.org").nil?
  puts "PASS: invalid associated emails fall back, rejected passwords lock login, existing owners survive"
ensure
  ENV.replace(original_env)
end
