extends CanvasLayer

@export var stage1: Button
@export var stage2: Button
@export var stage3: Button
@export var stage4: Button
@export var stage5: Button
@export var stage6: Button
@export var stage7: Button
@export var stage8: Button

@export var rect1: Area2D
@export var rect2: Area2D
@export var rect3: Area2D
@export var rect4: Area2D
@export var rect5: Area2D
@export var rect6: Area2D
@export var rect7: Area2D
@export var rect8: Area2D

@export var shallow_button: Button
@export var deep_button: Button
@export var core_button: Button
@export var poetry_button: Button

@onready var difficulty_bonus_label: RichTextLabel = $Control/DifficultyBounsLabel
@onready var difficulty_bonus_num: RichTextLabel = $Control/DifficultyBounsNum
@onready var difficulty_bonus_text: RichTextLabel = $Control/DifficultyBounsText
@onready var core_depth_right_button: Button = $Control/right
@onready var core_depth_left_button: Button = $Control/left

@onready var poey_bonus_label: RichTextLabel = $Control/poeyBounsText
@onready var mijing_panel: Panel = $Mijing
@onready var mijing_button_1: Button = $Mijing/Button
@onready var mijing_button_2: Button = $Mijing/Button2
@onready var mijing_button_3: Button = $Mijing/Button3
@onready var mijing_key_1: RichTextLabel = $Mijing/key1
@onready var mijing_key_2: RichTextLabel = $Mijing/key2
@onready var mijing_key_3: RichTextLabel = $Mijing/key3

const TOOLTIP_FONT_SIZE := 24
const MOUSE_OFFSET := Vector2(34, 24)
const TOOLTIP_DESC_WIDTH := 260.0
const TOOLTIP_SCREEN_MARGIN := 10.0
const CORE_BONUS_COLOR_VALUE := "yellow"
const CORE_BONUS_COLOR_UPGRADED := "red"
const CORE_BONUS_COLOR_MECHANIC := "orange"

# 关卡说明数据
const STAGE_INFO := {
	"stage1": {
		"stage_id": "peach_grove",
		"stage_name": "壹 · 桃林",
		"stage_desc": "桃源镇外的桃林，即使在结界最外围，也能感受到强烈的魔气。",
		"available": true
	},
	"stage2": {
		"stage_id": "ruin",
		"stage_name": "贰 · 古迹",
		"stage_desc": "残垣断壁间无数精怪游荡，祭祀用的宣纸灯笼都化作了魔物。",
		"available": true
	},
	"stage3": {
		"stage_id": "cave",
		"stage_name": "叁 · 深窟",
		"stage_desc": "幽深的洞窟是通往山顶的必经之路，但洞窟深处却有着一股让诺姆熟悉的气息……",
		"available": true
	},
	"stage4": {
		"stage_id": "forest",
		"stage_name": "肆 · 密林",
		"stage_desc": "密林深处被封印的气息愈加强盛，被魔气侵蚀的森林危机四伏。",
		"available": true
	},
	"stage5": {
		"stage_name": "未开放关卡",
		"stage_desc": "当前测试版本该关卡暂未开放。",
		"available": false
	},
	"stage6": {
		"stage_name": "未开放关卡",
		"stage_desc": "当前测试版本该关卡暂未开放。",
		"available": false
	},
	"stage7": {
		"stage_name": "未开放关卡",
		"stage_desc": "当前测试版本该关卡暂未开放。",
		"available": false
	},
	"stage8": {
		"stage_name": "未开放关卡",
		"stage_desc": "当前测试版本该关卡暂未开放。",
		"available": false
	}
}

var _stage_buttons: Dictionary = {}
var _stage_rect_map: Dictionary = {}
var _difficulty_button_map: Dictionary = {}
var _hovered_stage_key: String = ""
var _tooltip_panel: Panel = null
var _tooltip_vbox: VBoxContainer = null
var _tooltip_name_label: Label = null
var _tooltip_desc_label: Label = null
var _tooltip_power_label: Label = null
var _tooltip_font: Font = null
var _tooltip_cached_size: Vector2 = Vector2.ZERO
var _tooltip_canvas_layer: CanvasLayer = null
var _tooltip_request_id: int = 0
var _tooltip_tween: Tween = null
var _stage_tooltips_suppressed: bool = false
var _selected_difficulty: String = Global.STAGE_DIFFICULTY_SHALLOW
var _lock_texture: AtlasTexture = null
var _difficulty_lock_overlays: Dictionary = {}
var _stage_lock_overlays: Dictionary = {}
var _mijing_buttons: Dictionary = {}
var _mijing_key_labels: Dictionary = {}
var _mijing_lock_overlays: Dictionary = {}
var _core_bonus_controls: Array[Control] = []
var _core_bonus_tween: Tween = null
var _poetry_bonus_controls: Array[Control] = []
var _poetry_bonus_tween: Tween = null
var _hovered_mijing_id: String = ""

const LOCK_ICON_TEXTURE_PATH := "res://AssetBundle/Sprites/Sprite sheets/Sprite sheet for Basic Pack.png"
const LOCK_ICON_REGION := Rect2(496, 160, 16, 16)
const DIFFICULTY_LOCK_SCALE := 3.0
const STAGE_LOCK_SCALE := 3.2
const MIJING_LOCK_SCALE := STAGE_LOCK_SCALE
const MIJING_DIFU_ID := "difu"
const MIJING_KONGMENG_ID := "kongmeng"
const MIJING_DIYU_ID := "diyu"
const MIJING_INFO := {
	MIJING_DIFU_ID: {
		"stage_id": "difu",
		"stage_name": "九幽冥府",
		"stage_desc": "传说是通向死者之都的第一道关卡，而现在里面充斥着大量狂暴的魂灵。"
	},
	MIJING_KONGMENG_ID: {
		"stage_id": "",
		"stage_name": "空濛秘境",
		"stage_desc": "当前秘境暂未开放。"
	},
	MIJING_DIYU_ID: {
		"stage_id": "",
		"stage_name": "地狱秘境",
		"stage_desc": "当前秘境暂未开放。"
	}
}

