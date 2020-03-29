defmodule WebKimbleWeb.Channels.UserSocketTest do
  use WebKimbleWeb.ChannelCase, async: true
  alias WebKimbleWeb.UserSocket

  test "socket anonymous connection" do
    assert {:ok, socket} = connect(UserSocket, %{})
  end
end
