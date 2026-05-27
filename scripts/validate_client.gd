extends SceneTree

const CLIENT_SCRIPT := "res://addons/persistly/persistly_client.gd"
const RUNTIME_KEY := "ps_test_local"

const CREATE_PAYLOAD := {
	"playerRef": "player-184",
	"metadata": {
		"characterName": "Ayla",
		"slot": 2,
	},
	"state": {
		"gold": 100,
		"level": 1,
	},
}

const CREATE_SAVE_RESPONSE := {
	"save": {
		"saveId": "sv_01HXYZ",
		"playerRef": "player-184",
		"metadata": {
			"characterName": "Ayla",
			"slot": 2,
		},
		"state": {
			"gold": 100,
			"level": 1,
		},
		"version": 4,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:05:00Z",
	},
}

const LOAD_SAVE_RESPONSE := {
	"save": {
		"saveId": "sv_01HXYZ",
		"playerRef": "player-184",
		"metadata": {
			"characterName": "Ayla",
			"slot": 2,
		},
		"state": {
			"gold": 120,
			"level": 2,
		},
		"version": 5,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:06:00Z",
	},
}

const SYNC_ACCEPTED_RESPONSE := {
	"status": "accepted",
	"save": {
		"saveId": "sv_01HXYZ",
		"playerRef": "player-184",
		"metadata": {
			"characterName": "Ayla",
			"slot": 2,
		},
		"state": {
			"gold": 130,
			"level": 3,
		},
		"version": 6,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:07:00Z",
	},
}

const SYNC_CONFLICT_RESPONSE := {
	"status": "conflict",
	"save": {
		"saveId": "sv_01HXYZ",
		"playerRef": "player-184",
		"metadata": {
			"characterName": "Ayla",
			"slot": 2,
		},
		"state": {
			"gold": 140,
			"level": 4,
		},
		"version": 7,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:08:00Z",
	},
	"details": {
		"reason": "base_version_mismatch",
	},
}

const PROFILE_SAVE := {
	"saveId": "sv_profile",
	"playerRef": "player-184",
	"metadata": {
		"displayName": "Ayla",
	},
	"state": {
		"schema": "persistly.profile.v1",
		"accountData": {
			"diamonds": 20,
		},
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
		"name": "Ayla",
	},
	"state": {
		"gold": 100,
		"level": 1,
	},
	"version": 1,
	"createdAt": "2026-04-09T10:00:00Z",
	"updatedAt": "2026-04-09T10:00:00Z",
}

const PROFILE_WITH_CHARACTER_SAVE := {
	"saveId": "sv_profile",
	"playerRef": "player-184",
	"metadata": {
		"displayName": "Ayla",
	},
	"state": {
		"schema": "persistly.profile.v1",
		"accountData": {
			"diamonds": 20,
		},
		"characterSlots": [
			{
				"slotKey": "autosave",
				"characterSaveId": "sv_char",
				"metadata": {
					"name": "Ayla",
				},
			},
		],
	},
	"version": 2,
	"createdAt": "2026-04-09T10:00:00Z",
	"updatedAt": "2026-04-09T10:01:00Z",
}

const CREATE_PROFILE_RESPONSE := {
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

const CREATE_PROFILE_WITH_CHARACTER_RESPONSE := {
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

const ACCOUNT_DATA_SYNC_RESPONSE := {
	"status": "accepted",
	"save": {
		"saveId": "sv_profile",
		"playerRef": "player-184",
		"metadata": {
			"displayName": "Ayla Updated",
		},
		"state": {
			"schema": "persistly.profile.v1",
			"accountData": {
				"diamonds": 30,
			},
			"characterSlots": [
				{
					"slotKey": "autosave",
					"characterSaveId": "sv_char",
					"metadata": {
						"name": "Ayla",
					},
				},
			],
		},
		"version": 3,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:02:00Z",
	},
}

const LIGHTWEIGHT_ACCOUNT_DATA_SYNC_RESPONSE := {
	"status": "accepted",
	"version": 4,
	"updatedAt": "2026-04-09T10:04:00Z",
	"historyRetained": true,
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
				"diamonds": 20,
			},
			"characterSlots": [
				{
					"slotKey": "autosave",
					"characterSaveId": "sv_char",
					"metadata": {
						"name": "Ayla",
					},
					"archived": true,
					"archivedAt": "2026-04-09T10:03:00Z",
				},
			],
		},
		"version": 4,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:03:00Z",
	},
}

