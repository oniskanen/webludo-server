defmodule WebKimbleWeb.CreateControllerTest do
    use WebKimbleWeb.ConnCase
  
    test "POST /create", %{conn: conn} do
      conn = post(conn, "/create")
      assert html_response(conn, 200) =~ "Your game code is"
    end
  end
  