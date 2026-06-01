extends Node

const PersistlySaveService := preload("res://templates/account-slots/persistly_save_service.gd")

var saves := PersistlySaveService.new()


func _ready() -> void:
	saves.configure("ps_test_replace_me")


func first_device_save() -> void:
	var restore_payload := saves.export_account_session_for_backend()
	if restore_payload.has("error"):
		return

	send_account_session_to_backend(restore_payload)
	saves.save_account_slot("campaign-1", {
		"level": 7,
		"coins": 1200,
	}, "Campaign 1")
	saves.sync_account_slot("campaign-1")


func second_device_restore() -> void:
	var restore_payload := fetch_account_session_from_backend()
	saves.attach_account_session(restore_payload)


func first_device_transfer() -> Dictionary:
	var created := saves.create_transfer_code("Desktop")
	if created.has("error"):
		return created

	show_transfer_code_to_player(String(created.get("transferCode", "")))
	return created


func second_device_transfer(transfer_code: String) -> void:
	saves.attach_with_transfer_code(transfer_code, "Laptop")


func send_account_session_to_backend(payload: Dictionary) -> void:
	# Replace with your authenticated backend request. Do not log the token.
	var account_id := String(payload.get("accountId", ""))
	if account_id.is_empty():
		return


func show_transfer_code_to_player(transfer_code: String) -> void:
	# Render this in your UI. Do not print or persist the code.
	if transfer_code.is_empty():
		return


func fetch_account_session_from_backend() -> Dictionary:
	# Replace with your authenticated backend request.
	return {
		"accountId": "acc_replace_me",
		"accountSessionToken": "pst_replace_me",
	}
