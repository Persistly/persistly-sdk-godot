extends RefCounted
class_name PersistlyClient

const SDK_VERSION := "0.10.0"
const BUNDLE_VERSION := "persistly-contract-v0.3.0"
const BUNDLE_ROOT := "res://contracts/persistly-contract-v0.3.0"
const DEFAULT_BASE_URL := "https://api.persistly.app"
const DEFAULT_TIMEOUT_SECONDS := 30.0
const METADATA_MAX_BYTES := 16384
const STATE_MAX_BYTES := 262144

const ERROR_INVALID_REQUEST := "invalid_request"
const ERROR_UNAUTHORIZED := "unauthorized"
const ERROR_FORBIDDEN := "forbidden"
const ERROR_NOT_FOUND := "not_found"
const ERROR_CONFLICT := "conflict"
const ERROR_SLOT_ALREADY_EXISTS := "slot_already_exists"
const ERROR_CHARACTER_ARCHIVED := "character_archived"
const ERROR_RATE_LIMITED := "rate_limited"
const ERROR_PAYLOAD_TOO_LARGE := "payload_too_large"
const ERROR_SERVER := "server_error"

var base_url: String
var runtime_key: String
var timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS

var _save_cache: Dictionary = {}
var _fixture_responses: Dictionary = {}
var _recorded_requests: Array = []


func _init(base_url_value: String = DEFAULT_BASE_URL, runtime_key_value: String = "", timeout_seconds_value: float = DEFAULT_TIMEOUT_SECONDS) -> void:
	base_url = _normalize_base_url(base_url_value)
	runtime_key = runtime_key_value
	timeout_seconds = max(timeout_seconds_value, 1.0)


func configure(base_url_value: String, runtime_key_value: String, timeout_seconds_value: float = DEFAULT_TIMEOUT_SECONDS) -> void:
	base_url = _normalize_base_url(base_url_value)
	runtime_key = runtime_key_value
	timeout_seconds = max(timeout_seconds_value, 1.0)


func configure_runtime_key(runtime_key_value: String, timeout_seconds_value: float = DEFAULT_TIMEOUT_SECONDS) -> void:
	configure(DEFAULT_BASE_URL, runtime_key_value, timeout_seconds_value)


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


