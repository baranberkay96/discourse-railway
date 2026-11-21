FROM ghcr.io/railwayapp-templates/postgres-ssl:18@sha256:4fc833b43d2aaf6ecc9b18615f5533602b723a32d0e2efe2dae8ca0f7217c863

# The Railway image includes pgvector. Initialize the same extensions that
# Discourse's upstream postgres.template.yml installs, before app migrations.
COPY --chmod=0755 10-discourse.sql /docker-entrypoint-initdb.d/10-discourse.sql
