This project provides the bare minimum to keep playing HoN when it shuts down:
 - Patched binaries to allow multiplayer play with the included practice server
 - UI mod to bypass the login screen, set a username, allow picking heroes when not logged in, restore the old main UI

[Download link](https://github.com/honserver/honserver/archive/refs/heads/master.zip)

# Server

To host a server, replace `k2_x64.dll` and `game/game_x64.dll` in your HoN install (or a copy of it). Run `hon_x64.exe -dedicated` to start the server (on Windows, you will need to start it with a high priority or the server will skip frames. you can make a shortcut and change the target to `C:\Windows\System32\cmd.exe /c start /high "something" "C:\Program Files\Heroes of Newerth x64\hon_x64.exe" -dedicated`). Only the server needs these modified dlls.

On the client `connect 127.0.0.1` in the console (assuming server is running locally), then start a game (`startgame local_automatic game_name map:caldavar` for example). Now other players can join by using `connect yourip`. For LAN players this should be your LAN IP, for online players this should be your public IP, the server uses UDP port 11235 by default (must be unblocked/forwarded as necessary).

The server still has some limitations/problems
- No disconnect timeout
- Unreliable reconnect
- Should be restarted between games to avoid issues

# No login UI mod

Copy the `ui/` and `stringtables/` to the `game/` folder in your HoN install. Edit `stringtables/client_messages_en.str` (notepad works) and replace Maliken in the first line with your game name.
