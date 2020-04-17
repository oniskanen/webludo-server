defmodule WebLudoWeb.AuthTest do
  use ExUnit.Case

  alias WebLudoWeb.Auth
  alias WebLudo.Logic.Player

  test "a created token can be validated" do
    assert token = Auth.get_token(%Player{id: 123})
    assert {:ok, id} = Auth.get_player_id(token)
  end
end
