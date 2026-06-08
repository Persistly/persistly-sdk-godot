extends RefCounted
class_name PersistlyGameSaves

const CLIENT_SCRIPT := preload("res://addons/persistly/persistly_client.gd")

const PERSISTLY_API_ORIGIN := "https://api.persistly.app"
const DEFAULT_SLOT_KEY := "autosave"
const DEFAULT_SYNC_INTERVAL_SECONDS := 60.0
const DEFAULT_STORAGE_PATH := "user://persistly_game_saves"
const ACCOUNT_SCHEMA := "persistly.godot.account.v1"
const SLOT_INDEX_SCHEMA := "persistly.godot.slot-index.v1"
const SLOT_SCHEMA := "persistly.godot.slot.v1"

const ERROR_NOT_CONFIGURED := "not_configured"
const ERROR_INVALID_REQUEST := "invalid_request"
const ERROR_NOT_FOUND := "not_found"
const ERROR_STORAGE := "storage_error"
const ERROR_AUTH_REQUIRED := "auth_required"

var runtime_key: String = ""
var sync_interval_seconds: float = DEFAULT_SYNC_INTERVAL_SECONDS
var account_mode: String = PersistlyAccountMode.ANONYMOUS_FIRST
var player_ref: Variant = null
var external_account_ref: Variant = null
var local_account_key: String = ""
var account_id: String = ""
var account_session_token: String = ""
var account_data: Dictionary = {}
var account_version: int = 0
var sync_policy: Dictionary = _default_sync_policy()

var _client: Object = CLIENT_SCRIPT.new()
var _slots: Dictionary = {}
var _storage_path: String = DEFAULT_STORAGE_PATH
var _account_root: String = ""
var _dirty_account: bool = false
var _account_last_synced_msec: int = 0
var _account_updated_at_unix: float = 0.0
var _on_sync_result: Callable = Callable()


func configure(settings: Dictionary) -> Dictionary:
	runtime_key = String(_setting(settings, "runtime_key", "runtimeKey", "")).strip_edges()
	sync_interval_seconds = max(float(_setting(settings, "sync_interval_seconds", "syncIntervalSeconds", DEFAULT_SYNC_INTERVAL_SECONDS)), 1.0)
	account_mode = String(_setting(settings, "account_mode", "accountMode", PersistlyAccountMode.ANONYMOUS_FIRST)).strip_edges()
	if account_mode.is_empty():
		account_mode = PersistlyAccountMode.ANONYMOUS_FIRST
	player_ref = _setting(settings, "player_ref", "playerRef", null)
	external_account_ref = _setting(settings, "external_account_ref", "externalAccountRef", null)
	_storage_path = String(_setting(settings, "storage_path", "storagePath", DEFAULT_STORAGE_PATH)).rstrip("/")
	local_account_key = String(_setting(settings, "local_account_key", "localAccountKey", "")).strip_edges()
	if local_account_key.is_empty():
		local_account_key = _resolve_local_account_key()
	_account_root = _storage_path.path_join(local_account_key.uri_encode())

	_client.configure_runtime_key(runtime_key, sync_interval_seconds)

	if settings.has("onSyncResult") and settings["onSyncResult"] is Callable:
		_on_sync_result = settings["onSyncResult"]
	elif settings.has("on_sync_result") and settings["on_sync_result"] is Callable:
		_on_sync_result = settings["on_sync_result"]

	if runtime_key.is_empty():
		return _error_result(ERROR_NOT_CONFIGURED, "PersistlyGameSaves requires runtime_key in configure settings.")
	if account_mode != PersistlyAccountMode.ANONYMOUS_FIRST and account_mode != PersistlyAccountMode.AUTH_REQUIRED:
		return _error_result(ERROR_INVALID_REQUEST, "PersistlyGameSaves accountMode must be anonymousFirst or authRequired.")

	var storage_error := _load_local_records()
	if not storage_error.is_empty():
		return storage_error

	var configured_account_id := String(_setting(settings, "account_id", "accountId", "")).strip_edges()
	if not configured_account_id.is_empty():
		account_id = configured_account_id
	var configured_account_session_token := String(_setting(settings, "account_session_token", "accountSessionToken", "")).strip_edges()
	if not configured_account_session_token.is_empty():
		account_session_token = configured_account_session_token
	if settings.has("syncPolicy") and typeof(settings["syncPolicy"]) == TYPE_DICTIONARY:
		sync_policy = (settings["syncPolicy"] as Dictionary).duplicate(true)
	elif settings.has("sync_policy") and typeof(settings["sync_policy"]) == TYPE_DICTIONARY:
		sync_policy = (settings["sync_policy"] as Dictionary).duplicate(true)

	_persist_account()

	return {
		"status": "configured",
		"syncIntervalSeconds": sync_interval_seconds,
		"accountMode": account_mode,
		"localAccountKey": local_account_key,
		"accountId": account_id,
	}


func create_account() -> Dictionary:
	var preflight := _validate_configured("create_account")
	if not preflight.is_empty():
		return preflight
	var local_state_error := _ensure_no_existing_local_account_state(
		"create_account requires empty local account state. Call clear_local_account before creating a different account."
	)
	if not local_state_error.is_empty():
		return local_state_error
	return ensure_account()


func attach_account(account_id_value: String, account_session_token_value: String) -> Dictionary:
	var preflight := _validate_configured("attach_account")
	if not preflight.is_empty():
		return preflight
	if account_id_value.strip_edges().is_empty() or account_session_token_value.strip_edges().is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "attach_account requires non-empty account_id and account_session_token.")
	var local_state_error := _ensure_no_existing_local_account_state(
		"attach_account requires empty local account state. Call clear_local_account before attaching a different account."
	)
	if not local_state_error.is_empty():
		return local_state_error
	account_id = account_id_value.strip_edges()
	account_session_token = account_session_token_value.strip_edges()
	_dirty_account = false
	_persist_account()
	return _restore_account(false)


