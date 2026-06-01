extends RefCounted
class_name PersistlyClient

const SDK_VERSION := "1.0.0"
const BUNDLE_VERSION := "persistly-contract-v0.4.0"
const BUNDLE_ROOT := "res://contracts/persistly-contract-v0.4.0"
const PERSISTLY_API_ORIGIN := "https://api.persistly.app"
const DEFAULT_TIMEOUT_SECONDS := 30.0
const METADATA_MAX_BYTES := 16384
const STATE_MAX_BYTES := 262144

const ERROR_INVALID_REQUEST := "invalid_request"
const ERROR_UNAUTHORIZED := "unauthorized"
const ERROR_FORBIDDEN := "forbidden"
const ERROR_NOT_FOUND := "not_found"
const ERROR_CONFLICT := "conflict"
const ERROR_SLOT_ALREADY_EXISTS := "slot_already_exists"
const ERROR_SLOT_ARCHIVED := "slot_archived"
const ERROR_ACCOUNT_DELETED := "account_deleted"
const ERROR_SLOT_DELETED := "slot_deleted"
const ERROR_RATE_LIMITED := "rate_limited"
const ERROR_MONTHLY_QUOTA_EXCEEDED := "monthly_quota_exceeded"
const ERROR_PAYLOAD_TOO_LARGE := "payload_too_large"
const ERROR_SERVER := "server_error"

var _api_origin: String = PERSISTLY_API_ORIGIN
var runtime_key: String
var timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS

var _save_cache: Dictionary = {}
var _fixture_responses: Dictionary = {}
var _recorded_requests: Array = []


func _init(runtime_key_value: String = "", timeout_seconds_value: float = DEFAULT_TIMEOUT_SECONDS) -> void:
	runtime_key = runtime_key_value
	timeout_seconds = max(timeout_seconds_value, 1.0)


func configure_runtime_key(runtime_key_value: String, timeout_seconds_value: float = DEFAULT_TIMEOUT_SECONDS) -> void:
	runtime_key = runtime_key_value
	timeout_seconds = max(timeout_seconds_value, 1.0)


