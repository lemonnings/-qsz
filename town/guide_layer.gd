extends CanvasLayer

signal exit_requested

const ITEMS_PER_PAGE := 16
const GRID_SIZE := Vector2(88, 88)
const UI_FONT_PATH := "res://AssetBundle/Uranus_Pixel_11Px.ttf"
const CATEGORY_FRIEND := "friend"
const CATEGORY_ENEMY := "yao"
const CATEGORY_ITEM := "wu"
const CATEGORY_BATTLE := "battle"
const COMPLETION_CONTENT_WIDTH := 900.0
const COMPLETION_BAR_HEIGHT := 24.0
const DETAIL_LABEL_COLOR := "#FFD84A"
const PAGE_BUTTON_FADE_DURATION := 0.12
const VIEW_FADE_DURATION := 0.16
const ENEMY_ICON_BASE_SIZE := Vector2(82, 82)
const ENEMY_ICON_FRAME_SIZE := Vector2(88, 88)
const STAGE_NAMES := {
	"peach_grove": "桃林",
	"ruin": "古迹",
	"cave": "深窟",
	"forest": "密林",
	"difu": "九幽冥府",
}
const ENEMY_GRID_ICON_SCALE := {
	"slime_blue": 1.30,
	"peach_yao": 0.85,
	"frog": 0.85,
	"copper": 1.40,
	"lantern": 0.70,
	"paper": 0.70,
	"bat": 0.85,
	"stone_man": 0.85,
	"shen": 1.30,
	"frog_new": 0.85,
}
const ENEMY_GRID_ICON_FLIP_H := {
	"slime_blue": true,
	"peach_yao": true,
	"bat": true,
	"slime_grey": true,
	"ghost": true,
	"stone_man": true,
	"slime": true,
	"shen": true,
}
const ENEMY_DETAIL_DISPLAY_SCALE := {
	"lantern": 1.50,
	"paper": 1.50,
	"slime": 0.70,
	"youling": 0.70,
}

class PixelArrowProgressBar:
	extends Control

	const CELL_SIZE := 3.0
	const CORNER_RADIUS := 8.0
	const ARROW_WIDTH_CELLS := 9
	const COLOR_STOPS := [
		Color(1.0, 0.96, 0.22, 1.0),
		Color(0.98, 0.82, 0.12, 1.0),
		Color(0.89, 0.62, 0.04, 1.0),
		Color(0.72, 0.42, 0.0, 1.0),
	]

	var progress_ratio := 0.0

	func set_progress_ratio(value: float) -> void:
		progress_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var filled_width := size.x * progress_ratio
		if filled_width <= 0.0:
			return
		var columns := int(ceil(filled_width / CELL_SIZE))
		var rows := int(floor(size.y / CELL_SIZE))
		for x in range(columns):
			var cell_x := float(x) * CELL_SIZE
			if cell_x >= filled_width:
				continue
			var draw_width := minf(CELL_SIZE, filled_width - cell_x)
			var base_color := _get_gradient_color(cell_x / maxf(size.x, 1.0))
			for y in range(rows):
				var rect := Rect2(cell_x, float(y) * CELL_SIZE, draw_width, CELL_SIZE)
				if not _is_rect_inside_rounded_bar(rect):
					continue
				draw_rect(rect, _get_arrow_cell_color(base_color, x, y, rows))

	func _is_rect_inside_rounded_bar(rect: Rect2) -> bool:
		var center_point := rect.get_center()
		var radius := minf(CORNER_RADIUS, minf(size.x, size.y) * 0.5)
		if center_point.x >= radius and center_point.x <= size.x - radius:
			return true
		if center_point.y >= radius and center_point.y <= size.y - radius:
			return true
		var corner_center := Vector2(radius if center_point.x < radius else size.x - radius, radius if center_point.y < radius else size.y - radius)
		return center_point.distance_to(corner_center) <= radius

	func _get_gradient_color(ratio: float) -> Color:
		var clamped_ratio := clampf(ratio, 0.0, 1.0)
		var scaled := clamped_ratio * float(COLOR_STOPS.size() - 1)
		var index := int(floor(scaled))
		if index >= COLOR_STOPS.size() - 1:
			return COLOR_STOPS[COLOR_STOPS.size() - 1]
		return COLOR_STOPS[index].lerp(COLOR_STOPS[index + 1], scaled - float(index))

	func _get_arrow_cell_color(base_color: Color, column: int, row: int, rows: int) -> Color:
		var center := int(rows / 2)
		var distance := absi(row - center)
		var phase := (column + distance) % ARROW_WIDTH_CELLS
		var highlight := 0.0
		if phase <= 1:
			highlight = 0.18
		elif phase <= 3:
			highlight = 0.08
		elif phase >= ARROW_WIDTH_CELLS - 2:
			highlight = -0.10
		return base_color.lightened(highlight) if highlight >= 0.0 else base_color.darkened(absf(highlight))

