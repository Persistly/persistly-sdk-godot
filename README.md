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

The addon reads the pinned contract bundle from `res://contracts/persistly-contract-v0.3.0`, so copying only the addon without `contracts/` is incomplete.

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
	"playerRef": "player-184",
	"localProfileKey": "player-184",
})

persistly.save_slot("autosave", {"level": 5, "coins": 1200}, {"scene": "starter"})
var loaded := persistly.load_slot("autosave")
var synced := persistly.force_sync("autosave", {"bypassCooldown": true})
```

`PersistlyGameSaves` stores slot state locally first, creates a profile lazily on the first remote sync, and keeps local/cloud conflict state separate until the game chooses a resolution.

For profile-first games, create the profile before character selection:

```gdscript
persistly.save_account_data({"diamonds": 20})
var profile := persistly.ensure_profile()
var session := persistly.get_profile_session({"includeToken": true})
```

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
	"character": {
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
			"characterName": "Ayla",
		},
		"state": {
			"gold": 100,
			"level": 1,
		},
	},
})

var profile_save_id: String = created["profileSaveId"]
var profile_session_token: String = created["profileSessionToken"]
var character_save_id: String = created["character"]["saveId"]

var loaded := client.load_profile_character(
	profile_save_id,
	profile_session_token,
	character_save_id)

var synced := client.sync_profile_character(profile_save_id, profile_session_token, character_save_id, {
	"baseVersion": loaded["save"]["version"],
	"metadata": {
		"_persistly": {
			"slotKey": "autosave",
		},
		"characterName": "Ayla",
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
- `PersistlyGameSaveStatus`
- `PersistlyGameSaveTarget`
- `configure`
- `ensure_profile`
- `get_profile_session`
- `save_account_data`
- `patch_account_data`
- `force_sync_profile`
- `sync_due_profile`
- `save_slot`
- `load_slot`
- `list_slots`
- `inspect_slot`
- `force_sync`
- `sync_due_slots`
- `sync_due`
- `archive_slot`
- `clear_local_slot`
- `accept_cloud_version`
- `overwrite_cloud_version`
- `keep_local_for_later`
- `create_profile`
- `load_profile`
- `create_profile_character`
- `load_profile_character`
- `sync_profile_character`
- `sync_profile_account_data`
- `archive_profile_character`
- advanced raw `create_save`, `load_save`, and `sync_save`
- `get_runtime_config`
- structured error envelopes, including `forbidden` profile-session failures
- in-memory save cache
- `PersistlyMemoryAutosaveDraftStore`
- `PersistlyFileAutosaveDraftStore`
- `PersistlyAutosaveManager`

## Profile Sessions

Profile endpoints require `profileSessionToken`. The SDK sends it as `X-Persistly-Profile-Session` for profile and character routes.

`playerRef` and `externalProfileRef` are optional developer references. `externalProfileRef` must be a dictionary such as `{ "provider": "auth0", "subject": "auth0|user_123" }`. These references are not authentication tokens, not ownership proof, and not public lookup or recovery APIs. Cross-device restore requires explicit `profileSaveId` plus `profileSessionToken`, usually stored by your own trusted backend.

## Local Persistence And Sync

`PersistlyGameSaves` persists schema-versioned profile, slot index, and slot records under `user://` by default. It never starts background timers automatically. Call `sync_due_profile`, `sync_due_slots`, `sync_due`, or `force_sync` from your own lifecycle hooks or explicit save buttons.

`PersistlyAutosaveManager` remains available for advanced integrations that want lower-level draft storage while respecting Persistly remote-sync policy:

- local changes are stored immediately
- remote sync can be throttled by `minRemoteSyncIntervalSeconds`
- explicit sync buttons can use force sync and honor `forceSyncCooldownSeconds`
- if the game closes before remote sync, the local draft is still available

Use `PersistlyFileAutosaveDraftStore` for real players and `PersistlyMemoryAutosaveDraftStore` for tests.

## Contract Bundle

This repo pins `persistly-contract-v0.3.0` under `contracts/`.
The bundle is authoritative for request/response semantics, routes, and runtime limits.

## Validation

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/validate_game_saves.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/validate_contract.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/validate_client.gd
```

## Playable Proof

`examples/last_beacon/` is a small endless idle demo. New integrations should follow the facade-first `PersistlyGameSaves` quickstart above; the raw client remains documented as an advanced reference.

## Release Checklist

- validate the pinned contract bundle
- run the client validation scripts
- launch `Last Beacon` and verify create, load, sync, and conflict handling against a real runtime key
- keep example defaults aligned with `https://api.persistly.app`
