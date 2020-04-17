# Webludo

This project is a Phoenix server that handles running a game of beer-Ludo ("Kalja-Kimble"). The API is based on Phoenix channels. A Postgres-based persistence layer is included for longer games. See [the React frontend project](https://github.com/katrimarika/kimble-frontend) for the corresponding web client. The current version of the game can be played at https://webludo.katris.dev/

## Initial local setup

Steps to setup the project the first time:

- Clone the repository
- Install dependencies with `mix deps.get`
- Ensure that a local Postgres database is running and the settings in `config/dev.exs` match your local setup
- Create and migrate your database with `mix ecto.setup`

## Local server

To start your Phoenix server: `mix phx.server`

The server now runs in [`localhost:4000`](http://localhost:4000). There is no built-in browser interface, but running [the React frontend project](https://github.com/katrimarika/kimble-frontend) locally works well.

## Production deployment

The production instance can be found at https://webludo-api.oni.dev. Deployment is done through Gigalixir.

1. Deploy by running `git push gigalixir master`
2. (If migrations are needed:) `gigalixir ps:migrate` to run missing database migrations

## Accessing production server logs

You can tail the production server logs by running `gigalixir logs`
