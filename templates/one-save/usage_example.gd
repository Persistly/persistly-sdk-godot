extends Node

const PersistlySaveService := preload("res://templates/one-save/persistly_save_service.gd")

var saves := PersistlySaveService.new()
var state := {
	"level": 1,
	"coins": 0,
	"checkpoint": "start",
}


func _ready() -> void:
	saves.configure("ps_test_replace_me")
	var existing := saves.load_game()
	if not existing.is_empty():
		state = existing


func award_coins(amount: int) -> void:
	state["coins"] = int(state.get("coins", 0)) + amount
	saves.save_game(state)


func sync_at_checkpoint() -> void:
	saves.sync_game()