const DELETE_PROFILE_CHARACTER_RESPONSE := {
	"profileSaveId": "sv_profile",
	"characterSaveId": "sv_char",
	"slotKey": "autosave",
	"deletedAt": "2026-04-09T10:04:00Z",
	"alreadyDeleted": false,
	"cleanupQueued": true,
	"profile": {
		"saveId": "sv_profile",
		"playerRef": "player-184",
		"metadata": {
			"displayName": "Ayla",
		},
		"state": {
			"schema": "persistly.profile.v1",
			"accountData": {
				"diamonds": 20,
			},
			"characterSlots": [],
		},
		"version": 5,
		"createdAt": "2026-04-09T10:00:00Z",
		"updatedAt": "2026-04-09T10:04:00Z",
	},
}

const DELETE_PROFILE_RESPONSE := {
	"profileSaveId": "sv_profile",
	"deletedAt": "2026-04-09T10:10:00Z",
	"deletedCharacterCount": 1,
	"alreadyDeleted": false,
	"cleanupQueued": true,
}

const RUNTIME_CONFIG_RESPONSE := {
	"syncPolicy": {
		"minRemoteSyncIntervalSeconds": 60,
		"forceSyncCooldownSeconds": 10,
		"syncOnAppBackground": true,
		"syncOnAppForeground": true,
		"syncOnReconnect": true,
		"maxQueuedLocalSnapshots": 25,
	},
	"gameConfig": {
		"enabled": true,
		"version": 3,
		"sizeBytes": 37,
		"hasData": true,
		"eventName": "launch",
		"data": {
			"season": "spring",
		},
	},
}

var _failure_count := 0


func _initialize() -> void:
	var client_script := load(CLIENT_SCRIPT)
	if client_script == null:
		_fail("Could not load client script at " + CLIENT_SCRIPT)
		_finish()
		return

	var client: Object = client_script.new(RUNTIME_KEY)
	_seed_fixture_responses(client)

	_check_versions(client_script)
	_check_create_save(client)
	_check_load_save(client)
	_check_sync_save(client)
	_check_create_profile_only(client)
	_check_create_profile_with_character(client)
	_check_rejects_legacy_character_aliases(client)
	_check_profile_session_routes(client)
	_check_account_data_sync(client)
	_check_archive(client)
	_check_delete_routes(client)
	_check_runtime_config(client)
	_check_autosave(client_script)
	_check_error_mapping(client)
	_check_cache_update(client)
	_finish()


func _check_versions(client_script: GDScript) -> void:
	_expect_equal(client_script.SDK_VERSION, "1.0.0", "SDK_VERSION")
	_expect_equal(client_script.BUNDLE_VERSION, "persistly-contract-v0.3.0", "BUNDLE_VERSION")
	_expect_equal(client_script.ERROR_PROFILE_DELETED, "profile_deleted", "ERROR_PROFILE_DELETED")
	_expect_equal(client_script.ERROR_CHARACTER_DELETED, "character_deleted", "ERROR_CHARACTER_DELETED")
	_expect_equal(client_script.ERROR_MONTHLY_QUOTA_EXCEEDED, "monthly_quota_exceeded", "ERROR_MONTHLY_QUOTA_EXCEEDED")


func _check_create_save(client: Object) -> void:
	var result = client.create_save(CREATE_PAYLOAD)
	if typeof(result) != TYPE_DICTIONARY or not result.has("save"):
		_fail("create_save should return a save envelope.")
		return

	_expect_save(result["save"], CREATE_SAVE_RESPONSE["save"], "create_save")


func _check_load_save(client: Object) -> void:
	var result = client.load_save("sv_01HXYZ")
	if typeof(result) != TYPE_DICTIONARY or not result.has("save"):
		_fail("load_save should return a save envelope.")
		return

	_expect_save(result["save"], LOAD_SAVE_RESPONSE["save"], "load_save")


