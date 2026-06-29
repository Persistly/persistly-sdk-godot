extends SceneTree

const CLIENT_SCRIPT := "res://addons/persistly/persistly_client.gd"
const RUNTIME_KEY := "ps_test_local"

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
		"level": 1,
	},
	"data": {
		"gold": 100,
		"level": 1,
	},
	"version": 1,
	"updatedAt": "2026-05-29T10:01:00Z",
}

var _failure_count := 0


func _initialize() -> void:
	var client_script := load(CLIENT_SCRIPT)
	if client_script == null:
		_fail("Could not load client script at " + CLIENT_SCRIPT)
		_finish()
		return

	var client: Object = client_script.new(RUNTIME_KEY)
	_seed_fixture_responses(client)
	_check_versions(client_script)
	_check_account_first_surface(client, client_script)
	_check_no_raw_save_transport(client, CLIENT_SCRIPT)
	_check_account_routes(client)
	_check_transfer_code_routes(client)
	_check_auth_routes(client, client_script)
	_check_slot_routes(client, client_script)
	_check_runtime_config(client)
	_check_error_mapping(client, client_script)
	_finish()


func _check_versions(client_script: GDScript) -> void:
	_expect_equal(client_script.SDK_VERSION, "1.2.0", "SDK_VERSION")
	_expect_equal(client_script.BUNDLE_VERSION, "persistly-contract-v0.4.0", "BUNDLE_VERSION")
	_expect_equal(client_script.ERROR_ACCOUNT_DELETED, "account_deleted", "ERROR_ACCOUNT_DELETED")
	_expect_equal(client_script.ERROR_SLOT_DELETED, "slot_deleted", "ERROR_SLOT_DELETED")
	_expect_equal(client_script.ERROR_SLOT_ARCHIVED, "slot_archived", "ERROR_SLOT_ARCHIVED")
	_expect_equal(client_script.ERROR_MONTHLY_QUOTA_EXCEEDED, "monthly_quota_exceeded", "ERROR_MONTHLY_QUOTA_EXCEEDED")
	_expect_equal(client_script.ERROR_AUTH_REQUIRED, "auth_required", "ERROR_AUTH_REQUIRED")
	_expect_equal(client_script.ERROR_PROVIDER_TOKEN_INVALID, "provider_token_invalid", "ERROR_PROVIDER_TOKEN_INVALID")
	_expect_equal(client_script.ERROR_FIREBASE_PROJECT_MISMATCH, "firebase_project_mismatch", "ERROR_FIREBASE_PROJECT_MISMATCH")
	_expect_equal(client_script.ERROR_AUTH_PROVIDER_NOT_CONFIGURED, "auth_provider_not_configured", "ERROR_AUTH_PROVIDER_NOT_CONFIGURED")
	_expect_equal(client_script.ERROR_ACCOUNT_AUTH_CONFLICT, "account_auth_conflict", "ERROR_ACCOUNT_AUTH_CONFLICT")


func _check_account_first_surface(client: Object, _client_script: GDScript) -> void:
	for method_name in [
		"create_account",
		"load_account",
		"sync_account_data",
		"create_transfer_code",
		"consume_transfer_code",
		"create_account_slot",
		"load_account_slot",
		"sync_account_slot",
		"archive_account_slot",
		"delete_account_slot",
		"delete_account",
		"create_auth_session",
		"list_linked_providers",
	]:
		if not client.has_method(method_name):
			_fail("PersistlyClient should expose account-first method " + method_name + ".")
	for legacy_method_name in [
		"create_save",
		"load_save",
		"sync_save",
		"create_profile",
		"load_profile",
		"sync_profile_account_data",
		"create_profile_character",
		"load_profile_character",
		"sync_profile_character",
		"archive_profile_character",
		"delete_profile_character",
		"delete_profile",
	]:
		if client.has_method(legacy_method_name):
			_fail("PersistlyClient should not expose release profile compatibility method " + legacy_method_name + ".")


func _check_no_raw_save_transport(client: Object, client_script_path: String) -> void:
	for raw_method_name in ["create_save", "load_save", "sync_save"]:
		if client.has_method(raw_method_name):
			_fail("PersistlyClient should not expose raw save method " + raw_method_name + ".")

	var source_text := FileAccess.get_file_as_string(client_script_path)
	for forbidden_route in ["/api/v1/saves", "/api/v1/saves/", "/sync_save"]:
		if source_text.find(forbidden_route) >= 0:
			_fail("PersistlyClient release source should not contain raw save transport string " + forbidden_route + ".")


