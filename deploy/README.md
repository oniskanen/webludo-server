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

## 1. VM bootstrap

Install packages and the Erlang/Elixir toolchain. The Erlang Solutions apt
repo tracks recent versions; stock distro packages typically lag too far for
the toolchain pinned in `.tool-versions`.

```bash
sudo apt update
sudo apt install -y build-essential git curl gnupg lsb-release \
  libssl-dev libncurses-dev postgresql postgresql-contrib

# Erlang Solutions apt source
curl -fsSL https://binaries2.erlang-solutions.com/GPG-KEY-pmanager.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/erlang-solutions.gpg
echo "deb [signed-by=/usr/share/keyrings/erlang-solutions.gpg] https://binaries2.erlang-solutions.com/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/ $(lsb_release -cs) contrib" \
  | sudo tee /etc/apt/sources.list.d/erlang-solutions.list
sudo apt update
sudo apt install -y esl-erlang elixir
```

Verify the versions match `.tool-versions` at the repo root:

```bash
elixir --version    # expect Elixir 1.19.x / Erlang/OTP 28
```

If Erlang Solutions is behind, fall back to asdf — `.tool-versions` will
drive the install.

## 2. Application user and directories

```bash
sudo useradd --system --home /opt/webludo --shell /usr/sbin/nologin webludo
sudo mkdir -p /opt/webludo /etc/webludo
sudo chown webludo:webludo /opt/webludo
sudo chown root:webludo /etc/webludo && sudo chmod 750 /etc/webludo
```

## 3. Postgres role and database

```bash
sudo -u postgres psql <<'SQL'
CREATE ROLE webludo WITH LOGIN PASSWORD 'CHANGE_ME';
CREATE DATABASE webludo_prod OWNER webludo;
SQL
```

Pick a strong password; you will paste it into `webludo.env` next.

## 4. Env file

```bash
sudo cp deploy/.env.example /etc/webludo/webludo.env
sudo chown root:webludo /etc/webludo/webludo.env
sudo chmod 640 /etc/webludo/webludo.env
sudo -e /etc/webludo/webludo.env
```

Fill in:

- `DATABASE_URL` — `ecto://webludo:<password>@localhost/webludo_prod`
- `SECRET_KEY_BASE` — generate with `mix phx.gen.secret` (any host with
  Elixir works, including the VM after step 1).
- `PHX_HOST` — `webludo-api.oni.dev`.
- `PORT` — `4000` (must match the exe.dev edge mapping in step 8).

## 5. Clone the repo

```bash
sudo -u webludo git clone https://github.com/oniskanen/webludo-server.git /opt/webludo/repo
cd /opt/webludo/repo
```

## 6. Build the release

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

## 7. First-run migrations

```bash
sudo -iu webludo bash -c '
  set -a && . /etc/webludo/webludo.env && set +a &&
  /opt/webludo/repo/_build/prod/rel/webludo/bin/webludo eval "WebLudo.Release.migrate"
'
```

`set -a` exports the env vars to the eval subprocess. The release task
applies all pending migrations and exits.

## 8. Systemd unit and edge mapping

```bash
sudo cp /opt/webludo/repo/deploy/webludo.service /etc/systemd/system/webludo.service
sudo systemctl daemon-reload
sudo systemctl enable --now webludo
sudo systemctl status webludo
```

In the exe.dev console, map the custom domain `webludo-api.oni.dev` to
port `4000` of this VM (refer to exe.dev docs for the current console
flow). TLS provisioning is automatic.

## 9. Verify

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://webludo-api.oni.dev/socket/websocket
```

A `400` or `426` is expected — the websocket endpoint rejects plain HTTP
upgrade attempts but proves the path is wired end to end. The frontend at
`https://webludo.katris.dev` should now connect.

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
