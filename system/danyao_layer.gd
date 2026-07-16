extends CanvasLayer

signal exit_requested

const MODE_XIULIAN := "xiulian"
const MODE_LIANTI := "lianti"
const TAB_FADE_DURATION := 0.12
const TOOLTIP_WIDTH := 240.0
const ICON_INSET := 11.0
const LIANTI_ROW_WIDTH := 682.0
const LIANTI_ROW_HEIGHT := 72.0
const DETAIL_USED_COUNT_BASE_LEN := 4
const DETAIL_SHORT_SHIFT_PER_CHAR := 6.0
const DETAIL_LONG_SHIFT_PER_CHAR := 3.0

const XIULIAN_TIER_LABELS := ["一阶", "二阶", "三阶", "四阶", "五阶"]
const LIANTI_TIER_LABELS := ["玄阶", "地阶", "天阶"]

const XIULIAN_ITEMS := [
	["item_047", "item_048", "item_049", "item_050", "item_051", "item_052", "item_053", "item_054"],
	["item_037", "item_036", "item_039", "item_038", "item_055", "item_056", "item_057", "item_058"],
	["item_060", "item_061", "item_062", "item_063", "item_064", "item_065", "item_066", "item_067"],
	["item_068", "item_069", "item_070", "item_071", "item_072", "item_073", "item_074", "item_075"],
	["item_076", "item_077", "item_078", "item_079", "item_080", "item_081", "item_082", "item_083"],
]

const LIANTI_ITEMS := [
	["item_085", "item_088", "item_091", "item_094"],
	["item_086", "item_089", "item_092", "item_095"],
	["item_087", "item_090", "item_093", "item_096"],
]

const XIULIAN_STAT_LABELS := {
	"cultivation_poxu_level_max": "破虚（攻击）",
	"cultivation_xuanyuan_level_max": "玄元（体力）",
	"cultivation_liuguang_level_max": "流光（攻速）",
	"cultivation_hualing_level_max": "化灵（真气）",
	"cultivation_fengrui_level_max": "锋锐（暴击率）",
	"cultivation_huti_level_max": "护体（减伤率）",
	"cultivation_zhuifeng_level_max": "追风（移速）",
	"cultivation_liejin_level_max": "烈劲（暴击伤害）",
}

const XIULIAN_STAT_ORDER := [
	"cultivation_poxu_level_max",
	"cultivation_xuanyuan_level_max",
	"cultivation_liuguang_level_max",
	"cultivation_hualing_level_max",
	"cultivation_fengrui_level_max",
	"cultivation_huti_level_max",
	"cultivation_zhuifeng_level_max",
	"cultivation_liejin_level_max",
]

const LIANTI_STAT_LABELS := {
	"exp_multi": "经验获取率",
	"drop_multi": "掉落率",
	"sheild_multi": "护盾率",
	"heal_multi": "治疗率",
	"normal_monster_multi": "对小怪增伤",
	"boss_multi": "对精英首领增伤",
	"body_size": "体型大小",
	"attack_range": "伤害范围",
}

const LIANTI_STAT_ORDER := [
	"exp_multi",
	"drop_multi",
	"sheild_multi",
	"heal_multi",
	"normal_monster_multi",
	"boss_multi",
	"body_size",
	"attack_range",
]

@onready var panel: Panel = $Panel
@onready var active_detail: FlowContainer = $Panel/active_detail
@onready var type_label: RichTextLabel = $Panel/type
@onready var all_label: RichTextLabel = $Panel/all
@onready var template_slot: Panel = $Panel/active_detail/danyao
@onready var change_button: Button = $Panel/change
@onready var use_button: Button = $Panel/use
@onready var exit_button: Button = $Panel/Exit
@onready var tips: Panel = $tips

var current_mode: String = MODE_XIULIAN
var _tab_tween: Tween = null
var _tooltip_panel: Panel = null
var _tooltip_vbox: VBoxContainer = null
var _tooltip_name_label: RichTextLabel = null
var _tooltip_detail_label: Label = null
var _tooltip_count_label: Label = null
var _tooltip_tween: Tween = null
var _tooltip_request_id: int = 0
var _tooltip_font: Font = null