@onready var panel: Panel = $Panel
@onready var menu: Control = $Panel/menu
@onready var detail_view: Control = $Panel/detail
@onready var active_detail: FlowContainer = $Panel/detail/active_detail
@onready var item_template: Panel = $Panel/detail/active_detail/item
@onready var next_button: Button = $Panel/detail/next
@onready var prev_button: Button = $Panel/detail/prev
@onready var page_label: RichTextLabel = $Panel/detail/page
@onready var detail_label: RichTextLabel = $Panel/detail/detail
@onready var display_sprite: Sprite2D = $Panel/detail/Sprite2D
@onready var exit_button: Button = $Panel/Exit
@onready var completion: Control = $Panel/menu/completion
@onready var friend_button: Button = $Panel/menu/friend
@onready var yao_button: Button = $Panel/menu/yao
@onready var wu_button: Button = $Panel/menu/wu
@onready var battle_button: Button = $Panel/menu/battle

var _current_category := CATEGORY_FRIEND
var _current_page := 0
var _current_entries: Array[Dictionary] = []
var _grid_panels: Array[Panel] = []
var _ui_font: Font
var _progress_text: RichTextLabel
var _progress_bar: PixelArrowProgressBar
var _reward_text: RichTextLabel
var _friend_display: AnimatedSprite2D
var _display_base_scale := Vector2.ONE
var _button_tweens: Dictionary = {}
var _view_transition_tween: Tween
var _enemy_thumbnail_cache: Dictionary = {}
var _pending_enemy_thumbnail_jobs: Array[Dictionary] = []
var _thumbnail_loader_running := false
var _thumbnail_load_generation := 0
var _selected_enemy_scene_path := ""
var _selected_enemy_collected := false
var _selected_enemy_detail_scale := 1.0
var _detail_drag_active := false
var _detail_last_drag_position := Vector2.ZERO
var _guide_manager: Node

func _ready() -> void:
	add_to_group("guide_layer")
	visible = false
	_load_ui_font()
	menu.visible = true
	menu.modulate.a = 1.0
	detail_view.visible = false
	detail_view.modulate.a = 1.0
	item_template.visible = false
	_setup_completion_nodes()
	_connect_buttons()
	_setup_detail_style()
	_setup_display_nodes()
	_set_menu_input_enabled(true)
	_set_detail_input_enabled(false)
	refresh()

func open_layer() -> void:
	visible = true
	menu.visible = true
	menu.modulate.a = 1.0
	detail_view.visible = false
	detail_view.modulate.a = 1.0
	_hide_detail_display()
	_current_page = 0
	_set_menu_input_enabled(true)
	_set_detail_input_enabled(false)
	refresh()

func close_layer(emit_request: bool = true) -> void:
	if _view_transition_tween and _view_transition_tween.is_valid():
		_view_transition_tween.kill()
	_set_menu_input_enabled(true)
	_set_detail_input_enabled(false)
	visible = false
	if emit_request:
		exit_requested.emit()

func _get_guide_manager() -> Node:
	if _guide_manager != null and is_instance_valid(_guide_manager):
		return _guide_manager
	_guide_manager = get_node_or_null("/root/GuideManager")
	return _guide_manager

func _get_category_progress(category: String) -> Dictionary:
	var guide_manager := _get_guide_manager()
	if guide_manager == null or not guide_manager.has_method("get_category_progress"):
		return {"collected": 0, "total": 0}
	var progress = guide_manager.call("get_category_progress", category)
	if typeof(progress) == TYPE_DICTIONARY:
		return progress as Dictionary
	return {"collected": 0, "total": 0}

func _is_collected(entry_id: String) -> bool:
	var guide_manager := _get_guide_manager()
	if guide_manager == null or not guide_manager.has_method("is_collected"):
		return false
	return bool(guide_manager.call("is_collected", entry_id))

func _get_rarity_color(rarity: String) -> Color:
	var guide_manager := _get_guide_manager()
	if guide_manager != null and guide_manager.has_method("get_rarity_color"):
		return guide_manager.call("get_rarity_color", rarity) as Color
	return Color.WHITE

func refresh() -> void:
	var guide_manager := _get_guide_manager()
	if guide_manager == null:
		return
	guide_manager.call_deferred("sync_rule_based_friend_collection", true)
	if guide_manager.has_method("sync_current_battle_law_collection"):
		guide_manager.call_deferred("sync_current_battle_law_collection", true)
	_update_category_counts()
	_update_completion()
	if detail_view.visible:
		_open_category(_current_category, false)

