defmodule WebKimbleWeb.LobbyControllerTest do
  use WebKimbleWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Kimble!"
  end
end