func create_transfer_code(options: Dictionary = {}) -> Dictionary:
	var preflight := _validate_configured("create_transfer_code")
	if not preflight.is_empty():
		return preflight
	if account_id.is_empty() or account_session_token.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "create_transfer_code requires an existing account session.")
	return _client.create_transfer_code(account_id, account_session_token, options)


func attach_with_transfer_code(transfer_code: String, options: Dictionary = {}) -> Dictionary:
	var preflight := _validate_configured("attach_with_transfer_code")
	if not preflight.is_empty():
		return preflight
	if transfer_code.strip_edges().is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "attach_with_transfer_code requires a non-empty transfer_code.")
	var local_state_error := _ensure_no_existing_local_account_state(
		"attach_with_transfer_code requires empty local account state. Call clear_local_account before attaching a different account."
	)
	if not local_state_error.is_empty():
		return local_state_error

	var consumed: Dictionary = _client.consume_transfer_code(transfer_code, options)
	if consumed.has("error"):
		return _map_remote_error(consumed, PersistlyGameSaveTarget.ACCOUNT)

	_apply_account_response(consumed, true)
	_dirty_account = false
	_account_last_synced_msec = Time.get_ticks_msec()
	_persist_account()
	return _account_result(PersistlyGameSaveStatus.SYNCED, false)


func sign_in_with_firebase_token(firebase_id_token: String, options := {}) -> Dictionary:
	if typeof(options) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "sign_in_with_firebase_token options must be a dictionary.")
	var input := (options as Dictionary).duplicate(true)
	input["provider"] = "firebase"
	input["token"] = firebase_id_token
	return sign_in_with_provider(input)


func sign_in_with_provider(input: Dictionary) -> Dictionary:
	var preflight := _validate_configured("sign_in_with_provider")
	if not preflight.is_empty():
		return preflight
	return _exchange_provider_session(input, account_session_token, account_id)


func link_provider(input: Dictionary) -> Dictionary:
	var preflight := _validate_configured("link_provider")
	if not preflight.is_empty():
		return preflight
	if account_session_token.is_empty():
		return _auth_required_result(PersistlyGameSaveTarget.ACCOUNT, "link_provider requires sign-in or an existing account session.")
	return _exchange_provider_session(input, account_session_token, account_id)


func list_linked_providers() -> Dictionary:
	var preflight := _validate_configured("list_linked_providers")
	if not preflight.is_empty():
		return preflight
	if account_session_token.is_empty():
		return _auth_required_result(PersistlyGameSaveTarget.ACCOUNT, "list_linked_providers requires sign-in or an existing account session.")
	var providers: Dictionary = _client.list_linked_providers(account_id, account_session_token)
	if providers.has("error"):
		return _map_remote_error(providers, PersistlyGameSaveTarget.ACCOUNT)
	return providers


func sign_out() -> Dictionary:
	return clear_local_account()


func ensure_account() -> Dictionary:
	var preflight := _validate_configured("ensure_account")
	if not preflight.is_empty():
		return preflight
	if not account_id.is_empty() and not account_session_token.is_empty():
		if account_version <= 0:
			var restored := _restore_account()
			if restored.has("error"):
				return restored
			return _account_result(PersistlyGameSaveStatus.SYNCED, false)
		return _account_result(PersistlyGameSaveStatus.SYNCED, false)

	if account_mode == PersistlyAccountMode.AUTH_REQUIRED:
		return _auth_required_result(PersistlyGameSaveTarget.ACCOUNT, "Sign in before creating a cloud account.")

	var config_result := _refresh_runtime_policy()
	if config_result.has("error") and config_result["error"].get("code", "") != CLIENT_SCRIPT.ERROR_RATE_LIMITED:
		return config_result

	var payload: Dictionary = {
		"accountData": account_data.duplicate(true),
	}
	if typeof(player_ref) == TYPE_STRING:
		payload["playerRef"] = player_ref
	if typeof(external_account_ref) == TYPE_DICTIONARY:
		payload["externalAccountRef"] = (external_account_ref as Dictionary).duplicate(true)

	var created: Dictionary = _client.create_account(payload)
	if created.has("error"):
		return _map_remote_error(created, PersistlyGameSaveTarget.ACCOUNT)

	_apply_account_response(created, true)
	_dirty_account = false
	_account_last_synced_msec = Time.get_ticks_msec()
	_persist_account()
	return _account_result(PersistlyGameSaveStatus.SYNCED, false)


func get_account_session(options: Dictionary = {}) -> Dictionary:
	var result := {
		"accountId": account_id,
		"localAccountKey": local_account_key,
	}
	if bool(options.get("includeToken", options.get("include_token", false))):
		result["accountSessionToken"] = account_session_token
	return result


func account_info() -> Dictionary:
	return _account_result(PersistlyGameSaveStatus.LOCAL_FOUND, false)


func get_account_data() -> Dictionary:
	return account_data.duplicate(true)


