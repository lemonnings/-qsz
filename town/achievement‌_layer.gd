extends CanvasLayer

signal exit_requested

@export var exit: Button
@export var detail: RichTextLabel
@export var achievement_list: Control
@export var example_achievement_grid: Panel

const GRID_SIZE := Vector2(88, 88)
const GRID_COLUMNS := 7
const GRID_H_SEPARATION := 6
const GRID_V_SEPARATION := 6
const TOOLTIP_FONT_SIZE := 24
const TOOLTIP_DESC_WIDTH := 260.0
const UI_FONT_PATH := "res://AssetBundle/Uranus_Pixel_11Px.ttf"

var _scroll_container: ScrollContainer
var _tooltip_panel: Panel
var _tooltip_name_label: Label
var _tooltip_desc_label: Label
var _tooltip_reward_separator: HSeparator
var _tooltip_reward_label: Label
var _tooltip_vbox: VBoxContainer
var _grid_container: GridContainer
var _grid_nodes: Dictionary = {}
var _ui_font: Font
var _tooltip_request_id: int = 0
var _mobile_scroll_touch_index: int = -1
var _mobile_scroll_mouse_dragging: bool = false

func _ready() -> void:
	add_to_group("achievement_layer")
	visible = false
	_load_ui_font()
	if exit and not exit.pressed.is_connected(_on_exit_pressed):
		exit.pressed.connect(_on_exit_pressed)
	_setup_detail_style()
	_setup_scroll_container()
	_setup_tooltip()
	_build_achievement_grid()
	refresh()

func _input(event: InputEvent) -> void:
	if not visible or not Global.is_mobile_input_mode() or _scroll_container == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _mobile_scroll_touch_index == -1 and _is_mobile_scroll_point_inside(touch.position):
				_mobile_scroll_touch_index = touch.index
		elif touch.index == _mobile_scroll_touch_index:
			_mobile_scroll_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _mobile_scroll_touch_index:
			_apply_mobile_scroll_delta(drag.relative.y)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_mobile_scroll_mouse_dragging = _is_mobile_scroll_point_inside(mouse_button.position)
			else:
				_mobile_scroll_mouse_dragging = false
	elif event is InputEventMouseMotion and _mobile_scroll_mouse_dragging:
		var motion := event as InputEventMouseMotion
		_apply_mobile_scroll_delta(motion.relative.y)
		get_viewport().set_input_as_handled()

func open_layer() -> void:
	visible = true
	refresh()

func close_layer(emit_request: bool = true) -> void:
	visible = false
	_hide_tooltip()
	_mobile_scroll_touch_index = -1
	_mobile_scroll_mouse_dragging = false
	if emit_request:
		exit_requested.emit()

func refresh() -> void:
	if detail:
		detail.bbcode_enabled = true
		_setup_detail_style()
		detail.text = AchievementManager.get_detail_text()
	for achievement_id in _grid_nodes.keys():
		var panel: Panel = _grid_nodes[achievement_id]
		_update_grid_state(panel, AchievementManager.get_definition(str(achievement_id)))

func _setup_scroll_container() -> void:
	if achievement_list == null:
		return
	if achievement_list is GridContainer:
		_grid_container = achievement_list as GridContainer
		_scroll_container = achievement_list.get_parent() as ScrollContainer
		if _scroll_container:
			_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			_scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
		_configure_list_size(achievement_list.size)
		return
	var original_parent := achievement_list.get_parent() as Control
	if original_parent == null:
		return
	var original_size := achievement_list.size
	var original_position := achievement_list.position
	var original_index := achievement_list.get_index()
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "AchievementScroll"
	_scroll_container.position = original_position
	_scroll_container.size = original_size
	_scroll_container.custom_minimum_size = original_size
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	original_parent.add_child(_scroll_container)
	original_parent.move_child(_scroll_container, original_index)

	achievement_list.visible = false
	_grid_container = GridContainer.new()
	_grid_container.name = "AchievementGrid"
	_grid_container.columns = GRID_COLUMNS
	_grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_container.add_child(_grid_container)
	achievement_list = _grid_container
	_configure_list_size(original_size)

func _configure_list_size(view_size: Vector2) -> void:
	var list_width := _get_grid_width()
	achievement_list.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	achievement_list.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	if achievement_list is GridContainer:
		(achievement_list as GridContainer).columns = GRID_COLUMNS
	achievement_list.position = Vector2.ZERO
	achievement_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	achievement_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	achievement_list.size = Vector2(list_width, maxf(view_size.y, GRID_SIZE.y))
	achievement_list.custom_minimum_size = Vector2(list_width, maxf(view_size.y, GRID_SIZE.y))

