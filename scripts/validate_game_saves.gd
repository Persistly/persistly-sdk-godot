extends SceneTree

const GAME_SAVES_SCRIPT := "res://addons/persistly/persistly_game_saves.gd"

const PROFILE_SAVE := {
	"saveId": "sv_profile",
	"playerRef": "player-184",
	"metadata": {
		"displayName": "Ayla",
	},
	"state": {
		"schema": "persistly.profile.v1",
		"accountData": {},
		"characterSlots": [],
	},
	"version": 1,
	"createdAt": "2026-04-09T10:00:00Z",
	"updatedAt": "2026-04-09T10:00:00Z",
}

const CHARACTER_SAVE := {
	"saveId": "sv_char",
	"playerRef": "player-184",
	"metadata": {
		"_persistly": {
			"slotKey": "autosave",
		},
		"scene": "cloud",
	},
	"state": {
		"level": 5,
		"coins": 1200,
	},
	"version": 2,
	"createdAt": "2026-04-09T10:01:00Z",
	"updatedAt": "2026-04-09T10:02:00Z",
}

const REPLACEMENT_CHARACTER_SAVE := {
	"saveId": "sv_char_replacement",
	"playerRef": "player-184",
	"metadata": {
		"_persistly": {
			"slotKey": "autosave",
		},
		"scene": "replacement",
	},
	"state": {
		"level": 1,
		"coins": 50,
	},
	"version": 1,
	"createdAt": "2026-04-09T10:06:00Z",
	"updatedAt": "2026-04-09T10:06:00Z",
}

const PROFILE_WITH_CHARACTER_SAVE := {
	"saveId": "sv_profile",
	"playerRef": "player-184",
	"metadata": {
		"displayName": "Ayla",
	},
	"state": {
		"schema": "persistly.profile.v1",
		"accountData": {},
		"characterSlots": [
			{
				"slotKey": "autosave",
				"characterSaveId": "sv_char",
				"metadata": {
					"scene": "starter",
				},
			},
		],
	},
	"version": 2,
	"createdAt": "2026-04-09T10:00:00Z",
	"updatedAt": "2026-04-09T10:01:00Z",
}

const PROFILE_CREATE_RESPONSE := {
	"profileSaveId": "sv_profile",
	"profileSessionToken": "pst_profile_session",
	"profile": PROFILE_SAVE,
	"syncPolicy": {
		"minRemoteSyncIntervalSeconds": 60,
		"forceSyncCooldownSeconds": 10,
		"syncOnAppBackground": true,
		"syncOnAppForeground": true,
		"syncOnReconnect": true,
		"maxQueuedLocalSnapshots": 25,
	},
}

const CHARACTER_CREATE_RESPONSE := {
	"profileSaveId": "sv_profile",
	"profile": PROFILE_WITH_CHARACTER_SAVE,
	"character": CHARACTER_SAVE,
	"syncPolicy": {
		"minRemoteSyncIntervalSeconds": 60,
		"forceSyncCooldownSeconds": 10,
		"syncOnAppBackground": true,
		"syncOnAppForeground": true,
		"syncOnReconnect": true,
		"maxQueuedLocalSnapshots": 25,
	},
}

const FIRST_PROFILE_CREATE_WITH_CHARACTER_RESPONSE := {
	"profileSaveId": "sv_profile",
	"profileSessionToken": "pst_profile_session",
	"profile": PROFILE_WITH_CHARACTER_SAVE,
	"character": CHARACTER_SAVE,
	"syncPolicy": {
		"minRemoteSyncIntervalSeconds": 60,
		"forceSyncCooldownSeconds": 10,
		"syncOnAppBackground": true,
		"syncOnAppForeground": true,
		"syncOnReconnect": true,
		"maxQueuedLocalSnapshots": 25,
	},
}

const SYNC_ACCEPTED_RESPONSE := {
	"status": "accepted",
	"save": {
		"saveId": "sv_char",
		"playerRef": "player-184",
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
			"scene": "starter",
		},
		"state": {
			"level": 6,
			"coins": 1400,
		},
		"version": 3,
		"createdAt": "2026-04-09T10:01:00Z",
		"updatedAt": "2026-04-09T10:03:00Z",
	},
}