func save_account_data(new_account_data: Dictionary) -> Dictionary:
	var preflight := _validate_configured("save_account_data")
	if not preflight.is_empty():
		return preflight
	account_data = new_account_data.duplicate(true)
	_dirty_account = true
	_account_updated_at_unix = Time.get_unix_time_from_system()
	_persist_account()
	return {
		"status": PersistlyGameSaveStatus.LOCAL_SAVED,
		"target": PersistlyGameSaveTarget.ACCOUNT,
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


func save_data(data: Dictionary, options: Dictionary = {}) -> Dictionary:
	return save_slot(DEFAULT_SLOT_KEY, data, options)


func load_data() -> Dictionary:
	return load_slot(DEFAULT_SLOT_KEY)


func inspect_data() -> Dictionary:
	return slot_info(DEFAULT_SLOT_KEY)


func refresh_data() -> Dictionary:
	return refresh_slot(DEFAULT_SLOT_KEY)


func force_sync_data(options: Dictionary = {}) -> Dictionary:
	return force_sync(DEFAULT_SLOT_KEY, options)


func force_sync_account(options: Dictionary = {}) -> Dictionary:
	return _sync_account(options, true)


func sync_due_account(options: Dictionary = {}) -> Dictionary:
	return _sync_account(options, false)


func save_slot(slot_id: String, data: Dictionary, options: Dictionary = {}) -> Dictionary:
	var preflight := _validate_configured("save_slot")
	if not preflight.is_empty():
		return preflight

	var slot_error := _validate_slot_id(slot_id, "save_slot")
	if not slot_error.is_empty():
		return slot_error
	if typeof(data) != TYPE_DICTIONARY or typeof(options) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "save_slot requires dictionary data and options.")
	var slot_info := options.get("slotInfo", options.get("slot_info", options))
	if typeof(slot_info) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "save_slot slotInfo must be a dictionary.")
	var slot_info_error := _validate_developer_slot_info(slot_info, "save_slot")
	if not slot_info_error.is_empty():
		return slot_info_error

	var previous := _slots.get(slot_id, {})
	var was_archived := bool(previous.get("archived", false))
	var stored := {} if was_archived else _duplicate_dictionary(previous)
	stored["slotId"] = slot_id
	stored["status"] = PersistlyGameSaveStatus.LOCAL_SAVED
	stored["data"] = data.duplicate(true)
	stored["slotInfo"] = slot_info.duplicate(true)
	stored["updatedAtUnix"] = Time.get_unix_time_from_system()
	stored["dirty"] = true
	stored["archived"] = false
	if not stored.has("slotId"):
		stored["slotId"] = ""
	if not stored.has("version"):
		stored["version"] = 0
	_slots[slot_id] = stored
	_persist_slot(slot_id)
	_persist_slot_index()
	return _slot_result(stored, PersistlyGameSaveStatus.LOCAL_SAVED)


func load_slot(slot_id: String) -> Dictionary:
	var preflight := _validate_configured("load_slot")
	if not preflight.is_empty():
		return preflight

	var slot_error := _validate_slot_id(slot_id, "load_slot")
	if not slot_error.is_empty():
		return slot_error
	if not _slots.has(slot_id):
		return {
			"status": PersistlyGameSaveStatus.NOT_FOUND,
			"slotId": slot_id,
			"found": false,
		}

	return _slot_result(_slots[slot_id], PersistlyGameSaveStatus.LOCAL_FOUND)


func list_slot_data(options: Dictionary = {}) -> Array:
	var include_archived := bool(options.get("includeArchived", options.get("include_archived", false)))
	var slots: Array = []
	for slot_id in _slots.keys():
		var slot: Dictionary = _slots[slot_id]
		if bool(slot.get("archived", false)) and not include_archived:
			continue
		slots.append(_slot_result(slot, PersistlyGameSaveStatus.LOCAL_FOUND))
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("slotId", "")) < String(b.get("slotId", ""))
	)
	return slots


func slot_info(slot_id: String) -> Dictionary:
	return load_slot(slot_id)


func refresh_slot(slot_id: String) -> Dictionary:
	var preflight := _validate_configured("refresh_slot")
	if not preflight.is_empty():
		return preflight
	var slot_error := _validate_slot_id(slot_id, "refresh_slot")
	if not slot_error.is_empty():
		return slot_error
	if account_id.is_empty() or account_session_token.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "refresh_slot requires an existing account session.", {
			"slotId": slot_id,
		})

	var restored := _restore_account(true)
	if restored.has("error"):
		return restored
	if not _slots.has(slot_id):
		return {
			"status": PersistlyGameSaveStatus.NOT_FOUND,
			"target": PersistlyGameSaveTarget.SLOT,
			"slotId": slot_id,
			"found": false,
		}

	var slot: Dictionary = _slots[slot_id]
	if bool(slot.get("archived", false)):
		return {
			"status": PersistlyGameSaveStatus.NOT_FOUND,
			"target": PersistlyGameSaveTarget.SLOT,
			"slotId": slot_id,
			"found": false,
		}

	var loaded: Dictionary = _client.load_account_slot(account_id, account_session_token, slot_id)
	if loaded.has("error"):
		return _map_remote_error(loaded, PersistlyGameSaveTarget.SLOT, slot_id)

	var remote_slot: Dictionary = loaded.get("slot", loaded)
	if bool(slot.get("dirty", false)):
		var conflict_result := _record_slot_conflict(slot_id, {
			"slot": remote_slot,
			"details": {
				"reason": "remote_changed",
			},
		})
		_notify_sync_result(conflict_result)
		return conflict_result

	_apply_slot_save_to_slot(slot_id, remote_slot)
	var refreshed_slot: Dictionary = _slots[slot_id]
	refreshed_slot["data"] = _duplicate_dictionary(remote_slot.get("data", {}))
	refreshed_slot["slotInfo"] = _duplicate_dictionary(remote_slot.get("slotInfo", {}))
	_slots[slot_id] = refreshed_slot
	return _finalize_synced_slot(slot_id, loaded)


func force_sync(slot_id: String, options: Dictionary = {}) -> Dictionary:
	return _sync_slot(slot_id, options, true, false)


func sync_due_slots(options: Dictionary = {}) -> Array:
	var include_skipped := bool(options.get("includeSkipped", options.get("include_skipped", false)))
	var results: Array = []
	for slot_id in _slots.keys():
		var slot: Dictionary = _slots[slot_id]
		if bool(slot.get("archived", false)):
			continue
		if not bool(slot.get("dirty", false)):
			if include_skipped:
				results.append(_slot_result(slot, PersistlyGameSaveStatus.NO_CHANGES))
			continue
		var result := _sync_slot(String(slot_id), options, false, false)
		if result.get("status", "") != PersistlyGameSaveStatus.COOLDOWN or include_skipped:
			results.append(result)
	return results


func sync_due(options: Dictionary = {}) -> Dictionary:
	return {
		"account": sync_due_account(options),
		"slots": sync_due_slots(options),
	}


