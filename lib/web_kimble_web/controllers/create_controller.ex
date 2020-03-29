defmodule WebKimbleWeb.CreateController do
  use WebKimbleWeb, :controller

  def create(conn, _params) do
    render(conn, "index.html")
  end
end
