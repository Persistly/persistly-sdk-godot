extends RefCounted
class_name PersistlyGameSaves

const CLIENT_SCRIPT := preload("res://addons/persistly/persistly_client.gd")

const DEFAULT_BASE_URL := "https://api.persistly.app"
const DEFAULT_SYNC_INTERVAL_SECONDS := 60.0
const DEFAULT_STORAGE_PATH := "user://persistly_game_saves"
const PROFILE_SCHEMA := "persistly.godot.profile.v1"
const SLOT_INDEX_SCHEMA := "persistly.godot.slot-index.v1"
const SLOT_SCHEMA := "persistly.godot.slot.v1"

const ERROR_NOT_CONFIGURED := "not_configured"
const ERROR_INVALID_REQUEST := "invalid_request"
const ERROR_NOT_FOUND := "not_found"
const ERROR_STORAGE := "storage_error"

var base_url: String = DEFAULT_BASE_URL
var runtime_key: String = ""
var sync_interval_seconds: float = DEFAULT_SYNC_INTERVAL_SECONDS
var player_ref: Variant = null
var external_profile_ref: Variant = null
var local_profile_key: String = ""
var profile_save_id: String = ""
var profile_session_token: String = ""
var profile_metadata: Dictionary = {}
var account_data: Dictionary = {}
var profile_version: int = 0
var sync_policy: Dictionary = _default_sync_policy()

var _client: Object = CLIENT_SCRIPT.new()
var _slots: Dictionary = {}
var _storage_path: String = DEFAULT_STORAGE_PATH
var _profile_root: String = ""
var _dirty_profile: bool = false
var _profile_last_synced_msec: int = 0
var _profile_updated_at_unix: float = 0.0
var _on_sync_result: Callable = Callable()


func configure(settings: Dictionary) -> Dictionary:
	base_url = String(_setting(settings, "base_url", "baseUrl", DEFAULT_BASE_URL)).strip_edges().rstrip("/")
	if base_url.is_empty():
		base_url = DEFAULT_BASE_URL

	runtime_key = String(_setting(settings, "runtime_key", "runtimeKey", "")).strip_edges()
	sync_interval_seconds = max(float(_setting(settings, "sync_interval_seconds", "syncIntervalSeconds", DEFAULT_SYNC_INTERVAL_SECONDS)), 1.0)
	player_ref = _setting(settings, "player_ref", "playerRef", null)
	external_profile_ref = _setting(settings, "external_profile_ref", "externalProfileRef", null)
	_storage_path = String(_setting(settings, "storage_path", "storagePath", DEFAULT_STORAGE_PATH)).rstrip("/")
	local_profile_key = String(_setting(settings, "local_profile_key", "localProfileKey", "")).strip_edges()
	if local_profile_key.is_empty():
		local_profile_key = _resolve_local_profile_key()
	_profile_root = _storage_path.path_join(local_profile_key.uri_encode())

	_client.configure(base_url, runtime_key, sync_interval_seconds)

	if settings.has("onSyncResult") and settings["onSyncResult"] is Callable:
		_on_sync_result = settings["onSyncResult"]
	elif settings.has("on_sync_result") and settings["on_sync_result"] is Callable:
		_on_sync_result = settings["on_sync_result"]

	if runtime_key.is_empty():
		return _error_result(ERROR_NOT_CONFIGURED, "PersistlyGameSaves requires runtime_key in configure settings.")

	var storage_error := _load_local_records()
	if not storage_error.is_empty():
		return storage_error

	var configured_profile_save_id := String(_setting(settings, "profile_save_id", "profileSaveId", "")).strip_edges()
	if not configured_profile_save_id.is_empty():
		profile_save_id = configured_profile_save_id
	var configured_profile_session_token := String(_setting(settings, "profile_session_token", "profileSessionToken", "")).strip_edges()
	if not configured_profile_session_token.is_empty():
		profile_session_token = configured_profile_session_token
	if settings.has("syncPolicy") and typeof(settings["syncPolicy"]) == TYPE_DICTIONARY:
		sync_policy = (settings["syncPolicy"] as Dictionary).duplicate(true)
	elif settings.has("sync_policy") and typeof(settings["sync_policy"]) == TYPE_DICTIONARY:
		sync_policy = (settings["sync_policy"] as Dictionary).duplicate(true)

	_persist_profile()

	return {
		"status": "configured",
		"baseUrl": base_url,
		"syncIntervalSeconds": sync_interval_seconds,
		"localProfileKey": local_profile_key,
		"profileSaveId": profile_save_id,
	}


func create_profile() -> Dictionary:
	var preflight := _validate_configured("create_profile")
	if not preflight.is_empty():
		return preflight
	var local_state_error := _ensure_no_existing_local_profile_state(
		"create_profile requires empty local profile state. Call clear_local_profile before creating a different profile."
	)
	if not local_state_error.is_empty():
		return local_state_error
	return ensure_profile()


func attach_profile(profile_save_id_value: String, profile_session_token_value: String) -> Dictionary:
	var preflight := _validate_configured("attach_profile")
	if not preflight.is_empty():
		return preflight
	if profile_save_id_value.strip_edges().is_empty() or profile_session_token_value.strip_edges().is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "attach_profile requires non-empty profile_save_id and profile_session_token.")
	var local_state_error := _ensure_no_existing_local_profile_state(
		"attach_profile requires empty local profile state. Call clear_local_profile before attaching a different profile."
	)
	if not local_state_error.is_empty():
		return local_state_error
	profile_save_id = profile_save_id_value.strip_edges()
	profile_session_token = profile_session_token_value.strip_edges()
	_dirty_profile = false
	_persist_profile()
	return _restore_profile(false)