func archive_slot(slot_id: String) -> Dictionary:
	var preflight := _validate_configured("archive_slot")
	if not preflight.is_empty():
		return preflight
	if not _slots.has(slot_id):
		return load_slot(slot_id)
	if account_id.is_empty() or account_session_token.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "archive_slot requires an existing account session.")

	var slot: Dictionary = _slots[slot_id]
	if int(slot.get("version", 0)) <= 0:
		return _error_result(ERROR_INVALID_REQUEST, "archive_slot requires a synced slot.")

	var archived: Dictionary = _client.archive_account_slot(account_id, account_session_token, slot_id)
	if archived.has("error"):
		return _map_remote_error(archived, PersistlyGameSaveTarget.SLOT, slot_id)

	_apply_account_response(archived, false)
	slot = _slots[slot_id]
	slot["archived"] = true
	slot["dirty"] = false
	slot["status"] = PersistlyGameSaveStatus.SYNCED
	_slots[slot_id] = slot
	_persist_slot(slot_id)
	_persist_slot_index()
	var result := _slot_result(slot, PersistlyGameSaveStatus.SYNCED)
	result["target"] = PersistlyGameSaveTarget.SLOT
	_notify_sync_result(result)
	return result


func delete_account() -> Dictionary:
	var preflight := _validate_configured("delete_account")
	if not preflight.is_empty():
		return preflight

	if account_id.is_empty() or account_session_token.is_empty():
		return clear_local_account()

	var deleted: Dictionary = _client.delete_account(account_id, account_session_token)
	if deleted.has("error"):
		return _map_remote_error(deleted, PersistlyGameSaveTarget.ACCOUNT)

	var warnings: Array = []
	if bool(deleted.get("cleanupQueued", false)):
		warnings.append("delete_cleanup_queued")
	var cleared := clear_local_account()
	cleared["status"] = PersistlyGameSaveStatus.SYNCED
	if not warnings.is_empty():
		cleared["warnings"] = warnings.duplicate(true)
	_notify_sync_result(cleared)
	return cleared


func delete_slot(slot_id: String) -> Dictionary:
	var preflight := _validate_configured("delete_slot")
	if not preflight.is_empty():
		return preflight
	var slot_error := _validate_slot_id(slot_id, "delete_slot")
	if not slot_error.is_empty():
		return slot_error
	if not _slots.has(slot_id):
		return {
			"status": PersistlyGameSaveStatus.NO_CHANGES,
			"slotId": slot_id,
			"target": PersistlyGameSaveTarget.SLOT,
		}

	var slot: Dictionary = _slots[slot_id]
	if int(slot.get("version", 0)) <= 0:
		return clear_local_slot(slot_id)

	if account_id.is_empty() or account_session_token.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "delete_slot requires an existing account session for synced slots.", {
			"slotId": slot_id,
		})

	var deleted: Dictionary = _client.delete_account_slot(account_id, account_session_token, slot_id)
	if deleted.has("error"):
		return _map_remote_error(deleted, PersistlyGameSaveTarget.SLOT, slot_id)

	_slots.erase(slot_id)
	_remove_slot_file(slot_id)
	_persist_slot_index()
	if deleted.has("account"):
		_apply_account_save(deleted["account"])
		_persist_account()
	var result := {
		"status": PersistlyGameSaveStatus.SYNCED,
		"slotId": slot_id,
		"target": PersistlyGameSaveTarget.SLOT,
	}
	if deleted.has("account"):
		result["account"] = _duplicate_dictionary(deleted["account"])
	if bool(deleted.get("cleanupQueued", false)):
		result["warnings"] = ["delete_cleanup_queued"]
	_notify_sync_result(result)
	return result


func clear_local_account() -> Dictionary:
	var preflight := _validate_configured("clear_local_account")
	if not preflight.is_empty():
		return preflight
	for slot_id in _slots.keys():
		_remove_slot_file(String(slot_id))
	_slots.clear()
	account_id = ""
	account_session_token = ""
	account_data = {}
	account_version = 0
	sync_policy = _default_sync_policy()
	_dirty_account = false
	_account_last_synced_msec = 0
	_account_updated_at_unix = 0.0
	if _client.has_method("clear_cache"):
		_client.clear_cache()
	_persist_account()
	_persist_slot_index()
	return {
		"status": PersistlyGameSaveStatus.LOCAL_SAVED,
		"target": PersistlyGameSaveTarget.ACCOUNT,
		"accountId": "",
		"localAccountKey": local_account_key,
		"dirty": false,
	}


func clear_local_slot(slot_id: String) -> Dictionary:
	var slot_error := _validate_slot_id(slot_id, "clear_local_slot")
	if not slot_error.is_empty():
		return slot_error
	_slots.erase(slot_id)
	_remove_slot_file(slot_id)
	_persist_slot_index()
	return {
		"status": PersistlyGameSaveStatus.LOCAL_SAVED,
		"slotId": slot_id,
		"target": PersistlyGameSaveTarget.SLOT,
	}


func accept_cloud_data() -> Dictionary:
	return accept_cloud_version(DEFAULT_SLOT_KEY)


func overwrite_cloud_data(options: Dictionary = {}) -> Dictionary:
	return overwrite_cloud_version(DEFAULT_SLOT_KEY, options)


func keep_local_data_for_later() -> Dictionary:
	return keep_local_for_later(DEFAULT_SLOT_KEY)


func accept_cloud_version(slot_id: String) -> Dictionary:
	var slot := load_slot(slot_id)
	if slot.get("status", "") == PersistlyGameSaveStatus.NOT_FOUND or slot.has("error"):
		return slot
	if not _slots[slot_id].has("conflict"):
		return _error_result(ERROR_INVALID_REQUEST, "accept_cloud_version requires an active conflict for slot " + slot_id + ".", {
			"slotId": slot_id,
		})

	var conflict: Dictionary = _slots[slot_id]["conflict"]
	var stored: Dictionary = _slots[slot_id]
	if typeof(conflict.get("cloudData", null)) == TYPE_DICTIONARY:
		stored["data"] = (conflict["cloudData"] as Dictionary).duplicate(true)
	if typeof(conflict.get("cloudSlotInfo", null)) == TYPE_DICTIONARY:
		stored["slotInfo"] = (conflict["cloudSlotInfo"] as Dictionary).duplicate(true)
	stored["version"] = int(conflict.get("cloudVersion", stored.get("version", 0)))
	stored["cloudVersion"] = stored["version"]
	stored["cloudData"] = stored.get("data", {}).duplicate(true)
	stored["cloudSlotInfo"] = stored.get("slotInfo", {}).duplicate(true)
	stored["dirty"] = false
	stored["status"] = PersistlyGameSaveStatus.SYNCED
	stored.erase("conflict")
	_slots[slot_id] = stored
	_persist_slot(slot_id)
	return _slot_result(stored, PersistlyGameSaveStatus.SYNCED)


