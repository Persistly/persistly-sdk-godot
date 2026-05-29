extends RefCounted

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func configure(runtime_key: String) -> Dictionary:
	return persistly.configure({
		"runtime_key": runtime_key,
	})


func load_game() -> Dictionary:
	var loaded := persistly.load_data()
	if loaded.get("status", "") == "local_found":
		return loaded.get("data", {})
	return {}


func save_game(data: Dictionary) -> Dictionary:
	return persistly.save_data(data)


func sync_game() -> Dictionary:
	return persistly.force_sync_data({ "bypassCooldown": true })