func _get_grid_width() -> float:
	return GRID_COLUMNS * GRID_SIZE.x + (GRID_COLUMNS - 1) * GRID_H_SEPARATION

func _is_mobile_scroll_point_inside(point: Vector2) -> bool:
	if _scroll_container == null:
		return false
	return _scroll_container.get_global_rect().has_point(point)

func _apply_mobile_scroll_delta(relative_y: float) -> void:
	if _scroll_container == null:
		return
	_scroll_container.scroll_vertical = maxi(0, _scroll_container.scroll_vertical + roundi(-relative_y))

func _setup_tooltip() -> void:
	var panel_parent := get_node_or_null("Panel")
	if panel_parent == null:
		panel_parent = self
	_tooltip_panel = Panel.new()
	_tooltip_panel.name = "AchievementTooltip"
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 100
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	panel_parent.add_child(_tooltip_panel)

	_tooltip_vbox = VBoxContainer.new()
	_tooltip_vbox.name = "VBox"
	_tooltip_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip_vbox.position = Vector2(10, 8)
	_tooltip_panel.add_child(_tooltip_vbox)

	_tooltip_name_label = Label.new()
	_tooltip_name_label.name = "NameLabel"
	_setup_label_style(_tooltip_name_label)
	_tooltip_vbox.add_child(_tooltip_name_label)

	_tooltip_desc_label = Label.new()
	_tooltip_desc_label.name = "DescLabel"
	_tooltip_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_setup_label_style(_tooltip_desc_label)
	_tooltip_vbox.add_child(_tooltip_desc_label)

	_tooltip_reward_separator = HSeparator.new()
	_tooltip_reward_separator.name = "RewardSeparator"
	_tooltip_vbox.add_child(_tooltip_reward_separator)

	_tooltip_reward_label = Label.new()
	_tooltip_reward_label.name = "RewardLabel"
	_tooltip_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_reward_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_setup_label_style(_tooltip_reward_label, Color(1.0, 0.85, 0.0, 1.0))
	_tooltip_vbox.add_child(_tooltip_reward_label)

func _build_achievement_grid() -> void:
	if achievement_list == null or example_achievement_grid == null:
		return
	for child in achievement_list.get_children():
		if child != example_achievement_grid:
			child.queue_free()
	example_achievement_grid.visible = false
	_grid_nodes.clear()
	for definition in AchievementManager.get_achievement_definitions():
		var panel := example_achievement_grid.duplicate()
		panel.visible = true
		panel.custom_minimum_size = GRID_SIZE
		panel.size = GRID_SIZE
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		achievement_list.add_child(panel)
		_configure_grid(panel, definition)
		_grid_nodes[definition["id"]] = panel
	var row_count := ceili(float(_grid_nodes.size()) / float(GRID_COLUMNS))
	var list_height := row_count * GRID_SIZE.y + maxi(row_count - 1, 0) * GRID_V_SEPARATION
	if _scroll_container:
		list_height = maxf(list_height, _scroll_container.size.y)
	achievement_list.custom_minimum_size = Vector2(_get_grid_width(), list_height)
	achievement_list.size = achievement_list.custom_minimum_size

func _configure_grid(panel: Panel, definition: Dictionary) -> void:
	panel.set_meta("achievement_id", definition["id"])
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.position = Vector2(15, 15)
	icon_rect.size = Vector2(58, 58)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_rect)
	var mask := ColorRect.new()
	mask.name = "LockedMask"
	mask.color = Color(0.0, 0.0, 0.0, 0.55)
	mask.position = Vector2.ZERO
	mask.size = GRID_SIZE
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(mask)
	panel.gui_input.connect(_on_grid_gui_input.bind(panel))
	panel.mouse_entered.connect(_show_tooltip.bind(panel))
	panel.mouse_exited.connect(_hide_tooltip)
	_update_grid_state(panel, definition)

func _update_grid_state(panel: Panel, definition: Dictionary) -> void:
	var unlocked := AchievementManager.is_unlocked(str(definition.get("id", "")))
	var icon_rect := panel.get_node_or_null("Icon") as TextureRect
	if icon_rect:
		var icon_path := AchievementManager.get_achievement_icon_path(definition)
		icon_rect.texture = load(icon_path) if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else null
		icon_rect.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.55, 0.55, 0.55, 0.75)
	var mask := panel.get_node_or_null("LockedMask")
	if mask:
		mask.visible = not unlocked

