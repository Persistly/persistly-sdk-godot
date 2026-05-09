extends Control

const STATE_SCRIPT := preload("res://examples/last_beacon/last_beacon_state.gd")
const STORE_SCRIPT := preload("res://examples/last_beacon/last_beacon_store.gd")
const GAME_SAVES_SCRIPT := preload("res://addons/persistly/persistly_game_saves.gd")

const PROFILE_PATH := "user://last_beacon_profile.json"
const TICK_INTERVAL_SECONDS := 1.0
const SLOT_KEY := "autosave"

var _state
var _store

var _profile: Dictionary = {}
var _profile_save_id: String = ""
var _profile_session_token: String = ""
var _character_save_id: String = ""
var _version: int = 0
var _sync_status: String = "Local only"
var _last_error: String = ""
var _is_busy: bool = false

var _tick_timer: Timer

var _base_url_input: LineEdit
var _runtime_key_input: LineEdit
var _player_ref_input: LineEdit
var _character_name_input: LineEdit
var _slot_label_input: LineEdit
var _resources_label: Label
var _production_label: Label
var _save_label: Label
var _sync_label: Label
var _error_label: Label
var _gather_button: Button
var _hire_button: Button
var _upgrade_button: Button
var _sync_button: Button
var _connect_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_state = STATE_SCRIPT.new()
	_store = STORE_SCRIPT.new(PROFILE_PATH)
	_profile = _store.load_profile()

	_restore_profile_state()
	_build_ui()
	_apply_profile_to_inputs()
	_create_timers()
	_refresh_ui()


func _on_gather_pressed() -> void:
	_state.gather()
	_sync_status = "Local changes pending"
	_last_error = ""
	_save_profile()
	_refresh_ui()


func _on_hire_worker_pressed() -> void:
	if _state.hire_worker():
		_sync_status = "Local changes pending"
		_last_error = ""
	else:
		_last_error = "Not enough scrap to hire a worker."
	_save_profile()
	_refresh_ui()


func _on_upgrade_core_pressed() -> void:
	if _state.upgrade_core():
		_sync_status = "Local changes pending"
		_last_error = ""
	else:
		_last_error = "Not enough scrap to upgrade the beacon core."
	_save_profile()
	_refresh_ui()


func _on_resume_pressed() -> void:
	if _is_busy:
		return

	_last_error = ""
	var config := _current_config()
	if String(config.get("baseUrl", "")).is_empty() or String(config.get("runtimeKey", "")).is_empty():
		_last_error = "Base URL and runtime key are required before connecting to Persistly."
		_refresh_ui()
		return

	_is_busy = true
	_sync_status = "Connecting..."
	_refresh_ui()

	var persistly = _build_game_saves(config)
	var ensure_result: Dictionary = persistly.ensure_profile()
	if ensure_result.has("error"):
		_last_error = String(ensure_result["error"].get("message", "Persistly profile create/load failed."))
		_sync_status = "Profile connect failed"
	else:
		_capture_profile_session(persistly)
		_sync_facade_slot(persistly)

	_is_busy = false
	_save_profile()
	_refresh_ui()


func _sync_now() -> void:
	if _is_busy:
		return

	var config := _current_config()
	if String(config.get("baseUrl", "")).is_empty() or String(config.get("runtimeKey", "")).is_empty():
		_last_error = "Base URL and runtime key are required before syncing."
		_refresh_ui()
		return

	_is_busy = true
	_last_error = ""
	_sync_status = "Syncing..."
	_refresh_ui()

	var persistly = _build_game_saves(config)
	_sync_facade_slot(persistly)

	_is_busy = false
	_save_profile()
	_refresh_ui()


func _on_new_beacon_pressed() -> void:
	_state = STATE_SCRIPT.new()
	_profile_save_id = ""
	_profile_session_token = ""
	_character_save_id = ""
	_version = 0
	_sync_status = "New local run"
	_last_error = ""
	_save_profile()
	_refresh_ui()


