extends Node

# 双指缩放相关变量
var pinch_start_distance : float = 0.0  # 双指初始距离
var pinch_start_zoom : float = 0.0  # 缩放开始时的zoom值
var is_pinching : bool = false  # 是否正在双指缩放

var touch_points : Dictionary = {} # 存储触摸点信息

@export var min_zoom : float = 2  # 最小缩放（视野最大）
@export var max_zoom : float = 5.2  # 最大缩放（视野最小）
@onready var camera : Camera2D # 需要从外部传入Camera2D节点

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
		# 检查双指缩放
		_check_pinch_gesture()
	else:
		# 触摸结束
		touch_points.erase(event.index)
		
		# 检查是否结束双指缩放
		if touch_points.size() < 2:
			is_pinching = false

# 处理拖拽输入
func _handle_drag_input(event: InputEventScreenDrag) -> void:
	var touch_pos = event.position
	touch_points[event.index] = touch_pos
	
	# 更新双指缩放
	if is_pinching and touch_points.size() >= 2:
		_update_pinch_zoom()

# 检查双指缩放手势
func _check_pinch_gesture() -> void:
	if touch_points.size() == 2:
		var touch_positions = touch_points.values()
		pinch_start_distance = touch_positions[0].distance_to(touch_positions[1])
		pinch_start_zoom = camera.zoom.x
		is_pinching = true

# 更新双指缩放
func _update_pinch_zoom() -> void:
	var touch_positions = touch_points.values()
	var current_distance = touch_positions[0].distance_to(touch_positions[1])
	
	if pinch_start_distance > 0:
		var scale_factor = current_distance / pinch_start_distance
		var new_zoom = pinch_start_zoom * scale_factor
		
		# 限制缩放范围
		new_zoom = clamp(new_zoom, min_zoom, max_zoom)
		
		# 检查缩放后是否会超出场景边界
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_rect_size = viewport_size / new_zoom
		
		# 获取场景边界
		var limit_left = camera.limit_left
		var limit_right = camera.limit_right
		var limit_top = camera.limit_top
		var limit_bottom = camera.limit_bottom
		
		# 计算场景大小
		var scene_width = limit_right - limit_left
		var scene_height = limit_bottom - limit_top
		
		# 确保缩放后的视野不会超出场景边界
		if camera_rect_size.x <= scene_width and camera_rect_size.y <= scene_height:
			camera.zoom = Vector2(new_zoom, new_zoom)