const SYNC_CONFLICT_RESPONSE := {
	"status": "conflict",
	"save": {
		"saveId": "sv_char",
		"playerRef": "player-184",
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
			"scene": "cloud",
		},
		"state": {
			"level": 8,
			"coins": 3000,
		},
		"version": 4,
		"createdAt": "2026-04-09T10:01:00Z",
		"updatedAt": "2026-04-09T10:04:00Z",
	},
	"details": {
		"reason": "base_version_mismatch",
	},
}

const ACCOUNT_SYNC_RESPONSE := {
	"status": "accepted",
	"save": {
		"saveId": "sv_profile",
		"playerRef": "player-184",
		"metadata": {
			"displayName": "Ayla",
		},
		"state": {
			"schema": "persistly.profile.v1",
			"accountData": {
				"diamonds": 25,
			},
			"characterSlots": [
				{
					"slotKey": "autosave",
					"characterSaveId": "sv_char",
					"metadata": {
						"scene": "starter",
					},
				},
			],
		},
		"version": 3,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:03:00Z",
	},
}

const ACCOUNT_SYNC_CONFLICT_RESPONSE := {
	"status": "conflict",
	"save": {
		"saveId": "sv_profile",
		"playerRef": "player-184",
		"metadata": {
			"displayName": "Cloud",
		},
		"state": {
			"schema": "persistly.profile.v1",
			"accountData": {
				"diamonds": 40,
				"region": "eu",
			},
			"characterSlots": [
				{
					"slotKey": "autosave",
					"characterSaveId": "sv_char",
					"metadata": {
						"scene": "starter",
					},
				},
			],
		},
		"version": 5,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:06:00Z",
	},
	"details": {
		"reason": "base_version_mismatch",
	},
}

const ARCHIVE_RESPONSE := {
	"profileSaveId": "sv_profile",
	"profile": {
		"saveId": "sv_profile",
		"playerRef": "player-184",
		"metadata": {
			"displayName": "Ayla",
		},
		"state": {
			"schema": "persistly.profile.v1",
			"accountData": {
				"diamonds": 25,
			},
			"characterSlots": [
				{
					"slotKey": "autosave",
					"characterSaveId": "sv_char",
					"metadata": {
						"scene": "starter",
					},
					"archived": true,
					"archivedAt": "2026-04-09T10:05:00Z",
				},
			],
		},
		"version": 4,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:05:00Z",
	},
}

const REPLACEMENT_CHARACTER_CREATE_RESPONSE := {
	"profileSaveId": "sv_profile",
	"profile": {
		"saveId": "sv_profile",
		"playerRef": "player-184",
		"metadata": {
			"displayName": "Ayla",
		},
		"state": {
			"schema": "persistly.profile.v1",
			"accountData": {
				"diamonds": 25,
			},
			"characterSlots": [
				{
					"slotKey": "autosave",
					"characterSaveId": "sv_char",
					"metadata": {
						"scene": "starter",
					},
					"archived": true,
					"archivedAt": "2026-04-09T10:05:00Z",
				},
				{
					"slotKey": "autosave",
					"characterSaveId": "sv_char_replacement",
					"metadata": {
						"scene": "replacement",
					},
				},
			],
		},
		"version": 5,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:06:00Z",
	},
	"character": REPLACEMENT_CHARACTER_SAVE,
	"syncPolicy": {
		"minRemoteSyncIntervalSeconds": 60,
		"forceSyncCooldownSeconds": 10,
		"syncOnAppBackground": true,
		"syncOnAppForeground": true,
		"syncOnReconnect": true,
		"maxQueuedLocalSnapshots": 25,
	},
}

var _failure_count := 0
var _run_storage_prefix := "user://persistly_validation/run_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())


