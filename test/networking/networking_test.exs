defmodule WebKimble.NetworkingTest do
  use WebKimble.DataCase, async: true

  alias WebKimble.Networking

  @valid_attrs %{
    name: "Game",
    code: "abc123"
  }

  alias WebKimble.Networking.Game

  test "with valid data inserts game" do
    assert {:ok, %Game{id: id} = game} = Networking.create_game(@valid_attrs)
    assert game.name == "Game"
    assert game.code == "abc123"
    assert [%Game{id: ^id}] = Networking.list_games()
  end
end
