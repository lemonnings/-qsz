extends Area2D

## 毒圈持续伤害区域
## 椭圆形，长40像素（水平），宽30像素（垂直），4:3比例
## 通过 scale = Vector2(4/3, 1) 配合 CircleShape2D(radius=15) 实现椭圆碰撞体

var damage_per_tick: float = 0.0 # 每秒伤害（由外部赋值）
var duration: float = 5.0 # 持续时间（秒）
const FADE_IN_TIME: float = 0.6 # 渐入时间（秒）
const FADE_OUT_TIME: float = 0.8 # 渐出时间（秒）
const TICK_INTERVAL: float = 1.0 # 伤害间隔（秒）

var tick_timer: float = 0.0
var life_timer: float = 0.0
var player_inside: bool = false
var fading_out: bool = false
var pulse_time: float = 0.0

func _ready():
	modulate.a = 0.0
	# 渐入动画
	var tween = create_tween()
	tween.tween_property(self , "modulate:a", 0.65, FADE_IN_TIME)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	life_timer += delta
	pulse_time += delta
	queue_redraw() # 每帧重绘（脉冲动画）

	# 到达结束时间前开始渐出
	if life_timer >= duration - FADE_OUT_TIME and not fading_out:
		fading_out = true
		var tween = create_tween()
		tween.tween_property(self , "modulate:a", 0.0, FADE_OUT_TIME)
		tween.tween_callback(queue_free)

	# 每秒对圈内玩家造成伤害
	if player_inside and not PC.invincible:
		tick_timer += delta
		if tick_timer >= TICK_INTERVAL:
			tick_timer -= TICK_INTERVAL
			var dmg = max(1, int(damage_per_tick))
			PC.apply_damage(dmg)
			Global.emit_signal("player_hit")

func _draw():
	# 像素风格绘制 —— 用 2×2 像素块拼出椭圆
	# scale=(4/3,1) 将本地圆(r=15)拉伸为 40×30 像素椭圆
	var R: float = 15.0
	const P: int = 2 # 像素块边长
	var pulse: float = (sin(pulse_time * 2.5) + 1.0) * 0.5

	# 颜色定义
	var col_border = Color(0.30, 1.00, 0.20, 1.00) # 外框实心像素
	var col_ring = Color(0.15, 0.85, 0.15, 0.72 + pulse * 0.18) # 中间棋盘环
	var col_fill = Color(0.05, 0.50, 0.08, 0.48 + pulse * 0.12) # 外填充稀疏点
	var col_inner = Color(0.02, 0.28, 0.04, 0.28 + pulse * 0.10) # 内核极稀疏

	# 各区域半径平方
	var R2: float = R * R
	var Rbord2: float = (R - P * 1.5) * (R - P * 1.5)
	var Rmid2: float = (R * 0.65) * (R * 0.65)
	var Rin2: float = (R * 0.35) * (R * 0.35)

	var gx: int = - int(R) - P
	while gx < int(R) + P:
		var gy: int = - int(R) - P
		while gy < int(R) + P:
			var cx: float = gx + P * 0.5
			var cy: float = gy + P * 0.5
			var d2: float = cx * cx + cy * cy
			if d2 <= R2:
				var rect = Rect2(gx, gy, P, P)
				var gxi: int = int(gx / float(P))
				var gyi: int = int(gy / float(P))
				if d2 >= Rbord2:
					# 外框：每块都画（实心像素环）
					draw_rect(rect, col_border)
				elif d2 >= Rmid2:
					# 中间环：棋盘格抖动，模拟半透明
					if (gxi + gyi) % 2 == 0:
						draw_rect(rect, col_ring)
					else:
						draw_rect(rect, col_fill)
				elif d2 >= Rin2:
					# 外填充：每3格画1格
					if (gxi + gyi) % 3 == 0:
						draw_rect(rect, col_fill)
				else:
					# 内核：每4格画1格
					if (gxi + gyi) % 4 == 0:
						draw_rect(rect, col_inner)
			gy += P
		gx += P

	# 像素气泡：绕圈旋转，吸附到像素网格
	var bubble_color = Color(0.55, 1.0, 0.40, 0.95)
	for i in range(4):
		var angle: float = (TAU / 4.0) * i + pulse_time * 0.8
		var bx: float = round(cos(angle) * R * 0.62 / P) * P
		var by: float = round(sin(angle) * R * 0.62 / P) * P
		draw_rect(Rect2(bx - P, by - P, P * 2, P * 2), bubble_color)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_inside = true
		tick_timer = 0.0
		# 踩入立刻判定一次伤害
		if not PC.invincible:
			var dmg = max(1, int(damage_per_tick))
			PC.apply_damage(dmg)
			Global.emit_signal("player_hit")

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_inside = false