func _connect_buttons() -> void:
	if not friend_button.pressed.is_connected(_on_category_pressed.bind(CATEGORY_FRIEND)):
		friend_button.pressed.connect(_on_category_pressed.bind(CATEGORY_FRIEND))
	if not yao_button.pressed.is_connected(_on_category_pressed.bind(CATEGORY_ENEMY)):
		yao_button.pressed.connect(_on_category_pressed.bind(CATEGORY_ENEMY))
	if not wu_button.pressed.is_connected(_on_category_pressed.bind(CATEGORY_ITEM)):
		wu_button.pressed.connect(_on_category_pressed.bind(CATEGORY_ITEM))
	if not battle_button.pressed.is_connected(_on_category_pressed.bind(CATEGORY_BATTLE)):
		battle_button.pressed.connect(_on_category_pressed.bind(CATEGORY_BATTLE))
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if not prev_button.pressed.is_connected(_on_prev_pressed):
		prev_button.pressed.connect(_on_prev_pressed)
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	var guide_manager := _get_guide_manager()
	var refresh_callable := Callable(self , "refresh")
	if guide_manager != null and guide_manager.has_signal("collection_changed") and not guide_manager.is_connected("collection_changed", refresh_callable):
		guide_manager.connect("collection_changed", refresh_callable)
	if not detail_label.gui_input.is_connected(_on_detail_label_gui_input):
		detail_label.gui_input.connect(_on_detail_label_gui_input)

func _setup_completion_nodes() -> void:
	completion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in completion.get_children():
		child.queue_free()
	_progress_text = RichTextLabel.new()
	_progress_text.name = "ExplorationProgress"
	_progress_text.position = Vector2(12, 6)
	_progress_text.size = Vector2(COMPLETION_CONTENT_WIDTH, 40)
	_setup_rich_text_style(_progress_text, Color.WHITE, 31)
	_progress_text.add_theme_constant_override("outline_size", 6)
	completion.add_child(_progress_text)

	var bar_bg := Panel.new()
	bar_bg.name = "ExplorationBarBg"
	bar_bg.position = Vector2(12, 56)
	bar_bg.size = Vector2(COMPLETION_CONTENT_WIDTH, COMPLETION_BAR_HEIGHT)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.16, 0.12, 0.02, 0.85)
	bar_style.border_color = Color(0.95, 0.73, 0.12, 0.9)
	bar_style.set_border_width_all(2)
	bar_style.corner_radius_top_left = 9
	bar_style.corner_radius_top_right = 9
	bar_style.corner_radius_bottom_left = 9
	bar_style.corner_radius_bottom_right = 9
	bar_bg.add_theme_stylebox_override("panel", bar_style)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion.add_child(bar_bg)

	_progress_bar = PixelArrowProgressBar.new()
	_progress_bar.name = "ExplorationBarFill"
	_progress_bar.position = bar_bg.position + Vector2(2, 2)
	_progress_bar.size = bar_bg.size - Vector2(4, 4)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion.add_child(_progress_bar)

	_reward_text = RichTextLabel.new()
	_reward_text.name = "ExplorationReward"
	_reward_text.position = Vector2(12, 94)
	_reward_text.size = Vector2(COMPLETION_CONTENT_WIDTH, 54)
	_reward_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_setup_rich_text_style(_reward_text, Color.WHITE, 25)
	_reward_text.add_theme_constant_override("outline_size", 6)
	completion.add_child(_reward_text)

func _update_category_counts() -> void:
	_set_button_count(friend_button, _get_category_progress(CATEGORY_FRIEND))
	_set_button_count(yao_button, _get_category_progress(CATEGORY_ENEMY))
	_set_button_count(wu_button, _get_category_progress(CATEGORY_ITEM))
	_set_button_count(battle_button, _get_category_progress(CATEGORY_BATTLE))

func _set_button_count(button: Button, progress: Dictionary) -> void:
	var label := button.get_node_or_null(button.name + "_detail") as RichTextLabel
	if label == null:
		return
	label.text = "%d / %d" % [int(progress.get("collected", 0)), int(progress.get("total", 0))]

func _update_completion() -> void:
	var guide_manager := _get_guide_manager()
	if guide_manager == null:
		return
	var current := int(guide_manager.call("get_collected_exploration_points"))
	var total := int(guide_manager.call("get_total_exploration_points"))
	var percent := 0.0
	if total > 0:
		percent = float(current) / float(total) * 100.0
	_progress_text.text = "探索点进度：%d / %d （%.2f%%）" % [current, total, percent]
	var bar_ratio := clampf(percent / 100.0, 0.0, 1.0)
	if _progress_bar != null:
		_progress_bar.set_progress_ratio(bar_ratio)
	_reward_text.text = "探索点加成：" + _get_bonus_text_line(guide_manager)