func ensure_profile() -> Dictionary:
	var preflight := _validate_configured("ensure_profile")
	if not preflight.is_empty():
		return preflight
	if not profile_save_id.is_empty() and not profile_session_token.is_empty():
		if profile_version <= 0:
			var restored := _restore_profile()
			if restored.has("error"):
				return restored
			return _profile_result(PersistlyGameSaveStatus.SYNCED, false)
		return _profile_result(PersistlyGameSaveStatus.SYNCED, false)

	var config_result := _refresh_runtime_policy()
	if config_result.has("error") and config_result["error"].get("code", "") != CLIENT_SCRIPT.ERROR_RATE_LIMITED:
		return config_result

	var payload: Dictionary = {
		"accountData": account_data.duplicate(true),
		"profileMetadata": profile_metadata.duplicate(true),
	}
	if typeof(player_ref) == TYPE_STRING:
		payload["playerRef"] = player_ref
	if typeof(external_profile_ref) == TYPE_DICTIONARY:
		payload["externalProfileRef"] = (external_profile_ref as Dictionary).duplicate(true)

	var created: Dictionary = _client.create_profile(payload)
	if created.has("error"):
		return _map_remote_error(created, PersistlyGameSaveTarget.PROFILE)

	_apply_profile_response(created, true)
	_dirty_profile = false
	_profile_last_synced_msec = Time.get_ticks_msec()
	_persist_profile()
	return _profile_result(PersistlyGameSaveStatus.SYNCED, false)


func get_profile_session(options: Dictionary = {}) -> Dictionary:
	var result := {
		"profileSaveId": profile_save_id,
		"localProfileKey": local_profile_key,
	}
	if bool(options.get("includeToken", options.get("include_token", false))):
		result["profileSessionToken"] = profile_session_token
	return result


func inspect_profile() -> Dictionary:
	return _profile_result(PersistlyGameSaveStatus.LOCAL_FOUND, false)


func get_account_data() -> Dictionary:
	return account_data.duplicate(true)


func save_account_data(new_account_data: Dictionary) -> Dictionary:
	var preflight := _validate_configured("save_account_data")
	if not preflight.is_empty():
		return preflight
	account_data = new_account_data.duplicate(true)
	_dirty_profile = true
	_profile_updated_at_unix = Time.get_unix_time_from_system()
	_persist_profile()
	return {
		"status": PersistlyGameSaveStatus.LOCAL_SAVED,
		"target": PersistlyGameSaveTarget.PROFILE,
		"accountData": account_data.duplicate(true),
		"dirty": true,
	}


func patch_account_data(partial_account_data: Dictionary) -> Dictionary:
	var patched := account_data.duplicate(true)
	for key in partial_account_data.keys():
		if partial_account_data[key] == null:
			patched.erase(key)
		else:
			patched[key] = partial_account_data[key]
	return save_account_data(patched)


func force_sync_profile(options: Dictionary = {}) -> Dictionary:
	return _sync_profile(options, true)


func sync_due_profile(options: Dictionary = {}) -> Dictionary:
	return _sync_profile(options, false)


func save_slot(slot_key: String, state: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	var preflight := _validate_configured("save_slot")
	if not preflight.is_empty():
		return preflight

	var slot_error := _validate_slot_key(slot_key, "save_slot")
	if not slot_error.is_empty():
		return slot_error
	if typeof(state) != TYPE_DICTIONARY or typeof(metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "save_slot requires dictionary state and metadata.")
	var metadata_error := _validate_developer_metadata(metadata, "save_slot")
	if not metadata_error.is_empty():
		return metadata_error

	var previous := _slots.get(slot_key, {})
	var was_archived := bool(previous.get("archived", false))
	var stored := {} if was_archived else _duplicate_dictionary(previous)
	stored["slotKey"] = slot_key
	stored["status"] = PersistlyGameSaveStatus.LOCAL_SAVED
	stored["state"] = state.duplicate(true)
	stored["metadata"] = metadata.duplicate(true)
	stored["updatedAtUnix"] = Time.get_unix_time_from_system()
	stored["dirty"] = true
	stored["archived"] = false
	if not stored.has("characterSaveId"):
		stored["characterSaveId"] = ""
	if not stored.has("version"):
		stored["version"] = 0
	_slots[slot_key] = stored
	_persist_slot(slot_key)
	_persist_slot_index()
	return _slot_result(stored, PersistlyGameSaveStatus.LOCAL_SAVED)


func load_slot(slot_key: String) -> Dictionary:
	var preflight := _validate_configured("load_slot")
	if not preflight.is_empty():
		return preflight

	var slot_error := _validate_slot_key(slot_key, "load_slot")
	if not slot_error.is_empty():
		return slot_error
	if not _slots.has(slot_key):
		return {
			"status": PersistlyGameSaveStatus.NOT_FOUND,
			"slotKey": slot_key,
			"found": false,
		}

	return _slot_result(_slots[slot_key], PersistlyGameSaveStatus.LOCAL_FOUND)


func list_slots(options: Dictionary = {}) -> Array:
	var include_archived := bool(options.get("includeArchived", options.get("include_archived", false)))
	var slots: Array = []
	for slot_key in _slots.keys():
		var slot: Dictionary = _slots[slot_key]
		if bool(slot.get("archived", false)) and not include_archived:
			continue
		slots.append(_slot_result(slot, PersistlyGameSaveStatus.LOCAL_FOUND))
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("slotKey", "")) < String(b.get("slotKey", ""))
	)
	return slots


func inspect_slot(slot_key: String) -> Dictionary:
	return load_slot(slot_key)


