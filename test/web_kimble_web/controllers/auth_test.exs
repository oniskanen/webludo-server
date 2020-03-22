defmodule WebKimbleWeb.AuthTest do
    use ExUnit.Case
  
    alias WebKimbleWeb.Auth

    test "a created token can be validated" do
        id = 123
        assert token = Auth.get_token(id)
        assert {:ok, id} = Auth.get_player_id(token)
    end
  end
  