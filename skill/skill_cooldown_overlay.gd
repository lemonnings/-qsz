extends TextureButton

var cooldown_time: float
var skill_id: int
var is_paused : bool = false


func _ready() -> void:
	$Label.hide()
	$TextureProgressBar.value = 0
	$TextureProgressBar.texture_progress = texture_normal
	
func update_skill(skill: int, cooldown_time_new: float, skill_icon_url: String) -> void:
	$Label.show()
	$Timer.start()
	skill_id = skill
	cooldown_time = cooldown_time_new
	$Timer.wait_time = cooldown_time_new
	var texture = load(skill_icon_url)
	texture_normal = texture

func _process(delta: float) -> void:
	$Label.text = "%.2f" % $Timer.time_left
	$TextureProgressBar.value = int(($Timer.time_left / cooldown_time ) * 100)

func _on_timer_timeout() -> void:
	$Timer.start()
	$TextureProgressBar.value = 100
	if skill_id == 1:
		Global.emit_signal("skill_cooldown_complete", skill_id)
	if skill_id == 2:
		Global.emit_signal("skill_cooldown_complete_branch", skill_id)

func set_game_paused(pause: bool):
	is_paused = pause
	if pause:
		$Timer.stop()
	else:
		$Timer.start()
