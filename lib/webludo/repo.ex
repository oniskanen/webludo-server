defmodule WebLudo.Repo do
  use Ecto.Repo,
    otp_app: :webludo,
    adapter: Ecto.Adapters.Postgres
end
