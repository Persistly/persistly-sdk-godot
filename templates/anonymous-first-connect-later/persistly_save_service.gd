extends RefCounted

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func configure(runtime_key: String, local_account_key: String = "current-player") -> Dictionary:
	return persistly.configure({
		"runtime_key": runtime_key,
		"localAccountKey": local_account_key,
	})


func save_game(data: Dictionary) -> Dictionary:
	return persistly.save_data(data, {
		"slotInfo": {
			"level": data.get("level", 0),
			"checkpoint": data.get("checkpoint", ""),
		},
	})


func sync_game() -> Dictionary:
	return persistly.force_sync_data({"bypassCooldown": true})


func connect_firebase(firebase_id_token: String, device_label: String = "") -> Dictionary:
	# The token comes from Firebase Auth in your game. Normal save/load/sync calls
	# do not receive or store this token.
	return persistly.connect_with_firebase_token(firebase_id_token, {
		"deviceLabel": device_label,
	})


func discard_local_and_use_provider_account(firebase_id_token: String, device_label: String = "") -> Dictionary:
	# Only call this after the player confirms discarding this device's local Persistly state.
	# This does not copy anonymous progress into the provider-linked cloud account.
	var cleared := persistly.clear_local_account()
	if cleared.has("error"):
		return cleared
	return persistly.sign_in_with_firebase_token(firebase_id_token, {
		"deviceLabel": device_label,
	})