func _check_sync_save(client: Object) -> void:
	var accepted = client.sync_save("sv_01HXYZ", {
		"baseVersion": 5,
		"metadata": {
			"characterName": "Ayla",
			"slot": 2,
		},
		"state": {
			"gold": 130,
			"level": 3,
		},
	})

	if typeof(accepted) != TYPE_DICTIONARY or accepted.get("status", "") != "accepted":
		_fail("sync_save should return accepted status for a successful sync.")
		return

	_expect_save(accepted.get("save", {}), SYNC_ACCEPTED_RESPONSE["save"], "sync_save accepted")

	var conflict = client.sync_save("sv_01HXYZ", {
		"baseVersion": 5,
		"metadata": {
			"characterName": "Ayla",
			"slot": 2,
		},
		"state": {
			"gold": 140,
			"level": 4,
		},
	})

	if typeof(conflict) != TYPE_DICTIONARY or conflict.get("status", "") != "conflict":
		_fail("sync_save should return conflict status when the server reports a conflict.")
		return

	_expect_save(conflict.get("save", {}), SYNC_CONFLICT_RESPONSE["save"], "sync_save conflict")
	var details = conflict.get("details", {})
	if typeof(details) != TYPE_DICTIONARY or details.get("reason", "") != "base_version_mismatch":
		_fail("sync_save conflict should preserve the conflict reason.")


func _check_create_profile_only(client: Object) -> void:
	var result = client.create_profile({
		"playerRef": "player-184",
		"externalProfileRef": {
			"provider": "auth0",
			"subject": "auth0|user_123",
		},
		"profileMetadata": {
			"displayName": "Ayla",
		},
		"accountData": {
			"diamonds": 20,
		},
	})
	if typeof(result) != TYPE_DICTIONARY or result.has("character"):
		_fail("profile-only create_profile should return no character envelope.")
		return

	_expect_profile(result, CREATE_PROFILE_RESPONSE, "create_profile profile-only", true)
	var state = result["profile"].get("state", {})
	if typeof(state) != TYPE_DICTIONARY or typeof(state.get("characterSlots", null)) != TYPE_ARRAY:
		_fail("create_profile should parse profile.state.characterSlots.")
	if typeof(state) == TYPE_DICTIONARY and state.has("characters"):
		_fail("create_profile should not expose legacy profile.state.characters.")


func _check_create_profile_with_character(client: Object) -> void:
	var result = client.create_profile({
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
				"name": "Ayla",
			},
			"state": {
				"gold": 100,
				"level": 1,
			},
		},
	})
	if typeof(result) != TYPE_DICTIONARY or not result.has("character"):
		_fail("create_profile with character should return a character save.")
		return

	_expect_profile(result, CREATE_PROFILE_WITH_CHARACTER_RESPONSE, "create_profile with character", true)
	_expect_save(result["character"], CHARACTER_SAVE, "create_profile character")


func _check_rejects_legacy_character_aliases(client: Object) -> void:
	var profile_alias_result = client.create_profile({
		"playerRef": "player-184",
		"characterState": {
			"level": 1,
		},
		"characterMetadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
		},
	})
	_expect_error_code(profile_alias_result, "invalid_request", "create_profile should reject stale characterState/characterMetadata aliases")

	var create_alias_result = client.create_profile_character("sv_profile", "pst_profile_session", {
		"characterState": {
			"level": 1,
		},
		"characterMetadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
		},
	})
	_expect_error_code(create_alias_result, "invalid_request", "create_profile_character should reject stale characterState/characterMetadata aliases")

	var sync_alias_result = client.sync_profile_character("sv_profile", "pst_profile_session", "sv_char", {
		"baseVersion": 1,
		"characterState": {
			"level": 2,
		},
		"characterMetadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
		},
	})
	_expect_error_code(sync_alias_result, "invalid_request", "sync_profile_character should reject stale characterState/characterMetadata aliases")

	var extra_reserved_result = client.create_profile_character("sv_profile", "pst_profile_session", {
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
				"owner": "game",
			},
		},
		"state": {
			"level": 1,
		},
	})
	_expect_error_code(extra_reserved_result, "invalid_request", "create_profile_character should reject extra reserved _persistly fields")


