extends CanvasLayer

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

var _joystick: Control = null
var _joystick_base: Panel = null
var _joystick_tip: Panel = null
var _last_visible_state: bool = false
var _pending_touch_index: int = -1
var _pending_touch_position: Vector2 = Vector2.ZERO
var _joystick_drag_active: bool = false

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_virtual_joystick()
	if not Global.input_device_mode_changed.is_connected(_on_input_device_mode_changed):
		Global.input_device_mode_changed.connect(_on_input_device_mode_changed)
	if not Global.mobile_input_reset_requested.is_connected(reset_mobile_movement_input):
		Global.mobile_input_reset_requested.connect(reset_mobile_movement_input)
	_update_visibility()

func _process(_delta: float) -> void:
	_update_visibility()

func _input(event: InputEvent) -> void:
	if not _should_show_joystick() or _joystick == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _pending_touch_index == -1 and _is_point_inside_joystick_area(touch.position):
				_pending_touch_index = touch.index
				_pending_touch_position = touch.position
				_joystick_drag_active = false
				_release_movement_actions()
		else:
			if touch.index == _pending_touch_index:
				var was_drag_active: bool = _joystick_drag_active
				_release_movement_actions()
				_reset_joystick_visual()
				_pending_touch_index = -1
				_pending_touch_position = Vector2.ZERO
				_joystick_drag_active = false
				if was_drag_active:
					get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
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
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				if _pending_touch_index == -1 and _is_point_inside_joystick_area(mouse_button.position):
					_pending_touch_index = -2
					_pending_touch_position = mouse_button.position
					_joystick_drag_active = false
					_release_movement_actions()
			elif _pending_touch_index == -2:
				var was_drag_active: bool = _joystick_drag_active
				_release_movement_actions()
				_reset_joystick_visual()
				_pending_touch_index = -1
				_pending_touch_position = Vector2.ZERO
				_joystick_drag_active = false
				if was_drag_active:
					get_viewport().set_input_as_handled()
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
			get_viewport().set_input_as_handled()

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
	_release_movement_actions()
	_pending_touch_index = -1
	_pending_touch_position = Vector2.ZERO
	_joystick_drag_active = false
	_reset_joystick_visual()

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

func _is_point_inside_joystick_area(point: Vector2) -> bool:
	if _joystick == null:
		return false
	var rect := Rect2(_joystick.global_position, _joystick.size)
	return rect.has_point(point)

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
