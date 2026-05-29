extends Node

const PersistlySaveService := preload("res://templates/multi-slot/persistly_save_service.gd")

var saves := PersistlySaveService.new()
var selected_slot_id := "campaign-1"
var state := {
	"level": 1,
	"coins": 0,
	"quest": "harbor",
}


func _ready() -> void:
	saves.configure("ps_test_replace_me")
	var existing := saves.load_slot(selected_slot_id)
	if not existing.is_empty():
		state = existing
	else:
		saves.save_slot(selected_slot_id, state, "Campaign 1")


func save_progress() -> void:
	state["coins"] = int(state.get("coins", 0)) + 50
	saves.save_slot(selected_slot_id, state, "Campaign 1")
	saves.sync_slot(selected_slot_id)


func saved_slot_count() -> int:
	return saves.list_saved_slots().size()
