extends RefCounted
class_name LastBeaconStore

const DEFAULT_PATH := "user://last_beacon_profile.json"

var profile_path: String = DEFAULT_PATH


func _init(profile_path_value: String = DEFAULT_PATH) -> void:
	profile_path = profile_path_value


func load_profile() -> Dictionary:
	if not FileAccess.file_exists(profile_path):
		return _default_profile()

	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		return _default_profile()

	var raw := file.get_as_text()
	file.close()
	if raw.is_empty():
		return _default_profile()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _default_profile()

	return _normalize_profile(parsed as Dictionary)


func save_profile(profile: Dictionary) -> bool:
	var normalized := _normalize_profile(profile)
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return true


func reset() -> void:
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))


func _default_profile() -> Dictionary:
	return {
		"config": {},
		"saveId": "",
		"version": 0,
		"state": {},
	}


func _normalize_profile(profile: Dictionary) -> Dictionary:
	var normalized := _default_profile()
	if typeof(profile.get("config", {})) == TYPE_DICTIONARY:
		normalized["config"] = (profile.get("config", {}) as Dictionary).duplicate(true)
	if typeof(profile.get("saveId", "")) == TYPE_STRING:
		normalized["saveId"] = String(profile.get("saveId", ""))
	var version_value = profile.get("version", 0)
	if typeof(version_value) == TYPE_INT or typeof(version_value) == TYPE_FLOAT:
		normalized["version"] = int(profile.get("version", 0))
	if typeof(profile.get("state", {})) == TYPE_DICTIONARY:
		normalized["state"] = (profile.get("state", {}) as Dictionary).duplicate(true)
	return normalized
