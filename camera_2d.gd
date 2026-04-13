extends Camera2D
# Camera2D 边界限制脚本（Godot 4.6 兼容）
# 挂在 Camera2D 节点上

func _process(_delta):
	# 获取当前渲染视口的实际像素尺寸（考虑 stretch 设置）
	var screen_size = get_viewport().get_visible_rect().size

	# 计算当前缩放下，相机视野在世界坐标中的半宽/半高
	# 注意：zoom 是 Vector2，可能 x/y 不同（如非等比缩放）
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
		# 获取当前渲染视口的中心（平滑后的位置）
		var current_center = get_screen_center_position()
		
		# 检查当前渲染位置是否在合法范围内（允许微小误差）
		# 如果因为缩放导致边界收缩，当前渲染位置可能瞬间变得非法
		# 此时必须强制重置平滑，否则会看到边界外的区域
		if current_center.x < min_x - 1.0 or current_center.x > max_x + 1.0 or \
		   current_center.y < min_y - 1.0 or current_center.y > max_y + 1.0:
			reset_smoothing()
