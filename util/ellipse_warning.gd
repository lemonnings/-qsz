extends Node2D

## 椭圆形AOE预警视觉效果
## 参考 WarnRectUtil 的预警闪烁 + poison_circle 的像素风格椭圆绘制

# 预警参数
var ellipse_a: float = 20.0 # 半长轴（水平）
var ellipse_b: float = 15.0 # 半短轴（垂直）
var warning_time: float = 2.0 # 预警持续时间
var current_time: float = 0.0
var is_active: bool = false
var pulse_time: float = 0.0

func start(pos: Vector2, a: float, b: float, time: float) -> void:
	"""开始预警
	pos: 预警中心位置
	a: 椭圆半长轴（水平像素）
	b: 椭圆半短轴（垂直像素）
	time: 预警持续时间（秒）
	"""
	ellipse_a = a
	ellipse_b = b
	warning_time = time
	global_position = pos
	current_time = 0.0
	is_active = true
	pulse_time = 0.0

func _process(delta: float) -> void:
	if not is_active:
		return
	current_time += delta
	pulse_time += delta
	queue_redraw()
	
	if current_time >= warning_time:
		is_active = false
		queue_free()

func _draw():
	if not is_active:
		return
	
	var progress = current_time / warning_time
	
	# 预警闪烁效果（参考 WarnRectUtil）
	var alpha: float
	if progress <= 0.75:
		alpha = 0.25
	elif progress <= 0.9:
		var blink_progress = (progress - 0.75) / 0.15
		var blink_speed = 5.0 + blink_progress * 10.0
		var blink_alpha = (sin(pulse_time * blink_speed) + 1.0) * 0.5
		alpha = 0.25 * (0.25 + blink_alpha * 0.75)
	else:
		var fade_progress = (progress - 0.9) / 0.1
		alpha = 0.4 * (1.0 - fade_progress)
	
	# 像素风格绘制椭圆（参考 poison_circle.gd）
	const P: int = 2 # 像素块边长
	
	# 颜色定义
	var col_border = Color(1.0, 0.3, 0.3, min(alpha * 2.5, 1.0)) # 红色外框
	var col_ring = Color(1.0, 0.2, 0.2, alpha * 0.8) # 中间棋盘环
	var col_fill = Color(0.8, 0.1, 0.1, alpha * 0.5) # 外填充
	var col_inner = Color(0.5, 0.05, 0.05, alpha * 0.3) # 内核
	
	var A: float = ellipse_a
	var B: float = ellipse_b
	var A2: float = A * A
	var B2: float = B * B
	
	# 各区域半径比例
	var Abord2: float = (A * 0.85) * (A * 0.85)
	var Bbord2: float = (B * 0.85) * (B * 0.85)
	var Amid2: float = (A * 0.6) * (A * 0.6)
	var Bmid2: float = (B * 0.6) * (B * 0.6)
	var Ain2: float = (A * 0.3) * (A * 0.3)
	var Bin2: float = (B * 0.3) * (B * 0.3)
	
	var gx: int = - int(A) - P
	while gx < int(A) + P:
		var gy: int = - int(B) - P
		while gy < int(B) + P:
			var cx: float = gx + P * 0.5
			var cy: float = gy + P * 0.5
			# 椭圆方程判断
			var dx2: float = cx * cx
			var dy2: float = cy * cy
			if (dx2 / A2 + dy2 / B2) <= 1.0:
				var rect = Rect2(gx, gy, P, P)
				var gxi: int = int(gx / float(P))
				var gyi: int = int(gy / float(P))
				if dx2 >= Abord2 or dy2 >= Bbord2:
					# 外框：实心像素环
					draw_rect(rect, col_border)
				elif dx2 >= Amid2 or dy2 >= Bmid2:
					# 中间环：棋盘格
					if (gxi + gyi) % 2 == 0:
						draw_rect(rect, col_ring)
					else:
						draw_rect(rect, col_fill)
				elif dx2 >= Ain2 or dy2 >= Bin2:
					# 外填充：每3格画1格
					if (gxi + gyi) % 3 == 0:
						draw_rect(rect, col_fill)
				else:
					# 内核：每4格画1格
					if (gxi + gyi) % 4 == 0:
						draw_rect(rect, col_inner)
			gy += P
		gx += P