func _ready() -> void:
	_stage_buttons = {
		"stage1": stage1,
		"stage2": stage2,
		"stage3": stage3,
		"stage4": stage4,
		"stage5": stage5,
		"stage6": stage6,
		"stage7": stage7,
		"stage8": stage8
	}
	_stage_rect_map = {
		"stage1": rect1,
		"stage2": rect2,
		"stage3": rect3,
		"stage4": rect4,
		"stage5": rect5,
		"stage6": rect6,
		"stage7": rect7,
		"stage8": rect8
	}
	
	if ResourceLoader.exists("res://AssetBundle/Uranus_Pixel_11Px.ttf"):
		_tooltip_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	_setup_lock_texture()
	
	for button in _stage_buttons.values():
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.visible = false
			button.modulate.a = 0.0
	
	_create_tooltip_panel()
	_connect_rect_input_events()
	_connect_difficulty_buttons()
	_setup_mijing_controls()
	_setup_core_bonus_controls()
	_setup_poetry_bonus_controls()
	_fix_difficulty_button_hit_areas()
	prepare_for_open()

func _process(_delta: float) -> void:
	if _hovered_stage_key.is_empty() and _hovered_mijing_id.is_empty():
		return
	if _tooltip_panel == null or not _tooltip_panel.visible:
		return
	_update_tooltip_position()

# 每次重新打开关卡层时，重置悬浮态和难度按钮显示。
func prepare_for_open() -> void:
	_stage_tooltips_suppressed = false
	_hovered_stage_key = ""
	_hide_tooltip()
	_selected_difficulty = Global.validate_stage_difficulty_id(Global.selected_stage_difficulty)
	if not Global.is_stage_difficulty_unlocked(_selected_difficulty):
		_selected_difficulty = Global.STAGE_DIFFICULTY_SHALLOW
		Global.set_selected_stage_difficulty(_selected_difficulty)
	var max_unlocked_core_depth := Global.get_global_max_unlocked_core_depth()
	if max_unlocked_core_depth > 0 and Global.selected_core_depth > max_unlocked_core_depth:
		Global.set_selected_core_depth(max_unlocked_core_depth)
	# 诗想难度：通关cave后才显示按钮
	if poetry_button != null:
		poetry_button.visible = Global.is_stage_cleared("cave")
	_refresh_lock_visuals()
	_apply_difficulty_button_visual()
	_update_mijing_ui()

func reset_stage_tooltip_state() -> void:
	prepare_for_open()

func suppress_stage_tooltips(suppressed: bool) -> void:
	_stage_tooltips_suppressed = suppressed
	if suppressed:
		_hide_tooltip()

func _connect_rect_input_events() -> void:
	if rect1 != null:
		rect1.input_event.connect(_on_rect_input_event.bind("stage1"))
	if rect2 != null:
		rect2.input_event.connect(_on_rect_input_event.bind("stage2"))
	if rect3 != null:
		rect3.input_event.connect(_on_rect_input_event.bind("stage3"))
	if rect4 != null:
		rect4.input_event.connect(_on_rect_input_event.bind("stage4"))
	if rect5 != null:
		rect5.input_event.connect(_on_rect_input_event.bind("stage5"))
	if rect6 != null:
		rect6.input_event.connect(_on_rect_input_event.bind("stage6"))
	if rect7 != null:
		rect7.input_event.connect(_on_rect_input_event.bind("stage7"))
	if rect8 != null:
		rect8.input_event.connect(_on_rect_input_event.bind("stage8"))

func _connect_difficulty_buttons() -> void:
	_difficulty_button_map = {
		Global.STAGE_DIFFICULTY_SHALLOW: shallow_button,
		Global.STAGE_DIFFICULTY_DEEP: deep_button,
		Global.STAGE_DIFFICULTY_CORE: core_button,
		Global.STAGE_DIFFICULTY_POETRY: poetry_button
	}
	for difficulty_id in _difficulty_button_map.keys():
		var button := _difficulty_button_map[difficulty_id] as Button
		if button != null and not button.pressed.is_connected(_on_difficulty_button_pressed.bind(difficulty_id)):
			button.pressed.connect(_on_difficulty_button_pressed.bind(difficulty_id))

func _setup_mijing_controls() -> void:
	_mijing_buttons = {
		MIJING_DIFU_ID: mijing_button_1,
		MIJING_KONGMENG_ID: mijing_button_2,
		MIJING_DIYU_ID: mijing_button_3
	}
	_mijing_key_labels = {
		MIJING_DIFU_ID: mijing_key_1,
		MIJING_KONGMENG_ID: mijing_key_2,
		MIJING_DIYU_ID: mijing_key_3
	}
	for label in _mijing_key_labels.values():
		var key_label := label as RichTextLabel
		if key_label != null:
			key_label.bbcode_enabled = true
	for mijing_id in _mijing_buttons.keys():
		var button := _mijing_buttons[mijing_id] as Button
		if button == null:
			continue
		if not button.pressed.is_connected(_on_mijing_button_pressed.bind(mijing_id)):
			button.pressed.connect(_on_mijing_button_pressed.bind(mijing_id))
		if not button.mouse_entered.is_connected(_on_mijing_mouse_entered.bind(mijing_id)):
			button.mouse_entered.connect(_on_mijing_mouse_entered.bind(mijing_id))
		if not button.mouse_exited.is_connected(_on_mijing_mouse_exited.bind(mijing_id)):
			button.mouse_exited.connect(_on_mijing_mouse_exited.bind(mijing_id))

func _has_any_mijing_unlocked() -> bool:
	for mijing_id in _mijing_buttons.keys():
		if _is_mijing_unlocked(str(mijing_id)):
			return true
	return false

func _is_mijing_unlocked(mijing_id: String) -> bool:
	if mijing_id == MIJING_DIFU_ID:
		return Global.is_difu_mijing_unlocked()
	return false

func _get_mijing_stage_id(mijing_id: String) -> String:
	var info: Dictionary = MIJING_INFO.get(mijing_id, {})
	return str(info.get("stage_id", ""))

func _is_mijing_difficulty_unlocked(mijing_id: String) -> bool:
	if not _is_mijing_unlocked(mijing_id):
		return false
	if _selected_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		return false
	var stage_id := _get_mijing_stage_id(mijing_id)
	if stage_id.is_empty():
		return false
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		return Global.can_enter_core_depth(stage_id, Global.selected_core_depth)
	return Global.can_enter_stage_difficulty(stage_id, _selected_difficulty)

func _get_mijing_key_requirement(mijing_id: String) -> Dictionary:
	var stage_id := _get_mijing_stage_id(mijing_id)
	if stage_id.is_empty() or _selected_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		return {"item_id": "", "required": 0}
	return Global.get_mijing_stage_key_requirement(stage_id, _selected_difficulty, Global.selected_core_depth)

