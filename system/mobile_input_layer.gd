extends CanvasLayer

signal unclaimed_mobile_input(event: InputEvent)

const ACTION_LEFT: StringName = &"left"
const ACTION_RIGHT: StringName = &"right"
const ACTION_UP: StringName = &"up"
const ACTION_DOWN: StringName = &"down"
const JOYSTICK_AREA_SIZE: Vector2 = Vector2(600.0, 420.0)
const JOYSTICK_IDLE_ALPHA: float = 0.2
const JOYSTICK_ACTIVE_ALPHA: float = 0.7
const JOYSTICK_ACTIVATION_DRAG_DISTANCE: float = 22.0
const JOYSTICK_MANUAL_RANGE: float = 170.0
const JOYSTICK_BASE_SIZE: float = 180.0
const JOYSTICK_TIP_SIZE: float = 67.2
const TOUCH_OWNER_MOVEMENT: StringName = &"movement"

var _joystick: Control = null
var _joystick_base: Panel = null
var _joystick_tip: Panel = null
var _last_visible_state: bool = false
var _pending_touch_index: int = -1
var _pending_touch_position: Vector2 = Vector2.ZERO
var _joystick_drag_active: bool = false
var _active_touch_positions: Dictionary = {}
var _active_touch_start_positions: Dictionary = {}
var _touch_owners: Dictionary = {}
var _restore_touch_request_id: int = 0

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_claim_input_priority")
	_create_virtual_joystick()
	if not Global.input_device_mode_changed.is_connected(_on_input_device_mode_changed):
		Global.input_device_mode_changed.connect(_on_input_device_mode_changed)
	if not Global.mobile_input_reset_requested.is_connected(reset_mobile_movement_input):
		Global.mobile_input_reset_requested.connect(reset_mobile_movement_input)
	if not Global.mobile_input_restore_requested.is_connected(restore_mobile_movement_input):
		Global.mobile_input_restore_requested.connect(restore_mobile_movement_input)
	_update_visibility()

func _process(_delta: float) -> void:
	_claim_input_priority()
	_update_visibility()
	if _pending_touch_index == -1 and _should_show_joystick() and not _active_touch_positions.is_empty():
		_restore_active_touch_if_possible()

func _input(event: InputEvent) -> void:
	var touch_index := _get_event_touch_index(event)
	var owner_before: StringName = _touch_owners.get(touch_index, &"")
	_track_active_touch_position(event)
	var movement_consumed := false
	if _should_show_joystick() and _joystick != null:
		movement_consumed = _handle_movement_input(event)
	elif _pending_touch_index != -1:
		_end_joystick_touch()

	if not movement_consumed and _should_route_unclaimed_input(event):
		unclaimed_mobile_input.emit(event)

	var owner_after: StringName = _touch_owners.get(touch_index, &"")
	_finish_touch_tracking(event)
	if movement_consumed or owner_before != &"" or owner_after != &"":
		get_viewport().set_input_as_handled()

func _handle_movement_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _can_begin_joystick_touch(touch.index, touch.position):
				if _begin_joystick_touch(touch.index, touch.position):
					return true
		else:
			if touch.index == _pending_touch_index:
				_end_joystick_touch()
				return true
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var previous_position: Vector2 = drag.position - drag.relative
		if _can_begin_joystick_drag(drag.index, previous_position, drag.position):
			var joystick_start_position: Vector2 = previous_position if _is_point_inside_joystick_activation_area(previous_position) else drag.position
			if _begin_joystick_touch(drag.index, joystick_start_position):
				_joystick_drag_active = true
		if drag.index == _pending_touch_index:
			if not _joystick_drag_active and drag.position.distance_to(_pending_touch_position) >= JOYSTICK_ACTIVATION_DRAG_DISTANCE:
				_joystick_drag_active = true
				if _joystick != null:
					_joystick.modulate.a = JOYSTICK_ACTIVE_ALPHA
			if not _joystick_drag_active:
				_release_movement_actions()
			else:
				_apply_movement_from_drag_position(drag.position)
				_update_joystick_visual(drag.position)
			return true
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				if _pending_touch_index == -1 and _is_point_inside_joystick_activation_area(mouse_button.position):
					return _begin_joystick_touch(-2, mouse_button.position)
			elif _pending_touch_index == -2:
				_end_joystick_touch()
				return true
	elif event is InputEventMouseMotion:
		if _pending_touch_index == -2:
			var motion := event as InputEventMouseMotion
			if not _joystick_drag_active and motion.position.distance_to(_pending_touch_position) >= JOYSTICK_ACTIVATION_DRAG_DISTANCE:
				_joystick_drag_active = true
				if _joystick != null:
					_joystick.modulate.a = JOYSTICK_ACTIVE_ALPHA
			if not _joystick_drag_active:
				_release_movement_actions()
			else:
				_apply_movement_from_drag_position(motion.position)
				_update_joystick_visual(motion.position)
			return true
	return false