func _get_bonus_text_line(guide_manager: Node) -> String:
	if guide_manager.has_method("get_bonus_summary"):
		var summary_value: Variant = guide_manager.call("get_bonus_summary")
		if typeof(summary_value) == TYPE_DICTIONARY:
			var summary := summary_value as Dictionary
			return "攻击 + %d   最大体力 + %d   真气获取率 + %.1f%%   掉落率 + %.2f%%" % [
				int(round(float(summary.get("atk", 0.0)))),
				int(round(float(summary.get("hp", 0.0)))),
				float(summary.get("point", 0.0)) * 100.0,
				float(summary.get("drop", 0.0)) * 100.0,
			]
	if guide_manager.has_method("get_bonus_text"):
		var fallback_text := str(guide_manager.call("get_bonus_text"))
		return fallback_text.replace("\n", "   ")
	return "攻击 + 0   最大体力 + 0   真气获取率 + 0.0%   掉落率 + 0.00%"

func _on_category_pressed(category: String) -> void:
	_open_category(category, true)

func _open_category(category: String, reset_page: bool) -> void:
	_current_category = category
	if reset_page:
		_current_page = 0
	var animate_view_transition := reset_page and menu.visible and not detail_view.visible
	_set_menu_input_enabled(false)
	var guide_manager := _get_guide_manager()
	if guide_manager == null:
		_current_entries = []
	else:
		_current_entries = []
		var definitions = guide_manager.call("get_definitions", category)
		if typeof(definitions) == TYPE_ARRAY:
			for definition in definitions:
				if typeof(definition) == TYPE_DICTIONARY:
					_current_entries.append(definition as Dictionary)
	detail_view.visible = true
	if animate_view_transition:
		_render_page(false)
		_set_detail_input_enabled(true)
		_fade_between_views(menu, detail_view)
	else:
		menu.visible = false
		menu.modulate.a = 1.0
		detail_view.modulate.a = 1.0
		_render_page(false)
		_set_detail_input_enabled(true)

func _render_page(animate_page_buttons: bool = false) -> void:
	_thumbnail_load_generation += 1
	for panel_node in _grid_panels:
		if is_instance_valid(panel_node):
			panel_node.queue_free()
	_grid_panels.clear()
	var total_pages := _get_total_pages()
	_current_page = clampi(_current_page, 0, max(total_pages - 1, 0))
	var start := _current_page * ITEMS_PER_PAGE
	var end := mini(start + ITEMS_PER_PAGE, _current_entries.size())
	for i in range(start, end):
		var entry := _current_entries[i]
		var panel_node := item_template.duplicate() as Panel
		panel_node.visible = true
		panel_node.custom_minimum_size = GRID_SIZE
		panel_node.size = GRID_SIZE
		panel_node.mouse_filter = Control.MOUSE_FILTER_STOP
		active_detail.add_child(panel_node)
		_configure_grid_item(panel_node, entry)
		_grid_panels.append(panel_node)
	page_label.text = "%d / %d" % [_current_page + 1, total_pages]
	_update_page_buttons(total_pages, animate_page_buttons)
	if end > start:
		_select_entry(_current_entries[start])
	else:
		detail_label.text = ""
		_hide_detail_display()

func _configure_grid_item(panel_node: Panel, entry: Dictionary) -> void:
	panel_node.set_meta("guide_entry_id", str(entry.get("id", "")))
	var icon := panel_node.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel_node.add_child(icon)
	if _is_regular_enemy_entry(entry):
		var icon_scale := _get_enemy_grid_icon_scale(entry)
		icon.size = ENEMY_ICON_BASE_SIZE * icon_scale
		var should_flip := _should_flip_enemy_grid_icon(entry)
		icon.scale = Vector2(-1, 1) if should_flip else Vector2.ONE
		icon.position = Vector2((ENEMY_ICON_FRAME_SIZE.x + icon.size.x) * 0.5, (ENEMY_ICON_FRAME_SIZE.y - icon.size.y) * 0.5) if should_flip else (ENEMY_ICON_FRAME_SIZE - icon.size) * 0.5
		icon.texture = _get_enemy_thumbnail_texture(entry)
		_queue_enemy_thumbnail_load(icon, entry, _thumbnail_load_generation)
	else:
		icon.scale = Vector2.ONE
		icon.position = Vector2(10, 10)
		icon.size = Vector2(68, 68)
		icon.texture = _load_texture(str(entry.get("icon", "")))
	var collected := _is_collected(str(entry.get("id", "")))
	icon.modulate = Color(1, 1, 1, 1) if collected else Color(0.0, 0.0, 0.0, 0.58)
	var mask := panel_node.get_node_or_null("LockedMask") as ColorRect
	if mask == null:
		mask = ColorRect.new()
		mask.name = "LockedMask"
		mask.position = Vector2.ZERO
		mask.size = GRID_SIZE
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel_node.add_child(mask)
	mask.color = Color(0, 0, 0, 0.28)
	mask.visible = not collected
	_apply_rarity_outline(panel_node, str(entry.get("rarity", "white")))
	panel_node.gui_input.connect(_on_grid_item_gui_input.bind(entry))