func _initialize() -> void:
	var game_saves_script := load(GAME_SAVES_SCRIPT)
	if game_saves_script == null or not game_saves_script.can_instantiate():
		_fail("Could not load game saves facade at " + GAME_SAVES_SCRIPT)
		_finish()
		return

	_check_status_and_target_constants(game_saves_script)
	_check_not_configured(game_saves_script)
	_check_configured_local_slot_flow(game_saves_script)
	_check_profile_session_and_account_data(game_saves_script)
	_check_existing_profile_session_loads_remote_profile(game_saves_script)
	_check_profile_only_ensure_and_remote_slot_sync(game_saves_script)
	_check_duplicate_remote_slot_is_reconciled(game_saves_script)
	_check_first_dirty_slot_sync_creates_profile_with_character(game_saves_script)
	_check_sync_policy_and_cooldown(game_saves_script)
	_check_profile_conflict_payload(game_saves_script)
	_check_conflict_helpers(game_saves_script)
	_check_archive_and_clear(game_saves_script)
	_check_archived_slot_can_be_reused(game_saves_script)
	_check_rejects_reserved_developer_metadata(game_saves_script)
	_check_schema_versioned_file_persistence(game_saves_script)
	_finish()


func _check_status_and_target_constants(game_saves_script: Script) -> void:
	var status = game_saves_script.PersistlyGameSaveStatus
	_expect_equal(status.LOCAL_SAVED, "local_saved", "PersistlyGameSaveStatus.LOCAL_SAVED")
	_expect_equal(status.LOCAL_FOUND, "local_found", "PersistlyGameSaveStatus.LOCAL_FOUND")
	_expect_equal(status.NOT_FOUND, "not_found", "PersistlyGameSaveStatus.NOT_FOUND")
	_expect_equal(status.NO_CHANGES, "no_changes", "PersistlyGameSaveStatus.NO_CHANGES")
	_expect_equal(status.COOLDOWN, "cooldown", "PersistlyGameSaveStatus.COOLDOWN")
	_expect_equal(status.SYNCED, "synced", "PersistlyGameSaveStatus.SYNCED")
	_expect_equal(status.CONFLICT, "conflict", "PersistlyGameSaveStatus.CONFLICT")
	_expect_equal(status.OFFLINE, "offline", "PersistlyGameSaveStatus.OFFLINE")
	_expect_equal(status.RATE_LIMITED, "rate_limited", "PersistlyGameSaveStatus.RATE_LIMITED")

	var target = game_saves_script.PersistlyGameSaveTarget
	_expect_equal(target.PROFILE, "profile", "PersistlyGameSaveTarget.PROFILE")
	_expect_equal(target.SLOT, "slot", "PersistlyGameSaveTarget.SLOT")


func _check_not_configured(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	var result: Dictionary = persistly.save_slot("autosave", {
		"level": 1,
	})
	if result.get("status", "") != "not_configured":
		_fail("save_slot before configure should return status not_configured.")
	if typeof(result.get("error", {})) != TYPE_DICTIONARY:
		_fail("save_slot before configure should include a clear error envelope.")
	elif result["error"].get("code", "") != "not_configured":
		_fail("save_slot before configure error code should be not_configured.")


func _check_configured_local_slot_flow(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	var configure_result: Dictionary = persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"sync_interval_seconds": 40,
		"playerRef": "player-184",
		"externalProfileRef": {
			"provider": "auth0",
			"subject": "auth0|user_123",
		},
		"localProfileKey": "validation-local-flow",
		"storage_path": _storage_path("local_flow"),
	})
	if configure_result.get("status", "") != "configured":
		_fail("configure with runtime_key should return configured status.")
	if configure_result.get("localProfileKey", "") != "validation-local-flow":
		_fail("configure should expose the resolved local profile key.")

	var save_result: Dictionary = persistly.save_slot("autosave", {
		"level": 5,
		"coins": 1200,
	}, {
		"scene": "starter",
	})
	if save_result.get("status", "") != "local_saved":
		_fail("save_slot should return local_saved status.")
	if save_result.get("slotKey", "") != "autosave":
		_fail("save_slot should echo the slot key.")
	if bool(save_result.get("dirty", false)) != true:
		_fail("save_slot should mark the local slot dirty.")
	_expect_dictionary(save_result.get("state", {}), {
		"level": 5,
		"coins": 1200,
	}, "save_slot state")

	var loaded: Dictionary = persistly.load_slot("autosave")
	if loaded.get("status", "") != "local_found":
		_fail("load_slot should report local_found for locally stored slots.")
	_expect_dictionary(loaded.get("state", {}), {
		"level": 5,
		"coins": 1200,
	}, "load_slot state")
	_expect_dictionary(loaded.get("metadata", {}), {
		"scene": "starter",
	}, "load_slot metadata")

	var listed: Array = persistly.list_slots()
	if listed.size() != 1 or listed[0].get("slotKey", "") != "autosave":
		_fail("list_slots should return active local slots.")

	var inspected: Dictionary = persistly.inspect_slot("autosave")
	if inspected.get("status", "") != "local_found" or not inspected.has("updatedAtUnix"):
		_fail("inspect_slot should expose local slot metadata without a network request.")