func _check_profile_session_routes(client: Object) -> void:
	var load_profile_result = client.load_profile("sv_profile", "pst_profile_session")
	if typeof(load_profile_result) != TYPE_DICTIONARY or not load_profile_result.has("profile"):
		_fail("load_profile should return a profile save envelope.")
		return
	_expect_profile(load_profile_result, {"profileSaveId": "sv_profile", "profile": PROFILE_WITH_CHARACTER_SAVE}, "load_profile", false)

	var create_character = client.create_profile_character("sv_profile", "pst_profile_session", {
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
			"name": "Ayla",
		},
		"state": {
			"gold": 100,
			"level": 1,
		},
	})
	if typeof(create_character) != TYPE_DICTIONARY or not create_character.has("character"):
		_fail("create_profile_character should return the updated profile and character save.")
		return
	_expect_profile(create_character, CREATE_PROFILE_WITH_CHARACTER_RESPONSE, "create_profile_character", false)
	_expect_save(create_character["character"], CHARACTER_SAVE, "create_profile_character character")

	var load_result = client.load_profile_character("sv_profile", "pst_profile_session", "sv_char")
	if typeof(load_result) != TYPE_DICTIONARY or not load_result.has("save"):
		_fail("load_profile_character should return a save envelope.")
		return
	_expect_save(load_result["save"], CHARACTER_SAVE, "load_profile_character")

	var sync_result = client.sync_profile_character("sv_profile", "pst_profile_session", "sv_char", {
		"baseVersion": 1,
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
			"name": "Ayla",
		},
		"state": {
			"gold": 110,
			"level": 2,
		},
	})
	if typeof(sync_result) != TYPE_DICTIONARY or sync_result.get("status", "") != "accepted":
		_fail("sync_profile_character should return accepted status for a successful sync.")
		return
	_expect_save(sync_result.get("save", {}), SYNC_ACCEPTED_RESPONSE["save"], "sync_profile_character")

	var duplicate = client.create_profile_character("sv_profile", "pst_profile_session", {
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
		},
		"state": {
			"level": 1,
		},
	})
	_expect_error_code(duplicate, "slot_already_exists", "create_profile_character should preserve duplicate-slot typed errors")

	var archived = client.sync_profile_character("sv_profile", "pst_profile_session", "sv_char", {
		"baseVersion": 1,
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
		},
		"state": {
			"level": 1,
		},
	})
	_expect_error_code(archived, "character_archived", "sync_profile_character should preserve archived-character typed errors")


func _check_account_data_sync(client: Object) -> void:
	var result = client.sync_profile_account_data("sv_profile", "pst_profile_session", {
		"baseVersion": 2,
		"accountDataPatch": {
			"diamonds": 30,
			"obsolete": null,
		},
		"metadata": {
			"displayName": "Ayla Updated",
		},
	})
	if typeof(result) != TYPE_DICTIONARY or result.get("status", "") != "accepted":
		_fail("sync_profile_account_data should return accepted status.")
		return

	_expect_save(result.get("save", {}), ACCOUNT_DATA_SYNC_RESPONSE["save"], "sync_profile_account_data")
	var state = result["save"].get("state", {})
	if typeof(state) != TYPE_DICTIONARY or not state.has("characterSlots"):
		_fail("sync_profile_account_data should preserve characterSlots in profile state.")

	var cached_profile: Dictionary = ACCOUNT_DATA_SYNC_RESPONSE["save"].duplicate(true)
	cached_profile["state"] = (ACCOUNT_DATA_SYNC_RESPONSE["save"]["state"] as Dictionary).duplicate(true)
	cached_profile["state"]["accountData"] = {
		"diamonds": 30,
		"obsolete": "remove-me",
	}
	client._save_cache["sv_profile"] = cached_profile
	var lightweight = client.sync_profile_account_data("sv_profile", "pst_profile_session", {
		"baseVersion": 3,
		"accountDataPatch": {
			"diamonds": 35,
			"obsolete": null,
		},
	})
	if typeof(lightweight) != TYPE_DICTIONARY or lightweight.get("status", "") != "accepted":
		_fail("sync_profile_account_data should accept lightweight sync responses.")
		return
	var lightweight_state = lightweight.get("save", {}).get("state", {})
	if typeof(lightweight_state) != TYPE_DICTIONARY:
		_fail("lightweight account-data sync should synthesize profile state.")
	elif (lightweight_state.get("accountData", {}) as Dictionary).has("obsolete"):
		_fail("lightweight account-data sync should delete accountDataPatch keys set to null.")
	elif int(lightweight_state.get("accountData", {}).get("diamonds", 0)) != 35:
		_fail("lightweight account-data sync should apply accountDataPatch changes.")