func _update_mijing_ui() -> void:
	if mijing_panel == null:
		return
	var panel_visible := _has_any_mijing_unlocked()
	mijing_panel.visible = panel_visible
	if not panel_visible:
		return
	_ensure_mijing_lock_overlays()
	for mijing_id in _mijing_buttons.keys():
		var id := str(mijing_id)
		var button := _mijing_buttons[id] as Button
		var key_label := _mijing_key_labels[id] as RichTextLabel
		var unlocked := _is_mijing_unlocked(id)
		var difficulty_unlocked := _is_mijing_difficulty_unlocked(id)
		var requirement := _get_mijing_key_requirement(id)
		var item_id := str(requirement.get("item_id", ""))
		var required_count := int(requirement.get("required", 0))
		var owned_count := Global.get_item_count(item_id) if not item_id.is_empty() else 0
		var count_color := "green" if required_count > 0 and owned_count >= required_count else "#777"
		if key_label != null:
			key_label.text = "[color=%s]%d[/color] / %d" % [count_color, owned_count, required_count]
		if button != null:
			button.modulate = Color(1, 1, 1, 1) if difficulty_unlocked else Color(0.45, 0.45, 0.45, 0.95)
		var overlay := _mijing_lock_overlays.get(id) as Sprite2D
		if overlay != null:
			overlay.visible = not difficulty_unlocked

func _setup_core_bonus_controls() -> void:
	_core_bonus_controls.clear()
	for control in [difficulty_bonus_label, difficulty_bonus_num, difficulty_bonus_text, core_depth_right_button, core_depth_left_button]:
		if control != null:
			_core_bonus_controls.append(control)
			control.modulate.a = 0.0
			control.visible = false
	for label in [difficulty_bonus_label, difficulty_bonus_num, difficulty_bonus_text]:
		if label != null:
			label.bbcode_enabled = true
	if core_depth_right_button != null and not core_depth_right_button.pressed.is_connected(_on_core_depth_right_pressed):
		core_depth_right_button.pressed.connect(_on_core_depth_right_pressed)
	if core_depth_left_button != null and not core_depth_left_button.pressed.is_connected(_on_core_depth_left_pressed):
		core_depth_left_button.pressed.connect(_on_core_depth_left_pressed)

func _setup_poetry_bonus_controls() -> void:
	_poetry_bonus_controls.clear()
	if poey_bonus_label == null:
		return
	_poetry_bonus_controls.append(poey_bonus_label)
	poey_bonus_label.bbcode_enabled = true
	poey_bonus_label.modulate.a = 0.0
	poey_bonus_label.visible = false

func _fix_difficulty_button_hit_areas() -> void:
	for button in [shallow_button, deep_button, core_button, poetry_button]:
		if button == null:
			continue
		var ref_style = button.get_theme_stylebox("normal")
		if ref_style == null:
			continue
		var el = ref_style.expand_margin_left
		var et = ref_style.expand_margin_top
		var er = ref_style.expand_margin_right
		var eb = ref_style.expand_margin_bottom
		if el == 0 and et == 0 and er == 0 and eb == 0:
			continue
		# 扩大按钮矩形，使其覆盖原先 expand_margin 渲染的区域
		button.offset_left -= el
		button.offset_top -= et
		button.offset_right += er
		button.offset_bottom += eb
		# 替换各状态的 StyleBox：去掉 expand_margin，将其转为 content_margin
		for style_name in ["normal", "hover", "pressed", "focus"]:
			var style = button.get_theme_stylebox(style_name)
			if style == null:
				continue
			var new_style = style.duplicate()
			new_style.content_margin_left = style.get_margin(SIDE_LEFT) + el
			new_style.content_margin_top = style.get_margin(SIDE_TOP) + et
			new_style.content_margin_right = style.get_margin(SIDE_RIGHT) + er
			new_style.content_margin_bottom = style.get_margin(SIDE_BOTTOM) + eb
			new_style.expand_margin_left = 0
			new_style.expand_margin_top = 0
			new_style.expand_margin_right = 0
			new_style.expand_margin_bottom = 0
			button.add_theme_stylebox_override(style_name, new_style)

func _on_difficulty_button_pressed(difficulty_id: String) -> void:
	if not Global.is_stage_difficulty_unlocked(difficulty_id):
		_show_tip(_build_locked_difficulty_message_for(difficulty_id))
		return
	_selected_difficulty = Global.validate_stage_difficulty_id(difficulty_id)
	Global.set_selected_stage_difficulty(_selected_difficulty)
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		var global_start_depth := Global.get_global_core_start_depth()
		if Global.selected_core_depth < global_start_depth:
			Global.set_selected_core_depth(global_start_depth)
	_apply_difficulty_button_visual()
	_update_mijing_ui()
	if not _hovered_stage_key.is_empty():
		_show_stage_tooltip(_hovered_stage_key)
	if not _hovered_mijing_id.is_empty():
		_show_mijing_tooltip(_hovered_mijing_id)

# 给当前选中的难度按钮一个直观的高亮
func _apply_difficulty_button_visual() -> void:
	_refresh_lock_visuals()
	for difficulty_id in _difficulty_button_map.keys():
		var button := _difficulty_button_map[difficulty_id] as Button
		if button == null:
			continue
		var is_unlocked: bool = Global.is_stage_difficulty_unlocked(difficulty_id)
		if not is_unlocked:
			button.modulate = Color(0.4, 0.4, 0.4, 0.95)
		elif difficulty_id == _selected_difficulty:
			button.modulate = Color(1, 1, 1, 1)
		else:
			button.modulate = Color(0.7, 0.7, 0.7, 0.9)
	_update_core_bonus_ui(true)
	_update_poetry_bonus_ui(true)

func _on_core_depth_left_pressed() -> void:
	Global.set_selected_core_depth(Global.selected_core_depth - 1)
	_update_core_bonus_ui(false)
	_refresh_lock_visuals()
	_update_mijing_ui()
	if not _hovered_stage_key.is_empty():
		_show_stage_tooltip(_hovered_stage_key)
	if not _hovered_mijing_id.is_empty():
		_show_mijing_tooltip(_hovered_mijing_id)

