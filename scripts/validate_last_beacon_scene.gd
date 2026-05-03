extends SceneTree

const SCENE_PATH := "res://examples/last_beacon/last_beacon.tscn"

var _failure_count := 0


func _initialize() -> void:
	var scene := load(SCENE_PATH)
	if scene == null:
		_fail("Could not load Last Beacon scene at " + SCENE_PATH)
		_finish()
		return

	var instance = scene.instantiate()
	_expect(instance != null, "Last Beacon scene should instantiate.")
	if instance != null:
		_expect(instance.has_method("_on_gather_pressed"), "Last Beacon scene should expose the gather action handler.")
		_expect(instance.has_method("_sync_now"), "Last Beacon scene should expose a sync action handler.")
		instance.queue_free()

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failure_count += 1
	push_error(message)


func _finish() -> void:
	if _failure_count == 0:
		print("Last Beacon scene validation passed.")
		quit(0)
		return

	push_error("Last Beacon scene validation failed with " + str(_failure_count) + " issue(s).")
	quit(1)