func overwrite_cloud_version(slot_id: String, options: Dictionary = {}) -> Dictionary:
	var slot := load_slot(slot_id)
	if slot.get("status", "") == PersistlyGameSaveStatus.NOT_FOUND or slot.has("error"):
		return slot
	if _slots[slot_id].has("cloudVersion"):
		_slots[slot_id]["version"] = int(_slots[slot_id]["cloudVersion"])
	_slots[slot_id].erase("conflict")
	_slots[slot_id]["dirty"] = true
	return _sync_slot(slot_id, options, true, true)


func keep_local_for_later(slot_id: String) -> Dictionary:
	var slot := load_slot(slot_id)
	if slot.get("status", "") == PersistlyGameSaveStatus.NOT_FOUND or slot.has("error"):
		return slot

	var stored: Dictionary = _slots[slot_id]
	stored["status"] = PersistlyGameSaveStatus.CONFLICT if stored.has("conflict") else PersistlyGameSaveStatus.LOCAL_SAVED
	stored["dirty"] = true
	_slots[slot_id] = stored
	_persist_slot(slot_id)
	return _slot_result(stored, stored["status"])


func _sync_account(options: Dictionary, force: bool) -> Dictionary:
	var preflight := _validate_configured("sync_account")
	if not preflight.is_empty():
		return preflight
	if account_id.is_empty() or account_session_token.is_empty():
		if account_mode == PersistlyAccountMode.AUTH_REQUIRED:
			return _auth_required_result(PersistlyGameSaveTarget.ACCOUNT, "Sign in before syncing account data.")
		return ensure_account()
	if account_version <= 0:
		var restored := _restore_account(_dirty_account)
		if restored.has("error"):
			return restored
	if not _dirty_account:
		return _account_result(PersistlyGameSaveStatus.NO_CHANGES, false)
	if not _can_sync_account(options, force):
		return _account_result(PersistlyGameSaveStatus.COOLDOWN, false)

	var payload: Dictionary = {
		"baseVersion": max(account_version, 1),
		"accountData": account_data.duplicate(true),
	}
	var synced: Dictionary = _client.sync_account_data(account_id, account_session_token, payload)
	if synced.has("error"):
		return _map_remote_error(synced, PersistlyGameSaveTarget.ACCOUNT)
	if synced.get("status", "") == "conflict":
		var result := _record_account_conflict(synced)
		_notify_sync_result(result)
		return result

	_apply_account_save(synced.get("account", {}))
	_dirty_account = false
	_account_last_synced_msec = Time.get_ticks_msec()
	_persist_account()
	var result := _account_result(PersistlyGameSaveStatus.SYNCED, false)
	result["historyRetained"] = bool(synced.get("historyRetained", false))
	if typeof(synced.get("warnings", null)) == TYPE_ARRAY:
		result["warnings"] = (synced["warnings"] as Array).duplicate(true)
	_notify_sync_result(result)
	return result


func _sync_slot(slot_id: String, options: Dictionary, force: bool, overwrite: bool) -> Dictionary:
	var preflight := _validate_configured("sync_slot")
	if not preflight.is_empty():
		return preflight
	var slot_error := _validate_slot_id(slot_id, "sync_slot")
	if not slot_error.is_empty():
		return slot_error
	if not _slots.has(slot_id):
		return load_slot(slot_id)

	var slot: Dictionary = _slots[slot_id]
	if bool(slot.get("archived", false)):
		return _slot_result(slot, PersistlyGameSaveStatus.NOT_FOUND)
	if not bool(slot.get("dirty", false)) and not overwrite:
		return _slot_result(slot, PersistlyGameSaveStatus.NO_CHANGES)
	if not _can_sync_slot(slot, options, force):
		return _slot_result(slot, PersistlyGameSaveStatus.COOLDOWN)

	if account_id.is_empty() or account_session_token.is_empty():
		if account_mode == PersistlyAccountMode.AUTH_REQUIRED:
			return _auth_required_result(PersistlyGameSaveTarget.SLOT, "Sign in before syncing cloud save data.", {
				"slotId": slot_id,
			})
		var first_sync_result := _create_account_with_first_slot(slot_id, slot)
		if first_sync_result.has("error") or first_sync_result.get("status", "") == PersistlyGameSaveStatus.SYNCED:
			return first_sync_result

	var response: Dictionary
	if int(slot.get("version", 0)) <= 0:
		response = _client.create_account_slot(account_id, account_session_token, {
			"slotId": slot_id,
			"slotInfo": slot.get("slotInfo", {}),
			"data": slot.get("data", {}),
		})
		if response.has("error"):
			var error = response.get("error", {})
			if typeof(error) == TYPE_DICTIONARY and String(error.get("code", "")) == CLIENT_SCRIPT.ERROR_SLOT_ALREADY_EXISTS:
				var recovered := _recover_existing_remote_slot(slot_id)
				if recovered.has("error"):
					return recovered
				return _sync_slot(slot_id, options, true, overwrite)
			return _map_remote_error(response, PersistlyGameSaveTarget.SLOT, slot_id)
		_apply_account_response(response, false)
		if response.has("slot"):
			_apply_slot_save_to_slot(slot_id, response["slot"])
		return _finalize_synced_slot(slot_id)

	response = _client.sync_account_slot(account_id, account_session_token, slot_id, {
		"baseVersion": max(int(slot.get("version", 0)), 1),
		"slotInfo": slot.get("slotInfo", {}),
		"data": slot.get("data", {}),
	})
	if response.has("error"):
		return _map_remote_error(response, PersistlyGameSaveTarget.SLOT, slot_id)
	if response.get("status", "") == "conflict":
		var conflict_result := _record_slot_conflict(slot_id, response)
		_notify_sync_result(conflict_result)
		return conflict_result

	_apply_slot_save_to_slot(slot_id, response.get("slot", {}))
	return _finalize_synced_slot(slot_id, response)


