extends Node2D

@export var animate: AnimatedSprite2D
@export var collsionShape: CollisionShape2D

signal completed(vortex: Node2D)
signal expired(vortex: Node2D)

const TICK_SECONDS: float = 0.1
const PROGRESS_GAIN_PER_TICK: float = 0.025
const PROGRESS_LOSS_PER_TICK: float = 0.01
const LIFE_SECONDS: float = 30.0
const BAR_SIZE := Vector2(84.0, 8.0)
const BAR_OFFSET := Vector2(-42.0, -70.0)

var progress: float = 0.0
var _tick_accumulator: float = 0.0
var _life_time: float = 0.0
var _player_inside: bool = false
var _closing: bool = false

@onready var area: Area2D = $Area2D

func _ready() -> void:
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)
	if animate and not animate.is_playing():
		animate.play()

func _process(delta: float) -> void:
	if _closing:
		return
	_life_time += delta
	if _life_time >= LIFE_SECONDS:
		_expire()
		return
	_tick_accumulator += delta
	while _tick_accumulator >= TICK_SECONDS:
		_tick_accumulator -= TICK_SECONDS
		_update_progress_tick()

func _draw() -> void:
	var outer_rect := Rect2(BAR_OFFSET, BAR_SIZE)
	var inner_rect := Rect2(BAR_OFFSET + Vector2(2.0, 2.0), BAR_SIZE - Vector2(4.0, 4.0))
	var fill_width = floor(inner_rect.size.x * progress)
	draw_rect(outer_rect, Color(0.05, 0.08, 0.12, 0.85), true)
	draw_rect(inner_rect, Color(0.18, 0.24, 0.28, 0.85), true)
	if fill_width > 0.0:
		draw_rect(Rect2(inner_rect.position, Vector2(fill_width, inner_rect.size.y)), Color(0.35, 0.95, 1.0, 0.95), true)
	draw_rect(outer_rect, Color(0.72, 1.0, 1.0, 0.95), false, 1.0)

func _update_progress_tick() -> void:
	var old_progress := progress
	if _player_inside:
		progress = min(1.0, progress + PROGRESS_GAIN_PER_TICK)
	else:
		progress = max(0.0, progress - PROGRESS_LOSS_PER_TICK)
	if not is_equal_approx(old_progress, progress):
		queue_redraw()
	if progress >= 1.0:
		_complete()

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
