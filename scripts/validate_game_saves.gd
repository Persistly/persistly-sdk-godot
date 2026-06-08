extends SceneTree

const GAME_SAVES_SCRIPT := "res://addons/persistly/persistly_game_saves.gd"

const SYNC_POLICY := {
	"minRemoteSyncIntervalSeconds": 60,
	"forceSyncCooldownSeconds": 10,
	"syncOnAppBackground": true,
	"syncOnAppForeground": true,
	"syncOnReconnect": true,
	"maxQueuedLocalSnapshots": 25,
}

const ACCOUNT := {
	"accountId": "acc_test",
	"accountData": {
		"diamonds": 20,
	},
	"slots": [],
	"version": 1,
	"updatedAt": "2026-05-29T10:00:00Z",
}

const SLOT := {
	"slotId": "autosave",
	"slotInfo": {
		"characterName": "Ayla",
		"level": 5,
	},
	"data": {
		"level": 5,
		"coins": 1200,
	},
	"version": 1,
	"updatedAt": "2026-05-29T10:01:00Z",
}

var _failure_count := 0
var _run_storage_prefix := "user://persistly_validation/run_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())


func _initialize() -> void:
	var game_saves_script := load(GAME_SAVES_SCRIPT)
	if game_saves_script == null or not game_saves_script.can_instantiate():
		_fail("Could not load game saves facade at " + GAME_SAVES_SCRIPT)
		_finish()
		return

	_check_status_and_target_constants(game_saves_script)
	_check_account_first_facade_surface(game_saves_script)
	_check_local_slot_flow(game_saves_script)
	_check_first_sync_creates_account_and_slot(game_saves_script)
	_check_account_data_sync(game_saves_script)
	_check_transfer_code_facade(game_saves_script)
	_check_auth_required_mode(game_saves_script)
	_check_auth_facade_session_flow(game_saves_script)
	_check_auth_conflict_mapping(game_saves_script)
	_check_clear_and_delete_boundaries(game_saves_script)
	_check_reserved_slot_info_rejected(game_saves_script)
	_finish()


func _check_status_and_target_constants(game_saves_script: Script) -> void:
	_expect_equal(game_saves_script.DEFAULT_SLOT_KEY, "autosave", "PersistlyGameSaves.DEFAULT_SLOT_KEY")
	var target = game_saves_script.PersistlyGameSaveTarget
	_expect_equal(target.ACCOUNT, "account", "PersistlyGameSaveTarget.ACCOUNT")
	_expect_equal(target.SLOT, "slot", "PersistlyGameSaveTarget.SLOT")
	var account_mode = game_saves_script.PersistlyAccountMode
	_expect_equal(account_mode.ANONYMOUS_FIRST, "anonymousFirst", "PersistlyAccountMode.ANONYMOUS_FIRST")
	_expect_equal(account_mode.AUTH_REQUIRED, "authRequired", "PersistlyAccountMode.AUTH_REQUIRED")
	var status = game_saves_script.PersistlyGameSaveStatus
	_expect_equal(status.AUTH_REQUIRED, "auth_required", "PersistlyGameSaveStatus.AUTH_REQUIRED")