func _recover_existing_remote_slot(slot_id: String) -> Dictionary:
	var restored := _restore_account(true)
	if restored.has("error"):
		return restored
	var slot: Dictionary = _slots.get(slot_id, {})
	if int(slot.get("version", 0)) <= 0:
		return _error_result(ERROR_STORAGE, "Persistly could not reconcile remote slot " + slot_id + " after duplicate slot response.")

	var loaded: Dictionary = _client.load_account_slot(account_id, account_session_token, slot_id)
	if loaded.has("error"):
		return _map_remote_error(loaded, PersistlyGameSaveTarget.SLOT, slot_id)
	_apply_slot_save_to_slot(slot_id, loaded.get("slot", loaded))
	_persist_slot(slot_id)
	return {}


func _create_account_with_first_slot(slot_id: String, slot: Dictionary) -> Dictionary:
	if account_mode == PersistlyAccountMode.AUTH_REQUIRED:
		return _auth_required_result(PersistlyGameSaveTarget.SLOT, "Sign in before syncing cloud save data.", {
			"slotId": slot_id,
		})
	var payload: Dictionary = {
		"accountData": account_data.duplicate(true),
		"slot": {
			"slotId": slot_id,
			"slotInfo": slot.get("slotInfo", {}),
			"data": slot.get("data", {}),
		},
	}
	if typeof(player_ref) == TYPE_STRING:
		payload["playerRef"] = player_ref
	if typeof(external_account_ref) == TYPE_DICTIONARY:
		payload["externalAccountRef"] = (external_account_ref as Dictionary).duplicate(true)

	var created: Dictionary = _client.create_account(payload)
	if created.has("error"):
		return _map_remote_error(created, PersistlyGameSaveTarget.SLOT, slot_id)

	_apply_account_response(created, true)
	if created.has("slot"):
		_apply_slot_save_to_slot(slot_id, created["slot"])
	_dirty_account = false
	_account_last_synced_msec = Time.get_ticks_msec()
	_persist_account()
	return _finalize_synced_slot(slot_id)


func _exchange_provider_session(input: Dictionary, current_session_token: String = "", current_account_id: String = "") -> Dictionary:
	if typeof(input) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "Auth provider input must be a dictionary.")
	var session: Dictionary = _client.create_auth_session(input, current_session_token, current_account_id)
	if session.has("error"):
		return _map_remote_error(session, PersistlyGameSaveTarget.ACCOUNT)

	_apply_account_response(session, true)
	_dirty_account = false
	_account_last_synced_msec = Time.get_ticks_msec()
	_persist_account()

	var result := _account_result(PersistlyGameSaveStatus.SYNCED, false)
	result["accountId"] = account_id
	result["linkedProvider"] = String(session.get("linkedProvider", ""))
	result["isNewAccount"] = bool(session.get("isNewAccount", false))
	result["wasProviderNewForAccount"] = bool(session.get("wasProviderNewForAccount", false))
	if session.has("account"):
		result["account"] = _duplicate_dictionary(session["account"])
	if session.has("slot"):
		result["slot"] = _duplicate_dictionary(session["slot"])
	_notify_sync_result(result)
	return result


func _finalize_synced_slot(slot_id: String, sync_response: Dictionary = {}) -> Dictionary:
	var slot: Dictionary = _slots[slot_id]
	slot["dirty"] = false
	slot["status"] = PersistlyGameSaveStatus.SYNCED
	slot["lastSyncedMsec"] = Time.get_ticks_msec()
	slot["lastSyncedAtUnix"] = Time.get_unix_time_from_system()
	slot.erase("conflict")
	_slots[slot_id] = slot
	_persist_slot(slot_id)
	_persist_slot_index()
	var result := _slot_result(slot, PersistlyGameSaveStatus.SYNCED)
	result["target"] = PersistlyGameSaveTarget.SLOT
	if not sync_response.is_empty():
		result["historyRetained"] = bool(sync_response.get("historyRetained", false))
		if typeof(sync_response.get("warnings", null)) == TYPE_ARRAY:
			result["warnings"] = (sync_response["warnings"] as Array).duplicate(true)
	_notify_sync_result(result)
	return result


func _record_account_conflict(response: Dictionary) -> Dictionary:
	var cloud_account: Dictionary = response.get("account", {})
	var result := _account_result(PersistlyGameSaveStatus.CONFLICT, true)
	result["reason"] = response.get("details", {}).get("reason", "base_version_mismatch")
	result["localAccountData"] = account_data.duplicate(true)
	result["cloudAccountData"] = _duplicate_dictionary(cloud_account.get("accountData", {}))
	result["localVersion"] = account_version
	result["cloudVersion"] = int(cloud_account.get("version", 0))
	result["localUpdatedAtUnix"] = _account_updated_at_unix
	result["cloudUpdatedAt"] = String(cloud_account.get("updatedAt", ""))
	result["cloudAccount"] = cloud_account.duplicate(true)
	return result