func _check_account_routes(client: Object) -> void:
	var created: Dictionary = client.create_account({
		"playerRef": "player-184",
		"externalAccountRef": {
			"provider": "auth0",
			"subject": "auth0|user_123",
		},
		"accountData": {
			"diamonds": 20,
		},
		"slot": {
			"slotId": "autosave",
			"slotInfo": SLOT["slotInfo"],
			"data": SLOT["data"],
		},
	})
	_expect_equal(created.get("accountId", ""), "acc_test", "create_account accountId")
	_expect_equal(created.get("accountSessionToken", ""), "pst_account_session", "create_account accountSessionToken")
	_expect_dictionary(created.get("account", {}).get("accountData", {}), ACCOUNT["accountData"], "create_account accountData")
	_expect_dictionary(created.get("slot", {}).get("slotInfo", {}), SLOT["slotInfo"], "create_account slotInfo")

	var loaded: Dictionary = client.load_account("acc_test", "pst_account_session")
	_expect_equal(loaded.get("account", {}).get("accountId", ""), "acc_test", "load_account accountId")

	var synced: Dictionary = client.sync_account_data("acc_test", "pst_account_session", {
		"baseVersion": 1,
		"accountDataPatch": {
			"diamonds": 30,
			"obsolete": null,
		},
	})
	_expect_equal(synced.get("status", ""), "accepted", "sync_account_data status")
	_expect_equal(synced.get("account", {}).get("accountData", {}).get("diamonds", 0), 30, "sync_account_data synthesized patch")

	var deleted: Dictionary = client.delete_account("acc_test", "pst_account_session")
	_expect_equal(deleted.get("deletedSlotCount", -1), 1, "delete_account deletedSlotCount")

	var requests: Array = client.get_recorded_requests()
	_expect_request(requests[0], "POST", "/api/v1/accounts", false)
	_expect_request(requests[1], "GET", "/api/v1/accounts/acc_test", true)
	_expect_request(requests[2], "POST", "/api/v1/accounts/acc_test/data/sync", true)
	_expect_request(requests[3], "DELETE", "/api/v1/accounts/acc_test", true)
	if str(requests[0].get("body", {})).find("_persistly") >= 0:
		_fail("create_account request should not expose _persistly slotInfo.")
	_expect_facade_body_terms(requests[0].get("body", {}), "create_account")
	_expect_facade_body_terms(requests[2].get("body", {}), "sync_account_data")
	client.clear_recorded_requests()


func _check_transfer_code_routes(client: Object) -> void:
	var created_code: Dictionary = client.create_transfer_code("acc_test", "pst_account_session", {
		"deviceLabel": "Steam Deck",
		"ttlSeconds": 600,
	})
	_expect_equal(created_code.get("transferCode", ""), "P7K2D-M9Q4R", "create_transfer_code transferCode")
	_expect_equal(created_code.get("expiresInSeconds", 0), 600, "create_transfer_code expiresInSeconds")

	var consumed: Dictionary = client.consume_transfer_code("P7K2D-M9Q4R", {
		"deviceLabel": "Laptop",
	})
	_expect_equal(consumed.get("accountId", ""), "acc_test", "consume_transfer_code accountId")
	_expect_equal(consumed.get("accountSessionToken", ""), "pst_new_session", "consume_transfer_code accountSessionToken")
	_expect_dictionary(consumed.get("account", {}).get("accountData", {}), ACCOUNT["accountData"], "consume_transfer_code accountData")

	var requests: Array = client.get_recorded_requests()
	_expect_request(requests[0], "POST", "/api/v1/accounts/acc_test/transfer-codes", true)
	_expect_request(requests[1], "POST", "/api/v1/account-transfer-codes/consume", false)
	if JSON.stringify(requests).find("P7K2D-M9Q4R") >= 0:
		_fail("Recorded transfer-code requests should redact raw transfer codes.")
	if JSON.stringify(requests).find("pst_account_session") >= 0 or JSON.stringify(requests).find("pst_new_session") >= 0:
		_fail("Recorded transfer-code requests should not expose account session tokens.")
	client.clear_recorded_requests()


