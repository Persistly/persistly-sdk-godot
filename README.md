# Persistly Godot SDK

Godot runtime SDK for Persistly game-friendly slot saves, profile saves, profile sessions, character save-sync, and local autosave support.

Persistly is a lightweight cloud save backend for games. The recommended Godot flow is:

1. Start with `PersistlyGameSaves` and named slots such as `autosave`.
2. Save gameplay state locally first.
3. Load by slot key when the game resumes.
4. Force sync at safe moments or on explicit player action.

Raw `PersistlyClient` profile and save APIs remain available for advanced runtime integrations and migrations.

## Install

Copy both directories into your Godot project:

```text
addons/persistly/
contracts/
```

The addon reads the pinned contract bundle from `res://contracts/persistly-contract-v0.2.0`, so copying only the addon without `contracts/` is incomplete.

When the public repository is connected, use:

```text
https://github.com/Persistly/persistly-sdk-godot
```

## Quickstart

```gdscript
const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()
persistly.configure({
	"runtime_key": "ps_test_replace_me",
	"sync_interval_seconds": 40,
})

await persistly.save_slot("autosave", {"level": 5, "coins": 1200})
var loaded := await persistly.load_slot("autosave")
await persistly.force_sync("autosave")
```

`PersistlyGameSaves` stores slot state locally first. This initial facade keeps remote profile sync unwired; `force_sync` is present so games can wire the same call site now and gain remote behavior later.

## Advanced Runtime Client

Use `PersistlyClient` directly when you need profile sessions, character save IDs, raw save migration, or lower-level conflict handling.

```gdscript
const PersistlyClient := preload("res://addons/persistly/persistly_client.gd")

var client := PersistlyClient.new()
client.configure_runtime_key("ps_test_...")

var created := client.create_profile({
	"playerRef": "player-184",
	"profileMetadata": {
		"displayName": "Ayla",
	},
	"accountData": {
		"diamonds": 20,
	},
	"characterMetadata": {
		"characterName": "Ayla",
		"slot": 1,
	},
	"characterState": {
		"gold": 100,
		"level": 1,
	},
})

var profile_save_id: String = created["profile"]["profileSaveId"]
var profile_session_token: String = created["profile"]["profileSessionToken"]
var character_save_id: String = created["character"]["save"]["saveId"]

var loaded := client.load_profile_character(
	profile_save_id,
	profile_session_token,
	character_save_id)

var synced := client.sync_profile_character(profile_save_id, profile_session_token, character_save_id, {
	"baseVersion": loaded["save"]["version"],
	"metadata": {
		"characterName": "Ayla",
		"slot": 1,
	},
	"state": {
		"gold": 120,
		"level": 2,
	},
})

if synced.get("status", "") == "conflict":
	# synced["save"] is the canonical server character save. Reconcile intentionally.
	pass
```

## Runtime Surface

The package includes:

- `PersistlyGameSaves`
- `PersistlySlotStatus`
- `configure`
- `save_slot`
- `load_slot`
- `force_sync`
- `accept_cloud_version`
- `overwrite_cloud_version`
- `keep_local_for_later`
- `create_profile`
- `load_profile`
- `create_profile_character`
- `load_profile_character`
- `sync_profile_character`
- advanced raw `create_save`, `load_save`, and `sync_save`
- `get_runtime_config`
- structured error envelopes, including `forbidden` profile-session failures
- in-memory save cache
- `PersistlyMemoryAutosaveDraftStore`
- `PersistlyFileAutosaveDraftStore`
- `PersistlyAutosaveManager`

## Profile Sessions

Profile endpoints require `profileSessionToken`. The SDK sends it as `X-Persistly-Profile-Session` for profile and character routes.

`playerRef` and `externalProfileRef` are optional developer references. `externalProfileRef` must be a dictionary such as `{ "provider": "auth0", "subject": "auth0|user_123" }`. These references are not authentication tokens, not ownership proof, and not public lookup APIs. Store `profileSaveId` and `profileSessionToken` locally or in your own trusted backend.

## Autosave

`PersistlyAutosaveManager` lets games write every state change to local storage while respecting Persistly remote-sync policy:

- local changes are stored immediately
- remote sync can be throttled by `minRemoteSyncIntervalSeconds`
- explicit sync buttons can use force sync and honor `forceSyncCooldownSeconds`
- if the game closes before remote sync, the local draft is still available

Use `PersistlyFileAutosaveDraftStore` for real players and `PersistlyMemoryAutosaveDraftStore` for tests.

## Contract Bundle

This repo pins `persistly-contract-v0.2.0` under `contracts/`.
The bundle is authoritative for request/response semantics, routes, and runtime limits.

## Validation

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/validate_game_saves.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/validate_contract.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/validate_client.gd
```

## Playable Proof

`examples/last_beacon/` is a small endless idle demo that stores local profile/config under `user://` and wires Persistly create/load/sync from inside a real Godot project.

## Release Checklist

- validate the pinned contract bundle
- run the client validation scripts
- launch `Last Beacon` and verify create, load, sync, and conflict handling against a real runtime key
- keep example defaults aligned with `https://api.persistly.app`
