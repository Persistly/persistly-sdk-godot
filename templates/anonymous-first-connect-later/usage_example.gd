extends Node

const PersistlySaveService := preload("res://templates/anonymous-first-connect-later/persistly_save_service.gd")

var saves := PersistlySaveService.new()


func _ready() -> void:
	saves.configure("ps_test_replace_me", "current-player")
	saves.save_game({
		"level": 3,
		"coins": 250,
		"checkpoint": "meadow-gate",
	})
	saves.sync_game()

	# Get this from Firebase Auth in your game. Use the matching Supabase or Auth0
	# connect helper when those SDKs provide the token instead.
	var firebase_id_token := "firebase_id_token_from_your_login_flow"
	var connected := saves.connect_firebase(firebase_id_token, OS.get_name())
	if connected.get("status", "") == "account_auth_conflict":
		# Local anonymous progress is still present. Only switch after confirmation.
		pass