func _should_route_unclaimed_input(event: InputEvent) -> bool:
	if not Global.is_mobile_input_mode():
		return false
	if Global.is_level_up or Global.in_menu or PC.is_game_over:
		return false
	var tree := get_tree()
	if tree == null or tree.paused:
		return false
	return event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion

func _get_event_touch_index(event: InputEvent) -> int:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).index
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).index
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return -2
	return -1

func _begin_joystick_touch(touch_index: int, position: Vector2) -> bool:
	if not try_claim_touch(touch_index, TOUCH_OWNER_MOVEMENT):
		return false
	if _pending_touch_index != -1 and _pending_touch_index != touch_index:
		release_touch(_pending_touch_index, TOUCH_OWNER_MOVEMENT)
	_pending_touch_index = touch_index
	_pending_touch_position = position
	_joystick_drag_active = false
	_release_movement_actions()
	return true

func _end_joystick_touch() -> void:
	var ended_touch_index := _pending_touch_index
	_release_movement_actions()
	_reset_joystick_visual()
	_pending_touch_index = -1
	_pending_touch_position = Vector2.ZERO
	_joystick_drag_active = false
	release_touch(ended_touch_index, TOUCH_OWNER_MOVEMENT)

func _claim_input_priority() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var last_index: int = parent_node.get_child_count() - 1
	if last_index >= 0 and parent_node.get_child(last_index) != self:
		# Later siblings receive _input first, so keep movement touch tracking ahead of battle UI consumers.
		parent_node.move_child(self, last_index)

func _can_begin_joystick_touch(touch_index: int, position: Vector2) -> bool:
	if not _is_point_inside_joystick_activation_area(position):
		return false
	if not can_claim_touch(touch_index, TOUCH_OWNER_MOVEMENT):
		return false
	if _pending_touch_index == -1:
		return true
	return _can_replace_pending_joystick_touch(touch_index)

func _can_begin_joystick_drag(touch_index: int, previous_position: Vector2, current_position: Vector2) -> bool:
	if not (_is_point_inside_joystick_activation_area(previous_position) or _is_point_inside_joystick_activation_area(current_position)):
		return false
	if not can_claim_touch(touch_index, TOUCH_OWNER_MOVEMENT):
		return false
	if _pending_touch_index == -1:
		return true
	if _pending_touch_index == touch_index:
		return false
	return _can_replace_pending_joystick_touch(touch_index)

func _can_replace_pending_joystick_touch(touch_index: int) -> bool:
	if _pending_touch_index == touch_index:
		return false
	# 未拖动到激活距离的触摸只是候选项，不能挡住另一根手指接管移动摇杆。
	return not _joystick_drag_active

func _create_virtual_joystick() -> void:
	if _joystick != null:
		return
	_joystick = Control.new()
	_joystick.name = "MobileJoystickVisual"
	_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick.modulate.a = JOYSTICK_IDLE_ALPHA
	_joystick.anchor_left = 0.0
	_joystick.anchor_top = 1.0
	_joystick.anchor_right = 0.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = 0.0
	_joystick.offset_top = - JOYSTICK_AREA_SIZE.y
	_joystick.offset_right = JOYSTICK_AREA_SIZE.x
	_joystick.offset_bottom = 0.0
	_create_joystick_visual_nodes()
	add_child(_joystick)
	_reset_joystick_visual()

func _create_joystick_visual_nodes() -> void:
	_joystick_base = Panel.new()
	_joystick_base.name = "Base"
	_joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_base.size = Vector2(JOYSTICK_BASE_SIZE, JOYSTICK_BASE_SIZE)
	_joystick_base.position = _get_joystick_base_default_position()
	_joystick.add_child(_joystick_base)

	_joystick_tip = Panel.new()
	_joystick_tip.name = "Tip"
	_joystick_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_tip.size = Vector2(JOYSTICK_TIP_SIZE, JOYSTICK_TIP_SIZE)
	_joystick_base.add_child(_joystick_tip)
	_apply_joystick_theme()