func _check_account_first_facade_surface(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	for method_name in [
		"create_account",
		"attach_account",
		"create_transfer_code",
		"attach_with_transfer_code",
		"get_account_session",
		"sign_in_with_firebase_token",
		"sign_in_with_provider",
		"link_provider",
		"list_linked_providers",
		"sign_out",
		"force_sync_account",
		"sync_due_account",
		"clear_local_account",
		"delete_account",
		"save_slot",
		"load_slot",
		"list_slot_data",
		"slot_info",
	]:
		if not persistly.has_method(method_name):
			_fail("PersistlyGameSaves should expose account-first method " + method_name + ".")
	for legacy_method_name in [
		"create_profile",
		"attach_profile",
		"get_profile_session",
		"force_sync_profile",
		"sync_due_profile",
		"clear_local_profile",
		"delete_profile",
		"list_slots",
		"inspect_profile",
	]:
		if persistly.has_method(legacy_method_name):
			_fail("PersistlyGameSaves should not expose release profile compatibility method " + legacy_method_name + ".")


func _check_local_slot_flow(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	var configured: Dictionary = persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"playerRef": "player-184",
		"externalAccountRef": {
			"provider": "auth0",
			"subject": "auth0|user_123",
		},
		"localAccountKey": "validation-local-flow",
		"storage_path": _storage_path("local_flow"),
	})
	_expect_equal(configured.get("status", ""), "configured", "configure status")
	_expect_equal(configured.get("accountMode", ""), "anonymousFirst", "configure default accountMode")
	_expect_equal(configured.get("localAccountKey", ""), "validation-local-flow", "configure localAccountKey")

	var saved: Dictionary = persistly.save_slot("autosave", {
		"level": 5,
		"coins": 1200,
	}, {
		"slotInfo": {
			"characterName": "Ayla",
			"level": 5,
		},
	})
	_expect_equal(saved.get("status", ""), "local_saved", "save_slot status")
	_expect_equal(saved.get("slotId", ""), "autosave", "save_slot slotId")
	_expect_dictionary(saved.get("data", {}), SLOT["data"], "save_slot data")
	_expect_dictionary(saved.get("slotInfo", {}), SLOT["slotInfo"], "save_slot slotInfo")
	_expect_facade_slot_terms(saved, "save_slot")

	var loaded: Dictionary = persistly.load_slot("autosave")
	_expect_equal(loaded.get("status", ""), "local_found", "load_slot status")
	_expect_dictionary(loaded.get("data", {}), SLOT["data"], "load_slot data")
	_expect_facade_slot_terms(loaded, "load_slot")
	var loaded_data: Dictionary = persistly.load_data()
	_expect_dictionary(loaded_data.get("data", {}), SLOT["data"], "load_data data")
	_expect_facade_slot_terms(loaded_data, "load_data")

	var listed: Array = persistly.list_slot_data()
	if listed.size() != 1 or listed[0].get("slotId", "") != "autosave":
		_fail("list_slot_data should return active local slots.")
	else:
		_expect_facade_slot_terms(listed[0], "list_slot_data")

	var info: Dictionary = persistly.slot_info("autosave")
	_expect_dictionary(info.get("slotInfo", {}), SLOT["slotInfo"], "slot_info slotInfo")