func _check_profile_session_and_account_data(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"localProfileKey": "validation-account",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"storage_path": _storage_path("account"),
	})
	persistly._client.register_fixture_response("GET", "/api/v1/profiles/sv_profile", 200, PROFILE_CREATE_RESPONSE)
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/account-data/sync", 200, ACCOUNT_SYNC_RESPONSE)

	var session_without_token: Dictionary = persistly.get_profile_session()
	if session_without_token.has("profileSessionToken"):
		_fail("get_profile_session should not return profileSessionToken unless explicitly requested.")
	var session_with_token: Dictionary = persistly.get_profile_session({
		"includeToken": true,
	})
	_expect_equal(session_with_token.get("profileSessionToken", ""), "pst_profile_session", "get_profile_session includeToken")

	var saved: Dictionary = persistly.save_account_data({
		"diamonds": 20,
	})
	_expect_equal(saved.get("status", ""), "local_saved", "save_account_data status")
	var patched: Dictionary = persistly.patch_account_data({
		"diamonds": 25,
		"obsolete": null,
	})
	_expect_equal(patched.get("accountData", {}).get("diamonds", 0), 25, "patch_account_data shallow patch")
	if patched.get("accountData", {}).has("obsolete"):
		_fail("patch_account_data should delete keys patched to null.")

	var synced: Dictionary = persistly.force_sync_profile({
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "force_sync_profile status")
	_expect_equal(synced.get("target", ""), "profile", "force_sync_profile target")


func _check_existing_profile_session_loads_remote_profile(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"localProfileKey": "validation-restore",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"storage_path": _storage_path("restore"),
	})
	persistly._client.register_fixture_response("GET", "/api/v1/profiles/sv_profile", 200, PROFILE_CREATE_RESPONSE)

	var ensured: Dictionary = persistly.ensure_profile()
	_expect_equal(ensured.get("status", ""), "synced", "restored ensure_profile status")
	_expect_equal(ensured.get("version", 0), 1, "restored ensure_profile version")
	_expect_dictionary(ensured.get("metadata", {}), PROFILE_SAVE["metadata"], "restored ensure_profile metadata")
	if persistly._client.get_recorded_requests().is_empty():
		_fail("ensure_profile with an existing profile session should load the remote profile.")


