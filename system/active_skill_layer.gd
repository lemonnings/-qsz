extends CanvasLayer

@export var now_character_anime: AnimatedSprite2D
@export var now_character_name: RichTextLabel

@export var exit_button: Button

@export var active_skill1: Panel
@export var active_skill2: Panel
@export var active_skill3: Panel

@export var skillFlowContainer: FlowContainer

@export var skill1: Panel
@export var skill2: Panel
@export var skill3: Panel
@export var skill4: Panel
@export var skill5: Panel
@export var skill6: Panel
@export var skill7: Panel
@export var skill8: Panel
@export var skill9: Panel
@export var skill10: Panel
@export var skill11: Panel
@export var skill12: Panel
@export var skill13: Panel
@export var skill14: Panel
@export var skill15: Panel

var active_slot_panels: Array[Panel] = []
var learned_skill_panels: Array[Panel] = []
var slot_keys: Array[String] = ["space", "q", "e"]

var panel_icons: Dictionary = {}
var panel_skill_map: Dictionary = {}

var tooltip_panel: Panel
var tooltip_visible: bool = false

func _ready() -> void:
	active_slot_panels = [active_skill1, active_skill2, active_skill3]
	learned_skill_panels = [skill1, skill2, skill3, skill4, skill5, skill6, skill7, skill8, skill9, skill10, skill11, skill12, skill13, skill14, skill15]
	_setup_static_ui_input_filter()
	exit_button.pressed.connect(_on_exit_pressed)
	_setup_panels()
	_create_tooltip()
	# 这个界面需要在拖拽期间持续检查鼠标状态，
	# 这样才能把 Godot 内置拖拽想切换的鼠标样式重新压回默认箭头。
	set_process(true)
	open_layer()

func _process(_delta: float) -> void:
	# Godot 在 UI 拖拽时，可能会自动把鼠标切成“可放下/不可放下”等样式。
	# 这里统一强制回默认箭头，满足“拖动技能时不要变换鼠标样式”的需求。
	if get_viewport().gui_is_dragging():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _setup_static_ui_input_filter() -> void:
	var panel_root = get_node("Panel")
	var skill_hotkey_label = panel_root.get_node("skill_hotkey") as Control
	var skill_tip_label = panel_root.get_node("skill_tip") as Control
	skill_hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func open_layer() -> void:
	_update_character_info()
	_refresh_learned_skill_panels()
	_refresh_active_skill_panels()

func _on_exit_pressed() -> void:
	Global.save_game()
	var default_layer = get_node("../DefaultLayer")
	default_layer.hide_dark_overlay()
	default_layer.hide_skill_layer()
	PC.movement_disabled = false
	_hide_tooltip()

func _setup_panels() -> void:
	for panel in learned_skill_panels:
		_setup_single_panel(panel, true)
	for panel in active_slot_panels:
		_setup_single_panel(panel, false)

func _setup_single_panel(panel: Panel, can_drag: bool) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 保持面板始终使用默认箭头鼠标，避免拖拽技能时变成其他样式。
	# 这里用最小改动处理，只影响技能配置界面的这些面板。
	panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var icon = _get_or_create_icon(panel)
	panel_icons[panel] = icon
	panel.mouse_entered.connect(_on_panel_mouse_entered.bind(panel))
	panel.mouse_exited.connect(_on_panel_mouse_exited.bind(panel))
	panel.gui_input.connect(_on_panel_gui_input.bind(panel))
	if can_drag:
		panel.set_drag_forwarding(_get_panel_drag_data.bind(panel), _can_panel_drop_data.bind(panel), _drop_panel_data.bind(panel))
	else:
		panel.set_drag_forwarding(_empty_drag_data, _can_panel_drop_data.bind(panel), _drop_panel_data.bind(panel))


