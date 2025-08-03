extends Node2D
class_name SectorDrawer

# 扇形绘制器
# 用于绘制预警范围的扇形形状

var sector_radius: float = 200.0
var sector_angle: float = 60.0  # 扇形角度（度）
var center_direction: float = 0.0  # 扇形中心方向（弧度）
var segments: int = 32  # 扇形分段数，越大越平滑

func setup(_radius: float, _angle: float, _direction: float):
	"""设置绘制参数"""
	sector_radius = _radius
	sector_angle = _angle
	center_direction = _direction
	queue_redraw()  # 请求重绘

func _draw():
	"""绘制扇形"""
	var points = PackedVector2Array()
	
	# 添加扇形顶点（原点）
	points.append(Vector2.ZERO)
	
	# 计算扇形的起始和结束角度
	var half_angle = deg_to_rad(sector_angle / 2.0)
	var start_angle = center_direction - half_angle
	var end_angle = center_direction + half_angle
	
	# 生成扇形弧线的顶点
	for i in range(segments + 1):
		var progress = float(i) / float(segments)
		var current_angle = start_angle + (end_angle - start_angle) * progress
		var x = cos(current_angle) * sector_radius
		var y = sin(current_angle) * sector_radius
		points.append(Vector2(x, y))
	
	# 绘制填充的扇形
	draw_colored_polygon(points, Color.WHITE)
	
	# 绘制边框（可选）
	# 绘制两条边线
	draw_line(Vector2.ZERO, points[1], Color.WHITE, 2.0)  # 起始边
	draw_line(Vector2.ZERO, points[points.size() - 1], Color.WHITE, 2.0)  # 结束边
	
	# 绘制弧线
	for i in range(1, points.size() - 1):
		var start_point = points[i]
		var end_point = points[i + 1]
		draw_line(start_point, end_point, Color.WHITE, 2.0)