func _check_profile_only_ensure_and_remote_slot_sync(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"playerRef": "player-184",
		"localProfileKey": "validation-sync",
		"storage_path": _storage_path("sync"),
	})
	persistly._client.register_fixture_response("GET", "/api/v1/runtime-config", 200, {
		"syncPolicy": PROFILE_CREATE_RESPONSE["syncPolicy"],
	})
	persistly._client.register_fixture_response("POST", "/api/v1/profiles", 201, PROFILE_CREATE_RESPONSE)
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters", 201, CHARACTER_CREATE_RESPONSE)

	var ensured: Dictionary = persistly.ensure_profile()
	_expect_equal(ensured.get("status", ""), "synced", "ensure_profile status")
	if ensured.has("profileSessionToken"):
		_fail("ensure_profile should not return profileSessionToken by default.")
	_expect_equal(persistly.get_profile_session({"includeToken": true}).get("profileSessionToken", ""), "pst_profile_session", "ensure_profile stored token")

	var save_result: Dictionary = persistly.save_slot("autosave", {
		"level": 5,
		"coins": 1200,
	}, {
		"scene": "starter",
	})
	_expect_equal(save_result.get("status", ""), "local_saved", "save_slot before remote create")

	var synced: Dictionary = persistly.force_sync("autosave", {
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "force_sync first character create")
	_expect_equal(synced.get("target", ""), "slot", "force_sync target")
	_expect_equal(synced.get("characterSaveId", ""), "sv_char", "force_sync characterSaveId")
	var inspected: Dictionary = persistly.inspect_slot("autosave")
	_expect_equal(inspected.get("dirty", true), false, "force_sync clears dirty flag")
	_expect_dictionary(inspected.get("cloudState", {}), CHARACTER_SAVE["state"], "force_sync stores cloud state separately")


func _check_duplicate_remote_slot_is_reconciled(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"playerRef": "player-184",
		"localProfileKey": "validation-duplicate-slot-recovery",
		"storage_path": _storage_path("duplicate_slot_recovery"),
		"syncPolicy": {
			"minRemoteSyncIntervalSeconds": 60,
			"forceSyncCooldownSeconds": 0,
			"syncOnAppBackground": true,
			"syncOnAppForeground": true,
			"syncOnReconnect": true,
			"maxQueuedLocalSnapshots": 25,
		},
	})
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters", 409, {
		"error": {
			"code": "slot_already_exists",
			"message": "An active character already exists for this slot key.",
		},
	})
	persistly._client.register_fixture_response("GET", "/api/v1/profiles/sv_profile", 200, {
		"profileSaveId": "sv_profile",
		"profile": PROFILE_WITH_CHARACTER_SAVE,
		"syncPolicy": PROFILE_CREATE_RESPONSE["syncPolicy"],
	})
	persistly._client.register_fixture_response("GET", "/api/v1/profiles/sv_profile/characters/sv_char", 200, {
		"save": CHARACTER_SAVE,
	})
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/sync", 200, SYNC_ACCEPTED_RESPONSE)
	persistly.save_slot("autosave", {
		"level": 6,
		"coins": 1400,
	}, {
		"scene": "local",
	})

	var synced: Dictionary = persistly.force_sync("autosave", {
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "duplicate remote slot recovery sync status")
	_expect_equal(synced.get("characterSaveId", ""), "sv_char", "duplicate remote slot recovery stores characterSaveId")
	var requests: Array = persistly._client.get_recorded_requests()
	if requests.size() != 4:
		_fail("duplicate remote slot recovery should create, reload profile, load character, then sync.")
	elif requests[3].get("path", "") != "/api/v1/profiles/sv_profile/characters/sv_char/sync":
		_fail("duplicate remote slot recovery should retry using the reconciled character save id.")


func _check_first_dirty_slot_sync_creates_profile_with_character(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"baseUrl": "http://127.0.0.1:9",
		"runtime_key": "ps_test_replace_me",
		"playerRef": "player-184",
		"localProfileKey": "validation-atomic-first-slot",
		"storage_path": _storage_path("atomic_first_slot"),
	})
	persistly._client.register_fixture_response("POST", "/api/v1/profiles", 201, FIRST_PROFILE_CREATE_WITH_CHARACTER_RESPONSE)
	persistly.save_slot("autosave", {
		"level": 5,
		"coins": 1200,
	}, {
		"scene": "starter",
	})

	var synced: Dictionary = persistly.force_sync("autosave", {
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "first dirty slot sync creates profile with character in one request")
	_expect_equal(synced.get("characterSaveId", ""), "sv_char", "first dirty slot sync stores returned characterSaveId")
	_expect_equal(persistly.get_profile_session({"includeToken": true}).get("profileSessionToken", ""), "pst_profile_session", "first dirty slot sync stores profile token")
	var requests: Array = persistly._client.get_recorded_requests()
	if requests.size() != 1:
		_fail("first dirty slot sync should make exactly one remote request.")
	elif requests[0].get("method", "") != "POST" or requests[0].get("path", "") != "/api/v1/profiles":
		_fail("first dirty slot sync should create the profile and first character with POST /api/v1/profiles.")
	else:
		var headers: Array = requests[0].get("headers", [])
		if not headers.has("X-Persistly-SDK: godot"):
			_fail("first dirty slot sync should send X-Persistly-SDK diagnostics header.")
		if not headers.has("X-Persistly-SDK-Version: 1.0.0"):
			_fail("first dirty slot sync should send X-Persistly-SDK-Version diagnostics header.")
		if not headers.has("X-Persistly-Platform: godot"):
			_fail("first dirty slot sync should send X-Persistly-Platform diagnostics header.")
		var body = requests[0].get("body", {})
		if typeof(body) != TYPE_DICTIONARY or typeof(body.get("character", null)) != TYPE_DICTIONARY:
			_fail("first dirty slot sync create_profile request should include the first character payload.")


func _check_sync_policy_and_cooldown(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"localProfileKey": "validation-policy",
		"storage_path": _storage_path("policy"),
		"syncPolicy": {
			"minRemoteSyncIntervalSeconds": 60,
			"forceSyncCooldownSeconds": 10,
			"syncOnAppBackground": true,
			"syncOnAppForeground": true,
			"syncOnReconnect": true,
			"maxQueuedLocalSnapshots": 25,
		},
	})
	persistly.save_slot("autosave", {
		"level": 6,
	}, {
		"scene": "starter",
	})
	persistly._slots["autosave"]["characterSaveId"] = "sv_char"
	persistly._slots["autosave"]["version"] = 2
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/sync", 200, SYNC_ACCEPTED_RESPONSE)

	var first: Dictionary = persistly.force_sync("autosave", {
		"bypassCooldown": true,
	})
	_expect_equal(first.get("status", ""), "synced", "first force_sync status")
	persistly.save_slot("autosave", {
		"level": 7,
	}, {
		"scene": "starter",
	})

	var cooled: Dictionary = persistly.force_sync("autosave")
	_expect_equal(cooled.get("status", ""), "cooldown", "force_sync should respect cooldown by default")

	var skipped: Array = persistly.sync_due_slots({
		"includeSkipped": true,
	})
	if skipped.is_empty() or skipped[0].get("status", "") != "cooldown":
		_fail("sync_due_slots should report cooldown skips when includeSkipped is true.")