func _get_or_create_icon(panel: Panel) -> TextureRect:
	var icon = panel.get_node_or_null("SkillIcon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "SkillIcon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = -4.0
		icon.offset_bottom = -4.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
	return icon

func _update_character_info() -> void:
	var current_character = PC.player_name
	now_character_name.text = PC.get_character_display_name(current_character)
	var player = get_tree().get_first_node_in_group("player")
	var character_sprite = player.get_node(current_character) as AnimatedSprite2D
	now_character_anime.sprite_frames = character_sprite.sprite_frames
	now_character_anime.animation = character_sprite.animation
	now_character_anime.play()

func _refresh_learned_skill_panels() -> void:
	panel_skill_map.clear()
	var learned_skill_ids: Array[String] = []
	for skill_id in Global.player_active_skill_data.keys():
		learned_skill_ids.append(skill_id)
	for i in range(learned_skill_panels.size()):
		var panel = learned_skill_panels[i]
		var icon = panel_icons[panel] as TextureRect
		if i < learned_skill_ids.size():
			var skill_id = learned_skill_ids[i]
			panel_skill_map[panel] = skill_id
			_apply_panel_icon(icon, skill_id)
			panel.visible = true
		else:
			panel_skill_map.erase(panel)
			icon.texture = null
			panel.visible = true

func _refresh_active_skill_panels() -> void:
	for i in range(active_slot_panels.size()):
		var panel = active_slot_panels[i]
		var slot_key = slot_keys[i]
		var icon = panel_icons[panel] as TextureRect
		var skill_name = Global.player_now_active_skill[slot_key].get("name", "")
		if skill_name == "":
			icon.texture = null
		else:
			_apply_panel_icon(icon, skill_name)

func _apply_panel_icon(icon: TextureRect, skill_id: String) -> void:
	var skill_data = Global.player_active_skill_data.get(skill_id, {})
	var icon_path = skill_data.get("icon", _get_default_icon_path(skill_id))
	icon.texture = load(icon_path)

func _get_default_icon_path(skill_id: String) -> String:
	match skill_id:
		"dodge":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shanbi.png"
		"mizongbu":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mizongbu.png"
		"huanling":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mingxiang.png"
		"random_strike":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/luanji.png"
		"beastify":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shouhua.png"
		"heal_hot":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yuliao.png"
		"water_sheild":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shuiliumu.png"
		"holy_fire":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png"
		_:
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shanbi.png"

func _empty_drag_data(_at_position: Vector2) -> Variant:
	return null

func _get_panel_drag_data(_at_position: Vector2, panel: Panel) -> Variant:
	if not panel_skill_map.has(panel):
		return null
	var skill_id = panel_skill_map[panel]
	var preview = _create_drag_preview(skill_id)
	panel.set_drag_preview(preview)
	return {
		"skill_id": skill_id
	}

func _create_drag_preview(skill_id: String) -> Control:
	var preview_panel = Panel.new()
	preview_panel.custom_minimum_size = Vector2(88, 88)
	var icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var skill_data = Global.player_active_skill_data.get(skill_id, {})
	var icon_path = skill_data.get("icon", _get_default_icon_path(skill_id))
	icon.texture = load(icon_path)
	preview_panel.add_child(icon)
	return preview_panel

func _can_panel_drop_data(_at_position: Vector2, data: Variant, panel: Panel) -> bool:
	if not active_slot_panels.has(panel):
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return data.has("skill_id")

func _drop_panel_data(_at_position: Vector2, data: Variant, panel: Panel) -> void:
	var skill_id = data["skill_id"] as String
	var slot_key = slot_keys[active_slot_panels.find(panel)]
	if _is_skill_already_equipped(skill_id, slot_key):
		_show_tip("配置失败：不能放置两个相同的技能")
		return
	Global.player_now_active_skill[slot_key] = {
		"name": skill_id
	}
	_refresh_active_skill_panels()
	Global.save_game()
	_show_tip("配置成功：" + _get_slot_display_name(slot_key) + " 装备了 " + _get_skill_display_name(skill_id))

func _is_skill_already_equipped(skill_id: String, exclude_slot_key: String) -> bool:
	for slot_key in slot_keys:
		if slot_key == exclude_slot_key:
			continue
		var equipped_skill_id = Global.player_now_active_skill[slot_key].get("name", "")
		if equipped_skill_id == skill_id:
			return true
	return false

func _get_slot_display_name(slot_key: String) -> String:
	match slot_key:
		"space":
			return "Space"
		"q":
			return "Q"
		"e":
			return "E"
		_:
			return slot_key

func _show_tip(message: String) -> void:
	var main_town = get_parent()
	main_town.tip.start_animation(message, 0.5)

func _on_panel_mouse_entered(panel: Panel) -> void:
	_show_tooltip_for_panel(panel)

func _on_panel_mouse_exited(_panel: Panel) -> void:
	_hide_tooltip()

func _on_panel_gui_input(event: InputEvent, panel: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event = event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and mouse_button_event.pressed:
			_show_tooltip_for_panel(panel)

func _show_tooltip_for_panel(panel: Panel) -> void:
	var skill_id = _get_skill_id_by_panel(panel)
	if skill_id == "":
		_hide_tooltip()
		return
	_show_tooltip(skill_id, panel)

func _get_skill_id_by_panel(panel: Panel) -> String:
	if panel_skill_map.has(panel):
		return panel_skill_map[panel]
	var panel_index = active_slot_panels.find(panel)
	if panel_index == -1:
		return ""
	var slot_key = slot_keys[panel_index]
	return Global.player_now_active_skill[slot_key].get("name", "")

func _create_tooltip() -> void:
	tooltip_panel = Panel.new()
	tooltip_panel.name = "SkillTooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tooltip_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(10, 8)
	tooltip_panel.add_child(vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.name = "Header"
	vbox.add_child(header_hbox)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_hbox.add_child(icon)

	var name_label = Label.new()
	name_label.name = "NameLabel"
	_setup_label_style(name_label)
	header_hbox.add_child(name_label)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	var detail_label = RichTextLabel.new()
	detail_label.name = "DetailLabel"
	detail_label.fit_content = true
	detail_label.custom_minimum_size = Vector2(240, 0)
	detail_label.bbcode_enabled = true
	detail_label.scroll_active = false
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_rich_text_style(detail_label)
	vbox.add_child(detail_label)

	add_child(tooltip_panel)

func _setup_label_style(label: Label, text_color: Color = Color(1.0, 1.0, 1.0)) -> void:
	var font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)

func _setup_rich_text_style(rich_label: RichTextLabel) -> void:
	var font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	rich_label.add_theme_font_override("normal_font", font)
	rich_label.add_theme_font_size_override("normal_font_size", 16)
	rich_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0))
	rich_label.add_theme_constant_override("line_separation", 4)
	rich_label.add_theme_constant_override("outline_size", 1)
	rich_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))

