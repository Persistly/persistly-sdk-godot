extends RefCounted
class_name PersistlyClient

const SDK_VERSION := "0.9.1"
const BUNDLE_VERSION := "persistly-contract-v0.2.0"
const BUNDLE_ROOT := "res://contracts/persistly-contract-v0.2.0"
const DEFAULT_BASE_URL := "https://api.persistly.app"
const DEFAULT_TIMEOUT_SECONDS := 30.0
const METADATA_MAX_BYTES := 16384
const STATE_MAX_BYTES := 262144

const ERROR_INVALID_REQUEST := "invalid_request"
const ERROR_UNAUTHORIZED := "unauthorized"
const ERROR_FORBIDDEN := "forbidden"
const ERROR_NOT_FOUND := "not_found"
const ERROR_CONFLICT := "conflict"
const ERROR_RATE_LIMITED := "rate_limited"
const ERROR_PAYLOAD_TOO_LARGE := "payload_too_large"
const ERROR_SERVER := "server_error"

var base_url: String
var runtime_key: String
var timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS

var _save_cache: Dictionary = {}
var _fixture_responses: Dictionary = {}


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

	var base_version := payload.get("baseVersion", null)
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

	var status = String(response.get("status", ""))
	if status != "accepted" and status != "conflict":
		return _error_result(ERROR_SERVER, "sync_save returned an unexpected status.")

	var normalized := _normalize_save_envelope(response, true)
	if normalized.has("error"):
		return normalized

	if status == "conflict":
		var details = normalized.get("details", {})
		if typeof(details) != TYPE_DICTIONARY or String(details.get("reason", "")) != "base_version_mismatch":
			return _error_result(ERROR_SERVER, "sync_save conflict response is missing a valid reason.")

	return normalized


func create_profile(payload: Dictionary) -> Dictionary:
	var preflight := _validate_runtime_configuration("create_profile")
	if not preflight.is_empty():
		return preflight

	var account_data := payload.get("accountData", {})
	var profile_metadata := payload.get("profileMetadata", {})
	var character_metadata := payload.get("characterMetadata", {})
	var character_state := payload.get("characterState", null)
	if typeof(account_data) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile accountData must be a dictionary.")
	if typeof(profile_metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile profileMetadata must be a dictionary when provided.")
	if typeof(character_metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile characterMetadata must be a dictionary.")
	if typeof(character_state) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile requires a dictionary characterState payload.")

	var profile_payload_error := _validate_payload_sizes(profile_metadata, account_data)
	if not profile_payload_error.is_empty():
		return profile_payload_error
	var character_payload_error := _validate_payload_sizes(character_metadata, character_state)
	if not character_payload_error.is_empty():
		return character_payload_error

	var request_body: Dictionary = {
		"accountData": account_data,
		"profileMetadata": profile_metadata,
		"characterMetadata": character_metadata,
		"characterState": character_state,
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

	var response := _request_json("POST", "/api/v1/profiles", request_body)
	if response.has("error"):
		return response

	return _normalize_create_profile_response(response, true)


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

	return _normalize_profile_envelope(response, true)


func create_profile_character(profile_save_id: String, profile_session_token: String, payload: Dictionary) -> Dictionary:
	var preflight := _validate_profile_session_configuration("create_profile_character", profile_save_id, profile_session_token)
	if not preflight.is_empty():
		return preflight

	var character_metadata := payload.get("characterMetadata", {})
	var character_state := payload.get("characterState", null)
	if typeof(character_metadata) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile_character characterMetadata must be a dictionary.")
	if typeof(character_state) != TYPE_DICTIONARY:
		return _error_result(ERROR_INVALID_REQUEST, "create_profile_character requires a dictionary characterState payload.")

	var payload_error := _validate_payload_sizes(character_metadata, character_state)
	if not payload_error.is_empty():
		return payload_error

	var response := _request_json(
		"POST",
		"/api/v1/profiles/" + _url_encode(profile_save_id) + "/characters",
		{
			"characterMetadata": character_metadata,
			"characterState": character_state,
		},
		profile_session_token)
	if response.has("error"):
		return response

	return _normalize_character_envelope(response, true)


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

	var base_version := payload.get("baseVersion", null)
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

	return _normalize_sync_response(response, true, "sync_profile_character")


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

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
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

	var normalized := _duplicate_dictionary(response)
	var normalized_save := _duplicate_dictionary(save)
	normalized_save["version"] = int(save["version"])
	normalized["save"] = normalized_save
	if cache_result:
		_save_cache[String(save["saveId"])] = normalized_save.duplicate(true)
	return normalized


func _normalize_sync_response(response: Dictionary, cache_result: bool, label: String) -> Dictionary:
	var status = String(response.get("status", ""))
	if status != "accepted" and status != "conflict":
		return _error_result(ERROR_SERVER, label + " returned an unexpected status.")

	var normalized := _normalize_save_envelope(response, cache_result)
	if normalized.has("error"):
		return normalized

	if status == "conflict":
		var details = normalized.get("details", {})
		if typeof(details) != TYPE_DICTIONARY or String(details.get("reason", "")) != "base_version_mismatch":
			return _error_result(ERROR_SERVER, label + " conflict response is missing a valid reason.")

	return normalized


func _normalize_create_profile_response(response: Dictionary, cache_result: bool) -> Dictionary:
	if typeof(response.get("profile", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "create_profile response is missing profile.")
	if typeof(response.get("character", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "create_profile response is missing character.")

	var profile := _normalize_profile_envelope(response["profile"], cache_result)
	if profile.has("error"):
		return profile
	var character := _normalize_character_envelope(response["character"], cache_result)
	if character.has("error"):
		return character

	return {
		"profile": profile,
		"character": character,
	}


func _normalize_profile_envelope(response: Dictionary, cache_result: bool) -> Dictionary:
	var envelope := response
	if typeof(response.get("profile", null)) == TYPE_DICTIONARY:
		envelope = response["profile"]

	if typeof(envelope.get("profileSaveId", null)) != TYPE_STRING or String(envelope.get("profileSaveId", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly profile envelope is missing profileSaveId.")
	if typeof(envelope.get("profileSessionToken", null)) != TYPE_STRING or String(envelope.get("profileSessionToken", "")).is_empty():
		return _error_result(ERROR_SERVER, "Persistly profile envelope is missing profileSessionToken.")
	if typeof(envelope.get("save", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly profile envelope is missing save.")

	var normalized_save := _normalize_save_envelope({"save": envelope["save"]}, cache_result)
	if normalized_save.has("error"):
		return normalized_save

	var normalized := _duplicate_dictionary(envelope)
	normalized["save"] = normalized_save["save"]
	return normalized


func _normalize_character_envelope(response: Dictionary, cache_result: bool) -> Dictionary:
	var envelope := response
	if typeof(response.get("character", null)) == TYPE_DICTIONARY:
		envelope = response["character"]
	if typeof(envelope.get("save", null)) != TYPE_DICTIONARY:
		return _error_result(ERROR_SERVER, "Persistly character envelope is missing save.")

	var normalized_save := _normalize_save_envelope({"save": envelope["save"]}, cache_result)
	if normalized_save.has("error"):
		return normalized_save
	return {
		"save": normalized_save["save"],
	}


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