func _check_profile_conflict_payload(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	var events: Array = []
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"localProfileKey": "validation-profile-conflict",
		"storage_path": _storage_path("profile_conflict"),
		"onSyncResult": func(result: Dictionary) -> void:
			events.append(result),
	})
	persistly.profile_metadata = {
		"displayName": "Local",
	}
	persistly.profile_version = 3
	persistly.save_account_data({
		"diamonds": 35,
		"region": "us",
	})
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/account-data/sync", 409, ACCOUNT_SYNC_CONFLICT_RESPONSE)

	var conflict: Dictionary = persistly.force_sync_profile({
		"bypassCooldown": true,
	})
	_expect_equal(conflict.get("status", ""), "conflict", "force_sync_profile conflict status")
	_expect_equal(conflict.get("target", ""), "profile", "force_sync_profile conflict target")
	_expect_dictionary(conflict.get("localAccountData", {}), {
		"diamonds": 35,
		"region": "us",
	}, "force_sync_profile conflict local account data")
	_expect_dictionary(conflict.get("cloudAccountData", {}), ACCOUNT_SYNC_CONFLICT_RESPONSE["save"]["state"]["accountData"], "force_sync_profile conflict cloud account data")
	_expect_dictionary(conflict.get("localMetadata", {}), {
		"displayName": "Local",
	}, "force_sync_profile conflict local metadata")
	_expect_dictionary(conflict.get("cloudMetadata", {}), ACCOUNT_SYNC_CONFLICT_RESPONSE["save"]["metadata"], "force_sync_profile conflict cloud metadata")
	_expect_equal(conflict.get("localVersion", 0), 3, "force_sync_profile conflict local version")
	_expect_equal(conflict.get("cloudVersion", 0), 5, "force_sync_profile conflict cloud version")
	if not conflict.has("localUpdatedAtUnix") or not conflict.has("cloudUpdatedAt"):
		_fail("force_sync_profile conflict should expose explicit local and cloud timestamps.")
	if events.is_empty() or events[0].get("target", "") != "profile":
		_fail("force_sync_profile conflict should notify onSyncResult with profile target.")