func _on_core_depth_right_pressed() -> void:
	if Global.selected_core_depth >= Global.get_global_max_unlocked_core_depth():
		return
	Global.set_selected_core_depth(Global.selected_core_depth + 1)
	_update_core_bonus_ui(false)
	_refresh_lock_visuals()
	_update_mijing_ui()
	if not _hovered_stage_key.is_empty():
		_show_stage_tooltip(_hovered_stage_key)
	if not _hovered_mijing_id.is_empty():
		_show_mijing_tooltip(_hovered_mijing_id)

func _update_core_bonus_ui(animate_visibility: bool) -> void:
	var should_show := _selected_difficulty == Global.STAGE_DIFFICULTY_CORE
	_update_core_bonus_text()
	_set_core_bonus_visible(should_show, animate_visibility)
	_update_core_depth_navigation_state()

func _update_poetry_bonus_ui(animate_visibility: bool) -> void:
	var should_show := _selected_difficulty == Global.STAGE_DIFFICULTY_POETRY
	_set_poetry_bonus_visible(should_show, animate_visibility)

func _update_core_depth_navigation_state() -> void:
	var is_core_selected := _selected_difficulty == Global.STAGE_DIFFICULTY_CORE
	if core_depth_left_button != null:
		var can_go_left := Global.selected_core_depth > Global.CORE_DEPTH_MIN
		core_depth_left_button.disabled = not can_go_left
		core_depth_left_button.visible = is_core_selected and can_go_left
		core_depth_left_button.modulate.a = 1.0 if core_depth_left_button.visible else 0.0
	if core_depth_right_button != null:
		var max_unlocked_depth := Global.get_global_max_unlocked_core_depth()
		var can_go_right := Global.selected_core_depth < Global.CORE_DEPTH_MAX and Global.selected_core_depth < max_unlocked_depth
		core_depth_right_button.disabled = not can_go_right
		core_depth_right_button.visible = is_core_selected and can_go_right
		core_depth_right_button.modulate.a = 1.0 if core_depth_right_button.visible else 0.0

func _set_core_bonus_visible(should_show: bool, animate_visibility: bool) -> void:
	if _core_bonus_tween and _core_bonus_tween.is_valid():
		_core_bonus_tween.kill()
	if _core_bonus_controls.is_empty():
		return
	if not animate_visibility:
		for control in _core_bonus_controls:
			if control == core_depth_left_button or control == core_depth_right_button:
				continue
			control.visible = should_show
			control.modulate.a = 1.0 if should_show else 0.0
		return
	if should_show:
		_core_bonus_tween = create_tween()
		_core_bonus_tween.set_parallel(true)
		for control in _core_bonus_controls:
			if control == core_depth_left_button or control == core_depth_right_button:
				continue
			control.visible = true
			_core_bonus_tween.tween_property(control, "modulate:a", 1.0, 0.18)
	else:
		_core_bonus_tween = create_tween()
		_core_bonus_tween.set_parallel(true)
		for control in _core_bonus_controls:
			if control == core_depth_left_button or control == core_depth_right_button:
				continue
			_core_bonus_tween.tween_property(control, "modulate:a", 0.0, 0.15)
		_core_bonus_tween.set_parallel(false)
		_core_bonus_tween.tween_callback(func():
			for control in _core_bonus_controls:
				if control == core_depth_left_button or control == core_depth_right_button:
					continue
				control.visible = false
		)

func _set_poetry_bonus_visible(should_show: bool, animate_visibility: bool) -> void:
	if _poetry_bonus_tween and _poetry_bonus_tween.is_valid():
		_poetry_bonus_tween.kill()
	if _poetry_bonus_controls.is_empty():
		return
	if not animate_visibility:
		for control in _poetry_bonus_controls:
			control.visible = should_show
			control.modulate.a = 1.0 if should_show else 0.0
		return
	if should_show:
		_poetry_bonus_tween = create_tween()
		_poetry_bonus_tween.set_parallel(true)
		for control in _poetry_bonus_controls:
			control.visible = true
			_poetry_bonus_tween.tween_property(control, "modulate:a", 1.0, 0.18)
	else:
		_poetry_bonus_tween = create_tween()
		_poetry_bonus_tween.set_parallel(true)
		for control in _poetry_bonus_controls:
			_poetry_bonus_tween.tween_property(control, "modulate:a", 0.0, 0.15)
		_poetry_bonus_tween.set_parallel(false)
		_poetry_bonus_tween.tween_callback(func():
			for control in _poetry_bonus_controls:
				control.visible = false
		)

func _update_core_bonus_text() -> void:
	var depth := Global.clamp_core_depth(Global.selected_core_depth)
	var stage_id := _get_core_bonus_stage_id()
	if difficulty_bonus_label != null:
		difficulty_bonus_label.text = "核心进阶"
	if difficulty_bonus_num != null:
		difficulty_bonus_num.text = str(depth)
	if difficulty_bonus_text == null:
		return
	difficulty_bonus_text.clear()
	var qi_bonus := Global.get_core_qi_gain_bonus_percent(depth) - 40
	var stat_bonus := Global.get_stage_core_stat_bonus_percent(stage_id, depth)
	var move_bonus := 25 if depth >= 10 else 15
	var growth_bonus := 30 if depth >= 10 else 20
	var exp_bonus := 25 if depth >= 10 else 20
	var move_color := CORE_BONUS_COLOR_UPGRADED if depth >= 10 else CORE_BONUS_COLOR_VALUE
	var growth_color := CORE_BONUS_COLOR_UPGRADED if depth >= 10 else CORE_BONUS_COLOR_VALUE
	var exp_color := CORE_BONUS_COLOR_UPGRADED if depth >= 10 else CORE_BONUS_COLOR_VALUE
	var lines: Array[String] = [
		"真气获取提升%s" % _color_value("%d%%" % qi_bonus),
		"敌人攻击、体力提升%s" % _color_value("%d%%" % stat_bonus)
	]
	if depth >= 1:
		lines.append(_color_mechanic("首领技能强化"))
	if depth >= 2:
		lines.append("敌人移动速度提升%s" % _color_text("%d%%" % move_bonus, move_color))
	if depth >= 3:
		lines.append(_color_mechanic("出现被侵蚀的精英"))
	if depth >= 4:
		lines.append("灵气漩涡消耗精魄提升%s" % _color_value("25%"))
	if depth >= 5:
		lines.append("敌人攻击成长提升%s" % _color_text("%d%%" % growth_bonus, growth_color))
	if depth >= 6:
		lines.append("升级所需经验增加%s" % _color_text("%d%%" % exp_bonus, exp_color))
	if depth >= 7:
		lines.append(_color_mechanic("不定期飞弹袭击"))
	if depth >= 8:
		lines.append("灵气漩涡出现频率降低%s" % _color_value("16%"))
	if depth >= 9:
		lines.append("护盾与治疗效果降低%s" % _color_value("30%"))
	difficulty_bonus_text.parse_bbcode("\n".join(lines))

