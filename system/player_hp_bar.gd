extends Node2D
class_name PlayerHpBar

const FADE_DURATION: float = 0.3
const HP_TWEEN_DURATION: float = 0.15

const BAR_WIDTH: float = 28.0

@onready var fill_bar: ColorRect = $Fill

var _fade_tween: Tween = null
var _hp_tween: Tween = null
var _hp_tween_target: float = -1.0
var _is_shown: bool = false

func _ready() -> void:
	modulate.a = 0.0
	visible = false
	z_index = 100
	if fill_bar:
		fill_bar.size.x = BAR_WIDTH

func set_hp(current_hp: float, max_hp: float) -> void:
	if not fill_bar:
		return
	var target_value: float = 0.0
	if max_hp <= 0.0:
		target_value = 0.0
	else:
		target_value = clampf(current_hp / max_hp * 100.0, 0.0, 100.0)
	if abs(_hp_tween_target - target_value) < 0.01:
		return
	_hp_tween_target = target_value
	var target_width: float = BAR_WIDTH * target_value / 100.0
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	if abs(target_width - fill_bar.size.x) > 0.5:
		_hp_tween = create_tween()
		_hp_tween.tween_property(fill_bar, "size:x", target_width, HP_TWEEN_DURATION)
	else:
		fill_bar.size.x = target_width

func set_bar_visible(show_bar: bool) -> void:
	if show_bar == _is_shown:
		return
	_is_shown = show_bar
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if show_bar:
		visible = true
		_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	else:
		_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
		_fade_tween.finished.connect(func():
			if not _is_shown:
				visible = false
		)
