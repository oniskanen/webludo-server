defmodule WebLudo.Repo do
  use Ecto.Repo,
    otp_app: :webludo,
    adapter: Ecto.Adapters.Postgres

  defp env_config() do
    env = Keyword.new()
      |> Keyword.put(:username, System.get_env("PGUSER"))
      |> Keyword.put(:password, System.get_env("PGPASSWORD"))
      |> Keyword.put(:database, System.get_env("PGDATABASE"))
      |> Keyword.put(:hostname, System.get_env("PGHOST"))
    port_str = System.get_env("PGPORT")

    if port_str == nil do
      env
    else
      env |> Keyword.put(:port, port_str |> String.to_integer)
    end
  end

  defp merge_config(_keyword, base, nil) do
    base
  end

  defp merge_config(_keyword, _base, env) do
    env
  end

  def init(_, config) do
    config = Keyword.merge(config, env_config(),
      fn k, base, env ->
        merge_config(k, base, env)
      end)
    {:ok, config}
  end
end
