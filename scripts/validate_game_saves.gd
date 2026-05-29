extends SceneTree

const GAME_SAVES_SCRIPT := "res://addons/persistly/persistly_game_saves.gd"

const SYNC_POLICY := {
	"minRemoteSyncIntervalSeconds": 60,
	"forceSyncCooldownSeconds": 10,
	"syncOnAppBackground": true,
	"syncOnAppForeground": true,
	"syncOnReconnect": true,
	"maxQueuedLocalSnapshots": 25,
}

const ACCOUNT := {
	"accountId": "acc_test",
	"accountData": {
		"diamonds": 20,
	},
	"slots": [],
	"version": 1,
	"updatedAt": "2026-05-29T10:00:00Z",
}

const SLOT := {
	"slotId": "autosave",
	"slotInfo": {
		"characterName": "Ayla",
		"level": 5,
	},
	"data": {
		"level": 5,
		"coins": 1200,
	},
	"version": 1,
	"updatedAt": "2026-05-29T10:01:00Z",
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
	_check_account_first_facade_surface(game_saves_script)
	_check_local_slot_flow(game_saves_script)
	_check_first_sync_creates_account_and_slot(game_saves_script)
	_check_account_data_sync(game_saves_script)
	_check_clear_and_delete_boundaries(game_saves_script)
	_check_reserved_slot_info_rejected(game_saves_script)
	_finish()


func _check_status_and_target_constants(game_saves_script: Script) -> void:
	_expect_equal(game_saves_script.DEFAULT_SLOT_KEY, "autosave", "PersistlyGameSaves.DEFAULT_SLOT_KEY")
	var target = game_saves_script.PersistlyGameSaveTarget
	_expect_equal(target.ACCOUNT, "account", "PersistlyGameSaveTarget.ACCOUNT")
	_expect_equal(target.SLOT, "slot", "PersistlyGameSaveTarget.SLOT")


func _check_account_first_facade_surface(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	for method_name in [
		"create_account",
		"attach_account",
		"get_account_session",
		"force_sync_account",
		"sync_due_account",
		"clear_local_account",
		"delete_account",
		"save_slot",
		"load_slot",
		"list_slot_data",
		"slot_info",
	]:
		if not persistly.has_method(method_name):
			_fail("PersistlyGameSaves should expose account-first method " + method_name + ".")
	for legacy_method_name in [
		"create_profile",
		"attach_profile",
		"get_profile_session",
		"force_sync_profile",
		"sync_due_profile",
		"clear_local_profile",
		"delete_profile",
		"list_slots",
		"inspect_profile",
	]:
		if persistly.has_method(legacy_method_name):
			_fail("PersistlyGameSaves should not expose release profile compatibility method " + legacy_method_name + ".")


func _check_local_slot_flow(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	var configured: Dictionary = persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"playerRef": "player-184",
		"externalAccountRef": {
			"provider": "auth0",
			"subject": "auth0|user_123",
		},
		"localAccountKey": "validation-local-flow",
		"storage_path": _storage_path("local_flow"),
	})
	_expect_equal(configured.get("status", ""), "configured", "configure status")
	_expect_equal(configured.get("localAccountKey", ""), "validation-local-flow", "configure localAccountKey")

	var saved: Dictionary = persistly.save_slot("autosave", {
		"level": 5,
		"coins": 1200,
	}, {
		"slotInfo": {
			"characterName": "Ayla",
			"level": 5,
		},
	})
	_expect_equal(saved.get("status", ""), "local_saved", "save_slot status")
	_expect_equal(saved.get("slotId", ""), "autosave", "save_slot slotId")
	_expect_dictionary(saved.get("data", {}), SLOT["data"], "save_slot data")
	_expect_dictionary(saved.get("slotInfo", {}), SLOT["slotInfo"], "save_slot slotInfo")

	var loaded: Dictionary = persistly.load_slot("autosave")
	_expect_equal(loaded.get("status", ""), "local_found", "load_slot status")
	_expect_dictionary(loaded.get("data", {}), SLOT["data"], "load_slot data")

	var listed: Array = persistly.list_slot_data()
	if listed.size() != 1 or listed[0].get("slotId", "") != "autosave":
		_fail("list_slot_data should return active local slots.")

	var info: Dictionary = persistly.slot_info("autosave")
	_expect_dictionary(info.get("slotInfo", {}), SLOT["slotInfo"], "slot_info slotInfo")


func _check_first_sync_creates_account_and_slot(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"playerRef": "player-184",
		"localAccountKey": "validation-first-sync",
		"storage_path": _storage_path("first_sync"),
	})
	persistly._client.register_fixture_response("POST", "/api/v1/accounts", 201, {
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"account": _account_with_slot("autosave"),
		"slot": SLOT,
		"syncPolicy": SYNC_POLICY,
	})

	persistly.save_data(SLOT["data"], {
		"slotInfo": SLOT["slotInfo"],
	})
	var synced: Dictionary = persistly.force_sync_data({
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "force_sync_data status")
	_expect_equal(synced.get("slotId", ""), "autosave", "force_sync_data slotId")
	_expect_equal(persistly.get_account_session({"includeToken": true}).get("accountId", ""), "acc_test", "get_account_session accountId")
	_expect_equal(persistly.get_account_session({"includeToken": true}).get("accountSessionToken", ""), "pst_account_session", "get_account_session token")

	var request: Dictionary = persistly._client.get_recorded_requests()[0]
	_expect_equal(request.get("path", ""), "/api/v1/accounts", "first sync route")
	if str(request.get("body", {})).find("_persistly") >= 0:
		_fail("Facade account create request should not expose _persistly metadata.")


func _check_account_data_sync(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"localAccountKey": "validation-account-sync",
		"storage_path": _storage_path("account_sync"),
	})
	persistly.account_version = 1
	persistly._client.register_fixture_response("POST", "/api/v1/accounts/acc_test/data/sync", 200, {
		"status": "accepted",
		"version": 2,
		"updatedAt": "2026-05-29T10:04:00Z",
		"historyRetained": true,
	})

	persistly.save_account_data({
		"diamonds": 20,
	})
	persistly.patch_account_data({
		"diamonds": 30,
		"obsolete": null,
	})
	_expect_equal(persistly.get_account_data().get("diamonds", 0), 30, "patch_account_data")
	var synced: Dictionary = persistly.force_sync_account({
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "force_sync_account status")
	_expect_equal(synced.get("target", ""), "account", "force_sync_account target")

	var request: Dictionary = persistly._client.get_recorded_requests()[0]
	_expect_equal(request.get("path", ""), "/api/v1/accounts/acc_test/data/sync", "account sync route")
	_expect_has_account_session_header(request)


func _check_clear_and_delete_boundaries(game_saves_script: Script) -> void:
	var local_only: Object = game_saves_script.new()
	local_only.configure({
		"runtime_key": "ps_test_replace_me",
		"localAccountKey": "validation-clear",
		"storage_path": _storage_path("clear"),
	})
	local_only.save_slot("autosave", {"level": 1})
	var cleared: Dictionary = local_only.clear_local_account()
	_expect_equal(cleared.get("status", ""), "local_saved", "clear_local_account status")
	_expect_equal(local_only.load_slot("autosave").get("status", ""), "not_found", "clear_local_account removes slots")

	var remote: Object = game_saves_script.new()
	remote.configure({
		"runtime_key": "ps_test_replace_me",
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"localAccountKey": "validation-delete",
		"storage_path": _storage_path("delete"),
	})
	remote._client.register_fixture_response("DELETE", "/api/v1/accounts/acc_test", 200, {
		"accountId": "acc_test",
		"deletedAt": "2026-05-29T10:05:00Z",
		"deletedSlotCount": 1,
		"alreadyDeleted": false,
		"cleanupQueued": true,
	})
	var deleted: Dictionary = remote.delete_account()
	_expect_equal(deleted.get("status", ""), "synced", "delete_account status")
	_expect_equal(remote.get_account_session({"includeToken": true}).get("accountId", ""), "", "delete_account clears account session")


func _check_reserved_slot_info_rejected(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"localAccountKey": "validation-reserved",
		"storage_path": _storage_path("reserved"),
	})
	var result: Dictionary = persistly.save_slot("autosave", {"level": 1}, {
		"slotInfo": {
			"_persistly": {
				"slotId": "autosave",
			},
		},
	})
	_expect_equal(result.get("status", ""), "invalid_request", "save_slot rejects reserved slotInfo")


