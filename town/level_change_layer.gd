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

# 这 4 个按钮按你的要求保留为 `@export`，
# 后续你可以直接在场景里拖节点进来、换样式、换位置。
# 这里脚本只负责：
# 1. 监听它们的点击；
# 2. 记录当前想进入的难度；
# 3. 刷新悬浮提示框里的推荐修为。
@export var shallow_button: Button
@export var deep_button: Button
@export var core_button: Button
@export var poetry_button: Button

const TOOLTIP_FONT_SIZE := 24
const MOUSE_OFFSET := Vector2(34, 24)
const TOOLTIP_DESC_WIDTH := 260.0

# 关卡说明数据。
# 这里把“关卡名”和“简介”写死在脚本里，
# 这样即使场景节点还没补全，也能先把功能跑起来。
const STAGE_INFO := {
	"stage1": {
		"stage_id": "peach_grove",
		"stage_name": "桃林",
		"stage_desc": "桃雾缭绕，妖气初现，适合先熟悉衍阵中的战斗节奏。",
		"available": true
	},
	"stage2": {
		"stage_id": "ruin",
		"stage_name": "废墟",
		"stage_desc": "残垣断壁间阴物游荡，远程与突进敌人开始形成压力。",
		"available": true
	},
	"stage3": {
		"stage_id": "cave",
		"stage_name": "洞窟",
		"stage_desc": "幽深洞窟中甲石与石人更难缠，需要更稳定的正面强度。",
		"available": true
	},
	"stage4": {
		"stage_id": "forest",
		"stage_name": "森林",
		"stage_desc": "古林灵物躁动，怪群更密更快，对持续作战能力要求更高。",
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
var _difficulty_button_map: Dictionary = {}
var _hovered_stage_key: String = ""
var _tooltip_panel: Panel = null
var _tooltip_vbox: VBoxContainer = null
var _tooltip_name_label: Label = null
var _tooltip_desc_label: Label = null
var _tooltip_power_label: Label = null
var _tooltip_font: Font = null
var _tooltip_request_id: int = 0
var _selected_difficulty: String = Global.STAGE_DIFFICULTY_SHALLOW

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
	
	if ResourceLoader.exists("res://AssetBundle/Uranus_Pixel_11Px.ttf"):
		_tooltip_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	
	# 原来这里的 `stage1~stage8` 会在鼠标悬浮时当作“跟着鼠标跑的提示按钮”。
	# 现在需求改成“背包同款提示框”，
	# 所以这些按钮只保留为“信号桥接器”，本体不再负责显示提示内容。
	for button in _stage_buttons.values():
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.visible = false
			button.modulate.a = 0.0
	
	_create_tooltip_panel()
	_connect_rect_input_events()
	_connect_difficulty_buttons()
	prepare_for_open()

func _process(_delta: float) -> void:
	if _hovered_stage_key.is_empty():
		return
	if _tooltip_panel == null or not _tooltip_panel.visible:
		return
	_update_tooltip_position()

# 每次重新打开关卡层时，重置悬浮态和难度按钮显示。
func prepare_for_open() -> void:
	_hovered_stage_key = ""
	_hide_tooltip()
	_selected_difficulty = Global.validate_stage_difficulty_id(Global.selected_stage_difficulty)
	_apply_difficulty_button_visual()

func reset_stage_tooltip_state() -> void:
	prepare_for_open()

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

func _on_difficulty_button_pressed(difficulty_id: String) -> void:
	_selected_difficulty = Global.validate_stage_difficulty_id(difficulty_id)
	Global.set_selected_stage_difficulty(_selected_difficulty)
	_apply_difficulty_button_visual()
	if not _hovered_stage_key.is_empty():
		_show_stage_tooltip(_hovered_stage_key)

# 给当前选中的难度按钮一个直观的高亮。
# 这里只改透明度，不改你的按钮文字、贴图和主题，
# 这样你后面自己配场景时更自由。
func _apply_difficulty_button_visual() -> void:
	for difficulty_id in _difficulty_button_map.keys():
		var button := _difficulty_button_map[difficulty_id] as Button
		if button == null:
			continue
		button.modulate = Color(1, 1, 1, 1) if difficulty_id == _selected_difficulty else Color(0.7, 0.7, 0.7, 0.9)

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
	_tooltip_panel.z_index = 100
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

func _update_tooltip_position() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var tooltip_pos := mouse_pos + MOUSE_OFFSET
	var viewport_size := get_viewport().get_visible_rect().size
	if tooltip_pos.x + _tooltip_panel.size.x > viewport_size.x:
		tooltip_pos.x = viewport_size.x - _tooltip_panel.size.x - 10
	if tooltip_pos.y + _tooltip_panel.size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - _tooltip_panel.size.y - 10
	_tooltip_panel.global_position = tooltip_pos

func _show_tip(message: String) -> void:
	var current_scene = get_tree().current_scene
	if current_scene != null and "tip" in current_scene and current_scene.tip != null:
		if current_scene.tip.has_method("start_animation"):
			current_scene.tip.start_animation(message, 0.5)

func _build_locked_difficulty_message(stage_key: String) -> String:
	var info := STAGE_INFO.get(stage_key, {})
	var stage_name := str(info.get("stage_name", "该关卡"))
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
	var info := STAGE_INFO.get(stage_key, {})
	if not bool(info.get("available", false)):
		_show_tip("当前测试版本该关卡暂未开放")
		return
	var stage_id := str(info.get("stage_id", ""))
	if not Global.can_enter_stage_difficulty(stage_id, _selected_difficulty):
		_show_tip(_build_locked_difficulty_message(stage_key))
		return
	Global.set_selected_stage_difficulty(_selected_difficulty)
	var button := _stage_buttons.get(stage_key) as Button
	if button != null:
		button.pressed.emit()

func _show_stage_tooltip(stage_key: String) -> void:
	_hovered_stage_key = stage_key
	_tooltip_request_id += 1
	var request_id := _tooltip_request_id
	var info := STAGE_INFO.get(stage_key, {})
	_tooltip_name_label.text = str(info.get("stage_name", "未知关卡"))
	_tooltip_desc_label.text = str(info.get("stage_desc", "暂无说明。"))
	if bool(info.get("available", false)):
		var stage_id := str(info.get("stage_id", ""))
		var recommended_power := Global.get_stage_recommended_power(stage_id, _selected_difficulty)
		_tooltip_power_label.text = "推荐修为：" + str(recommended_power)
	else:
		_tooltip_power_label.text = "推荐修为：--"
	
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.custom_minimum_size = Vector2.ZERO
	_tooltip_panel.global_position = Vector2(-10000, -10000)
	_tooltip_panel.visible = true
	_tooltip_desc_label.size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	_tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_DESC_WIDTH, 0)
	
	await get_tree().process_frame
	await get_tree().process_frame
	if request_id != _tooltip_request_id:
		return
	if _hovered_stage_key != stage_key:
		return
	var content_size := _tooltip_vbox.get_combined_minimum_size()
	var panel_size := content_size + Vector2(20, 16)
	_tooltip_panel.custom_minimum_size = panel_size
	_tooltip_panel.size = panel_size
	_update_tooltip_position()
	_tooltip_panel.visible = true

func _hide_tooltip() -> void:
	_tooltip_request_id += 1
	if _tooltip_panel != null:
		_tooltip_panel.visible = false

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
