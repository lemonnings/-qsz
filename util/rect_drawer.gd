extends Node2D
class_name RectDrawer

# 矩形绘制器
# 用于绘制预警范围的矩形形状

var rect_length: float = 100.0
var rect_width: float = 50.0
var rect_angle: float = 0.0

func setup(_length: float, _width: float, _angle: float):
	"""设置绘制参数"""
	rect_length = _length
	rect_width = _width
	rect_angle = _angle
	rotation = rect_angle  # 设置节点旋转
	queue_redraw()  # 请求重绘

func _draw():
	"""绘制矩形"""
	# 计算矩形的四个顶点（以中心为原点）
	var half_length = rect_length / 2.0
	var half_width = rect_width / 2.0
	
	var points = PackedVector2Array([
		Vector2(-half_length, -half_width),  # 左上
		Vector2(half_length, -half_width),   # 右上
		Vector2(half_length, half_width),    # 右下
		Vector2(-half_length, half_width)    # 左下
	])
	
	# 绘制填充的矩形
	draw_colored_polygon(points, Color.WHITE)
	
	# 绘制边框（可选）
	for i in range(points.size()):
		var start_point = points[i]
		var end_point = points[(i + 1) % points.size()]
		draw_line(start_point, end_point, Color.WHITE, 2.0)
