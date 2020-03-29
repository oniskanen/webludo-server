defmodule WebKimbleWeb.AuthTest do
  use ExUnit.Case

  alias WebKimbleWeb.Auth
  alias WebKimble.Networking.Player

  test "a created token can be validated" do
    assert token = Auth.get_token(%Player{id: 123})
    assert {:ok, id} = Auth.get_player_id(token)
  end
end
