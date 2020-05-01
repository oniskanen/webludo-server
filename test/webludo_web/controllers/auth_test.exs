defmodule WebLudoWeb.AuthTest do
  use ExUnit.Case

  alias WebLudoWeb.Auth
  alias WebLudoWeb.HostAuth
  alias WebLudo.Logic.Player
  alias WebLudo.Logic.Game

  test "a created token can be validated" do
    assert token = Auth.get_token(%Player{id: 123})
    assert {:ok, id} = Auth.get_player_id(token)
    assert id == 123
  end

  test "a created host token can be validated" do
    assert token = HostAuth.get_token(%Game{id: 1234})
    assert {:ok, id} = HostAuth.get_game_id(token)
    assert id == 1234
  end

  test "a valid host token returns an error for player token validation" do
    assert token = HostAuth.get_token(%Game{id: 1234})
    assert {:error, :invalid} = Auth.get_player_id(token)
  end

  test "a valid player token returns an error for host token validation" do
    assert token = Auth.get_token(%Player{id: 123})
    assert {:error, :invalid} = HostAuth.get_game_id(token)
  end
end
