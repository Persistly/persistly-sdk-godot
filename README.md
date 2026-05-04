# Persistly Godot SDK

Godot runtime SDK for Persistly profile saves, profile sessions, character save-sync, and local autosave support.

Persistly is a lightweight cloud save backend for games. The recommended Godot flow is:

1. Create a profile with the first character.
2. Persist `profileSaveId`, `profileSessionToken`, and character `saveId` locally.
3. Load and sync characters through the profile session.
4. Keep gameplay state local first, then sync remotely at safe intervals or on explicit player action.

Raw `create_save`, `load_save`, and `sync_save` remain available for advanced migrations, but new games should start with profile sessions.

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