func refresh_slot(slot_key: String) -> Dictionary:
	var preflight := _validate_configured("refresh_slot")
	if not preflight.is_empty():
		return preflight
	var slot_error := _validate_slot_key(slot_key, "refresh_slot")
	if not slot_error.is_empty():
		return slot_error
	if profile_save_id.is_empty() or profile_session_token.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "refresh_slot requires an existing profile session.", {
			"slotKey": slot_key,
		})

	var restored := _restore_profile(true)
	if restored.has("error"):
		return restored
	if not _slots.has(slot_key):
		return {
			"status": PersistlyGameSaveStatus.NOT_FOUND,
			"target": PersistlyGameSaveTarget.SLOT,
			"slotKey": slot_key,
			"found": false,
		}

	var slot: Dictionary = _slots[slot_key]
	var character_save_id := String(slot.get("characterSaveId", ""))
	if character_save_id.is_empty() or bool(slot.get("archived", false)):
		return {
			"status": PersistlyGameSaveStatus.NOT_FOUND,
			"target": PersistlyGameSaveTarget.SLOT,
			"slotKey": slot_key,
			"found": false,
		}

	var loaded: Dictionary = _client.load_profile_character(profile_save_id, profile_session_token, character_save_id)
	if loaded.has("error"):
		return _map_remote_error(loaded, PersistlyGameSaveTarget.SLOT, slot_key)

	var save: Dictionary = loaded.get("save", loaded)
	if bool(slot.get("dirty", false)):
		var conflict_result := _record_slot_conflict(slot_key, {
			"save": save,
			"details": {
				"reason": "remote_changed",
			},
		})
		_notify_sync_result(conflict_result)
		return conflict_result

	_apply_character_save_to_slot(slot_key, save)
	var refreshed_slot: Dictionary = _slots[slot_key]
	refreshed_slot["state"] = _duplicate_dictionary(save.get("state", {}))
	refreshed_slot["metadata"] = _developer_metadata(save.get("metadata", {}))
	_slots[slot_key] = refreshed_slot
	return _finalize_synced_slot(slot_key, loaded)


func force_sync(slot_key: String, options: Dictionary = {}) -> Dictionary:
	return _sync_slot(slot_key, options, true, false)


func sync_due_slots(options: Dictionary = {}) -> Array:
	var include_skipped := bool(options.get("includeSkipped", options.get("include_skipped", false)))
	var results: Array = []
	for slot_key in _slots.keys():
		var slot: Dictionary = _slots[slot_key]
		if bool(slot.get("archived", false)):
			continue
		if not bool(slot.get("dirty", false)):
			if include_skipped:
				results.append(_slot_result(slot, PersistlyGameSaveStatus.NO_CHANGES))
			continue
		var result := _sync_slot(String(slot_key), options, false, false)
		if result.get("status", "") != PersistlyGameSaveStatus.COOLDOWN or include_skipped:
			results.append(result)
	return results


func sync_due(options: Dictionary = {}) -> Dictionary:
	return {
		"profile": sync_due_profile(options),
		"slots": sync_due_slots(options),
	}


func archive_slot(slot_key: String) -> Dictionary:
	var preflight := _validate_configured("archive_slot")
	if not preflight.is_empty():
		return preflight
	if not _slots.has(slot_key):
		return load_slot(slot_key)
	if profile_save_id.is_empty() or profile_session_token.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "archive_slot requires an existing profile session.")

	var slot: Dictionary = _slots[slot_key]
	var character_save_id := String(slot.get("characterSaveId", ""))
	if character_save_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "archive_slot requires a synced characterSaveId.")

	var archived: Dictionary = _client.archive_profile_character(profile_save_id, profile_session_token, character_save_id)
	if archived.has("error"):
		return _map_remote_error(archived, PersistlyGameSaveTarget.SLOT, slot_key)

	_apply_profile_response(archived, false)
	slot = _slots[slot_key]
	slot["archived"] = true
	slot["dirty"] = false
	slot["status"] = PersistlyGameSaveStatus.SYNCED
	_slots[slot_key] = slot
	_persist_slot(slot_key)
	_persist_slot_index()
	var result := _slot_result(slot, PersistlyGameSaveStatus.SYNCED)
	result["target"] = PersistlyGameSaveTarget.SLOT
	_notify_sync_result(result)
	return result


func delete_profile() -> Dictionary:
	var preflight := _validate_configured("delete_profile")
	if not preflight.is_empty():
		return preflight

	if profile_save_id.is_empty() or profile_session_token.is_empty():
		return clear_local_profile()

	var deleted: Dictionary = _client.delete_profile(profile_save_id, profile_session_token)
	if deleted.has("error"):
		return _map_remote_error(deleted, PersistlyGameSaveTarget.PROFILE)

	var warnings: Array = []
	if bool(deleted.get("cleanupQueued", false)):
		warnings.append("delete_cleanup_queued")
	var cleared := clear_local_profile()
	cleared["status"] = PersistlyGameSaveStatus.SYNCED
	if not warnings.is_empty():
		cleared["warnings"] = warnings.duplicate(true)
	_notify_sync_result(cleared)
	return cleared


func delete_slot(slot_key: String) -> Dictionary:
	var preflight := _validate_configured("delete_slot")
	if not preflight.is_empty():
		return preflight
	var slot_error := _validate_slot_key(slot_key, "delete_slot")
	if not slot_error.is_empty():
		return slot_error
	if not _slots.has(slot_key):
		return {
			"status": PersistlyGameSaveStatus.NO_CHANGES,
			"slotKey": slot_key,
			"target": PersistlyGameSaveTarget.SLOT,
		}

	var slot: Dictionary = _slots[slot_key]
	var character_save_id := String(slot.get("characterSaveId", ""))
	if character_save_id.is_empty():
		return clear_local_slot(slot_key)

	if profile_save_id.is_empty() or profile_session_token.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "delete_slot requires an existing profile session for synced characters.", {
			"slotKey": slot_key,
		})

	var deleted: Dictionary = _client.delete_profile_character(profile_save_id, profile_session_token, character_save_id)
	if deleted.has("error"):
		return _map_remote_error(deleted, PersistlyGameSaveTarget.SLOT, slot_key)

	_slots.erase(slot_key)
	_remove_slot_file(slot_key)
	_persist_slot_index()
	if deleted.has("profile"):
		_apply_profile_save(deleted["profile"])
		_persist_profile()
	var result := {
		"status": PersistlyGameSaveStatus.SYNCED,
		"slotKey": slot_key,
		"target": PersistlyGameSaveTarget.SLOT,
	}
	if deleted.has("profile"):
		result["profile"] = _duplicate_dictionary(deleted["profile"])
	if bool(deleted.get("cleanupQueued", false)):
		result["warnings"] = ["delete_cleanup_queued"]
	_notify_sync_result(result)
	return result


