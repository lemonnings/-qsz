extends Node

@export var achievement_detail: RichTextLabel
@export var achievement_icon: Panel

signal finished
signal display_finished

const SLIDE_IN_DURATION := 0.32
const DISPLAY_DURATION := 2.0
const SLIDE_OUT_DURATION := 0.12
const OUT_MARGIN := 24.0

var _panel: Panel
var _tween: Tween
var _auto_close: bool = true

func show_achievement(achievement_data: Dictionary, auto_close: bool = true) -> void:
	_resolve_nodes()
	_auto_close = auto_close
	_setup_detail(achievement_data)
	_setup_icon(achievement_data)
	_play_slide_in()

func update_achievement(achievement_data: Dictionary) -> void:
	_resolve_nodes()
	_auto_close = false
	_setup_detail(achievement_data)
	_setup_icon(achievement_data)
	_play_display_timer()

func close_popup() -> void:
	_resolve_nodes()
	if _panel == null:
		finished.emit()
		queue_free()
		return
	if _tween:
		_tween.kill()
	var hidden_x: float = _get_hidden_x()
	_tween = create_tween()
	_tween.tween_property(_panel, "global_position:x", hidden_x, SLIDE_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		finished.emit()
		queue_free()
	)

func _resolve_nodes() -> void:
	if _panel == null:
		_panel = get_node_or_null("Panel") as Panel
	if achievement_detail == null:
		achievement_detail = get_node_or_null("Panel/RichTextLabel") as RichTextLabel
	if achievement_icon == null:
		achievement_icon = get_node_or_null("Panel/Panel") as Panel

func _setup_detail(achievement_data: Dictionary) -> void:
	if achievement_detail == null:
		return
	achievement_detail.bbcode_enabled = false
	achievement_detail.text = "成就达成\n" + str(achievement_data.get("name", ""))

func _setup_icon(achievement_data: Dictionary) -> void:
	if achievement_icon == null:
		return
	for child: Node in achievement_icon.get_children():
		achievement_icon.remove_child(child)
		child.queue_free()
	var rarity := str(achievement_data.get("rarity", "white"))
	var rarity_color: Color = AchievementManager.RARITY_COLORS.get(rarity, Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(rarity_color.r * 0.22, rarity_color.g * 0.22, rarity_color.b * 0.22, 0.92)
	style.border_color = rarity_color
	style.set_border_width_all(3)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	achievement_icon.add_theme_stylebox_override("panel", style)

	var icon_path := AchievementManager.get_achievement_icon_path(achievement_data)
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6.0
		icon.offset_top = 6.0
		icon.offset_right = -6.0
		icon.offset_bottom = -6.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		achievement_icon.add_child(icon)

func _play_slide_in() -> void:
	_resolve_nodes()
	if _panel == null:
		_emit_display_finished()
		return
	_panel.global_position.x = _get_hidden_x()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "global_position:x", _get_target_x(), SLIDE_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(DISPLAY_DURATION)
	_tween.tween_callback(_emit_display_finished)

func _play_display_timer() -> void:
	if _panel == null:
		_emit_display_finished()
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(DISPLAY_DURATION)
	_tween.tween_callback(_emit_display_finished)

func _emit_display_finished() -> void:
	display_finished.emit()
	if _auto_close:
		close_popup()

func _get_target_x() -> float:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	return viewport_width - _panel.size.x

func _get_hidden_x() -> float:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	return viewport_width + OUT_MARGIN