func _check_auth_routes(client: Object, client_script: GDScript) -> void:
	var unsupported_provider: Dictionary = client.create_auth_session({
		"provider": "google",
		"token": "unsupported-token",
	})
	_expect_error_code(unsupported_provider, client_script.ERROR_INVALID_REQUEST, "create_auth_session rejects direct Google provider")
	var unsupported_oidc: Dictionary = client.create_auth_session({
		"provider": "oidc_jwt",
		"token": "unsupported-oidc-token",
	})
	_expect_error_code(unsupported_oidc, client_script.ERROR_INVALID_REQUEST, "create_auth_session rejects generic OIDC JWT provider")
	if client.get_recorded_requests().size() != 0:
		_fail("Unsupported auth provider should be rejected before recording a request.")

	var signed_in: Dictionary = client.create_auth_session({
		"provider": "firebase",
		"token": "firebase-id-token",
		"deviceLabel": "Steam Deck",
	})
	_expect_equal(signed_in.get("accountId", ""), "acc_auth", "create_auth_session accountId")
	_expect_equal(signed_in.get("accountSessionToken", ""), "pst_auth_session", "create_auth_session accountSessionToken")
	_expect_equal(signed_in.get("linkedProvider", ""), "firebase", "create_auth_session linkedProvider")
	_expect_equal(signed_in.get("isNewAccount", false), true, "create_auth_session isNewAccount")

	var linked: Dictionary = client.create_auth_session({
		"provider": "supabase",
		"token": "supabase-access-token",
		"deviceLabel": "Laptop",
	}, "pst_current_session", "acc_current")
	_expect_equal(linked.get("linkedProvider", ""), "supabase", "create_auth_session linked Supabase provider")
	_expect_equal(linked.get("wasProviderNewForAccount", false), true, "create_auth_session linked current provider")

	var linked_auth0: Dictionary = client.create_auth_session({
		"provider": "auth0",
		"token": "auth0-token",
		"deviceLabel": "Desktop",
	}, "pst_current_session", "acc_current")
	_expect_equal(linked_auth0.get("linkedProvider", ""), "auth0", "create_auth_session linked Auth0 provider")

	var providers: Dictionary = client.list_linked_providers("acc_auth", "pst_auth_session")
	var provider_rows: Array = providers.get("providers", [])
	if provider_rows.size() != 3:
		_fail("list_linked_providers should return Firebase, Supabase, and Auth0 provider rows.")
	else:
		_expect_equal(provider_rows[0].get("provider", ""), "firebase", "list_linked_providers provider")
		_expect_equal(provider_rows[1].get("provider", ""), "supabase", "list_linked_providers Supabase provider")
		_expect_equal(provider_rows[2].get("provider", ""), "auth0", "list_linked_providers Auth0 provider")

	var invalid_token: Dictionary = client.create_auth_session({
		"provider": "firebase",
		"token": "bad-token",
	})
	_expect_error_code(invalid_token, client_script.ERROR_PROVIDER_TOKEN_INVALID, "create_auth_session preserves provider_token_invalid")
	var project_mismatch: Dictionary = client.create_auth_session({
		"provider": "firebase",
		"token": "wrong-project-token",
	})
	_expect_error_code(project_mismatch, client_script.ERROR_FIREBASE_PROJECT_MISMATCH, "create_auth_session preserves firebase_project_mismatch")
	_expect_equal(project_mismatch.get("error", {}).get("message", ""), "This Firebase token belongs to a different Firebase project than the one configured for this environment.", "create_auth_session firebase_project_mismatch safe message")
	var not_configured: Dictionary = client.create_auth_session({
		"provider": "firebase",
		"token": "missing-config-token",
	})
	_expect_error_code(not_configured, client_script.ERROR_AUTH_PROVIDER_NOT_CONFIGURED, "create_auth_session preserves auth_provider_not_configured")
	var conflict: Dictionary = client.create_auth_session({
		"provider": "firebase",
		"token": "conflict-token",
	}, "pst_current_session", "acc_current")
	_expect_error_code(conflict, client_script.ERROR_ACCOUNT_AUTH_CONFLICT, "create_auth_session preserves account_auth_conflict")

	var requests: Array = client.get_recorded_requests()
	_expect_request(requests[0], "POST", "/api/v1/accounts/auth/session", false)
	_expect_request(requests[1], "POST", "/api/v1/accounts/auth/session", true, "acc_current")
	_expect_request(requests[2], "POST", "/api/v1/accounts/auth/session", true, "acc_current")
	_expect_request(requests[3], "GET", "/api/v1/accounts/auth/providers", true, "acc_auth")
	if JSON.stringify(requests).find("firebase-id-token") >= 0 or JSON.stringify(requests).find("supabase-access-token") >= 0 or JSON.stringify(requests).find("auth0-token") >= 0:
		_fail("Recorded auth bridge requests should redact provider tokens.")
	if JSON.stringify(requests).find("wrong-project-token") >= 0:
		_fail("Recorded auth bridge requests should not expose rejected provider tokens.")
	if JSON.stringify(requests).find("pst_auth_session") >= 0 or JSON.stringify(requests).find("pst_current_session") >= 0:
		_fail("Recorded auth bridge requests should not expose account session tokens.")
	client.clear_recorded_requests()