func _check_conflict_helpers(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	var events: Array = []
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"localProfileKey": "validation-conflict",
		"storage_path": _storage_path("conflict"),
		"syncPolicy": {
			"minRemoteSyncIntervalSeconds": 60,
			"forceSyncCooldownSeconds": 10,
			"syncOnAppBackground": true,
			"syncOnAppForeground": true,
			"syncOnReconnect": true,
			"maxQueuedLocalSnapshots": 25,
		},
		"onSyncResult": func(result: Dictionary) -> void:
			events.append(result),
	})
	persistly.save_slot("autosave", {
		"level": 5,
	}, {
		"scene": "local",
	})
	persistly._slots["autosave"]["characterSaveId"] = "sv_char"
	persistly._slots["autosave"]["version"] = 2
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/sync", 409, SYNC_CONFLICT_RESPONSE)

	var conflict: Dictionary = persistly.force_sync("autosave", {
		"bypassCooldown": true,
	})
	_expect_equal(conflict.get("status", ""), "conflict", "force_sync conflict status")
	_expect_dictionary(conflict.get("localState", {}), {
		"level": 5,
	}, "force_sync conflict local state")
	_expect_dictionary(conflict.get("cloudState", {}), SYNC_CONFLICT_RESPONSE["save"]["state"], "force_sync conflict cloud state")
	if events.is_empty() or events[0].get("target", "") != "slot":
		_fail("force_sync conflict should notify onSyncResult with slot target.")

	var kept: Dictionary = persistly.keep_local_for_later("autosave")
	_expect_equal(kept.get("dirty", false), true, "keep_local_for_later keeps slot dirty")
	var accepted: Dictionary = persistly.accept_cloud_version("autosave")
	_expect_equal(accepted.get("status", ""), "synced", "accept_cloud_version with conflict status")
	_expect_dictionary(accepted.get("state", {}), SYNC_CONFLICT_RESPONSE["save"]["state"], "accept_cloud_version state")

	persistly.save_slot("autosave", {
		"level": 9,
	}, {
		"scene": "local",
	})
	persistly._slots["autosave"]["cloudVersion"] = 4
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/sync", 200, SYNC_ACCEPTED_RESPONSE)
	var overwritten: Dictionary = persistly.overwrite_cloud_version("autosave", {
		"bypassCooldown": true,
	})
	_expect_equal(overwritten.get("status", ""), "synced", "overwrite_cloud_version status")


func _check_archive_and_clear(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"localProfileKey": "validation-archive",
		"storage_path": _storage_path("archive"),
	})
	persistly.save_slot("autosave", {
		"level": 5,
	})
	persistly._slots["autosave"]["characterSaveId"] = "sv_char"
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/archive", 200, ARCHIVE_RESPONSE)

	var archived: Dictionary = persistly.archive_slot("autosave")
	_expect_equal(archived.get("status", ""), "synced", "archive_slot status")
	var active: Array = persistly.list_slots()
	if not active.is_empty():
		_fail("list_slots should exclude archived slots by default.")
	var all_slots: Array = persistly.list_slots({
		"includeArchived": true,
	})
	if all_slots.size() != 1 or not bool(all_slots[0].get("archived", false)):
		_fail("list_slots includeArchived should include archived slots.")

	var cleared: Dictionary = persistly.clear_local_slot("autosave")
	_expect_equal(cleared.get("status", ""), "local_saved", "clear_local_slot status")
	_expect_equal(persistly.load_slot("autosave").get("status", ""), "not_found", "clear_local_slot removes local slot")


func _check_archived_slot_can_be_reused(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"localProfileKey": "validation-archive-reuse",
		"storage_path": _storage_path("archive_reuse"),
	})
	persistly.save_slot("autosave", {
		"level": 5,
	})
	persistly._slots["autosave"]["characterSaveId"] = "sv_char"
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/archive", 200, ARCHIVE_RESPONSE)
	persistly.archive_slot("autosave")

	var replacement_local: Dictionary = persistly.save_slot("autosave", {
		"level": 1,
		"coins": 50,
	}, {
		"scene": "replacement",
	})
	_expect_equal(replacement_local.get("archived", true), false, "save_slot should reactivate a previously archived slot locally")
	_expect_equal(replacement_local.get("characterSaveId", ""), "", "save_slot after archive should clear the archived characterSaveId")
	persistly._client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters", 201, REPLACEMENT_CHARACTER_CREATE_RESPONSE)

	var replacement_synced: Dictionary = persistly.force_sync("autosave", {
		"bypassCooldown": true,
	})
	_expect_equal(replacement_synced.get("status", ""), "synced", "force_sync should create replacement character for reused archived slot")
	_expect_equal(replacement_synced.get("characterSaveId", ""), "sv_char_replacement", "force_sync should store replacement characterSaveId")


