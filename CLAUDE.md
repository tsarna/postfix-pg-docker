# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Docker image that runs Postfix (MTA) with PostgreSQL support on Alpine Linux. It uses `runit` for process supervision with three services: `postfix`, `rsyslog`, and `crond`.

## Building and Running

```bash
# Build the image
docker build -t postfix-pg:local .

# Run locally (basic example)
docker run --rm -ti -p 25:25 -p 587:587 \
  -e CONF_MYDOMAIN=example.com \
  postfix-pg:local

# Build and push to Docker Hub (uses $USER/$PASSWORD env vars)
./build_and_deploy.sh
```

CI (GitHub Actions) builds multi-arch images (`linux/amd64`, `linux/arm64`) and pushes to Docker Hub on push to `master`/`main` or on version tags.

## Architecture

### Container Startup Flow

1. `runit_bootstrap` → runs `runsvdir /etc/service` (starts all runit services)
2. `service/rsyslog/run` → configures and starts rsyslogd
3. `service/crond/run` → configures and starts crond (or sleeps if no cron jobs configured)
4. `service/postfix/run` → main startup script that:
   - Applies `CONF_*` env vars to `/etc/postfix/main.cf` via `postconf -e`
   - Sources `/etc/service/postfix/run.config` if present (for customization by sub-images)
   - Configures SASL auth, root aliases, mailname
   - Writes PostgreSQL map config files into `/etc/postfix/pgsql/`
   - Starts the postfix master process

### Key Configuration Mechanism

**`CONF_*` env vars** are transformed into `main.cf` settings at startup:
- `CONF_MYDOMAIN=example.com` → `mydomain = example.com`
- The transform: `printenv | grep '^CONF_' | sed 's/^CONF_\(.*\)=\(.*\)/\L\1\E=\2/' | tr '\n' '\0' | xargs -0 postconf -e`

**Sub-image customization**: Place a `run.config` bash script at `/etc/service/postfix/run.config` — it gets sourced before Postfix starts, allowing derived images to add custom logic.

### PostgreSQL Integration

Two independent PostgreSQL features:

1. **Alias/Virtual maps** (`service/postfix/run`): `PGQUERY_<NAME>=<sql>` env vars generate `/etc/postfix/pgsql/<name>.cf` files at startup (e.g. `PGQUERY_RELAY_DOMAINS` → `relay_domains.cf`). Shared connection vars: `POSTGRES_HOSTS`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_ALIAS_DB`.

2. **Log forwarding** (`service/rsyslog/run`): When `POSTGRES_LOG_*` vars are set, generates `/etc/rsyslog.d/pg_mail_log.conf` using rsyslog's `ompgsql` module.

### master.cf Notable Configuration

- SMTP uses `postscreen` (1 process max) as front-end
- `submission` (587) and `submissions` (465) both configured with HAProxy PROXY protocol support (`smtpd_upstream_proxy_protocol=haproxy`)
- Chroot is disabled (`n`) for all services

### Environment Variables Reference

| Variable | Purpose |
|---|---|
| `CONF_*` | Any postfix `main.cf` setting |
| `MAILNAME` | Sets `/etc/mailname` and `smtp_helo_name` |
| `ROOT_ALIAS` | Adds `root: <value>` to `/etc/aliases` |
| `SASL_AUTH` | `username:password` for relay SASL auth |
| `MAIL_LOG_FILE` | Rsyslog file destination for mail logs |
| `LOGROTATE_CRON_SCHEDULE` | Cron schedule for logrotate |
| `POSTQUEUE_CRON_SCHEDULE` + `POSTQUEUE_OUTPUT` | Periodic `postqueue -p` dumps |
| `CRON_EXTRA` / `CRON_EXTRA_FILE` | Additional crontab entries |
| `POSTCONF_OUTPUT` | File path to dump full `postconf` output at startup |
| `POSTGRES_LOG_HOST/DB/USER/PASSWORD/TABLE` | PostgreSQL log forwarding |
| `POSTGRES_HOSTS/USER/PASSWORD/ALIAS_DB` | Shared PostgreSQL alias map connection |
| `PGQUERY_<NAME>` | Generates `/etc/postfix/pgsql/<name>.cf` with the given SQL query (e.g. `PGQUERY_RELAY_DOMAINS`, `PGQUERY_VIRTUAL_ALIAS_MAPS`) |