func clear_local_profile() -> Dictionary:
	var preflight := _validate_configured("clear_local_profile")
	if not preflight.is_empty():
		return preflight
	for slot_key in _slots.keys():
		_remove_slot_file(String(slot_key))
	_slots.clear()
	profile_save_id = ""
	profile_session_token = ""
	profile_metadata = {}
	account_data = {}
	profile_version = 0
	sync_policy = _default_sync_policy()
	_dirty_profile = false
	_profile_last_synced_msec = 0
	_profile_updated_at_unix = 0.0
	_persist_profile()
	_persist_slot_index()
	return {
		"status": PersistlyGameSaveStatus.LOCAL_SAVED,
		"target": PersistlyGameSaveTarget.PROFILE,
		"profileSaveId": "",
		"localProfileKey": local_profile_key,
		"dirty": false,
	}


func clear_local_slot(slot_key: String) -> Dictionary:
	var slot_error := _validate_slot_key(slot_key, "clear_local_slot")
	if not slot_error.is_empty():
		return slot_error
	_slots.erase(slot_key)
	_remove_slot_file(slot_key)
	_persist_slot_index()
	return {
		"status": PersistlyGameSaveStatus.LOCAL_SAVED,
		"slotKey": slot_key,
		"target": PersistlyGameSaveTarget.SLOT,
	}


func accept_cloud_version(slot_key: String) -> Dictionary:
	var slot := load_slot(slot_key)
	if slot.get("status", "") == PersistlyGameSaveStatus.NOT_FOUND or slot.has("error"):
		return slot
	if not _slots[slot_key].has("conflict"):
		return _error_result(ERROR_INVALID_REQUEST, "accept_cloud_version requires an active conflict for slot " + slot_key + ".", {
			"slotKey": slot_key,
		})

	var conflict: Dictionary = _slots[slot_key]["conflict"]
	var stored: Dictionary = _slots[slot_key]
	if typeof(conflict.get("cloudState", null)) == TYPE_DICTIONARY:
		stored["state"] = (conflict["cloudState"] as Dictionary).duplicate(true)
	if typeof(conflict.get("cloudMetadata", null)) == TYPE_DICTIONARY:
		stored["metadata"] = _developer_metadata(conflict["cloudMetadata"])
	stored["version"] = int(conflict.get("cloudVersion", stored.get("version", 0)))
	stored["cloudVersion"] = stored["version"]
	stored["cloudState"] = stored.get("state", {}).duplicate(true)
	stored["cloudMetadata"] = stored.get("metadata", {}).duplicate(true)
	stored["dirty"] = false
	stored["status"] = PersistlyGameSaveStatus.SYNCED
	stored.erase("conflict")
	_slots[slot_key] = stored
	_persist_slot(slot_key)
	return _slot_result(stored, PersistlyGameSaveStatus.SYNCED)


func overwrite_cloud_version(slot_key: String, options: Dictionary = {}) -> Dictionary:
	var slot := load_slot(slot_key)
	if slot.get("status", "") == PersistlyGameSaveStatus.NOT_FOUND or slot.has("error"):
		return slot
	if _slots[slot_key].has("cloudVersion"):
		_slots[slot_key]["version"] = int(_slots[slot_key]["cloudVersion"])
	_slots[slot_key].erase("conflict")
	_slots[slot_key]["dirty"] = true
	return _sync_slot(slot_key, options, true, true)


func keep_local_for_later(slot_key: String) -> Dictionary:
	var slot := load_slot(slot_key)
	if slot.get("status", "") == PersistlyGameSaveStatus.NOT_FOUND or slot.has("error"):
		return slot

	var stored: Dictionary = _slots[slot_key]
	stored["status"] = PersistlyGameSaveStatus.CONFLICT if stored.has("conflict") else PersistlyGameSaveStatus.LOCAL_SAVED
	stored["dirty"] = true
	_slots[slot_key] = stored
	_persist_slot(slot_key)
	return _slot_result(stored, stored["status"])


func _sync_profile(options: Dictionary, force: bool) -> Dictionary:
	var preflight := _validate_configured("sync_profile")
	if not preflight.is_empty():
		return preflight
	if profile_save_id.is_empty() or profile_session_token.is_empty():
		return ensure_profile()
	if profile_version <= 0:
		var restored := _restore_profile(_dirty_profile)
		if restored.has("error"):
			return restored
	if not _dirty_profile:
		return _profile_result(PersistlyGameSaveStatus.NO_CHANGES, false)
	if not _can_sync_profile(options, force):
		return _profile_result(PersistlyGameSaveStatus.COOLDOWN, false)

	var payload: Dictionary = {
		"baseVersion": max(profile_version, 1),
		"accountData": account_data.duplicate(true),
		"metadata": profile_metadata.duplicate(true),
	}
	var synced: Dictionary = _client.sync_profile_account_data(profile_save_id, profile_session_token, payload)
	if synced.has("error"):
		return _map_remote_error(synced, PersistlyGameSaveTarget.PROFILE)
	if synced.get("status", "") == "conflict":
		var result := _record_profile_conflict(synced)
		_notify_sync_result(result)
		return result

	_apply_profile_save(synced.get("save", {}))
	_dirty_profile = false
	_profile_last_synced_msec = Time.get_ticks_msec()
	_persist_profile()
	var result := _profile_result(PersistlyGameSaveStatus.SYNCED, false)
	result["historyRetained"] = bool(synced.get("historyRetained", false))
	if typeof(synced.get("warnings", null)) == TYPE_ARRAY:
		result["warnings"] = (synced["warnings"] as Array).duplicate(true)
	_notify_sync_result(result)
	return result


