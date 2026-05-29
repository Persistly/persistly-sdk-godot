extends RefCounted

const PersistlyGameSaves := preload("res://addons/persistly/persistly_game_saves.gd")

var persistly := PersistlyGameSaves.new()


func configure(runtime_key: String) -> Dictionary:
	return persistly.configure({
		"runtime_key": runtime_key,
	})


func list_saved_slots() -> Array:
	return persistly.list_slot_data()


func load_slot(slot_id: String) -> Dictionary:
	var loaded := persistly.load_slot(slot_id)
	if loaded.get("status", "") == "local_found":
		return loaded.get("data", {})
	return {}


func save_slot(slot_id: String, data: Dictionary, label: String) -> Dictionary:
	return persistly.save_slot(slot_id, data, {
		"slotInfo": {
			"label": label,
			"updatedBy": "game-client",
		},
	})


func sync_slot(slot_id: String) -> Dictionary:
	return persistly.force_sync(slot_id, { "bypassCooldown": true })
