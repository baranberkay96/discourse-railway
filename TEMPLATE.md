# Discourse 2026.7 Community Forum (Postgres, Redis)

Status: PUBLISHED (2026-11-21). https://railway.com/deploy/discourse-20267-community-forum-postgres

## Listing

| Field | Value |
|---|---|
| Name | Discourse 2026.7 Community Forum (Postgres, Redis) |
| Description | Community forum with private Postgres, Redis and automatic admin login. |
| Category | CMS |
| Icon | `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/discourse.svg` |
| Intended repo | `baranberkay96/discourse-railway` (not created by this local task) |

## Base market templates

Four complete definitions are retained in `../_market/`:

- `discourse`: strongest by usage, 25 active / 152 total when checked. Official
  `2026.7.1` app, Postgres, Redis and a mail preview container. Its app command
  removes nginx's default site and boots runit, but first-owner protection and
  delivered email are not supplied by a preview inbox.
- `discourse-forum`: repository-based app plus Postgres, Redis and Mailpit. The
  source had no verified licence in this research; no files or prose were copied.
- `discourse-forum-postgres-redis`: legacy Bitnami 3.5 web and Sidekiq containers.
  Moving away from the legacy image avoids relying on an old distribution.
- `discourse-1`: MIT-licensed prebuilt image wrapper and admin bootstrap. Its
  first-admin pattern informed the independent synchronous bootstrap here.

Kept: upstream Discourse + Postgres + Redis, `/shared` persistence, nginx and
`/srv/status` readiness. The app's own runit/Pitchfork supervisor keeps web and
Sidekiq together; no unsupported shared volume is needed.

## Improvements over market templates

1. Current published stable-channel image `2026.7.6`, pinned by digest instead of
   floating `latest` or an old Bitnami image; explicit experimental-image warning.
2. Synchronous database migrations and first-admin creation in runit's final
   initialization phase, before nginx serves public requests. No owner-claim race.
3. Invalid inputs fall back; rejected passwords lock the new owner without
   printing the random key or letting a visitor claim administration.
4. Existing real users are never promoted or overwritten from deploy variables.
5. Postgres extensions initialize before app migrations. All data traffic stays
   private; no public database TCP proxies are defined.
6. Authenticated Redis with append-only persistence and IPv4 + IPv6 listeners.
7. Generated, stable app signing secret and bounded web/background worker counts.
8. No public mock inbox or misleading suggestion that captured mail is delivered.

## Pinned versions

| Component | Pin | Checked |
|---|---|---|
| Discourse | `2026.7.6@sha256:f8a7a3c0f7e5ee6c66e3d8b24d55ba860ed8f7f265384aba81a3c440b008108a` | 2026-11-21 |
| Railway Postgres | `18@sha256:4fc833b43d2aaf6ecc9b18615f5533602b723a32d0e2efe2dae8ca0f7217c863` (18.6) | 2026-11-21 |
| Redis | `8.2@sha256:b0b01167ff47bc3868e56a967895a26be4230891a1f42a78ab61cdd227accc8d` (8.2.11) | 2026-11-21 |

## Runtime compatibility

The image records the exact application file tree at build time. Before boot,
it removes obsolete image paths that Railway can restore from older layers.
The traversal never follows volume symlinks, so uploads, backups and logs remain
on their volumes. Keep the manifest capture after application or plugin changes
in a fork. Redis removes only an empty lost+found directory before its official
entrypoint repairs volume ownership. The session signing key is 128 hex digits.

## Composer instructions

Use `template.json` or `python3 ../../_tools/to_serialized.py template.json` from
this directory. Repository service roots are `/services/discourse` and
`/services/postgres`; publish the package repository before applying that source
specification remotely. Only the app gets a public domain, target port 80.
Attach `/shared`, `/var/lib/postgresql/data` and `/data` volumes to their respective
services. Set `PORT=80`, app health `/srv/status`, timeout 1200 seconds and restart
policy `ALWAYS`. All variable descriptions and defaults are in `template.json`.

Run migrations in the app's runit initialization rather than Railway's
pre-deploy phase: initialization needs the mounted `/shared` volume and upstream
filesystem preparation, which Railway pre-deploy commands do not mount.

## Resources and plan

The default is one web worker and one Sidekiq. Budget at least 2 GB app memory;
Trial (1 GB) and Free (0.5 GB) are not supported targets for this package. SMTP
delivery requires Pro even if a smaller paid plan has sufficient app resources.

Provisional planning estimates, not Railway measurements: app 0.7–1.2 GB idle /
1.2–2.5 GB with activity; Postgres 0.15–0.3 GB idle / 0.3–0.6 GB typical; Redis
0.02–0.05 GB idle / 0.05–0.15 GB typical. At the STANDARD's RAM $10/GB-month,
CPU $20/vCPU-month and storage $0.15/GB-month, low-traffic usage might be $10–25
monthly plus plan minimums, storage growth and email delivery. Re-measure on
Railway before making a published cost claim. Local Docker evidence is recorded
in `../../_reports/167-discourse-2026-11-21.md`.

## Verification checklist

- [x] App and Postgres Dockerfiles build for linux/amd64.
- [x] `ruby services/discourse/test/config_test.rb`: invalid fields, locked
  credentials, domain fallback and worker bounds.
- [x] Fresh empty `/shared` volume with `nocopy` and Docker `init: true` boots.
- [x] PostgreSQL's three required extensions are present.
- [x] Generated owner password authenticates and the account is active/admin.
- [x] Web responds at `/srv/status`; Sidekiq registers with Redis.
- [x] Post and image survive a forced container recreation on the same volumes.
- [x] Invalid associated email and rejected-password integration regressions.
- [x] Railway live deploy and HTTPS first login, admin API, public topic and image upload/read. Client-IP header details remain delegated to Railway edge behavior.
- [ ] SMTP, signups and mail delivery (requires credentials and Pro).

## Open questions

- Discourse's upstream prebuilt image remains experimental; only its standard
  Docker launcher install receives official support.
- Resource figures need real Railway measurements before a public listing.
- Published source and marketplace URL are verified. Real-ID functional checks
  passed; see ../../_reports/publication-2026-11-21/167-discourse for full evidence.
