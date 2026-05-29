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

	var initial = store.load_account()
	_expect(initial.get("config", {}).is_empty(), "Initial config should be empty after reset.")
	_expect(initial.get("accountId", "") == "", "Initial accountId should be empty after reset.")
	_expect(initial.get("slotId", "") == "", "Initial slotId should be empty after reset.")

	var account := {
		"config": {
			"runtimeKey": "ps_test_example",
			"playerRef": "player-184",
			"characterName": "Ayla",
			"slotLabel": "Beacon-A",
		},
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"slotId": "sv_01HXYZ",
		"version": 7,
		"data": {
			"scrap": 88,
			"workers": 4,
		},
	}

	var save_result = store.save_account(account)
	_expect(bool(save_result), "Saving an account should succeed.")

	var reloaded = store.load_account()
	_expect(reloaded.get("accountId", "") == "acc_test", "Reloaded accountId should match the saved value.")
	_expect(reloaded.get("accountSessionToken", "") == "pst_account_session", "Reloaded accountSessionToken should match the saved value.")
	_expect(reloaded.get("slotId", "") == "sv_01HXYZ", "Reloaded slotId should match the saved value.")
	_expect(reloaded.get("version", 0) == 7, "Reloaded version should match the saved value.")
	_expect(reloaded.get("config", {}).get("characterName", "") == "Ayla", "Reloaded config should keep the character name.")
	_expect(reloaded.get("data", {}).get("workers", 0) == 4, "Reloaded state should keep nested data values.")

	store.reset()
	var reset_account = store.load_account()
	_expect(reset_account.get("accountId", "") == "", "Reset should remove the stored accountId.")
	_expect(reset_account.get("slotId", "") == "", "Reset should remove the stored slotId.")
	_expect(reset_account.get("data", {}).is_empty(), "Reset should remove stored data.")

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
