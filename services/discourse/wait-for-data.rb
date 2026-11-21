# frozen_string_literal: true

require "pg"
require "redis"

begin
  connection = PG.connect(
    host: ENV.fetch("DISCOURSE_DB_HOST"),
    port: ENV.fetch("DISCOURSE_DB_PORT", "5432"),
    dbname: ENV.fetch("DISCOURSE_DB_NAME"),
    user: ENV.fetch("DISCOURSE_DB_USERNAME"),
    password: ENV.fetch("DISCOURSE_DB_PASSWORD"),
    connect_timeout: 3
  )
  connection.exec("SELECT 1")
  connection.close
  redis = Redis.new(
    host: ENV.fetch("DISCOURSE_REDIS_HOST"),
    port: ENV.fetch("DISCOURSE_REDIS_PORT", "6379").to_i,
    password: ENV.fetch("DISCOURSE_REDIS_PASSWORD"),
    connect_timeout: 3,
    read_timeout: 3
  )
  raise "Redis not ready" unless redis.ping == "PONG"
  redis.close
rescue StandardError => error
  # Connection exceptions can include credentials; never emit their messages.
  warn "railway: data service not ready (#{error.class})"
  exit 1
end
