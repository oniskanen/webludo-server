# CLAUDE.md

Phoenix API server for a multiplayer Beer-Ludo (Finnish "Kimble") game. Live at `https://webludo-api.oni.dev`. Frontend at `https://webludo.katris.dev` lives in a separate repo (`katrimarika/kimble-frontend`) and is out of scope here.

## Architecture

- `lib/webludo/logic.ex` (~1100 LOC) is the rules engine — turn order, movement, raise/hembo mechanics, win conditions. Schemas in `lib/webludo/logic/`: `game`, `team`, `player`, `piece`, `move`, `constants`.
- `lib/webludo_web/channels/` is the transport. `game_channel.ex` is thick; `lobby_channel.ex` and `user_socket.ex` are minimal.
- `lib/webludo_web/controllers/{auth,host_auth}.ex` are channel-auth helpers — there is no HTTP router, no controller actions. The endpoint only mounts `/socket`. Don't be surprised by the directory name.
- `lib/ecto_atom/atom.ex` is a 12-line custom Ecto type for atom columns. Stable; don't modify without an explicit reason.
- `lib/webludo/release.ex` exposes `migrate/0` and `rollback/2` for the production release (Mix-less). See `deploy/README.md`.

## Commands

```
mix test                                   # creates+migrates webludo_test, runs ExUnit
mix format
MIX_ENV=prod mix release                   # build a release at _build/prod/rel/webludo
docker compose -f docker-compose.dev.yml up -d db   # local Postgres (postgres/postgres)
```

The Docker compose file is dev-only — production runs `mix release` under systemd; see `deploy/README.md`.

## Conventions

- **TDD in the rules engine.** Failing tests in `test/logic/` land before changes to `lib/webludo/logic*`.
- **Channel handlers stay thin.** Domain logic lives in `WebLudo.Logic.*`, not in `WebLudoWeb.*`.
- **Never edit historical migrations.** Add a new one in `priv/repo/migrations/`.
- **Don't touch `lib/ecto_atom/`** unless the task explicitly says to.
- **One task = one PR**, branch from `main`. Squash-merge with `gh pr merge <n> --squash --delete-branch`. The PR description becomes the commit body, so write it well.
- **Don't add runtime dependencies** without flagging — the small surface area is part of the portfolio story.

## Ask before acting

Stop and ask the user before:

- Schema changes (new migration, column type changes, indexes that rewrite tables).
- Adding a runtime dependency to `mix.exs`.
- Touching `lib/ecto_atom/` or modifying production config beyond what `config/runtime.exs` already covers.
- Pinning toolchain versions or upgrading Elixir/OTP.
- Any change that crosses into the frontend repo.
