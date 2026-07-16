extends Node2D

@export var animate: AnimatedSprite2D
@export var collsionShape: CollisionShape2D

signal completed(vortex: Node2D)
signal expired(vortex: Node2D)

const TICK_SECONDS: float = 0.1
const ACTIVATE_SECONDS: float = 3.0
const PROGRESS_GAIN_PER_TICK: float = TICK_SECONDS / ACTIVATE_SECONDS
const PROGRESS_LOSS_PER_TICK: float = 0.01
const LIFE_SECONDS: float = 35.0
const EXPIRING_FLASH_SECONDS: float = 10.0
const EXPIRING_FLASH_MIN_ALPHA_RATIO: float = 0.2
const BAR_SIZE := Vector2(84.0, 8.0)
const BAR_OFFSET := Vector2(-42.0, -70.0)
const VORTEX_Z_INDEX: int = -1
const PROGRESS_BAR_Z_INDEX: int = 100

class ProgressBarLayer:
	extends Node2D

	var progress: float = 0.0

	func _draw() -> void:
		var outer_rect := Rect2(BAR_OFFSET, BAR_SIZE)
		var inner_rect := Rect2(BAR_OFFSET + Vector2(2.0, 2.0), BAR_SIZE - Vector2(4.0, 4.0))
		var fill_width = floor(inner_rect.size.x * progress)
		draw_rect(outer_rect, Color(0.05, 0.08, 0.12, 0.85), true)
		draw_rect(inner_rect, Color(0.18, 0.24, 0.28, 0.85), true)
		if fill_width > 0.0:
			draw_rect(Rect2(inner_rect.position, Vector2(fill_width, inner_rect.size.y)), Color(0.35, 0.95, 1.0, 0.95), true)
		draw_rect(outer_rect, Color(0.72, 1.0, 1.0, 0.95), false, 1.0)

var progress: float = 0.0
var _tick_accumulator: float = 0.0
var _life_time: float = 0.0
var _player_inside: bool = false
var _closing: bool = false
var _base_animate_modulate: Color = Color.WHITE
var _flash_phase: float = 0.0
var _progress_bar_layer: ProgressBarLayer = null

@onready var area: Area2D = $Area2D

func _ready() -> void:
	z_index = VORTEX_Z_INDEX
	_ensure_progress_bar_layer()
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)
	if animate:
		_base_animate_modulate = animate.modulate
		if not animate.is_playing():
			animate.play()

func _ensure_progress_bar_layer() -> void:
	if _progress_bar_layer and is_instance_valid(_progress_bar_layer):
		return
	_progress_bar_layer = ProgressBarLayer.new()
	_progress_bar_layer.name = "ProgressBarLayer"
	_progress_bar_layer.z_as_relative = false
	_progress_bar_layer.z_index = PROGRESS_BAR_Z_INDEX
	_progress_bar_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_progress_bar_layer)
	_update_progress_bar_layer()

func _process(delta: float) -> void:
	if _closing:
		return
	_life_time += delta
	if _life_time >= LIFE_SECONDS:
		_expire()
		return
	_update_expiring_flash(delta)
	_tick_accumulator += delta
	while _tick_accumulator >= TICK_SECONDS:
		_tick_accumulator -= TICK_SECONDS
		_update_progress_tick()

func _update_progress_tick() -> void:
	var old_progress := progress
	if _player_inside:
		progress = min(1.0, progress + PROGRESS_GAIN_PER_TICK)
	else:
		progress = max(0.0, progress - PROGRESS_LOSS_PER_TICK)
	if not is_equal_approx(old_progress, progress):
		_update_progress_bar_layer()
	if progress >= 1.0:
		_complete()

func _update_progress_bar_layer() -> void:
	if _progress_bar_layer and is_instance_valid(_progress_bar_layer):
		_progress_bar_layer.progress = progress
		_progress_bar_layer.queue_redraw()

func _update_expiring_flash(delta: float) -> void:
	if animate == null:
		return
	var time_left := LIFE_SECONDS - _life_time
	if time_left > EXPIRING_FLASH_SECONDS:
		if animate.modulate != _base_animate_modulate:
			animate.modulate = _base_animate_modulate
		return
	var flash_ratio := 1.0 - clampf(time_left / EXPIRING_FLASH_SECONDS, 0.0, 1.0)
	var flash_speed := lerpf(4.0, 18.0, flash_ratio * flash_ratio)
	_flash_phase += delta * flash_speed
	var wave := (sin(_flash_phase * TAU) + 1.0) * 0.5
	var min_alpha := _base_animate_modulate.a * EXPIRING_FLASH_MIN_ALPHA_RATIO
	var max_alpha := _base_animate_modulate.a
	var flash_modulate := _base_animate_modulate
	flash_modulate.a = lerpf(min_alpha, max_alpha, wave)
	animate.modulate = flash_modulate

func get_expiring_flash_alpha(base_alpha: float) -> float:
	var time_left := LIFE_SECONDS - _life_time
	if time_left > EXPIRING_FLASH_SECONDS:
		return base_alpha
	var flash_ratio := 1.0 - clampf(time_left / EXPIRING_FLASH_SECONDS, 0.0, 1.0)
	var wave := (sin(_flash_phase * TAU) + 1.0) * 0.5
	return lerpf(base_alpha * EXPIRING_FLASH_MIN_ALPHA_RATIO, base_alpha, wave)

func _on_area_body_entered(body: Node) -> void:
	if _is_player(body):
		_player_inside = true

func _on_area_body_exited(body: Node) -> void:
	if _is_player(body):
		_player_inside = false

func _is_player(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("player"):
		return true
	return PC.player_instance != null and is_instance_valid(PC.player_instance) and body == PC.player_instance

func _complete() -> void:
	if _closing:
		return
	_closing = true
	_set_collision_enabled(false)
	completed.emit(self)
	_fade_out_and_free()

func _expire() -> void:
	if _closing:
		return
	_closing = true
	_set_collision_enabled(false)
	expired.emit(self)
	_fade_out_and_free()

func _set_collision_enabled(enabled: bool) -> void:
	if area:
		area.monitoring = enabled
		area.monitorable = enabled
	if collsionShape:
		collsionShape.set_deferred("disabled", not enabled)

func _fade_out_and_free() -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