func _on_tick_timeout() -> void:
	_state.tick(TICK_INTERVAL_SECONDS)
	if _sync_status == "Synced":
		_sync_status = "Local changes pending"
	_save_profile()
	_refresh_ui()


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 20)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)

	var shell := HBoxContainer.new()
	shell.add_theme_constant_override("separation", 18)
	root.add_child(shell)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	shell.add_child(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	right.add_theme_constant_override("separation", 14)
	shell.add_child(right)

	left.add_child(_section_heading("Last Beacon", "An endless idle outpost that persists through Persistly."))

	var resources_panel := _panel_container()
	left.add_child(resources_panel)
	var resources_box := VBoxContainer.new()
	resources_box.add_theme_constant_override("separation", 8)
	resources_panel.add_child(resources_box)
	_resources_label = Label.new()
	_resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resources_label.add_theme_font_size_override("font_size", 24)
	resources_box.add_child(_resources_label)
	_production_label = Label.new()
	_production_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resources_box.add_child(_production_label)

	var actions_panel := _panel_container()
	left.add_child(actions_panel)
	var actions_box := VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 10)
	actions_panel.add_child(actions_box)
	actions_box.add_child(_panel_title("Actions"))

	_gather_button = _action_button("Gather Scrap", Callable(self, "_on_gather_pressed"))
	_hire_button = _action_button("Hire Worker", Callable(self, "_on_hire_worker_pressed"))
	_upgrade_button = _action_button("Upgrade Core", Callable(self, "_on_upgrade_core_pressed"))
	_sync_button = _action_button("Sync Now", Callable(self, "_sync_now"))

	actions_box.add_child(_gather_button)
	actions_box.add_child(_hire_button)
	actions_box.add_child(_upgrade_button)
	actions_box.add_child(_sync_button)

	var config_panel := _panel_container()
	right.add_child(config_panel)
	var config_box := VBoxContainer.new()
	config_box.add_theme_constant_override("separation", 10)
	config_panel.add_child(config_box)
	config_box.add_child(_panel_title("Persistly Runtime"))

	_base_url_input = _labeled_input(config_box, "API Base URL", false)
	_runtime_key_input = _labeled_input(config_box, "Runtime Key", true)
	_player_ref_input = _labeled_input(config_box, "Player reference", false)
	_character_name_input = _labeled_input(config_box, "Character Name", false)
	_slot_label_input = _labeled_input(config_box, "Slot Label", false)

	_connect_button = _action_button("Connect / Resume Remote Save", Callable(self, "_on_resume_pressed"))
	config_box.add_child(_connect_button)
	config_box.add_child(_action_button("Start New Beacon", Callable(self, "_on_new_beacon_pressed")))

	var status_panel := _panel_container()
	right.add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 8)
	status_panel.add_child(status_box)
	status_box.add_child(_panel_title("Status"))

	_save_label = Label.new()
	_save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_box.add_child(_save_label)

	_sync_label = Label.new()
	_sync_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_box.add_child(_sync_label)

	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.modulate = Color(1.0, 0.58, 0.58)
	status_box.add_child(_error_label)

	var note_panel := _panel_container()
	right.add_child(note_panel)
	var note_box := VBoxContainer.new()
	note_box.add_theme_constant_override("separation", 8)
	note_panel.add_child(note_box)
	note_box.add_child(_panel_title("How This Proves Persistly"))
	note_box.add_child(_paragraph("This scene stores runtime config, profile session, and local idle state under user:// so you can close and reopen it without losing context."))
	note_box.add_child(_paragraph("PersistlyGameSaves saves the autosave slot locally first. Use Sync Now or Connect / Resume Remote Save to explicitly push the slot to Persistly."))


func _section_heading(title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 36)
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.modulate = Color(0.76, 0.81, 0.89)
	box.add_child(subtitle_label)
	return box


func _panel_container() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _panel_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


func _paragraph(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.76, 0.81, 0.89)
	return label


func _labeled_input(parent: VBoxContainer, label_text: String, secret: bool) -> LineEdit:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)
	parent.add_child(wrapper)

	var label := Label.new()
	label.text = label_text
	wrapper.add_child(label)

	var input := LineEdit.new()
	input.secret = secret
	input.placeholder_text = label_text
	input.text_submitted.connect(func(_text: String) -> void:
		_save_profile()
	)
	wrapper.add_child(input)
	return input


func _action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _create_timers() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL_SECONDS
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick_timeout)
	add_child(_tick_timer)


func _apply_profile_to_inputs() -> void:
	var config: Dictionary = _profile.get("config", {})
	_base_url_input.text = String(config.get("baseUrl", "https://api.persistly.app"))
	_runtime_key_input.text = String(config.get("runtimeKey", ""))
	_player_ref_input.text = String(config.get("playerRef", ""))
	_character_name_input.text = String(config.get("characterName", "Ayla"))
	_slot_label_input.text = String(config.get("slotLabel", "Beacon-A"))


func _restore_profile_state() -> void:
	_profile_save_id = String(_profile.get("profileSaveId", ""))
	_profile_session_token = String(_profile.get("profileSessionToken", ""))
	_character_save_id = String(_profile.get("characterSaveId", ""))
	_version = int(_profile.get("version", 0))
	var saved_state = _profile.get("state", {})
	if typeof(saved_state) == TYPE_DICTIONARY and not saved_state.is_empty():
		var hydrated: bool = _state.from_save_state(saved_state)
		if hydrated:
			_sync_status = "Local cache loaded"