func _sync_slot(slot_key: String, options: Dictionary, force: bool, overwrite: bool) -> Dictionary:
	var preflight := _validate_configured("sync_slot")
	if not preflight.is_empty():
		return preflight
	var slot_error := _validate_slot_key(slot_key, "sync_slot")
	if not slot_error.is_empty():
		return slot_error
	if not _slots.has(slot_key):
		return load_slot(slot_key)

	var slot: Dictionary = _slots[slot_key]
	if bool(slot.get("archived", false)):
		return _slot_result(slot, PersistlyGameSaveStatus.NOT_FOUND)
	if not bool(slot.get("dirty", false)) and not overwrite:
		return _slot_result(slot, PersistlyGameSaveStatus.NO_CHANGES)
	if not _can_sync_slot(slot, options, force):
		return _slot_result(slot, PersistlyGameSaveStatus.COOLDOWN)

	if profile_save_id.is_empty() or profile_session_token.is_empty():
		var first_sync_result := _create_profile_with_first_slot(slot_key, slot)
		if first_sync_result.has("error") or first_sync_result.get("status", "") == PersistlyGameSaveStatus.SYNCED:
			return first_sync_result

	var metadata := _remote_slot_metadata(slot_key, slot.get("metadata", {}))
	var character_save_id := String(slot.get("characterSaveId", ""))
	var response: Dictionary
	if character_save_id.is_empty():
		response = _client.create_profile_character(profile_save_id, profile_session_token, {
			"metadata": metadata,
			"state": slot.get("state", {}),
		})
		if response.has("error"):
			var error = response.get("error", {})
			if typeof(error) == TYPE_DICTIONARY and String(error.get("code", "")) == CLIENT_SCRIPT.ERROR_SLOT_ALREADY_EXISTS:
				var recovered := _recover_existing_remote_slot(slot_key)
				if recovered.has("error"):
					return recovered
				return _sync_slot(slot_key, options, true, overwrite)
			return _map_remote_error(response, PersistlyGameSaveTarget.SLOT, slot_key)
		_apply_profile_response(response, false)
		if response.has("character"):
			_apply_character_save_to_slot(slot_key, response["character"])
		return _finalize_synced_slot(slot_key)

	response = _client.sync_profile_character(profile_save_id, profile_session_token, character_save_id, {
		"baseVersion": max(int(slot.get("version", 0)), 1),
		"metadata": metadata,
		"state": slot.get("state", {}),
	})
	if response.has("error"):
		return _map_remote_error(response, PersistlyGameSaveTarget.SLOT, slot_key)
	if response.get("status", "") == "conflict":
		var conflict_result := _record_slot_conflict(slot_key, response)
		_notify_sync_result(conflict_result)
		return conflict_result

	_apply_character_save_to_slot(slot_key, response.get("save", {}))
	return _finalize_synced_slot(slot_key, response)


func _recover_existing_remote_slot(slot_key: String) -> Dictionary:
	var restored := _restore_profile(true)
	if restored.has("error"):
		return restored
	var slot: Dictionary = _slots.get(slot_key, {})
	var character_save_id := String(slot.get("characterSaveId", ""))
	if character_save_id.is_empty():
		return _error_result(ERROR_STORAGE, "Persistly could not reconcile remote slot " + slot_key + " after duplicate slot response.")

	var loaded: Dictionary = _client.load_profile_character(profile_save_id, profile_session_token, character_save_id)
	if loaded.has("error"):
		return _map_remote_error(loaded, PersistlyGameSaveTarget.SLOT, slot_key)
	_apply_character_save_to_slot(slot_key, loaded.get("save", loaded))
	_persist_slot(slot_key)
	return {}


func _create_profile_with_first_slot(slot_key: String, slot: Dictionary) -> Dictionary:
	var metadata := _remote_slot_metadata(slot_key, slot.get("metadata", {}))
	var payload: Dictionary = {
		"accountData": account_data.duplicate(true),
		"profileMetadata": profile_metadata.duplicate(true),
		"character": {
			"metadata": metadata,
			"state": slot.get("state", {}),
		},
	}
	if typeof(player_ref) == TYPE_STRING:
		payload["playerRef"] = player_ref
	if typeof(external_profile_ref) == TYPE_DICTIONARY:
		payload["externalProfileRef"] = (external_profile_ref as Dictionary).duplicate(true)

	var created: Dictionary = _client.create_profile(payload)
	if created.has("error"):
		return _map_remote_error(created, PersistlyGameSaveTarget.SLOT, slot_key)

	_apply_profile_response(created, true)
	if created.has("character"):
		_apply_character_save_to_slot(slot_key, created["character"])
	_dirty_profile = false
	_profile_last_synced_msec = Time.get_ticks_msec()
	_persist_profile()
	return _finalize_synced_slot(slot_key)


func _finalize_synced_slot(slot_key: String, sync_response: Dictionary = {}) -> Dictionary:
	var slot: Dictionary = _slots[slot_key]
	slot["dirty"] = false
	slot["status"] = PersistlyGameSaveStatus.SYNCED
	slot["lastSyncedMsec"] = Time.get_ticks_msec()
	slot["lastSyncedAtUnix"] = Time.get_unix_time_from_system()
	slot.erase("conflict")
	_slots[slot_key] = slot
	_persist_slot(slot_key)
	_persist_slot_index()
	var result := _slot_result(slot, PersistlyGameSaveStatus.SYNCED)
	result["target"] = PersistlyGameSaveTarget.SLOT
	if not sync_response.is_empty():
		result["historyRetained"] = bool(sync_response.get("historyRetained", false))
		if typeof(sync_response.get("warnings", null)) == TYPE_ARRAY:
			result["warnings"] = (sync_response["warnings"] as Array).duplicate(true)
	_notify_sync_result(result)
	return result


func _record_profile_conflict(response: Dictionary) -> Dictionary:
	var cloud_save: Dictionary = response.get("save", {})
	var cloud_state := _duplicate_dictionary(cloud_save.get("state", {}))
	var result := _profile_result(PersistlyGameSaveStatus.CONFLICT, true)
	result["reason"] = response.get("details", {}).get("reason", "base_version_mismatch")
	result["localAccountData"] = account_data.duplicate(true)
	result["cloudAccountData"] = _duplicate_dictionary(cloud_state.get("accountData", {}))
	result["localMetadata"] = profile_metadata.duplicate(true)
	result["cloudMetadata"] = _duplicate_dictionary(cloud_save.get("metadata", {}))
	result["localVersion"] = profile_version
	result["cloudVersion"] = int(cloud_save.get("version", 0))
	result["localUpdatedAtUnix"] = _profile_updated_at_unix
	result["cloudUpdatedAt"] = String(cloud_save.get("updatedAt", ""))
	result["cloudProfile"] = cloud_save.duplicate(true)
	return result