func _record_slot_conflict(slot_id: String, response: Dictionary) -> Dictionary:
	var cloud_slot: Dictionary = response.get("slot", {})
	var stored: Dictionary = _slots[slot_id]
	var cloud_slot_info := _duplicate_dictionary(cloud_slot.get("slotInfo", {}))
	stored["cloudData"] = cloud_slot.get("data", {}).duplicate(true)
	stored["cloudSlotInfo"] = cloud_slot_info
	stored["cloudVersion"] = int(cloud_slot.get("version", 0))
	stored["cloudUpdatedAt"] = String(cloud_slot.get("updatedAt", ""))
	stored["dirty"] = true
	stored["status"] = PersistlyGameSaveStatus.CONFLICT
	stored["conflict"] = {
		"reason": response.get("details", {}).get("reason", "base_version_mismatch"),
		"localData": stored.get("data", {}).duplicate(true),
		"localSlotInfo": stored.get("slotInfo", {}).duplicate(true),
		"localVersion": int(stored.get("version", 0)),
		"cloudData": stored["cloudData"].duplicate(true),
		"cloudSlotInfo": cloud_slot_info.duplicate(true),
		"cloudVersion": stored["cloudVersion"],
		"cloudUpdatedAt": stored["cloudUpdatedAt"],
	}
	_slots[slot_id] = stored
	_persist_slot(slot_id)

	var result := _slot_result(stored, PersistlyGameSaveStatus.CONFLICT)
	result["target"] = PersistlyGameSaveTarget.SLOT
	result["localData"] = stored["conflict"]["localData"].duplicate(true)
	result["localSlotInfo"] = stored["conflict"]["localSlotInfo"].duplicate(true)
	result["cloudData"] = stored["conflict"]["cloudData"].duplicate(true)
	result["cloudSlotInfo"] = stored["conflict"]["cloudSlotInfo"].duplicate(true)
	result["cloudVersion"] = stored["cloudVersion"]
	return result


func _apply_account_response(response: Dictionary, include_token: bool) -> void:
	if response.has("accountId"):
		account_id = String(response["accountId"])
	if include_token and response.has("accountSessionToken"):
		account_session_token = String(response["accountSessionToken"])
	if response.has("syncPolicy") and typeof(response["syncPolicy"]) == TYPE_DICTIONARY:
		sync_policy = (response["syncPolicy"] as Dictionary).duplicate(true)
	if response.has("account"):
		_apply_account_save(response["account"])
	if response.has("slot"):
		var slot: Dictionary = response["slot"]
		var slot_id := String(slot.get("slotId", ""))
		if not slot_id.is_empty():
			_apply_slot_save_to_slot(slot_id, slot)
	_persist_account()


func _restore_account(preserve_local_dirty: bool = false) -> Dictionary:
	var local_account_data := account_data.duplicate(true)
	var local_dirty := _dirty_account
	var loaded: Dictionary = _client.load_account(account_id, account_session_token)
	if loaded.has("error"):
		return _map_remote_error(loaded, PersistlyGameSaveTarget.ACCOUNT)
	_apply_account_response(loaded, false)
	if preserve_local_dirty and local_dirty:
		account_data = local_account_data
	_dirty_account = preserve_local_dirty and local_dirty
	_account_last_synced_msec = Time.get_ticks_msec()
	_persist_account()
	return _account_result(PersistlyGameSaveStatus.SYNCED, false)


func _apply_account_save(account: Dictionary) -> void:
	if account.is_empty():
		return
	account_id = String(account.get("accountId", account_id))
	account_version = int(account.get("version", account_version))
	account_data = _duplicate_dictionary(account.get("accountData", account_data))
	var slots = account.get("slots", [])
	if typeof(slots) == TYPE_ARRAY:
		_apply_slot_refs(slots)
	_account_updated_at_unix = Time.get_unix_time_from_system()


func _apply_slot_refs(slots: Array) -> void:
	for slot_ref in slots:
		if typeof(slot_ref) != TYPE_DICTIONARY:
			continue
		var slot_id := String(slot_ref.get("slotId", ""))
		if slot_id.is_empty():
			continue
		var slot: Dictionary = _slots.get(slot_id, {
			"slotId": slot_id,
			"data": {},
			"slotInfo": {},
			"dirty": false,
			"version": 0,
		})
		slot["version"] = int(slot_ref.get("version", slot.get("version", 0)))
		if typeof(slot_ref.get("slotInfo", null)) == TYPE_DICTIONARY and slot.get("slotInfo", {}).is_empty():
			slot["slotInfo"] = (slot_ref["slotInfo"] as Dictionary).duplicate(true)
		slot["archived"] = bool(slot_ref.get("archived", false))
		if slot_ref.has("archivedAt"):
			slot["archivedAt"] = String(slot_ref["archivedAt"])
		_slots[slot_id] = slot
		_persist_slot(slot_id)
	_persist_slot_index()


func _apply_slot_save_to_slot(slot_id: String, remote_slot: Dictionary) -> void:
	if remote_slot.is_empty():
		return
	var slot: Dictionary = _slots.get(slot_id, {
		"slotId": slot_id,
		"data": {},
		"slotInfo": {},
	})
	slot["slotId"] = String(remote_slot.get("slotId", slot_id))
	slot["version"] = int(remote_slot.get("version", slot.get("version", 0)))
	slot["cloudVersion"] = slot["version"]
	slot["cloudData"] = _duplicate_dictionary(remote_slot.get("data", {}))
	slot["cloudSlotInfo"] = _duplicate_dictionary(remote_slot.get("slotInfo", {}))
	slot["cloudUpdatedAt"] = String(remote_slot.get("updatedAt", ""))
	slot["archived"] = false
	if slot.get("data", {}).is_empty():
		slot["data"] = slot["cloudData"].duplicate(true)
	if slot.get("slotInfo", {}).is_empty():
		slot["slotInfo"] = slot["cloudSlotInfo"].duplicate(true)
	_slots[slot_id] = slot


func _slot_result(slot: Dictionary, status: String) -> Dictionary:
	var result := _duplicate_dictionary(slot)
	result["status"] = status
	result["target"] = PersistlyGameSaveTarget.SLOT
	result["found"] = status != PersistlyGameSaveStatus.NOT_FOUND
	return result


func _account_result(status: String, include_token: bool) -> Dictionary:
	var result := {
		"status": status,
		"target": PersistlyGameSaveTarget.ACCOUNT,
		"accountId": account_id,
		"localAccountKey": local_account_key,
		"accountData": account_data.duplicate(true),
		"version": account_version,
		"dirty": _dirty_account,
	}
	if include_token:
		result["accountSessionToken"] = account_session_token
	return result