func _check_archive(client: Object) -> void:
	var result = client.archive_profile_character("sv_profile", "pst_profile_session", "sv_char")
	if typeof(result) != TYPE_DICTIONARY or not result.has("profile"):
		_fail("archive_profile_character should return the updated profile.")
		return

	_expect_profile(result, ARCHIVE_RESPONSE, "archive_profile_character", false)
	var slots = result["profile"].get("state", {}).get("characterSlots", [])
	if typeof(slots) != TYPE_ARRAY or slots.is_empty() or not bool(slots[0].get("archived", false)):
		_fail("archive_profile_character should parse archived characterSlots.")


func _check_delete_routes(client: Object) -> void:
	var deleted_character = client.delete_profile_character("sv_profile", "pst_profile_session", "sv_char")
	if typeof(deleted_character) != TYPE_DICTIONARY or deleted_character.get("characterSaveId", "") != "sv_char":
		_fail("delete_profile_character should return deleted character payload.")
		return
	if not deleted_character.has("profile"):
		_fail("delete_profile_character should preserve optional profile envelope when provided.")
	else:
		_expect_save(deleted_character["profile"], DELETE_PROFILE_CHARACTER_RESPONSE["profile"], "delete_profile_character profile")
	if not client.get_cached_save("sv_char").is_empty():
		_fail("delete_profile_character should clear cached character saves.")
	if client.get_cached_save("sv_profile").is_empty():
		_fail("delete_profile_character should refresh cached profile saves when profile payload is returned.")

	var deleted_profile = client.delete_profile("sv_profile", "pst_profile_session")
	if typeof(deleted_profile) != TYPE_DICTIONARY or int(deleted_profile.get("deletedCharacterCount", -1)) != 1:
		_fail("delete_profile should return deleted profile payload.")
		return
	if not client.get_cached_save("sv_profile").is_empty():
		_fail("delete_profile should clear cached profile saves.")


func _check_runtime_config(client: Object) -> void:
	var result = client.get_runtime_config(2)
	if typeof(result) != TYPE_DICTIONARY or not result.has("syncPolicy"):
		_fail("get_runtime_config should return syncPolicy.")
		return

	var policy = result["syncPolicy"]
	if typeof(policy) != TYPE_DICTIONARY:
		_fail("get_runtime_config syncPolicy should be a dictionary.")
		return

	if int(policy.get("minRemoteSyncIntervalSeconds", 0)) != 60:
		_fail("get_runtime_config should preserve minRemoteSyncIntervalSeconds.")
	if int(policy.get("forceSyncCooldownSeconds", 0)) != 10:
		_fail("get_runtime_config should preserve forceSyncCooldownSeconds.")
	if not policy.has("syncOnAppBackground"):
		_fail("get_runtime_config should preserve syncOnAppBackground.")
	if typeof(result.get("gameConfig", null)) != TYPE_DICTIONARY:
		_fail("get_runtime_config should preserve gameConfig.")
	elif int(result["gameConfig"].get("version", 0)) != 3:
		_fail("get_runtime_config should preserve gameConfig version.")


func _check_autosave(client_script: GDScript) -> void:
	var store = client_script.PersistlyMemoryAutosaveDraftStore.new()
	var draft := {
		"profileSaveId": "sv_profile",
		"profileSessionToken": "pst_profile_session",
		"characterSaveId": "sv_char",
		"metadata": {
			"_persistly": {
				"slotKey": "autosave",
			},
		},
		"state": {
			"level": 2,
		},
		"baseVersion": 1,
	}

	store.store_draft(draft)
	var loaded = store.load_draft("sv_char")
	if typeof(loaded) != TYPE_DICTIONARY or loaded.get("characterSaveId", "") != "sv_char":
		_fail("PersistlyMemoryAutosaveDraftStore should load stored drafts by characterSaveId.")
		return

	var policy := {
		"minRemoteSyncIntervalSeconds": 60,
		"forceSyncCooldownSeconds": 10,
		"maxQueuedLocalSnapshots": 25,
	}
	var manager = client_script.PersistlyAutosaveManager.new(store, policy)
	var first = manager.should_sync_remote("sv_char", true)
	manager.mark_remote_synced("sv_char")
	var second = manager.should_sync_remote("sv_char", true)
	if first != true:
		_fail("PersistlyAutosaveManager should allow first forced sync.")
	if second != false:
		_fail("PersistlyAutosaveManager should enforce force sync cooldown.")


