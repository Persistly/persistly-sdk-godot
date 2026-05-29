extends RefCounted

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func configure(runtime_key: String) -> Dictionary:
	return persistly.configure({
		"runtime_key": runtime_key,
	})


func attach_account_session(payload: Dictionary) -> Dictionary:
	return persistly.attach_account(
		String(payload.get("accountId", "")),
		String(payload.get("accountSessionToken", ""))
	)


func export_account_session_for_backend() -> Dictionary:
	var ensured := persistly.ensure_account()
	if ensured.has("error"):
		return ensured

	var session := persistly.get_account_session({ "includeToken": true })
	if String(session.get("accountId", "")).is_empty() or String(session.get("accountSessionToken", "")).is_empty():
		return {
			"error": {
				"code": "account_session_not_ready",
				"message": "Persistly account session is not ready to export.",
			},
		}

	return {
		"accountId": session["accountId"],
		"accountSessionToken": session["accountSessionToken"],
	}


func save_account_slot(slot_id: String, data: Dictionary, label: String) -> Dictionary:
	return persistly.save_slot(slot_id, data, {
		"slotInfo": {
			"label": label,
		},
	})


func load_account_slot(slot_id: String) -> Dictionary:
	return persistly.load_slot(slot_id)


func sync_account_slot(slot_id: String) -> Dictionary:
	return persistly.force_sync(slot_id, { "bypassCooldown": true })