func _on_grid_item_gui_input(event: InputEvent, entry: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_select_entry(entry)

func _select_entry(entry: Dictionary) -> void:
	var collected := _is_collected(str(entry.get("id", "")))
	_update_detail_display(entry, collected)
	if not collected:
		detail_label.text = "尚未收集\n\n提示：获得或见过该条目后解锁详细信息。"
		return
	detail_label.text = _build_detail_text(entry)

func _build_detail_text(entry: Dictionary) -> String:
	match str(entry.get("detail_type", "")):
		"friend":
			return "%s：%s\n\n%s：%s\n\n%s：待补充" % [
				_detail_label("姓名"),
				_escape_bbcode(str(entry.get("name", ""))),
				_detail_label("年龄"),
				_escape_bbcode(str(entry.get("age", "待补充"))),
				_detail_label("介绍"),
			]
		"enemy":
			var stages: Array = entry.get("stages", []) as Array
			var stage_names: Array[String] = []
			for stage_id in stages:
				stage_names.append(str(STAGE_NAMES.get(str(stage_id), str(stage_id))))
			var drops: Array = entry.get("drops", []) as Array
			var skills: Array = entry.get("skills", []) as Array
			return "%s：%s\n\n%s：%s\n\n%s：%s\n\n%s：%s" % [
				_detail_label("怪物名称"),
				_escape_bbcode(str(entry.get("name", ""))),
				_detail_label("出没区域"),
				_escape_bbcode("、".join(stage_names) if not stage_names.is_empty() else "待补充"),
				_detail_label("掉落物"),
				_escape_bbcode("、".join(drops) if not drops.is_empty() else "无"),
				_detail_label("技能"),
				_format_enemy_skills(skills),
			]
		"item":
			return "%s：%s\n\n%s：%s" % [
				_detail_label("物品名称"),
				_escape_bbcode(str(entry.get("name", ""))),
				_detail_label("介绍"),
				_escape_bbcode(str(entry.get("detail", ""))),
			]
		"law":
			return "%s：%s\n\n%s：%s" % [
				_detail_label("法则"),
				_escape_bbcode(str(entry.get("name", ""))),
				_detail_label("法则详情"),
				_escape_bbcode(str(entry.get("detail", ""))),
			]
		"weapon":
			return "%s：%s\n%s" % [
				_detail_label("武器名"),
				_escape_bbcode(str(entry.get("name", ""))),
				_escape_bbcode(str(entry.get("detail", ""))),
			]
		"reward":
			return "%s：%s\n\n%s：%s" % [
				_detail_label("领悟名称"),
				_escape_bbcode(str(entry.get("name", ""))),
				_detail_label("领悟效果"),
				_escape_bbcode(str(entry.get("detail", ""))),
			]
	return _escape_bbcode(str(entry.get("name", "")))

func _detail_label(text: String) -> String:
	return "[color=%s]%s[/color]" % [DETAIL_LABEL_COLOR, text]

func _format_enemy_skills(skills: Array) -> String:
	if skills.is_empty():
		return "待补充"
	var lines: Array[String] = []
	for skill in skills:
		lines.append(_format_enemy_skill_line(str(skill)))
	return "\n".join(lines)

func _format_enemy_skill_line(skill_text: String) -> String:
	var separator_index := skill_text.find("-")
	var skill_name := skill_text
	var skill_effect := ""
	if separator_index >= 0:
		skill_name = skill_text.substr(0, separator_index)
		skill_effect = skill_text.substr(separator_index)
	var name_color := "TOMATO" if skill_name.left(2) == "核心" else "SANDY_BROWN"
	return "[color=%s]%s[/color]%s" % [
		name_color,
		_escape_bbcode(skill_name),
		_escape_bbcode(skill_effect),
	]

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

func _on_next_pressed() -> void:
	if _current_page >= _get_total_pages() - 1:
		return
	_current_page += 1
	_render_page(true)

func _on_prev_pressed() -> void:
	if _current_page <= 0:
		return
	_current_page -= 1
	_render_page(true)

func _get_total_pages() -> int:
	return maxi(1, int(ceil(float(_current_entries.size()) / float(ITEMS_PER_PAGE))))

func _update_page_buttons(total_pages: int, animate: bool) -> void:
	_set_page_button_visible(prev_button, _current_page > 0, animate)
	_set_page_button_visible(next_button, _current_page < total_pages - 1, animate)

func _set_page_button_visible(button: Button, should_show: bool, animate: bool) -> void:
	button.disabled = not should_show
	button.mouse_filter = Control.MOUSE_FILTER_STOP if should_show else Control.MOUSE_FILTER_IGNORE
	var existing_tween: Tween = _button_tweens.get(button, null)
	if existing_tween and existing_tween.is_valid():
		existing_tween.kill()
	var was_visible := button.visible and button.modulate.a > 0.01
	if should_show:
		button.visible = true
		if animate and not was_visible:
			button.modulate.a = 0.0
			var tween := create_tween()
			_button_tweens[button] = tween
			tween.tween_property(button, "modulate:a", 1.0, PAGE_BUTTON_FADE_DURATION)
		else:
			button.modulate.a = 1.0
		return
	if animate and was_visible:
		var tween := create_tween()
		_button_tweens[button] = tween
		tween.tween_property(button, "modulate:a", 0.0, PAGE_BUTTON_FADE_DURATION)
		tween.finished.connect(func() -> void:
			button.visible = false
		)
	else:
		button.modulate.a = 0.0
		button.visible = false

func _fade_between_views(from_view: Control, to_view: Control, after_finish: Callable = Callable()) -> void:
	if _view_transition_tween and _view_transition_tween.is_valid():
		_view_transition_tween.kill()
	from_view.visible = true
	to_view.visible = true
	from_view.modulate.a = 1.0
	to_view.modulate.a = 0.0
	_view_transition_tween = create_tween()
	_view_transition_tween.set_parallel(true)
	_view_transition_tween.tween_property(from_view, "modulate:a", 0.0, VIEW_FADE_DURATION)
	_view_transition_tween.tween_property(to_view, "modulate:a", 1.0, VIEW_FADE_DURATION)
	_view_transition_tween.finished.connect(func() -> void:
		from_view.visible = false
		from_view.modulate.a = 1.0
		to_view.modulate.a = 1.0
		if after_finish.is_valid():
			after_finish.call()
	)

func _set_menu_input_enabled(enabled: bool) -> void:
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button in [friend_button, yao_button, wu_button, battle_button]:
		if button == null:
			continue
		button.disabled = not enabled
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _set_detail_input_enabled(enabled: bool) -> void:
	detail_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for panel_node in _grid_panels:
		if is_instance_valid(panel_node):
			panel_node.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if enabled:
		_update_page_buttons(_get_total_pages(), false)
	else:
		_detail_drag_active = false
		for button in [prev_button, next_button]:
			button.disabled = true
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_rarity_outline(panel_node: Panel, rarity: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.04, 0.72)
	style.border_color = _get_rarity_color(rarity)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel_node.add_theme_stylebox_override("panel", style)

func _load_texture(path: String) -> Texture2D:
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path)
	return null