func _current_config() -> Dictionary:
	return {
		"baseUrl": _base_url_input.text.strip_edges(),
		"runtimeKey": _runtime_key_input.text.strip_edges(),
		"playerRef": _player_ref_input.text.strip_edges(),
		"characterName": _character_name_input.text.strip_edges(),
		"slotLabel": _slot_label_input.text.strip_edges(),
		"localProfileKey": _local_profile_key(),
	}


func _current_metadata() -> Dictionary:
	return {
		"characterName": _character_name_input.text.strip_edges(),
		"slotLabel": _slot_label_input.text.strip_edges(),
		"build": "last-beacon",
		"sdk": "godot",
	}


func _build_game_saves(config: Dictionary):
	var persistly = GAME_SAVES_SCRIPT.new()
	persistly.configure({
		"baseUrl": String(config.get("baseUrl", "")),
		"runtimeKey": String(config.get("runtimeKey", "")),
		"playerRef": _nullable_string(String(config.get("playerRef", ""))),
		"localProfileKey": String(config.get("localProfileKey", "")),
		"profileSaveId": _profile_save_id,
		"profileSessionToken": _profile_session_token,
		"storage_path": "user://last_beacon_persistly",
	})
	return persistly


func _sync_facade_slot(persistly) -> void:
	var local_result: Dictionary = persistly.save_slot(SLOT_KEY, _state.to_save_state(), _current_metadata())
	if local_result.has("error"):
		_last_error = String(local_result["error"].get("message", "Persistly local save failed."))
		_sync_status = "Local save failed"
		return

	var sync_result: Dictionary = persistly.force_sync(SLOT_KEY, {
		"bypassCooldown": true,
	})
	_capture_profile_session(persistly)
	if sync_result.has("error"):
		_last_error = String(sync_result["error"].get("message", "Persistly sync failed."))
		_sync_status = "Sync failed"
		return

	_apply_facade_slot(sync_result)
	if sync_result.get("status", "") == GAME_SAVES_SCRIPT.PersistlyGameSaveStatus.CONFLICT:
		_sync_status = "Conflict: local and cloud states kept separately"
	elif sync_result.get("status", "") == GAME_SAVES_SCRIPT.PersistlyGameSaveStatus.SYNCED:
		_sync_status = "Synced"
	else:
		_sync_status = String(sync_result.get("status", "Local saved"))
	_last_error = ""


func _capture_profile_session(persistly) -> void:
	var session: Dictionary = persistly.get_profile_session({
		"includeToken": true,
	})
	_profile_save_id = String(session.get("profileSaveId", _profile_save_id))
	_profile_session_token = String(session.get("profileSessionToken", _profile_session_token))


func _apply_facade_slot(slot: Dictionary) -> void:
	_character_save_id = String(slot.get("characterSaveId", _character_save_id))
	_version = int(slot.get("version", _version))


func _save_profile() -> void:
	_profile = {
		"config": _current_config(),
		"profileSaveId": _profile_save_id,
		"profileSessionToken": _profile_session_token,
		"characterSaveId": _character_save_id,
		"version": _version,
		"state": _state.to_save_state(),
	}
	_store.save_profile(_profile)


func _refresh_ui() -> void:
	_resources_label.text = "Scrap: %d   Workers: %d   Power Cells: %d   Tier: %d" % [
		_state.scrap,
		_state.workers,
		_state.power_cells,
		_state.level,
	]
	_production_label.text = "Passive: %.2f scrap/s   Gather: +%d   Core charge: %.0f%%   Next worker: %d   Next upgrade: %d" % [
		_state.passive_scrap_per_second(),
		_state.manual_gather_amount,
		_state.core_charge,
		_state.worker_cost(),
		_state.core_upgrade_cost(),
	]

	_save_label.text = "Profile: %s\nCharacter: %s\nVersion: %d" % [
		_profile_save_id if not _profile_save_id.is_empty() else "Not created yet",
		_character_save_id if not _character_save_id.is_empty() else "Not created yet",
		_version,
	]
	_sync_label.text = "Sync status: %s" % _sync_status
	_error_label.text = _last_error

	_gather_button.disabled = _is_busy
	_hire_button.disabled = _is_busy
	_upgrade_button.disabled = _is_busy
	_sync_button.disabled = _is_busy
	_connect_button.disabled = _is_busy


func _nullable_string(value: String) -> Variant:
	if value.is_empty():
		return null
	return value


func _local_profile_key() -> String:
	var player_ref := _player_ref_input.text.strip_edges()
	if not player_ref.is_empty():
		return player_ref
	return "last-beacon-local"