func _get_core_bonus_stage_id() -> String:
	if not _hovered_stage_key.is_empty():
		var hovered_info: Dictionary = STAGE_INFO.get(_hovered_stage_key, {})
		var hovered_stage_id := str(hovered_info.get("stage_id", ""))
		if not hovered_stage_id.is_empty():
			return hovered_stage_id
	if not Global.current_stage_id.is_empty():
		return Global.current_stage_id
	return str(STAGE_INFO.get("stage1", {}).get("stage_id", "peach_grove"))

func _color_value(text: String) -> String:
	return _color_text(text, CORE_BONUS_COLOR_VALUE)

func _color_mechanic(text: String) -> String:
	return _color_text(text, CORE_BONUS_COLOR_MECHANIC)

func _color_text(text: String, color_name: String) -> String:
	return "[color=%s]%s[/color]" % [color_name, text]

func _setup_lock_texture() -> void:
	if _lock_texture != null:
		return
	var atlas := load(LOCK_ICON_TEXTURE_PATH) as Texture2D
	if atlas == null:
		return
	_lock_texture = AtlasTexture.new()
	_lock_texture.atlas = atlas
	_lock_texture.region = LOCK_ICON_REGION

func _create_lock_sprite(lock_scale: float) -> Sprite2D:
	if _lock_texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = _lock_texture
	sprite.centered = true
	sprite.scale = Vector2.ONE * lock_scale
	sprite.z_index = 120
	sprite.visible = false
	return sprite

func _ensure_difficulty_lock_overlays() -> void:
	if _lock_texture == null:
		return
	for difficulty_id in _difficulty_button_map.keys():
		if is_instance_valid(_difficulty_lock_overlays.get(difficulty_id)):
			continue
		var button := _difficulty_button_map[difficulty_id] as Button
		if button == null:
			continue
		var overlay := _create_lock_sprite(DIFFICULTY_LOCK_SCALE)
		if overlay == null:
			continue
		overlay.name = "%s_lock_overlay" % difficulty_id
		button.add_child(overlay)
		_difficulty_lock_overlays[difficulty_id] = overlay

func _ensure_stage_lock_overlays() -> void:
	if _lock_texture == null:
		return
	for stage_key in _stage_buttons.keys():
		if is_instance_valid(_stage_lock_overlays.get(stage_key)):
			continue
		var rect := _stage_rect_map.get(stage_key) as Area2D
		if rect == null:
			continue
		var overlay := _create_lock_sprite(STAGE_LOCK_SCALE)
		if overlay == null:
			continue
		overlay.name = "%s_lock_overlay" % stage_key
		rect.add_child(overlay)
		_stage_lock_overlays[stage_key] = overlay

func _ensure_mijing_lock_overlays() -> void:
	if _lock_texture == null or mijing_panel == null:
		return
	for mijing_id in _mijing_buttons.keys():
		if is_instance_valid(_mijing_lock_overlays.get(mijing_id)):
			continue
		var button := _mijing_buttons[mijing_id] as Button
		if button == null:
			continue
		var overlay := _create_lock_sprite(MIJING_LOCK_SCALE)
		if overlay == null:
			continue
		overlay.name = "%s_lock_overlay" % str(mijing_id)
		overlay.z_index = 240
		mijing_panel.add_child(overlay)
		_mijing_lock_overlays[mijing_id] = overlay

func _get_mijing_lock_local_position(mijing_id: String) -> Vector2:
	var button := _mijing_buttons.get(mijing_id) as Button
	if button == null:
		return Vector2.ZERO
	return button.position + button.size * button.scale * 0.5

func _get_stage_lock_local_position(stage_key: String) -> Vector2:
	var rect := _stage_rect_map.get(stage_key) as Area2D
	if rect == null:
		return Vector2.ZERO
	for child in rect.get_children():
		if child is CollisionShape2D:
			return (child as CollisionShape2D).position
	return Vector2.ZERO

func _refresh_lock_visuals() -> void:
	_ensure_difficulty_lock_overlays()
	_ensure_stage_lock_overlays()
	_ensure_mijing_lock_overlays()
	for difficulty_id in _difficulty_button_map.keys():
		var button := _difficulty_button_map[difficulty_id] as Button
		var overlay := _difficulty_lock_overlays.get(difficulty_id) as Sprite2D
		if button != null and overlay != null:
			overlay.position = button.size * 0.5
			overlay.visible = not Global.is_stage_difficulty_unlocked(difficulty_id)
	for stage_key in _stage_buttons.keys():
		var overlay := _stage_lock_overlays.get(stage_key) as Sprite2D
		if overlay == null:
			continue
		overlay.position = _get_stage_lock_local_position(stage_key)
		overlay.visible = _should_show_stage_lock(stage_key)
	for mijing_id in _mijing_buttons.keys():
		var overlay := _mijing_lock_overlays.get(mijing_id) as Sprite2D
		if overlay != null:
			overlay.position = _get_mijing_lock_local_position(str(mijing_id))
			overlay.visible = not _is_mijing_difficulty_unlocked(str(mijing_id))

func _is_stage_available(stage_key: String) -> bool:
	return STAGE_INFO.get(stage_key, {}).get("available", false) == true

func _is_stage_unlocked(stage_key: String) -> bool:
	if not _is_stage_available(stage_key):
		return false
	var stage_id := str(STAGE_INFO.get(stage_key, {}).get("stage_id", ""))
	if stage_id.is_empty():
		return false
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		return Global.can_enter_core_depth(stage_id, Global.selected_core_depth)
	return Global.can_enter_stage_difficulty(stage_id, _selected_difficulty)

func _should_show_stage_lock(stage_key: String) -> bool:
	if not _is_stage_available(stage_key):
		return true
	return not _is_stage_unlocked(stage_key)

func _get_stage_name_by_id(stage_id: String) -> String:
	for stage_key in STAGE_INFO.keys():
		var info: Dictionary = STAGE_INFO.get(stage_key, {})
		if str(info.get("stage_id", "")) == stage_id:
			return str(info.get("stage_name", stage_id))
	return stage_id