func _show_tooltip(skill_id: String, panel: Panel) -> void:
	var skill_data = Global.player_active_skill_data.get(skill_id, {})
	var level = skill_data.get("level", 1)
	var vbox = tooltip_panel.get_node("VBox")
	var header = vbox.get_node("Header")
	var icon = header.get_node("Icon")
	var name_label = header.get_node("NameLabel")
	var detail_label = vbox.get_node("DetailLabel")

	var icon_path = skill_data.get("icon", _get_default_icon_path(skill_id))
	icon.texture = load(icon_path)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.text = "  " + _get_skill_display_name(skill_id) + "  LV." + str(level)
	detail_label.text = _build_skill_detail_text(skill_id, level)

	tooltip_panel.size = Vector2.ZERO
	tooltip_panel.custom_minimum_size = Vector2.ZERO
	await get_tree().process_frame
	await get_tree().process_frame

	var content_size = vbox.get_combined_minimum_size()
	var panel_size = content_size + Vector2(20, 16)
	tooltip_panel.custom_minimum_size = panel_size
	tooltip_panel.size = panel_size

	var panel_global_pos = panel.global_position
	var tooltip_pos = panel_global_pos + Vector2(panel.size.x + 10, 0)
	var viewport_size = get_viewport().get_visible_rect().size
	if tooltip_pos.x + tooltip_panel.size.x > viewport_size.x:
		tooltip_pos.x = panel_global_pos.x - tooltip_panel.size.x - 10
	if tooltip_pos.y + tooltip_panel.size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_panel.size.y - 10

	tooltip_panel.global_position = tooltip_pos
	tooltip_panel.visible = true
	tooltip_visible = true

func _hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false
	tooltip_visible = false

func _get_skill_display_name(skill_id: String) -> String:
	match skill_id:
		"dodge":
			return "闪避"
		"mizongbu":
			return "迷踪步"
		"huanling":
			return "唤灵"
		"random_strike":
			return "乱击"
		"beastify":
			return "魔化·趋桀"
		"heal_hot":
			return "疗愈"
		"water_sheild":
			return "水幕护体"
		"holy_fire":
			return "神圣灼烧"
		_:
			return skill_id

func _build_skill_detail_text(skill_id: String, level: int) -> String:
	match skill_id:
		"dodge":
			return _build_dodge_skill_text(level)
		"random_strike":
			return _build_random_strike_skill_text(level)
		"mizongbu":
			return _build_mizongbu_skill_text(level)
		"huanling":
			return _build_huanling_skill_text(level)
		"beastify":
			return _build_beastify_skill_text(level)
		"heal_hot":
			return _build_heal_hot_skill_text(level)
		"water_sheild":
			return _build_water_shield_skill_text(level)
		"holy_fire":
			return _build_holy_fire_skill_text(level)
		_:
			return "暂无描述"

