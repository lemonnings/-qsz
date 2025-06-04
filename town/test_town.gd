extends Node2D

@export var dialog_control : Control
@export var npc1 : AnimatableBody2D 
@export var interaction_distance : float = 40.0 
@export var dialog_file_to_start: String = "res://AssetBundle/Dialog/test_dialog.csv"

var player: CharacterBody2D


func _ready() -> void:
	if $Player is CharacterBody2D:
		player = $Player
	else:
		printerr("Player node not found or not a CharacterBody2D at path: $Player")
		return
		
	Global.emit_signal("reset_camera")


	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event_f_key = InputEventKey.new()
		event_f_key.physical_keycode = KEY_F # Godot 4.x
		InputMap.action_add_event("interact", event_f_key)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

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

	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	dialog_control.visible = true
	print_debug("Activated dialog_control in test_town.")

	Global.start_dialog.emit(dialog_file_to_start)
	print_debug("Emitted start_dialog signal with: ", dialog_file_to_start)
