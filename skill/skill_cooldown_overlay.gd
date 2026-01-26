extends TextureButton

var cooldown_time: float
var skill_id: int
var is_paused: bool = false
@export var skill_timer: Timer

func _ready() -> void:
	$Label.hide()
	$TextureProgressBar.value = 0
	$TextureProgressBar.texture_progress = texture_normal
	
func update_skill(skill: int, cooldown_time_new: float, skill_icon_url: String) -> void:
	$Label.show()
	skill_id = skill
	var texture = load(skill_icon_url)
	texture_normal = texture
	
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

func _process(delta: float) -> void:
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

var remaining_time: float = 0

func set_game_paused(pause: bool):
	remaining_time = $Timer.time_left
	is_paused = pause
	if pause:
		$Timer.paused = true
	else:
		$Timer.paused = false
