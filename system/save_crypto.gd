extends RefCounted
class_name SaveCrypto

const _SAVE_PASSWORD_A := "xianxia"
const _SAVE_PASSWORD_B := "save"
const _SAVE_PASSWORD_C := "v2"
const _SAVE_PASSWORD_D := "godot-test"
const _ENCRYPTED_FILE_MAGIC := 0x43454447

static func save_config(config: ConfigFile, path: String) -> int:
	return config.save_encrypted_pass(path, _get_password())

static func load_config(config: ConfigFile, path: String) -> int:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	if _is_encrypted_file(path):
		return config.load_encrypted_pass(path, _get_password())
	config.clear()
	return config.load(path)

static func _get_password() -> String:
	return "%s:%s:%s:%s" % [_SAVE_PASSWORD_A, _SAVE_PASSWORD_D, _SAVE_PASSWORD_B, _SAVE_PASSWORD_C]

static func _is_encrypted_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() < 4:
		return false
	return file.get_32() == _ENCRYPTED_FILE_MAGIC
