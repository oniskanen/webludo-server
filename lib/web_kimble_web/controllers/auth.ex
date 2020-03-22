defmodule WebKimbleWeb.Auth do
    @salt "player id"
    @max_age 2 * 7 * 24 * 60 * 60

    alias WebKimble.Networking.Player

    def get_token(%Player{id: player_id} = _player) do
        Phoenix.Token.sign(WebKimbleWeb.Endpoint, @salt, player_id, max_age: @max_age)
    end

    def get_player_id(token) do
        Phoenix.Token.verify(WebKimbleWeb.Endpoint, @salt, token, max_age: @max_age)
    end

end