func _check_slot_routes(client: Object, client_script: GDScript) -> void:
	var created: Dictionary = client.create_account_slot("acc_test", "pst_account_session", {
		"slotId": "manual-1",
		"slotInfo": {
			"characterName": "Bryn",
		},
		"data": {
			"level": 2,
		},
	})
	_expect_equal(created.get("slot", {}).get("slotId", ""), "manual-1", "create_account_slot slotId")

	var loaded: Dictionary = client.load_account_slot("acc_test", "pst_account_session", "manual-1")
	_expect_equal(loaded.get("slot", {}).get("slotId", ""), "manual-1", "load_account_slot slotId")

	var synced: Dictionary = client.sync_account_slot("acc_test", "pst_account_session", "manual-1", {
		"baseVersion": 2,
		"slotInfo": {
			"characterName": "Bryn",
			"level": 3,
		},
		"data": {
			"level": 3,
		},
	})
	_expect_equal(synced.get("status", ""), "accepted", "sync_account_slot status")
	_expect_equal(synced.get("slot", {}).get("version", 0), 3, "sync_account_slot version")

	var archived: Dictionary = client.archive_account_slot("acc_test", "pst_account_session", "manual-1")
	_expect_equal(archived.get("account", {}).get("accountId", ""), "acc_test", "archive_account_slot accountId")

	var deleted: Dictionary = client.delete_account_slot("acc_test", "pst_account_session", "manual-1")
	_expect_equal(deleted.get("slotId", ""), "manual-1", "delete_account_slot slotId")

	var requests: Array = client.get_recorded_requests()
	_expect_request(requests[0], "POST", "/api/v1/accounts/acc_test/slots", true)
	_expect_request(requests[1], "GET", "/api/v1/accounts/acc_test/slots/manual-1", true)
	_expect_request(requests[2], "POST", "/api/v1/accounts/acc_test/slots/manual-1/sync", true)
	_expect_request(requests[3], "POST", "/api/v1/accounts/acc_test/slots/manual-1/archive", true)
	_expect_request(requests[4], "DELETE", "/api/v1/accounts/acc_test/slots/manual-1", true)
	_expect_facade_body_terms(requests[0].get("body", {}), "create_account_slot")
	_expect_facade_body_terms(requests[2].get("body", {}), "sync_account_slot")

	var raw_create: Dictionary = client.create_account_slot("acc_test", "pst_account_session", {
		"slotId": "raw-create",
		"metadata": {},
		"state": {
			"level": 1,
		},
	})
	_expect_error_code(raw_create, client_script.ERROR_INVALID_REQUEST, "create_account_slot rejects raw state/metadata aliases")
	var raw_sync: Dictionary = client.sync_account_slot("acc_test", "pst_account_session", "raw-sync", {
		"baseVersion": 1,
		"metadata": {},
		"state": {
			"level": 1,
		},
	})
	_expect_error_code(raw_sync, client_script.ERROR_INVALID_REQUEST, "sync_account_slot rejects raw state/metadata aliases")
	client.clear_recorded_requests()


func _check_runtime_config(client: Object) -> void:
	var config: Dictionary = client.get_runtime_config()
	_expect_equal(config.get("gameConfig", {}).get("data", {}).get("season", ""), "spring", "get_runtime_config gameConfig data")


func _check_error_mapping(client: Object, client_script: GDScript) -> void:
	var deleted_account = client.load_account("acc_deleted", "pst_account_session")
	_expect_error_code(deleted_account, client_script.ERROR_ACCOUNT_DELETED, "load_account should preserve account_deleted errors")
	var deleted_slot = client.load_account_slot("acc_test", "pst_account_session", "deleted")
	_expect_error_code(deleted_slot, client_script.ERROR_SLOT_DELETED, "load_account_slot should preserve slot_deleted errors")
	var archived_slot = client.sync_account_slot("acc_test", "pst_account_session", "archived", {
		"baseVersion": 1,
		"slotInfo": {},
		"data": {},
	})
	_expect_error_code(archived_slot, client_script.ERROR_SLOT_ARCHIVED, "sync_account_slot should preserve slot_archived errors")


