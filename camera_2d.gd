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
	if not is_instance_valid(get_parent()):
		return
	# 边界限制逻辑
	_clamp_camera_position()
	
	# 镜头行走抖动效果
	_update_walk_bob(delta)

func _clamp_camera_position():
	# 基于 Player（父节点）的全局位置直接计算本地偏移
	# 每帧只写一次 position，不修改 global_position，确保 position_smoothing 正常工作
	var parent_pos = get_parent().global_position

	# 获取当前渲染视口的实际像素尺寸（考虑 stretch 设置）
	var screen_size = get_viewport().get_visible_rect().size

	# 计算当前缩放下，相机视野在世界坐标中的半宽/半高
	var half_viewport_width = screen_size.x / 2.0 / zoom.x
	var half_viewport_height = screen_size.y / 2.0 / zoom.y

	# 计算相机中心允许的最小/最大全局位置
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

	# 从 Player 位置 clamp 出目标全局位置，再转换为本地偏移
	# 玩家在边界内 → position=(0,0)，相机完美跟随
	# 玩家靠近边界 → position 产生偏移，相机停在边界
	position.x = clamp(parent_pos.x, min_x, max_x) - parent_pos.x
	position.y = clamp(parent_pos.y, min_y, max_y) - parent_pos.y

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