func _ready() -> void:
	visible = false
	if ResourceLoader.exists("res://AssetBundle/Uranus_Pixel_11Px.ttf"):
		_tooltip_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	template_slot.visible = false
	change_button.pressed.connect(_on_change_pressed)
	use_button.pressed.connect(_on_use_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_create_tooltip()
	_refresh_content(false)


func open_layer() -> void:
	current_mode = MODE_XIULIAN
	visible = true
	_refresh_content(false)
	_hide_tooltip()


func prepare_for_close() -> void:
	_hide_tooltip()


func _on_exit_pressed() -> void:
	exit_requested.emit()


func _on_change_pressed() -> void:
	current_mode = MODE_LIANTI if current_mode == MODE_XIULIAN else MODE_XIULIAN
	_hide_tooltip()
	_refresh_content(true)


func _on_use_pressed() -> void:
	var total_used := 0
	for item_id in _get_current_item_ids():
		var use_count := _get_available_use_count(item_id)
		if use_count <= 0:
			continue
		var result: Dictionary = ItemManager.use_item(item_id, use_count)
		if bool(result.get("success", false)):
			total_used += use_count
	if total_used <= 0:
		_show_tips("当前没有可以服用的丹药", 0.5)
		_refresh_content(false)
		return
	_show_tips("一键服用了所有可以使用的丹药", 0.5)
	_hide_tooltip()
	_refresh_content(false)


func _refresh_content(animated: bool) -> void:
	if animated:
		_fade_refresh_content()
	else:
		_apply_content()


func _fade_refresh_content() -> void:
	if _tab_tween and _tab_tween.is_valid():
		_tab_tween.kill()
	_tab_tween = create_tween()
	_tab_tween.set_parallel(true)
	for node in [active_detail, type_label, all_label]:
		_tab_tween.tween_property(node, "modulate:a", 0.0, TAB_FADE_DURATION)
	_tab_tween.set_parallel(false)
	_tab_tween.tween_callback(_apply_content)
	_tab_tween.set_parallel(true)
	for node in [active_detail, type_label, all_label]:
		_tab_tween.tween_property(node, "modulate:a", 1.0, TAB_FADE_DURATION)


func _apply_content() -> void:
	type_label.text = "\n".join(XIULIAN_TIER_LABELS if current_mode == MODE_XIULIAN else LIANTI_TIER_LABELS)
	change_button.text = "切换炼体" if current_mode == MODE_XIULIAN else "切换修行"
	_rebuild_slots()
	_refresh_summary()
	use_button.disabled = not _has_any_available_use()
	use_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if use_button.disabled else Control.MOUSE_FILTER_STOP


func _rebuild_slots() -> void:
	for child in active_detail.get_children():
		if child != template_slot:
			child.queue_free()
	if current_mode == MODE_LIANTI:
		_rebuild_lianti_rows()
		return
	for item_id in _get_current_item_ids():
		var slot := template_slot.duplicate() as Panel
		slot.visible = true
		slot.name = item_id
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.set_meta("item_id", item_id)
		_setup_slot(slot, item_id)
		active_detail.add_child(slot)


func _rebuild_lianti_rows() -> void:
	for tier_index in range(LIANTI_ITEMS.size()):
		var row := Control.new()
		row.name = "lianti_row_%d" % tier_index
		row.custom_minimum_size = Vector2(LIANTI_ROW_WIDTH, LIANTI_ROW_HEIGHT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_detail.add_child(row)

		var hbox := HBoxContainer.new()
		hbox.name = "items"
		hbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hbox.add_theme_constant_override("separation", 10)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hbox)

		for item_id in LIANTI_ITEMS[tier_index]:
			var slot := template_slot.duplicate() as Panel
			slot.visible = true
			slot.name = str(item_id)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.set_meta("item_id", str(item_id))
			_setup_slot(slot, str(item_id))
			hbox.add_child(slot)


func _setup_slot(slot: Panel, item_id: String) -> void:
	var item_data := ItemManager.get_item_all_data(item_id)
	var icon_path := str(item_data.get("item_icon", ""))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = ICON_INSET
	icon.offset_top = ICON_INSET
	icon.offset_right = - ICON_INSET
	icon.offset_bottom = - ICON_INSET
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	slot.add_child(icon)
	slot.move_child(icon, 0)

	var detail := slot.get_node_or_null("detail") as RichTextLabel
	if detail:
		detail.bbcode_enabled = true
		detail.text = _get_slot_detail_text(item_id)
		detail.position.x += _get_detail_x_shift(item_id)
	slot.modulate.a = 1.0
	slot.gui_input.connect(_on_slot_gui_input.bind(slot))


func _get_slot_detail_text(item_id: String) -> String:
	var held := int(Global.player_inventory.get(item_id, 0))
	var info := ItemManager.get_limited_pill_use_info(item_id)
	var used := int(info.get("used", 0))
	var max_uses := int(info.get("max_uses", 0))
	if held <= 0:
		return "[color=#888888]%d\n%d/%d[/color]" % [held, used, max_uses]
	var used_line := "%d/%d" % [used, max_uses]
	if max_uses > 0 and used >= max_uses:
		used_line = "[color=YELLOW]%s[/color]" % used_line
	else:
		used_line = "[color=WHITE]%s[/color]" % used_line
	return "[color=WHITE]%d[/color]\n%s" % [held, used_line]


func _get_detail_x_shift(item_id: String) -> float:
	var info := ItemManager.get_limited_pill_use_info(item_id)
	var used_text := "%d/%d" % [int(info.get("used", 0)), int(info.get("max_uses", 0))]
	var length_delta := used_text.length() - DETAIL_USED_COUNT_BASE_LEN
	if length_delta < 0:
		return float(length_delta) * DETAIL_SHORT_SHIFT_PER_CHAR
	if length_delta > 0:
		return float(length_delta) * DETAIL_LONG_SHIFT_PER_CHAR
	return 0.0


func _on_slot_gui_input(event: InputEvent, slot: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_show_tooltip(slot)
			slot.accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_show_tooltip(slot)
			slot.accept_event()


func _input(event: InputEvent) -> void:
	if not visible or _tooltip_panel == null or not _tooltip_panel.visible:
		return
	var click_pos := Vector2.ZERO
	var should_check := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			click_pos = mouse_event.position
			should_check = true
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			click_pos = touch_event.position
			should_check = true
	if not should_check:
		return
	if _tooltip_panel.get_global_rect().has_point(click_pos):
		return
	if _is_point_on_danyao_slot(click_pos):
		return
	_hide_tooltip()


func _is_point_on_danyao_slot(point: Vector2) -> bool:
	for slot in _get_visible_danyao_slots(active_detail):
		if slot.get_global_rect().has_point(point):
			return true
	return false


func _get_visible_danyao_slots(root: Node) -> Array[Panel]:
	var slots: Array[Panel] = []
	for child in root.get_children():
		if child is Panel and child.has_meta("item_id") and child.visible:
			slots.append(child as Panel)
		slots.append_array(_get_visible_danyao_slots(child))
	return slots


func _create_tooltip() -> void:
	_tooltip_panel = Panel.new()
	_tooltip_panel.name = "DanyaoTooltipPanel"
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	add_child(_tooltip_panel)

	_tooltip_vbox = VBoxContainer.new()
	_tooltip_vbox.name = "VBox"
	_tooltip_vbox.position = Vector2(10, 8)
	_tooltip_panel.add_child(_tooltip_vbox)

	_tooltip_name_label = RichTextLabel.new()
	_tooltip_name_label.bbcode_enabled = true
	_tooltip_name_label.fit_content = true
	_tooltip_name_label.scroll_active = false
	_setup_rich_label(_tooltip_name_label)
	_tooltip_vbox.add_child(_tooltip_name_label)

	var separator := HSeparator.new()
	_tooltip_vbox.add_child(separator)

	_tooltip_detail_label = Label.new()
	_tooltip_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_detail_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	_setup_label(_tooltip_detail_label)
	_tooltip_vbox.add_child(_tooltip_detail_label)

	_tooltip_count_label = Label.new()
	_setup_label(_tooltip_count_label, Color(1.0, 0.85, 0.0))
	_tooltip_vbox.add_child(_tooltip_count_label)


func _setup_label(label: Label, font_color: Color = Color.WHITE) -> void:
	if _tooltip_font:
		label.add_theme_font_override("font", _tooltip_font)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)


func _setup_rich_label(label: RichTextLabel) -> void:
	if _tooltip_font:
		label.add_theme_font_override("normal_font", _tooltip_font)
		label.add_theme_font_override("default_font", _tooltip_font)
	label.add_theme_font_size_override("normal_font_size", 24)
	label.add_theme_color_override("default_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)


func _show_tooltip(slot: Panel) -> void:
	var item_id := str(slot.get_meta("item_id", ""))
	var item_data := ItemManager.get_item_all_data(item_id)
	if item_data.is_empty():
		return
	_tooltip_request_id += 1
	var request_id := _tooltip_request_id
	var rare := str(item_data.get("item_rare", "common"))
	_tooltip_name_label.text = "[color=%s][font_size=29]%s[/font_size][/color]" % [
		_get_rare_color_hex(rare),
		str(item_data.get("item_name", item_id))
	]
	_tooltip_detail_label.text = str(item_data.get("item_detail", ""))
	var info := ItemManager.get_limited_pill_use_info(item_id)
	_tooltip_count_label.text = "持有：%d    已服用：%d/%d" % [
		int(Global.player_inventory.get(item_id, 0)),
		int(info.get("used", 0)),
		int(info.get("max_uses", 0))
	]
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.custom_minimum_size = Vector2.ZERO
	_tooltip_panel.global_position = Vector2(-10000, -10000)
	_tooltip_panel.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if request_id != _tooltip_request_id:
		return
	var content_size := _tooltip_vbox.get_combined_minimum_size()
	var panel_size := content_size + Vector2(20, 16)
	_tooltip_panel.custom_minimum_size = panel_size
	_tooltip_panel.size = panel_size
	_position_tooltip(slot)
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip_panel.modulate.a = 0.0
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.15)


func _position_tooltip(slot: Panel) -> void:
	var slot_pos := slot.global_position
	var tooltip_pos := slot_pos + Vector2(slot.size.x + 10, 0)
	var vp_size := get_viewport().get_visible_rect().size
	if tooltip_pos.x + _tooltip_panel.size.x > vp_size.x:
		tooltip_pos.x = slot_pos.x - _tooltip_panel.size.x - 10
	if tooltip_pos.y + _tooltip_panel.size.y > vp_size.y:
		tooltip_pos.y = vp_size.y - _tooltip_panel.size.y - 10
	if tooltip_pos.y < 0:
		tooltip_pos.y = 0
	_tooltip_panel.global_position = tooltip_pos


func _hide_tooltip() -> void:
	_tooltip_request_id += 1
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	if _tooltip_panel:
		_tooltip_panel.visible = false
		_tooltip_panel.modulate.a = 0.0


func _refresh_summary() -> void:
	all_label.bbcode_enabled = true
	if current_mode == MODE_XIULIAN:
		all_label.text = _build_xiulian_summary()
	else:
		all_label.text = _build_lianti_summary()


func _build_xiulian_summary() -> String:
	var totals := {}
	for stat_name in XIULIAN_STAT_ORDER:
		totals[stat_name] = 0
	for item_id in _flatten_item_groups(XIULIAN_ITEMS):
		var cfg: Dictionary = ItemManager.pill_config.get(item_id, {})
		var stat_name := str(cfg.get("var", ""))
		if stat_name == "":
			continue
		totals[stat_name] = int(totals.get(stat_name, 0)) + int(Global.pill_used_counts.get(item_id, 0)) * int(cfg.get("bonus", 0))
	var lines := ["[font_size=34]修炼等级提升[/font_size]"]
	for stat_name in XIULIAN_STAT_ORDER:
		lines.append("%s：+%d" % [str(XIULIAN_STAT_LABELS.get(stat_name, stat_name)), int(totals.get(stat_name, 0))])
	return "\n".join(lines)


func _build_lianti_summary() -> String:
	var totals := {}
	for stat_name in LIANTI_STAT_ORDER:
		totals[stat_name] = 0.0
	for item_id in _flatten_item_groups(LIANTI_ITEMS):
		var cfg: Dictionary = ItemManager.pill_config.get(item_id, {})
		var effects: Dictionary = cfg.get("effects", {})
		var used := int(Global.pill_used_counts.get(item_id, 0))
		for stat_name in effects.keys():
			totals[str(stat_name)] = float(totals.get(str(stat_name), 0.0)) + float(effects[stat_name]) * used
	var lines := ["[font_size=34]炼体效果[/font_size]"]
	for stat_name in LIANTI_STAT_ORDER:
		lines.append("%s：%s" % [
			str(LIANTI_STAT_LABELS.get(stat_name, stat_name)),
			_format_percent_bonus(float(totals.get(stat_name, 0.0)))
		])
	return "\n".join(lines)


func _format_percent_bonus(value: float) -> String:
	var percent := value * 100.0
	var sign := "+" if percent >= 0.0 else ""
	return "%s%s%%" % [sign, _trim_float(percent)]


func _trim_float(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


func _has_any_available_use() -> bool:
	for item_id in _get_current_item_ids():
		if _get_available_use_count(item_id) > 0:
			return true
	return false


func _get_available_use_count(item_id: String) -> int:
	var held := int(Global.player_inventory.get(item_id, 0))
	if held <= 0:
		return 0
	var info := ItemManager.get_limited_pill_use_info(item_id)
	var remaining := int(info.get("max_uses", 0)) - int(info.get("used", 0))
	return mini(held, maxi(0, remaining))


func _is_item_full(item_id: String) -> bool:
	var info := ItemManager.get_limited_pill_use_info(item_id)
	var max_uses := int(info.get("max_uses", 0))
	return max_uses > 0 and int(info.get("used", 0)) >= max_uses


func _get_current_item_ids() -> Array[String]:
	return _flatten_item_groups(XIULIAN_ITEMS if current_mode == MODE_XIULIAN else LIANTI_ITEMS)


func _flatten_item_groups(groups: Array) -> Array[String]:
	var ids: Array[String] = []
	for group in groups:
		for item_id in group:
			ids.append(str(item_id))
	return ids


func _show_tips(message: String, duration: float) -> void:
	if tips and tips.has_method("start_animation"):
		tips.start_animation(message, duration)


func _get_rare_color_hex(rare: String) -> String:
	match rare:
		"common":
			return "#ffffff"
		"rare":
			return "#87ceeb"
		"epic":
			return "#d78cff"
		"legendary":
			return "#ffd166"
		"artifact":
			return "#ff5555"
	return "#ffffff"