func _seed_fixture_responses(client: Object) -> void:
	client.register_fixture_response("POST", "/api/v1/accounts", 201, {
		"accountId": "acc_test",
		"accountSessionToken": "pst_account_session",
		"account": ACCOUNT,
		"slot": SLOT,
		"syncPolicy": SYNC_POLICY,
	})
	client.register_fixture_response("GET", "/api/v1/accounts/acc_test", 200, ACCOUNT)
	client.register_fixture_response("POST", "/api/v1/accounts/acc_test/data/sync", 200, {
		"status": "accepted",
		"version": 2,
		"updatedAt": "2026-05-29T10:02:00Z",
		"historyRetained": true,
	})
	client.register_fixture_response("DELETE", "/api/v1/accounts/acc_test", 200, {
		"accountId": "acc_test",
		"deletedAt": "2026-05-29T10:03:00Z",
		"deletedSlotCount": 1,
		"alreadyDeleted": false,
		"cleanupQueued": true,
	})
	client.register_fixture_response("POST", "/api/v1/accounts/acc_test/transfer-codes", 200, {
		"transferCode": "P7K2D-M9Q4R",
		"expiresAt": "2026-06-01T12:10:00Z",
		"expiresInSeconds": 600,
	})
	client.register_fixture_response("POST", "/api/v1/account-transfer-codes/consume", 200, {
		"accountId": "acc_test",
		"accountSessionToken": "pst_new_session",
		"account": ACCOUNT,
		"syncPolicy": SYNC_POLICY,
	})
	client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 200, {
		"accountId": "acc_auth",
		"accountSessionToken": "pst_auth_session",
		"isNewAccount": true,
		"linkedProvider": "firebase",
		"wasProviderNewForAccount": true,
	})
	client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 200, {
		"accountId": "acc_test",
		"accountSessionToken": "pst_linked_session",
		"isNewAccount": false,
		"linkedProvider": "supabase",
		"wasProviderNewForAccount": true,
	})
	client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 200, {
		"accountId": "acc_test",
		"accountSessionToken": "pst_linked_auth0_session",
		"isNewAccount": false,
		"linkedProvider": "auth0",
		"wasProviderNewForAccount": true,
	})
	client.register_fixture_response("GET", "/api/v1/accounts/auth/providers", 200, [
		{
			"provider": "firebase",
			"display": {
				"label": "Firebase",
				"emailHint": "a***@example.com",
			},
			"linkedAt": "2026-06-06T00:00:00Z",
		},
		{
			"provider": "supabase",
			"display": {
				"label": "Supabase",
				"emailHint": "s***@example.com",
			},
			"linkedAt": "2026-06-07T00:00:00Z",
		},
		{
			"provider": "auth0",
			"display": {
				"label": "Auth0",
				"emailHint": "u***@example.com",
			},
			"linkedAt": "2026-06-08T00:00:00Z",
		},
	])
	client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 401, {
		"error": {
			"code": "provider_token_invalid",
			"message": "Provider token could not be verified.",
		},
	})
	client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 401, {
		"error": {
			"code": "firebase_project_mismatch",
			"message": "This Firebase token belongs to a different Firebase project than the one configured for this environment.",
			"retryable": false,
		},
	})
	client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 403, {
		"error": {
			"code": "auth_provider_not_configured",
			"message": "Auth provider is not configured for this environment.",
		},
	})
	client.register_fixture_response("POST", "/api/v1/accounts/auth/session", 409, {
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
	client.register_fixture_response("POST", "/api/v1/accounts/acc_test/slots", 201, {
		"accountId": "acc_test",
		"account": _account_with_slot("manual-1"),
		"slot": _slot("manual-1", 2),
	})
	client.register_fixture_response("GET", "/api/v1/accounts/acc_test/slots/manual-1", 200, {
		"slot": _slot("manual-1", 2),
	})
	client.register_fixture_response("POST", "/api/v1/accounts/acc_test/slots/manual-1/sync", 200, {
		"status": "accepted",
		"version": 3,
		"updatedAt": "2026-05-29T10:04:00Z",
	})
	client.register_fixture_response("POST", "/api/v1/accounts/acc_test/slots/manual-1/archive", 200, {
		"accountId": "acc_test",
		"account": _account_with_slot("manual-1", true),
	})
	client.register_fixture_response("DELETE", "/api/v1/accounts/acc_test/slots/manual-1", 200, {
		"accountId": "acc_test",
		"slotId": "manual-1",
		"deletedAt": "2026-05-29T10:05:00Z",
		"alreadyDeleted": false,
		"cleanupQueued": true,
		"account": ACCOUNT,
	})
	client.register_fixture_response("GET", "/api/v1/runtime-config", 200, {
		"syncPolicy": SYNC_POLICY,
		"gameConfig": {
			"enabled": true,
			"version": 3,
			"data": {
				"season": "spring",
			},
		},
	})
	client.register_fixture_response("GET", "/api/v1/accounts/acc_deleted", 410, {
		"error": {
			"code": "account_deleted",
			"message": "Account was deleted.",
		},
	})
	client.register_fixture_response("GET", "/api/v1/accounts/acc_test/slots/deleted", 410, {
		"error": {
			"code": "slot_deleted",
			"message": "Slot was deleted.",
		},
	})
	client.register_fixture_response("POST", "/api/v1/accounts/acc_test/slots/archived/sync", 409, {
		"error": {
			"code": "slot_archived",
			"message": "Archived slots cannot be synced.",
		},
	})


func _slot(slot_id: String, version: int) -> Dictionary:
	return {
		"slotId": slot_id,
		"slotInfo": {
			"characterName": "Bryn",
		},
		"data": {
			"level": version,
		},
		"version": version,
		"updatedAt": "2026-05-29T10:04:00Z",
	}


func _account_with_slot(slot_id: String, archived: Variant = false) -> Dictionary:
	var slot_summary := {
		"slotId": slot_id,
		"slotInfo": {
			"characterName": "Bryn",
		},
		"version": 2,
		"status": "active",
		"updatedAt": "2026-05-29T10:04:00Z",
	}
	if bool(archived):
		slot_summary["status"] = "archived"
		slot_summary["archived"] = true
	return {
		"accountId": "acc_test",
		"accountData": ACCOUNT["accountData"],
		"slots": [slot_summary],
		"version": 2,
		"updatedAt": "2026-05-29T10:04:00Z",
	}


func _expect_request(request: Dictionary, method: String, path: String, should_have_session: bool, expected_account_id: String = "") -> void:
	_expect_equal(request.get("method", ""), method, method + " " + path + " method")
	_expect_equal(request.get("path", ""), path, method + " " + path + " path")
	var headers: Array = request.get("headers", [])
	var has_account_header := false
	var account_id_header := ""
	var has_profile_header := false
	for header in headers:
		if String(header).begins_with("X-Persistly-Account-Session:"):
			has_account_header = true
		if String(header).begins_with("X-Persistly-Account-ID:"):
			account_id_header = String(header).replace("X-Persistly-Account-ID:", "").strip_edges()
		if String(header).begins_with("X-Persistly-Profile-Session:"):
			has_profile_header = true
	if should_have_session and not has_account_header:
		_fail(method + " " + path + " should send X-Persistly-Account-Session.")
	if not should_have_session and has_account_header:
		_fail(method + " " + path + " should not send an account session header.")
	if has_profile_header:
		_fail(method + " " + path + " should not send X-Persistly-Profile-Session.")
	if not expected_account_id.is_empty() and account_id_header != expected_account_id:
		_fail(method + " " + path + " should send X-Persistly-Account-ID for " + expected_account_id + ".")
	if expected_account_id.is_empty() and not account_id_header.is_empty():
		_fail(method + " " + path + " should not send X-Persistly-Account-ID.")


func _expect_facade_body_terms(body: Variant, label: String) -> void:
	var body_text := JSON.stringify(body)
	for forbidden in ["metadata", "state", "saveId", "_persistly"]:
		if body_text.find(forbidden) >= 0:
			_fail(label + " request should not contain raw " + forbidden + " fields.")


func _expect_error_code(result: Dictionary, expected: String, label: String) -> void:
	var error = result.get("error", {})
	if typeof(error) != TYPE_DICTIONARY or String(error.get("code", "")) != expected:
		_fail(label + " expected " + expected + " but got " + str(result))


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
		print("Persistly Godot client validation passed.")
		quit(0)
	else:
		push_error("Persistly Godot client validation failed with " + str(_failure_count) + " issue(s).")
		quit(1)