func _check_first_sync_creates_account_and_slot(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"playerRef": "player-184",
		"localAccountKey": "validation-first-sync",
		"storage_path": _storage_path("first_sync"),
	})
	persistly._client.register_fixture_response("POST", "/api/v1/accounts", 201, {
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"account": _account_with_slot("autosave"),
		"slot": SLOT,
		"syncPolicy": SYNC_POLICY,
	})

	persistly.save_data(SLOT["data"], {
		"slotInfo": SLOT["slotInfo"],
	})
	var synced: Dictionary = persistly.force_sync_data({
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "force_sync_data status")
	_expect_equal(synced.get("slotId", ""), "autosave", "force_sync_data slotId")
	_expect_equal(persistly.get_account_session({"includeToken": true}).get("accountId", ""), "acc_test", "get_account_session accountId")
	_expect_equal(persistly.get_account_session({"includeToken": true}).get("accountSessionToken", ""), "pst_account_session", "get_account_session token")

	var request: Dictionary = persistly._client.get_recorded_requests()[0]
	_expect_equal(request.get("path", ""), "/api/v1/accounts", "first sync route")
	if str(request.get("body", {})).find("_persistly") >= 0:
		_fail("Facade account create request should not expose _persistly slotInfo.")
	_expect_facade_request_terms(request.get("body", {}), "force_sync_data")


func _check_account_data_sync(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"localAccountKey": "validation-account-sync",
		"storage_path": _storage_path("account_sync"),
	})
	persistly.account_version = 1
	persistly._client.register_fixture_response("POST", "/api/v1/accounts/acc_test/data/sync", 200, {
		"status": "accepted",
		"version": 2,
		"updatedAt": "2026-05-29T10:04:00Z",
		"historyRetained": true,
	})

	persistly.save_account_data({
		"diamonds": 20,
	})
	persistly.patch_account_data({
		"diamonds": 30,
		"obsolete": null,
	})
	_expect_equal(persistly.get_account_data().get("diamonds", 0), 30, "patch_account_data")
	var synced: Dictionary = persistly.force_sync_account({
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "force_sync_account status")
	_expect_equal(synced.get("target", ""), "account", "force_sync_account target")

	var request: Dictionary = persistly._client.get_recorded_requests()[0]
	_expect_equal(request.get("path", ""), "/api/v1/accounts/acc_test/data/sync", "account sync route")
	_expect_has_account_session_header(request)


func _check_transfer_code_facade(game_saves_script: Script) -> void:
	var source: Object = game_saves_script.new()
	source.configure({
		"runtime_key": "ps_test_replace_me",
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"localAccountKey": "validation-transfer-source",
		"storage_path": _storage_path("transfer_source"),
	})
	source._client.register_fixture_response("POST", "/api/v1/accounts/acc_test/transfer-codes", 200, {
		"transferCode": "P7K2D-M9Q4R",
		"expiresAt": "2026-06-01T12:10:00Z",
		"expiresInSeconds": 600,
	})
	var created_code: Dictionary = source.create_transfer_code({
		"deviceLabel": "Steam Deck",
		"ttlSeconds": 600,
	})
	_expect_equal(created_code.get("transferCode", ""), "P7K2D-M9Q4R", "facade create_transfer_code")
	_expect_has_account_session_header(source._client.get_recorded_requests()[0])

	var target: Object = game_saves_script.new()
	target.configure({
		"runtime_key": "ps_test_replace_me",
		"localAccountKey": "validation-transfer-target",
		"storage_path": _storage_path("transfer_target"),
	})
	target._client.register_fixture_response("POST", "/api/v1/account-transfer-codes/consume", 200, {
		"accountId": "acc_test",
		"accountSessionToken": "pst_new_session",
		"account": _account_with_slot("autosave"),
		"syncPolicy": SYNC_POLICY,
	})
	var attached: Dictionary = target.attach_with_transfer_code("P7K2D-M9Q4R", {
		"deviceLabel": "Laptop",
	})
	_expect_equal(attached.get("status", ""), "synced", "attach_with_transfer_code status")
	_expect_equal(target.get_account_session({"includeToken": true}).get("accountId", ""), "acc_test", "attach_with_transfer_code accountId")
	_expect_equal(target.get_account_session({"includeToken": true}).get("accountSessionToken", ""), "pst_new_session", "attach_with_transfer_code token")
	_expect_equal(target.slot_info("autosave").get("slotInfo", {}).get("level", 0), 5, "attach_with_transfer_code slot ref")
	var recorded := JSON.stringify(target._client.get_recorded_requests())
	if recorded.find("P7K2D-M9Q4R") >= 0 or recorded.find("pst_new_session") >= 0:
		_fail("attach_with_transfer_code should not record raw transfer codes or account session tokens.")

	var non_empty: Object = game_saves_script.new()
	non_empty.configure({
		"runtime_key": "ps_test_replace_me",
		"localAccountKey": "validation-transfer-non-empty",
		"storage_path": _storage_path("transfer_non_empty"),
	})
	non_empty.save_slot("autosave", {"level": 1})
	var rejected: Dictionary = non_empty.attach_with_transfer_code("P7K2D-M9Q4R")
	_expect_equal(rejected.get("error", {}).get("code", ""), "invalid_request", "attach_with_transfer_code rejects non-empty local state")


func _check_auth_required_mode(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	var configured: Dictionary = persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountMode": "authRequired",
		"localAccountKey": "validation-auth-required",
		"storage_path": _storage_path("auth_required"),
	})
	_expect_equal(configured.get("accountMode", ""), "authRequired", "authRequired configure accountMode")

	var saved: Dictionary = persistly.save_data(SLOT["data"], {
		"slotInfo": SLOT["slotInfo"],
	})
	_expect_equal(saved.get("status", ""), "local_saved", "authRequired save_data remains local")

	var synced: Dictionary = persistly.force_sync_data({
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "auth_required", "authRequired force_sync_data before sign-in")
	_expect_equal(synced.get("error", {}).get("code", ""), "auth_required", "authRequired force_sync_data error code")
	if persistly._client.get_recorded_requests().size() != 0:
		_fail("authRequired force_sync_data before sign-in must not create an anonymous remote account.")


func _check_auth_facade_session_flow(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountMode": "authRequired",
		"localAccountKey": "validation-auth-session",
		"storage_path": _storage_path("auth_session"),
	})
	persistly.save_data(SLOT["data"], {
		"slotInfo": SLOT["slotInfo"],
	})
	persistly._client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 200, {
		"accountId": "acc_auth",
		"accountSessionToken": "pst_auth_session",
		"isNewAccount": true,
		"linkedProvider": "firebase",
		"wasProviderNewForAccount": true,
	})
	persistly._client.register_fixture_response("GET", "/api/v1/accounts/auth/providers", 200, [
		{
			"provider": "firebase",
			"display": {
				"label": "Firebase",
				"emailHint": "a***@example.com",
			},
			"linkedAt": "2026-06-06T00:00:00Z",
		},
	])
	persistly._client.register_fixture_response("POST", "/api/v1/accounts/acc_auth/slots", 201, {
		"accountId": "acc_auth",
		"account": _account_with_slot("autosave"),
		"slot": SLOT,
	})

	var unsupported_provider: Dictionary = persistly.sign_in_with_provider({
		"provider": "google",
		"token": "unsupported-token",
	})
	_expect_equal(unsupported_provider.get("error", {}).get("code", ""), "invalid_request", "sign_in_with_provider rejects non-Firebase provider")
	if persistly._client.get_recorded_requests().size() != 0:
		_fail("Unsupported auth provider should be rejected before recording a request.")

	var signed_in: Dictionary = persistly.sign_in_with_firebase_token("firebase-id-token", {
		"deviceLabel": "Steam Deck",
	})
	_expect_equal(signed_in.get("status", ""), "synced", "sign_in_with_firebase_token status")
	_expect_equal(signed_in.get("accountId", ""), "acc_auth", "sign_in_with_firebase_token accountId")
	_expect_equal(persistly.get_account_session({"includeToken": true}).get("accountSessionToken", ""), "pst_auth_session", "sign-in stores accountSessionToken")

	var providers: Dictionary = persistly.list_linked_providers()
	var rows: Array = providers.get("providers", [])
	if rows.size() != 1 or rows[0].get("provider", "") != "firebase":
		_fail("list_linked_providers should return linked Firebase provider.")

	var synced: Dictionary = persistly.force_sync_data({
		"bypassCooldown": true,
	})
	_expect_equal(synced.get("status", ""), "synced", "force_sync_data after sign-in status")

	var requests: Array = persistly._client.get_recorded_requests()
	_expect_equal(requests[0].get("path", ""), "/api/v1/accounts/auth/session", "sign-in auth route")
	_expect_equal(requests[1].get("path", ""), "/api/v1/accounts/auth/providers", "list providers route")
	_expect_equal(requests[2].get("path", ""), "/api/v1/accounts/acc_auth/slots", "signed-in slot create route")
	_expect_has_account_id_header(requests[1])
	_expect_has_account_session_header(requests[2])
	if JSON.stringify(requests).find("firebase-id-token") >= 0 or JSON.stringify(requests).find("pst_auth_session") >= 0:
		_fail("Auth facade recorded requests should redact provider tokens and account sessions.")

	var signed_out: Dictionary = persistly.sign_out()
	_expect_equal(signed_out.get("status", ""), "local_saved", "sign_out status")
	_expect_equal(persistly.get_account_session({"includeToken": true}).get("accountId", ""), "", "sign_out clears accountId")
	_expect_equal(persistly.load_data().get("status", ""), "not_found", "sign_out clears slots")


