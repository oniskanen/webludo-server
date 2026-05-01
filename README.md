# Webludo

This project is a Phoenix server that handles running a game of beer-Ludo ("Kalja-Kimble"). The API is based on Phoenix channels. A Postgres-based persistence layer is included for longer games. See [the Preact frontend project](https://github.com/katrimarika/kimble-frontend) for the corresponding web client. The primary deployment of the frontend is at https://webludo.katris.dev/; while a config issue there is being resolved, https://webludo.oni.dev/ is the current playable URL.

## Initial local setup

Steps to set up the project the first time:

- Clone the repository.
- Install dependencies with `mix deps.get`.
- Either point at a local Postgres matching `config/dev.exs`, or start one with `docker compose -f docker-compose.dev.yml up -d db`.
- Create and migrate the database with `mix ecto.setup`.

## Local server

Start the Phoenix server with `mix phx.server`. It listens on [`localhost:4000`](http://localhost:4000). There is no built-in browser interface — run [the Preact frontend project](https://github.com/katrimarika/kimble-frontend) locally to interact with it.

## Tests

`mix test` creates and migrates the test database, then runs the ExUnit suite.

## Production

The production instance runs on an exe.dev VM at https://webludo-api.oni.dev. Deploy steps, env-file layout, systemd unit, migrations, and rollback are documented in [`deploy/README.md`](deploy/README.md). Tail logs with `sudo journalctl -u webludo`.
