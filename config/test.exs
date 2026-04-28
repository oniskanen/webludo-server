import Config

# Configure your database
config :webludo, WebLudo.Repo,
  username: "postgres",
  password: "postgres",
  database: "webludo_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :webludo, WebLudoWeb.Endpoint,
  secret_key_base:
    "RoSG5r2EoWGrOOQkKs3_iYA8ob2hL4j5RxNRKbFEpXzpF79Vb17HWUQMeWomYpEpXOKLgHCRmbqPv6QfOeb8yA",
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning
