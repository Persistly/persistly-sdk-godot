# Persistly Godot Examples

## Last Beacon

`examples/last_beacon/` is the first playable Godot proof for Persistly.

It is an endless idle outpost demo with:

- passive scrap generation every second
- manual gather actions
- worker and core upgrades
- persisted local account/config under `user://`
- facade-first Persistly slot saves through `PersistlyGameSaves`

To run it:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path "$(pwd)"
```

Inside the game:

1. Paste a `ps_test_...` runtime key from the Persistly dashboard.
2. Optionally fill `Player reference`, `Character Name`, and `Slot Label`.
3. Press `Connect / Resume Remote Save`.
4. Play the idle loop and use `Sync Now` to push the `autosave` slot to Persistly.

What it proves:

- local idle state can resume between launches
- a Godot game can save and load local slot state first
- the SDK can create a Persistly account lazily and sync a named save slot
- explicit `accountId` plus `accountSessionToken` is the restore path; `playerRef` and `externalAccountRef` are references only, not lookup APIs

## Auth Bridge

- `auth_google_usage.gd` shows `authRequired` mode with `sign_in_with_google_id_token`.
- `auth_oidc_usage.gd` shows generic `oidc_jwt` sign-in, provider linking, and linked provider listing.

These examples assume provider trust is already configured for the Persistly project environment.