func _format_skill_text(title: String, body_lines: Array[String]) -> String:
	var text = "[font_size=20]" + title + "[/font_size]\n\n"
	text += "[font_size=16]"
	for i in range(body_lines.size()):
		text += body_lines[i]
		if i < body_lines.size() - 1:
			text += "\n"
	text += "[/font_size]"
	return text

func _build_heal_hot_skill_text(level: int) -> String:
	var duration = 12.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			duration += 1.0

	var heal_base = 30.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			heal_base += 10.0

	var cooldown = 30.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(5.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	return _format_skill_text("持续恢复自身体力", [
		"持续时间：" + ("%.1f" % duration) + "秒",
		"基础回复：" + ("%.0f" % heal_base) + "点",
		"冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	])

func _build_water_shield_skill_text(level: int) -> String:
	var shield_percent = 10.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			shield_percent += 1.0

	var dr = 20.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			dr += 3.0

	var cooldown = 15.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 0.5
	cooldown = max(3.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	return _format_skill_text("释放水幕，获得护盾并提升减伤", [
		"护盾量：" + ("%.0f" % shield_percent) + "%最大体力",
		"减伤率：" + ("%.0f" % dr) + "%",
		"冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	])

func _build_holy_fire_skill_text(level: int) -> String:
	var damage_ratio = 30.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			damage_ratio += 4.0

	var duration = 5.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			duration += 0.5

	var cooldown = 24.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(4.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	return _format_skill_text("持续对自身周围造成伤害并回血", [
		"伤害：" + ("%.0f" % damage_ratio) + "%攻击力/0.5秒",
		"持续时间：" + ("%.1f" % duration) + "秒",
		"冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	])

func _build_mizongbu_skill_text(level: int) -> String:
	var dr = 40.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			dr += 4.0
	var cooldown = 9.5
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			cooldown -= 0.5
	cooldown = max(2.0, cooldown)
	var duration = 2.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			duration += 0.3
	return _format_skill_text("短时间提升移速并减伤，期间伤害降低", [
		"减伤率：" + ("%.0f" % dr) + "%",
		"持续时间：" + ("%.1f" % duration) + "秒",
		"冷却时间：" + ("%.1f" % cooldown) + "秒"
	])

func _build_huanling_skill_text(level: int) -> String:
	var attr_bonus = 80.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			attr_bonus += 4.0
	var duration = 10.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			duration += 1.0
	var cooldown = 20.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(4.0, cooldown)
	return _format_skill_text("召唤陨灭剑灵协助作战", [
		"剑灵属性继承：" + ("%.0f" % attr_bonus) + "%",
		"持续时间：" + ("%.1f" % duration) + "秒",
		"冷却时间：" + ("%.1f" % cooldown) + "秒"
	])

func _build_beastify_skill_text(level: int) -> String:
	var claw_damage_ratio = 55.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			claw_damage_ratio += 4.0
	var attr_bonus = 20.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			attr_bonus += 3.0
	var duration = 15.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			duration += 1.0
	return _format_skill_text("魔化形态：剑气改为爪击并强化自身属性", [
		"爪击伤害：" + ("%.0f" % claw_damage_ratio) + "%攻击力",
		"攻击/攻速/移速提升：" + ("%.0f" % attr_bonus) + "%",
		"持续时间：" + ("%.1f" % duration) + "秒",
		"冷却时间：40.0秒"
	])

func _build_dodge_skill_text(level: int) -> String:
	var invincible_time = 0.5
	for lv in [2, 4, 6, 8, 10, 12, 14]:
		if level >= lv:
			invincible_time += 0.1

	var cooldown = 6.0
	for lv in [3, 5, 7, 9, 11, 13, 15]:
		if level >= lv:
			cooldown -= 0.5
	cooldown = max(1.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	return _format_skill_text("向移动方向位移并获得无敌", [
		"无敌时间：" + ("%.1f" % invincible_time) + "秒",
		"冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	])

func _build_random_strike_skill_text(level: int) -> String:
	var damage_multi = 50
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			damage_multi += 5

	var bullet_count = 10
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			bullet_count += 1

	var cooldown = 20.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(5.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	return _format_skill_text("向随机方向每0.1秒射出剑气", [
		"伤害倍率：" + str(damage_multi) + "%",
		"剑气数量：" + str(bullet_count) + "发",
		"冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	])