func create_profile(payload: Dictionary = {}) -> Dictionary:
	var preflight := _validate_runtime_configuration("create_profile")
	if not preflight.is_empty():
		return preflight

	var account_data := payload.get("accountData", {})
	var profile_metadata := payload.get("profileMetadata", {})
	if typeof(account_data) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile accountData must be a dictionary.")
	if typeof(profile_metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile profileMetadata must be a dictionary when provided.")

	var profile_payload_error := _validate_payload_sizes(profile_metadata, account_data)
	if not profile_payload_error.is_empty():
		return profile_payload_error

	var request_body: Dictionary = {
		"accountData": account_data,
		"profileMetadata": profile_metadata,
	}
	if payload.has("playerRef"):
		var player_ref = payload.get("playerRef")
		if not (typeof(player_ref) == TYPE_STRING or player_ref == null):
			return _error_result(ERROR_INVALID_REQUEST, "playerRef must be a string or null.")
		request_body["playerRef"] = player_ref
	if payload.has("externalProfileRef"):
		var external_profile_ref = payload.get("externalProfileRef")
		if not (typeof(external_profile_ref) == TYPE_DICTIONARY or external_profile_ref == null):
			return _error_result(ERROR_INVALID_REQUEST, "externalProfileRef must be a dictionary or null.")
		request_body["externalProfileRef"] = external_profile_ref

	if payload.has("characterState") or payload.has("characterMetadata"):
		return _error_result(ERROR_INVALID_REQUEST, "create_profile accepts character.metadata and character.state; characterState and characterMetadata are not supported.")

	var character = payload.get("character", null)
	if character != null:
		if typeof(character) != TYPE_DICTIONARY:
			return _error_result(ERROR_INVALID_REQUEST, "create_profile character must be a dictionary when provided.")
		var character_request := _normalize_character_request(character, "create_profile")
		if character_request.has("error"):
			return character_request
		request_body["character"] = character_request

	var response := _request_json("POST", "/api/v1/profiles", request_body)
	if response.has("error"):
		return response

	return _normalize_profile_response(response, true, true)


func load_profile(profile_save_id: String, profile_session_token: String) -> Dictionary:
	var preflight := _validate_profile_session_configuration("load_profile", profile_save_id, profile_session_token)
	if not preflight.is_empty():
		return preflight

	var response := _request_json(
		"GET",
		"/api/v1/profiles/" + _url_encode(profile_save_id),
		null,
		profile_session_token)
	if response.has("error"):
		return response

	return _normalize_profile_response(response, true, false)


func sync_profile_account_data(profile_save_id: String, profile_session_token: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_profile_session_configuration("sync_profile_account_data", profile_save_id, profile_session_token)
	if not preflight.is_empty():
		return preflight

	if payload.has("characterSlots") or payload.has("characters"):
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data cannot rewrite profile character slot refs.")

	var base_version = payload.get("baseVersion", null)
	if base_version == null and _save_cache.has(profile_save_id):
		base_version = int(_save_cache[profile_save_id].get("version", 0))
	if base_version == null:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data requires baseVersion unless the profile is already cached.")
	if typeof(base_version) != TYPE_INT:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data baseVersion must be an integer.")

	var has_account_data := payload.has("accountData")
	var has_account_data_patch := payload.has("accountDataPatch")
	var has_metadata := payload.has("metadata")
	if has_account_data and has_account_data_patch:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data accepts accountData or accountDataPatch, not both.")
	if not has_account_data and not has_account_data_patch and not has_metadata:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data requires accountData, accountDataPatch, or metadata.")

	var request_body: Dictionary = {
		"baseVersion": base_version,
	}
	if has_account_data:
		var account_data = payload["accountData"]
		if typeof(account_data) != TYPE_DICTIONARY:
			return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data accountData must be a dictionary.")
		var payload_error := _validate_payload_sizes({}, account_data)
		if not payload_error.is_empty():
			return payload_error
		request_body["accountData"] = account_data
	if has_account_data_patch:
		var account_data_patch = payload["accountDataPatch"]
		if typeof(account_data_patch) != TYPE_DICTIONARY:
			return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data accountDataPatch must be a dictionary.")
		var patch_error := _validate_payload_sizes({}, account_data_patch)
		if not patch_error.is_empty():
			return patch_error
		request_body["accountDataPatch"] = account_data_patch
	if has_metadata:
		var metadata = payload["metadata"]
		if not (typeof(metadata) == TYPE_DICTIONARY or metadata == null):
			return _error_result(ERROR_INVALID_REQUEST, "sync_profile_account_data metadata must be a dictionary or null.")
		var metadata_error := _validate_payload_sizes({} if metadata == null else metadata, {})
		if not metadata_error.is_empty():
			return metadata_error
		request_body["metadata"] = metadata

	var response := _request_json(
		"POST",
		"/api/v1/profiles/" + _url_encode(profile_save_id) + "/account-data/sync",
		request_body,
		profile_session_token)
	if response.has("error"):
		return response

	return _normalize_sync_response(response, true, "sync_profile_account_data", profile_save_id, request_body.get("metadata", "__persistly_missing__"), _profile_state_from_sync(profile_save_id, request_body))


func create_profile_character(profile_save_id: String, profile_session_token: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_profile_session_configuration("create_profile_character", profile_save_id, profile_session_token)
	if not preflight.is_empty():
		return preflight

	var character_request := _normalize_character_request(payload, "create_profile_character")
	if character_request.has("error"):
		return character_request

	var response := _request_json(
		"POST",
		"/api/v1/profiles/" + _url_encode(profile_save_id) + "/characters",
		character_request,
		profile_session_token)
	if response.has("error"):
		return response

	return _normalize_profile_response(response, true, false)


func load_profile_character(profile_save_id: String, profile_session_token: String, character_save_id: String) -> Dictionary:
	var preflight := _validate_profile_session_configuration("load_profile_character", profile_save_id, profile_session_token)
	if not preflight.is_empty():
		return preflight
	if character_save_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "load_profile_character requires a non-empty character_save_id.")

	var response := _request_json(
		"GET",
		"/api/v1/profiles/" + _url_encode(profile_save_id) + "/characters/" + _url_encode(character_save_id),
		null,
		profile_session_token)
	if response.has("error"):
		return response

	return _normalize_save_envelope(response, true)


func sync_profile_character(profile_save_id: String, profile_session_token: String, character_save_id: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_profile_session_configuration("sync_profile_character", profile_save_id, profile_session_token)
	if not preflight.is_empty():
		return preflight
	if character_save_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_character requires a non-empty character_save_id.")

	if typeof(payload.get("state", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_character requires a dictionary state payload.")

	var metadata := payload.get("metadata", {})
	if typeof(metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_character metadata must be a dictionary when provided.")
	var metadata_error := _validate_character_metadata(metadata, "sync_profile_character")
	if not metadata_error.is_empty():
		return metadata_error

	var base_version = payload.get("baseVersion", null)
	if base_version == null and _save_cache.has(character_save_id):
		base_version = int(_save_cache[character_save_id].get("version", 0))
	if base_version == null:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_character requires baseVersion unless the character save is already cached.")
	if typeof(base_version) != TYPE_INT:
		return _error_result(ERROR_INVALID_REQUEST, "sync_profile_character baseVersion must be an integer.")

	var payload_error := _validate_payload_sizes(metadata, payload["state"])
	if not payload_error.is_empty():
		return payload_error

	var response := _request_json(
		"POST",
		"/api/v1/profiles/" + _url_encode(profile_save_id) + "/characters/" + _url_encode(character_save_id) + "/sync",
		{
			"baseVersion": base_version,
			"metadata": metadata,
			"state": payload["state"],
		},
		profile_session_token)
	if response.has("error"):
		return response

	return _normalize_sync_response(response, true, "sync_profile_character", character_save_id, metadata, payload["state"])


func archive_profile_character(profile_save_id: String, profile_session_token: String, character_save_id: String) -> Dictionary:
	var preflight := _validate_profile_session_configuration("archive_profile_character", profile_save_id, profile_session_token)
	if not preflight.is_empty():
		return preflight
	if character_save_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "archive_profile_character requires a non-empty character_save_id.")

	var response := _request_json(
		"POST",
		"/api/v1/profiles/" + _url_encode(profile_save_id) + "/characters/" + _url_encode(character_save_id) + "/archive",
		null,
		profile_session_token)
	if response.has("error"):
		return response

	return _normalize_profile_response(response, true, false)


func get_runtime_config() -> Dictionary:
	var preflight := _validate_runtime_configuration("get_runtime_config")
	if not preflight.is_empty():
		return preflight

	var response := _request_json("GET", "/api/v1/runtime-config")
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


func clear_fixture_responses() -> void:
	_fixture_responses.clear()


func get_recorded_requests() -> Array:
	return _recorded_requests.duplicate(true)


func clear_recorded_requests() -> void:
	_recorded_requests.clear()


func _normalize_character_request(payload: Dictionary, action: String) -> Dictionary:
	var metadata := payload.get("metadata", {})
	var state = payload.get("state", null)
	if typeof(metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, action + " character metadata must be a dictionary.")
	if typeof(state) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, action + " requires a dictionary character state payload.")

	var metadata_error := _validate_character_metadata(metadata, action)
	if not metadata_error.is_empty():
		return metadata_error
	var payload_error := _validate_payload_sizes(metadata, state)
	if not payload_error.is_empty():
		return payload_error
	return {
		"metadata": metadata,
		"state": state,
	}


func _validate_character_metadata(metadata: Dictionary, action: String) -> Dictionary:
	var persistly_metadata = metadata.get("_persistly", null)
	if typeof(persistly_metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, action + " metadata._persistly.slotKey is required.")
	var slot_key := String((persistly_metadata as Dictionary).get("slotKey", ""))
	if not _is_valid_slot_key(slot_key):
		return _error_result(ERROR_INVALID_REQUEST, action + " metadata._persistly.slotKey must match ^[A-Za-z0-9_.-]{1,64}$.", {
			"slotKey": slot_key,
		})
	if (persistly_metadata as Dictionary).size() != 1:
		return _error_result(ERROR_INVALID_REQUEST, action + " metadata._persistly may only contain the SDK-owned slotKey.")
	return {}


func _is_valid_slot_key(slot_key: String) -> bool:
	if slot_key.length() < 1 or slot_key.length() > 64:
		return false
	for index in range(slot_key.length()):
		var code := slot_key.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_symbol := code == 45 or code == 46 or code == 95
		if not (is_digit or is_upper or is_lower or is_symbol):
			return false
	return true


func _validate_runtime_configuration(action: String) -> Dictionary:
	if base_url.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, "PersistlyClient requires base_url before calling " + action + ".")
	if runtime_key.is_empty():
		return _error_result(ERROR_UNAUTHORIZED, "PersistlyClient requires runtime_key before calling " + action + ".")
	return {}


func _validate_profile_session_configuration(action: String, profile_save_id: String, profile_session_token: String) -> Dictionary:
	var preflight := _validate_runtime_configuration(action)
	if not preflight.is_empty():
		return preflight
	if profile_save_id.is_empty():
		return _error_result(ERROR_INVALID_REQUEST, action + " requires a non-empty profile_save_id.")
	if profile_session_token.is_empty():
		return _error_result(ERROR_FORBIDDEN, action + " requires a non-empty profile_session_token.")
	return {}


func _normalize_base_url(value: String) -> String:
	var normalized := value.strip_edges().rstrip("/")
	return DEFAULT_BASE_URL if normalized.is_empty() else normalized


func _request_json(method: String, path: String, body: Variant = null, profile_session_token: String = "") -> Dictionary:
	_record_request(method, path, body, profile_session_token)
	var fixture := _pop_fixture_response(method, path)
	if not fixture.is_empty():
		return _parse_transport_response(int(fixture.get("status_code", 500)), String(fixture.get("body", "")))

	var url_parts := _parse_base_url()
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

	var headers := PackedStringArray([
		"Authorization: Bearer " + runtime_key,
		"Content-Type: application/json",
		"Accept: application/json",
		"User-Agent: PersistlyGodotSDK/" + SDK_VERSION,
	])
	if not profile_session_token.is_empty():
		headers.append("X-Persistly-Profile-Session: " + profile_session_token)
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


func _record_request(method: String, path: String, body: Variant, profile_session_token: String) -> void:
	var recorded_body = body
	if typeof(body) == TYPE_DICTIONARY or typeof(body) == TYPE_ARRAY:
		recorded_body = body.duplicate(true)
	_recorded_requests.append({
		"method": method.to_upper(),
		"path": path,
		"body": recorded_body,
		"profileSessionToken": profile_session_token,
	})


func _parse_base_url() -> Dictionary:
	var protocol := ""
	if base_url.begins_with("https://"):
		protocol = "https"
	elif base_url.begins_with("http://"):
		protocol = "http"
	else:
		return _error_result(ERROR_INVALID_REQUEST, "PersistlyClient base_url must start with http:// or https://.")

	var remainder := base_url.trim_prefix(protocol + "://")
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
		return _error_result(ERROR_INVALID_REQUEST, "PersistlyClient base_url must include a host.")

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
		if parsed_dict.get("status", "") == "conflict" and parsed_dict.has("save"):
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


func _profile_state_from_sync(profile_save_id: String, request_body: Dictionary) -> Dictionary:
	var cached: Dictionary = _save_cache.get(profile_save_id, {})
	var cached_state: Dictionary = cached.get("state", {}) if typeof(cached.get("state", {})) == TYPE_DICTIONARY else {}
	var account_data: Dictionary = {}
	if request_body.has("accountData"):
		account_data = (request_body["accountData"] as Dictionary).duplicate(true)
	elif request_body.has("accountDataPatch"):
		account_data = (cached_state.get("accountData", {}) as Dictionary).duplicate(true) if typeof(cached_state.get("accountData", {})) == TYPE_DICTIONARY else {}
		for key in (request_body["accountDataPatch"] as Dictionary).keys():
			account_data[key] = request_body["accountDataPatch"][key]
	else:
		account_data = (cached_state.get("accountData", {}) as Dictionary).duplicate(true) if typeof(cached_state.get("accountData", {})) == TYPE_DICTIONARY else {}
	var character_slots: Array = (cached_state.get("characterSlots", []) as Array).duplicate(true) if typeof(cached_state.get("characterSlots", [])) == TYPE_ARRAY else []
	return {
		"schema": "persistly.profile.v1",
		"accountData": account_data,
		"characterSlots": character_slots,
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


func _normalize_profile_response(response: Dictionary, cache_result: bool, require_session_token: bool) -> Dictionary:
	if typeof(response.get("profileSaveId", null)) != TYPE_STRING or String(response.get("profileSaveId", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly profile response is missing profileSaveId.")
	if require_session_token and (typeof(response.get("profileSessionToken", null)) != TYPE_STRING or String(response.get("profileSessionToken", "")).is_empty()):
		return _error_result(ERROR_SERVER, "Persistly profile response is missing profileSessionToken.")
	if typeof(response.get("profile", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly profile response is missing profile.")

	var profile := _normalize_save(response["profile"], cache_result)
	if profile.has("error"):
		return profile
	var profile_state = profile.get("state", {})
	if typeof(profile_state) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly profile state must be a dictionary.")
	if profile_state.get("schema", "") != "persistly.profile.v1":
		return _error_result(ERROR_SERVER, "Persistly profile state has an unsupported schema.")
	if typeof(profile_state.get("accountData", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly profile state is missing accountData.")
	if typeof(profile_state.get("characterSlots", null)) != TYPE_ARRAY:
		return _error_result(ERROR_SERVER, "Persistly profile state is missing characterSlots.")

	var normalized: Dictionary = {
		"profileSaveId": String(response["profileSaveId"]),
		"profile": profile,
	}
	if response.has("profileSessionToken"):
		normalized["profileSessionToken"] = String(response["profileSessionToken"])
	if response.has("syncPolicy"):
		if typeof(response["syncPolicy"]) != TYPE_DICTIONARY:
			return _error_result(ERROR_SERVER, "Persistly profile response syncPolicy must be a dictionary.")
		normalized["syncPolicy"] = (response["syncPolicy"] as Dictionary).duplicate(true)
	if response.has("character"):
		if typeof(response["character"]) != TYPE_DICTIONARY:
			return _error_result(ERROR_SERVER, "Persistly profile response character must be a dictionary.")
		var character := _normalize_save(response["character"], cache_result)
		if character.has("error"):
			return character
		normalized["character"] = character
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
		_drafts[String(draft.get("characterSaveId", ""))] = draft.duplicate(true)

	func load_draft(character_save_id: String) -> Dictionary:
		if not _drafts.has(character_save_id):
			return {}
		return (_drafts[character_save_id] as Dictionary).duplicate(true)

	func clear_draft(character_save_id: String) -> void:
		_drafts.erase(character_save_id)


class PersistlyFileAutosaveDraftStore:
	var root_path: String

	func _init(root_path_value: String = "user://persistly_autosave") -> void:
		root_path = root_path_value.rstrip("/")
		DirAccess.make_dir_recursive_absolute(root_path)

	func store_draft(draft: Dictionary) -> void:
		var character_save_id := String(draft.get("characterSaveId", ""))
		if character_save_id.is_empty():
			return
		var file := FileAccess.open(_draft_path(character_save_id), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(draft))
			file.close()

	func load_draft(character_save_id: String) -> Dictionary:
		var path := _draft_path(character_save_id)
		if not FileAccess.file_exists(path):
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			return {}
		return (parsed as Dictionary).duplicate(true)

	func clear_draft(character_save_id: String) -> void:
		var path := _draft_path(character_save_id)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	func _draft_path(character_save_id: String) -> String:
		return root_path.path_join(character_save_id.uri_encode() + ".json")


class PersistlyAutosaveManager:
	var draft_store: Variant
	var sync_policy: Dictionary
	var _last_remote_sync_msec: Dictionary = {}

	func _init(draft_store_value: Variant, sync_policy_value: Dictionary) -> void:
		draft_store = draft_store_value
		sync_policy = sync_policy_value.duplicate(true)

	func record_local_change(profile_save_id: String, profile_session_token: String, character_save_id: String, metadata: Dictionary, state: Dictionary, base_version: Variant = null) -> Dictionary:
		var draft := {
			"profileSaveId": profile_save_id,
			"profileSessionToken": profile_session_token,
			"characterSaveId": character_save_id,
			"metadata": metadata.duplicate(true),
			"state": state.duplicate(true),
			"baseVersion": base_version,
			"updatedAtMsec": Time.get_ticks_msec(),
		}
		draft_store.store_draft(draft)
		return draft

	func should_sync_remote(character_save_id: String, force: bool = false) -> bool:
		if draft_store.load_draft(character_save_id).is_empty():
			return false
		if not _last_remote_sync_msec.has(character_save_id):
			return true

		var elapsed_seconds := float(Time.get_ticks_msec() - int(_last_remote_sync_msec[character_save_id])) / 1000.0
		if force:
			return elapsed_seconds >= float(sync_policy.get("forceSyncCooldownSeconds", 10))
		return elapsed_seconds >= float(sync_policy.get("minRemoteSyncIntervalSeconds", 60))

	func mark_remote_synced(character_save_id: String) -> void:
		_last_remote_sync_msec[character_save_id] = Time.get_ticks_msec()
		draft_store.clear_draft(character_save_id)