func _is_regular_enemy_entry(entry: Dictionary) -> bool:
	return str(entry.get("detail_type", "")) == "enemy" and str(entry.get("rarity", "")) != "red"

func _get_enemy_grid_icon_scale(entry: Dictionary) -> float:
	return float(ENEMY_GRID_ICON_SCALE.get(str(entry.get("monster_id", "")), 1.0))

func _should_flip_enemy_grid_icon(entry: Dictionary) -> bool:
	return bool(ENEMY_GRID_ICON_FLIP_H.get(str(entry.get("monster_id", "")), false))

func _get_enemy_detail_display_scale(entry_or_monster_id: Variant) -> float:
	var monster_id := str(entry_or_monster_id)
	if typeof(entry_or_monster_id) == TYPE_DICTIONARY:
		monster_id = str((entry_or_monster_id as Dictionary).get("monster_id", ""))
	return float(ENEMY_DETAIL_DISPLAY_SCALE.get(monster_id, 1.0))

func _get_enemy_thumbnail_texture(entry: Dictionary) -> Texture2D:
	var scene_path := str(entry.get("scene_path", ""))
	if scene_path.is_empty():
		return _load_texture(str(entry.get("icon", "")))
	if _enemy_thumbnail_cache.has(scene_path):
		return _enemy_thumbnail_cache[scene_path] as Texture2D
	return _load_texture(str(entry.get("icon", "")))

func _queue_enemy_thumbnail_load(icon: TextureRect, entry: Dictionary, generation: int) -> void:
	var scene_path := str(entry.get("scene_path", ""))
	if scene_path.is_empty() or _enemy_thumbnail_cache.has(scene_path):
		return
	_pending_enemy_thumbnail_jobs.append({
		"icon": icon,
		"scene_path": scene_path,
		"fallback_icon": str(entry.get("icon", "")),
		"generation": generation,
	})
	if not _thumbnail_loader_running:
		_thumbnail_loader_running = true
		call_deferred("_process_enemy_thumbnail_queue")

