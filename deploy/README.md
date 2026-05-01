# Deploying webludo-server to an exe.dev VM

This runbook covers a single-VM deploy: a `mix release` running under systemd,
Postgres on the same host, TLS terminated by the exe.dev edge proxy.

## Layout

```
/opt/webludo/repo               git clone, owned by the webludo user
  _build/prod/rel/webludo/bin/  release entrypoint (built on the VM)
/etc/webludo/webludo.env        env file, root:webludo 0640
/etc/systemd/system/webludo.service   systemd unit
```

The exe.dev edge proxy terminates TLS and forwards requests for
`webludo-api.oni.dev` to `127.0.0.1:4000` on the VM. The release binds to
loopback only — never expose the port on a public interface.

## Prerequisites

- A fresh exe.dev VM (Debian/Ubuntu) with sudo and SSH access.
- DNS for `webludo-api.oni.dev` pointing at the VM (or controlled via the
  exe.dev custom-domain mapping).
- A local clone of this repo to copy commands from.

## 1. System packages

Install build dependencies for Erlang plus Postgres. The Erlang/Elixir
toolchain itself is installed via asdf in step 4 — the Erlang Solutions
apt repo does not currently serve Ubuntu 24.04 (`noble`), which is what
exe.dev provisions.

```bash
sudo apt update
sudo apt install -y build-essential autoconf m4 \
  libncurses-dev libssl-dev libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev \
  libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils \
  git curl unzip postgresql postgresql-contrib
```

## 2. Application user and directories

```bash
sudo useradd --system --home /opt/webludo --shell /bin/bash webludo
sudo mkdir -p /opt/webludo /etc/webludo
sudo chown webludo:webludo /opt/webludo
sudo chown root:webludo /etc/webludo && sudo chmod 750 /etc/webludo
```

