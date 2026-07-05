ServerFOX CC Music Player

Upload these files to the root of your GitHub repo:
  install.lua
  player.lua
  tracks.json
  all .dfpwm tracks

First install command on CC:
  wget https://raw.githubusercontent.com/dydosux/Player/main/install.lua install
  install

Start player:
  player

Update player code:
  Press R inside player, or reinstall with install.lua.

Update track list and download missing tracks:
  Press Update on the monitor, or press U.

Monitor controls:
  Prev - previous track
  Play - play selected track
  Stop - stop playback
  Next - next track
  Update - refresh GitHub tracks and download missing files
  Volume bar - click/touch to set volume

Keyboard controls:
  Up/Down - select track
  Enter - play selected track
  S - stop
  N/Right - next track
  P/Left - previous track
  U - update tracks
  R - self-update player
  +/- - volume
  T - rescan speakers
  Q - quit

Multiple monitors and speakers:
  The player scans all monitors and speakers visible to the computer.
  Wired modems can expose remote monitors and speakers as peripherals.
  Attach monitors/speakers to the wired modem network, then start player or press T.
