extends Node

const PersistlySaveService := preload("res://templates/auth-required/persistly_save_service.gd")

var saves := PersistlySaveService.new()


func _ready() -> void:
	saves.configure("ps_test_replace_me", "player-auth-required")
	saves.save_local_data({
		"level": 1,
		"coins": 100,
	}, {
		"characterName": "Ayla",
	})


func sync_before_sign_in() -> Dictionary:
	var result := saves.sync_now()
	if result.get("status", "") == "auth_required":
		show_sign_in_screen()
	return result


func google_sign_in_complete(id_token: String) -> Dictionary:
	var signed_in := saves.sign_in_with_google(id_token, OS.get_name())
	if signed_in.has("error"):
		return signed_in
	return saves.sync_now()


func oidc_sign_in_complete(jwt_token: String) -> Dictionary:
	return saves.sign_in_with_oidc(jwt_token, OS.get_name())


func sign_out_pressed() -> Dictionary:
	return saves.sign_out()


func show_sign_in_screen() -> void:
	pass