func _check_rejects_reserved_developer_metadata(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"localProfileKey": "validation-reserved-metadata",
		"storage_path": _storage_path("reserved_metadata"),
	})
	var result: Dictionary = persistly.save_slot("autosave", {
		"level": 1,
	}, {
		"_persistly": {
			"slotKey": "hijack",
		},
	})
	if result.get("status", "") != "invalid_request":
		_fail("save_slot should reject developer metadata containing reserved _persistly.")


func _check_schema_versioned_file_persistence(game_saves_script: Script) -> void:
	var storage_path := _storage_path("schema")
	var first: Object = game_saves_script.new()
	first.configure({
		"runtime_key": "ps_test_replace_me",
		"localProfileKey": "validation-schema",
		"storage_path": storage_path,
	})
	first.save_slot("autosave", {
		"level": 3,
	})
	first.save_account_data({
		"diamonds": 7,
	})

	var second: Object = game_saves_script.new()
	second.configure({
		"runtime_key": "ps_test_replace_me",
		"localProfileKey": "validation-schema",
		"storage_path": storage_path,
	})
	_expect_equal(second.load_slot("autosave").get("status", ""), "local_found", "schema-versioned slot reload status")
	_expect_equal(second.get_account_data().get("diamonds", 0), 7, "schema-versioned account data reload")

	var profile_path := storage_path.path_join("validation-schema".uri_encode()).path_join("profile.json")
	var profile_record: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	if typeof(profile_record) != TYPE_DICTIONARY or profile_record.get("schema", "") != "persistly.godot.profile.v1":
		_fail("profile persistence record should include schema persistly.godot.profile.v1.")


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail(label + " expected " + str(expected) + " but got " + str(actual) + ".")


func _expect_dictionary(actual: Variant, expected: Dictionary, label: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail(label + " should be a dictionary.")
		return
	if not _variants_equal(actual, expected):
		_fail(label + " expected " + JSON.stringify(expected) + " but got " + JSON.stringify(actual) + ".")


func _variants_equal(actual: Variant, expected: Variant) -> bool:
	var actual_type := typeof(actual)
	var expected_type := typeof(expected)
	if (actual_type == TYPE_INT or actual_type == TYPE_FLOAT) and (expected_type == TYPE_INT or expected_type == TYPE_FLOAT):
		return is_equal_approx(float(actual), float(expected))
	if actual_type == TYPE_DICTIONARY and expected_type == TYPE_DICTIONARY:
		var actual_dict: Dictionary = actual
		var expected_dict: Dictionary = expected
		if actual_dict.size() != expected_dict.size():
			return false
		for key in expected_dict.keys():
			if not actual_dict.has(key):
				return false
			if not _variants_equal(actual_dict[key], expected_dict[key]):
				return false
		return true
	if actual_type == TYPE_ARRAY and expected_type == TYPE_ARRAY:
		var actual_array: Array = actual
		var expected_array: Array = expected
		if actual_array.size() != expected_array.size():
			return false
		for index in range(expected_array.size()):
			if not _variants_equal(actual_array[index], expected_array[index]):
				return false
		return true
	return actual == expected


func _storage_path(name: String) -> String:
	return _run_storage_prefix.path_join(name)


func _fail(message: String) -> void:
	_failure_count += 1
	push_error(message)


func _finish() -> void:
	if _failure_count == 0:
		print("Persistly game saves facade validation passed.")
		quit(0)
	else:
		push_error("Persistly game saves facade validation failed with " + str(_failure_count) + " failure(s).")
		quit(1)
