extends Node

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func _ready() -> void:
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountMode": "authRequired",
		"localAccountKey": "signed-in-player",
	})


func sign_in_with_firebase(firebase_id_token: String) -> Dictionary:
	var signed_in := persistly.sign_in_with_firebase_token(firebase_id_token, {
		"deviceLabel": OS.get_name(),
	})
	if signed_in.has("error"):
		return signed_in

	return persistly.force_sync_data({ "bypassCooldown": true })


func link_firebase_to_current_account(firebase_id_token: String) -> Dictionary:
	return persistly.link_provider({
		"provider": "firebase",
		"token": firebase_id_token,
		"deviceLabel": OS.get_name(),
	})


func list_current_providers() -> Dictionary:
	return persistly.list_linked_providers()


func save_local_progress() -> Dictionary:
	return persistly.save_data({
		"level": 8,
		"coins": 2400,
	}, {
		"slotInfo": {
			"characterName": "Ayla",
			"level": 8,
		},
	})


func sign_out_current_player() -> Dictionary:
	return persistly.sign_out()