func _process_enemy_thumbnail_queue() -> void:
	while not _pending_enemy_thumbnail_jobs.is_empty():
		await get_tree().process_frame
		var job: Dictionary = _pending_enemy_thumbnail_jobs.pop_front()
		var scene_path := str(job.get("scene_path", ""))
		var job_generation := int(job.get("generation", -1))
		if job_generation != _thumbnail_load_generation:
			continue
		var texture: Texture2D = null
		if _enemy_thumbnail_cache.has(scene_path):
			texture = _enemy_thumbnail_cache[scene_path] as Texture2D
		else:
			texture = _load_enemy_frame_texture(scene_path)
			if texture == null:
				texture = _load_texture(str(job.get("fallback_icon", "")))
			_enemy_thumbnail_cache[scene_path] = texture
		var icon := job.get("icon") as TextureRect
		if is_instance_valid(icon):
			icon.texture = texture
		if scene_path == _selected_enemy_scene_path and detail_view.visible:
			_show_enemy_frame_texture(texture, _selected_enemy_collected, _selected_enemy_detail_scale)
	_thumbnail_loader_running = false

func _load_enemy_frame_texture(scene_path: String) -> Texture2D:
	var scene := _load_packed_scene(scene_path)
	if scene == null:
		return null
	var scene_instance := scene.instantiate()
	var source_sprite := _find_first_animated_sprite(scene_instance)
	if source_sprite == null or source_sprite.sprite_frames == null:
		scene_instance.queue_free()
		return null
	var animation_name := _get_first_available_animation(source_sprite.sprite_frames, ["run", "idle", "default"])
	if animation_name.is_empty():
		scene_instance.queue_free()
		return null
	var texture := source_sprite.sprite_frames.get_frame_texture(animation_name, 0)
	scene_instance.queue_free()
	return texture

func _setup_display_nodes() -> void:
	_display_base_scale = display_sprite.scale
	_friend_display = AnimatedSprite2D.new()
	_friend_display.name = "FriendDisplay"
	_friend_display.position = display_sprite.position
	_friend_display.scale = _display_base_scale
	_friend_display.visible = false
	detail_view.add_child(_friend_display)

func _update_detail_display(entry: Dictionary, collected: bool) -> void:
	_selected_enemy_scene_path = ""
	_selected_enemy_collected = false
	if str(entry.get("detail_type", "")) == "friend":
		_show_friend_display(entry, collected)
		return
	if str(entry.get("detail_type", "")) == "enemy":
		_show_enemy_display(entry, collected)
		return
	_friend_display.visible = false
	display_sprite.visible = true
	display_sprite.scale = _display_base_scale
	display_sprite.texture = _load_texture(str(entry.get("icon", "")))
	display_sprite.modulate = Color(1, 1, 1, 1) if collected else Color(0, 0, 0, 0.55)

func _show_friend_display(entry: Dictionary, collected: bool) -> void:
	display_sprite.visible = false
	display_sprite.texture = null
	var texture := _load_texture(str(entry.get("display_texture", "")))
	if texture == null:
		display_sprite.visible = true
		display_sprite.scale = _display_base_scale
		display_sprite.texture = _load_texture(str(entry.get("icon", "")))
		display_sprite.modulate = Color(1, 1, 1, 1) if collected else Color(0, 0, 0, 0.55)
		_friend_display.visible = false
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 128, 128)
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", atlas)
	frames.set_animation_speed("idle", 1.0)
	_friend_display.sprite_frames = frames
	_friend_display.animation = "idle"
	_friend_display.frame = 0
	_friend_display.scale = _display_base_scale
	_friend_display.modulate = Color(1, 1, 1, 1) if collected else Color(0, 0, 0, 0.55)
	_friend_display.visible = true
	_friend_display.play("idle")

func _show_enemy_display(entry: Dictionary, collected: bool) -> void:
	_selected_enemy_scene_path = str(entry.get("scene_path", ""))
	_selected_enemy_collected = collected
	_selected_enemy_detail_scale = _get_enemy_detail_display_scale(entry)
	var cached_texture := _get_enemy_thumbnail_texture(entry)
	if cached_texture != null and _selected_enemy_scene_path != "" and _enemy_thumbnail_cache.has(_selected_enemy_scene_path):
		_show_enemy_frame_texture(cached_texture, collected, _selected_enemy_detail_scale)
		return
	_show_icon_fallback(entry, collected)
	_queue_enemy_thumbnail_load(null, entry, _thumbnail_load_generation)