func _check_auth_conflict_mapping(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountId": "acc_local",
		"accountSessionToken": "pst_local_session",
		"localAccountKey": "validation-auth-conflict",
		"storage_path": _storage_path("auth_conflict"),
	})
	persistly._client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 409, {
		"error": {
			"code": "account_auth_conflict",
			"message": "This identity is already linked to another Persistly account.",
			"localAccount": {
				"hasSlots": true,
				"slotCount": 1,
			},
			"authenticatedAccount": {
				"hasSlots": true,
				"slotCount": 2,
			},
		},
	})

	var conflict: Dictionary = persistly.link_provider({
		"provider": "firebase",
		"token": "conflict-token",
	})
	_expect_equal(conflict.get("status", ""), "account_auth_conflict", "link_provider conflict status")
	_expect_equal(conflict.get("error", {}).get("code", ""), "account_auth_conflict", "link_provider conflict error code")
	_expect_equal(persistly.get_account_session({"includeToken": true}).get("accountId", ""), "acc_local", "link_provider conflict keeps local account")
	var request: Dictionary = persistly._client.get_recorded_requests()[0]
	_expect_has_account_id_header(request)
	_expect_has_account_session_header(request)


func _check_clear_and_delete_boundaries(game_saves_script: Script) -> void:
	var local_only: Object = game_saves_script.new()
	local_only.configure({
		"runtime_key": "ps_test_replace_me",
		"localAccountKey": "validation-clear",
		"storage_path": _storage_path("clear"),
	})
	local_only.save_slot("autosave", {"level": 1})
	var cleared: Dictionary = local_only.clear_local_account()
	_expect_equal(cleared.get("status", ""), "local_saved", "clear_local_account status")
	_expect_equal(local_only.load_slot("autosave").get("status", ""), "not_found", "clear_local_account removes slots")

	var remote: Object = game_saves_script.new()
	remote.configure({
		"runtime_key": "ps_test_replace_me",
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"localAccountKey": "validation-delete",
		"storage_path": _storage_path("delete"),
	})
	remote._client.register_fixture_response("DELETE", "/api/v1/accounts/acc_test", 200, {
		"accountId": "acc_test",
		"deletedAt": "2026-05-29T10:05:00Z",
		"deletedSlotCount": 1,
		"alreadyDeleted": false,
		"cleanupQueued": true,
	})
	var deleted: Dictionary = remote.delete_account()
	_expect_equal(deleted.get("status", ""), "synced", "delete_account status")
	_expect_equal(remote.get_account_session({"includeToken": true}).get("accountId", ""), "", "delete_account clears account session")