func _record_slot_conflict(slot_key: String, response: Dictionary) -> Dictionary:
	var cloud_save: Dictionary = response.get("save", {})
	var stored: Dictionary = _slots[slot_key]
	var cloud_metadata := _developer_metadata(cloud_save.get("metadata", {}))
	stored["cloudState"] = cloud_save.get("state", {}).duplicate(true)
	stored["cloudMetadata"] = cloud_metadata
	stored["cloudVersion"] = int(cloud_save.get("version", 0))
	stored["cloudUpdatedAt"] = String(cloud_save.get("updatedAt", ""))
	stored["dirty"] = true
	stored["status"] = PersistlyGameSaveStatus.CONFLICT
	stored["conflict"] = {
		"reason": response.get("details", {}).get("reason", "base_version_mismatch"),
		"localState": stored.get("state", {}).duplicate(true),
		"localMetadata": stored.get("metadata", {}).duplicate(true),
		"localVersion": int(stored.get("version", 0)),
		"cloudState": stored["cloudState"].duplicate(true),
		"cloudMetadata": cloud_metadata.duplicate(true),
		"cloudVersion": stored["cloudVersion"],
		"cloudUpdatedAt": stored["cloudUpdatedAt"],
	}
	_slots[slot_key] = stored
	_persist_slot(slot_key)

	var result := _slot_result(stored, PersistlyGameSaveStatus.CONFLICT)
	result["target"] = PersistlyGameSaveTarget.SLOT
	result["localState"] = stored["conflict"]["localState"].duplicate(true)
	result["localMetadata"] = stored["conflict"]["localMetadata"].duplicate(true)
	result["cloudState"] = stored["conflict"]["cloudState"].duplicate(true)
	result["cloudMetadata"] = stored["conflict"]["cloudMetadata"].duplicate(true)
	result["cloudVersion"] = stored["cloudVersion"]
	return result


func _apply_profile_response(response: Dictionary, include_token: bool) -> void:
	if response.has("profileSaveId"):
		profile_save_id = String(response["profileSaveId"])
	if include_token and response.has("profileSessionToken"):
		profile_session_token = String(response["profileSessionToken"])
	if response.has("syncPolicy") and typeof(response["syncPolicy"]) == TYPE_DICTIONARY:
		sync_policy = (response["syncPolicy"] as Dictionary).duplicate(true)
	if response.has("profile"):
		_apply_profile_save(response["profile"])
	if response.has("character"):
		var character: Dictionary = response["character"]
		var slot_key := _slot_key_from_metadata(character.get("metadata", {}))
		if not slot_key.is_empty():
			_apply_character_save_to_slot(slot_key, character)
	_persist_profile()


func _restore_profile(preserve_local_dirty: bool = false) -> Dictionary:
	var local_account_data := account_data.duplicate(true)
	var local_profile_metadata := profile_metadata.duplicate(true)
	var local_dirty := _dirty_profile
	var loaded: Dictionary = _client.load_profile(profile_save_id, profile_session_token)
	if loaded.has("error"):
		return _map_remote_error(loaded, PersistlyGameSaveTarget.PROFILE)
	_apply_profile_response(loaded, false)
	if preserve_local_dirty and local_dirty:
		account_data = local_account_data
		profile_metadata = local_profile_metadata
	_dirty_profile = preserve_local_dirty and local_dirty
	_profile_last_synced_msec = Time.get_ticks_msec()
	_persist_profile()
	return _profile_result(PersistlyGameSaveStatus.SYNCED, false)


func _apply_profile_save(save: Dictionary) -> void:
	if save.is_empty():
		return
	profile_save_id = String(save.get("saveId", profile_save_id))
	profile_metadata = _duplicate_dictionary(save.get("metadata", {}))
	profile_version = int(save.get("version", profile_version))
	var state = save.get("state", {})
	if typeof(state) == TYPE_DICTIONARY:
		account_data = _duplicate_dictionary(state.get("accountData", account_data))
		var character_slots = state.get("characterSlots", [])
		if typeof(character_slots) == TYPE_ARRAY:
			_apply_character_slot_refs(character_slots)
	_profile_updated_at_unix = Time.get_unix_time_from_system()


func _apply_character_slot_refs(character_slots: Array) -> void:
	for slot_ref in character_slots:
		if typeof(slot_ref) != TYPE_DICTIONARY:
			continue
		var slot_key := String(slot_ref.get("slotKey", ""))
		if slot_key.is_empty():
			continue
		var slot: Dictionary = _slots.get(slot_key, {
			"slotKey": slot_key,
			"state": {},
			"metadata": {},
			"dirty": false,
			"version": 0,
		})
		slot["characterSaveId"] = String(slot_ref.get("characterSaveId", slot.get("characterSaveId", "")))
		if typeof(slot_ref.get("metadata", null)) == TYPE_DICTIONARY and slot.get("metadata", {}).is_empty():
			slot["metadata"] = (slot_ref["metadata"] as Dictionary).duplicate(true)
		slot["archived"] = bool(slot_ref.get("archived", false))
		if slot_ref.has("archivedAt"):
			slot["archivedAt"] = String(slot_ref["archivedAt"])
		_slots[slot_key] = slot
		_persist_slot(slot_key)
	_persist_slot_index()


func _apply_character_save_to_slot(slot_key: String, save: Dictionary) -> void:
	if save.is_empty():
		return
	var slot: Dictionary = _slots.get(slot_key, {
		"slotKey": slot_key,
		"state": {},
		"metadata": {},
	})
	slot["characterSaveId"] = String(save.get("saveId", slot.get("characterSaveId", "")))
	slot["version"] = int(save.get("version", slot.get("version", 0)))
	slot["cloudVersion"] = slot["version"]
	slot["cloudState"] = _duplicate_dictionary(save.get("state", {}))
	slot["cloudMetadata"] = _developer_metadata(save.get("metadata", {}))
	slot["cloudUpdatedAt"] = String(save.get("updatedAt", ""))
	slot["archived"] = false
	if slot.get("metadata", {}).is_empty():
		slot["metadata"] = slot["cloudMetadata"].duplicate(true)
	_slots[slot_key] = slot


