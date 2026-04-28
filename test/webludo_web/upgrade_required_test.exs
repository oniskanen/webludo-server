defmodule WebLudoWeb.UpgradeRequiredTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias WebLudoWeb.UpgradeRequired

  test "responds 426 Upgrade Required" do
    conn = UpgradeRequired.call(conn(:get, "/"), UpgradeRequired.init([]))

    assert conn.status == 426
  end

  test "sets Upgrade: websocket and Connection: Upgrade headers" do
    conn = UpgradeRequired.call(conn(:get, "/"), [])

    assert get_resp_header(conn, "upgrade") == ["websocket"]
    assert get_resp_header(conn, "connection") == ["Upgrade"]
  end

  test "halts the pipeline so no upstream plug overwrites the response" do
    conn = UpgradeRequired.call(conn(:get, "/anything"), [])

    assert conn.halted
  end

  test "responds the same way regardless of method or path" do
    for method <- [:get, :post, :put, :delete, :patch],
        path <- ["/", "/anything", "/.env", "/socket/missing"] do
      conn = UpgradeRequired.call(conn(method, path), [])
      assert conn.status == 426, "#{method} #{path} did not return 426"
    end
  end
end