The user has `/bin/bash` so the `sudo -iu webludo` invocations below
work. See [Optional hardening](#optional-hardening) for locking the
account down once the deploy is stable.

## 3. Clone the repo

```bash
sudo -u webludo git clone https://github.com/oniskanen/webludo-server.git /opt/webludo/repo
```

## 4. Toolchain via asdf

The repo's `.tool-versions` pins Elixir 1.19.5 / Erlang 28.5. Install
asdf as the `webludo` user, then build the pinned toolchain (Erlang
compiles from source, ~15 min on a typical VM).

```bash
sudo -iu webludo bash -c '
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1 &&
  echo ". ~/.asdf/asdf.sh" >> ~/.bashrc &&
  . ~/.asdf/asdf.sh &&
  asdf plugin add erlang &&
  asdf plugin add elixir &&
  cd /opt/webludo/repo &&
  asdf install
'
```

Verify:

```bash
sudo -iu webludo bash -c 'cd /opt/webludo/repo && elixir --version'
# expect Elixir 1.19.5 / Erlang/OTP 28
```

## 5. Postgres role and database

```bash
sudo -u postgres psql <<'SQL'
CREATE ROLE webludo WITH LOGIN PASSWORD 'CHANGE_ME';
CREATE DATABASE webludo_prod OWNER webludo;
SQL
```

Pick a strong password; you will paste it into `webludo.env` next.

## 6. Env file

```bash
sudo cp /opt/webludo/repo/deploy/.env.example /etc/webludo/webludo.env
sudo chown root:webludo /etc/webludo/webludo.env
sudo chmod 640 /etc/webludo/webludo.env
sudo -e /etc/webludo/webludo.env
```

Fill in:

- `DATABASE_URL` — `ecto://webludo:<password>@localhost/webludo_prod`
- `SECRET_KEY_BASE` — generate with the one-liner below (`mix phx.gen.secret`
  needs the dev-only deps that a `--only prod` checkout does not fetch).
- `PHX_HOST` — `webludo-api.oni.dev`.
- `PORT` — `4000` (must match the exe.dev edge mapping in step 9).

```bash
sudo -iu webludo bash -c \
  'elixir -e ":crypto.strong_rand_bytes(64) |> Base.url_encode64(padding: false) |> IO.puts"'
```

## 7. Build the release

Run as the `webludo` user so build artefacts are owned correctly.

```bash
sudo -iu webludo bash -c '
  cd /opt/webludo/repo &&
  mix local.hex --force &&
  mix local.rebar --force &&
  MIX_ENV=prod mix deps.get --only prod &&
  MIX_ENV=prod mix release --overwrite
'
```

## 8. First-run migrations

```bash
sudo -iu webludo bash -c '
  set -a && . /etc/webludo/webludo.env && set +a &&
  /opt/webludo/repo/_build/prod/rel/webludo/bin/webludo eval "WebLudo.Release.migrate"
'
```

`set -a` exports the env vars to the eval subprocess. The release task
applies all pending migrations and exits.

## 9. Systemd unit and edge mapping

```bash
sudo cp /opt/webludo/repo/deploy/webludo.service /etc/systemd/system/webludo.service
sudo systemctl daemon-reload
sudo systemctl enable --now webludo
sudo systemctl status webludo
```

In the exe.dev console, map the custom domain `webludo-api.oni.dev` to
port `4000` of this VM (refer to exe.dev docs for the current console
flow). TLS provisioning is automatic.

**Toggle the domain to public.** exe.dev mappings default to private mode,
which intercepts requests with the exe.dev login wall (`307 → /__exe.dev/login`).
For an API and websocket, the domain has to be set to public in the same
console panel.

## 10. Verify

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://webludo-api.oni.dev/socket/websocket
```

A `400` or `426` is expected — the websocket endpoint rejects plain HTTP
upgrade attempts but proves the path is wired end to end. The frontend
should now connect: the primary deployment at `https://webludo.katris.dev`
or, while a config issue there is being resolved, the fallback at
`https://webludo.oni.dev`.

## Subsequent deploys

```bash
sudo -iu webludo bash -c '
  cd /opt/webludo/repo &&
  git pull --ff-only &&
  MIX_ENV=prod mix deps.get --only prod &&
  MIX_ENV=prod mix release --overwrite
'
sudo -iu webludo bash -c '
  set -a && . /etc/webludo/webludo.env && set +a &&
  /opt/webludo/repo/_build/prod/rel/webludo/bin/webludo eval "WebLudo.Release.migrate"
'
sudo systemctl restart webludo
```

If a deploy has no migrations, the eval step is a no-op and safe to skip.

## Logs

```bash
sudo journalctl -u webludo -f      # follow live
sudo journalctl -u webludo -n 200  # last 200 lines
```

## Rollback

To roll back code, check out the previous commit and rebuild:

```bash
sudo -iu webludo bash -c '
  cd /opt/webludo/repo &&
  git log --oneline -10 &&
  git checkout <previous-sha> &&
  MIX_ENV=prod mix release --overwrite
'
sudo systemctl restart webludo
```

To roll back a migration:

```bash
sudo -iu webludo bash -c '
  set -a && . /etc/webludo/webludo.env && set +a &&
  /opt/webludo/repo/_build/prod/rel/webludo/bin/webludo eval \
    "WebLudo.Release.rollback(WebLudo.Repo, <version>)"
'
```

`<version>` is the timestamp prefix on the migration filename in
`priv/repo/migrations/`.

## Optional hardening

The `webludo` user is created with `/bin/bash` so the `sudo -iu webludo`
invocations above work. Once the deploy is stable, you can lock the
account down further:

```bash
sudo passwd -l webludo                              # disable password login
sudo usermod -s /usr/sbin/nologin webludo           # no interactive shell
```

After switching the shell to `nologin`, replace `sudo -iu webludo bash -c
'...'` with `sudo -u webludo bash -lc '. ~/.asdf/asdf.sh && ...'` (or
explicit `env` invocations) — `sudo -i` requires a real login shell on
the target user, which `nologin` is not.

If `sshd` is configured locally, also set `DenyUsers webludo` in
`/etc/ssh/sshd_config` so the account cannot accept inbound SSH.
