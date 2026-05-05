extends RefCounted
class_name PersistlyGameSaves

const CLIENT_SCRIPT := preload("res://addons/persistly/persistly_client.gd")

const DEFAULT_BASE_URL := "https://api.persistly.app"
const DEFAULT_SYNC_INTERVAL_SECONDS := 60.0

const ERROR_NOT_CONFIGURED := "not_configured"
const ERROR_INVALID_REQUEST := "invalid_request"
const ERROR_NOT_FOUND := "not_found"

var base_url: String = DEFAULT_BASE_URL
var runtime_key: String = ""
var sync_interval_seconds: float = DEFAULT_SYNC_INTERVAL_SECONDS

var _client: Object = CLIENT_SCRIPT.new()
var _slots: Dictionary = {}


func configure(settings: Dictionary) -> Dictionary:
	base_url = String(settings.get("base_url", DEFAULT_BASE_URL)).strip_edges().rstrip("/")
	if base_url.is_empty():
		base_url = DEFAULT_BASE_URL

	runtime_key = String(settings.get("runtime_key", "")).strip_edges()
	sync_interval_seconds = max(float(settings.get("sync_interval_seconds", DEFAULT_SYNC_INTERVAL_SECONDS)), 1.0)
	_client.configure(base_url, runtime_key, sync_interval_seconds)

	if runtime_key.is_empty():
		return _error_result(ERROR_NOT_CONFIGURED, "PersistlyGameSaves requires runtime_key in configure settings.")

	return {
		"status": "configured",
		"baseUrl": base_url,
		"syncIntervalSeconds": sync_interval_seconds,
	}


func save_slot(slot_key: String, state: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	var preflight := _validate_configured("save_slot")
	if not preflight.is_empty():
		return preflight

	var slot_error := _validate_slot_key(slot_key, "save_slot")
	if not slot_error.is_empty():
		return slot_error

	var stored := {
		"slotKey": slot_key,
		"status": PersistlySlotStatus.LOCAL_SAVED,
		"state": state.duplicate(true),
		"metadata": metadata.duplicate(true),
		"updatedAtUnix": Time.get_unix_time_from_system(),
		"remoteSaveId": "",
		"version": 0,
	}
	_slots[slot_key] = stored
	return _duplicate_dictionary(stored)


func load_slot(slot_key: String) -> Dictionary:
	var preflight := _validate_configured("load_slot")
	if not preflight.is_empty():
		return preflight

	var slot_error := _validate_slot_key(slot_key, "load_slot")
	if not slot_error.is_empty():
		return slot_error
	if not _slots.has(slot_key):
		return _error_result(ERROR_NOT_FOUND, "PersistlyGameSaves could not find slot " + slot_key + ".", {
			"slotKey": slot_key,
		})

	return _duplicate_dictionary(_slots[slot_key])


func force_sync(slot_key: String) -> Dictionary:
	var preflight := _validate_configured("force_sync")
	if not preflight.is_empty():
		return preflight

	var slot := load_slot(slot_key)
	if slot.has("error"):
		return slot

	# Task 5 intentionally keeps remote profile sync out of scope.
	slot["status"] = PersistlySlotStatus.LOCAL_SAVED
	slot["sync"] = {
		"remoteAttempted": false,
		"reason": "remote_profile_sync_not_wired",
	}
	return slot


func accept_cloud_version(slot_key: String) -> Dictionary:
	var slot := load_slot(slot_key)
	if slot.has("error"):
		return slot

	var conflict = slot.get("conflict", {})
	if typeof(conflict) == TYPE_DICTIONARY and typeof(conflict.get("cloudState", null)) == TYPE_DICTIONARY:
		slot["state"] = (conflict["cloudState"] as Dictionary).duplicate(true)
	if typeof(conflict) == TYPE_DICTIONARY and typeof(conflict.get("cloudMetadata", null)) == TYPE_DICTIONARY:
		slot["metadata"] = (conflict["cloudMetadata"] as Dictionary).duplicate(true)
	slot["status"] = PersistlySlotStatus.SYNCED
	slot.erase("conflict")
	_slots[slot_key] = slot
	return _duplicate_dictionary(slot)


func overwrite_cloud_version(slot_key: String) -> Dictionary:
	var slot := load_slot(slot_key)
	if slot.has("error"):
		return slot

	slot["status"] = PersistlySlotStatus.LOCAL_SAVED
	slot["sync"] = {
		"remoteAttempted": false,
		"reason": "remote_profile_sync_not_wired",
		"intent": "overwrite_cloud",
	}
	slot.erase("conflict")
	_slots[slot_key] = slot
	return _duplicate_dictionary(slot)


func keep_local_for_later(slot_key: String) -> Dictionary:
	var slot := load_slot(slot_key)
	if slot.has("error"):
		return slot

	slot["status"] = PersistlySlotStatus.CONFLICT if slot.has("conflict") else PersistlySlotStatus.LOCAL_SAVED
	slot["sync"] = {
		"remoteAttempted": false,
		"reason": "kept_local_for_later",
	}
	_slots[slot_key] = slot
	return _duplicate_dictionary(slot)


func _validate_configured(action: String) -> Dictionary:
	if runtime_key.is_empty():
		return _error_result(ERROR_NOT_CONFIGURED, "Call PersistlyGameSaves.configure with runtime_key before " + action + ".")
	return {}


func _validate_slot_key(slot_key: String, action: String) -> Dictionary:
	if slot_key.strip_edges().is_empty():
		return _error_result(ERROR_INVALID_REQUEST, action + " requires a non-empty slot_key.")
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


func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return value.duplicate(true)


class PersistlySlotStatus:
	const LOCAL_SAVED := "local_saved"
	const SYNCED := "synced"
	const CONFLICT := "conflict"
	const OFFLINE := "offline"
	const RATE_LIMITED := "rate_limited"
