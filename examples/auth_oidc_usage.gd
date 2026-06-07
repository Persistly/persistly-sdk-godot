extends Node

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func _ready() -> void:
	persistly.configure({
		"runtime_key": "ps_test_replace_me",
		"accountMode": "authRequired",
		"localAccountKey": "oidc-player",
	})


func sign_in_with_oidc_jwt(jwt_token: String) -> Dictionary:
	return persistly.sign_in_with_provider({
		"provider": "oidc_jwt",
		"token": jwt_token,
		"deviceLabel": OS.get_name(),
	})


func link_google_after_oidc(google_id_token: String) -> Dictionary:
	return persistly.link_provider({
		"provider": "google",
		"token": google_id_token,
		"deviceLabel": OS.get_name(),
	})


func list_current_providers() -> Dictionary:
	return persistly.list_linked_providers()