func _can_sync_account(options: Dictionary, force: bool) -> bool:
	if bool(options.get("bypassCooldown", options.get("bypass_cooldown", false))):
		return true
	if _account_last_synced_msec == 0:
		return true
	var elapsed_seconds := float(Time.get_ticks_msec() - _account_last_synced_msec) / 1000.0
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
		_persist_account()
	return config


func _map_remote_error(remote_error: Dictionary, target: String, slot_id: String = "") -> Dictionary:
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
	if not slot_id.is_empty():
		result["slotId"] = slot_id
	return result


func _auth_required_result(target: String, message: String, details: Dictionary = {}) -> Dictionary:
	var result := _error_result(ERROR_AUTH_REQUIRED, message, details)
	result["target"] = target
	return result


func _ensure_no_existing_local_account_state(message: String) -> Dictionary:
	if not _is_blank_local_account_state() or not _slots.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, message)
	return {}


func _is_blank_local_account_state() -> bool:
	return account_id.is_empty() \
		and account_session_token.is_empty() \
		and account_data.is_empty() \
		and not _dirty_account \
		and account_version == 0


func _notify_sync_result(result: Dictionary) -> void:
	if _on_sync_result.is_valid():
		_on_sync_result.call(result.duplicate(true))


func _load_local_records() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(_account_root)
	DirAccess.make_dir_recursive_absolute(_slots_root())
	_load_account_record()
	return _load_slot_records()


func _load_account_record() -> void:
	var path := _account_path()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var record: Dictionary = parsed
	if record.get("schema", "") != ACCOUNT_SCHEMA:
		return
	account_id = String(record.get("accountId", account_id))
	account_session_token = String(record.get("accountSessionToken", account_session_token))
	account_data = _duplicate_dictionary(record.get("accountData", {}))
	account_version = int(record.get("version", 0))
	_dirty_account = bool(record.get("dirty", false))
	_account_last_synced_msec = int(record.get("lastSyncedMsec", 0))
	_account_updated_at_unix = float(record.get("updatedAtUnix", 0.0))
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
	var slot_ids = index_record.get("slots", [])
	if typeof(slot_ids) != TYPE_ARRAY:
		return _error_result(ERROR_STORAGE, "Persistly slot index slots must be an array.")
	for key in slot_ids:
		var slot_id := String(key)
		var slot_path := _slot_path(slot_id)
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
			_slots[slot_id] = (slot as Dictionary).duplicate(true)
	return {}


func _persist_account() -> void:
	if _account_root.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_account_root)
	var record := {
		"schema": ACCOUNT_SCHEMA,
		"accountId": account_id,
		"accountSessionToken": account_session_token,
		"playerRef": player_ref,
		"externalAccountRef": external_account_ref,
		"accountData": account_data.duplicate(true),
		"version": account_version,
		"syncPolicy": sync_policy.duplicate(true),
		"dirty": _dirty_account,
		"lastSyncedMsec": _account_last_synced_msec,
		"updatedAtUnix": _account_updated_at_unix,
	}
	_write_json(_account_path(), record)


func _persist_slot(slot_id: String) -> void:
	if _account_root.is_empty() or not _slots.has(slot_id):
		return
	DirAccess.make_dir_recursive_absolute(_slots_root())
	_write_json(_slot_path(slot_id), {
		"schema": SLOT_SCHEMA,
		"slot": _slots[slot_id],
	})


func _persist_slot_index() -> void:
	if _account_root.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_account_root)
	var keys := _slots.keys()
	keys.sort()
	_write_json(_slot_index_path(), {
		"schema": SLOT_INDEX_SCHEMA,
		"slots": keys,
	})


func _remove_slot_file(slot_id: String) -> void:
	var path := _slot_path(slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value))
		file.close()


func _account_path() -> String:
	return _account_root.path_join("account.json")


func _slot_index_path() -> String:
	return _account_root.path_join("slot_index.json")


func _slots_root() -> String:
	return _account_root.path_join("slots")


func _slot_path(slot_id: String) -> String:
	return _slots_root().path_join(slot_id.uri_encode() + ".json")


func _resolve_local_account_key() -> String:
	if typeof(external_account_ref) == TYPE_DICTIONARY:
		var provider := String((external_account_ref as Dictionary).get("provider", "")).strip_edges()
		var subject := String((external_account_ref as Dictionary).get("subject", "")).strip_edges()
		if not provider.is_empty() and not subject.is_empty():
			return provider + ":" + subject
	if typeof(player_ref) == TYPE_STRING and not String(player_ref).strip_edges().is_empty():
		return String(player_ref).strip_edges()
	return _load_or_create_anonymous_key()


func _load_or_create_anonymous_key() -> String:
	DirAccess.make_dir_recursive_absolute(_storage_path)
	var path := _storage_path.path_join("anonymous_account_key.txt")
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


func _validate_slot_id(slot_id: String, action: String) -> Dictionary:
	if not CLIENT_SCRIPT.new()._is_valid_slot_id(slot_id):
		return _error_result(ERROR_INVALID_REQUEST, action + " requires slot_id matching ^[A-Za-z0-9_.-]{1,64}$.", {
			"slotId": slot_id,
		})
	return {}


func _validate_developer_slot_info(slot_info: Dictionary, action: String) -> Dictionary:
	if slot_info.has("_persistly"):
		return _error_result(ERROR_INVALID_REQUEST, action + " slotInfo must not contain reserved _persistly fields.")
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
	const AUTH_REQUIRED := "auth_required"


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
	const AUTH_REQUIRED := "auth_required"


class PersistlyGameSaveTarget:
	const ACCOUNT := "account"
	const SLOT := "slot"


class PersistlyAccountMode:
	const ANONYMOUS_FIRST := "anonymousFirst"
	const AUTH_REQUIRED := "authRequired"
