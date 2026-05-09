# Persistly Godot Examples

## Last Beacon

`examples/last_beacon/` is the first playable Godot proof for Persistly.

It is an endless idle outpost demo with:

- passive scrap generation every second
- manual gather actions
- worker and core upgrades
- persisted local profile/config under `user://`
- facade-first Persistly slot saves through `PersistlyGameSaves`

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
5. Play the idle loop and use `Sync Now` to push the `autosave` slot to Persistly.

For explicit local development against a local API, override the base URL manually in the sample UI.

What it proves:

- local idle state can resume between launches
- a Godot game can save and load local slot state first
- the SDK can create a Persistly profile lazily and sync a named character slot
- explicit `profileSaveId` plus `profileSessionToken` is the restore path; `playerRef` and `externalProfileRef` are references only, not lookup APIs
