extends Camera2D
# Camera2D 边界限制脚本（Godot 4.6 兼容）
# 挂在 Camera2D 节点上

# ---------- 主角行走镜头上下抖动配置 ----------
@export var bob_amplitude: float = 0 # 抖动幅度（像素），设为0可关闭
@export var bob_frequency: float = 11.0 # 抖动频率
@export var bob_smoothing: float = 0.5 # 停止行走时平滑恢复速度
# -----------------------------------------------

var _bob_timer: float = 0.0
var _base_offset_y: float = 0.0
var _current_bob: float = 0.0

func _ready():
	_base_offset_y = offset.y

func _process(delta):
	# 边界限制逻辑
	_clamp_camera_position()
	
	# 镜头行走抖动效果
	_update_walk_bob(delta)

func _clamp_camera_position():
	# 获取当前渲染视口的实际像素尺寸（考虑 stretch 设置）
	var screen_size = get_viewport().get_visible_rect().size

	# 计算当前缩放下，相机视野在世界坐标中的半宽/半高
	var half_viewport_width = screen_size.x / 2.0 / zoom.x
	var half_viewport_height = screen_size.y / 2.0 / zoom.y

	# 计算相机中心允许的最小/最大位置
	var min_x = limit_left + half_viewport_width
	var max_x = limit_right - half_viewport_width
	var min_y = limit_top + half_viewport_height
	var max_y = limit_bottom - half_viewport_height

	# 处理视野大于地图的极端情况（避免 clamp 区间无效）
	if min_x > max_x:
		var center_x = (limit_left + limit_right) / 2.0
		min_x = center_x
		max_x = center_x
	if min_y > max_y:
		var center_y = (limit_top + limit_bottom) / 2.0
		min_y = center_y
		max_y = center_y

	# 强制将相机中心限制在合法范围内
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)

	# 修复平滑滞后导致的视野出界问题
	if is_position_smoothing_enabled():
		var current_center = get_screen_center_position()
		if current_center.x < min_x - 1.0 or current_center.x > max_x + 1.0 or \
		   current_center.y < min_y - 1.0 or current_center.y > max_y + 1.0:
			reset_smoothing()

func _update_walk_bob(delta: float):
	if bob_amplitude <= 0.0:
		_current_bob = move_toward(_current_bob, 0.0, bob_smoothing * delta)
		offset.y = _base_offset_y + _current_bob
		return
	
	var player = get_parent()
	if not (player is CharacterBody2D):
		return
	
	var is_moving = player.velocity.length_squared() > 1.0
	
	if is_moving:
		_bob_timer += delta * bob_frequency
		_current_bob = sin(_bob_timer) * bob_amplitude
		offset.y = _base_offset_y + _current_bob
	else:
		_bob_timer = 0.0
		_current_bob = move_toward(_current_bob, 0.0, bob_smoothing * delta)
		offset.y = _base_offset_y + _current_bob
