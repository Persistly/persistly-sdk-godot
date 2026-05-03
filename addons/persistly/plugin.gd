@tool
extends EditorPlugin

const PLUGIN_NAME := "Persistly"


func _enter_tree() -> void:
	# Editor entrypoint only. The runtime client lives in persistly_client.gd.
	pass


func _exit_tree() -> void:
	pass

