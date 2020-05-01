defmodule WebLudoWeb.HostAuth do
  @salt "game id"
  @max_age 2 * 7 * 24 * 60 * 60

  alias WebLudo.Logic.Game

  def get_token(%Game{id: game_id}) do
    Phoenix.Token.sign(WebLudoWeb.Endpoint, @salt, game_id, max_age: @max_age)
  end

  def get_game_id(host_token) do
    Phoenix.Token.verify(WebLudoWeb.Endpoint, @salt, host_token, max_age: @max_age)
  end
end