func _slot_result(slot: Dictionary, status: String) -> Dictionary:
	var result := _duplicate_dictionary(slot)
	result["status"] = status
	result["target"] = PersistlyGameSaveTarget.SLOT
	result["found"] = status != PersistlyGameSaveStatus.NOT_FOUND
	return result


func _profile_result(status: String, include_token: bool) -> Dictionary:
	var result := {
		"status": status,
		"target": PersistlyGameSaveTarget.PROFILE,
		"profileSaveId": profile_save_id,
		"localProfileKey": local_profile_key,
		"accountData": account_data.duplicate(true),
		"metadata": profile_metadata.duplicate(true),
		"version": profile_version,
		"dirty": _dirty_profile,
	}
	if include_token:
		result["profileSessionToken"] = profile_session_token
	return result


func _can_sync_profile(options: Dictionary, force: bool) -> bool:
	if bool(options.get("bypassCooldown", options.get("bypass_cooldown", false))):
		return true
	if _profile_last_synced_msec == 0:
		return true
	var elapsed_seconds := float(Time.get_ticks_msec() - _profile_last_synced_msec) / 1000.0
	var cooldown := float(sync_policy.get("forceSyncCooldownSeconds" if force else "minRemoteSyncIntervalSeconds", 10 if force else 60))
	return elapsed_seconds >= cooldown


func _can_sync_slot(slot: Dictionary, options: Dictionary, force: bool) -> bool:
	if bool(options.get("bypassCooldown", options.get("bypass_cooldown", false))):
		return true
	if not slot.has("lastSyncedMsec"):
		return true
	var elapsed_seconds := float(Time.get_ticks_msec() - int(slot["lastSyncedMsec"])) / 1000.0
	var cooldown := float(sync_policy.get("forceSyncCooldownSeconds" if force else "minRemoteSyncIntervalSeconds", 10 if force else 60))
	return elapsed_seconds >= cooldown


func _refresh_runtime_policy() -> Dictionary:
	var config: Dictionary = _client.get_runtime_config()
	if config.has("error"):
		return config
	if typeof(config.get("syncPolicy", null)) == TYPE_DICTIONARY:
		sync_policy = (config["syncPolicy"] as Dictionary).duplicate(true)
		_persist_profile()
	return config


func _map_remote_error(remote_error: Dictionary, target: String, slot_key: String = "") -> Dictionary:
	var error = remote_error.get("error", {})
	var code := String(error.get("code", CLIENT_SCRIPT.ERROR_SERVER))
	var status := code
	if code == CLIENT_SCRIPT.ERROR_RATE_LIMITED:
		status = PersistlyGameSaveStatus.RATE_LIMITED
	elif code == CLIENT_SCRIPT.ERROR_SERVER:
		status = PersistlyGameSaveStatus.OFFLINE
	var result := {
		"status": status,
		"target": target,
		"error": _duplicate_dictionary(error),
	}
	if not slot_key.is_empty():
		result["slotKey"] = slot_key
	return result


func _ensure_no_existing_local_profile_state(message: String) -> Dictionary:
	if not _is_blank_local_profile_state() or not _slots.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, message)
	return {}


func _is_blank_local_profile_state() -> bool:
	return profile_save_id.is_empty() \
		and profile_session_token.is_empty() \
		and profile_metadata.is_empty() \
		and account_data.is_empty() \
		and not _dirty_profile \
		and profile_version == 0


func _notify_sync_result(result: Dictionary) -> void:
	if _on_sync_result.is_valid():
		_on_sync_result.call(result.duplicate(true))


func _remote_slot_metadata(slot_key: String, metadata: Variant) -> Dictionary:
	var remote_metadata := _duplicate_dictionary(metadata)
	remote_metadata["_persistly"] = {
		"slotKey": slot_key,
	}
	return remote_metadata


func _developer_metadata(metadata: Variant) -> Dictionary:
	var result := _duplicate_dictionary(metadata)
	result.erase("_persistly")
	return result


func _slot_key_from_metadata(metadata: Variant) -> String:
	if typeof(metadata) != TYPE_DICTIONARY:
		return ""
	var persistly_metadata = (metadata as Dictionary).get("_persistly", null)
	if typeof(persistly_metadata) != TYPE_DICTIONARY:
		return ""
	return String((persistly_metadata as Dictionary).get("slotKey", ""))


func _load_local_records() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(_profile_root)
	DirAccess.make_dir_recursive_absolute(_slots_root())
	_load_profile_record()
	return _load_slot_records()


func _load_profile_record() -> void:
	var path := _profile_path()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var record: Dictionary = parsed
	if record.get("schema", "") != PROFILE_SCHEMA:
		return
	profile_save_id = String(record.get("profileSaveId", profile_save_id))
	profile_session_token = String(record.get("profileSessionToken", profile_session_token))
	profile_metadata = _duplicate_dictionary(record.get("metadata", {}))
	account_data = _duplicate_dictionary(record.get("accountData", {}))
	profile_version = int(record.get("version", 0))
	_dirty_profile = bool(record.get("dirty", false))
	_profile_last_synced_msec = int(record.get("lastSyncedMsec", 0))
	_profile_updated_at_unix = float(record.get("updatedAtUnix", 0.0))
	if typeof(record.get("syncPolicy", null)) == TYPE_DICTIONARY:
		sync_policy = (record["syncPolicy"] as Dictionary).duplicate(true)


