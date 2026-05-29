extends RefCounted
class_name LastBeaconStore

const DEFAULT_PATH := "user://last_beacon_account.json"

var account_path: String = DEFAULT_PATH


func _init(account_path_value: String = DEFAULT_PATH) -> void:
	account_path = account_path_value


func load_account() -> Dictionary:
	if not FileAccess.file_exists(account_path):
		return _default_account()

	var file := FileAccess.open(account_path, FileAccess.READ)
	if file == null:
		return _default_account()

	var raw := file.get_as_text()
	file.close()
	if raw.is_empty():
		return _default_account()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _default_account()

	return _normalize_account(parsed as Dictionary)


func save_account(account: Dictionary) -> bool:
	var normalized := _normalize_account(account)
	var file := FileAccess.open(account_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return true


func reset() -> void:
	if FileAccess.file_exists(account_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(account_path))


func _default_account() -> Dictionary:
	return {
		"config": {},
		"accountId": "",
		"accountSessionToken": "",
		"slotId": "",
		"version": 0,
		"data": {},
	}


func _normalize_account(account: Dictionary) -> Dictionary:
	var normalized := _default_account()
	if typeof(account.get("config", {})) == TYPE_DICTIONARY:
		normalized["config"] = (account.get("config", {}) as Dictionary).duplicate(true)
	if typeof(account.get("accountId", "")) == TYPE_STRING:
		normalized["accountId"] = String(account.get("accountId", ""))
	if typeof(account.get("accountSessionToken", "")) == TYPE_STRING:
		normalized["accountSessionToken"] = String(account.get("accountSessionToken", ""))
	if typeof(account.get("slotId", "")) == TYPE_STRING:
		normalized["slotId"] = String(account.get("slotId", ""))
	var version_value = account.get("version", 0)
	if typeof(version_value) == TYPE_INT or typeof(version_value) == TYPE_FLOAT:
		normalized["version"] = int(account.get("version", 0))
	if typeof(account.get("data", {})) == TYPE_DICTIONARY:
		normalized["data"] = (account.get("data", {}) as Dictionary).duplicate(true)
	return normalized
