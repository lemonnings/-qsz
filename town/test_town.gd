extends Node2D

@export var dialog_control : Control
@export var npc1 : AnimatableBody2D 
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
		print_rich("[color=yellow]Warning:[/color] Input action 'interact' was not found. Temporarily mapped to F key. Please configure it in Project > Project Settings > Input Map.")


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# 检测 F 键 (映射到 "interact" 动作) 是否按下
	if Input.is_action_just_pressed("interact"):
		if player.global_position.distance_to($NPC1/AnimatedSprite2D.global_position) < interaction_distance:
			if not dialog_control.visible:
				start_dialog_interaction()
			else:
				print_debug("Dialog is already active.")


func start_dialog_interaction() -> void:
	if not dialog_control:
		printerr("Dialog control (Control) is not set in test_town.gd. Please assign it in the editor.")
		return

	# 确保 dialog_control 已经添加到场景树中，如果它不是当前场景的子节点，则添加它。
	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	# 确保 dialog_control 可见
	dialog_control.visible = true
	print_debug("Activated dialog_control in test_town.")

	# 发出信号，dialog_manager.gd (在 current_dialog_instance 内部) 应该监听这个信号
	Global.start_dialog.emit(dialog_file_to_start)
	print_debug("Emitted start_dialog signal with: ", dialog_file_to_start)

	# 提示：dialog_manager.gd 中的 _end_dialog() 函数应该负责 queue_free() 对话框实例自身。
	# 例如，在 _end_dialog() 中添加 self.queue_free()
	# 并且，dialog_manager.gd 的 _ready() 函数中需要连接 Global.start_dialog 信号。
	# (e.g., Global.start_dialog.connect(_on_global_start_dialog))
	
