extends Node2D

@export var dialog_control : Control
@export var npc1 : AnimatableBody2D 
@export var npc2 : AnimatableBody2D 
@export var npc3 : AnimatableBody2D 
@export var interaction_distance : float = 40.0 
@export var dialog_file_to_start: String = "res://AssetBundle/Dialog/test_dialog.txt"

var player: CharacterBody2D


func _ready() -> void:
	if $Player is CharacterBody2D:
		player = $Player
	else:
		printerr("Player node not found or not a CharacterBody2D at path: $Player")
		return

	if not Global:
		printerr("Global singleton not found. Make sure it's autoloaded.")
		return

	Global.emit_signal("reset_camera")

	# 确保在项目设置 -> Input Map 中定义了 "interact" 动作并绑定到 F 键
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event_f_key = InputEventKey.new()
		event_f_key.physical_keycode = KEY_F # Godot 4.x
		InputMap.action_add_event("interact", event_f_key)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# 检测 F 键 (映射到 "interact" 动作) 是否按下
	if Input.is_action_just_pressed("interact"):
		if player.global_position.distance_to($NPC1/AnimatedSprite2D.global_position) < interaction_distance:
			if not dialog_control.visible:
				start_dialog_interaction(1)
			else:
				print_debug("Dialog is already active.")

		#if player.global_position.distance_to($NPC2/AnimatedSprite2D.global_position) < interaction_distance:
			#if not dialog_control.visible:
				#start_dialog_interaction(2)
			#else:
				#print_debug("Dialog is already active.")

func start_dialog_interaction(npc_id: int) -> void:
	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	# 确保 dialog_control 可见
	dialog_control.visible = true

	Global.start_dialog.emit(dialog_file_to_start)