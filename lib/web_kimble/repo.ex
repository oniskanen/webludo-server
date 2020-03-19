defmodule WebKimble.Repo do
  use Ecto.Repo,
    otp_app: :web_kimble,
    adapter: Ecto.Adapters.Postgres
end
