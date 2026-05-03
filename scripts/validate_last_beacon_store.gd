extends SceneTree

const STORE_SCRIPT := "res://examples/last_beacon/last_beacon_store.gd"
const TEST_PATH := "user://last_beacon_store_test.json"

var _failure_count := 0


func _initialize() -> void:
	var script := load(STORE_SCRIPT)
	if script == null:
		_fail("Could not load Last Beacon store script at " + STORE_SCRIPT)
		_finish()
		return

	var store = script.new(TEST_PATH)
	store.reset()

	var initial = store.load_profile()
	_expect(initial.get("config", {}).is_empty(), "Initial config should be empty after reset.")
	_expect(initial.get("saveId", "") == "", "Initial saveId should be empty after reset.")

	var profile := {
		"config": {
			"baseUrl": "http://127.0.0.1:8080",
			"runtimeKey": "ps_test_example",
			"playerRef": "player-184",
			"characterName": "Ayla",
			"slotLabel": "Beacon-A",
		},
		"saveId": "sv_01HXYZ",
		"version": 7,
		"state": {
			"scrap": 88,
			"workers": 4,
		},
	}

	var save_result = store.save_profile(profile)
	_expect(bool(save_result), "Saving a profile should succeed.")

	var reloaded = store.load_profile()
	_expect(reloaded.get("saveId", "") == "sv_01HXYZ", "Reloaded saveId should match the saved value.")
	_expect(reloaded.get("version", 0) == 7, "Reloaded version should match the saved value.")
	_expect(reloaded.get("config", {}).get("characterName", "") == "Ayla", "Reloaded config should keep the character name.")
	_expect(reloaded.get("state", {}).get("workers", 0) == 4, "Reloaded state should keep nested state values.")

	store.reset()
	var reset_profile = store.load_profile()
	_expect(reset_profile.get("saveId", "") == "", "Reset should remove the stored saveId.")
	_expect(reset_profile.get("state", {}).is_empty(), "Reset should remove stored state.")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failure_count += 1
	push_error(message)


func _finish() -> void:
	if _failure_count == 0:
		print("Last Beacon store validation passed.")
		quit(0)
		return

	push_error("Last Beacon store validation failed with " + str(_failure_count) + " issue(s).")
	quit(1)