func _check_reserved_slot_info_rejected(game_saves_script: Script) -> void:
	var persistly: Object = game_saves_script.new()
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"localAccountKey": "validation-reserved",
		"storage_path": _storage_path("reserved"),
	})
	var result: Dictionary = persistly.save_slot("autosave", {"level": 1}, {
		"slotInfo": {
			"_persistly": {
				"slotId": "autosave",
			},
		},
	})
	_expect_equal(result.get("status", ""), "invalid_request", "save_slot rejects reserved slotInfo")
	var message := String(result.get("error", {}).get("message", ""))
	if message.find("slotInfo") < 0 or message.find("metadata") >= 0:
		_fail("Reserved slotInfo error should use slotInfo wording, got: " + message)


func _account_with_slot(slot_id: String) -> Dictionary:
	return {
		"accountId": "acc_test",
		"accountData": ACCOUNT["accountData"],
		"slots": [
			{
				"slotId": slot_id,
				"slotInfo": SLOT["slotInfo"],
				"version": 1,
				"status": "active",
				"updatedAt": "2026-05-29T10:01:00Z",
			},
		],
		"version": 1,
		"updatedAt": "2026-05-29T10:01:00Z",
	}


func _expect_has_account_session_header(request: Dictionary) -> void:
	var headers: Array = request.get("headers", [])
	for header in headers:
		if String(header).begins_with("X-Persistly-Account-Session:"):
			return
	_fail("Request should include X-Persistly-Account-Session.")


func _expect_has_account_id_header(request: Dictionary) -> void:
	var headers: Array = request.get("headers", [])
	for header in headers:
		if String(header).begins_with("X-Persistly-Account-ID:"):
			return
	_fail("Request should include X-Persistly-Account-ID.")


func _expect_facade_request_terms(body: Variant, label: String) -> void:
	var body_text := JSON.stringify(body)
	for forbidden in ["metadata", "state", "saveId", "_persistly"]:
		if body_text.find(forbidden) >= 0:
			_fail(label + " request should not contain raw " + forbidden + " fields.")


func _expect_facade_slot_terms(slot_result: Dictionary, label: String) -> void:
	if not slot_result.has("data"):
		_fail(label + " result should expose playable save content as data.")
	if not slot_result.has("slotInfo"):
		_fail(label + " result should expose slot preview values as slotInfo.")
	for forbidden in ["metadata", "state", "saveId"]:
		if slot_result.has(forbidden):
			_fail(label + " result should not expose raw " + forbidden + " fields.")


func _storage_path(name: String) -> String:
	return _run_storage_prefix.path_join(name)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail(label + " expected " + str(expected) + " but got " + str(actual) + ".")


func _expect_dictionary(actual: Variant, expected: Dictionary, label: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail(label + " expected dictionary but got " + str(actual) + ".")
		return
	for key in expected.keys():
		if not (actual as Dictionary).has(key) or (actual as Dictionary)[key] != expected[key]:
			_fail(label + " expected " + JSON.stringify(expected) + " but got " + JSON.stringify(actual) + ".")
			return


func _fail(message: String) -> void:
	_failure_count += 1
	push_error(message)


func _finish() -> void:
	if _failure_count == 0:
		print("Persistly game saves facade validation passed.")
		quit(0)
	else:
		push_error("Persistly game saves facade validation failed with " + str(_failure_count) + " failure(s).")
		quit(1)