func _build_locked_stage_message(stage_key: String) -> String:
	var info: Dictionary = STAGE_INFO.get(stage_key, {})
	if info.get("available", false) != true:
		return "当前测试版本该关卡暂未开放。"
	var stage_id := str(info.get("stage_id", ""))
	var stage_name := str(info.get("stage_name", "该关卡"))
	var difficulty_name := Global.get_stage_difficulty_display_name(_selected_difficulty)
	var previous_difficulty_id := Global.get_required_stage_clear_difficulty(_selected_difficulty)
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		var target_depth := Global.clamp_core_depth(Global.selected_core_depth)
		var unlocked_depth := Global.get_stage_max_unlocked_core_depth(stage_id)
		if unlocked_depth <= 0:
			return "需要先通关%s的深层，才能开启核心进阶1层。" % stage_name
		var global_start_depth := Global.get_global_core_start_depth()
		if target_depth <= global_start_depth:
			return "需要先通关%s的深层，才能开启核心进阶%d层。" % [stage_name, target_depth]
		return "需要先通关%s的核心进阶%d层，才能开启核心进阶%d层。" % [
			stage_name,
			max(1, target_depth - 1),
			target_depth
		]
	if _selected_difficulty == Global.STAGE_DIFFICULTY_SHALLOW:
		var previous_stage_id := Global.get_previous_stage_id(stage_id)
		if previous_stage_id.is_empty():
			return "%s当前暂未解锁。" % stage_name
		return "需要先通关%s的%s难度，才能开启%s的%s难度。" % [
			_get_stage_name_by_id(previous_stage_id),
			difficulty_name,
			stage_name,
			difficulty_name
		]
	if previous_difficulty_id.is_empty():
		return "%s当前暂未解锁。" % stage_name
	return "该难度暂未解锁！" % [
		stage_name,
		Global.get_stage_difficulty_display_name(previous_difficulty_id),
		stage_name,
		difficulty_name
	]

func _build_locked_difficulty_message_for(difficulty_id: String) -> String:
	var required_difficulty := Global.get_required_stage_clear_difficulty(difficulty_id)
	if required_difficulty.is_empty():
		return "当前难度暂未解锁。"
	return "需要先通关%s难度，才能开启%s难度。" % [
		Global.get_stage_difficulty_display_name(required_difficulty),
		Global.get_stage_difficulty_display_name(difficulty_id)
	]

func _setup_label_style(label: Label, font_color: Color = Color.WHITE) -> void:
	if _tooltip_font != null:
		label.add_theme_font_override("font", _tooltip_font)
	label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

func _create_tooltip_panel() -> void:
	_tooltip_panel = Panel.new()
	_tooltip_panel.name = "StageTooltipPanel"
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 300
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

	# 创建独立的 CanvasLayer 来放置提示框，避免父级 LevelChangeLayer 的
	# offset/scale 影响提示框的坐标，导致鼠标位置与提示框位置不对应。
	_tooltip_canvas_layer = CanvasLayer.new()
	_tooltip_canvas_layer.name = "TooltipCanvasLayer"
	_tooltip_canvas_layer.layer = 100
	add_child(_tooltip_canvas_layer)
	_tooltip_canvas_layer.add_child(_tooltip_panel)
	
	_tooltip_vbox = VBoxContainer.new()
	_tooltip_vbox.name = "VBox"
	_tooltip_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip_vbox.position = Vector2(10, 8)
	_tooltip_panel.add_child(_tooltip_vbox)
	
	_tooltip_name_label = Label.new()
	_tooltip_name_label.name = "NameLabel"
	_setup_label_style(_tooltip_name_label)
	_tooltip_vbox.add_child(_tooltip_name_label)
	
	var separator1 := HSeparator.new()
	_tooltip_vbox.add_child(separator1)
	
	_tooltip_desc_label = Label.new()
	_tooltip_desc_label.name = "DescLabel"
	_tooltip_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_setup_label_style(_tooltip_desc_label)
	_tooltip_vbox.add_child(_tooltip_desc_label)
	
	var separator2 := HSeparator.new()
	_tooltip_vbox.add_child(separator2)
	
	_tooltip_power_label = Label.new()
	_tooltip_power_label.name = "PowerLabel"
	_tooltip_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_label_style(_tooltip_power_label, Color(1.0, 0.85, 0.0))
	_tooltip_vbox.add_child(_tooltip_power_label)

func _get_tooltip_panel_size() -> Vector2:
	if _tooltip_panel == null or _tooltip_vbox == null:
		return Vector2.ZERO
	var content_size := _tooltip_vbox.get_combined_minimum_size() + Vector2(20, 16)
	var panel_min_size := _tooltip_panel.get_combined_minimum_size()
	var resolved_size := Vector2(
		maxf(content_size.x, maxf(panel_min_size.x, _tooltip_panel.size.x)),
		maxf(content_size.y, maxf(panel_min_size.y, _tooltip_panel.size.y))
	)
	return resolved_size.ceil()

func _update_tooltip_position() -> void:
	if _tooltip_panel == null:
		return
	var visible_rect := get_viewport().get_visible_rect()
	var mouse_pos := get_viewport().get_mouse_position()
	var tooltip_size := _tooltip_cached_size
	if tooltip_size == Vector2.ZERO:
		return
	
	var min_x := visible_rect.position.x + TOOLTIP_SCREEN_MARGIN
	var min_y := visible_rect.position.y + TOOLTIP_SCREEN_MARGIN
	var max_x := visible_rect.position.x + visible_rect.size.x - tooltip_size.x - TOOLTIP_SCREEN_MARGIN
	var max_y := visible_rect.position.y + visible_rect.size.y - tooltip_size.y - TOOLTIP_SCREEN_MARGIN
	var right_x := mouse_pos.x + MOUSE_OFFSET.x
	var left_x := mouse_pos.x - tooltip_size.x - MOUSE_OFFSET.x
	var bottom_y := mouse_pos.y + MOUSE_OFFSET.y
	var top_y := mouse_pos.y - tooltip_size.y - MOUSE_OFFSET.y
	var space_right := visible_rect.position.x + visible_rect.size.x - TOOLTIP_SCREEN_MARGIN - mouse_pos.x
	var space_left := mouse_pos.x - visible_rect.position.x - TOOLTIP_SCREEN_MARGIN
	var space_below := visible_rect.position.y + visible_rect.size.y - TOOLTIP_SCREEN_MARGIN - mouse_pos.y
	var space_above := mouse_pos.y - visible_rect.position.y - TOOLTIP_SCREEN_MARGIN
	var tooltip_pos := Vector2.ZERO
	
	# 优先放在鼠标右侧/下侧；放不下时切到更有空间的一边。
	tooltip_pos.x = right_x if tooltip_size.x <= space_right or space_right >= space_left else left_x
	tooltip_pos.y = bottom_y if tooltip_size.y <= space_below or space_below >= space_above else top_y
	
	# 最后统一夹紧，确保即使提示框很大也不会越过屏幕上下左右边界。
	tooltip_pos.x = clampf(tooltip_pos.x, min_x, max(min_x, max_x))
	tooltip_pos.y = clampf(tooltip_pos.y, min_y, max(min_y, max_y))
	_tooltip_panel.position = tooltip_pos - Vector2(0, 25)


