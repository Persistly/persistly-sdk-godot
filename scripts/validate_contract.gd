extends SceneTree

const BUNDLE_ROOT := "res://contracts/persistly-contract-v0.3.0"
const MANIFEST_PATH := "res://contracts/persistly-contract-v0.3.0/manifest.json"


func _initialize() -> void:
	var manifest := _read_json_file(MANIFEST_PATH)
	if manifest.is_empty():
		push_error("Persistly contract bundle validation failed: manifest could not be read.")
		quit(1)
		return

	if manifest.get("bundle", "") != "persistly-contract-v0.3.0":
		push_error("Persistly contract bundle validation failed: expected persistly-contract-v0.3.0.")
		quit(1)
		return

	var files_value = manifest.get("files")
	if typeof(files_value) != TYPE_ARRAY:
		push_error("Persistly contract bundle validation failed: manifest is missing a files array.")
		quit(1)
		return

	var missing: Array[String] = []
	var mismatched: Array[String] = []
	var invalid: Array[String] = []

	for file_entry in files_value:
		if typeof(file_entry) != TYPE_DICTIONARY:
			invalid.append("manifest file entry is not an object")
			continue

		var relative_path := String(file_entry.get("path", ""))
		var expected_sha := String(file_entry.get("sha256", ""))
		var expected_bytes := int(file_entry.get("bytes", -1))
		if relative_path.is_empty() or expected_sha.is_empty() or expected_bytes < 0:
			invalid.append("manifest entry is missing path, sha256, or bytes")
			continue

		var full_path := BUNDLE_ROOT.path_join(relative_path)
		if not FileAccess.file_exists(full_path):
			missing.append(full_path)
			continue

		var actual_bytes := FileAccess.get_file_as_bytes(full_path)
		if actual_bytes.size() != expected_bytes:
			mismatched.append(full_path + " (bytes)")
			continue

		var actual_sha := FileAccess.get_sha256(full_path)
		if actual_sha != expected_sha:
			mismatched.append(full_path + " (sha256)")

	if missing.is_empty() and mismatched.is_empty() and invalid.is_empty():
		print("Persistly contract bundle is valid at " + BUNDLE_ROOT + ".")
		quit(0)
		return

	push_error("Persistly contract bundle validation failed.")
	for message in invalid:
		push_error("Invalid manifest entry: " + message)
	for file_path in missing:
		push_error("Missing file: " + file_path)
	for path in mismatched:
		push_error("Checksum or size mismatch: " + path)
	quit(1)


func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed
