defmodule WebLudoWeb.Auth do
  @salt "player id"
  @max_age 2 * 7 * 24 * 60 * 60

  alias WebLudo.Logic.Player

  def get_token(%Player{id: player_id}) do
    Phoenix.Token.sign(WebLudoWeb.Endpoint, @salt, player_id, max_age: @max_age)
  end

  def get_player_id(token) do
    Phoenix.Token.verify(WebLudoWeb.Endpoint, @salt, token, max_age: @max_age)
  end
end