func _show_tip(message: String) -> void:
	var current_scene = get_tree().current_scene
	if current_scene != null and "tip" in current_scene and current_scene.tip != null:
		if current_scene.tip.has_method("start_animation"):
			current_scene.tip.start_animation(message, 0.5)

func _build_locked_difficulty_message(stage_key: String) -> String:
	var info = STAGE_INFO.get(stage_key, {})
	var stage_name := str(info.get("stage_name", "该关卡"))
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		var stage_id := str(info.get("stage_id", ""))
		var target_depth := Global.clamp_core_depth(Global.selected_core_depth)
		var unlocked_depth := Global.get_stage_max_unlocked_core_depth(stage_id)
		if unlocked_depth <= 0:
			return "需要先通关%s的深层，才能进入核心进阶1层。" % stage_name
		var global_start_depth := Global.get_global_core_start_depth()
		if target_depth <= global_start_depth:
			return "需要先通关%s的深层，才能进入核心进阶%d层。" % [stage_name, target_depth]
		return "需要先通关%s的核心进阶%d层，才能进入核心进阶%d层。" % [
			stage_name,
			max(1, target_depth - 1),
			target_depth
		]
	var required_difficulty := Global.get_required_stage_clear_difficulty(_selected_difficulty)
	if required_difficulty.is_empty():
		return "当前难度暂未解锁。"
	return "需要先通关%s的%s，才能进入%s。" % [
		stage_name,
		Global.get_stage_difficulty_display_name(required_difficulty),
		Global.get_stage_difficulty_display_name(_selected_difficulty)
	]

func _on_rect_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, stage_key: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not _is_stage_available(stage_key):
		_show_tip(_build_locked_stage_message(stage_key))
		return
	if not _is_stage_unlocked(stage_key):
		_show_tip(_build_locked_stage_message(stage_key))
		return
	Global.set_selected_stage_difficulty(_selected_difficulty)
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		Global.set_selected_core_depth(Global.selected_core_depth)
	_hide_tooltip()
	var button := _stage_buttons.get(stage_key) as Button
	if button != null:
		button.pressed.emit()

func _get_mijing_locked_message(mijing_id: String) -> String:
	var info: Dictionary = MIJING_INFO.get(mijing_id, {})
	var mijing_name := str(info.get("stage_name", "该秘境"))
	if mijing_id == MIJING_KONGMENG_ID:
		return "需要先通关陆 · 幽域，才能开启空濛秘境。"
	if mijing_id == MIJING_DIYU_ID:
		return "需要先通关捌 · 次元裂隙，才能开启地狱秘境。"
	if _selected_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		return "诗想难度暂未开放。"
	var stage_id := _get_mijing_stage_id(mijing_id)
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		var target_depth := Global.clamp_core_depth(Global.selected_core_depth)
		var unlocked_depth := Global.get_stage_max_unlocked_core_depth(stage_id)
		if unlocked_depth <= 0:
			return "需要先通关%s的深层，才能开启核心进阶1层。" % mijing_name
		return "需要先通关%s的核心进阶%d层，才能开启核心进阶%d层。" % [
			mijing_name,
			max(1, target_depth - 1),
			target_depth
		]
	var required_difficulty := Global.get_required_stage_clear_difficulty(_selected_difficulty)
	if required_difficulty.is_empty():
		return "%s当前暂未解锁。" % mijing_name
	return "需要先通关%s的%s，才能进入%s。" % [
		mijing_name,
		Global.get_stage_difficulty_display_name(required_difficulty),
		Global.get_stage_difficulty_display_name(_selected_difficulty)
	]

func _get_mijing_key_status_text(mijing_id: String) -> String:
	var requirement := _get_mijing_key_requirement(mijing_id)
	var item_id := str(requirement.get("item_id", ""))
	var required_count := int(requirement.get("required", 0))
	var owned_count := Global.get_item_count(item_id) if not item_id.is_empty() else 0
	if required_count <= 0:
		return _get_mijing_locked_message(mijing_id)
	return "九幽秘钥：%d / %d" % [owned_count, required_count]

func _on_mijing_button_pressed(mijing_id: String) -> void:
	if not _is_mijing_difficulty_unlocked(mijing_id):
		_show_tip(_get_mijing_locked_message(mijing_id))
		return
	var requirement := _get_mijing_key_requirement(mijing_id)
	var item_id := str(requirement.get("item_id", ""))
	var required_count := int(requirement.get("required", 0))
	if required_count > 0 and Global.get_item_count(item_id) < required_count:
		_show_tip("九幽秘钥不足")
		return
	if mijing_id == MIJING_DIFU_ID and stage5 != null:
		_hide_tooltip()
		stage5.pressed.emit()

func _on_mijing_mouse_entered(mijing_id: String) -> void:
	_show_mijing_tooltip(mijing_id)

func _on_mijing_mouse_exited(mijing_id: String) -> void:
	if _hovered_mijing_id != mijing_id:
		return
	_hovered_mijing_id = ""
	_hide_tooltip()

