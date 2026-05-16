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
```

`save_slot` writes locally first. The first remote sync creates the Persistly profile and matching character slot if needed.

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
