# Persistly Godot Addon

Persistly is a lightweight cloud-save backend for games. This addon provides the account-first Godot runtime SDK for local-first slot data, account data, account sessions, safe sync timing, and explicit conflict handling.

## Start Here

```gdscript
const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()
persistly.configure({
  "runtime_key": "ps_test_replace_me",
  "playerRef": "player-184",
  "localAccountKey": "player-184",
})

persistly.save_data({
  "level": 5,
  "coins": 1200,
}, {
  "slotInfo": {
    "characterName": "Ayla",
    "level": 5,
  },
})

var loaded := persistly.load_data()
var synced := persistly.force_sync_data({"bypassCooldown": true})
var session := persistly.get_account_session({"includeToken": true})
```

`save_data` writes locally first to the default `autosave` slot. The first remote sync creates the Persistly account and matching slot if needed. Use `save_slot`, `load_slot`, and `force_sync` when your game needs multiple named slots.

Use `clear_local_account()` to wipe the local account session plus all local slots for the current namespace before switching players on the same device.

Use `create_account()` for explicit account-first flows, or `attach_account(accountId, accountSessionToken)` to load an existing Persistly account into empty local state.

Use `create_transfer_code()` on a device that already has a local account session, and `attach_with_transfer_code(code)` on an empty second device for short-lived anonymous save transfer. Transfer codes are single-use and should be shown to the player without logging them.

Use `get_account_data()` for account-wide data. `patch_account_data()` shallow-merges top-level keys and deletes a top-level key when its patch value is `null`.

Use `delete_slot(slotId)` for slot erasure. Use `delete_account()` to clear local-only state or remotely delete the synced account and then wipe local session plus slots.

## Install

Copy these folders into your Godot project:

```text
addons/persistly/
contracts/
```

The account-first contract bundle `persistly-contract-v0.4.0` is included under `contracts/` for release validation.

## Docs

- Main docs: https://docs.persistly.app/sdk/godot
- Templates: https://docs.persistly.app/templates/godot
- Runtime/API reference: https://docs.persistly.app/runtime-api
- Repository: https://github.com/Persistly/persistly-sdk-godot

## License

Apache-2.0. See `LICENSE` in this folder.
