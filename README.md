<p align="center">
  <img src="./assets/persistly-godot-sdk-banner.png" alt="Persistly Godot SDK - Cloud saves for Godot games" />
</p>

# Persistly Godot SDK

[![CI](https://github.com/Persistly/persistly-sdk-godot/actions/workflows/ci.yml/badge.svg)](https://github.com/Persistly/persistly-sdk-godot/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/Persistly/persistly-sdk-godot?sort=semver)](https://github.com/Persistly/persistly-sdk-godot/releases)
[![Godot](https://img.shields.io/badge/Godot-4.2%2B-478cbf)](https://godotengine.org/)
[![license](https://img.shields.io/github/license/Persistly/persistly-sdk-godot.svg)](LICENSE)
[![docs](https://img.shields.io/badge/docs-persistly.app-6467f2)](https://docs.persistly.app/sdk/godot)

Godot runtime SDK for Persistly account-first cloud saves, local-first slot data, account sessions, and explicit sync.

## Install

Copy both directories into your Godot project:

```text
addons/persistly/
contracts/
```

The account-first `persistly-contract-v0.4.0` bundle is included under `contracts/` for release validation.

## Quickstart

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
```

`save_data` writes local data immediately to the default `autosave` slot. The first `force_sync_data`, `sync_due_slots`, or `sync_due` call creates the remote Persistly account and matching slot if needed. Use `save_slot`, `load_slot`, and `force_sync` for multiple named slots.

## Account Sessions

Create an account before a slot picker when your game needs an explicit account session:

```gdscript
persistly.save_account_data({"diamonds": 20})
var created := persistly.create_account()
var session := persistly.get_account_session({"includeToken": true})
```

Attach an existing Persistly account into empty local state:

```gdscript
var attached := persistly.attach_account("acc_01HXYZ", "pst_account_session")
```

Create a short-lived transfer code on the device that already has the account session, then consume it on an empty second device:

```gdscript
var code := persistly.create_transfer_code({
	"deviceLabel": "Steam Deck",
})

var attached := other_device_persistly.attach_with_transfer_code(
	code["transferCode"],
	{"deviceLabel": "Laptop"}
)
```

Transfer codes are short-lived and single-use. Show the code to the player, but do not log it or treat it as a password.

Use `clear_local_account()` before switching players on the same device. It only wipes local SDK state. Use `delete_account()` for permanent remote erasure.

## Templates

- `templates/one-save` for idle, casual, and one-save games.
- `templates/multi-slot` for manual saves, campaigns, and slot select screens.
- `templates/account-slots` for games with sign-in or cross-device restore.

## Runtime Surface

Facade methods:

- `configure`
- `create_account`
- `attach_account`
- `create_transfer_code`
- `attach_with_transfer_code`
- `get_account_session`
- `save_account_data`
- `patch_account_data`
- `get_account_data`
- `force_sync_account`
- `sync_due_account`
- `save_data`
- `load_data`
- `force_sync_data`
- `save_slot`
- `load_slot`
- `list_slot_data`
- `slot_info`
- `refresh_slot`
- `force_sync`
- `sync_due_slots`
- `sync_due`
- `archive_slot`
- `delete_account`
- `delete_slot`
- `clear_local_account`
- `clear_local_slot`
- `accept_cloud_version`
- `overwrite_cloud_version`
- `keep_local_for_later`

Low-level client account methods use the same public facade terms: `accountData`, `slotInfo`, and `data`.

- `create_account`
- `load_account`
- `sync_account_data`
- `create_transfer_code`
- `consume_transfer_code`
- `create_account_slot`
- `load_account_slot`
- `sync_account_slot`
- `archive_account_slot`
- `delete_account_slot`
- `delete_account`
- `get_runtime_config`

Account and slot routes send `X-Persistly-Account-Session`. Release packages do not expose legacy compatibility aliases.

## Validate Local Changes

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/validate_contract.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/validate_client.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/validate_game_saves.gd
```

## Live Parity Smoke

Run this only with a dev/test runtime key:

```bash
PERSISTLY_RUNTIME_KEY=ps_test_replace_me scripts/live_smoke.sh
```

## Example Project

`examples/last_beacon/` is a small endless idle demo using `PersistlyGameSaves`, the default `autosave` slot, account sessions, and local-first slot data.
