defmodule WebLudoWeb.Channels.UserSocketTest do
  use WebLudoWeb.ChannelCase, async: true
  alias WebLudoWeb.UserSocket

  test "socket anonymous connection" do
    assert {:ok, _socket} = connect(UserSocket, %{})
  end
end
