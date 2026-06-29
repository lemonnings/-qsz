extends Control

@export var function1 : Button
@export var function2 : Button
@export var function3 : Button
@export var nameLabel : Label

var _name_source_text: String = ""
var _name_source_visible: bool = true
var _label1_source_text: String = ""
var _label2_source_text: String = ""
var _label3_source_text: String = ""
var _function1_source_visible: bool = true
var _function2_source_visible: bool = true
var _function3_source_visible: bool = true

func _ready() -> void:
	_name_source_text = nameLabel.text if nameLabel else ""
	_name_source_visible = nameLabel.visible if nameLabel else false
	_label1_source_text = function1.text if function1 else ""
	_label2_source_text = function2.text if function2 else ""
	_label3_source_text = function3.text if function3 else ""
	_function1_source_visible = function1.visible if function1 else false
	_function2_source_visible = function2.visible if function2 else false
	_function3_source_visible = function3.visible if function3 else false
	if not Global.input_device_mode_changed.is_connected(_on_input_device_mode_changed):
		Global.input_device_mode_changed.connect(_on_input_device_mode_changed)
	_refresh_name_text()
	_refresh_action_texts()

func change_name(text:String):
	_name_source_text = text
	_refresh_name_text()

func change_label1_text(text:String):
	_label1_source_text = text
	_refresh_action_texts()

func change_label2_text(text:String):
	_label2_source_text = text
	_refresh_action_texts()

func change_label3_text(text:String):
	_label3_source_text = text
	_refresh_action_texts()

func change_function1_visible(vis:bool):
	_function1_source_visible = vis
	_refresh_action_texts()

func change_function2_visible(vis:bool):
	_function2_source_visible = vis
	_refresh_action_texts()

func change_function3_visible(vis:bool):
	_function3_source_visible = vis
	_refresh_action_texts()

func _format_action_text_for_device(text: String) -> String:
	if not Global.is_mobile_input_mode():
		return text
	var regex := RegEx.new()
	regex.compile("\\s*\\[[^\\]]+\\]")
	return regex.sub(text, "", true).strip_edges()

func _format_name_text_for_device(text: String) -> String:
	if not Global.is_mobile_input_mode():
		return text
	var parts: PackedStringArray = text.split("\n", false)
	if parts.is_empty():
		return ""
	return str(parts[0]).strip_edges()

func _refresh_name_text() -> void:
	if nameLabel:
		nameLabel.text = _format_name_text_for_device(_name_source_text)
		nameLabel.visible = _name_source_visible and not Global.is_mobile_input_mode()

func _refresh_action_texts() -> void:
	if function1:
		function1.text = _format_action_text_for_device(_label1_source_text)
		function1.visible = _function1_source_visible and not Global.is_mobile_input_mode()
	if function2:
		function2.text = _format_action_text_for_device(_label2_source_text)
		function2.visible = _function2_source_visible and not Global.is_mobile_input_mode()
	if function3:
		function3.text = _format_action_text_for_device(_label3_source_text)
		function3.visible = _function3_source_visible and not Global.is_mobile_input_mode()

func _on_input_device_mode_changed(_mode: String) -> void:
	_refresh_name_text()
	_refresh_action_texts()

func _on_function_1_pressed() -> void:
	print("f")
	Global.emit_signal("press_f")


func _on_function_2_pressed() -> void:
	print("g")
	Global.emit_signal("press_g")


func _on_function_3_pressed() -> void:
	print("h")
	Global.emit_signal("press_h")
