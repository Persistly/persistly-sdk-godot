extends SceneTree

const STATE_SCRIPT := "res://examples/last_beacon/last_beacon_state.gd"

var _failure_count := 0


func _initialize() -> void:
	var script := load(STATE_SCRIPT)
	if script == null:
		_fail("Could not load Last Beacon state script at " + STATE_SCRIPT)
		_finish()
		return

	var state = script.new()
	_expect(state.scrap == 12, "Initial scrap should start at 12.")
	_expect(state.workers == 1, "Initial workers should start at 1.")
	_expect(state.level == 1, "Initial level should start at 1.")
	_expect(state.manual_gather_amount == 3, "Initial gather amount should start at 3.")

	state.tick(5.0)
	_expect(state.scrap == 17, "Tick should add passive scrap from workers.")

	state.gather()
	_expect(state.scrap == 20, "Manual gather should add the configured gather amount.")

	var hire_result = state.hire_worker()
	_expect(bool(hire_result), "First worker hire should succeed.")
	_expect(state.workers == 2, "Hiring a worker should increase worker count.")

	state.tick(6.0)
	state.gather()
	state.gather()

	var upgrade_result = state.upgrade_core()
	_expect(bool(upgrade_result), "Core upgrade should succeed after enough scrap exists.")
	_expect(state.level == 2, "Core upgrade should increase the level.")
	_expect(state.manual_gather_amount > 3, "Core upgrade should improve gather power.")

	var serialized = state.to_save_state()
	_expect(typeof(serialized) == TYPE_DICTIONARY, "Serialized state should be a dictionary.")
	_expect(serialized.get("workers", 0) == state.workers, "Serialized workers should match runtime state.")

	var hydrated = script.new()
	var hydrate_result = hydrated.from_save_state(serialized)
	_expect(bool(hydrate_result), "Hydrating from serialized save data should succeed.")
	_expect(hydrated.scrap == state.scrap, "Hydrated scrap should match serialized scrap.")
	_expect(hydrated.level == state.level, "Hydrated level should match serialized level.")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failure_count += 1
	push_error(message)


func _finish() -> void:
	if _failure_count == 0:
		print("Last Beacon state validation passed.")
		quit(0)
		return

	push_error("Last Beacon state validation failed with " + str(_failure_count) + " issue(s).")
	quit(1)
