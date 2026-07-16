extends Node

const MOVEMENT_OWNER: StringName = &"movement"
const SKILL_OWNER: StringName = &"battle_skill"

var _errors: Array[String] = []
var _mobile_input: Node = null
var _player: Node2D = null
var _skill_touch_to_claim: int = -1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	Global.set_input_device_mode(Global.INPUT_DEVICE_MODE_MOBILE, false)
	Global.is_level_up = false
	Global.in_menu = false
	PC.is_game_over = false
	PC.movement_disabled = false

	_mobile_input = get_tree().root.get_node_or_null("MobileInput")
	if _mobile_input == null:
		_fail("MobileInput autoload is missing")
		_finish()
		return
	var callback := Callable(self, "_on_unclaimed_mobile_input")
	if not _mobile_input.is_connected("unclaimed_mobile_input", callback):
		_mobile_input.connect("unclaimed_mobile_input", callback)
	_check(not bool(ProjectSettings.get_setting("input_devices/pointing/android/enable_pan_and_scale_gestures", true)), "Android pan/scale gestures must stay disabled")

	_player = Node2D.new()
	_player.name = "MobileInputTestPlayer"
	_player.add_to_group("player")
	get_tree().root.add_child(_player)
	await get_tree().process_frame

	var center: Vector2 = _mobile_input.call("_get_joystick_base_default_position")
	var joystick: Control = _mobile_input.get("_joystick") as Control
	center += joystick.global_position + Vector2.ONE * 90.0

	_test_unrelated_touch_does_not_claim_movement(center)
	_test_active_movement_survives_another_finger(center)
	_test_skill_touch_cannot_be_stolen(center)
	await _test_level_up_restore_keeps_physical_touch(center)
	_finish()


func _test_unrelated_touch_does_not_claim_movement(center: Vector2) -> void:
	_reset_test_state()
	var unrelated := center + Vector2(250.0, -120.0)
	_send_touch(0, unrelated, true)
	_send_drag(0, unrelated + Vector2(35.0, 0.0), Vector2(35.0, 0.0))
	_check(not _mobile_input.call("is_movement_touch_index", 0), "a touch outside the fixed joystick circle claimed movement")

	_send_touch(1, center, true)
	_send_drag(1, center + Vector2(100.0, 0.0), Vector2(100.0, 0.0))
	_check(Input.is_action_pressed("right"), "the joystick did not activate while an unrelated finger was held")
	_send_touch(1, center + Vector2(100.0, 0.0), false)
	_send_touch(0, unrelated + Vector2(35.0, 0.0), false)


func _test_active_movement_survives_another_finger(center: Vector2) -> void:
	_reset_test_state()
	_send_touch(2, center, true)
	_send_drag(2, center + Vector2(0.0, -100.0), Vector2(0.0, -100.0))
	_check(Input.is_action_pressed("up"), "movement did not start before the second-finger test")

	var unrelated := center + Vector2(260.0, -130.0)
	_send_touch(3, unrelated, true)
	_send_drag(3, unrelated + Vector2(40.0, 0.0), Vector2(40.0, 0.0))
	_check(Input.is_action_pressed("up"), "an unrelated second finger released active movement")
	_check(_mobile_input.call("is_touch_owned_by", 2, MOVEMENT_OWNER), "movement ownership changed to the wrong finger")
	_send_touch(3, unrelated + Vector2(40.0, 0.0), false)
	_send_touch(2, center + Vector2(0.0, -100.0), false)


func _test_skill_touch_cannot_be_stolen(center: Vector2) -> void:
	_reset_test_state()
	var skill_position := Vector2(1120.0, 620.0)
	_skill_touch_to_claim = 4
	_send_touch(4, skill_position, true)
	_check(_mobile_input.call("is_touch_owned_by", 4, SKILL_OWNER), "the routed skill touch could not claim its touch index")
	_send_drag(4, center, center - skill_position)
	_check(not _mobile_input.call("is_movement_touch_index", 4), "movement stole a skill-owned touch after it entered the left side")
	_check(not _is_any_movement_action_pressed(), "a skill-owned drag generated movement actions")
	_send_touch(4, center, false)
	_skill_touch_to_claim = -1


func _test_level_up_restore_keeps_physical_touch(center: Vector2) -> void:
	_reset_test_state()
	_send_touch(5, center, true)
	_send_drag(5, center + Vector2(105.0, 0.0), Vector2(105.0, 0.0))
	_check(Input.is_action_pressed("right"), "movement did not start before the level-up reset")

	Global.is_level_up = true
	Global.reset_mobile_input_now()
	_check(not _is_any_movement_action_pressed(), "level-up reset did not release movement actions")
	_check(not _mobile_input.call("is_movement_touch_index", 5), "level-up reset kept stale movement ownership")

	Global.is_level_up = false
	Global.request_mobile_input_restore()
	for _frame in range(4):
		await get_tree().process_frame
	_check(Input.is_action_pressed("right"), "a physically held joystick finger was not restored after level-up")
	_check(_mobile_input.call("is_touch_owned_by", 5, MOVEMENT_OWNER), "restored movement did not reclaim the original touch")
	_send_touch(5, center + Vector2(105.0, 0.0), false)


func _send_touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	_mobile_input.call("_input", event)


func _send_drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	_mobile_input.call("_input", event)


func _on_unclaimed_mobile_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch.index == _skill_touch_to_claim:
			_mobile_input.call("try_claim_touch", touch.index, SKILL_OWNER)


func _reset_test_state() -> void:
	_mobile_input.call("clear_all_mobile_touch_state")
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("up")
	Input.action_release("down")


func _is_any_movement_action_pressed() -> bool:
	return Input.is_action_pressed("left") or Input.is_action_pressed("right") or Input.is_action_pressed("up") or Input.is_action_pressed("down")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_errors.append(message)
	push_error(message)


func _finish() -> void:
	if _mobile_input != null:
		_reset_test_state()
	if is_instance_valid(_player):
		_player.queue_free()
	if _errors.is_empty():
		print("mobile_input_routing_test passed")
		get_tree().quit(0)
		return
	get_tree().quit(1)
