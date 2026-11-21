# Source and licence notice

Checked 2026-11-21. This is an independently maintained community deployment.

## Discourse

- Source: https://github.com/discourse/discourse
- Official image: https://hub.docker.com/r/discourse/discourse/
- Pin: `discourse/discourse:2026.7.6@sha256:f8a7a3c0f7e5ee6c66e3d8b24d55ba860ed8f7f265384aba81a3c440b008108a`.
- Application licence: GPL-2.0, retained in `LICENSES/Discourse-GPL-2.0.txt`.
- Image support notice says the prebuilt image is experimental; this package
  does not claim official support or production certification.

The original bootstrap code calls Discourse's public model helpers. The pinned
runtime's `User`, `UserPassword`, `UserNameSuggester`, `EmailAddressValidator` and
Pitchfork configuration were inspected to verify account and worker behavior.
The image includes its application source; no application patches are shipped.

## Official Docker configuration

- https://github.com/discourse/discourse_docker
- Inspected `templates/web.template.yml`, `templates/postgres.template.yml`,
  `samples/web_only.yml`, `image/base/Dockerfile`, `image/docker-bake.hcl` on main.
- Required database extensions match upstream: hstore, pg_trgm, vector.
- nginx, app and Sidekiq use the image's original runit and launcher scripts.
- Copyright (c) 2018 Civilized Discourse Construction Kit, Inc.; MIT text retained in
  `LICENSES/discourse_docker-MIT.txt` (the source licence is authoritative).

## Market references

Full marketplace definitions remain in `../_market`. The original admin
bootstrap pattern was informed by the MIT-licensed reference
https://github.com/aalfath/discourse-railway-template, copyright (c) 2026 aalfath.
Its complete licence is retained in `LICENSES/aalfath-MIT.txt` for attribution.
This package implements its own before-service bootstrap and validation.
No README text was copied. No code from an unlicensed competitor was reused.

## Data services

Postgres is based on `templates/_railway-base/postgres.json`, using
`ghcr.io/railwayapp-templates/postgres-ssl:18` pinned by digest in its Dockerfile.
The Railway image supplies pgvector. PostgreSQL uses the PostgreSQL licence;
pgvector uses the PostgreSQL licence. Redis is based on the Railway Redis
definition, pinned to the checked 8.2.11 digest. Redis 8 offers RSALv2, SSPLv1 or
AGPLv3 licensing. Refer to the upstream distributions for all bundled notices.

The package adds no MinIO, hosted telemetry credentials or mail-capture service.