func create_save(payload: Dictionary) -> Dictionary:
	var preflight := _validate_runtime_configuration("create_save")
	if not preflight.is_empty():
		return preflight

	if typeof(payload.get("state", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_save requires a dictionary state payload.")

	var metadata := payload.get("metadata", {})
	if typeof(metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_save metadata must be a dictionary when provided.")

	var request_body: Dictionary = {
		"state": payload["state"],
		"metadata": metadata,
	}
	var payload_error := _validate_payload_sizes(metadata, payload["state"])
	if not payload_error.is_empty():
		return payload_error

	if payload.has("playerRef"):
		var player_ref = payload.get("playerRef")
		if not (typeof(player_ref) == TYPE_STRING or player_ref == null):
			return _error_result(ERROR_INVALID_REQUEST, "playerRef must be a string or null.")
		request_body["playerRef"] = player_ref

	var response := _request_json("POST", "/api/v1/saves", request_body)
	if response.has("error"):
		return response

	return _normalize_save_envelope(response, true)


func load_save(save_id: String) -> Dictionary:
	var preflight := _validate_runtime_configuration("load_save")
	if not preflight.is_empty():
		return preflight

	if save_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "load_save requires a non-empty save_id.")

	var response := _request_json("GET", "/api/v1/saves/" + _url_encode(save_id))
	if response.has("error"):
		return response

	return _normalize_save_envelope(response, true)


func sync_save(save_id: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_runtime_configuration("sync_save")
	if not preflight.is_empty():
		return preflight

	if save_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "sync_save requires a non-empty save_id.")

	if typeof(payload.get("state", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "sync_save requires a dictionary state payload.")

	var metadata := payload.get("metadata", {})
	if typeof(metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "sync_save metadata must be a dictionary when provided.")

	var base_version = payload.get("baseVersion", null)
	if base_version == null and _save_cache.has(save_id):
		base_version = int(_save_cache[save_id].get("version", 0))
	if base_version == null:
		return _error_result(ERROR_INVALID_REQUEST, "sync_save requires baseVersion unless the save is already cached.")
	if typeof(base_version) != TYPE_INT:
		return _error_result(ERROR_INVALID_REQUEST, "sync_save baseVersion must be an integer.")

	var request_body := {
		"baseVersion": base_version,
		"metadata": metadata,
		"state": payload["state"],
	}
	var payload_error := _validate_payload_sizes(metadata, payload["state"])
	if not payload_error.is_empty():
		return payload_error

	var response := _request_json("POST", "/api/v1/saves/" + _url_encode(save_id) + "/sync", request_body)
	if response.has("error"):
		return response

	return _normalize_sync_response(response, true, "sync_save", save_id, metadata, payload["state"])


func create_account(payload: Dictionary = {}) -> Dictionary:
	var preflight := _validate_runtime_configuration("create_account")
	if not preflight.is_empty():
		return preflight

	var account_data := payload.get("accountData", {})
	if typeof(account_data) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_account accountData must be a dictionary.")

	var account_payload_error := _validate_payload_sizes({}, account_data)
	if not account_payload_error.is_empty():
		return account_payload_error

	var request_body: Dictionary = {
		"accountData": account_data,
	}
	if payload.has("playerRef"):
		var player_ref = payload.get("playerRef")
		if not (typeof(player_ref) == TYPE_STRING or player_ref == null):
			return _error_result(ERROR_INVALID_REQUEST, "playerRef must be a string or null.")
		request_body["playerRef"] = player_ref
	if payload.has("externalAccountRef"):
		var external_account_ref = payload.get("externalAccountRef")
		if not (typeof(external_account_ref) == TYPE_DICTIONARY or external_account_ref == null):
			return _error_result(ERROR_INVALID_REQUEST, "externalAccountRef must be a dictionary or null.")
		request_body["externalAccountRef"] = external_account_ref

	var slot = payload.get("slot", null)
	if slot != null:
		if typeof(slot) != TYPE_DICTIONARY:
			return _error_result(ERROR_INVALID_REQUEST, "create_account slot must be a dictionary when provided.")
		var slot_request := _normalize_slot_request(slot, "create_account")
		if slot_request.has("error"):
			return slot_request
		request_body["slot"] = slot_request

	var response := _request_json("POST", "/api/v1/accounts", request_body)
	if response.has("error"):
		return response

	return _normalize_account_response(response, true, true)


func load_account(account_id: String, account_session_token: String) -> Dictionary:
	var preflight := _validate_account_session_configuration("load_account", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight

	var response := _request_json(
		"GET",
		"/api/v1/accounts/" + _url_encode(account_id),
		null,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_account_response(response, true, false)


func delete_account(account_id: String, account_session_token: String) -> Dictionary:
	var preflight := _validate_account_session_configuration("delete_account", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight

	var response := _request_json(
		"DELETE",
		"/api/v1/accounts/" + _url_encode(account_id),
		null,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_delete_account_response(response, account_id)


func sync_account_data(account_id: String, account_session_token: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_account_session_configuration("sync_account_data", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight

	if payload.has("slots"):
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_data cannot rewrite account slot refs.")

	var base_version = payload.get("baseVersion", null)
	if base_version == null and _save_cache.has(account_id):
		base_version = int(_save_cache[account_id].get("version", 0))
	if base_version == null:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_data requires baseVersion unless the account is already cached.")
	if typeof(base_version) != TYPE_INT:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_data baseVersion must be an integer.")

	var has_account_data := payload.has("accountData")
	var has_account_data_patch := payload.has("accountDataPatch")
	if has_account_data and has_account_data_patch:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_data accepts accountData or accountDataPatch, not both.")
	if not has_account_data and not has_account_data_patch:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_data requires accountData or accountDataPatch.")

	var request_body: Dictionary = {
		"baseVersion": base_version,
	}
	if has_account_data:
		var account_data = payload["accountData"]
		if typeof(account_data) != TYPE_DICTIONARY:
			return _error_result(ERROR_INVALID_REQUEST, "sync_account_data accountData must be a dictionary.")
		var payload_error := _validate_payload_sizes({}, account_data)
		if not payload_error.is_empty():
			return payload_error
		request_body["accountData"] = account_data
	if has_account_data_patch:
		var account_data_patch = payload["accountDataPatch"]
		if typeof(account_data_patch) != TYPE_DICTIONARY:
			return _error_result(ERROR_INVALID_REQUEST, "sync_account_data accountDataPatch must be a dictionary.")
		var patch_error := _validate_payload_sizes({}, account_data_patch)
		if not patch_error.is_empty():
			return patch_error
		request_body["accountDataPatch"] = account_data_patch
	var response := _request_json(
		"POST",
		"/api/v1/accounts/" + _url_encode(account_id) + "/data/sync",
		request_body,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_account_sync_response(response, true, "sync_account_data", account_id, request_body)


func create_transfer_code(account_id: String, account_session_token: String, options: Dictionary = {}) -> Dictionary:
	var preflight := _validate_account_session_configuration("create_transfer_code", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight
	if typeof(options) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_transfer_code options must be a dictionary.")

	var request_body: Dictionary = {}
	if options.has("deviceLabel") or options.has("device_label"):
		var device_label = options.get("deviceLabel", options.get("device_label", null))
		if not (typeof(device_label) == TYPE_STRING or device_label == null):
			return _error_result(ERROR_INVALID_REQUEST, "create_transfer_code deviceLabel must be a string or null.")
		if typeof(device_label) == TYPE_STRING and not String(device_label).strip_edges().is_empty():
			request_body["deviceLabel"] = String(device_label).strip_edges()
	if options.has("ttlSeconds") or options.has("ttl_seconds"):
		var ttl_seconds = options.get("ttlSeconds", options.get("ttl_seconds", null))
		if not (typeof(ttl_seconds) == TYPE_INT or typeof(ttl_seconds) == TYPE_FLOAT):
			return _error_result(ERROR_INVALID_REQUEST, "create_transfer_code ttlSeconds must be a number.")
		request_body["ttlSeconds"] = int(ttl_seconds)

	var response := _request_json(
		"POST",
		"/api/v1/accounts/" + _url_encode(account_id) + "/transfer-codes",
		request_body,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_transfer_code_response(response)


func consume_transfer_code(transfer_code: String, options: Dictionary = {}) -> Dictionary:
	var preflight := _validate_runtime_configuration("consume_transfer_code")
	if not preflight.is_empty():
		return preflight
	if transfer_code.strip_edges().is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "consume_transfer_code requires a non-empty transfer_code.")
	if typeof(options) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "consume_transfer_code options must be a dictionary.")

	var request_body: Dictionary = {
		"transferCode": transfer_code.strip_edges(),
	}
	if options.has("deviceLabel") or options.has("device_label"):
		var device_label = options.get("deviceLabel", options.get("device_label", null))
		if not (typeof(device_label) == TYPE_STRING or device_label == null):
			return _error_result(ERROR_INVALID_REQUEST, "consume_transfer_code deviceLabel must be a string or null.")
		if typeof(device_label) == TYPE_STRING and not String(device_label).strip_edges().is_empty():
			request_body["deviceLabel"] = String(device_label).strip_edges()

	var response := _request_json("POST", "/api/v1/account-transfer-codes/consume", request_body)
	if response.has("error"):
		return response

	return _normalize_account_response(response, true, true)


func create_account_slot(account_id: String, account_session_token: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_account_session_configuration("create_account_slot", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight

	var slot_request := _normalize_slot_request(payload, "create_account_slot")
	if slot_request.has("error"):
		return slot_request

	var response := _request_json(
		"POST",
		"/api/v1/accounts/" + _url_encode(account_id) + "/slots",
		slot_request,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_account_response(response, true, false)


func load_account_slot(account_id: String, account_session_token: String, slot_id: String) -> Dictionary:
	var preflight := _validate_account_session_configuration("load_account_slot", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight
	if slot_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "load_account_slot requires a non-empty slot_id.")

	var response := _request_json(
		"GET",
		"/api/v1/accounts/" + _url_encode(account_id) + "/slots/" + _url_encode(slot_id),
		null,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_slot_envelope(response, true)


func delete_account_slot(account_id: String, account_session_token: String, slot_id: String) -> Dictionary:
	var preflight := _validate_account_session_configuration("delete_account_slot", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight
	if slot_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "delete_account_slot requires a non-empty slot_id.")

	var response := _request_json(
		"DELETE",
		"/api/v1/accounts/" + _url_encode(account_id) + "/slots/" + _url_encode(slot_id),
		null,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_delete_account_slot_response(response, slot_id)


func sync_account_slot(account_id: String, account_session_token: String, slot_id: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_account_session_configuration("sync_account_slot", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight
	if slot_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_slot requires a non-empty slot_id.")

	if typeof(payload.get("data", payload.get("state", null))) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_slot requires a dictionary data payload.")

	var slot_info := payload.get("slotInfo", payload.get("metadata", {}))
	if typeof(slot_info) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_slot slotInfo must be a dictionary when provided.")

	var base_version = payload.get("baseVersion", null)
	if base_version == null and _save_cache.has(slot_id):
		base_version = int(_save_cache[slot_id].get("version", 0))
	if base_version == null:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_slot requires baseVersion unless the slot save is already cached.")
	if typeof(base_version) != TYPE_INT:
		return _error_result(ERROR_INVALID_REQUEST, "sync_account_slot baseVersion must be an integer.")

	var data: Dictionary = payload.get("data", payload.get("state", {}))
	var payload_error := _validate_payload_sizes(slot_info, data)
	if not payload_error.is_empty():
		return payload_error

	var response := _request_json(
		"POST",
		"/api/v1/accounts/" + _url_encode(account_id) + "/slots/" + _url_encode(slot_id) + "/sync",
		{
			"baseVersion": base_version,
			"slotInfo": slot_info,
			"data": data,
		},
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_slot_sync_response(response, true, "sync_account_slot", slot_id, slot_info, data)


func archive_account_slot(account_id: String, account_session_token: String, slot_id: String) -> Dictionary:
	var preflight := _validate_account_session_configuration("archive_account_slot", account_id, account_session_token)
	if not preflight.is_empty():
		return preflight
	if slot_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "archive_account_slot requires a non-empty slot_id.")

	var response := _request_json(
		"POST",
		"/api/v1/accounts/" + _url_encode(account_id) + "/slots/" + _url_encode(slot_id) + "/archive",
		null,
		account_session_token)
	if response.has("error"):
		return response

	return _normalize_account_response(response, true, false)


func get_runtime_config(game_config_version: int = -1) -> Dictionary:
	var preflight := _validate_runtime_configuration("get_runtime_config")
	if not preflight.is_empty():
		return preflight
	if game_config_version < -1:
		return _error_result(ERROR_INVALID_REQUEST, "get_runtime_config game_config_version must be a non-negative integer.")

	var path := "/api/v1/runtime-config"
	if game_config_version >= 0:
		path += "?gameConfigVersion=" + str(game_config_version)

	var response := _request_json("GET", path)
	if response.has("error"):
		return response
	if typeof(response.get("syncPolicy", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "get_runtime_config response is missing syncPolicy.")
	return response


func get_cached_save(save_id: String) -> Dictionary:
	if _save_cache.has(save_id):
		return _duplicate_dictionary(_save_cache[save_id])
	return {}


func clear_cached_save(save_id: String) -> void:
	_save_cache.erase(save_id)


func register_fixture_response(method: String, path: String, status_code: int, body: Variant) -> void:
	var key := _fixture_key(method, path)
	if not _fixture_responses.has(key):
		_fixture_responses[key] = []

	var response_body := body
	if typeof(body) == TYPE_DICTIONARY or typeof(body) == TYPE_ARRAY:
		response_body = JSON.stringify(body)

	_fixture_responses[key].append({
		"status_code": status_code,
		"body": String(response_body),
	})


func get_recorded_requests() -> Array:
	return _recorded_requests.duplicate(true)


func clear_recorded_requests() -> void:
	_recorded_requests.clear()


func _normalize_slot_request(payload: Dictionary, action: String) -> Dictionary:
	var slot_id := String(payload.get("slotId", ""))
	if slot_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, action + " requires slotId.")
	if not _is_valid_slot_id(slot_id):
		return _error_result(ERROR_INVALID_REQUEST, action + " slotId must match ^[A-Za-z0-9_.-]{1,64}$.", {
			"slotId": slot_id,
		})

	var slot_info := payload.get("slotInfo", payload.get("metadata", {}))
	var data = payload.get("data", payload.get("state", null))
	if typeof(slot_info) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, action + " slotInfo must be a dictionary.")
	if typeof(data) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, action + " requires a dictionary data payload.")

	var payload_error := _validate_payload_sizes(slot_info, data)
	if not payload_error.is_empty():
		return payload_error
	return {
		"slotId": slot_id,
		"slotInfo": slot_info,
		"data": data,
	}


func _validate_slot_metadata(metadata: Dictionary, action: String) -> Dictionary:
	if metadata.has("_persistly"):
		return _error_result(ERROR_INVALID_REQUEST, action + " slotInfo must not contain reserved _persistly fields.")
	return {}


func _is_valid_slot_id(slot_id: String) -> bool:
	if slot_id.length() < 1 or slot_id.length() > 64:
		return false
	for index in range(slot_id.length()):
		var code := slot_id.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_symbol := code == 45 or code == 46 or code == 95
		if not (is_digit or is_upper or is_lower or is_symbol):
			return false
	return true


func _validate_runtime_configuration(action: String) -> Dictionary:
	if _api_origin.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "PersistlyClient requires an API origin before calling " + action + ".")
	if runtime_key.is_empty():
		return _error_result(ERROR_UNAUTHORIZED, "PersistlyClient requires runtime_key before calling " + action + ".")
	return {}


func _validate_account_session_configuration(action: String, account_id: String, account_session_token: String) -> Dictionary:
	var preflight := _validate_runtime_configuration(action)
	if not preflight.is_empty():
		return preflight
	if account_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, action + " requires a non-empty account_id.")
	if account_session_token.is_empty():
		return _error_result(ERROR_FORBIDDEN, action + " requires a non-empty account_session_token.")
	return {}


func _request_json(method: String, path: String, body: Variant = null, account_session_token: String = "") -> Dictionary:
	var headers := _request_headers(account_session_token)
	_record_request(method, path, body, account_session_token, headers)
	var fixture := _pop_fixture_response(method, path)
	if not fixture.is_empty():
		return _parse_transport_response(int(fixture.get("status_code", 500)), String(fixture.get("body", "")))

	var url_parts := _parse_api_origin()
	if url_parts.has("error"):
		return url_parts

	var client := HTTPClient.new()
	var use_tls := bool(url_parts.get("use_tls", false))
	var host := String(url_parts.get("host", ""))
	var port := int(url_parts.get("port", 0))
	var tls_options: TLSOptions = TLSOptions.client() if use_tls else null
	var connect_error := client.connect_to_host(host, port, tls_options)
	if connect_error != OK:
		return _error_result(ERROR_SERVER, "Persistly transport could not connect to the runtime API.", {
			"godotError": connect_error,
		})

	var wait_error := _wait_for_connection(client)
	if wait_error != OK:
		client.close()
		return _error_result(ERROR_SERVER, "Persistly transport timed out while connecting.", {
			"godotError": wait_error,
		})

	var request_path := String(url_parts.get("base_path", "")) + path
	var request_body := ""
	if body != null:
		request_body = JSON.stringify(body)

	var request_error := client.request(_http_method(method), request_path, headers, request_body)
	if request_error != OK:
		client.close()
		return _error_result(ERROR_SERVER, "Persistly transport could not send the request.", {
			"godotError": request_error,
		})

	var response := _read_response(client)
	client.close()
	return response


func _request_headers(account_session_token: String) -> PackedStringArray:
	var headers := PackedStringArray([
		"Authorization: Bearer " + runtime_key,
		"Content-Type: application/json",
		"Accept: application/json",
		"User-Agent: PersistlyGodotSDK/" + SDK_VERSION,
		"X-Persistly-SDK: godot",
		"X-Persistly-SDK-Version: " + SDK_VERSION,
		"X-Persistly-Platform: godot",
	])
	if not account_session_token.is_empty():
		headers.append("X-Persistly-Account-Session: " + account_session_token)
	return headers


func _record_request(method: String, path: String, body: Variant, account_session_token: String, headers: PackedStringArray) -> void:
	var recorded_body = _redact_sensitive_value(body)
	var recorded_headers: Array = []
	for header in headers:
		recorded_headers.append(_redact_sensitive_header(String(header)))
	_recorded_requests.append({
		"method": method.to_upper(),
		"path": path,
		"body": recorded_body,
		"accountSessionToken": "[redacted]" if not account_session_token.is_empty() else "",
		"headers": recorded_headers,
	})


func _redact_sensitive_header(header: String) -> String:
	if header.begins_with("Authorization: Bearer "):
		return "Authorization: Bearer [redacted]"
	if header.begins_with("X-Persistly-Account-Session:"):
		return "X-Persistly-Account-Session: [redacted]"
	return header


func _redact_sensitive_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var redacted := {}
		for key in (value as Dictionary).keys():
			var key_name := String(key)
			if key_name == "transferCode" or key_name == "accountSessionToken" or key_name == "account_session_token":
				redacted[key] = "[redacted]"
			else:
				redacted[key] = _redact_sensitive_value((value as Dictionary)[key])
		return redacted
	if typeof(value) == TYPE_ARRAY:
		var redacted_array: Array = []
		for item in (value as Array):
			redacted_array.append(_redact_sensitive_value(item))
		return redacted_array
	return value


func _parse_api_origin() -> Dictionary:
	var protocol := ""
	if _api_origin.begins_with("https://"):
		protocol = "https"
	elif _api_origin.begins_with("http://"):
		protocol = "http"
	else:
		return _error_result(ERROR_INVALID_REQUEST, "PersistlyClient API origin must start with http:// or https://.")

	var remainder := _api_origin.trim_prefix(protocol + "://")
	var slash_index := remainder.find("/")
	var host_port := remainder
	var base_path := ""
	if slash_index >= 0:
		host_port = remainder.substr(0, slash_index)
		base_path = remainder.substr(slash_index)

	var host := host_port
	var port := 443 if protocol == "https" else 80
	var colon_index := host_port.rfind(":")
	if colon_index >= 0:
		host = host_port.substr(0, colon_index)
		port = int(host_port.substr(colon_index + 1))

	if host.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "PersistlyClient API origin must include a host.")

	return {
		"host": host,
		"port": port,
		"use_tls": protocol == "https",
		"base_path": base_path,
	}


func _wait_for_connection(client: HTTPClient) -> int:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		var poll_error := client.poll()
		if poll_error != OK:
			return poll_error
		if Time.get_ticks_msec() > deadline:
			return ERR_TIMEOUT
		OS.delay_msec(10)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return ERR_CANT_CONNECT
	return OK


func _read_response(client: HTTPClient) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		var poll_error := client.poll()
		if poll_error != OK:
			return _error_result(ERROR_SERVER, "Persistly transport failed while waiting for a response.", {
				"godotError": poll_error,
			})
		if Time.get_ticks_msec() > deadline:
			return _error_result(ERROR_SERVER, "Persistly transport timed out while waiting for a response.", {
				"godotError": ERR_TIMEOUT,
			})
		OS.delay_msec(10)

	var body_bytes := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		var body_error := client.poll()
		if body_error != OK:
			return _error_result(ERROR_SERVER, "Persistly transport failed while reading the response body.", {
				"godotError": body_error,
			})
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body_bytes.append_array(chunk)
		elif Time.get_ticks_msec() > deadline:
			return _error_result(ERROR_SERVER, "Persistly transport timed out while reading the response body.", {
				"godotError": ERR_TIMEOUT,
			})
		else:
			OS.delay_msec(10)

	var status_code := client.get_response_code()
	var body_text := body_bytes.get_string_from_utf8()
	return _parse_transport_response(status_code, body_text)


func _parse_transport_response(status_code: int, body_text: String) -> Dictionary:
	var parsed: Variant = {}
	if not body_text.is_empty():
		parsed = JSON.parse_string(body_text)
		if parsed == null:
			return _error_result(ERROR_SERVER, "Persistly response was not valid JSON.", {
				"statusCode": status_code,
			})

	if status_code >= 200 and status_code < 300:
		if typeof(parsed) != TYPE_DICTIONARY:
			return _error_result(ERROR_SERVER, "Persistly response must be a JSON object.")
		return parsed

	if status_code == 409 and typeof(parsed) == TYPE_DICTIONARY:
		var parsed_dict: Dictionary = parsed
		if parsed_dict.get("status", "") == "conflict" and (parsed_dict.has("save") or parsed_dict.has("account") or parsed_dict.has("slot")):
			return parsed_dict

	if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("error"):
		return parsed

	var error_code := _error_code_for_status(status_code)
	return _error_result(error_code, "Persistly runtime returned an unexpected response.", {
		"statusCode": status_code,
	})


func _normalize_save_envelope(response: Dictionary, cache_result: bool) -> Dictionary:
	if not response.has("save"):
		return _error_result(ERROR_SERVER, "Persistly response is missing the save payload.")

	var save = response["save"]
	if typeof(save) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly save payload must be a dictionary.")
	var normalized_save := _normalize_save(save, cache_result)
	if normalized_save.has("error"):
		return normalized_save
	var normalized := _copy_response_extras(response, ["save"])
	normalized["save"] = normalized_save
	return normalized


func _normalize_slot_envelope(response: Dictionary, cache_result: bool) -> Dictionary:
	var slot_value = response.get("slot", response)
	if typeof(slot_value) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly slot response is missing slot.")
	var slot := _normalize_slot_object(slot_value, cache_result)
	if slot.has("error"):
		return slot
	var normalized := _copy_response_extras(response, ["slot"])
	normalized["slot"] = slot
	return normalized


func _normalize_transfer_code_response(response: Dictionary) -> Dictionary:
	if typeof(response.get("transferCode", null)) != TYPE_STRING or String(response.get("transferCode", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly transfer-code response is missing transferCode.")
	if typeof(response.get("expiresAt", null)) != TYPE_STRING or String(response.get("expiresAt", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly transfer-code response is missing expiresAt.")
	var expires_in_type := typeof(response.get("expiresInSeconds", null))
	if not (expires_in_type == TYPE_INT or expires_in_type == TYPE_FLOAT):
		return _error_result(ERROR_SERVER, "Persistly transfer-code response is missing expiresInSeconds.")
	return {
		"transferCode": String(response["transferCode"]),
		"expiresAt": String(response["expiresAt"]),
		"expiresInSeconds": int(response["expiresInSeconds"]),
	}


func _normalize_account_object(account: Dictionary, cache_result: bool) -> Dictionary:
	if typeof(account.get("accountId", null)) != TYPE_STRING or String(account.get("accountId", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly account payload is missing accountId.")
	if typeof(account.get("accountData", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly account payload is missing accountData.")
	if typeof(account.get("slots", null)) != TYPE_ARRAY:
		return _error_result(ERROR_SERVER, "Persistly account payload is missing slots.")
	if not (typeof(account.get("version", null)) == TYPE_INT or typeof(account.get("version", null)) == TYPE_FLOAT):
		return _error_result(ERROR_SERVER, "Persistly account payload is missing version.")

	var normalized := _duplicate_dictionary(account)
	normalized["version"] = int(account["version"])
	if cache_result:
		_save_cache[String(account["accountId"])] = normalized.duplicate(true)
	return normalized


func _normalize_slot_object(slot: Dictionary, cache_result: bool) -> Dictionary:
	if typeof(slot.get("slotId", null)) != TYPE_STRING or String(slot.get("slotId", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly slot payload is missing slotId.")
	if typeof(slot.get("slotInfo", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly slot payload is missing slotInfo.")
	if slot.has("data") and typeof(slot["data"]) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly slot payload data must be a dictionary.")
	if not (typeof(slot.get("version", null)) == TYPE_INT or typeof(slot.get("version", null)) == TYPE_FLOAT):
		return _error_result(ERROR_SERVER, "Persistly slot payload is missing version.")

	var normalized := _duplicate_dictionary(slot)
	normalized["version"] = int(slot["version"])
	if not normalized.has("data"):
		normalized["data"] = {}
	if cache_result:
		_save_cache[String(slot["slotId"])] = normalized.duplicate(true)
	return normalized


func _account_state_from_sync(account_id: String, request_body: Dictionary) -> Dictionary:
	var cached: Dictionary = _save_cache.get(account_id, {})
	var cached_state: Dictionary = cached.get("state", {}) if typeof(cached.get("state", {})) == TYPE_DICTIONARY else {}
	var account_data: Dictionary = {}
	if request_body.has("accountData"):
		account_data = (request_body["accountData"] as Dictionary).duplicate(true)
	elif request_body.has("accountDataPatch"):
		account_data = (cached_state.get("accountData", {}) as Dictionary).duplicate(true) if typeof(cached_state.get("accountData", {})) == TYPE_DICTIONARY else {}
		for key in (request_body["accountDataPatch"] as Dictionary).keys():
			if request_body["accountDataPatch"][key] == null:
				account_data.erase(key)
			else:
				account_data[key] = request_body["accountDataPatch"][key]
	else:
		account_data = (cached_state.get("accountData", {}) as Dictionary).duplicate(true) if typeof(cached_state.get("accountData", {})) == TYPE_DICTIONARY else {}
	var slot_slots: Array = (cached_state.get("slots", []) as Array).duplicate(true) if typeof(cached_state.get("slots", [])) == TYPE_ARRAY else []
	return {
		"schema": "persistly.account.v1",
		"accountData": account_data,
		"slots": slot_slots,
	}


func _synthesize_account_from_sync(account_id: String, request_body: Dictionary, response: Dictionary) -> Dictionary:
	var cached: Dictionary = _save_cache.get(account_id, {})
	var account_data: Dictionary = cached.get("accountData", {}).duplicate(true) if typeof(cached.get("accountData", {})) == TYPE_DICTIONARY else {}
	if request_body.has("accountData"):
		account_data = (request_body["accountData"] as Dictionary).duplicate(true)
	elif request_body.has("accountDataPatch"):
		for key in (request_body["accountDataPatch"] as Dictionary).keys():
			if request_body["accountDataPatch"][key] == null:
				account_data.erase(key)
			else:
				account_data[key] = request_body["accountDataPatch"][key]
	return {
		"accountId": account_id,
		"accountData": account_data,
		"slots": cached.get("slots", []).duplicate(true) if typeof(cached.get("slots", [])) == TYPE_ARRAY else [],
		"version": int(response["version"]),
		"updatedAt": String(response["updatedAt"]),
	}


func _synthesize_slot_from_sync(slot_id: String, slot_info: Dictionary, data: Dictionary, response: Dictionary) -> Dictionary:
	return {
		"slotId": slot_id,
		"slotInfo": slot_info.duplicate(true),
		"data": data.duplicate(true),
		"version": int(response["version"]),
		"updatedAt": String(response["updatedAt"]),
	}


func _synthesize_save_from_sync(save_id: String, request_metadata: Variant, request_state: Dictionary, response: Dictionary) -> Dictionary:
	var cached: Dictionary = _save_cache.get(save_id, {})
	var metadata: Dictionary = {}
	if request_metadata == "__persistly_missing__":
		metadata = cached.get("metadata", {}).duplicate(true) if typeof(cached.get("metadata", {})) == TYPE_DICTIONARY else {}
	elif request_metadata == null:
		metadata = {}
	elif typeof(request_metadata) == TYPE_DICTIONARY:
		metadata = (request_metadata as Dictionary).duplicate(true)
	var created_at := String(cached.get("createdAt", "1970-01-01T00:00:00Z"))
	return {
		"saveId": save_id,
		"playerRef": cached.get("playerRef", null),
		"metadata": metadata,
		"state": request_state.duplicate(true),
		"version": int(response["version"]),
		"createdAt": created_at,
		"updatedAt": String(response["updatedAt"]),
	}


func _normalize_sync_response(
	response: Dictionary,
	cache_result: bool,
	label: String,
	save_id: String = "",
	request_metadata: Variant = null,
	request_state: Dictionary = {},
) -> Dictionary:
	var status = String(response.get("status", ""))
	if status != "accepted" and status != "conflict":
		return _error_result(ERROR_SERVER, label + " returned an unexpected status.")

	var normalized := _copy_response_extras(response, [])

	if status == "conflict":
		normalized = _normalize_save_envelope(response, cache_result)
		if normalized.has("error"):
			return normalized
		var details = normalized.get("details", {})
		if typeof(details) != TYPE_DICTIONARY or String(details.get("reason", "")) != "base_version_mismatch":
			return _error_result(ERROR_SERVER, label + " conflict response is missing a valid reason.")
	else:
		if not response.has("version") and not response.has("save"):
			return _error_result(ERROR_SERVER, label + " accepted response is missing version.")
		if not response.has("updatedAt") and not response.has("save"):
			return _error_result(ERROR_SERVER, label + " accepted response is missing updatedAt.")
		if response.has("save"):
			normalized = _normalize_save_envelope(response, cache_result)
			if normalized.has("error"):
				return normalized
		else:
			var synthesized := _synthesize_save_from_sync(save_id, request_metadata, request_state, response)
			var normalized_save := _normalize_save(synthesized, cache_result)
			if normalized_save.has("error"):
				return normalized_save
			normalized["save"] = normalized_save
		normalized["version"] = int(response.get("version", normalized["save"].get("version", 0)))
		normalized["updatedAt"] = String(response.get("updatedAt", normalized["save"].get("updatedAt", "")))
		normalized["historyRetained"] = bool(response.get("historyRetained", false))

	normalized["status"] = status
	return normalized


func _normalize_account_sync_response(response: Dictionary, cache_result: bool, label: String, account_id: String, request_body: Dictionary) -> Dictionary:
	var status = String(response.get("status", ""))
	if status != "accepted" and status != "conflict":
		return _error_result(ERROR_SERVER, label + " returned an unexpected status.")

	var normalized := _copy_response_extras(response, [])
	if response.has("account"):
		var account := _normalize_account_object(response["account"], cache_result)
		if account.has("error"):
			return account
		normalized["account"] = account
	elif status == "accepted":
		if not response.has("version") or not response.has("updatedAt"):
			return _error_result(ERROR_SERVER, label + " accepted response is missing version or updatedAt.")
		normalized["account"] = _normalize_account_object(_synthesize_account_from_sync(account_id, request_body, response), cache_result)
	else:
		return _error_result(ERROR_SERVER, label + " conflict response is missing account.")

	normalized["status"] = status
	normalized["version"] = int(response.get("version", normalized["account"].get("version", 0)))
	normalized["updatedAt"] = String(response.get("updatedAt", normalized["account"].get("updatedAt", "")))
	normalized["historyRetained"] = bool(response.get("historyRetained", false))
	return normalized


func _normalize_slot_sync_response(response: Dictionary, cache_result: bool, label: String, slot_id: String, slot_info: Dictionary, data: Dictionary) -> Dictionary:
	var status = String(response.get("status", ""))
	if status != "accepted" and status != "conflict":
		return _error_result(ERROR_SERVER, label + " returned an unexpected status.")

	var normalized := _copy_response_extras(response, [])
	if response.has("slot"):
		var slot := _normalize_slot_object(response["slot"], cache_result)
		if slot.has("error"):
			return slot
		normalized["slot"] = slot
	elif status == "accepted":
		if not response.has("version") or not response.has("updatedAt"):
			return _error_result(ERROR_SERVER, label + " accepted response is missing version or updatedAt.")
		normalized["slot"] = _normalize_slot_object(_synthesize_slot_from_sync(slot_id, slot_info, data, response), cache_result)
	else:
		return _error_result(ERROR_SERVER, label + " conflict response is missing slot.")

	normalized["status"] = status
	normalized["version"] = int(response.get("version", normalized["slot"].get("version", 0)))
	normalized["updatedAt"] = String(response.get("updatedAt", normalized["slot"].get("updatedAt", "")))
	normalized["historyRetained"] = bool(response.get("historyRetained", false))
	return normalized


func _normalize_account_response(response: Dictionary, cache_result: bool, require_session_token: bool) -> Dictionary:
	var account_payload = response.get("account", response)
	if typeof(account_payload) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly account response is missing account.")
	var account := _normalize_account_object(account_payload, cache_result)
	if account.has("error"):
		return account

	var response_account_id := String(response.get("accountId", account.get("accountId", "")))
	if response_account_id.is_empty():
		return _error_result(ERROR_SERVER, "Persistly account response is missing accountId.")
	if require_session_token and (typeof(response.get("accountSessionToken", null)) != TYPE_STRING or String(response.get("accountSessionToken", "")).is_empty()):
		return _error_result(ERROR_SERVER, "Persistly account response is missing accountSessionToken.")

	var normalized: Dictionary = {
		"accountId": response_account_id,
		"account": account,
	}
	if response.has("accountSessionToken"):
		normalized["accountSessionToken"] = String(response["accountSessionToken"])
	if response.has("syncPolicy"):
		if typeof(response["syncPolicy"]) != TYPE_DICTIONARY:
			return _error_result(ERROR_SERVER, "Persistly account response syncPolicy must be a dictionary.")
		normalized["syncPolicy"] = (response["syncPolicy"] as Dictionary).duplicate(true)
	if response.has("slot"):
		if typeof(response["slot"]) != TYPE_DICTIONARY:
			return _error_result(ERROR_SERVER, "Persistly account response slot must be a dictionary.")
		var slot := _normalize_slot_object(response["slot"], cache_result)
		if slot.has("error"):
			return slot
		normalized["slot"] = slot
	return normalized


func _normalize_delete_account_response(response: Dictionary, account_id: String) -> Dictionary:
	if typeof(response.get("accountId", null)) != TYPE_STRING or String(response.get("accountId", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly delete account response is missing accountId.")
	if typeof(response.get("deletedAt", null)) != TYPE_STRING or String(response.get("deletedAt", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly delete account response is missing deletedAt.")
	var deleted_slot_count_type := typeof(response.get("deletedSlotCount", null))
	if not (deleted_slot_count_type == TYPE_INT or deleted_slot_count_type == TYPE_FLOAT):
		return _error_result(ERROR_SERVER, "Persistly delete account response is missing deletedSlotCount.")
	if typeof(response.get("alreadyDeleted", null)) != TYPE_BOOL:
		return _error_result(ERROR_SERVER, "Persistly delete account response is missing alreadyDeleted.")
	if typeof(response.get("cleanupQueued", null)) != TYPE_BOOL:
		return _error_result(ERROR_SERVER, "Persistly delete account response is missing cleanupQueued.")

	var normalized := {
		"accountId": String(response["accountId"]),
		"deletedAt": String(response["deletedAt"]),
		"deletedSlotCount": int(response["deletedSlotCount"]),
		"alreadyDeleted": bool(response["alreadyDeleted"]),
		"cleanupQueued": bool(response["cleanupQueued"]),
	}
	clear_cached_save(account_id)
	return normalized


func _normalize_delete_account_slot_response(response: Dictionary, slot_id: String) -> Dictionary:
	if typeof(response.get("accountId", null)) != TYPE_STRING or String(response.get("accountId", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly delete account slot response is missing accountId.")
	if typeof(response.get("slotId", null)) != TYPE_STRING or String(response.get("slotId", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly delete account slot response is missing slotId.")
	if typeof(response.get("deletedAt", null)) != TYPE_STRING or String(response.get("deletedAt", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly delete account slot response is missing deletedAt.")
	if typeof(response.get("alreadyDeleted", null)) != TYPE_BOOL:
		return _error_result(ERROR_SERVER, "Persistly delete account slot response is missing alreadyDeleted.")
	if typeof(response.get("cleanupQueued", null)) != TYPE_BOOL:
		return _error_result(ERROR_SERVER, "Persistly delete account slot response is missing cleanupQueued.")

	var normalized: Dictionary = {
		"accountId": String(response["accountId"]),
		"slotId": String(response["slotId"]),
		"deletedAt": String(response["deletedAt"]),
		"alreadyDeleted": bool(response["alreadyDeleted"]),
		"cleanupQueued": bool(response["cleanupQueued"]),
	}
	if typeof(response.get("slotId", null)) == TYPE_STRING:
		normalized["slotId"] = String(response["slotId"])
	clear_cached_save(slot_id)
	if response.has("account"):
		if typeof(response["account"]) != TYPE_DICTIONARY:
			return _error_result(ERROR_SERVER, "Persistly delete account slot response account must be a dictionary.")
		var account := _normalize_account_object(response["account"], true)
		if account.has("error"):
			return account
		normalized["account"] = account
	return normalized


func _normalize_save(save: Dictionary, cache_result: bool) -> Dictionary:
	var required_keys := [
		"saveId",
		"playerRef",
		"metadata",
		"state",
		"version",
		"createdAt",
		"updatedAt",
	]
	for key in required_keys:
		if not save.has(key):
			return _error_result(ERROR_SERVER, "Persistly save payload is missing " + key + ".")

	if typeof(save["saveId"]) != TYPE_STRING or String(save["saveId"]).is_empty():
		return _error_result(ERROR_SERVER, "Persistly save payload has an invalid saveId.")
	if not (typeof(save["playerRef"]) == TYPE_STRING or save["playerRef"] == null):
		return _error_result(ERROR_SERVER, "Persistly save payload has an invalid playerRef.")
	if typeof(save["metadata"]) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly save payload metadata must be a dictionary.")
	if typeof(save["state"]) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly save payload state must be a dictionary.")
	if not (typeof(save["version"]) == TYPE_INT or typeof(save["version"]) == TYPE_FLOAT):
		return _error_result(ERROR_SERVER, "Persistly save payload version must be an integer.")
	if typeof(save["createdAt"]) != TYPE_STRING or typeof(save["updatedAt"]) != TYPE_STRING:
		return _error_result(ERROR_SERVER, "Persistly save payload timestamps must be strings.")

	var normalized_save := _duplicate_dictionary(save)
	normalized_save["version"] = int(save["version"])
	if cache_result:
		_save_cache[String(save["saveId"])] = normalized_save.duplicate(true)
	return normalized_save


func _copy_response_extras(response: Dictionary, excluded_keys: Array[String]) -> Dictionary:
	var extras := {}
	for key in response.keys():
		if not excluded_keys.has(String(key)):
			extras[key] = response[key]
	return extras


func _error_result(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var error := {
		"code": code,
		"message": message,
	}
	if not details.is_empty():
		error["details"] = details
	return {"error": error}


func _error_code_for_status(status_code: int) -> String:
	match status_code:
		400:
			return ERROR_INVALID_REQUEST
		403:
			return ERROR_FORBIDDEN
		422:
			return ERROR_INVALID_REQUEST
		401:
			return ERROR_UNAUTHORIZED
		404:
			return ERROR_NOT_FOUND
		409:
			return ERROR_CONFLICT
		410:
			return ERROR_ACCOUNT_DELETED
		402:
			return ERROR_MONTHLY_QUOTA_EXCEEDED
		413:
			return ERROR_PAYLOAD_TOO_LARGE
		429:
			return ERROR_RATE_LIMITED
		_:
			return ERROR_SERVER


func _validate_payload_sizes(metadata: Dictionary, state: Dictionary) -> Dictionary:
	var metadata_bytes := JSON.stringify(metadata).to_utf8_buffer().size()
	if metadata_bytes > METADATA_MAX_BYTES:
		return _error_result(ERROR_PAYLOAD_TOO_LARGE, "Metadata exceeds the maximum allowed size.", {
			"field": "metadata",
			"maxBytes": METADATA_MAX_BYTES,
		})

	var state_bytes := JSON.stringify(state).to_utf8_buffer().size()
	if state_bytes > STATE_MAX_BYTES:
		return _error_result(ERROR_PAYLOAD_TOO_LARGE, "State exceeds the maximum allowed size.", {
			"field": "state",
			"maxBytes": STATE_MAX_BYTES,
		})

	return {}


func _http_method(method: String) -> int:
	match method.to_upper():
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"PATCH":
			return HTTPClient.METHOD_PUT
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET


func _fixture_key(method: String, path: String) -> String:
	return method.to_upper() + " " + path


func _pop_fixture_response(method: String, path: String) -> Dictionary:
	var key := _fixture_key(method, path)
	if not _fixture_responses.has(key):
		return {}

	var responses: Array = _fixture_responses[key]
	if responses.is_empty():
		_fixture_responses.erase(key)
		return {}

	var fixture: Dictionary = responses.pop_front()
	if responses.is_empty():
		_fixture_responses.erase(key)
	else:
		_fixture_responses[key] = responses
	return fixture


func _duplicate_dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _url_encode(value: String) -> String:
	return value.uri_encode()


class PersistlyMemoryAutosaveDraftStore:
	var _drafts: Dictionary = {}

	func store_draft(draft: Dictionary) -> void:
		_drafts[String(draft.get("slotId", ""))] = draft.duplicate(true)

	func load_draft(slot_id: String) -> Dictionary:
		if not _drafts.has(slot_id):
			return {}
		return (_drafts[slot_id] as Dictionary).duplicate(true)

	func clear_draft(slot_id: String) -> void:
		_drafts.erase(slot_id)


class PersistlyFileAutosaveDraftStore:
	var root_path: String

	func _init(root_path_value: String = "user://persistly_autosave") -> void:
		root_path = root_path_value.rstrip("/")
		DirAccess.make_dir_recursive_absolute(root_path)

	func store_draft(draft: Dictionary) -> void:
		var slot_id := String(draft.get("slotId", ""))
		if slot_id.is_empty():
			return
		var file := FileAccess.open(_draft_path(slot_id), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(draft))
			file.close()

	func load_draft(slot_id: String) -> Dictionary:
		var path := _draft_path(slot_id)
		if not FileAccess.file_exists(path):
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			return {}
		return (parsed as Dictionary).duplicate(true)

	func clear_draft(slot_id: String) -> void:
		var path := _draft_path(slot_id)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	func _draft_path(slot_id: String) -> String:
		return root_path.path_join(slot_id.uri_encode() + ".json")


class PersistlyAutosaveManager:
	var draft_store: Variant
	var sync_policy: Dictionary
	var _last_remote_sync_msec: Dictionary = {}

	func _init(draft_store_value: Variant, sync_policy_value: Dictionary) -> void:
		draft_store = draft_store_value
		sync_policy = sync_policy_value.duplicate(true)

	func record_local_change(account_id: String, account_session_token: String, slot_id: String, metadata: Dictionary, state: Dictionary, base_version: Variant = null) -> Dictionary:
		var draft := {
			"accountId": account_id,
			"accountSessionToken": account_session_token,
			"slotId": slot_id,
			"metadata": metadata.duplicate(true),
			"state": state.duplicate(true),
			"baseVersion": base_version,
			"updatedAtMsec": Time.get_ticks_msec(),
		}
		draft_store.store_draft(draft)
		return draft

	func should_sync_remote(slot_id: String, force: bool = false) -> bool:
		if draft_store.load_draft(slot_id).is_empty():
			return false
		if not _last_remote_sync_msec.has(slot_id):
			return true

		var elapsed_seconds := float(Time.get_ticks_msec() - int(_last_remote_sync_msec[slot_id])) / 1000.0
		if force:
			return elapsed_seconds >= float(sync_policy.get("forceSyncCooldownSeconds", 10))
		return elapsed_seconds >= float(sync_policy.get("minRemoteSyncIntervalSeconds", 60))

	func mark_remote_synced(slot_id: String) -> void:
		_last_remote_sync_msec[slot_id] = Time.get_ticks_msec()
		draft_store.clear_draft(slot_id)
