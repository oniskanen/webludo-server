// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html";

// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket";

let lobbyButton = document.getElementById("lobbyButton");

if (lobbyButton) {
  let channel = socket.channel("lobby", {});
  channel
    .join()
    .receive("ok", resp => {
      console.log("Joined successfully", resp);
    })
    .receive("error", resp => {
      console.log("Unable to join", resp);
    });

  lobbyButton.addEventListener("click", e => {
    let payload = { a: "123" };
    channel
      .push("create_game", payload)
      .receive("ok", resp => console.log("got reply", resp))
      .receive("error", e => console.log("error", e));
  });

  channel.on("game_created", resp => {
    console.log(resp);
  });
}
