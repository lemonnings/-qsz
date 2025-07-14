extends Control

@export var function1 : Button
@export var function2 : Button
@export var function3 : Button
@export var nameLabel : Label

func change_name(text:String):
	nameLabel.text = text

func change_label1_text(text:String):
	function1.text = text

func change_label2_text(text:String):
	function2.text = text

func change_label3_text(text:String):
	function3.text = text

func change_function1_visible(vis:bool):
	function1.visible = vis

func change_function2_visible(vis:bool):
	function2.visible = vis

func change_function3_visible(vis:bool):
	function3.visible = vis

func _on_function_1_pressed() -> void:
	print("f")
	Global.emit_signal("press_f")


func _on_function_2_pressed() -> void:
	print("g")
	Global.emit_signal("press_g")


func _on_function_3_pressed() -> void:
	print("h")
	Global.emit_signal("press_h")