func _account_with_slot(slot_id: String) -> Dictionary:
	return {
		"accountId": "acc_test",
		"accountData": ACCOUNT["accountData"],
		"slots": [
			{
				"slotId": slot_id,
				"slotInfo": SLOT["slotInfo"],
				"version": 1,
				"status": "active",
				"updatedAt": "2026-05-29T10:01:00Z",
			},
		],
		"version": 1,
		"updatedAt": "2026-05-29T10:01:00Z",
	}


func _expect_has_account_session_header(request: Dictionary) -> void:
	var headers: Array = request.get("headers", [])
	for header in headers:
		if String(header).begins_with("X-Persistly-Account-Session:"):
			return
	_fail("Request should include X-Persistly-Account-Session.")


func _storage_path(name: String) -> String:
	return _run_storage_prefix.path_join(name)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail(label + " expected " + str(expected) + " but got " + str(actual) + ".")


func _expect_dictionary(actual: Variant, expected: Dictionary, label: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail(label + " expected dictionary but got " + str(actual) + ".")
		return
	for key in expected.keys():
		if not (actual as Dictionary).has(key) or (actual as Dictionary)[key] != expected[key]:
			_fail(label + " expected " + JSON.stringify(expected) + " but got " + JSON.stringify(actual) + ".")
			return


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