func _on_grid_gui_input(event: InputEvent, panel: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_show_tooltip(panel)

func _show_tooltip(panel: Panel) -> void:
	if _tooltip_panel == null or _tooltip_name_label == null:
		return
	_tooltip_request_id += 1
	var request_id := _tooltip_request_id
	var achievement_id := str(panel.get_meta("achievement_id", ""))
	var definition := AchievementManager.get_definition(achievement_id)
	if definition.is_empty():
		return
	var rarity := str(definition.get("rarity", "white"))
	var extra_text := AchievementManager.get_unlock_text(achievement_id)
	var rarity_color: Color = AchievementManager.RARITY_COLORS.get(rarity, Color.WHITE)
	_tooltip_name_label.text = str(definition.get("name", ""))
	_tooltip_name_label.add_theme_color_override("font_color", rarity_color)
	_tooltip_desc_label.text = str(definition.get("condition_text", ""))
	var has_extra_reward := not extra_text.is_empty()
	_tooltip_reward_separator.visible = has_extra_reward
	_tooltip_reward_label.visible = has_extra_reward
	_tooltip_reward_label.text = "奖励：\n" + extra_text if has_extra_reward else ""
	_reset_tooltip_layout()
	await _finalize_tooltip_layout()
	if request_id != _tooltip_request_id:
		return
	if not is_instance_valid(panel):
		return
	var target_pos := panel.global_position + Vector2(panel.size.x + 10, 0)
	var viewport_size := get_viewport().get_visible_rect().size
	if target_pos.x + _tooltip_panel.size.x > viewport_size.x:
		target_pos.x = panel.global_position.x - _tooltip_panel.size.x - 10
	if target_pos.y + _tooltip_panel.size.y > viewport_size.y:
		target_pos.y = viewport_size.y - _tooltip_panel.size.y - 10
	target_pos.x = max(target_pos.x, 10.0)
	target_pos.y = max(target_pos.y, 10.0)
	_tooltip_panel.global_position = target_pos
	_tooltip_panel.visible = true

func _hide_tooltip() -> void:
	_tooltip_request_id += 1
	if _tooltip_panel:
		_tooltip_panel.visible = false

func _load_ui_font() -> void:
	if ResourceLoader.exists(UI_FONT_PATH):
		_ui_font = load(UI_FONT_PATH)

func _setup_label_style(label: Label, font_color: Color = Color.WHITE, font_size: int = TOOLTIP_FONT_SIZE) -> void:
	if _ui_font:
		label.add_theme_font_override("font", _ui_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_detail_style() -> void:
	if detail == null:
		return
	if _ui_font:
		detail.add_theme_font_override("normal_font", _ui_font)
		detail.add_theme_font_override("bold_font", _ui_font)
		detail.add_theme_font_override("italics_font", _ui_font)
		detail.add_theme_font_override("bold_italics_font", _ui_font)
		detail.add_theme_font_override("mono_font", _ui_font)
	detail.add_theme_font_size_override("normal_font_size", 34)
	detail.add_theme_font_size_override("bold_font_size", 34)
	detail.add_theme_font_size_override("italics_font_size", 34)
	detail.add_theme_font_size_override("bold_italics_font_size", 34)
	detail.add_theme_font_size_override("mono_font_size", 34)
	detail.add_theme_color_override("default_color", Color.WHITE)
	detail.add_theme_color_override("font_outline_color", Color.BLACK)
	detail.add_theme_constant_override("outline_size", 6)

func _reset_tooltip_layout() -> void:
	if _tooltip_panel == null or _tooltip_vbox == null:
		return
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.custom_minimum_size = Vector2.ZERO
	_tooltip_panel.global_position = Vector2(-10000, -10000)
	_tooltip_panel.visible = true
	_tooltip_vbox.size = Vector2.ZERO
	_tooltip_desc_label.size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_tooltip_reward_label.size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_tooltip_reward_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)

func _finalize_tooltip_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var content_size := _tooltip_vbox.get_combined_minimum_size()
	var panel_size := content_size + Vector2(20, 16)
	_tooltip_panel.custom_minimum_size = panel_size
	_tooltip_panel.size = panel_size

func _on_exit_pressed() -> void:
	exit_requested.emit()
