extends Node2D

## 技能咏唱提示指示器
## 直线型：从玩家位置向鼠标方向延伸的提示线（半透明浅蓝填充 + 不透明蓝色勾边）
## 圆圈型：以玩家为中心的椭圆提示范围（半透明浅蓝填充 + 不透明蓝色勾边）

enum IndicatorMode {LINE, CIRCLE}

var mode: int = IndicatorMode.LINE
var target_player: Node2D = null
var is_frozen: bool = false
var follow_mouse: bool = false # 圆圈模式下是否跟随鼠标位置（用于AoE放置型技能预览）

# 直线模式：当前朝向
var current_direction: Vector2 = Vector2.RIGHT

# 圆圈模式：椭圆大小 (x, y)
var circle_size: Vector2 = Vector2(100, 100)

# 颜色配置
var fill_color: Color = Color(0.2, 0.4, 1.0, 0.15) # 内部半透明浅蓝色
var border_color: Color = Color(0.2, 0.4, 1.0, 0.5) # 勾边不透明蓝色
var line_fill_width: float = 10.0 # 提示线内部宽度
var line_border_width: float = 1.5 # 提示线勾边宽度

func _ready():
	z_index = 5

## 初始化为直线型提示
func setup_line(player: Node2D) -> void:
	mode = IndicatorMode.LINE
	target_player = player

## 初始化为圆圈型提示，size 为椭圆 (宽, 高)，mouse_follow=true 时圆圈跟随鼠标位置
func setup_circle(player: Node2D, size: Vector2, mouse_follow: bool = false) -> void:
	mode = IndicatorMode.CIRCLE
	target_player = player
	circle_size = size
	follow_mouse = mouse_follow

func _process(_delta: float) -> void:
	if is_frozen:
		return
	if not is_instance_valid(target_player):
		queue_free()
		return
	# 圆圈跟随鼠标模式：跟随鼠标世界坐标
	if follow_mouse:
		global_position = get_global_mouse_position()
	else:
		global_position = target_player.global_position
	
	if mode == IndicatorMode.LINE:
		var mouse_pos = get_global_mouse_position()
		var dir = mouse_pos - global_position
		if dir.length() > 0.01:
			current_direction = dir.normalized()
	
	queue_redraw()

func _draw() -> void:
	match mode:
		IndicatorMode.LINE:
			_draw_line_indicator()
		IndicatorMode.CIRCLE:
			_draw_circle_indicator()

func _draw_line_indicator() -> void:
	var start = Vector2.ZERO
	var end = current_direction * 2000.0 # 延伸到屏幕外
	# 先画勾边（外层不透明蓝色，宽 = 填充宽 + 勾边宽*2）
	draw_line(start, end, border_color, line_fill_width + line_border_width * 2.0, true)
	# 再画填充（内层半透明浅蓝色）
	draw_line(start, end, fill_color, line_fill_width, true)

func _draw_circle_indicator() -> void:
	var seg: int = 64
	var points = PackedVector2Array()
	for i in range(seg):
		var angle = TAU * float(i) / float(seg)
		points.append(Vector2(cos(angle) * circle_size.x * 0.5, sin(angle) * circle_size.y * 0.5))
	# 填充
	draw_colored_polygon(points, fill_color)
	# 勾边（闭合）
	var border_pts = points.duplicate()
	border_pts.append(points[0])
	draw_polyline(border_pts, border_color, line_border_width, true)

## 获取当前提示线方向（用于技能发射）
func get_direction() -> Vector2:
	return current_direction

## 获取当前指示器位置（用于AoE放置型技能的目标点）
func get_target_position() -> Vector2:
	return global_position

## 冻结提示线位置，并渐变消失
func freeze_and_fade(duration: float = 0.3) -> void:
	is_frozen = true
	var tween = create_tween()
	tween.tween_property(self , "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)
