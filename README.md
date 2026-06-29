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

`anonymousFirst` is the default Persistly account mode. It is not Firebase Anonymous Auth, Supabase anonymous sign-in, or an Auth0 guest user. Use `authRequired` when your game requires sign-in before cloud sync:

```gdscript
persistly.configure({
	"runtime_key": "ps_test_replace_me",
	"accountMode": "authRequired",
	"localAccountKey": "signed-in-player",
})

persistly.save_data({ "level": 1 })
var blocked := persistly.force_sync_data({ "bypassCooldown": true })
# blocked["status"] == "auth_required"
```

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

## Auth Bridge

Auth Bridge exchanges a Firebase ID token, Supabase access token, or Auth0 token from your game's auth SDK for a Persistly `accountId` and `accountSessionToken`. Provider tokens are only sent to sign-in/connect exchange routes; normal save/load/sync routes continue using the Persistly account session. Use `sign_in_with_firebase_token` for Firebase, `sign_in_with_supabase_token` for Supabase, or `sign_in_with_auth0_token` for games that require sign-in before cloud sync. Use `connect_with_firebase_token`, `connect_with_supabase_token`, or `connect_with_auth0_token` when a player already has anonymous local/cloud progress and later connects a provider. Configure each provider in the Persistly dashboard before using provider sign-in.

```gdscript
var signed_in := persistly.sign_in_with_firebase_token(firebase_id_token, {
	"deviceLabel": OS.get_name(),
})

var supabase_signed_in := persistly.sign_in_with_supabase_token(supabase_access_token, {
	"deviceLabel": OS.get_name(),
})

var linked := persistly.link_provider({
	"provider": "supabase",
	"token": supabase_access_token,
})

var connected := persistly.connect_with_firebase_token(firebase_id_token, {
	"deviceLabel": OS.get_name(),
})

var providers := persistly.list_linked_providers()
var signed_out := persistly.sign_out()
```

If the provider is already linked to another Persistly account, connect-later returns `account_auth_conflict` and preserves the current local anonymous progress. Do not automatically clear local data or switch accounts; ask the player first.

`sign_in_with_provider`, `connect_provider`, and `link_provider` accept only `"firebase"`, `"supabase"`, and `"auth0"` provider keys. Other provider keys are rejected before the SDK sends a request.

`sign_out()` clears the local Persistly account session and slot cache for this device. It does not delete the remote account.

## Templates

- `templates/one-save` for idle, casual, and one-save games.
- `templates/multi-slot` for manual saves, campaigns, and slot select screens.
- `templates/account-slots` for games with sign-in or cross-device restore.
- `templates/auth-required` for games where cloud sync waits for Firebase, Supabase, or Auth0 sign-in.
- `templates/anonymous-first-connect-later` for games that start anonymous, save first, and connect Firebase, Supabase, or Auth0 later.

## Runtime Surface

Facade methods:

- `configure`
- `create_account`
- `attach_account`
- `create_transfer_code`
- `attach_with_transfer_code`
- `get_account_session`
- `sign_in_with_firebase_token`
- `sign_in_with_supabase_token`
- `sign_in_with_auth0_token`
- `sign_in_with_provider`
- `connect_with_firebase_token`
- `connect_with_supabase_token`
- `connect_with_auth0_token`
- `connect_provider`
- `link_provider`
- `list_linked_providers`
- `sign_out`
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
- `create_auth_session`
- `list_linked_providers`

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