func _show_enemy_frame_texture(frame_texture: Texture2D, collected: bool, detail_scale: float = 1.0) -> void:
	if frame_texture == null:
		return
	display_sprite.visible = false
	display_sprite.texture = null
	var frames := SpriteFrames.new()
	frames.add_animation("run")
	frames.add_frame("run", frame_texture)
	frames.set_animation_speed("run", 1.0)
	frames.set_animation_loop("run", false)
	_friend_display.sprite_frames = frames
	_friend_display.animation = "run"
	_friend_display.frame = 0
	_friend_display.scale = _display_base_scale * detail_scale
	_friend_display.modulate = Color(1, 1, 1, 1) if collected else Color(0, 0, 0, 0.55)
	_friend_display.visible = true
	_friend_display.stop()

func _show_icon_fallback(entry: Dictionary, collected: bool) -> void:
	_friend_display.visible = false
	display_sprite.visible = true
	display_sprite.scale = _display_base_scale * _get_enemy_detail_display_scale(entry)
	display_sprite.texture = _load_texture(str(entry.get("icon", "")))
	display_sprite.modulate = Color(1, 1, 1, 1) if collected else Color(0, 0, 0, 0.55)

func _load_packed_scene(path: String) -> PackedScene:
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null

func _find_first_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.sprite_frames != null:
			return sprite
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var result := _find_first_animated_sprite(child_node)
		if result != null:
			return result
	return null

func _get_first_available_animation(frames: SpriteFrames, names: Array[String]) -> StringName:
	for animation_name in names:
		var name := StringName(animation_name)
		if frames.has_animation(name) and frames.get_frame_count(name) > 0:
			return name
	var animation_names := frames.get_animation_names()
	for animation_name in animation_names:
		if frames.get_frame_count(animation_name) > 0:
			return animation_name
	return StringName("")

func _hide_detail_display() -> void:
	_selected_enemy_scene_path = ""
	_selected_enemy_collected = false
	_selected_enemy_detail_scale = 1.0
	display_sprite.texture = null
	display_sprite.scale = _display_base_scale
	display_sprite.visible = true
	if _friend_display != null:
		_friend_display.scale = _display_base_scale
		_friend_display.visible = false

func _setup_detail_style() -> void:
	detail_label.bbcode_enabled = true
	detail_label.scroll_active = false
	detail_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if _ui_font:
		detail_label.add_theme_font_override("normal_font", _ui_font)
	detail_label.add_theme_color_override("default_color", Color.WHITE)
	detail_label.add_theme_color_override("font_outline_color", Color.BLACK)
	detail_label.add_theme_constant_override("outline_size", 5)

func _on_detail_label_gui_input(event: InputEvent) -> void:
	var scroll_bar := detail_label.get_v_scroll_bar()
	if scroll_bar == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_scroll_detail_by(-48.0)
				detail_label.accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_detail_by(48.0)
				detail_label.accept_event()
			MOUSE_BUTTON_LEFT:
				_detail_drag_active = mouse_event.pressed
				_detail_last_drag_position = mouse_event.position
				detail_label.accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		_detail_drag_active = touch_event.pressed
		_detail_last_drag_position = touch_event.position
		detail_label.accept_event()

func _input(event: InputEvent) -> void:
	if not _detail_drag_active:
		return
	if not visible or not detail_view.visible:
		_detail_drag_active = false
		return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		_scroll_detail_by(-motion_event.relative.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_scroll_detail_by(-drag_event.relative.y)
		_detail_last_drag_position = drag_event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_detail_drag_active = false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed:
			_detail_drag_active = false
			get_viewport().set_input_as_handled()

func _scroll_detail_by(delta: float) -> void:
	var scroll_bar := detail_label.get_v_scroll_bar()
	if scroll_bar == null:
		return
	scroll_bar.value = clampf(scroll_bar.value + delta, scroll_bar.min_value, scroll_bar.max_value)

func _setup_label_style(label: Label, color: Color, font_size: int) -> void:
	if _ui_font:
		label.add_theme_font_override("font", _ui_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)

func _setup_rich_text_style(label: RichTextLabel, color: Color, font_size: int) -> void:
	label.bbcode_enabled = false
	label.fit_content = false
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _ui_font:
		label.add_theme_font_override("normal_font", _ui_font)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)

func _load_ui_font() -> void:
	if ResourceLoader.exists(UI_FONT_PATH):
		_ui_font = load(UI_FONT_PATH)

func _on_exit_pressed() -> void:
	handle_exit_request()

func handle_exit_request() -> bool:
	if detail_view.visible:
		_set_detail_input_enabled(false)
		_set_menu_input_enabled(true)
		_fade_between_views(detail_view, menu, Callable(self, "_hide_detail_display"))
		return true
	exit_requested.emit()
	return true
