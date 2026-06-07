extends Node

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func _ready() -> void:
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountMode": "authRequired",
		"localAccountKey": "signed-in-player",
	})


func sign_in_with_google(id_token: String) -> Dictionary:
	var signed_in := persistly.sign_in_with_google_id_token(id_token, {
		"deviceLabel": OS.get_name(),
	})
	if signed_in.has("error"):
		return signed_in

	return persistly.force_sync_data({ "bypassCooldown": true })


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
