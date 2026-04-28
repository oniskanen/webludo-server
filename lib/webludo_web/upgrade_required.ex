defmodule WebLudoWeb.UpgradeRequired do
  @moduledoc """
  Final fallback plug. The endpoint serves WebSocket traffic at
  `/socket/...`; any plain-HTTP request that gets here would otherwise
  crash with `Plug.Conn.NotSentError` because no upstream plug sent a
  response. This plug answers with `426 Upgrade Required` and the
  `Upgrade: websocket` / `Connection: Upgrade` headers from RFC 7231.
  """

  import Plug.Conn

  @body "This service requires the WebSocket protocol. Connect to /socket via WS.\n"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("upgrade", "websocket")
    |> put_resp_header("connection", "Upgrade")
    |> put_resp_content_type("text/plain")
    |> send_resp(426, @body)
    |> halt()
  end
end