func _apply_joystick_theme() -> void:
	var base_style: StyleBoxFlat = StyleBoxFlat.new()
	base_style.bg_color = Color(0.04, 0.045, 0.05, 0.82)
	base_style.border_color = Color(0.78, 0.82, 0.86, 1.0)
	base_style.set_border_width_all(4)
	base_style.set_corner_radius_all(96)
	base_style.shadow_color = Color(0, 0, 0, 0.45)
	base_style.shadow_size = 0

	var base_pressed_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	base_pressed_style.bg_color = Color(0.07, 0.08, 0.09, 0.92)
	base_pressed_style.border_color = Color(1.0, 1.0, 1.0, 1.0)

	var tip_style: StyleBoxFlat = StyleBoxFlat.new()
	tip_style.bg_color = Color(0.80, 0.86, 0.90, 1.0)
	tip_style.border_color = Color(0.18, 0.20, 0.22, 1.0)
	tip_style.set_border_width_all(4)
	tip_style.set_corner_radius_all(48)
	tip_style.shadow_color = Color(0, 0, 0, 0.0)
	tip_style.shadow_size = 0

	var tip_pressed_style: StyleBoxFlat = tip_style.duplicate() as StyleBoxFlat
	tip_pressed_style.bg_color = Color(0.96, 0.98, 1.0, 1.0)

	if _joystick_base:
		_joystick_base.add_theme_stylebox_override("panel", base_style)
	if _joystick_tip:
		_joystick_tip.add_theme_stylebox_override("panel", tip_style)

func _on_input_device_mode_changed(_mode: String) -> void:
	if not Global.is_mobile_input_mode():
		reset_mobile_movement_input()
	_update_visibility()

func _update_visibility() -> void:
	var should_show: bool = _should_show_joystick()
	if visible != should_show:
		visible = should_show
	if _joystick != null and _joystick.visible != should_show:
		_joystick.visible = should_show
	if _last_visible_state and not should_show:
		reset_mobile_movement_input()
	_last_visible_state = should_show

func reset_mobile_movement_input() -> void:
	_end_joystick_touch()
	_request_active_touch_restore()

func restore_mobile_movement_input() -> void:
	_request_active_touch_restore()

func clear_all_mobile_touch_state() -> void:
	_end_joystick_touch()
	_active_touch_positions.clear()
	_active_touch_start_positions.clear()
	_touch_owners.clear()
	_restore_touch_request_id += 1

func can_claim_touch(touch_index: int, owner: StringName) -> bool:
	var current_owner: StringName = _touch_owners.get(touch_index, &"")
	return current_owner == &"" or current_owner == owner

func try_claim_touch(touch_index: int, owner: StringName) -> bool:
	if not can_claim_touch(touch_index, owner):
		return false
	_touch_owners[touch_index] = owner
	return true

func release_touch(touch_index: int, owner: StringName) -> void:
	if touch_index == -1:
		return
	if _touch_owners.get(touch_index, &"") == owner:
		_touch_owners.erase(touch_index)

func is_touch_owned_by(touch_index: int, owner: StringName) -> bool:
	return _touch_owners.get(touch_index, &"") == owner

func is_movement_touch_index(touch_index: int) -> bool:
	return touch_index == _pending_touch_index

func is_movement_drag_active() -> bool:
	return _joystick_drag_active

func _should_show_joystick() -> bool:
	if _joystick == null:
		return false
	if not Global.is_mobile_input_mode():
		return false
	if PC.is_game_over or PC.movement_disabled:
		return false
	if Global.is_level_up or Global.in_menu:
		var scene: Node = get_tree().current_scene
		if scene == null or scene.scene_file_path != "res://Scenes/main_town.tscn":
			return false
	var tree: SceneTree = get_tree()
	if tree == null or tree.paused:
		return false
	if tree.get_first_node_in_group("player") == null:
		return false
	return true

