extends TextureButton

var cooldown_time: float
var skill_id: int
var is_paused: bool = false
@export var skill_timer: Timer

# 冷却遮罩纹理（带圆角的正方形）
var _cooldown_mask: Texture2D = null

func _ready() -> void:
	$Label.hide()
	$TextureProgressBar.value = 0
	_cooldown_mask = _create_rounded_square_mask()
	$TextureProgressBar.texture_progress = _cooldown_mask
	# 从12点方向开始顺时针扫描
	$TextureProgressBar.radial_initial_angle = 0.0
	
func update_skill(skill: int, cooldown_time_new: float, skill_icon_url: String) -> void:
	$Label.show()
	skill_id = skill
	var texture = load(skill_icon_url)
	texture_normal = texture
	# 更新遮罩纹理尺寸以匹配技能图标
	if texture:
		_cooldown_mask = _create_rounded_square_mask(texture.get_width(), texture.get_height())
		$TextureProgressBar.texture_progress = _cooldown_mask
	
	# 如果时间没变，只检查是否需要启动
	if abs(cooldown_time - cooldown_time_new) < 0.0001:
		if $Timer.is_stopped():
			$Timer.start()
		return
		
	# 计算当前进度比例，以便保留进度
	var ratio = 1.0
	if not $Timer.is_stopped() and cooldown_time > 0:
		ratio = $Timer.time_left / cooldown_time
	
	# 更新冷却时间
	cooldown_time = cooldown_time_new
	$Timer.wait_time = cooldown_time_new
	
	if $Timer.is_stopped():
		$Timer.start()
	else:
		# 应用保留了比例的新剩余时间
		var new_time_left = cooldown_time_new * ratio
		if new_time_left <= 0.01:
			new_time_left = 0.01
		$Timer.start(new_time_left)
		$Timer.wait_time = cooldown_time_new

## 生成带圆角的正方形遮罩纹理，用于 TextureProgressBar 的时钟扫描效果
func _create_rounded_square_mask(width: int = 72, height: int = 72) -> ImageTexture:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # 透明背景
	var color = Color(0, 0, 0, 0.886275) # 与原来 tscn 中 modulate + tint_under 一致的黑底
	var corner_radius = max(4, int(min(width, height) * 0.08)) # 圆角半径约8%
	# 绘制带圆角的正方形
	for x in range(width):
		for y in range(height):
			if _is_inside_rounded_rect(x, y, width, height, corner_radius):
				img.set_pixel(x, y, color)
	var tex = ImageTexture.create_from_image(img)
	return tex

## 判断像素是否在圆角矩形内部
func _is_inside_rounded_rect(x: int, y: int, w: int, h: int, r: int) -> bool:
	# 四个角的圆心
	var corners = [
		[Vector2(r, r), Vector2(r, r)], # 左上
		[Vector2(w - r - 1, r), Vector2(w - r - 1, r)], # 右上
		[Vector2(r, h - r - 1), Vector2(r, h - r - 1)], # 左下
		[Vector2(w - r - 1, h - r - 1), Vector2(w - r - 1, h - r - 1)] # 右下
	]
	# 检查是否在四个角的圆弧内
	# 左上角
	if x < r and y < r:
		return Vector2(x, y).distance_to(Vector2(r, r)) <= r
	# 右上角
	if x >= w - r and y < r:
		return Vector2(x, y).distance_to(Vector2(w - r - 1, r)) <= r
	# 左下角
	if x < r and y >= h - r:
		return Vector2(x, y).distance_to(Vector2(r, h - r - 1)) <= r
	# 右下角
	if x >= w - r and y >= h - r:
		return Vector2(x, y).distance_to(Vector2(w - r - 1, h - r - 1)) <= r
	# 非角落区域，在矩形内即可
	return true

func _process(delta: float) -> void:
	if cooldown_time <= 0.0:
		return
	$Label.text = "%.2f" % $Timer.time_left
	$TextureProgressBar.value = int(($Timer.time_left / cooldown_time) * 100)

func _on_timer_timeout() -> void:
	$Timer.start()
	$TextureProgressBar.value = 100
	if skill_id == 1:
		Global.emit_signal("skill_cooldown_complete", skill_id)
	elif skill_id == 2:
		Global.emit_signal("skill_cooldown_complete_branch", skill_id)
	elif skill_id == 3:
		Global.emit_signal("skill_cooldown_complete_moyan", skill_id)
	elif skill_id == 4:
		$Timer.stop()
		Global.emit_signal("skill_cooldown_complete_riyan", skill_id)
	elif skill_id == 5:
		$Timer.stop()
		Global.emit_signal("skill_cooldown_complete_ringFire", skill_id)
	elif skill_id == 6:
		Global.emit_signal("skill_cooldown_complete_thunder", skill_id)
	elif skill_id == 7:
		Global.emit_signal("skill_cooldown_complete_bloodwave", skill_id)
	elif skill_id == 8:
		Global.emit_signal("skill_cooldown_complete_bloodboardsword", skill_id)
	elif skill_id == 9:
		Global.emit_signal("skill_cooldown_complete_ice", skill_id)
	elif skill_id == 10:
		Global.emit_signal("skill_cooldown_complete_thunder_break", skill_id)
	elif skill_id == 11:
		Global.emit_signal("skill_cooldown_complete_light_bullet", skill_id)
	elif skill_id == 12:
		Global.emit_signal("skill_cooldown_complete_water", skill_id)
	elif skill_id == 13:
		Global.emit_signal("skill_cooldown_complete_qiankun", skill_id)
	elif skill_id == 14:
		Global.emit_signal("skill_cooldown_complete_xuanwu", skill_id)
	elif skill_id == 15:
		Global.emit_signal("skill_cooldown_complete_xunfeng", skill_id)
	elif skill_id == 16:
		Global.emit_signal("skill_cooldown_complete_genshan", skill_id)
	elif skill_id == 17:
		Global.emit_signal("skill_cooldown_complete_duize", skill_id)
	elif skill_id == 18:
		Global.emit_signal("skill_cooldown_complete_holylight", skill_id)
	elif skill_id == 19:
		Global.emit_signal("skill_cooldown_complete_qigong", skill_id)
	elif skill_id == 20:
		Global.emit_signal("skill_cooldown_complete_dragonwind", skill_id)

func stop_cooldown() -> void:
	$Timer.stop()
	$Label.hide()
	$TextureProgressBar.value = 0

var remaining_time: float = 0

func set_game_paused(pause: bool):
	remaining_time = $Timer.time_left
	is_paused = pause
	if pause:
		$Timer.paused = true
	else:
		$Timer.paused = false