func _show_mijing_tooltip(mijing_id: String) -> void:
	if _stage_tooltips_suppressed:
		return
	_hovered_mijing_id = mijing_id
	_hovered_stage_key = ""
	_tooltip_request_id += 1
	var request_id := _tooltip_request_id
	var info: Dictionary = MIJING_INFO.get(mijing_id, {})
	_tooltip_name_label.text = str(info.get("stage_name", "未知秘境"))
	_tooltip_desc_label.text = str(info.get("stage_desc", "暂无说明。")) if _is_mijing_unlocked(mijing_id) else "等待探索……"
	_tooltip_power_label.text = _get_mijing_key_status_text(mijing_id) if _is_mijing_difficulty_unlocked(mijing_id) else _get_mijing_locked_message(mijing_id)
	
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.custom_minimum_size = Vector2.ZERO
	_tooltip_panel.position = Vector2(-10000, -10000)
	_tooltip_panel.modulate.a = 0.0
	_tooltip_panel.visible = true
	_tooltip_desc_label.size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	
	await get_tree().process_frame
	if request_id != _tooltip_request_id or _hovered_mijing_id != mijing_id:
		return
	var content_size := _tooltip_vbox.get_combined_minimum_size()
	var panel_size := content_size + Vector2(20, 16)
	_tooltip_panel.custom_minimum_size = panel_size
	_tooltip_panel.size = panel_size
	_tooltip_cached_size = panel_size
	_update_tooltip_position()
	
	await get_tree().process_frame
	if request_id != _tooltip_request_id or _hovered_mijing_id != mijing_id:
		return
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.15)
	_tooltip_panel.visible = true

func _show_stage_tooltip(stage_key: String) -> void:
	if _stage_tooltips_suppressed:
		return
	_hovered_mijing_id = ""
	_hovered_stage_key = stage_key
	if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
		_update_core_bonus_text()
	_tooltip_request_id += 1
	var request_id := _tooltip_request_id
	var info: Dictionary = STAGE_INFO.get(stage_key, {})
	_tooltip_name_label.text = str(info.get("stage_name", "未知关卡"))
	if not _is_stage_available(stage_key) or not _is_stage_unlocked(stage_key):
		_tooltip_desc_label.text = "等待探索……"
	else:
		_tooltip_desc_label.text = str(info.get("stage_desc", "暂无说明。"))
	if not _is_stage_available(stage_key):
		_tooltip_power_label.text = _build_locked_stage_message(stage_key)
	elif not _is_stage_unlocked(stage_key):
		_tooltip_power_label.text = _build_locked_stage_message(stage_key)
	else:
		var stage_id := str(info.get("stage_id", ""))
		if _selected_difficulty == Global.STAGE_DIFFICULTY_CORE:
			var recommended_power := Global.get_stage_recommended_power(stage_id, _selected_difficulty)
			_tooltip_power_label.text = "推荐修为：" + str(recommended_power)
		elif Global.can_enter_stage_difficulty(stage_id, _selected_difficulty):
			var recommended_power := Global.get_stage_recommended_power(stage_id, _selected_difficulty)
			_tooltip_power_label.text = "推荐修为：" + str(recommended_power)
		else:
			_tooltip_power_label.text = _build_locked_difficulty_message(stage_key)
	
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.custom_minimum_size = Vector2.ZERO
	_tooltip_panel.position = Vector2(-10000, -10000)
	_tooltip_panel.modulate.a = 0.0

	_tooltip_panel.visible = true
	_tooltip_desc_label.size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	
	# 先等一帧让控件完成布局，再根据最终尺寸计算位置，避免先显示后跳位的闪烁。
	await get_tree().process_frame
	if request_id != _tooltip_request_id:
		return
	if _hovered_stage_key != stage_key:
		return
	
	var content_size := _tooltip_vbox.get_combined_minimum_size()
	var panel_size := content_size + Vector2(20, 16)
	_tooltip_panel.custom_minimum_size = panel_size
	_tooltip_panel.size = panel_size
	_tooltip_cached_size = panel_size
	_update_tooltip_position()
	
	# 再等一帧，确保位置和尺寸都稳定后再真正显示出来。
	await get_tree().process_frame
	if request_id != _tooltip_request_id:
		return
	if _hovered_stage_key != stage_key:
		return
	# 渐入动画，打断上一次
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.15)
	_tooltip_panel.visible = true


func _hide_tooltip() -> void:
	_tooltip_request_id += 1
	_tooltip_cached_size = Vector2.ZERO
	_hovered_stage_key = ""
	_hovered_mijing_id = ""
	if _tooltip_panel != null and _tooltip_panel.visible:
		if _tooltip_tween and _tooltip_tween.is_valid():
			_tooltip_tween.kill()
		_tooltip_tween = create_tween()
		_tooltip_tween.tween_property(_tooltip_panel, "modulate:a", 0.0, 0.12)
		_tooltip_tween.tween_callback(func(): _tooltip_panel.visible = false)

func _on_stage_mouse_entered(stage_key: String) -> void:
	_show_stage_tooltip(stage_key)

func _on_stage_mouse_exited(stage_key: String) -> void:
	if _hovered_stage_key != stage_key:
		return
	_hovered_stage_key = ""
	_hide_tooltip()

func _on_rect_1_mouse_entered() -> void:
	_on_stage_mouse_entered("stage1")

func _on_rect_1_mouse_exited() -> void:
	_on_stage_mouse_exited("stage1")

func _on_rect_2_mouse_entered() -> void:
	_on_stage_mouse_entered("stage2")

func _on_rect_2_mouse_exited() -> void:
	_on_stage_mouse_exited("stage2")

func _on_rect_3_mouse_entered() -> void:
	_on_stage_mouse_entered("stage3")

func _on_rect_3_mouse_exited() -> void:
	_on_stage_mouse_exited("stage3")

func _on_rect_4_mouse_entered() -> void:
	_on_stage_mouse_entered("stage4")

func _on_rect_4_mouse_exited() -> void:
	_on_stage_mouse_exited("stage4")

func _on_rect_5_mouse_entered() -> void:
	_on_stage_mouse_entered("stage5")

func _on_rect_5_mouse_exited() -> void:
	_on_stage_mouse_exited("stage5")

func _on_rect_6_mouse_entered() -> void:
	_on_stage_mouse_entered("stage6")

func _on_rect_6_mouse_exited() -> void:
	_on_stage_mouse_exited("stage6")

func _on_rect_7_mouse_entered() -> void:
	_on_stage_mouse_entered("stage7")

func _on_rect_7_mouse_exited() -> void:
	_on_stage_mouse_exited("stage7")

func _on_rect_8_mouse_entered() -> void:
	_on_stage_mouse_entered("stage8")

func _on_rect_8_mouse_exited() -> void:
	_on_stage_mouse_exited("stage8")