func _track_active_touch_position(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_active_touch_start_positions[touch.index] = touch.position
			_active_touch_positions[touch.index] = touch.position
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _active_touch_start_positions.has(drag.index):
			_active_touch_start_positions[drag.index] = drag.position - drag.relative
		_active_touch_positions[drag.index] = drag.position

func _finish_touch_tracking(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			_active_touch_start_positions.erase(touch.index)
			_active_touch_positions.erase(touch.index)
			_touch_owners.erase(touch.index)

func _request_active_touch_restore() -> void:
	_restore_touch_request_id += 1
	var request_id := _restore_touch_request_id
	_restore_active_touch_after_frame(request_id)

func _restore_active_touch_after_frame(request_id: int) -> void:
	await get_tree().process_frame
	if request_id != _restore_touch_request_id:
		return
	if _pending_touch_index != -1:
		return
	if not _should_show_joystick() or _joystick == null:
		return
	_restore_active_touch_if_possible()

func _restore_active_touch_if_possible() -> void:
	if _pending_touch_index != -1:
		return
	if not _should_show_joystick() or _joystick == null:
		return
	for raw_index in _active_touch_positions.keys():
		var touch_index := int(raw_index)
		var current_position: Vector2 = _active_touch_positions[raw_index]
		var start_position: Vector2 = _active_touch_start_positions.get(raw_index, current_position)
		if not can_claim_touch(touch_index, TOUCH_OWNER_MOVEMENT):
			continue
		if _is_point_inside_joystick_activation_area(start_position) or _is_point_inside_joystick_activation_area(current_position):
			var joystick_start := start_position if _is_point_inside_joystick_activation_area(start_position) else current_position
			if not _begin_joystick_touch(touch_index, joystick_start):
				continue
			if current_position.distance_to(joystick_start) >= JOYSTICK_ACTIVATION_DRAG_DISTANCE:
				_joystick_drag_active = true
				_apply_movement_from_drag_position(current_position)
			if _joystick != null:
				_joystick.modulate.a = JOYSTICK_ACTIVE_ALPHA
			_update_joystick_visual(current_position)
			return

func _is_point_inside_joystick_activation_area(point: Vector2) -> bool:
	if _joystick == null:
		return false
	var center := _joystick.global_position + _get_joystick_base_default_position() + Vector2.ONE * (JOYSTICK_BASE_SIZE * 0.5)
	return point.distance_to(center) <= JOYSTICK_MANUAL_RANGE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_all_mobile_touch_state()

func _get_joystick_base_default_position() -> Vector2:
	return Vector2(
		(JOYSTICK_AREA_SIZE.x - JOYSTICK_BASE_SIZE) * 0.50,
		(JOYSTICK_AREA_SIZE.y - JOYSTICK_BASE_SIZE) * 0.46
	)

func _reset_joystick_visual() -> void:
	if _joystick:
		_joystick.modulate.a = JOYSTICK_IDLE_ALPHA
	if _joystick_base:
		_joystick_base.position = _get_joystick_base_default_position()
	if _joystick_tip:
		_joystick_tip.position = (Vector2(JOYSTICK_BASE_SIZE, JOYSTICK_BASE_SIZE) - Vector2(JOYSTICK_TIP_SIZE, JOYSTICK_TIP_SIZE)) * 0.5

func _update_joystick_visual(position: Vector2) -> void:
	if _joystick == null or _joystick_base == null or _joystick_tip == null:
		return
	_joystick.modulate.a = JOYSTICK_ACTIVE_ALPHA
	var local_start := _pending_touch_position - _joystick.global_position
	var local_position := position - _joystick.global_position
	_joystick_base.position = local_start - Vector2(JOYSTICK_BASE_SIZE, JOYSTICK_BASE_SIZE) * 0.5
	var tip_offset := (local_position - local_start).limit_length(JOYSTICK_BASE_SIZE * 0.5)
	_joystick_tip.position = (Vector2(JOYSTICK_BASE_SIZE, JOYSTICK_BASE_SIZE) - Vector2(JOYSTICK_TIP_SIZE, JOYSTICK_TIP_SIZE)) * 0.5 + tip_offset

func _apply_movement_from_drag_position(position: Vector2) -> void:
	var vector := position - _pending_touch_position
	if vector.length() < JOYSTICK_ACTIVATION_DRAG_DISTANCE:
		_release_movement_actions()
		return
	var direction := vector.normalized()
	_release_movement_actions()
	if direction.x < -0.2:
		Input.action_press(ACTION_LEFT, 1.0)
	elif direction.x > 0.2:
		Input.action_press(ACTION_RIGHT, 1.0)
	if direction.y < -0.2:
		Input.action_press(ACTION_UP, 1.0)
	elif direction.y > 0.2:
		Input.action_press(ACTION_DOWN, 1.0)

func _release_movement_actions() -> void:
	Input.action_release(ACTION_LEFT)
	Input.action_release(ACTION_RIGHT)
	Input.action_release(ACTION_UP)
	Input.action_release(ACTION_DOWN)
