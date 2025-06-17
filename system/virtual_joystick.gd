extends Node

# 手机适配相关变量
@export var virtual_joystick_enabled : bool = true  # 是否启用虚拟摇杆
@export var joystick_deadzone : float = 0.1  # 摇杆死区
@export var joystick_radius : float = 100.0  # 摇杆半径
@export var joystick_position : Vector2 = Vector2(150, 400)  # 摇杆位置

# 触摸输入相关变量
var touch_points : Dictionary = {}  # 存储触摸点信息
var joystick_touch_id : int = -1  # 摇杆触摸ID
var joystick_center : Vector2  # 摇杆中心位置
var joystick_current : Vector2  # 当前摇杆位置
var is_joystick_active : bool = false  # 摇杆是否激活
var movement_vector : Vector2 = Vector2.ZERO  # 移动向量

func _ready() -> void:
	# 初始化虚拟摇杆
	joystick_center = joystick_position
	joystick_current = joystick_center

func _input(event: InputEvent) -> void:
	# 处理触摸输入
	if event is InputEventScreenTouch:
		_handle_touch_input(event)
	elif event is InputEventScreenDrag:
		_handle_drag_input(event)

# 处理触摸输入
func _handle_touch_input(event: InputEventScreenTouch) -> void:
	var touch_pos = event.position
	
	if event.pressed:
		# 触摸开始
		touch_points[event.index] = touch_pos
		
		# 检查是否在虚拟摇杆区域内
		if virtual_joystick_enabled and joystick_touch_id == -1:
			var distance_to_joystick = touch_pos.distance_to(joystick_center)
			if distance_to_joystick <= joystick_radius:
				joystick_touch_id = event.index
				is_joystick_active = true
				_update_joystick(touch_pos)
	else:
		# 触摸结束
		if event.index == joystick_touch_id:
			# 摇杆触摸结束
			joystick_touch_id = -1
			is_joystick_active = false
			movement_vector = Vector2.ZERO
			joystick_current = joystick_center
		
		touch_points.erase(event.index)

# 处理拖拽输入
func _handle_drag_input(event: InputEventScreenDrag) -> void:
	var touch_pos = event.position
	touch_points[event.index] = touch_pos
	
	# 更新虚拟摇杆
	if event.index == joystick_touch_id and is_joystick_active:
		_update_joystick(touch_pos)

# 更新虚拟摇杆
func _update_joystick(touch_pos: Vector2) -> void:
	var offset = touch_pos - joystick_center
	var distance = offset.length()
	
	# 限制摇杆范围
	if distance > joystick_radius:
		offset = offset.normalized() * joystick_radius
		distance = joystick_radius
	
	joystick_current = joystick_center + offset
	
	# 计算移动向量
	if distance > joystick_deadzone:
		movement_vector = offset.normalized() * ((distance - joystick_deadzone) / (joystick_radius - joystick_deadzone))
	else:
		movement_vector = Vector2.ZERO

# 获取虚拟摇杆的渲染信息（供UI显示使用）
func get_joystick_info() -> Dictionary:
	return {
		"center": joystick_center,
		"current": joystick_current,
		"radius": joystick_radius,
		"active": is_joystick_active,
		"enabled": virtual_joystick_enabled
	}

func get_movement_vector() -> Vector2:
	return movement_vector