func _check_error_mapping(client: Object) -> void:
	var not_found = client.load_save("sv_missing")
	_expect_error_code(not_found, "not_found", "load_save should map 404 to not_found")

	var rate_limited = client.create_save({
		"state": {
			"simulate": "rate_limited",
		},
	})
	_expect_error_code(rate_limited, "rate_limited", "create_save should map 429 to rate_limited")

	var monthly_quota = client.create_save({
		"state": {
			"simulate": "monthly_quota",
		},
	})
	_expect_error_code(monthly_quota, "monthly_quota_exceeded", "create_save should preserve monthly quota typed errors")

	var deleted_profile = client.load_profile("sv_deleted", "pst_profile_session")
	_expect_error_code(deleted_profile, "profile_deleted", "load_profile should preserve deleted-profile typed errors")

	var deleted_character = client.load_profile_character("sv_profile", "pst_profile_session", "sv_char_deleted")
	_expect_error_code(deleted_character, "character_deleted", "load_profile_character should preserve deleted-character typed errors")


func _check_cache_update(client: Object) -> void:
	var sync_result = client.sync_save("sv_01HXYZ", {
		"baseVersion": 6,
		"metadata": {
			"characterName": "Ayla",
			"slot": 2,
		},
		"state": {
			"gold": 145,
			"level": 4,
		},
	})
	if typeof(sync_result) != TYPE_DICTIONARY or not sync_result.has("save"):
		_fail("sync_save should return a canonical save payload.")


func _expect_profile(actual: Dictionary, expected: Dictionary, label: String, expect_token: bool) -> void:
	_expect_equal(actual.get("profileSaveId", ""), expected.get("profileSaveId", ""), label + " profileSaveId")
	if expect_token:
		_expect_equal(actual.get("profileSessionToken", ""), expected.get("profileSessionToken", ""), label + " profileSessionToken")
	_expect_save(actual.get("profile", {}), expected.get("profile", {}), label + " profile")
	if actual.has("syncPolicy") and expected.has("syncPolicy"):
		_expect_dictionary(actual["syncPolicy"], expected["syncPolicy"], label + " syncPolicy")


