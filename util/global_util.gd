extends Node

var kill_count: int = 0
var _screen_shake_generation: int = 0
var _screen_shake_active: bool = false
var _screen_shake_camera: Camera2D = null
var _screen_shake_base_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	Global.monster_killed.connect(_on_monster_killed)

func reset_kill_count() -> void:
	kill_count = 0

func add_kill_count(amount: int) -> void:
	kill_count += amount

func get_kill_count() -> int:
	return kill_count

func _on_monster_killed() -> void:
	add_kill_count(1)
	SEManager.play("200")

func parse_rect_from_func_string(rect_str: String) -> Rect2:
	var clean = rect_str.replace("Rect2(", "").replace(")", "")
	var parts = clean.split(",")
	if parts.size() == 4:
		return Rect2(
			float(parts[0]), float(parts[1]),
			float(parts[2]), float(parts[3])
		)
	return Rect2(0, 0, 0, 0)


## 屏幕震颤效果（统一入口）
## [param intensity] 震颤强度（像素偏移量）
## [param duration] 震颤持续时间（秒）
## 会检查 Global.screen_shake_enabled，关闭时跳过
func screen_shake(intensity: float = 6.0, duration: float = 0.3) -> void:
	if not Global.screen_shake_enabled:
		return
	var vp = get_viewport()
	var camera = vp.get_camera_2d() if vp else null
	if not camera:
		return
	if not _screen_shake_active or _screen_shake_camera != camera or not is_instance_valid(_screen_shake_camera):
		_screen_shake_base_offset = camera.offset
		_screen_shake_camera = camera
	_screen_shake_active = true
	_screen_shake_generation += 1
	var generation := _screen_shake_generation
	var elapsed := 0.0
	while elapsed < duration:
		if generation != _screen_shake_generation:
			return
		var dt = get_process_delta_time()
		elapsed += dt
		if not is_instance_valid(camera):
			break
		var strength = intensity * (1.0 - elapsed / duration)
		camera.offset = _screen_shake_base_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		await get_tree().process_frame
	if generation == _screen_shake_generation and is_instance_valid(camera):
		camera.offset = _screen_shake_base_offset
		_screen_shake_active = false
		_screen_shake_camera = null
