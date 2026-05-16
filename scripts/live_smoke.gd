extends SceneTree

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var failures: Array[String] = []


func _init() -> void:
	var runtime_key := OS.get_environment("PERSISTLY_RUNTIME_KEY").strip_edges()
	if runtime_key.is_empty():
		_fail("PERSISTLY_RUNTIME_KEY must be set to a dev/test runtime key.")
		_finish()
		return

	var base_url := OS.get_environment("PERSISTLY_API_BASE").strip_edges()
	if base_url.is_empty():
		base_url = "https://api.persistly.app"

	var smoke_id := "godot-live-smoke-" + str(Time.get_unix_time_from_system()).replace(".", "-")
	var persistly := PersistlyGameSaves.new()
	var configured: Dictionary = persistly.configure({
		"runtime_key": runtime_key,
		"base_url": base_url,
		"playerRef": smoke_id,
		"localProfileKey": smoke_id,
		"storage_path": "user://persistly-live-smoke",
		"syncPolicy": {
			"minRemoteSyncIntervalSeconds": 1,
			"forceSyncCooldownSeconds": 0,
			"syncOnAppBackground": true,
			"syncOnAppForeground": true,
			"syncOnReconnect": true,
			"maxQueuedLocalSnapshots": 25,
		},
	})
	_expect_status(configured, "configured", "configure")

	var local_account: Dictionary = persistly.save_account_data({
		"diamonds": 7,
		"unlockedSlots": 1,
	})
	_expect_status(local_account, "local_saved", "save_account_data")

	var saved: Dictionary = persistly.save_slot("autosave", {
		"level": 5,
		"coins": 1200,
		"checkpoint": "godot-live-smoke",
	}, {
		"characterName": "Smoke",
	})
	_expect_status(saved, "local_saved", "save_slot")

	var loaded: Dictionary = persistly.load_slot("autosave")
	_expect_status(loaded, "local_found", "load_slot")
	_expect_equal(loaded.get("state", {}).get("level", 0), 5, "load_slot state.level")

	var first_sync: Dictionary = persistly.force_sync("autosave", {"bypassCooldown": true})
	_expect_status(first_sync, "synced", "force_sync initial slot")
	_expect_present(first_sync.get("characterSaveId", ""), "force_sync characterSaveId")

	var updated: Dictionary = persistly.save_slot("autosave", {
		"level": 6,
		"coins": 1300,
		"checkpoint": "godot-live-smoke-updated",
	}, {
		"characterName": "Smoke",
	})
	_expect_status(updated, "local_saved", "save_slot updated")

	var due_results: Array = persistly.sync_due_slots({
		"bypassCooldown": true,
		"includeSkipped": true,
	})
	var synced_slot := false
	for result in due_results:
		if typeof(result) == TYPE_DICTIONARY and result.get("slotKey", "") == "autosave" and result.get("status", "") == "synced":
			synced_slot = true
	if not synced_slot:
		_fail("sync_due_slots should sync dirty autosave slot.")

	var patched_profile: Dictionary = persistly.patch_account_data({
		"diamonds": 8,
	})
	_expect_status(patched_profile, "local_saved", "patch_account_data")

	var profile_sync: Dictionary = persistly.force_sync_profile({"bypassCooldown": true})
	_expect_status(profile_sync, "synced", "force_sync_profile")

	var session: Dictionary = persistly.get_profile_session({"includeToken": true})
	_expect_present(session.get("profileSaveId", ""), "profileSaveId")
	_expect_present(session.get("profileSessionToken", ""), "profileSessionToken")

	_finish()


func _expect_status(result: Dictionary, expected: String, label: String) -> void:
	if result.get("status", "") != expected:
		_fail(label + " expected status " + expected + ", got " + str(result))


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail(label + " expected " + str(expected) + ", got " + str(actual))


func _expect_present(value: Variant, label: String) -> void:
	if String(value).strip_edges().is_empty():
		_fail(label + " should be present.")


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish() -> void:
	if failures.is_empty():
		print("Persistly Godot live smoke PASS")
		quit(0)
		return
	for failure in failures:
		print("Persistly Godot live smoke FAIL: " + failure)
	quit(1)
