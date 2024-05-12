# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :webludo,
  ecto_repos: [WebLudo.Repo]

# Configures the endpoint
config :webludo, WebLudoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "FLOYVRiQYbMc68sZSHmfExMRzIyI7thxEYwddsHPw3xlvFSQHNPCngM5G3H3Iazp",
  render_errors: [view: WebLudoWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: WebLudo.PubSub,
  live_view: [signing_salt: "SC1OdLtr"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
