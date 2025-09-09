extends Node2D
class_name CircleDrawer

# 圆形/椭圆形绘制器
# 用于绘制预警范围的形状

var radius: float = 100.0
var aspect_ratio: float = 1.0
var segments: int = 64  # 圆形分段数，越大越平滑

func setup(_radius: float, _aspect_ratio: float):
	radius = _radius
	aspect_ratio = _aspect_ratio
	queue_redraw()  # 请求重绘

func _draw():
	var points = PackedVector2Array()
	
	# 生成圆形/椭圆形的顶点
	for i in range(segments + 1):
		var angle = (i * 2.0 * PI) / segments
		var x = cos(angle) * radius * aspect_ratio
		var y = sin(angle) * radius
		points.append(Vector2(x, y))
	
	# 绘制填充的圆形/椭圆形
	draw_colored_polygon(points, Color.WHITE)
	
	# 绘制边框（可选）
	for i in range(segments):
		var start_point = points[i]
		var end_point = points[i + 1]
		draw_line(start_point, end_point, Color.WHITE, 2.0)
