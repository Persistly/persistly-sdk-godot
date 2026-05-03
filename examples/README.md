# Persistly Godot Examples

## Last Beacon

`examples/last_beacon/` is the first playable Godot proof for Persistly.

It is an endless idle outpost demo with:

- passive scrap generation every second
- manual gather actions
- worker and core upgrades
- persisted local profile/config under `user://last_beacon_profile.json`
- explicit Persistly create/load/sync wiring through the Godot SDK

To run it:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path "$(pwd)"
```

Inside the game:

1. Use `https://api.persistly.app` as the API base URL for standard Persistly traffic.
2. Paste a `ps_test_...` runtime key from the Persistly dashboard.
3. Optionally fill `Player reference`, `Character Name`, and `Slot Label`.
4. Press `Connect / Resume Remote Save`.
5. Play the idle loop and use `Sync Now` to push canonical state to Persistly.

For explicit local development against a local API, override the base URL manually in the sample UI.

What it proves:

- local idle state can resume between launches
- the game can create a new Persistly save from inside Godot
- the game can reload an existing save by explicit `saveId`
- the game can sync canonical state and keep version tracking visible
