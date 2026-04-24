#!/usr/bin/liquidsoap
#
# SoloMoon's Club — Phase 1 + 3: 24/7 playlist + Live DJ via harbor
# Liquidsoap 2.2.x

settings.log.level.set(3)
settings.log.stdout.set(true)
settings.server.telnet.set(true)
settings.server.telnet.bind_addr.set("127.0.0.1")
settings.server.telnet.port.set(1234)

# Live DJ input (harbor)
live = input.harbor(
  id="live",
  port=8005,
  auth=fun(login, password) ->
    password == environment.get("HARBOR_PASSWORD"),
  "/live"
)

# Playlist source
playlist_source = playlist(
  id="fallback",
  mode="randomize",
  reload=1800,
  reload_mode="rounds",
  "/music"
)

silence = blank()
safe_source = fallback(track_sensitive=false, [playlist_source, silence])

playlist_mixed = crossfade(
  duration=3.0,
  fade_in=2.0,
  fade_out=2.0,
  smart=true,
  safe_source
)

playlist_normalized = normalize(
  target=-14.0,
  gain_min=-6.0,
  gain_max=6.0,
  playlist_mixed
)

# Final source
radio = fallback(track_sensitive=false, [live, playlist_normalized])

# Icecast output
output.icecast(
  %mp3(bitrate=320, samplerate=44100, stereo=true),
  id="solomoon-stream",
  host=environment.get("ICECAST_HOST"),
  port=int_of_string(environment.get("ICECAST_PORT")),
  password=environment.get("ICECAST_SOURCE_PASSWORD"),
  mount="/stream.mp3",
  name="SoloMoon's Club",
  description="House · Deep House · EDM · R&B — Доброград",
  genre="House Deep-House EDM R&B",
  url="http://" ^ environment.get("ICECAST_HOSTNAME", "localhost") ^ ":8000/",
  public=false,
  encoding="UTF-8",
  chunked=true,
  send_icy_metadata=true,
  buffer(buffer=0.2, max=5.0, radio)
)

log("=== SoloMoon's Club is on air ===")
