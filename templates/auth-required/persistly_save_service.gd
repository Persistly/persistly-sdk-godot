extends RefCounted

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func configure(runtime_key: String, local_account_key: String) -> Dictionary:
	return persistly.configure({
		"runtime_key": runtime_key,
		"accountMode": "authRequired",
		"localAccountKey": local_account_key,
	})


func sign_in_with_google(id_token: String, device_label: String = "") -> Dictionary:
	return persistly.sign_in_with_google_id_token(id_token, {
		"deviceLabel": device_label,
	})


func sign_in_with_oidc(jwt_token: String, device_label: String = "") -> Dictionary:
	return persistly.sign_in_with_provider({
		"provider": "oidc_jwt",
		"token": jwt_token,
		"deviceLabel": device_label,
	})


func link_provider(input: Dictionary) -> Dictionary:
	return persistly.link_provider(input)


func list_linked_providers() -> Dictionary:
	return persistly.list_linked_providers()


func save_local_data(data: Dictionary, slot_info: Dictionary = {}) -> Dictionary:
	return persistly.save_data(data, {
		"slotInfo": slot_info,
	})


func load_local_data() -> Dictionary:
	return persistly.load_data()


func sync_now() -> Dictionary:
	return persistly.force_sync_data({ "bypassCooldown": true })


func sign_out() -> Dictionary:
	return persistly.sign_out()