func _expect_save(actual: Variant, expected: Dictionary, label: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail(label + " save payload should be a dictionary.")
		return

	var keys := [
		"saveId",
		"playerRef",
		"metadata",
		"state",
		"version",
		"createdAt",
		"updatedAt",
	]
	for key in keys:
		if not actual.has(key):
			_fail(label + " save payload is missing " + key + ".")
			return

		if not _variants_equal(actual[key], expected[key]):
			_fail(label + " save payload mismatch for " + key + ".")
			return


func _expect_dictionary(actual: Variant, expected: Dictionary, label: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail(label + " should be a dictionary.")
		return
	if not _variants_equal(actual, expected):
		_fail(label + " expected " + JSON.stringify(expected) + " but got " + JSON.stringify(actual) + ".")


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail(label + " expected " + str(expected) + " but got " + str(actual) + ".")


func _expect_error_code(result: Variant, expected_code: String, message: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or not result.has("error"):
		_fail(message + " Returned result did not include an error envelope.")
		return

	var error = result["error"]
	if typeof(error) != TYPE_DICTIONARY or error.get("code", "") != expected_code:
		_fail(message + " Expected error code " + expected_code + ".")


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


func _fail(message: String) -> void:
	_failure_count += 1
	push_error(message)


func _finish() -> void:
	if _failure_count == 0:
		print("Persistly Godot client validation passed.")
		quit(0)
		return

	push_error("Persistly Godot client validation failed with " + str(_failure_count) + " issue(s).")
	quit(1)


func _seed_fixture_responses(client: Object) -> void:
	client.register_fixture_response("POST", "/api/v1/saves", 200, CREATE_SAVE_RESPONSE)
	client.register_fixture_response("GET", "/api/v1/saves/sv_01HXYZ", 200, LOAD_SAVE_RESPONSE)
	client.register_fixture_response("GET", "/api/v1/saves/sv_missing", 404, {
		"error": {
			"code": "not_found",
			"message": "Save not found.",
		},
	})
	client.register_fixture_response("POST", "/api/v1/saves/sv_01HXYZ/sync", 200, SYNC_ACCEPTED_RESPONSE)
	client.register_fixture_response("POST", "/api/v1/saves/sv_01HXYZ/sync", 409, SYNC_CONFLICT_RESPONSE)
	client.register_fixture_response("POST", "/api/v1/saves/sv_01HXYZ/sync", 200, {
		"status": "accepted",
		"save": {
			"saveId": "sv_01HXYZ",
			"playerRef": "player-184",
			"metadata": {
				"characterName": "Ayla",
				"slot": 2,
			},
			"state": {
				"gold": 145,
				"level": 4,
			},
			"version": 8,
			"createdAt": "2026-04-09T10:00:00Z",
			"updatedAt": "2026-04-09T10:09:00Z",
		},
	})
	client.register_fixture_response("POST", "/api/v1/saves", 429, {
		"error": {
			"code": "rate_limited",
			"message": "Rate limit exceeded.",
		},
	})
	client.register_fixture_response("POST", "/api/v1/profiles", 201, CREATE_PROFILE_RESPONSE)
	client.register_fixture_response("POST", "/api/v1/profiles", 201, CREATE_PROFILE_WITH_CHARACTER_RESPONSE)
	client.register_fixture_response("GET", "/api/v1/profiles/sv_profile", 200, {
		"profileSaveId": "sv_profile",
		"profile": PROFILE_WITH_CHARACTER_SAVE,
	})
	client.register_fixture_response("GET", "/api/v1/profiles/sv_deleted", 410, {
		"error": {
			"code": "profile_deleted",
			"message": "Profile was deleted.",
		},
	})
	client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters", 201, CREATE_PROFILE_WITH_CHARACTER_RESPONSE)
	client.register_fixture_response("GET", "/api/v1/profiles/sv_profile/characters/sv_char", 200, {
		"save": CHARACTER_SAVE,
	})
	client.register_fixture_response("GET", "/api/v1/profiles/sv_profile/characters/sv_char_deleted", 410, {
		"error": {
			"code": "character_deleted",
			"message": "Character was deleted.",
		},
	})
	client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/sync", 200, SYNC_ACCEPTED_RESPONSE)
	client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters", 409, {
		"error": {
			"code": "slot_already_exists",
			"message": "An active character already exists for this slot key.",
			"details": {
				"slotKey": "autosave",
			},
		},
	})
	client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/sync", 409, {
		"error": {
			"code": "character_archived",
			"message": "Archived characters cannot be synced.",
			"details": {
				"characterSaveId": "sv_char",
			},
		},
	})
	client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/account-data/sync", 200, ACCOUNT_DATA_SYNC_RESPONSE)
	client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/account-data/sync", 200, LIGHTWEIGHT_ACCOUNT_DATA_SYNC_RESPONSE)
	client.register_fixture_response("POST", "/api/v1/profiles/sv_profile/characters/sv_char/archive", 200, ARCHIVE_RESPONSE)
	client.register_fixture_response("DELETE", "/api/v1/profiles/sv_profile/characters/sv_char", 200, DELETE_PROFILE_CHARACTER_RESPONSE)
	client.register_fixture_response("DELETE", "/api/v1/profiles/sv_profile", 200, DELETE_PROFILE_RESPONSE)
	client.register_fixture_response("GET", "/api/v1/runtime-config?gameConfigVersion=2", 200, RUNTIME_CONFIG_RESPONSE)
	client.register_fixture_response("POST", "/api/v1/saves", 402, {
		"error": {
			"code": "monthly_quota_exceeded",
			"message": "Monthly runtime request quota exceeded.",
			"details": {
				"planTier": "free",
				"used": 100000,
				"limit": 100000,
			},
		},
	})