func _load_slot_records() -> Dictionary:
	var index_path := _slot_index_path()
	if not FileAccess.file_exists(index_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _error_result(ERROR_STORAGE, "Persistly slot index is not valid JSON.")
	var index_record: Dictionary = parsed
	if index_record.get("schema", "") != SLOT_INDEX_SCHEMA:
		return _error_result(ERROR_STORAGE, "Persistly slot index schema is not supported.")
	var slot_keys = index_record.get("slots", [])
	if typeof(slot_keys) != TYPE_ARRAY:
		return _error_result(ERROR_STORAGE, "Persistly slot index slots must be an array.")
	for key in slot_keys:
		var slot_key := String(key)
		var slot_path := _slot_path(slot_key)
		if not FileAccess.file_exists(slot_path):
			continue
		var slot_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path))
		if typeof(slot_parsed) != TYPE_DICTIONARY:
			return _error_result(ERROR_STORAGE, "Persistly slot record is not valid JSON.")
		var slot_record: Dictionary = slot_parsed
		if slot_record.get("schema", "") != SLOT_SCHEMA:
			return _error_result(ERROR_STORAGE, "Persistly slot record schema is not supported.")
		var slot = slot_record.get("slot", {})
		if typeof(slot) == TYPE_DICTIONARY:
			_slots[slot_key] = (slot as Dictionary).duplicate(true)
	return {}


func _persist_profile() -> void:
	if _profile_root.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_profile_root)
	var record := {
		"schema": PROFILE_SCHEMA,
		"profileSaveId": profile_save_id,
		"profileSessionToken": profile_session_token,
		"playerRef": player_ref,
		"externalProfileRef": external_profile_ref,
		"metadata": profile_metadata.duplicate(true),
		"accountData": account_data.duplicate(true),
		"version": profile_version,
		"syncPolicy": sync_policy.duplicate(true),
		"dirty": _dirty_profile,
		"lastSyncedMsec": _profile_last_synced_msec,
		"updatedAtUnix": _profile_updated_at_unix,
	}
	_write_json(_profile_path(), record)


func _persist_slot(slot_key: String) -> void:
	if _profile_root.is_empty() or not _slots.has(slot_key):
		return
	DirAccess.make_dir_recursive_absolute(_slots_root())
	_write_json(_slot_path(slot_key), {
		"schema": SLOT_SCHEMA,
		"slot": _slots[slot_key],
	})


func _persist_slot_index() -> void:
	if _profile_root.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_profile_root)
	var keys := _slots.keys()
	keys.sort()
	_write_json(_slot_index_path(), {
		"schema": SLOT_INDEX_SCHEMA,
		"slots": keys,
	})


func _remove_slot_file(slot_key: String) -> void:
	var path := _slot_path(slot_key)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value))
		file.close()


func _profile_path() -> String:
	return _profile_root.path_join("profile.json")


func _slot_index_path() -> String:
	return _profile_root.path_join("slot_index.json")


func _slots_root() -> String:
	return _profile_root.path_join("slots")


func _slot_path(slot_key: String) -> String:
	return _slots_root().path_join(slot_key.uri_encode() + ".json")


func _resolve_local_profile_key() -> String:
	if typeof(external_profile_ref) == TYPE_DICTIONARY:
		var provider := String((external_profile_ref as Dictionary).get("provider", "")).strip_edges()
		var subject := String((external_profile_ref as Dictionary).get("subject", "")).strip_edges()
		if not provider.is_empty() and not subject.is_empty():
			return provider + ":" + subject
	if typeof(player_ref) == TYPE_STRING and not String(player_ref).strip_edges().is_empty():
		return String(player_ref).strip_edges()
	return _load_or_create_anonymous_key()


func _load_or_create_anonymous_key() -> String:
	DirAccess.make_dir_recursive_absolute(_storage_path)
	var path := _storage_path.path_join("anonymous_profile_key.txt")
	if FileAccess.file_exists(path):
		var stored := FileAccess.get_file_as_string(path).strip_edges()
		if not stored.is_empty():
			return stored
	var generated := "anonymous-" + str(Time.get_unix_time_from_system()) + "-" + str(randi())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(generated)
		file.close()
	return generated


func _setting(settings: Dictionary, snake_key: String, camel_key: String, default_value: Variant) -> Variant:
	if settings.has(snake_key):
		return settings[snake_key]
	if settings.has(camel_key):
		return settings[camel_key]
	return default_value


func _validate_configured(action: String) -> Dictionary:
	if runtime_key.is_empty():
		return _error_result(ERROR_NOT_CONFIGURED, "Call PersistlyGameSaves.configure with runtime_key before " + action + ".")
	return {}


func _validate_slot_key(slot_key: String, action: String) -> Dictionary:
	if not CLIENT_SCRIPT.new()._is_valid_slot_key(slot_key):
		return _error_result(ERROR_INVALID_REQUEST, action + " requires slot_key matching ^[A-Za-z0-9_.-]{1,64}$.", {
			"slotKey": slot_key,
		})
	return {}


func _validate_developer_metadata(metadata: Dictionary, action: String) -> Dictionary:
	if metadata.has("_persistly"):
		return _error_result(ERROR_INVALID_REQUEST, action + " metadata must not contain reserved _persistly fields.")
	return {}


func _error_result(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var result := {
		"status": code,
		"error": {
			"code": code,
			"message": message,
		},
	}
	if not details.is_empty():
		result["error"]["details"] = details.duplicate(true)
	return result


func _duplicate_dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _default_sync_policy() -> Dictionary:
	return {
		"minRemoteSyncIntervalSeconds": 60,
		"forceSyncCooldownSeconds": 10,
		"syncOnAppBackground": true,
		"syncOnAppForeground": true,
		"syncOnReconnect": true,
		"maxQueuedLocalSnapshots": 25,
	}


class PersistlyGameSaveStatus:
	const LOCAL_SAVED := "local_saved"
	const LOCAL_FOUND := "local_found"
	const NOT_FOUND := "not_found"
	const NO_CHANGES := "no_changes"
	const COOLDOWN := "cooldown"
	const SYNCED := "synced"
	const CONFLICT := "conflict"
	const OFFLINE := "offline"
	const RATE_LIMITED := "rate_limited"


class PersistlySlotStatus:
	const LOCAL_SAVED := "local_saved"
	const LOCAL_FOUND := "local_found"
	const NOT_FOUND := "not_found"
	const NO_CHANGES := "no_changes"
	const COOLDOWN := "cooldown"
	const SYNCED := "synced"
	const CONFLICT := "conflict"
	const OFFLINE := "offline"
	const RATE_LIMITED := "rate_limited"


class PersistlyGameSaveTarget:
	const PROFILE := "profile"
	const SLOT := "slot"
