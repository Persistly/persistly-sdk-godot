# Persistly Godot Addon

Persistly is a lightweight cloud-save backend for games. This addon provides the Godot runtime SDK for named save slots, profile account data, local-first persistence, profile sessions, safe sync timing, and explicit conflict handling.

## Start Here

```gdscript
const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()
persistly.configure({
  "runtime_key": "ps_test_replace_me",
  "playerRef": "player-184",
  "localProfileKey": "player-184",
})

persistly.save_slot("autosave", {
  "level": 5,
  "coins": 1200,
})

var loaded := persistly.load_slot("autosave")
var synced := persistly.force_sync("autosave", {"bypassCooldown": true})

# After restoring an existing profile session on another device:
var refreshed := persistly.refresh_slot("autosave")
```

`save_slot` writes locally first and guarantees a local profile envelope exists. The first remote sync creates the Persistly profile and matching character slot if needed.

Use `clear_local_profile()` to wipe the local profile session plus all local slots for the current namespace before switching players on the same device.

For explicit profile-first flows, use `create_profile()` to create one facade-managed Persistly profile, or `attach_profile(profileSaveId, profileSessionToken)` to load an already existing Persistly profile into empty local state.

Use `inspect_profile()` and `get_account_data()` for account-wide state such as bundles, shared inventory, settings, or display currency balances. `patch_account_data()` shallow-merges top-level keys and deletes a top-level key when its patch value is `null`.

Use `delete_slot(slotKey)` for JS-style delete parity: unsynced slots clear locally, synced slots delete the remote profile character and remove local state. Use `delete_profile()` to clear local-only state or remotely delete the synced profile and then wipe local session plus slots.

## Install

Copy these folders into your Godot project:

```text
addons/persistly/
contracts/
```

The contract bundle is required because the SDK validates against `res://contracts/persistly-contract-v0.3.0`.

## Docs

- Main docs: https://docs.persistly.app/sdk/godot
- Runtime/API reference: https://docs.persistly.app/runtime-api
- Repository: https://github.com/Persistly/persistly-sdk-godot

## License

Apache-2.0. See `LICENSE` in this folder.
