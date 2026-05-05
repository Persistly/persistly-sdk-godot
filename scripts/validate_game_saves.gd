extends SceneTree

const GAME_SAVES_SCRIPT := "res://addons/persistly/persistly_game_saves.gd"

var _failure_count := 0


func _initialize() -> void:
	var game_saves_script := load(GAME_SAVES_SCRIPT)
	if game_saves_script == null or not game_saves_script.can_instantiate():
		_fail("Could not load game saves facade at " + GAME_SAVES_SCRIPT)
		_finish()
		return

	_check_slot_status_constants(game_saves_script)
	_check_not_configured(game_saves_script)
	_check_configured_local_slot_flow(game_saves_script)
	_check_force_sync_exists(game_saves_script)
	_check_conflict_helpers(game_saves_script)
	_finish()


func _check_slot_status_constants(game_saves_script: Script) -> void:
	var status = game_saves_script.PersistlySlotStatus
	_expect_equal(status.LOCAL_SAVED, "local_saved", "PersistlySlotStatus.LOCAL_SAVED")
	_expect_equal(status.SYNCED, "synced", "PersistlySlotStatus.SYNCED")
	_expect_equal(status.CONFLICT, "conflict", "PersistlySlotStatus.CONFLICT")
	_expect_equal(status.OFFLINE, "offline", "PersistlySlotStatus.OFFLINE")
	_expect_equal(status.RATE_LIMITED, "rate_limited", "PersistlySlotStatus.RATE_LIMITED")


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
	})
	if configure_result.get("status", "") != "configured":
		_fail("configure with runtime_key should return configured status.")

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
	_expect_dictionary(save_result.get("state", {}), {
		"level": 5,
		"coins": 1200,
	}, "save_slot state")

	var loaded: Dictionary = persistly.load_slot("autosave")
	if loaded.get("status", "") != "local_saved":
		_fail("load_slot should report local_saved for locally stored slots.")
	_expect_dictionary(loaded.get("state", {}), {
		"level": 5,
		"coins": 1200,
	}, "load_slot state")
	_expect_dictionary(loaded.get("metadata", {}), {
		"scene": "starter",
	}, "load_slot metadata")


func _check_force_sync_exists(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
	})
	persistly.save_slot("autosave", {
		"level": 5,
	})

	var result: Dictionary = persistly.force_sync("autosave")
	_expect_equal(result.get("status", ""), "local_saved", "force_sync status")
	_expect_dictionary(result.get("sync", {}), {
		"remoteAttempted": false,
		"reason": "remote_profile_sync_not_wired",
	}, "force_sync sync metadata")


func _check_conflict_helpers(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
	})
	persistly.save_slot("autosave", {
		"level": 5,
	}, {
		"scene": "local",
	})

	var invalid_accept: Dictionary = persistly.accept_cloud_version("autosave")
	_expect_equal(invalid_accept.get("status", ""), "invalid_request", "accept_cloud_version without conflict status")

	persistly._slots["autosave"]["conflict"] = {
		"cloudState": {
			"level": 8,
		},
		"cloudMetadata": {
			"scene": "cloud",
		},
	}
	var accepted: Dictionary = persistly.accept_cloud_version("autosave")
	_expect_equal(accepted.get("status", ""), "synced", "accept_cloud_version with conflict status")
	_expect_dictionary(accepted.get("state", {}), {
		"level": 8,
	}, "accept_cloud_version state")
	_expect_dictionary(accepted.get("metadata", {}), {
		"scene": "cloud",
	}, "accept_cloud_version metadata")


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail(label + " expected " + str(expected) + " but got " + str(actual) + ".")


func _expect_dictionary(actual: Variant, expected: Dictionary, label: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail(label + " should be a dictionary.")
		return
	if actual != expected:
		_fail(label + " expected " + JSON.stringify(expected) + " but got " + JSON.stringify(actual) + ".")


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
