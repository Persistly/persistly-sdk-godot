extends SceneTree

const CLIENT_SCRIPT := "res://addons/persistly/persistly_client.gd"
const BASE_URL := "http://127.0.0.1:18080"
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

var _failure_count := 0


func _initialize() -> void:
	var client_script := load(CLIENT_SCRIPT)
	if client_script == null:
		_fail("Could not load client script at " + CLIENT_SCRIPT)
		_finish()
		return

	var client: Object = client_script.new(BASE_URL, RUNTIME_KEY)
	_seed_fixture_responses(client)

	_check_create_save(client)
	_check_load_save(client)
	_check_sync_save(client)
	_check_error_mapping(client)
	_check_cache_update(client)
	_finish()


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


func _check_error_mapping(client: Object) -> void:
	var not_found = client.load_save("sv_missing")
	_expect_error_code(not_found, "not_found", "load_save should map 404 to not_found")

	var rate_limited = client.create_save({
		"state": {
			"simulate": "rate_limited",
		},
	})
	_expect_error_code(rate_limited, "rate_limited", "create_save should map 429 to rate_limited")


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
