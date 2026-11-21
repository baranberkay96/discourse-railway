# Deploy and Host Discourse with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/discourse-20267-community-forum-postgres?referralCode=20H68q)

Discourse is an open-source community forum with searchable topics, categories,
chat and moderation tools. This community package runs the Discourse application
and Sidekiq together, with private PostgreSQL and Redis services. It creates the
first administrator before opening the forum, and keeps uploads and database
contents on separate persistent volumes.

## About Hosting Discourse

The app service uses Discourse's prebuilt `discourse/discourse:2026.7.6` image,
pinned by digest. nginx fronts the Rails application server; Sidekiq handles
background jobs in the same container so it can access the upload volume.
PostgreSQL includes hstore, pg_trgm and pgvector. Redis has authentication and
append-only persistence. Discourse describes its prebuilt image as experimental:
the supported upstream installation is its Docker launcher, which cannot run
inside a normal Railway service. Test this community deployment for your needs
and take backups before updates. Configure SMTP before inviting members; Railway
permits outbound SMTP on Pro.

## Common Use Cases

- Product and open-source project communities
- Customer support discussions with searchable answers
- Member forums for courses and publications
- Internal announcements and long-form team discussions

## Dependencies for Discourse Hosting

- PostgreSQL 18 with required extensions (included)
- Redis 8.2 with generated authentication (included)
- A persistent app volume for uploads and local backups (included)
- An external SMTP provider and Railway Pro for email delivery
- At least 2 GB available to the app service; size upward for traffic and plugins

### Deployment Dependencies

- [Discourse](https://www.discourse.org)
- [Application source and tags](https://github.com/discourse/discourse)
- [Official image and support notice](https://hub.docker.com/r/discourse/discourse/)
- [Upstream Docker configuration](https://github.com/discourse/discourse_docker)
- [Railway outbound networking](https://docs.railway.com/networking/outbound-networking)

### Implementation Details

| Service | Source | Public | Persistence |
|---|---|---|---|
| Discourse | Pinned Discourse image plus startup hooks | HTTP port 80 | `/shared`: uploads, backups and logs |
| Postgres | Pinned Railway Postgres 18 plus extension initialization | No | `/var/lib/postgresql/data` |
| Redis | Pinned Redis 8.2.11 | No | `/data`: append-only data |

**First login.** Set `DISCOURSE_ADMIN_EMAIL` to your own email before deploying
(the fallback is `admin@example.com`). Wait for `/srv/status` to become healthy,
then open the public URL and log in with that email and the generated
`DISCOURSE_ADMIN_PASSWORD` from the app service's Variables tab. Complete the
setup wizard. Existing users and passwords are preserved on every redeploy;
changing the bootstrap variables does not replace an existing account.

**Invalid inputs and recovery.** An invalid hostname or email falls back with a
warning. A short, excessively long or rejected admin password creates the owner
with a random unknown password; it is never printed. To recover without working
mail, open a Railway shell in the Discourse service and run:

```sh
cd /var/www/discourse
su discourse -c 'bundle exec rake admin:create'
```

Use the interactive prompts to set the owner credentials. Do not paste passwords
into logged command arguments. If a restored database already has real users,
bootstrap leaves them alone, even if no administrator exists; use the same
interactive recovery task.

**Email.** Add `DISCOURSE_SMTP_ADDRESS`, `DISCOURSE_SMTP_PORT` (usually 587),
`DISCOURSE_SMTP_USER_NAME`, `DISCOURSE_SMTP_PASSWORD` and
`DISCOURSE_NOTIFICATION_EMAIL` to the app service. Use your provider's TLS
instructions and verified sender domain. Outbound SMTP needs Railway Pro;
without it you can evaluate the forum with the bootstrapped admin, but invites,
account activation, notifications and password reset mail will not be delivered.
No mail-capture service is included or presented as real email delivery.

**Custom domain.** Add it to the Discourse service and complete DNS setup, then
set `DISCOURSE_HOSTNAME` to the hostname without `https://` and redeploy.
`RAILWAY_FORCE_HTTPS=true` accounts for Railway's TLS termination. The `false`
setting is only for local HTTP tests. Do not expose the app directly outside a
trusted reverse proxy: nginx forwards Railway's client-address headers to Rails.

**Workers and scaling.** The defaults are one web worker and one Sidekiq process.
`UNICORN_WORKERS` accepts 1–4 and `UNICORN_SIDEKIQS` accepts 1–2; invalid values
fall back to one. Increase memory before raising either. The app uses a volume
and should remain a single replica. Independent worker replicas need shared
object storage and a different deployment layout.

**Backups and upgrades.** Back up PostgreSQL and `/shared/uploads`, and copy local
backups off the service. Pin changes belong in `services/*/Dockerfile` and the
Redis image in `template.json`. The startup hook waits for data services, applies
migrations and preserves the owner before starting the web server. Do not use
the in-app Docker updater on Railway. Additional plugins require a tested custom
image. The generated `DISCOURSE_SECRET_KEY_BASE` should remain stable.

**Licence.** Discourse is GPL-2.0; upstream Docker configuration is MIT. Included
licence files and provenance are in `LICENSES/` and `NOTICE.md`. This template is
independent of the Discourse team.

### Why Deploy Discourse on Railway?

Railway provides private networking, generated variables, volumes and an HTTPS
endpoint for the forum. The template connects the services and documents first
login, recovery and updates so you can operate a community from one project.
