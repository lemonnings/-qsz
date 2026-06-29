extends CanvasLayer
class_name BattleCanvasLayer

const ZHUAZHUAJUCHUI_SCRIPT = preload("res://Script/skill/zhuazhuajuchui.gd")

# ============== UI 组件引用 ==============
@export var hp_bar: ProgressBar
@export var sheild_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var map_mechanism_bar: ProgressBar
@export var hp_num: Label
@export var score_label: Label
@export var gameover_label: Label
@export var victory_label: Label
@export var victory_summary_container: VBoxContainer
@export var victory_time_label: RichTextLabel
@export var victory_score_label: RichTextLabel
@export var victory_kill_label: RichTextLabel
@export var victory_total_label: RichTextLabel
@export var attr_label: RichTextLabel

@export var stop_layer: CanvasLayer
@export var setting_layer: Panel
@export var warning_node: Control
@export var buff_box: HBoxContainer
var warning_active: bool = false

@export var now_time: Label
@export var now_lv: Label
@export var stop_button: Button

@export var dialogue_container: VBoxContainer

# 技能图标
@export var skill1: TextureButton
@export var skill2: TextureButton
@export var skill3: TextureButton
@export var skill4: TextureButton
@export var skill5: TextureButton
@export var skill6: TextureButton
@export var skill7: TextureButton
@export var skill8: TextureButton
@export var skill9: TextureButton
@export var skill10: TextureButton
@export var skill11: TextureButton
@export var skill12: TextureButton
@export var skill13: TextureButton
@export var skill14: TextureButton
@export var skill15: TextureButton
@export var skill16: TextureButton
@export var skill17: TextureButton
@export var skill18: TextureButton
@export var skill19: TextureButton
@export var skill20: TextureButton
@export var skill21: TextureButton

# 主动技能
@export var active1: TextureButton
@export var active2: TextureButton
@export var active3: TextureButton

# 升级选择UI
@onready var lv_up_change: Control = $LevelUpChange
@onready var lv_up_change_b1: Button = lv_up_change.get_node("LvUpChange1Button")
@onready var lv_up_change_b2: Button = lv_up_change.get_node("LvUpChange2Button")
@onready var lv_up_change_b3: Button = lv_up_change.get_node("LvUpChange3Button")
@onready var lv_up_exit_button: Button = _find_level_up_exit_button()

@export var lv_up_start_button: Button
@onready var instant_level_up_button_label: Label = lv_up_change.get_node("manual_level_up_label")
@onready var instant_level_up_button: CheckButton = lv_up_change.get_node("manual_level_up")

@export var speed_change_button: Button

# 速度切换配置
const SPEED_VALUES: Array = [1.0, 1.2, 1.4]
const SPEED_NAMES: Array = ["正常", "快速", "高速"]
const SPEED_ICON_PATHS: Array = [
	"res://AssetBundle/Sprites/Sprite sheets/Icons/speed_change1.png",
	"res://AssetBundle/Sprites/Sprite sheets/Icons/speed_change2.png",
	"res://AssetBundle/Sprites/Sprite sheets/Icons/speed_change3.png"
]
var _current_speed_index: int = 0

# 战斗内Tips节点（用于显示刷新次数不足等提示）
@export var lv_up_tip: Panel
@export var spell: Control

@onready var refresh_num_label: RichTextLabel = lv_up_change.get_node("LevelUpChange_Panel#RefreshNum")
@onready var lock_num_label: RichTextLabel = lv_up_change.get_node("LevelUpChange_Panel#LockNum")
@onready var ban_num_label: RichTextLabel = lv_up_change.get_node("LevelUpChange_Panel#BanNum")
@onready var refresh_all_button: Button = lv_up_change.get_node_or_null("LevelUpChange_Panel#RefreshNum/RefreshButton") as Button
# 刷新次数配置（每达REFRESH_LEVEL_STEP级，额外获得REFRESH_BONUS_PER_STEP次刷新）
const REFRESH_LEVEL_STEP: int = 3
const REFRESH_BONUS_PER_STEP: int = 1
# 锁定次数配置（每达LOCK_LEVEL_STEP级，额外获得LOCK_BONUS_PER_STEP次锁定）
const LOCK_LEVEL_STEP: int = 5
const LOCK_BONUS_PER_STEP: int = 1
const BAN_HOLD_SECONDS: float = 1.0
const FAZE_TOOLTIP_LAYER: int = 10000
var _ban_hold_button_id: int = 0
var _ban_hold_elapsed: float = 0.0
var _ban_hold_active: bool = false
var _ban_hold_completed: bool = false
var _last_refresh_display_text: String = ""
var _last_lock_display_text: String = ""
var _last_ban_display_text: String = ""
var _faze_base_parent: Node = null
var _faze_base_index: int = -1
var _faze_overlay_layer: CanvasLayer = null

# 纹章相关
@export var emblem1: TextureRect
@export var emblem1_panel: Panel
@export var emblem1_detail: RichTextLabel
@export var emblem2: TextureRect
@export var emblem2_panel: Panel
@export var emblem2_detail: RichTextLabel
@export var emblem3: TextureRect
@export var emblem3_panel: Panel
@export var emblem3_detail: RichTextLabel
@export var emblem4: TextureRect
@export var emblem4_panel: Panel
@export var emblem4_detail: RichTextLabel
@export var emblem5: TextureRect
@export var emblem5_panel: Panel
@export var emblem5_detail: RichTextLabel
@export var emblem6: TextureRect
@export var emblem6_panel: Panel
@export var emblem6_detail: RichTextLabel
@export var emblem7: TextureRect
@export var emblem7_panel: Panel
@export var emblem7_detail: RichTextLabel
@export var emblem8: TextureRect
@export var emblem8_panel: Panel
@export var emblem8_detail: RichTextLabel

# 法则标签
@export var faze: HBoxContainer
@export var faze1: TextureRect
@export var faze1_panel: Panel
@export var faze1_detail: RichTextLabel
@export var faze1_level: Label
@export var faze2: TextureRect
@export var faze2_panel: Panel
@export var faze2_detail: RichTextLabel
@export var faze2_level: Label
@export var faze3: TextureRect
@export var faze3_panel: Panel
@export var faze3_detail: RichTextLabel
@export var faze3_level: Label
@export var faze4: TextureRect
@export var faze4_panel: Panel
@export var faze4_detail: RichTextLabel
@export var faze4_level: Label
@export var faze5: TextureRect
@export var faze5_panel: Panel
@export var faze5_detail: RichTextLabel
@export var faze5_level: Label
@export var faze6: TextureRect
@export var faze6_panel: Panel
@export var faze6_detail: RichTextLabel
@export var faze6_level: Label
@export var faze7: TextureRect
@export var faze7_panel: Panel
@export var faze7_detail: RichTextLabel
@export var faze7_level: Label
@export var faze8: TextureRect
@export var faze8_panel: Panel
@export var faze8_detail: RichTextLabel
@export var faze8_level: Label
@export var faze9: TextureRect
@export var faze9_panel: Panel
@export var faze9_detail: RichTextLabel
@export var faze9_level: Label
@export var faze10: TextureRect
@export var faze10_panel: Panel
@export var faze10_detail: RichTextLabel
@export var faze10_level: Label
@export var faze_icon_paths: Dictionary = {
	"blood": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_blood.png",
	"sword": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_sword.png",
	"thunder": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_thunder.png",
	"heal": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_heal.png",
	"summon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_summon.png",
	"shield": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_sheild.png",
	"destroy": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_destory.png",
	"life": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_life.png",
	"bullet": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_bullet.png",
	"wide": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_wide.png",
	"wind": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_wind.png",
	"liushi": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_liushi.png",
	"treasure": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_treasure.png",
	"deep": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/buff_chenyuan.png",
	"fire": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_fire.png",
	"bagua": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_bagua.png",
	"chaos": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_chaos.png"
}

# 技能标签
@export var skill_label1: RichTextLabel
@export var active_skill_label: RichTextLabel

# ---- 提示框动画 tween 追踪（防快速切换闪烁） ----
var _skill_label_tween: Tween = null
var _active_skill_tween: Tween = null
var _emblem_tweens: Dictionary = {} # key = emblem_index
var _manual_level_up_shop_hidden: bool = false
var _manual_level_up_shop_tween: Tween = null
var _shop_restore_instant_level_up_button_visible: bool = false
var _shop_restore_instant_level_up_label_visible: bool = false
var victory_summary_data: Dictionary = {}

# ============== 管理器引用 ==
var level_up_manager: LevelUpManager
var emblem_manager: EmblemManager
var buff_manager: BuffManager
var faze_icons: Array
var faze_panels: Array
var faze_details: Array
var faze_level_labels: Array
var faze_slot_laws: Array

# ============== 咏唱魔法 UI 状态 ==============
var _spell_icon: TextureRect = null
var _spell_name_label: Label = null
var _spell_chant_bar: ProgressBar = null
var _spell_status_label: Label = null
var _spell_time_label: Label = null
var _spell_chant_active: bool = false
var _spell_chant_total_time: float = 0.0
var _spell_chant_elapsed: float = 0.0
var _spell_chant_timer: Timer = null
var _defer_level_up_until_chant_end: bool = false
var _chant_level_up_resume_id: int = 0

const MOBILE_SKILL_LONG_PRESS_TIME: float = 0.45
const MOBILE_SKILL_AIM_DEADZONE: float = 18.0
const MOBILE_SKILL_AIM_SCREEN_RANGE: float = 90.0
const MOBILE_SKILL_AIM_WORLD_RANGE: float = 180.0
const MOBILE_POINT_SKILL_AIM_SCREEN_RANGE: float = 260.0
const MOBILE_POINT_SKILL_AIM_WORLD_RANGE: float = 252.0
const MOBILE_POINT_SKILL_EFFECT_SCALE: float = 1.1
var _mobile_skill_touch_active: bool = false
var _mobile_skill_touch_index: int = -1
var _mobile_skill_slot: String = ""
var _mobile_skill_name: String = ""
var _mobile_skill_icon: TextureButton = null
var _mobile_skill_press_position: Vector2 = Vector2.ZERO
var _mobile_skill_last_position: Vector2 = Vector2.ZERO
var _mobile_skill_press_elapsed: float = 0.0
var _mobile_skill_long_press_shown: bool = false
var _mobile_skill_aim_started: bool = false
var _mobile_skill_cast_consumed: bool = false
var _mobile_skill_gui_position_is_local: bool = false
var _mobile_skill_indicator: Node = null
var _mobile_chant_aim_active: bool = false
var _mobile_chant_aim_slot: String = ""
var _mobile_chant_aim_skill: String = ""
var _mobile_chant_aim_icon: TextureButton = null
var _mobile_chant_aim_press_position: Vector2 = Vector2.ZERO
var _mobile_chant_aim_last_position: Vector2 = Vector2.ZERO
var _mobile_skill_point_aim_origin: Vector2 = Vector2.INF
var _mobile_chant_point_aim_origin: Vector2 = Vector2.INF

# ============== 信号 ==============
@warning_ignore("unused_signal")
signal refresh_button_pressed(button_id: int)
@warning_ignore("unused_signal")
signal skill_icon_hovered(skill_id: int, is_hovered: bool)
@warning_ignore("unused_signal")
signal victory_evaluation_finished

# ============== 初始化 ==============
var teammate_dialogue_mgr: TeammateDialogueManager = null
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_managers()
	_init_faze_overlay_layer()
	_connect_signals()
	if not Global.input_device_mode_changed.is_connected(_on_input_device_mode_changed):
		Global.input_device_mode_changed.connect(_on_input_device_mode_changed)
	_set_warning_mouse_filter_ignore()
	_init_active_skills()
	_init_faze_ui()
	_refresh_faze_ui()
	_init_level_up_exit_button()
	_init_lv_up_start_button()
	_init_speed_change_button()
	_init_attr_hover_ui()
	victory_summary_container.visible = false
	_raise_tooltip_z_index()
	_init_spell_ui()
	_init_stop_layer()

func _init_attr_hover_ui() -> void:
	if attr_label:
		attr_label.process_mode = Node.PROCESS_MODE_ALWAYS
	var attr_button := get_node_or_null("AttrButton")
	if attr_button:
		attr_button.process_mode = Node.PROCESS_MODE_ALWAYS
	var analysis_button := get_node_or_null("AnalysisButton")
	if analysis_button:
		analysis_button.process_mode = Node.PROCESS_MODE_ALWAYS

func _init_managers() -> void:
	# 初始化升级管理器
	level_up_manager = LevelUpManager.new()
	add_child(level_up_manager)
	# todo
	var skill_nodes_array: Array[TextureButton] = [skill1, skill2, skill3, skill4, skill5, skill6, skill7, skill8, skill9, skill10, skill11, skill12, skill13, skill14, skill15, skill16, skill17, skill18, skill19, skill20, skill21]
	level_up_manager.initialize(self , lv_up_change, lv_up_change_b1, lv_up_change_b2, lv_up_change_b3, self , skill_nodes_array)
	
	# 连接刷新按钮信号
	_connect_refresh_buttons()
	# 连接锁定按钮信号
	_connect_lock_buttons()
	
	# 初始化纹章管理器
	emblem_manager = EmblemManager.new()
	add_child(emblem_manager)
	emblem_manager.setup_emblem_container(buff_box)
	var icons := [emblem1, emblem2, emblem3, emblem4, emblem5, emblem6, emblem7, emblem8]
	var panels := [emblem1_panel, emblem2_panel, emblem3_panel, emblem4_panel, emblem5_panel, emblem6_panel, emblem7_panel, emblem8_panel]
	var details := [emblem1_detail, emblem2_detail, emblem3_detail, emblem4_detail, emblem5_detail, emblem6_detail, emblem7_detail, emblem8_detail]
	emblem_manager.setup_emblem_ui(icons, panels, details)
	
	buff_manager = BuffManager.new()
	add_child(buff_manager)
	buff_manager.setup_buff_container(buff_box)
	
	# 连接纹章鼠标事件信号
	_connect_emblem_signals(icons)
	
	# 连接技能图标鼠标事件信号
	_connect_skill_icon_signals()
	
	# 连接主动技能图标鼠标事件信号
	_connect_active_skill_signals()

	# 初始化队友对话管理器
	teammate_dialogue_mgr = TeammateDialogueManager.new()
	add_child(teammate_dialogue_mgr)
	teammate_dialogue_mgr.initialize(dialogue_container)

func _init_faze_ui() -> void:
	faze_icons = [faze1, faze2, faze3, faze4, faze5, faze6, faze7, faze8, faze9, faze10]
	faze_panels = [faze1_panel, faze2_panel, faze3_panel, faze4_panel, faze5_panel, faze6_panel, faze7_panel, faze8_panel, faze9_panel, faze10_panel]
	faze_details = [faze1_detail, faze2_detail, faze3_detail, faze4_detail, faze5_detail, faze6_detail, faze7_detail, faze8_detail, faze9_detail, faze10_detail]
	faze_level_labels = [faze1_level, faze2_level, faze3_level, faze4_level, faze5_level, faze6_level, faze7_level, faze8_level, faze9_level, faze10_level]
	faze_slot_laws = []
	var tooltip_style := _create_faze_tooltip_style()
	for i in range(faze_icons.size()):
		var icon = faze_icons[i]
		var panel = faze_panels[i]
		var detail = faze_details[i]
		var slot_index = i + 1
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.mouse_entered.connect(_on_faze_mouse_entered.bind(slot_index))
		icon.mouse_exited.connect(_on_faze_mouse_exited.bind(slot_index))
		if panel:
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_theme_stylebox_override("panel", tooltip_style)
		if detail:
			detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_faze_to_overlay_layer()

func _create_faze_tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.188235, 0.101961, 0.0, 0.82)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style

func _init_faze_overlay_layer() -> void:
	if _faze_overlay_layer != null and is_instance_valid(_faze_overlay_layer):
		return
	if faze == null:
		return
	_faze_base_parent = faze.get_parent()
	_faze_base_index = faze.get_index()
	_faze_overlay_layer = CanvasLayer.new()
	_faze_overlay_layer.name = "FazeTooltipLayer"
	_faze_overlay_layer.layer = FAZE_TOOLTIP_LAYER
	_faze_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_faze_overlay_layer)

func _move_faze_to_overlay_layer() -> void:
	if faze == null:
		return
	_init_faze_overlay_layer()
	if _faze_overlay_layer == null:
		return
	if faze.get_parent() == _faze_overlay_layer:
		return
	var current_global_position := faze.global_position
	var parent := faze.get_parent()
	if parent:
		parent.remove_child(faze)
	_faze_overlay_layer.add_child(faze)
	faze.global_position = current_global_position
	faze.process_mode = Node.PROCESS_MODE_ALWAYS

# 提升所有提示框节点的z_index，使其在升级选择界面之上可见
# z_as_relative=false 使z_index成为CanvasLayer内的绝对值，不受父节点链影响
func _raise_tooltip_z_index() -> void:
	const TOOLTIP_Z = 1000
	if _faze_overlay_layer != null and is_instance_valid(_faze_overlay_layer):
		_faze_overlay_layer.layer = FAZE_TOOLTIP_LAYER
	if faze:
		faze.z_index = TOOLTIP_Z
		faze.z_as_relative = false
	# 法则提示框
	for panel in faze_panels:
		if panel:
			panel.z_index = TOOLTIP_Z
			panel.z_as_relative = false
	for detail in faze_details:
		if detail:
			detail.z_index = TOOLTIP_Z
			detail.z_as_relative = false
	# 纹章提示框
	var emblem_panels_arr = [emblem1_panel, emblem2_panel, emblem3_panel, emblem4_panel, emblem5_panel, emblem6_panel, emblem7_panel, emblem8_panel]
	var emblem_details_arr = [emblem1_detail, emblem2_detail, emblem3_detail, emblem4_detail, emblem5_detail, emblem6_detail, emblem7_detail, emblem8_detail]
	for panel in emblem_panels_arr:
		if panel:
			panel.z_index = TOOLTIP_Z
			panel.z_as_relative = false
	for detail in emblem_details_arr:
		if detail:
			detail.z_index = TOOLTIP_Z
			detail.z_as_relative = false
	# 技能提示标签
	if skill_label1:
		skill_label1.z_index = TOOLTIP_Z
		skill_label1.z_as_relative = false
	if active_skill_label:
		active_skill_label.z_index = TOOLTIP_Z
		active_skill_label.z_as_relative = false

func _get_faze_icon_texture(law_id: String) -> Texture2D:
	var icon_path = faze_icon_paths[law_id]
	return load(icon_path)

func _refresh_faze_ui() -> void:
	var laws = _get_faze_laws()
	laws.sort_custom(_sort_faze_laws)
	faze_slot_laws = []
	for i in range(faze_icons.size()):
		faze_slot_laws.append(null)
		var icon = faze_icons[i]
		var panel = faze_panels[i]
		var detail = faze_details[i]
		var level_label = faze_level_labels[i]
		icon.visible = false
		icon.texture = null
		panel.visible = false
		detail.visible = false
		detail.text = ""
		level_label.visible = false
		level_label.text = ""
	var slot_index = 0
	for law in laws:
		if slot_index >= faze_icons.size():
			break
		var icon = faze_icons[slot_index]
		var panel = faze_panels[slot_index]
		var detail = faze_details[slot_index]
		var level_label = faze_level_labels[slot_index]
		icon.visible = true
		icon.texture = _get_faze_icon_texture(law["id"])
		panel.visible = false
		detail.visible = false
		detail.text = law["detail"]
		level_label.visible = true
		level_label.text = str(law["level"])
		_update_faze_panel_size(panel, detail)
		faze_slot_laws[slot_index] = law
		slot_index += 1
	_sync_bullet_faze_buff()

func refresh_faze_ui() -> void:
	_refresh_faze_ui()

func _sync_bullet_faze_buff() -> void:
	var bullet_level = PC.faze_bullet_level
	if bullet_level < 7:
		if BuffManager.has_buff("barrage_charge"):
			Global.emit_signal("buff_removed", "barrage_charge")
		return
	var charge_count = Faze.bullet_hit_count
	if charge_count > 0:
		if BuffManager.has_buff("barrage_charge"):
			Global.emit_signal("buff_stack_changed", "barrage_charge", charge_count)
		else:
			Global.emit_signal("buff_added", "barrage_charge", -1, charge_count)
	else:
		if BuffManager.has_buff("barrage_charge"):
			Global.emit_signal("buff_removed", "barrage_charge")

func _get_faze_laws() -> Array:
	var laws: Array = []
	var blood_level = PC.faze_blood_level
	if blood_level > 0:
		var blood_detail = _build_bath_blood_detail(blood_level)
		laws.append({"id": "blood", "name": "浴血法则", "level": blood_level, "detail": blood_detail})
	var sword_level = PC.faze_sword_level
	if sword_level > 0:
		var sword_detail = _build_sword_faze_detail(sword_level)
		laws.append({"id": "sword", "name": "刀剑法则", "level": sword_level, "detail": sword_detail})
	var thunder_level = PC.faze_thunder_level
	if thunder_level > 0:
		var thunder_detail = _build_thunder_faze_detail(thunder_level)
		laws.append({"id": "thunder", "name": "鸣雷法则", "level": thunder_level, "detail": thunder_detail})
	var heal_level = PC.faze_heal_level
	if heal_level > 0:
		var heal_detail = _build_heal_faze_detail(heal_level)
		laws.append({"id": "heal", "name": "愈疗法则", "level": heal_level, "detail": heal_detail})
	var summon_level = PC.faze_summon_level
	if summon_level > 0:
		var summon_detail = _build_summon_faze_detail(summon_level)
		laws.append({"id": "summon", "name": "御灵法则", "level": summon_level, "detail": summon_detail})
	var shield_level = PC.faze_shield_level
	if shield_level > 0:
		var shield_detail = _build_shield_faze_detail(shield_level)
		laws.append({"id": "shield", "name": "护佑法则", "level": shield_level, "detail": shield_detail})
	var fire_level = PC.faze_fire_level
	if fire_level > 0:
		var fire_detail = _build_fire_faze_detail(fire_level)
		laws.append({"id": "fire", "name": "炽焰法则", "level": fire_level, "detail": fire_detail})
	var destroy_level = PC.faze_destroy_level
	if destroy_level > 0:
		var destroy_detail = _build_destroy_faze_detail(destroy_level)
		laws.append({"id": "destroy", "name": "破坏法则", "level": destroy_level, "detail": destroy_detail})
	var life_level = PC.faze_life_level
	if life_level > 0:
		var life_detail = _build_life_faze_detail(life_level)
		laws.append({"id": "life", "name": "生灵法则", "level": life_level, "detail": life_detail})
	var bullet_level = PC.faze_bullet_level
	if bullet_level > 0:
		var bullet_detail = _build_bullet_faze_detail(bullet_level)
		laws.append({"id": "bullet", "name": "弹雨法则", "level": bullet_level, "detail": bullet_detail})
	var wind_level = PC.faze_wind_level
	if wind_level > 0:
		var wind_detail = _build_wind_faze_detail(wind_level)
		laws.append({"id": "wind", "name": "啸风法则", "level": wind_level, "detail": wind_detail})
	var wide_level = PC.faze_wide_level
	if wide_level > 0:
		var wide_detail = _build_wide_faze_detail(wide_level)
		laws.append({"id": "wide", "name": "广域法则", "level": wide_level, "detail": wide_detail})
	var bagua_level = PC.faze_bagua_level
	if bagua_level > 0:
		var bagua_detail = _build_bagua_faze_detail(bagua_level)
		laws.append({"id": "bagua", "name": "八卦法则", "level": bagua_level, "detail": bagua_detail})
	var sixsense_level = PC.faze_sixsense_level
	if sixsense_level > 0:
		var sixsense_detail = _build_sixsense_faze_detail(sixsense_level)
		laws.append({"id": "liushi", "name": "六识法则", "level": sixsense_level, "detail": sixsense_detail})
	var treasure_level = PC.faze_treasure_level
	if treasure_level > 0:
		var treasure_detail = _build_treasure_faze_detail(treasure_level)
		laws.append({"id": "treasure", "name": "宝器法则", "level": treasure_level, "detail": treasure_detail})
	var deep_level = PC.faze_deep_level
	if deep_level > 0:
		var deep_detail = _build_deep_faze_detail(deep_level)
		laws.append({"id": "deep", "name": "沉渊法则", "level": deep_level, "detail": deep_detail})
	var chaos_level = Faze.get_current_chaos_level()
	if chaos_level > 0:
		var chaos_detail = _build_chaos_faze_detail(chaos_level)
		laws.append({"id": "chaos", "name": "混沌法则", "level": chaos_level, "detail": chaos_detail})
	return laws

func _build_simple_faze_detail(law_name: String, level: int) -> String:
	var text = _build_law_title(law_name) + "\n"
	text += "当前层数：" + str(level)
	return text

func _build_sixsense_faze_detail(level: int) -> String:
	var tiers = [2, 3, 4, 5, 6]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("六识法则"))
	lines.append("当前倍率：" + str(Faze.get_sixsense_multiplier(level)) + "x")
	lines.append(_format_faze_line(level, current_tier, 2, "2阶：六识系领悟加成的属性提升至1.2倍"))
	lines.append(_format_faze_line(level, current_tier, 3, "3阶：六识系领悟加成的属性提升至1.6倍"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：六识系领悟加成的属性提升至2.4倍"))
	lines.append(_format_faze_line(level, current_tier, 5, "5阶：六识系领悟加成的属性提升至4倍"))
	lines.append(_format_faze_line(level, current_tier, 6, "6阶：六识系领悟加成的属性提升至8倍"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_fire_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("炽焰法则"))
	lines.append(_color_owned_weapons("炽焰系武器：赤曜，离火诀，爆炎诀"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：炽焰系武器伤害提升 30%，燃烧伤害提升 50%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：燃烧伤害与范围再次提升 50%，燃烧持续时间 +1 秒"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：炽焰系武器伤害再次提升 60%，燃烧效果对精英、首领造成 5 倍伤害"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：燃烧伤害再次提升 120%，燃烧范围再次提升 50%，燃烧效果对精英、首领造成 10 倍伤害"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：炽焰系武器伤害、燃烧伤害再次提升 120%，燃烧效果对精英、首领造成 20 倍伤害"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_law_title(law_name: String) -> String:
	return "[font_size=24]" + law_name + "[/font_size]"

# 武器中文名 → reward key 映射。兼容 reward.csv 原始 ID 与运行时规范化 ID。
const _WEAPON_REWARD_KEYS: Dictionary = {
	"剑气诀": ["Swordqi", "SwordQi"],
	"饮血刀": ["Bloodboardsword", "BloodBoardSword"],
	"乾坤双剑": ["Qiankun"],
	"赤曜": ["Riyan"],
	"离火诀": ["Ringfire", "RingFire"],
	"爆炎诀": ["Moyan"],
	"冰刺术": ["Ice"],
	"天雷破": ["Thunderbreak", "ThunderBreak"],
	"光弹": ["Lightbullet", "LightBullet"],
	"坎水诀": ["Water"],
	"圣光术": ["Holylight", "HolyLight"],
	"震雷诀": ["Thunder"],
	"玄武盾": ["Xuanwu"],
	"艮山诀": ["Genshan"],
	"巽风诀": ["Xunfeng"],
	"仙枝": ["Branch"],
	"风龙杖": ["Dragonwind", "DragonWind"],
	"血气波": ["Bloodwave"],
	"兑泽诀": ["Duize"],
	"气功波": ["Qigong", "qigong"],
	"爪爪巨锤": ["Zhuazhuajuchui", "zhuazhuajuchui"],
}

# 将"系武器：武器A，武器B，武器C"格式中已拥有的武器名标绿
func _color_owned_weapons(weapon_line: String) -> String:
	# 找到冒号分割点
	var colon_pos = weapon_line.find("：")
	if colon_pos < 0:
		return weapon_line
	var prefix = weapon_line.left(colon_pos + "：".length())
	var weapon_str = weapon_line.substr(colon_pos + "：".length())
	
	# 按"，"分割武器名
	var weapon_names = weapon_str.split("，")
	var result = prefix
	for i in range(weapon_names.size()):
		var name = weapon_names[i]
		var base_name = name.replace("（进化）", "")
		if _has_owned_weapon(base_name):
			result += "[color=green]" + name + "[/color]"
		else:
			result += name
		if i < weapon_names.size() - 1:
			result += "，"
	return result

func _has_owned_weapon(weapon_name: String) -> bool:
	var reward_keys: Array = _WEAPON_REWARD_KEYS.get(weapon_name, [])
	var selected_lookup: Dictionary = {}
	for selected_id in PC.selected_rewards:
		selected_lookup[str(selected_id).to_lower()] = true
	for reward_key in reward_keys:
		if selected_lookup.has(str(reward_key).to_lower()):
			return true
	return false

func _build_bath_blood_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("浴血法则"))
	lines.append(_color_owned_weapons("浴血系武器：饮血刀，血气波"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：每 4 秒或受伤后（内置 2 秒冷却），对周围敌人发出一次震击，被击中的敌人受到 100% 攻击的伤害，自身获得 2.5% 最大体力的护盾，持续 4 秒"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：震击伤害提升至 200% 攻击，震击对精英，首领造成的伤害提升 200%，获得护盾量提升至 3% 最大体力"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：震击范围 大幅 提升，并且必定附加 流血，流血 对精英，首领的伤害提升 500%，获得护盾量提升至 4% 最大体力"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：震击范围 极大幅 提升，伤害提升至 500% 攻击，获得护盾量提升至 7% 最大体力"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _format_faze_line(level: int, current_tier: int, tier: int, content: String) -> String:
	var line = content
	if level < tier:
		line = "[color=#888]" + content + "[/color]"
	elif current_tier == tier:
		line = "[color=green]" + content + "[/color]"
	else:
		line = "[color=LEMONCHIFFON]" + content + "[/color]"
	return line

func _build_sword_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("刀剑法则"))
	lines.append(_color_owned_weapons("刀剑系武器：剑气诀，饮血刀，乾坤双剑"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：刀剑系武器攻击速度提升 20%，暴击伤害提升 10%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：刀剑系武器击中目标后会给其叠加一层寒光，寒光叠加到5层后会被引爆，对目标造成 240% 攻击的伤害"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：刀剑系武器攻击速度再次提升 30%，暴击伤害再次提升 30%"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：寒光可以暴击，并且暴击伤害提升 30%，寒光的伤害对精英、首领提升 50%"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：刀剑系的武器攻击速度再次提升 60%，寒光的伤害提高至 500% 攻击"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_wide_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("广域法则"))
	lines.append(_color_owned_weapons("广域类武器：血气波，赤曜，兑泽诀，气功波"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：广域类武器伤害及伤害范围提升 15%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：角色的伤害范围提升 15%，并且广域类武器的伤害范围加成每提高 1%，伤害提高 1%"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：广域类武器的伤害提升 45% ，广域类武器伤害范围提升 20%"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：角色的伤害范围提升 25%，广域类武器的范围加成每提高 1%，伤害提升量由 1% 提升到 3%"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：广域类武器伤害及伤害范围再次提升 65%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_bagua_faze_detail(level: int) -> String:
	var tiers = [4, 11, 18, 25, 33]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("八卦法则"))
	lines.append(_color_owned_weapons("八卦类武器：乾坤双剑，离火诀，兑泽诀，坎水诀，震雷诀，巽风诀，艮山诀"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：八卦类武器击中目标 + 1 推衍度，击杀目标 + 5 推衍度，对精英翻倍，首领翻 5 倍，满 100 点后，获得 1 层【推衍完成】，每层提升 3 % 的经验值加成与 1 % 八卦类武器伤害提升，每层【推衍完成】会使下一层【推衍完成】的获取所需的推衍值 +10"))
	lines.append(_format_faze_line(level, current_tier, 11, "11阶：推衍度获得翻倍，八卦类武器伤害提升 10%"))
	lines.append(_format_faze_line(level, current_tier, 18, "18阶：推衍度获得提升至 3 倍，八卦类武器伤害再次提升 20%"))
	lines.append(_format_faze_line(level, current_tier, 25, "25阶：推衍度获得提升至 5 倍，八卦类武器伤害再次提升 30%"))
	lines.append(_format_faze_line(level, current_tier, 33, "33阶：推衍度获得提升至 10 倍，八卦类武器伤害再次提升 45%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_destroy_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("破坏法则"))
	lines.append(_color_owned_weapons("破坏系武器：冰刺术，爆炎诀，天雷破"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：破坏系武器暴击率提升 15%，溢出的暴击率会等量转换为暴击伤害"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：破坏系武器造成暴击或击杀敌人后，有 6% 的概率引爆目标，对大范围造成 75% 攻击的可暴击伤害"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：破坏系武器造成的暴击伤害会从 -30% ~ +90% 之间波动，引爆的伤害提升至 160% 攻击，对首领额外造成 300% 的伤害"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：破坏系武器暴击率再次提升 25%，破坏系武器造成的暴击伤害会从 -40% ~ +120% 之间波动"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：破坏系武器伤害再次提升 100%，引爆的范围大幅增加，引爆的伤害提升至 800% 攻击"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_life_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("生灵法则"))
	lines.append(_color_owned_weapons("生灵系武器：光弹，坎水诀，圣光术"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：生灵系武器伤害提升 25%，经验获取提升 20%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：每 20 秒/升级时降下神圣光辉，对大范围的敌人造成 300% 攻击的伤害，对首领造成额外 200% 伤害"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：神圣光辉的伤害提升至 500% ，范围提升，经验获取加成提升至 75%"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：生灵系武器伤害再次提升 60%，神圣光辉范围大幅提升 ，经验获取加成提升至 120%"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：生灵系武器伤害再次提升 120%，神圣光辉触发时间缩短至 4 秒，伤害提升至 1800%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_bullet_faze_detail(level: int) -> String:
	var tiers = [4, 11, 18, 24, 31]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("弹雨法则"))
	lines.append(_color_owned_weapons("弹雨类武器：剑气诀，光弹，仙枝，冰刺术"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：弹雨类武器伤害提升 12%，射程提升 20%"))
	lines.append(_format_faze_line(level, current_tier, 11, "11阶：弹雨类武器累计命中 100 次后，会以自身为中心连续发射 2 波弹幕，每波 45 发，每发造成 45% 攻击的伤害"))
	lines.append(_format_faze_line(level, current_tier, 18, "18阶：弹雨类武器伤害再次提升 28%，范围提升 30%，弹幕提升至 3 波，每发伤害提升至 80% 攻击"))
	lines.append(_format_faze_line(level, current_tier, 24, "24阶：弹雨类武器伤害再次提升 40%，弹幕提升至 4 波，每发伤害提升至 150% 攻击"))
	lines.append(_format_faze_line(level, current_tier, 31, "31阶：弹雨类武器伤害再次提升 90%，弹幕提升至 6 波，每发伤害提升至 500% 攻击"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_wind_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("啸风法则"))
	lines.append(_color_owned_weapons("啸风类武器：气功波，巽风诀，风龙杖"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：啸风类武器伤害提升 25%，移动速度提升 10%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：啸风类攻击速度提升 30%，啸风类武器击中敌人后，为自身添加 1 层【唤风】，每层唤风可以提升自身 0.15% 的攻击速度与移动速度，最多可以叠加 200 层，持续 12 秒"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：啸风类武器伤害再次提升 50%，啸风类攻击速度再次提升 40%，每层【唤风】额外提升啸风类武器伤害 0.2%"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：啸风类武器伤害再次提升 75%，【唤风】最多叠加层数提升至 300 层，啸风类武器击中首领时额外获得 2 层【唤风】"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：啸风类武器伤害再次提升 110%，拥有的每层【唤风】会提升啸风类武器对精英，首领 0.5% 的伤害"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_thunder_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("鸣雷法则"))
	lines.append(_color_owned_weapons("鸣雷系武器：天雷破，震雷诀"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：鸣雷系武器伤害提升 20% ，感电伤害提升 40%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：鸣雷系武器击中敌人或感电触发，有 5% 概率召唤鸣雷劈向目标，造成 70 % 攻击的范围伤害"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：鸣雷的伤害提升到 150% 攻击，鸣雷触发概率提升至 15% ，鸣雷对精英、首领的伤害额外提升 400%"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：鸣雷系武器伤害再次提升 120% ，鸣雷触发概率提升至 60% ，鸣雷对精英、首领的额外伤害增加到 900%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_heal_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("愈疗法则"))
	lines.append(_color_owned_weapons("愈疗系武器：坎水诀，圣光术"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：治疗与护盾获取加成提升 30%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：治疗自身或护盾受损后，会向最近的敌人发射弹体，造成 60% 攻击 + 治疗量 2400% /护盾损失 1600% 的伤害，随等级上升，每级提升 10%"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：治疗与护盾加成再次提升 35%，弹体伤害* 150% "))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：治疗与护盾加成再次提升 50%，弹体伤害* 600% ，并允许暴击"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_summon_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("御灵法则"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：召唤物伤害与治疗 + 20% ，触发间隔 - 10% "))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：最大召唤物容量 + 1 ，召唤物弹体大小 + 20%"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：召唤 1 个不占容量的双极魔剑，召唤物伤害与治疗 + 40%"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：每个召唤物可以使角色的攻击力提升 10%，攻击速度提升 8%"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：召唤 1 个不占容量的陨灭剑灵，召唤物伤害与治疗 + 100%，触发间隔 - 30%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_shield_faze_detail(level: int) -> String:
	var tiers = [4, 7, 11, 15]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("护佑法则"))
	lines.append(_color_owned_weapons("护佑系武器：玄武盾，艮山诀，饮血刀（进化），坎水诀（进化）"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：护盾获取加成提升 20% ，最大体力提升 10%"))
	lines.append(_format_faze_line(level, current_tier, 7, "7阶：最大体力再次提升 25% ，护盾因时间结束消失后，其 30% 会转为生命回复"))
	lines.append(_format_faze_line(level, current_tier, 11, "11阶：最大体力再次提升 35% ，每存在相当于最大体力 3% 的护盾，获得额外 1% 的减伤率，最高 20%"))
	lines.append(_format_faze_line(level, current_tier, 15, "15阶：护盾获取加成再次提升 50%，护盾因时间结束消失后，其 60% 会转为生命回复"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _sort_faze_laws(a: Dictionary, b: Dictionary) -> bool:
	return a["level"] > b["level"]

func _on_faze_mouse_entered(slot_index: int) -> void:
	var index = slot_index - 1
	var panel = faze_panels[index]
	var detail = faze_details[index]
	_update_faze_panel_size(panel, detail)
	panel.visible = true
	detail.visible = true

func _on_faze_mouse_exited(slot_index: int) -> void:
	var index = slot_index - 1
	var panel = faze_panels[index]
	var detail = faze_details[index]
	panel.visible = false
	detail.visible = false

func _update_faze_panel_size(panel: Panel, detail: RichTextLabel) -> void:
	var content_width = detail.get_content_width()
	var content_height = detail.get_content_height()
	var text_size = Vector2(content_width, content_height)
	detail.size = text_size
	panel.size = text_size + Vector2(8, 8)
	var panel_position := Vector2(72, 48)
	var viewport_size := get_viewport().get_visible_rect().size
	var parent_control := panel.get_parent() as Control
	if parent_control:
		var target_global_x := parent_control.global_position.x + panel_position.x
		var right_overflow := target_global_x + panel.size.x - (viewport_size.x - 8.0)
		if right_overflow > 0.0:
			panel_position.x -= right_overflow
		var left_overflow := 8.0 - (parent_control.global_position.x + panel_position.x)
		if left_overflow > 0.0:
			panel_position.x += left_overflow
	panel.position = panel_position
	detail.position = panel_position + Vector2(4, 6)

func _connect_signals() -> void:
	Global.connect("skill_attack_speed_updated", Callable(self , "_on_skill_attack_speed_updated"))
	Global.connect("player_lv_up", Callable(self , "_on_level_up"))
	Global.connect("manual_level_up_pending", Callable(self , "_on_manual_level_up_pending"))
	
	# 连接玩家咏唱信号
	Global.connect("player_chant_start", Callable(self , "_on_player_chant_start"))
	Global.connect("player_chant_end", Callable(self , "_on_player_chant_end"))
	
	# 连接主动技能信号
	# if Global.active_skill_manager:
	# 	Global.active_skill_manager.skill_cooldown_started.connect(_on_active_skill_cooldown_started)
	# 	Global.active_skill_manager.skill_cooldown_finished.connect(_on_active_skill_cooldown_finished)

## 断开信号上指定回调的所有连接
func _disconnect_callable(sig: Signal, callable: Callable) -> void:
	while sig.is_connected(callable):
		sig.disconnect(callable)

## 连接刷新按钮信号
func _connect_refresh_buttons() -> void:
	if refresh_all_button:
		refresh_all_button.process_mode = Node.PROCESS_MODE_ALWAYS
		_disconnect_callable(refresh_all_button.pressed, _on_refresh_all_button_pressed)
		refresh_all_button.pressed.connect(_on_refresh_all_button_pressed)
		print("[Connect] 全局刷新按钮 信号已连接")
	else:
		print("[Connect] 全局刷新按钮 未找到!")
	
	var ban_button1 = _get_ban_button(1)
	var ban_button2 = _get_ban_button(2)
	var ban_button3 = _get_ban_button(3)
	
	if ban_button1:
		_connect_ban_button(ban_button1, 1)
		print("[Connect] 禁用按钮1 信号已连接")
	else:
		print("[Connect] 禁用按钮1 未找到!")
	
	if ban_button2:
		_connect_ban_button(ban_button2, 2)
		print("[Connect] 禁用按钮2 信号已连接")
	else:
		print("[Connect] 禁用按钮2 未找到!")
	
	if ban_button3:
		_connect_ban_button(ban_button3, 3)
		print("[Connect] 禁用按钮3 信号已连接")
	else:
		print("[Connect] 禁用按钮3 未找到!")

func _get_ban_button(button_id: int) -> Button:
	var target_btn: Button
	match button_id:
		1:
			target_btn = lv_up_change_b1
		2:
			target_btn = lv_up_change_b2
		3:
			target_btn = lv_up_change_b3
	if target_btn == null:
		return null
	var ban_button := target_btn.get_node_or_null("BanButton" if button_id == 1 else "BanButton%d" % button_id) as Button
	if ban_button == null:
		ban_button = target_btn.get_node_or_null("RefreshButton" if button_id == 1 else "RefreshButton%d" % button_id) as Button
	return ban_button

func _is_ban_button_available(button_id: int) -> bool:
	if level_up_manager == null or level_up_manager.now_main_skill_name != "":
		return false
	if PC.ban_num <= 0:
		return false
	if _is_reward_button_locked(button_id):
		return false
	if not level_up_manager.current_rewards.has(button_id):
		return false
	var reward = level_up_manager.current_rewards[button_id]
	if reward == null:
		return false
	if not LvUp.has_method("get_lingwu_series_key"):
		return false
	var series_key := LvUp.get_lingwu_series_key(str(reward.id))
	return not series_key.is_empty()

func _update_ban_button_states() -> void:
	for button_id in [1, 2, 3]:
		var ban_button := _get_ban_button(button_id)
		if ban_button == null:
			continue
		var available := _is_ban_button_available(button_id)
		ban_button.disabled = not available
		if not available and _ban_hold_button_id == button_id:
			_cancel_ban_hold()

func _connect_ban_button(button: Button, button_id: int) -> void:
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.focus_mode = Control.FOCUS_NONE
	var button_down_callable := Callable(self , "_on_ban_button_down").bind(button_id)
	var button_up_callable := Callable(self , "_on_ban_button_up").bind(button_id)
	var gui_input_callable := Callable(self , "_on_ban_button_gui_input").bind(button_id)
	for conn in button.button_down.get_connections():
		if conn.callable.get_object() == self:
			button.button_down.disconnect(conn.callable)
	for conn in button.button_up.get_connections():
		if conn.callable.get_object() == self:
			button.button_up.disconnect(conn.callable)
	for conn in button.gui_input.get_connections():
		if conn.callable.get_object() == self:
			button.gui_input.disconnect(conn.callable)
	button.button_down.connect(button_down_callable)
	button.button_up.connect(button_up_callable)
	button.gui_input.connect(gui_input_callable)
	_get_or_create_ban_progress_bar(button, button_id).visible = false

func _on_refresh_all_button_pressed() -> void:
	handle_refresh_all_button()

func _on_ban_button_down(button_id: int) -> void:
	_start_ban_hold(button_id)

func _on_ban_button_up(button_id: int) -> void:
	if _ban_hold_button_id == button_id:
		_cancel_ban_hold()

func _on_ban_button_gui_input(event: InputEvent, button_id: int) -> void:
	if event is InputEventMouseButton and not event.pressed and _ban_hold_button_id == button_id:
		_cancel_ban_hold()

func _get_level_up_reward_button(button_id: int) -> Button:
	match button_id:
		1:
			return lv_up_change_b1
		2:
			return lv_up_change_b2
		3:
			return lv_up_change_b3
	return null

func _show_level_up_tip(text: String) -> void:
	var tip = lv_up_tip if lv_up_tip else get_node_or_null("TipsLayer/Tip")
	if tip and tip.has_method("start_animation"):
		tip.start_animation(text, 0.5)

func _is_reward_button_locked(button_id: int) -> bool:
	return level_up_manager != null and (level_up_manager.locked_rewards.has(button_id) or level_up_manager.tentative_locked_rewards.has(button_id))

func _get_or_create_ban_progress_bar(button: Button, button_id: int) -> ColorRect:
	var progress_bar := button.get_node_or_null("BanHoldProgress") as ColorRect
	if progress_bar != null:
		return progress_bar
	progress_bar = ColorRect.new()
	progress_bar.name = "BanHoldProgress"
	progress_bar.z_index = 40
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.color = Color(0.95, 0.18, 0.12, 0.82)
	progress_bar.position = Vector2(0.0, max(button.size.y - 7.0, 0.0))
	progress_bar.size = Vector2(0.0, 7.0)
	button.add_child(progress_bar)
	button.set_meta("ban_button_id", button_id)
	return progress_bar

func _update_ban_progress_bar(button_id: int, ratio: float) -> void:
	var ban_button := _get_ban_button(button_id)
	if ban_button == null:
		return
	var progress_bar := _get_or_create_ban_progress_bar(ban_button, button_id)
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	progress_bar.visible = clamped_ratio > 0.0
	progress_bar.position = Vector2(0.0, max(ban_button.size.y - 7.0, 0.0))
	progress_bar.size = Vector2(max(ban_button.size.x, 1.0) * clamped_ratio, 7.0)

func _clear_ban_hold_progress() -> void:
	for button_id in [1, 2, 3]:
		var ban_button := _get_ban_button(button_id)
		if ban_button == null:
			continue
		var progress_bar := ban_button.get_node_or_null("BanHoldProgress") as ColorRect
		if progress_bar != null:
			progress_bar.visible = false
			progress_bar.size.x = 0.0

func _start_ban_hold(button_id: int) -> void:
	if level_up_manager and level_up_manager.has_method("_is_mobile_level_up_input_guard_active") and level_up_manager._is_mobile_level_up_input_guard_active():
		return
	if level_up_manager == null or level_up_manager.now_main_skill_name != "":
		return
	if _is_reward_button_locked(button_id):
		_show_level_up_tip("该栏位已锁定")
		return
	if PC.ban_num <= 0:
		_show_level_up_tip("禁用次数不足")
		return
	if not level_up_manager.current_rewards.has(button_id):
		_show_level_up_tip("该栏位暂无奖励")
		return
	var reward = level_up_manager.current_rewards[button_id]
	var series_key := LvUp.get_lingwu_series_key(str(reward.id)) if reward != null and LvUp.has_method("get_lingwu_series_key") else ""
	if series_key.is_empty():
		return
	_cancel_ban_hold()
	_ban_hold_button_id = button_id
	_ban_hold_elapsed = 0.0
	_ban_hold_active = true
	_ban_hold_completed = false
	_update_ban_progress_bar(button_id, 0.001)

func _cancel_ban_hold() -> void:
	if _ban_hold_completed:
		return
	_ban_hold_active = false
	_ban_hold_button_id = 0
	_ban_hold_elapsed = 0.0
	_clear_ban_hold_progress()

func _process_ban_hold(delta: float) -> void:
	if not _ban_hold_active:
		return
	if _ban_hold_button_id <= 0:
		_cancel_ban_hold()
		return
	var ban_button := _get_ban_button(_ban_hold_button_id)
	if ban_button == null:
		_cancel_ban_hold()
		return
	_ban_hold_elapsed += delta
	var ratio := _ban_hold_elapsed / BAN_HOLD_SECONDS
	_update_ban_progress_bar(_ban_hold_button_id, ratio)
	if _ban_hold_elapsed >= BAN_HOLD_SECONDS:
		_complete_ban_hold(_ban_hold_button_id)

func _complete_ban_hold(button_id: int) -> void:
	_ban_hold_completed = true
	_ban_hold_active = false
	_ban_hold_button_id = 0
	_ban_hold_elapsed = 0.0
	_clear_ban_hold_progress()
	if level_up_manager == null or level_up_manager.now_main_skill_name != "":
		_ban_hold_completed = false
		return
	if _is_reward_button_locked(button_id):
		_show_level_up_tip("该栏位已锁定")
		_ban_hold_completed = false
		return
	if PC.ban_num <= 0:
		_show_level_up_tip("禁用次数不足")
		_ban_hold_completed = false
		return
	if not level_up_manager.current_rewards.has(button_id):
		_show_level_up_tip("该栏位暂无奖励")
		_ban_hold_completed = false
		return
	var reward = level_up_manager.current_rewards[button_id]
	if reward == null or not LvUp.ban_lingwu_series_by_reward_id(str(reward.id)):
		_ban_hold_completed = false
		_update_ban_button_states()
		return
	PC.ban_num -= 1
	_update_refresh_lock_display()
	var target_btn := _get_level_up_reward_button(button_id)
	if is_instance_valid(target_btn):
		_do_refresh_with_transition(target_btn, button_id, false)
	else:
		level_up_manager.handle_refresh_button_without_cost(button_id, get_tree(), get_viewport())
		_update_refresh_lock_display()
	_ban_hold_completed = false

## 连接锁定按钮信号
func _connect_lock_buttons() -> void:
	# 锁定按钮是升级按钮的子节点
	var lock_button1 = lv_up_change_b1.get_node_or_null("LockButton")
	var lock_button2 = lv_up_change_b2.get_node_or_null("LockButton2")
	var lock_button3 = lv_up_change_b3.get_node_or_null("LockButton3")
	
	if lock_button1:
		lock_button1.process_mode = Node.PROCESS_MODE_ALWAYS
		_disconnect_callable(lock_button1.pressed, _on_lock_button_1_pressed)
		lock_button1.pressed.connect(_on_lock_button_1_pressed)
		print("[Connect] 锁定按钮1 信号已连接")
	else:
		print("[Connect] 锁定按钮1 未找到!")
	
	if lock_button2:
		lock_button2.process_mode = Node.PROCESS_MODE_ALWAYS
		_disconnect_callable(lock_button2.pressed, _on_lock_button_2_pressed)
		lock_button2.pressed.connect(_on_lock_button_2_pressed)
		print("[Connect] 锁定按钮2 信号已连接")
	else:
		print("[Connect] 锁定按钮2 未找到!")
	
	if lock_button3:
		lock_button3.process_mode = Node.PROCESS_MODE_ALWAYS
		_disconnect_callable(lock_button3.pressed, _on_lock_button_3_pressed)
		lock_button3.pressed.connect(_on_lock_button_3_pressed)
		print("[Connect] 锁定按钮3 信号已连接")
	else:
		print("[Connect] 锁定按钮3 未找到!")

func _on_lock_button_1_pressed() -> void:
	handle_lock_button(1)

func _on_lock_button_2_pressed() -> void:
	handle_lock_button(2)

func _on_lock_button_3_pressed() -> void:
	handle_lock_button(3)

## 处理锁定按钮点击
func handle_lock_button(button_id: int) -> void:
	if level_up_manager and level_up_manager.has_method("_is_mobile_level_up_input_guard_active") and level_up_manager._is_mobile_level_up_input_guard_active():
		return
	if level_up_manager and level_up_manager.now_main_skill_name != "":
		return
	# 找对应的大按钮
	var target_btn: Button
	match button_id:
		1: target_btn = lv_up_change_b1
		2: target_btn = lv_up_change_b2
		3: target_btn = lv_up_change_b3
	
	if not is_instance_valid(target_btn):
		return
	
	# 如果该位置已经是临时锁定，则取消锁定并返还次数
	if level_up_manager and level_up_manager.tentative_locked_rewards.has(button_id):
		level_up_manager.tentative_locked_rewards.erase(button_id)
		PC.lock_num += 1
		print("[Lock] 取消临时锁定 位置", button_id, "，返还锁定次数")
		# 恢复按钮颜色
		var tween = target_btn.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(target_btn, "modulate", Color(1, 1, 1, 1.0), 0.15)
		_update_refresh_lock_display()
		return
	
	# 如果该位置是已确认锁定，只取消继承锁定；锁定次数已经在上一轮消耗，不返还
	if level_up_manager and level_up_manager.locked_rewards.has(button_id):
		level_up_manager.locked_rewards.erase(button_id)
		print("[Lock] 取消已确认锁定 位置", button_id, "，不返还锁定次数")
		var tween = target_btn.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(target_btn, "modulate", Color(1, 1, 1, 1.0), 0.15)
		_update_refresh_lock_display()
		return
	
	# 锁定次数不足检查
	if PC.lock_num <= 0:
		var tip = lv_up_tip if lv_up_tip else get_node_or_null("TipsLayer/Tip")
		if tip and tip.has_method("start_animation"):
			tip.start_animation("锁定次数不足", 0.5)
		return
	
	# 消耗锁定次数
	PC.lock_num -= 1
	
	# 保存到临时锁定（当前界面有效，选择其他项后才转正）
	if level_up_manager and level_up_manager.current_rewards.has(button_id):
		level_up_manager.tentative_locked_rewards[button_id] = level_up_manager.current_rewards[button_id]
		print("[Lock] 临时锁定位置", button_id, ": ", level_up_manager.current_rewards[button_id].reward_name)
	else:
		print("[Lock] 临时锁定失败！current_rewards不包含位置", button_id, "，当前keys=", level_up_manager.current_rewards.keys() if level_up_manager else "null")
		var tip = lv_up_tip if lv_up_tip else get_node_or_null("TipsLayer/Tip")
		if tip and tip.has_method("start_animation"):
			tip.start_animation("该栏位暂无奖励", 0.5)
		PC.lock_num += 1
		return
	
	# 添加灰色滤镜（通过设置modulate颜色）
	var tween = target_btn.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(target_btn, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.15)
	
	# 更新显示
	_update_refresh_lock_display()

## 连接纹章鼠标事件信号
func _connect_emblem_signals(icons: Array) -> void:
	for i in range(icons.size()):
		var icon = icons[i]
		if icon:
			var emblem_index = i + 1 # emblem 索引从 1 开始
			icon.mouse_entered.connect(_on_emblem_mouse_entered.bind(emblem_index))
			icon.mouse_exited.connect(_on_emblem_mouse_exited.bind(emblem_index))

func _on_emblem_mouse_entered(emblem_index: int) -> void:
	show_emblem_detail(emblem_index)

func _on_emblem_mouse_exited(emblem_index: int) -> void:
	hide_emblem_detail(emblem_index)

## 连接技能图标鼠标事件信号
func _connect_skill_icon_signals() -> void:
	var skill_icons := [skill1, skill2, skill3, skill4, skill5, skill6, skill7, skill8, skill9, skill10, skill11, skill12, skill13, skill14, skill15, skill16, skill17, skill18, skill19, skill20, skill21]
	for i in range(skill_icons.size()):
		var icon = skill_icons[i]
		if icon:
			var skill_index = i + 1 # skill 索引从 1 开始
			icon.mouse_entered.connect(_on_skill_icon_mouse_entered.bind(skill_index))
			icon.mouse_exited.connect(_on_skill_icon_mouse_exited.bind(skill_index))

func _on_skill_icon_mouse_entered(skill_index: int) -> void:
	if PC.player_instance:
		show_skill_label(skill_index, PC.player_instance)

func _on_skill_icon_mouse_exited(_skill_index: int) -> void:
	hide_skill_label()

## 连接主动技能图标鼠标事件信号
func _connect_active_skill_signals() -> void:
	var active_icons := [active1, active2, active3]
	var slot_keys := ["space", "q", "e"]
	for i in range(active_icons.size()):
		var icon = active_icons[i]
		if icon:
			var slot_key = slot_keys[i]
			icon.mouse_entered.connect(_on_active_skill_mouse_entered.bind(slot_key))
			icon.mouse_exited.connect(_on_active_skill_mouse_exited)
			icon.gui_input.connect(_on_mobile_active_skill_gui_input.bind(slot_key, icon))
	_update_mobile_active_skill_mouse_filters()

func _on_active_skill_mouse_entered(slot_key: String) -> void:
	if Global.is_mobile_input_mode():
		return
	if lv_up_change and lv_up_change.visible:
		return
	show_active_skill_label(slot_key)

func _on_active_skill_mouse_exited() -> void:
	if Global.is_mobile_input_mode():
		return
	hide_active_skill_label()

## 显示主动技能详情
func show_active_skill_label(slot_key: String) -> void:
	# 获取槽位绑定的技能
	var skill_config: Dictionary = Global.get_current_active_skills().get(slot_key, {})
	var skill_name: String = skill_config.get("name", "")
	if skill_name == "":
		return
	
	# 获取技能等级数据
	var skill_data = Global.player_active_skill_data.get(skill_name, {})
	var level = skill_data.get("level", 1)
	
	var text = ""
	
	match skill_name:
		"dodge":
			text = _build_dodge_skill_text(level)
		"random_strike":
			text = _build_random_strike_skill_text(level)
		"mizongbu":
			text = _build_mizongbu_skill_text(level)
		"beastify":
			text = _build_beastify_skill_text(level)
		"heal_hot":
			text = _build_heal_hot_skill_text(level)
		"water_sheild":
			text = _build_water_shield_skill_text(level)
		"holy_fire":
			text = _build_holy_fire_skill_text(level)
		"wind_thunder":
			text = _build_wind_thunder_skill_text(level)
		"magical_ice":
			text = _build_magical_ice_skill_text(level)
		"magical_fire":
			text = _build_magical_fire_skill_text(level)
		"magic":
			text = _build_magic_skill_text(level)
		"meditation":
			text = _build_meditation_skill_text(level)
		"destructive_hammer":
			text = _build_destructive_hammer_skill_text(level)
		_:
			text = "[未知技能]"
	
	active_skill_label.text = text
	if Global.is_mobile_input_mode() and _mobile_skill_icon:
		_position_mobile_active_skill_label(_mobile_skill_icon)
	active_skill_label.visible = true
	if _active_skill_tween and _active_skill_tween.is_valid():
		_active_skill_tween.kill()
	active_skill_label.modulate.a = 0.0
	_active_skill_tween = create_tween()
	_active_skill_tween.tween_property(active_skill_label, "modulate:a", 1.0, 0.2)

## 隐藏主动技能详情
func hide_active_skill_label() -> void:
	if _active_skill_tween and _active_skill_tween.is_valid():
		_active_skill_tween.kill()
	if not active_skill_label.visible:
		return
	_active_skill_tween = create_tween()
	_active_skill_tween.tween_property(active_skill_label, "modulate:a", 0.0, 0.2)
	_active_skill_tween.tween_callback(func():
		active_skill_label.visible = false
		active_skill_label.modulate.a = 1.0
	)

func _position_mobile_active_skill_label(icon: Control) -> void:
	if active_skill_label == null or icon == null:
		return
	var label_size := active_skill_label.size
	if label_size.x <= 0.0 or label_size.y <= 0.0:
		label_size = active_skill_label.get_combined_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var target_position := icon.global_position - Vector2(label_size.x + 10.0, label_size.y + 10.0)
	target_position.x = clampf(target_position.x, 0.0, max(0.0, viewport_size.x - label_size.x))
	target_position.y = clampf(target_position.y, 0.0, max(0.0, viewport_size.y - label_size.y))
	active_skill_label.global_position = target_position

func _input(event: InputEvent) -> void:
	if not Global.is_mobile_input_mode():
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _mobile_skill_touch_index:
			_update_mobile_skill_touch(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not _mobile_skill_touch_active:
				var touch_hit: Dictionary = _get_mobile_active_skill_hit(touch.position)
				if not touch_hit.is_empty():
					var touch_slot_key: String = String(touch_hit.get("slot_key", ""))
					var touch_icon: TextureButton = touch_hit.get("icon", null) as TextureButton
					_begin_mobile_skill_touch(touch_slot_key, touch_icon, touch.index, touch.position)
					if _mobile_skill_touch_active and _mobile_skill_touch_index == touch.index:
						get_viewport().set_input_as_handled()
		elif _mobile_skill_touch_active and touch.index == _mobile_skill_touch_index:
			_end_mobile_skill_touch(touch.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _mobile_skill_touch_index == -2:
			var motion := event as InputEventMouseMotion
			_update_mobile_skill_touch(motion.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if _mobile_skill_touch_active and _mobile_skill_touch_index >= 0:
				return
			if mouse_button.pressed:
				if not _mobile_skill_touch_active:
					var mouse_hit: Dictionary = _get_mobile_active_skill_hit(mouse_button.position)
					if not mouse_hit.is_empty():
						var mouse_slot_key: String = String(mouse_hit.get("slot_key", ""))
						var mouse_icon: TextureButton = mouse_hit.get("icon", null) as TextureButton
						_begin_mobile_skill_touch(mouse_slot_key, mouse_icon, -2, mouse_button.position)
						if _mobile_skill_touch_active and _mobile_skill_touch_index == -2:
							get_viewport().set_input_as_handled()
			elif _mobile_skill_touch_index == -2:
				_end_mobile_skill_touch(mouse_button.position)
				get_viewport().set_input_as_handled()

func _get_mobile_active_skill_hit(position: Vector2) -> Dictionary:
	var active_icons: Array[TextureButton] = [active1, active2, active3]
	var slot_keys: Array[String] = ["space", "q", "e"]
	for i in range(active_icons.size() - 1, -1, -1):
		var icon: TextureButton = active_icons[i]
		if not is_instance_valid(icon) or not icon.visible:
			continue
		if _is_viewport_position_inside_control(icon, position):
			return {
				"slot_key": slot_keys[i],
				"icon": icon,
			}
	return {}

func _is_viewport_position_inside_control(control: Control, position: Vector2) -> bool:
	if control == null:
		return false
	var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)

func _update_mobile_active_skill_mouse_filters() -> void:
	var use_mobile: bool = Global.is_mobile_input_mode()
	var filter: int = Control.MOUSE_FILTER_IGNORE if use_mobile else Control.MOUSE_FILTER_STOP
	var active_icons: Array[TextureButton] = [active1, active2, active3]
	for icon in active_icons:
		if is_instance_valid(icon):
			icon.mouse_filter = filter
	var active_bar: Control = active1.get_parent() as Control if active1 != null else null
	if is_instance_valid(active_bar):
		active_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE if use_mobile else Control.MOUSE_FILTER_PASS

func _on_input_device_mode_changed(_mode: String) -> void:
	_update_mobile_active_skill_mouse_filters()
	_refresh_active_skill_hotkey_text()

func _refresh_active_skill_hotkey_text() -> void:
	var active_icons: Array[TextureButton] = [active1, active2, active3]
	var slot_keys: Array[String] = ["space", "q", "e"]
	var pc_texts: Array[String] = ["Space", "Q", "E"]
	for i in range(active_icons.size()):
		var icon: TextureButton = active_icons[i]
		if not is_instance_valid(icon):
			continue
		if icon.has_method("setup_active_skill"):
			icon.setup_active_skill(slot_keys[i], _get_active_skill_button_text(slot_keys[i], pc_texts[i]))
		icon.visible = _has_skill_in_slot(slot_keys[i])

func _on_mobile_active_skill_gui_input(event: InputEvent, slot_key: String, icon: TextureButton) -> void:
	if not Global.is_mobile_input_mode():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var touch_position := _get_mobile_skill_viewport_position(icon, touch.position)
		if touch.pressed:
			_begin_mobile_skill_touch(slot_key, icon, touch.index, touch_position)
			if _mobile_skill_touch_active and _mobile_skill_touch_index == touch.index:
				get_viewport().set_input_as_handled()
		elif _mobile_skill_touch_active and touch.index == _mobile_skill_touch_index:
			_end_mobile_skill_touch(touch_position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _mobile_skill_touch_active and drag.index == _mobile_skill_touch_index:
			_update_mobile_skill_touch(_get_mobile_skill_viewport_position(icon, drag.position))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if _mobile_skill_touch_active and _mobile_skill_touch_index >= 0:
			return
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			var mouse_position := _get_mobile_skill_viewport_position(icon, mouse_button.position)
			if mouse_button.pressed:
				_begin_mobile_skill_touch(slot_key, icon, -2, mouse_position)
				if _mobile_skill_touch_active and _mobile_skill_touch_index == -2:
					get_viewport().set_input_as_handled()
			elif _mobile_skill_touch_active and _mobile_skill_touch_index == -2:
				_end_mobile_skill_touch(mouse_position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _mobile_skill_touch_active and _mobile_skill_touch_index == -2:
			var motion := event as InputEventMouseMotion
			_update_mobile_skill_touch(_get_mobile_skill_viewport_position(icon, motion.position))
			get_viewport().set_input_as_handled()

func _get_mobile_skill_viewport_position(icon: Control, local_position: Vector2) -> Vector2:
	if icon == null:
		return local_position
	var should_convert := _mobile_skill_gui_position_is_local
	if not _mobile_skill_touch_active:
		should_convert = _is_mobile_skill_local_gui_position(icon, local_position)
		_mobile_skill_gui_position_is_local = should_convert
	if should_convert:
		return icon.get_global_transform_with_canvas() * local_position
	return local_position

func _is_mobile_skill_local_gui_position(icon: Control, position: Vector2) -> bool:
	if icon == null:
		return false
	var local_rect := Rect2(Vector2.ZERO, icon.size).grow(2.0)
	return local_rect.has_point(position)

func _get_mobile_skill_icon_center(icon: Control) -> Vector2:
	if icon == null:
		return Vector2.ZERO
	return icon.get_global_transform_with_canvas() * (icon.size * 0.5)

func _begin_mobile_skill_touch(slot_key: String, icon: TextureButton, touch_index: int, position: Vector2) -> void:
	if _mobile_skill_touch_active:
		_cancel_mobile_skill_touch()
	if Global.is_level_up or get_tree().paused or Global.in_menu or PC.is_game_over:
		_force_clear_mobile_skill_input()
		return
	var skill_config: Dictionary = Global.get_current_active_skills().get(slot_key, {})
	var skill_name: String = skill_config.get("name", "")
	if skill_name == "":
		return
	var adjusting_chant_aim: bool = _can_adjust_mobile_chant_aim(slot_key, skill_name)
	if not _is_mobile_skill_ready(skill_name) and not adjusting_chant_aim:
		return
	_mobile_skill_touch_active = true
	_mobile_skill_touch_index = touch_index
	_mobile_skill_slot = slot_key
	_mobile_skill_name = skill_name
	_mobile_skill_icon = icon
	_mobile_skill_press_position = _get_mobile_chant_aim_press_position(icon, skill_name) if adjusting_chant_aim else (_get_mobile_skill_icon_center(icon) if _is_mobile_aim_skill(skill_name) else position)
	_mobile_skill_last_position = position
	_mobile_skill_point_aim_origin = _get_mobile_point_aim_origin_for_touch(skill_name, adjusting_chant_aim)
	_mobile_skill_press_elapsed = 0.0
	_mobile_skill_long_press_shown = false
	_mobile_skill_aim_started = false
	_mobile_skill_cast_consumed = adjusting_chant_aim
	if _is_mobile_aim_skill(skill_name):
		_mobile_skill_aim_started = true
		_mobile_skill_long_press_shown = true
		if adjusting_chant_aim:
			_update_mobile_aim_cast()
		else:
			_update_mobile_skill_aim_preview()
			_cast_mobile_skill_from_touch()

func _update_mobile_skill_touch(position: Vector2) -> void:
	_mobile_skill_last_position = position
	if _mobile_skill_aim_started:
		if _mobile_chant_aim_active and _mobile_skill_name == _mobile_chant_aim_skill:
			_mobile_chant_aim_last_position = position
		_update_mobile_aim_cast()
		if not _mobile_skill_cast_consumed and not _mobile_chant_aim_active:
			_update_mobile_skill_aim_preview()

func _end_mobile_skill_touch(position: Vector2) -> void:
	_mobile_skill_last_position = position
	if _mobile_skill_aim_started:
		if _mobile_chant_aim_active and _mobile_skill_name == _mobile_chant_aim_skill:
			_mobile_chant_aim_last_position = position
		_update_mobile_aim_cast()
		if not _mobile_chant_aim_active and Global.active_skill_manager and Global.active_skill_manager.has_method("end_mobile_aim_cast"):
			Global.active_skill_manager.end_mobile_aim_cast()
	if _mobile_skill_long_press_shown:
		hide_active_skill_label()
		_clear_mobile_skill_touch_state()
		return
	if _mobile_skill_cast_consumed:
		_clear_mobile_skill_touch_state()
		return
	if _is_mobile_aim_skill(_mobile_skill_name):
		_mobile_skill_aim_started = true
		_cast_mobile_skill_from_touch()
		_clear_mobile_skill_touch_state()
		return
	_cast_mobile_skill_from_touch()
	_clear_mobile_skill_touch_state()

func _cancel_mobile_skill_touch() -> void:
	hide_active_skill_label()
	if _mobile_skill_aim_started and not _mobile_chant_aim_active and Global.active_skill_manager and Global.active_skill_manager.has_method("end_mobile_aim_cast"):
		_update_mobile_aim_cast()
		Global.active_skill_manager.end_mobile_aim_cast()
	_clear_mobile_skill_indicator()
	_clear_mobile_skill_touch_state()

func _force_clear_mobile_skill_input() -> void:
	hide_active_skill_label()
	_clear_mobile_skill_indicator()
	if Global.active_skill_manager and Global.active_skill_manager.has_method("end_mobile_aim_cast"):
		Global.active_skill_manager.end_mobile_aim_cast()
	_clear_mobile_skill_touch_state()

func _begin_mobile_chant_aim_session() -> void:
	if not Global.is_mobile_input_mode() or not _is_mobile_aim_skill(_mobile_skill_name):
		return
	_mobile_chant_aim_active = true
	_mobile_chant_aim_slot = _mobile_skill_slot
	_mobile_chant_aim_skill = _mobile_skill_name
	_mobile_chant_aim_icon = _mobile_skill_icon
	_mobile_chant_aim_press_position = _mobile_skill_press_position
	_mobile_chant_aim_last_position = _mobile_skill_last_position
	_mobile_chant_point_aim_origin = _mobile_skill_point_aim_origin

func _end_mobile_chant_aim_session() -> void:
	if not _mobile_chant_aim_active:
		return
	if Global.active_skill_manager and Global.active_skill_manager.has_method("end_mobile_aim_cast"):
		Global.active_skill_manager.end_mobile_aim_cast()
	_mobile_chant_aim_active = false
	_mobile_chant_aim_slot = ""
	_mobile_chant_aim_skill = ""
	_mobile_chant_aim_icon = null
	_mobile_chant_aim_press_position = Vector2.ZERO
	_mobile_chant_aim_last_position = Vector2.ZERO
	_mobile_chant_point_aim_origin = Vector2.INF

func _clear_mobile_skill_touch_state() -> void:
	_mobile_skill_touch_active = false
	_mobile_skill_touch_index = -1
	_mobile_skill_slot = ""
	_mobile_skill_name = ""
	_mobile_skill_icon = null
	_mobile_skill_press_position = Vector2.ZERO
	_mobile_skill_last_position = Vector2.ZERO
	_mobile_skill_point_aim_origin = Vector2.INF
	_mobile_skill_press_elapsed = 0.0
	_mobile_skill_long_press_shown = false
	_mobile_skill_aim_started = false
	_mobile_skill_cast_consumed = false
	_mobile_skill_gui_position_is_local = false

func _process_mobile_skill_touch(delta: float) -> void:
	if not _mobile_skill_touch_active:
		return
	if get_tree().paused or Global.in_menu or Global.is_level_up or PC.is_game_over:
		_force_clear_mobile_skill_input()
		return
	if _mobile_skill_aim_started:
		_update_mobile_aim_cast()
		if not _mobile_skill_cast_consumed and not _mobile_chant_aim_active:
			_update_mobile_skill_aim_preview()
	_mobile_skill_press_elapsed += delta
	if not _mobile_skill_long_press_shown and _mobile_skill_press_elapsed >= MOBILE_SKILL_LONG_PRESS_TIME:
		_mobile_skill_long_press_shown = true
		if not _is_mobile_aim_skill(_mobile_skill_name):
			show_active_skill_label(_mobile_skill_slot)

func _is_mobile_skill_ready(skill_name: String) -> bool:
	if Global.active_skill_manager == null:
		return false
	if not Global.active_skill_manager.mastered_skills.has(skill_name):
		return false
	var skill: Object = Global.active_skill_manager.mastered_skills[skill_name] as Object
	if skill == null:
		return false
	return int(skill.get("state")) == 0

func _is_mobile_aim_skill(skill_name: String) -> bool:
	return skill_name == "wind_thunder" or skill_name == "magical_ice" or skill_name == "magical_fire"

func _is_mobile_point_aim_skill(skill_name: String) -> bool:
	return skill_name == "magical_ice" or skill_name == "magical_fire"

func _get_mobile_point_aim_origin_for_touch(skill_name: String, adjusting_chant_aim: bool) -> Vector2:
	if not _is_mobile_point_aim_skill(skill_name):
		return Vector2.INF
	if adjusting_chant_aim and _mobile_chant_point_aim_origin != Vector2.INF:
		return _mobile_chant_point_aim_origin
	var player: Node2D = PC.player_instance as Node2D
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return Vector2.ZERO
	return player.global_position

func _get_mobile_touch_vector() -> Vector2:
	var vector := _mobile_skill_last_position - _mobile_skill_press_position
	if vector.length() < MOBILE_SKILL_AIM_DEADZONE:
		return Vector2.ZERO
	return vector

func _get_mobile_raw_touch_vector() -> Vector2:
	return _mobile_skill_last_position - _mobile_skill_press_position

func _get_mobile_chant_aim_vector() -> Vector2:
	if _mobile_skill_touch_active and _mobile_skill_aim_started:
		return _get_mobile_touch_vector()
	var vector := _mobile_chant_aim_last_position - _mobile_chant_aim_press_position
	if vector.length() < MOBILE_SKILL_AIM_DEADZONE:
		return Vector2.ZERO
	return vector

func _get_mobile_raw_chant_aim_vector() -> Vector2:
	if _mobile_skill_touch_active and _mobile_skill_aim_started:
		return _get_mobile_raw_touch_vector()
	return _mobile_chant_aim_last_position - _mobile_chant_aim_press_position

func _get_mobile_active_aim_skill_name() -> String:
	if _mobile_skill_touch_active and _mobile_skill_aim_started:
		return _mobile_skill_name
	return _mobile_chant_aim_skill

func _can_adjust_mobile_chant_aim(slot_key: String, skill_name: String) -> bool:
	return _mobile_chant_aim_active and _mobile_chant_aim_slot == slot_key and _mobile_chant_aim_skill == skill_name

func _get_mobile_chant_aim_press_position(icon: TextureButton, skill_name: String) -> Vector2:
	if _mobile_chant_aim_active and _mobile_chant_aim_skill == skill_name and _mobile_chant_aim_press_position != Vector2.ZERO:
		return _mobile_chant_aim_press_position
	return _get_mobile_skill_icon_center(icon)

func _get_mobile_skill_direction(default_to_facing: bool = true) -> Vector2:
	var vector := _get_mobile_chant_aim_vector() if _mobile_chant_aim_active else _get_mobile_touch_vector()
	if vector.length() > 0.01:
		return vector.normalized()
	if default_to_facing and PC.player_instance and PC.player_instance.has_method("get_facing_direction"):
		return PC.player_instance.get_facing_direction()
	return Vector2.RIGHT

func _get_mobile_skill_target() -> Vector2:
	var player: Node2D = PC.player_instance as Node2D
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return Vector2.ZERO
	var aim_skill_name := _get_mobile_active_aim_skill_name()
	var is_point_skill: bool = _is_mobile_point_aim_skill(aim_skill_name)
	var vector: Vector2 = _get_mobile_raw_chant_aim_vector() if (_mobile_chant_aim_active and is_point_skill) else (_get_mobile_raw_touch_vector() if is_point_skill else (_get_mobile_chant_aim_vector() if _mobile_chant_aim_active else _get_mobile_touch_vector()))
	var origin: Vector2 = player.global_position
	if is_point_skill:
		if _mobile_skill_touch_active and _mobile_skill_aim_started and _mobile_skill_point_aim_origin != Vector2.INF:
			origin = _mobile_skill_point_aim_origin
		elif _mobile_chant_aim_active and _mobile_chant_point_aim_origin != Vector2.INF:
			origin = _mobile_chant_point_aim_origin
	var target: Vector2 = origin
	if vector.length() <= 0.01:
		return _clamp_mobile_point_skill_target(target, _get_mobile_point_skill_indicator_size(aim_skill_name))
	var aim_range: float = MOBILE_POINT_SKILL_AIM_WORLD_RANGE if is_point_skill else MOBILE_SKILL_AIM_WORLD_RANGE
	var screen_range: float = MOBILE_POINT_SKILL_AIM_SCREEN_RANGE if is_point_skill else MOBILE_SKILL_AIM_SCREEN_RANGE
	var distance_ratio: float = clampf(vector.length() / screen_range, 0.0, 1.0)
	var distance: float = aim_range * distance_ratio
	target = origin + vector.normalized() * distance
	if is_point_skill:
		return _clamp_mobile_point_skill_target(target, _get_mobile_point_skill_indicator_size(aim_skill_name))
	return target

func _get_mobile_point_skill_indicator_size(skill_name: String) -> Vector2:
	var size := Vector2(90, 65)
	var manager_skill: Object = null
	if Global.active_skill_manager and Global.active_skill_manager.mastered_skills.has(skill_name):
		manager_skill = Global.active_skill_manager.mastered_skills[skill_name] as Object
	if manager_skill != null and manager_skill.get("indicator_size") != null:
		size = manager_skill.get("indicator_size")
	return size * MOBILE_POINT_SKILL_EFFECT_SCALE

func _clamp_mobile_point_skill_target(target: Vector2, indicator_size: Vector2) -> Vector2:
	var visible_rect := _get_mobile_visible_world_rect()
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return target
	var half_size := indicator_size * 0.5
	var min_x := visible_rect.position.x + half_size.x
	var max_x := visible_rect.position.x + visible_rect.size.x - half_size.x
	var min_y := visible_rect.position.y + half_size.y
	var max_y := visible_rect.position.y + visible_rect.size.y - half_size.y
	var clamped := target
	clamped.x = (visible_rect.position.x + visible_rect.size.x * 0.5) if min_x > max_x else clampf(target.x, min_x, max_x)
	clamped.y = (visible_rect.position.y + visible_rect.size.y * 0.5) if min_y > max_y else clampf(target.y, min_y, max_y)
	return clamped

func _get_mobile_visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var viewport_size := viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d()
	if camera == null and PC.player_instance and is_instance_valid(PC.player_instance):
		camera = PC.player_instance.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		var fallback_center := Vector2.ZERO
		if PC.player_instance and is_instance_valid(PC.player_instance):
			fallback_center = PC.player_instance.global_position
		return Rect2(fallback_center - viewport_size * 0.5, viewport_size)
	var zoom_value := camera.zoom
	var half_size := Vector2(
		viewport_size.x / max(zoom_value.x, 0.01),
		viewport_size.y / max(zoom_value.y, 0.01)
	) * 0.5
	var center := camera.get_screen_center_position()
	return Rect2(center - half_size, half_size * 2.0)

func _update_mobile_skill_aim_preview() -> void:
	var player: Node2D = PC.player_instance as Node2D
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	var SkillIndicator = preload("res://Script/skill/skill_indicator.gd")
	if not is_instance_valid(_mobile_skill_indicator):
		_mobile_skill_indicator = SkillIndicator.new()
		get_tree().current_scene.add_child(_mobile_skill_indicator)
	if _mobile_skill_name == "wind_thunder":
		var direction := _get_mobile_skill_direction()
		if _mobile_skill_indicator.has_method("setup_line_fixed"):
			_mobile_skill_indicator.setup_line_fixed(player, direction)
		elif _mobile_skill_indicator.has_method("set_fixed_direction"):
			_mobile_skill_indicator.set_fixed_direction(direction)
	elif _is_mobile_point_aim_skill(_mobile_skill_name):
		var target := _get_mobile_skill_target()
		var size := _get_mobile_point_skill_indicator_size(_mobile_skill_name)
		if _mobile_skill_indicator.has_method("setup_circle_fixed"):
			_mobile_skill_indicator.setup_circle_fixed(player, size, target)
		elif _mobile_skill_indicator.has_method("set_fixed_target_position"):
			_mobile_skill_indicator.set_fixed_target_position(target)

func _update_mobile_aim_cast() -> void:
	if not Global.active_skill_manager or not Global.active_skill_manager.has_method("update_mobile_aim_cast"):
		return
	var direction := Vector2.ZERO
	var target := Vector2.INF
	var aim_skill_name := _get_mobile_active_aim_skill_name()
	if aim_skill_name == "wind_thunder":
		direction = _get_mobile_skill_direction()
	elif _is_mobile_point_aim_skill(aim_skill_name):
		target = _get_mobile_skill_target()
	Global.active_skill_manager.update_mobile_aim_cast(direction, target)

func _get_mobile_aim_state() -> Dictionary:
	var aim_state: Dictionary = {
		"active": (_mobile_skill_touch_active and _mobile_skill_aim_started) or _mobile_chant_aim_active,
		"direction": Vector2.ZERO,
		"target": Vector2.INF,
	}
	var aim_skill_name := _get_mobile_active_aim_skill_name()
	if aim_skill_name == "wind_thunder":
		aim_state["direction"] = _get_mobile_skill_direction()
	elif _is_mobile_point_aim_skill(aim_skill_name):
		aim_state["target"] = _get_mobile_skill_target()
	return aim_state

func _clear_mobile_skill_indicator() -> void:
	if is_instance_valid(_mobile_skill_indicator):
		_mobile_skill_indicator.queue_free()
	_mobile_skill_indicator = null

func _fade_mobile_skill_indicator() -> void:
	if is_instance_valid(_mobile_skill_indicator) and _mobile_skill_indicator.has_method("freeze_and_fade"):
		_mobile_skill_indicator.freeze_and_fade(0.3)
	_mobile_skill_indicator = null

func _cast_mobile_skill_from_touch() -> void:
	if not Global.active_skill_manager:
		return
	if _mobile_skill_cast_consumed:
		return
	var direction := Vector2.ZERO
	var target := Vector2.INF
	if _mobile_skill_name == "dodge":
		direction = Input.get_vector("left", "right", "up", "down")
		if direction.length() <= 0.01:
			direction = _get_mobile_skill_direction()
	elif _mobile_skill_name == "wind_thunder":
		direction = _get_mobile_skill_direction()
	elif _is_mobile_point_aim_skill(_mobile_skill_name):
		target = _get_mobile_skill_target()
	if _is_mobile_aim_skill(_mobile_skill_name):
		_clear_mobile_skill_indicator()
		_begin_mobile_chant_aim_session()
		if Global.active_skill_manager.has_method("begin_mobile_aim_cast"):
			Global.active_skill_manager.begin_mobile_aim_cast(direction, target, Callable(self , "_get_mobile_aim_state"))
	if Global.active_skill_manager.has_method("use_skill_with_mobile_aim"):
		Global.active_skill_manager.use_skill_with_mobile_aim(_mobile_skill_name, direction, target)
	else:
		Global.active_skill_manager.use_skill(_mobile_skill_name)
	_mobile_skill_cast_consumed = true

## 构建疗愈技能详情文本
func _build_heal_hot_skill_text(level: int) -> String:
	var text = "[font_size=24]疗愈  LV. " + str(level) + "[/font_size]\n"
	text += "持续恢复自身体力\n\n"
	
	# 计算持续时间
	var duration = 12.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			duration += 1.0
	text += "持续时间：" + ("%.1f" % duration) + "秒\n"
	
	# 计算回复量
	var heal_base = 30.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			heal_base += 10.0
	text += "基础回复：" + ("%.0f" % heal_base) + "点\n"
	
	# 计算冷却时间
	var cooldown = 30.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(5.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建水幕护体技能详情文本
func _build_water_shield_skill_text(level: int) -> String:
	var text = "[font_size=24]水幕护体  LV. " + str(level) + "[/font_size]\n"
	text += "释放水幕，获得护盾并提升减伤\n\n"
	
	# 计算护盾比例
	var shield_percent = 10.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			shield_percent += 1.0
	text += "护盾量：" + ("%.0f" % shield_percent) + "%最大体力\n"
	
	# 计算减伤
	var dr = 20.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			dr += 3.0
	text += "减伤率：" + ("%.0f" % dr) + "%\n"
	
	# 计算冷却时间
	var cooldown = 15.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 0.5
	cooldown = max(3.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建神圣灼烧技能详情文本
func _build_holy_fire_skill_text(level: int) -> String:
	var text = "[font_size=24]神圣灼烧  LV. " + str(level) + "[/font_size]\n"
	text += "持续对自身周围造成伤害并回血\n\n"
	
	# 计算伤害比率
	var damage_ratio = 30.0
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			damage_ratio += 4.0
	text += "伤害：" + ("%.0f" % damage_ratio) + "%攻击力/0.5秒\n"
	
	# 计算持续时间
	var duration = 5.0
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			duration += 0.5
	text += "持续时间：" + ("%.1f" % duration) + "秒\n"
	
	# 计算冷却时间
	var cooldown = 24.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(4.0, cooldown)
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建风雷破技能详情文本
func _build_wind_thunder_skill_text(level: int) -> String:
	var text = "[font_size=24]风雷破  LV. " + str(level) + "[/font_size]\n"
	text += "咏唱后向鼠标方向发射风雷弹\n击中敌人造成大范围爆炸\n\n"
	text += "咏唱时间：1.2秒\n"
	text += "伤害：275%攻击力\n"
	var cooldown = 12.0
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建玄冰技能详情文本
func _build_magical_ice_skill_text(level: int) -> String:
	var damage_ratio = 360.0
	var chant_time = 1.5
	var cooldown = 15.0
	var final_cooldown = cooldown * (1 - PC.cooldown)
	var text = "[font_size=24]玄冰  LV. " + str(level) + "[/font_size]\n"
	text += "咏唱后对鼠标位置释放玄冰阵\n对范围内敌人造成伤害并减速\n\n"
	text += "咏唱时间：" + ("%.1f" % chant_time) + "秒\n"
	text += "伤害：" + ("%.0f" % damage_ratio) + "%攻击力\n"
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建炽炎技能详情文本
func _build_magical_fire_skill_text(level: int) -> String:
	var damage_ratio = 220.0
	var chant_time = 1.2
	var cooldown = 2.5
	var final_cooldown = cooldown * (1 - PC.cooldown)
	var text = "[font_size=24]炽炎  LV. " + str(level) + "[/font_size]\n"
	text += "咏唱后对鼠标位置释放炽炎\n对范围内敌人造成伤害\n\n"
	text += "咏唱时间：" + ("%.1f" % chant_time) + "秒\n"
	text += "伤害：" + ("%.0f" % damage_ratio) + "%攻击力\n"
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建魔纹阵技能详情文本
func _build_magic_skill_text(level: int) -> String:
	var duration = 15.0
	var cooldown = 40.0
	var final_cooldown = cooldown * (1 - PC.cooldown)
	var text = "[font_size=24]魔纹阵  LV. " + str(level) + "[/font_size]\n"
	text += "立即在脚下展开魔纹阵\n刷新其他技能冷却\n\n"
	text += "范围内效果：\n"
	text += "· 攻击速度提升25%\n"
	text += "· 咏唱技能冷却加速100%\n"
	text += "· 咏唱时间缩短50%\n\n"
	text += "持续时间：" + ("%.0f" % duration) + "秒\n"
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建冒想技能详情文本
func _build_meditation_skill_text(level: int) -> String:
	var chant_time = 3.0
	var cooldown = 60.0
	var final_cooldown = cooldown * (1 - PC.cooldown)
	var text = "[font_size=24]冥想  LV. " + str(level) + "[/font_size]\n"
	text += "咏唱后提升1级\n\n"
	text += "咏唱时间：" + ("%.1f" % chant_time) + "秒\n"
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建破坏乱锤技能详情文本
func _build_destructive_hammer_skill_text(level: int) -> String:
	var cooldown = 18.0
	var final_cooldown = cooldown * (1 - PC.cooldown)
	var text = "[font_size=24]破坏乱锤  LV. " + str(level) + "[/font_size]\n"
	text += "连续三次砸下巨锤\n对范围内敌人造成伤害\n\n"
	text += "前两次锤击：60%攻击力\n"
	text += "第三次锤击：120%攻击力\n"
	text += "施放期间获得40%独立减伤\n"
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	return text

## 构建迷踪步技能详情文本
func _build_mizongbu_skill_text(level: int) -> String:
	return "[font_size=24]迷踪步  LV. " + str(level) + "[/font_size]\n短时间提升移速并减伤，期间造成伤害降低20%"

## 构建魔化技能详情文本
func _build_beastify_skill_text(level: int) -> String:
	return "[font_size=24]魔化  LV. " + str(level) + "[/font_size]\n短时间提升属性并将剑气改为爪击"

## 构建闪避技能详情文本
func _build_dodge_skill_text(level: int) -> String:
	var text = "[font_size=24]闪避  LV. " + str(level) + "[/font_size]\n"
	text += "向移动方向位移一小段距离并获得无敌\n"
	text += "随着移速增加，位移距离也会少量增加\n\n"
	
	# 计算当前无敌时间
	var invincible_time = 0.5
	for lv in [2, 4, 6, 8, 10, 12, 14]:
		if level >= lv:
			invincible_time += 0.1
	text += "无敌时间：" + ("%.1f" % invincible_time) + "秒\n"
	
	# 计算当前冷却时间
	var cooldown = 6.0
	for lv in [3, 5, 7, 9, 11, 13, 15]:
		if level >= lv:
			cooldown -= 0.5
	cooldown = max(1.0, cooldown)
	# 应用冷却缩减
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	if PC.cooldown > 0:
		text += " [color=#88ff88](-" + str(int(PC.cooldown * 100)) + "%)[/color]"
	
	return text

## 构建乱击技能详情文本
func _build_random_strike_skill_text(level: int) -> String:
	var text = "[font_size=24]乱击  LV. " + str(level) + "[/font_size]\n"
	text += "向随机方向每0.1秒射出剑气\n\n"
	
	# 计算当前伤害倍率
	var damage_multi = 50
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			damage_multi += 5
	text += "伤害倍率：" + str(damage_multi) + "%\n"
	
	# 计算当前子弹数量
	var bullet_count = 10
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			bullet_count += 1
	text += "剑气数量：" + str(bullet_count) + "发\n"
	
	# 计算当前冷却时间
	var cooldown = 20.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(5.0, cooldown)
	# 应用冷却缩减
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	if PC.cooldown > 0:
		text += " [color=#88ff88](-" + str(int(PC.cooldown * 100)) + "%)[/color]"
	
	return text

func _init_active_skills() -> void:
	"""初始化主动技能UI"""
	# 加载主动技能图标脚本
	var active_skill_script = preload("res://Script/skill/active_skill_icon.gd")
	
	# 配置三个主动技能槽位：空格、Q、E
	if active1:
		# 替换脚本
		active1.set_script(active_skill_script)
		# 调用_ready模拟初始化
		if active1.has_method("_setup_ui_nodes"):
			active1._setup_ui_nodes()
		if active1.has_method("setup_active_skill"):
			active1.setup_active_skill("space", _get_active_skill_button_text("space", "Space"))
		active1.visible = _has_skill_in_slot("space")
	
	if active2:
		active2.set_script(active_skill_script)
		if active2.has_method("_setup_ui_nodes"):
			active2._setup_ui_nodes()
		if active2.has_method("setup_active_skill"):
			active2.setup_active_skill("q", _get_active_skill_button_text("q", "Q"))
		active2.visible = _has_skill_in_slot("q")
	
	if active3:
		active3.set_script(active_skill_script)
		if active3.has_method("_setup_ui_nodes"):
			active3._setup_ui_nodes()
		if active3.has_method("setup_active_skill"):
			active3.setup_active_skill("e", _get_active_skill_button_text("e", "E"))
		active3.visible = _has_skill_in_slot("e")

func _get_active_skill_button_text(slot: String, pc_text: String) -> String:
	if not Global.is_mobile_input_mode():
		return pc_text
	var skill_config: Dictionary = Global.get_current_active_skills().get(slot, {})
	var skill_name: String = skill_config.get("name", "")
	return _get_active_skill_display_name(skill_name)

func _get_active_skill_display_name(skill_id: String) -> String:
	match skill_id:
		"dodge":
			return "闪避"
		"mizongbu":
			return "迷踪步"
		"random_strike":
			return "乱击"
		"beastify":
			return "兽化"
		"heal_hot":
			return "疗愈"
		"water_sheild":
			return "水幕护体"
		"holy_fire":
			return "神圣灼烧"
		"wind_thunder":
			return "风雷破"
		"magical_ice":
			return "玄冰"
		"magical_fire":
			return "炽炎"
		"magic":
			return "魔纹阵"
		"meditation":
			return "冥想"
		"destructive_hammer":
			return "破坏乱锤"
		_:
			return skill_id

func _has_skill_in_slot(slot: String) -> bool:
	"""检查槽位是否有技能"""
	var skill_config: Dictionary = Global.get_current_active_skills().get(slot, {})
	return skill_config.get("name", "") != ""


func refresh_active_skills() -> void:
	"""刷新主动技能UI（当技能配置变化时调用）"""
	_init_active_skills()

# ============== UI 更新方法 ==============

## 更新血条
func update_hp_bar(current_hp: int, max_hp: int, current_shield: int) -> void:
	var target_value = (float(current_hp) / max_hp) * 100
	if hp_bar.value != target_value:
		if abs(target_value - hp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(hp_bar, "value", target_value, 0.15)
		else:
			hp_bar.value = target_value
	
	var shield_display = min(current_shield, max_hp)
	var shield_target_value = (float(shield_display) / max_hp) * 100
	if sheild_bar.value != shield_target_value:
		if abs(shield_target_value - sheild_bar.value) > 2:
			var shield_tween = create_tween()
			shield_tween.tween_property(sheild_bar, "value", shield_target_value, 0.15)
		else:
			sheild_bar.value = shield_target_value
	
	var hp_value = current_hp
	if current_hp <= 0:
		hp_value = 0
	
	if current_shield > 0:
		hp_num.text = str(hp_value) + " (+" + str(current_shield) + ") / " + str(max_hp)
	else:
		hp_num.text = str(hp_value) + " / " + str(max_hp)

## 更新经验条
func update_exp_bar(current_exp: int, required_exp: int) -> void:
	var target_value = (float(current_exp) / required_exp) * 100
	if exp_bar.value != target_value:
		if abs(target_value - exp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(exp_bar, "value", target_value, 0.15)
		else:
			exp_bar.value = target_value

## 更新机关进度条
func update_mechanism_bar(current_value: float, max_value: float, is_boss_triggered: bool = false) -> void:
	if not is_boss_triggered:
		map_mechanism_bar.value = (current_value / max_value) * 100
	else:
		map_mechanism_bar.value = 100

## 更新时间显示
func update_time_display(real_time: float) -> void:
	if now_time:
		var display_time := Global.get_battle_display_time(real_time)
		var minutes = int(display_time / 60.0)
		var seconds = int(display_time) % 60
		now_time.text = "%02d : %02d" % [minutes, seconds]
	if _attr_label_open and attr_label != null and attr_label.visible and (attr_label_tween == null or not attr_label_tween.is_valid()):
		show_attr_label()

## 更新等级显示
func update_level_display(level: int) -> void:
	now_lv.text = "Lv." + str(level)

## 更新分数显示
func update_score_display(point: int, spirit: int = 0) -> void:
	var formatted_spirit: String
	if spirit >= 10000000:
		formatted_spirit = "%.3fm" % (spirit / 1000000.0)
	elif spirit >= 100000:
		formatted_spirit = "%.2fk" % (spirit / 1000.0)
	else:
		formatted_spirit = str(spirit)
	var formatted_point: String
	if point >= 10000000:
		formatted_point = "%.3fm" % (point / 1000000.0)
	elif point >= 100000:
		formatted_point = "%.2fk" % (point / 1000.0)
	else:
		formatted_point = str(point)
	score_label.text = formatted_spirit + "\n" + formatted_point

## 更新DPS显示
func update_dps_display() -> void:
	var current_dps = DpsManager.get_current_total_dps()
	var _formatted_dps = "%.1f" % current_dps
	#current_multi.text = "DPS: " + _formatted_dps

## 更新升级选择UI可见性
func update_lv_up_visibility() -> void:
	if Global.is_level_up == false:
		lv_up_change.visible = false

# ============== 技能图标更新 ==============

## 初始化主技能图标
func init_main_skill(fire_speed_wait_time: float) -> void:
	if not PC.selected_rewards.has("SwordQi"):
		skill1.visible = false
		skill1.get_node("Timer").stop()
		return
	skill1.visible = true
	skill1.update_skill(1, fire_speed_wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/jianqi.png")

## 检查并更新技能图标可见性
func check_and_update_skill_icons(player_node: Node) -> void:
	if not has_meta("_qigong_debug_done"):
		set_meta("_qigong_debug_done", true)
		print("[Qigong DEBUG] check_and_update_skill_icons ENTERED. rewards=%s, player=%s, first_has_qigong=%s" % [str(PC.selected_rewards), PC.player_name, PC.first_has_qigong])
	if PC.selected_rewards.has("Swordqi") and PC.first_has_swordqi:
		skill1.visible = true
		skill1.update_skill(1, player_node.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/jianqi.png")
		PC.first_has_swordqi = false

	if PC.selected_rewards.has("Branch") and PC.first_has_branch:
		skill2.visible = true
		skill2.update_skill(2, player_node.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xianzhi.png")
		PC.first_has_branch = false

	if PC.selected_rewards.has("Moyan") and PC.first_has_moyan:
		skill3.visible = true
		skill3.update_skill(3, player_node.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yunshi.png")
		PC.first_has_moyan = false

	if PC.selected_rewards.has("Riyan") and PC.first_has_riyan:
		skill4.visible = true
		skill4.update_skill(4, player_node.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png")
		PC.first_has_riyan = false

	if PC.selected_rewards.has("Ringfire") and PC.first_has_ringFire:
		skill5.visible = true
		_set_ring_fire_static_icon()
		Global.emit_signal("ringFire_damage_triggered")
		PC.first_has_ringFire = false

	if PC.selected_rewards.has("Thunder") and PC.first_has_thunder:
		skill6.visible = true
		skill6.update_skill(6, player_node.thunder_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/thunder.png")
		PC.first_has_thunder = false

	if PC.selected_rewards.has("Bloodwave") and not skill7.visible:
		skill7.visible = true
		skill7.update_skill(7, player_node.bloodwave_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xueqibo.png")
	
	if PC.selected_rewards.has("Bloodboardsword") and PC.first_has_bloodboardsword:
		skill8.visible = true
		skill8.update_skill(8, player_node.bloodboardsword_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yinxue.png")
		PC.first_has_bloodboardsword = false
	
	if PC.selected_rewards.has("Ice") and not skill9.visible:
		skill9.visible = true
		skill9.update_skill(9, player_node.ice_flower_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/binghua.png")
	
	if PC.selected_rewards.has("Thunderbreak") and PC.first_has_thunder_break:
		skill10.visible = true
		skill10.update_skill(10, player_node.thunder_break_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/tianleipo2.png")
		PC.first_has_thunder_break = false
	
	if PC.selected_rewards.has("Lightbullet") and PC.first_has_light_bullet:
		skill11.visible = true
		skill11.update_skill(11, player_node.light_bullet_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/guangdan.png")
		PC.first_has_light_bullet = false
	
	if PC.selected_rewards.has("Water") and PC.first_has_water:
		skill12.visible = true
		skill12.update_skill(12, player_node.water_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/kanshui.png")
		PC.first_has_water = false
	
	if PC.selected_rewards.has("Qiankun") and not skill13.visible:
		skill13.visible = true
		skill13.update_skill(13, player_node.qiankun_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qiankun.png")
	
	if PC.selected_rewards.has("Xuanwu") and not skill14.visible:
		skill14.visible = true
		skill14.update_skill(14, player_node.xuanwu_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xuanwu.png")
	
	if PC.selected_rewards.has("Xunfeng") and not skill15.visible:
		skill15.visible = true
		skill15.update_skill(15, player_node.xunfeng_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xunfeng.png")
	
	if PC.selected_rewards.has("Genshan") and PC.first_has_genshan:
		skill16.visible = true
		skill16.update_skill(16, player_node.genshan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/genshan.png")
		PC.first_has_genshan = false
	
	if PC.selected_rewards.has("Duize") and PC.first_has_duize:
		skill17.visible = true
		skill17.update_skill(17, player_node.duize_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/duize.png")
		PC.first_has_duize = false
	
	if PC.selected_rewards.has("Holylight") and PC.first_has_holylight:
		skill18.visible = true
		skill18.update_skill(18, player_node.holy_light_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png")
		PC.first_has_holylight = false
	
	if PC.selected_rewards.has("Qigong") and PC.first_has_qigong:
		print("[Qigong] skill19 init: wait_time=%s" % player_node.qigong_fire_speed.wait_time)
		skill19.visible = true
		skill19.update_skill(19, player_node.qigong_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qigong.png")
		PC.first_has_qigong = false

	if PC.selected_rewards.has("Dragonwind") and PC.first_has_dragonwind:
		skill20.visible = true
		skill20.update_skill(20, player_node.dragonwind_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/fenglongzhang.png")
		PC.first_has_dragonwind = false

	if PC.selected_rewards.has("Zhuazhuajuchui") and PC.first_has_zhuazhuajuchui:
		skill21.visible = true
		skill21.update_skill(21, player_node.zhuazhuajuchui_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/zhuazhuachui.png")
		PC.first_has_zhuazhuajuchui = false


## 更新技能冷却时间显示
func update_skill_cooldowns(player_node: Node) -> void:
	if PC.selected_rewards.has("Swordqi") and skill1.visible:
		skill1.update_skill(1, player_node.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/jianqi.png") # update
	
	if PC.selected_rewards.has("Branch") and skill2.visible:
		skill2.update_skill(2, player_node.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xianzhi.png") # update
	
	if PC.selected_rewards.has("Moyan") and skill3.visible:
		skill3.update_skill(3, player_node.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yunshi.png") # update
	
	if PC.selected_rewards.has("Riyan") and skill4.visible:
		skill4.update_skill(4, player_node.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png") # update
	
	if PC.selected_rewards.has("Ringfire") and skill5.visible:
		_set_ring_fire_static_icon()
	
	if PC.selected_rewards.has("Thunder") and skill6.visible:
		skill6.update_skill(6, player_node.thunder_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/thunder.png")
	
	if PC.selected_rewards.has("Bloodwave") and skill7.visible:
		skill7.update_skill(7, player_node.bloodwave_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xueqibo.png")
	
	if PC.selected_rewards.has("Bloodboardsword") and skill8.visible:
		skill8.update_skill(8, player_node.bloodboardsword_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yinxue.png")

	if PC.selected_rewards.has("Ice") and skill9.visible:
		skill9.update_skill(9, player_node.ice_flower_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/binghua.png") # update
		
	if PC.selected_rewards.has("Thunderbreak") and skill10.visible:
		skill10.update_skill(10, player_node.thunder_break_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/tianleipo2.png") # update
		
	if PC.selected_rewards.has("Lightbullet") and skill11.visible:
		skill11.update_skill(11, player_node.light_bullet_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/guangdan.png") # update
		
	if PC.selected_rewards.has("Water") and skill12.visible:
		skill12.update_skill(12, player_node.water_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/kanshui.png") # update
		
	if PC.selected_rewards.has("Qiankun") and skill13.visible:
		skill13.update_skill(13, player_node.qiankun_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qiankun.png") # update
		
	if PC.selected_rewards.has("Xuanwu") and skill14.visible:
		skill14.update_skill(14, player_node.xuanwu_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xuanwu.png") # update
		
	if PC.selected_rewards.has("Xunfeng") and skill15.visible:
		skill15.update_skill(15, player_node.xunfeng_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xunfeng.png")
		
	if PC.selected_rewards.has("Genshan") and skill16.visible:
		skill16.update_skill(16, player_node.genshan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/genshan.png")

	if PC.selected_rewards.has("Duize") and skill17.visible:
		skill17.update_skill(17, player_node.duize_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/duize.png") # update

	if PC.selected_rewards.has("Holylight") and skill18.visible:
		skill18.update_skill(18, player_node.holy_light_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png") # update

	if PC.selected_rewards.has("Qigong") and skill19.visible:
		skill19.update_skill(19, player_node.qigong_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qigong.png")

	if PC.selected_rewards.has("Dragonwind") and skill20.visible:
		skill20.update_skill(20, player_node.dragonwind_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/fenglongzhang.png") # update

	if PC.selected_rewards.has("Zhuazhuajuchui") and skill21.visible:
		skill21.update_skill(21, player_node.zhuazhuajuchui_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/zhuazhuachui.png")

func stop_all_skill_cooldowns() -> void:
	skill1.stop_cooldown()
	skill2.stop_cooldown()
	skill3.stop_cooldown()
	skill4.stop_cooldown()
	skill5.stop_cooldown()
	skill6.stop_cooldown()
	skill7.stop_cooldown()
	skill8.stop_cooldown()
	skill9.stop_cooldown()
	skill10.stop_cooldown()
	skill11.stop_cooldown()
	skill12.stop_cooldown()
	skill13.stop_cooldown()
	skill14.stop_cooldown()
	skill15.stop_cooldown()
	skill16.stop_cooldown()
	skill17.stop_cooldown()
	skill18.stop_cooldown()
	skill19.stop_cooldown()
	skill20.stop_cooldown()
	skill21.stop_cooldown()

func _set_ring_fire_static_icon() -> void:
	skill5.visible = true
	if skill5.has_method("set_static_skill"):
		skill5.call("set_static_skill", 5, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/lihuo.png")
	else:
		skill5.stop_cooldown()

func _on_skill_attack_speed_updated() -> void:
	# 需要获取player节点来更新，通过信号通知父场景
	if PC.player_instance:
		update_skill_cooldowns(PC.player_instance)

# ============== 属性标签显示 ==============

# 属性标签过渡动画 Tween
var attr_label_tween: Tween = null
var _attr_label_open: bool = false

func _format_attr_bonus_percent(value: float) -> String:
	var percent := int(round(value * 100.0))
	if percent > 0:
		return "+%d%%" % percent
	return "%d%%" % percent

func _get_attr_panel_final_damage_bonus() -> float:
	return Faze.get_final_damage_multiplier() * BulletCalculator.get_global_buff_damage_multiplier() * PC.damage_deal_multiplier - 1.0

func _get_attr_panel_heal_bonus() -> float:
	var bonus := PC.heal_multi
	if Global.is_current_poetry_difficulty():
		bonus -= 1.0 - Global.get_poetry_heal_shield_multiplier()
	return bonus

func _get_attr_panel_shield_bonus() -> float:
	var bonus := PC.sheild_multi
	if Global.is_current_poetry_difficulty():
		bonus -= 1.0 - Global.get_poetry_heal_shield_multiplier()
	return bonus

func show_attr_label() -> void:
	_attr_label_open = true
	var was_visible := attr_label.visible
	# 停止之前的动画
	if attr_label_tween and attr_label_tween.is_valid():
		attr_label_tween.kill()
	
	# 构建美化的属性文本
	var text = ""
	
	# ===== 基本属性 =====
	text += "\n[font_size=21][color=#87CEEB]═══ 基本属性 ═══[/color][/font_size]\n"
	text += "攻击：" + str(PC.pc_atk) + "    "
	text += "HP：" + str(PC.pc_hp) + "/" + str(PC.pc_max_hp) + "\n"
	text += "护甲：" + str(int(PC.pc_armor)) + "（%.2f%%）\n" % (PC.pc_armor / (PC.pc_armor + 500.0) * 100.0)
	text += "攻击速度：+" + str(int(PC.pc_atk_speed * 100)) + "%    "
	var total_move_speed = PC.pc_speed + Global.cultivation_zhuifeng_level * 0.01 + Global.study_move_speed_bonus
	text += "移动速度：+" + str(int(total_move_speed * 100)) + "%\n"
	text += "暴击率：" + str(int(PC.crit_chance * 100)) + "%    "
	text += "暴击伤害：" + str(int(PC.crit_damage_multi * 100)) + "%\n"
	text += "最终伤害：" + _format_attr_bonus_percent(_get_attr_panel_final_damage_bonus()) + "\n"
	text += "减伤率：" + str(int(PC.damage_reduction_rate * 100)) + "%    "
	text += "天命：" + str(PC.now_lunky_level) + "\n"
	
	# ===== 次要属性 =====
	text += "[font_size=21][color=#98FB98]═══ 次要属性 ═══[/color][/font_size]\n"
	text += "伤害范围：+" + str(int((Global.get_attack_range_multiplier() - 1.0) * 100)) + "%    "
	text += "体型大小：" + str(int(PC.body_size * 100)) + "%\n"
	text += "真气获取：+" + str(int(PC.point_multi * 100)) + "%    "
	text += "精魄获取：+" + str(int(PC.spirit_multi * 100)) + "%\n"
	text += "经验获取：+" + str(int(PC.exp_multi * 100)) + "%    "
	text += "掉落率：+" + str(int(PC.drop_multi * 100)) + "%    \n"
	text += "治疗加成：" + _format_attr_bonus_percent(_get_attr_panel_heal_bonus()) + "    "
	text += "护盾加成：" + _format_attr_bonus_percent(_get_attr_panel_shield_bonus()) + "\n"
	text += "对小怪增伤：+" + str(int(PC.normal_monster_multi * 100)) + "%    "
	text += "对精英首领增伤：+" + str(int(PC.boss_multi * 100)) + "%\n"
	text += "技能冷却缩减：" + str(int(PC.cooldown * 100)) + "%    "
	text += "技能增伤：+" + str(int(PC.active_skill_multi * 100)) + "%\n"
	
	# ===== 领悟概率 =====
	var _red_p: float = clampf(PC.now_red_p, 0.0, 100.0)
	var _gold_p: float = clampf(PC.now_gold_p, 0.0, 100.0 - _red_p)
	var _darkorchid_p: float = clampf(PC.now_darkorchid_p, 0.0, 100.0 - _red_p - _gold_p)
	var _blue_p: float = maxf(0.0, 100.0 - _red_p - _gold_p - _darkorchid_p)
	text += "[font_size=21][color=#FFD700]═══ 领悟出现概率 ═══[/color][/font_size]\n"
	text += "[color=#87CEEB]通明[/color]：" + "%.1f" % _blue_p + "%    "
	text += "[color=#DA70D6]悟道[/color]：" + "%.1f" % _darkorchid_p + "%\n"
	text += "[color=#FFD700]臻境[/color]：" + "%.1f" % _gold_p + "%    "
	text += "[color=#FF4444]逆天[/color]：" + "%.1f" % _red_p + "%\n"
	
	# # ===== 技艺 =====
	# if PC.ring_bullet_enabled or PC.wave_bullet_enabled:
	# 	text += "[font_size=21][color=#DDA0DD]═══ 技艺 ═══[/color][/font_size]\n"
	# 	# 技艺·环
	# 	if PC.ring_bullet_enabled:
	# 		text += "[color=#FFB6C1]【环】[/color] "
	# 		text += "伤害：" + str(int(PC.ring_bullet_damage_multiplier * 100)) + "%  "
	# 		text += "数量：" + str(PC.ring_bullet_count) + "  "
	# 		text += "大小：" + str(int(PC.ring_bullet_size_multiplier * 100)) + "%  "
	# 		text += "间隔：" + ("%.2f" % PC.ring_bullet_interval) + "秒\n"
	# 	# 技艺·浪
	# 	if PC.wave_bullet_enabled:
	# 		text += "[color=#87CEFA]【浪】[/color] "
	# 		text += "伤害：" + str(int(PC.wave_bullet_damage_multiplier * 100)) + "%  "
	# 		text += "数量：" + str(PC.wave_bullet_count) + "  "
	# 		text += "间隔：" + ("%.2f" % PC.wave_bullet_interval) + "秒\n"
	
	# ===== 召唤物 =====
	if PC.summon_count > 0 or PC.summon_count_max > 0:
		text += "[font_size=21][color=#E2CBF7]═══ 召唤物 ═══[/color][/font_size]\n"
		text += "当前数量：" + str(PC.summon_count) + "/" + str(PC.summon_count_max) + "    "
		text += "伤害倍率：" + str(int(PC.summon_damage_multiplier * 100)) + "%\n"
		text += "弹体大小：" + str(int(PC.summon_bullet_size_multiplier * 100)) + "%    "
		text += "攻击间隔倍率：" + str(int(PC.summon_interval_multiplier * 100)) + "%\n"
	
	attr_label.text = text + "\n"
	
	# 设置初始透明度并显示
	if not attr_label.visible:
		attr_label.modulate.a = 0.0
		attr_label.visible = true
	if was_visible:
		attr_label.modulate.a = 1.0
		return
	
	# 渐入动画
	attr_label_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	attr_label_tween.tween_property(attr_label, "modulate:a", 1.0, 0.3)

func hide_attr_label() -> void:
	_attr_label_open = false
	# 停止之前的动画
	if attr_label_tween and attr_label_tween.is_valid():
		attr_label_tween.kill()
	
	# 渐出动画
	attr_label_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	attr_label_tween.tween_property(attr_label, "modulate:a", 0.0, 0.3)
	attr_label_tween.tween_callback(func(): attr_label.visible = false)

# ============== 技能标签显示 ==============

func _get_skill_own_damage_bonus(tag: String, _damage_multi) -> float:
	match tag:
		"qigong":
			return Qigong.main_skill_qigong_damage
		"dragonwind":
			return maxf(0.0, DragonWind.dragonwind_final_damage_multi - 1.0)
		_:
			return 0.0

func show_skill_label(skill_index: int, player_node: Node) -> void:
	var skill_data = {
		1: {"name": "剑气诀", "level_prop": "main_skill_swordQi", "damage_prop": "main_skill_swordQi_damage", "speed_node": "fire_speed", "tag": "swordqi", "reward_prefixes": ["SplitSwordQi", "RSwordQi", "SRSwordQi", "SSRSwordQi", "URSwordQi"]},
		2: {"name": "仙枝", "level_prop": "main_skill_branch", "damage_prop": "main_skill_branch_damage", "speed_node": "branch_fire_speed", "tag": "branch", "reward_prefixes": ["Branch", "RBranch", "SRBranch", "SSRBranch", "URBranch"]},
		3: {"name": "爆炎诀", "level_prop": "main_skill_moyan", "damage_prop": "main_skill_moyan_damage", "speed_node": "moyan_fire_speed", "tag": "moyan", "reward_prefixes": ["Moyan", "Rmoyan", "SRmoyan", "SSRmoyan", "URmoyan"]},
		4: {"name": "赤曜", "level_prop": "main_skill_riyan", "damage_prop": "main_skill_riyan_damage", "speed_node": "riyan_fire_speed", "tag": "riyan", "reward_prefixes": ["Riyan", "RRiyan", "SRRiyan", "SSRRiyan", "URRiyan"]},
		5: {"name": "离火诀", "level_prop": "main_skill_ringFire", "damage_prop": "main_skill_ringFire_damage", "speed_node": "ringFire_fire_speed", "tag": "ringFire", "reward_prefixes": ["RingFire", "RRingFire", "SRRingFire", "SSRRingFire", "URRingFire"]},
		6: {"name": "震雷诀", "level_prop": "main_skill_thunder", "damage_prop": "main_skill_thunder_damage", "speed_node": "thunder_fire_speed", "tag": "thunder", "reward_prefixes": ["Thunder", "RThunder", "SRThunder", "SSRThunder", "URThunder"]},
		7: {"name": "血气波", "level_prop": "main_skill_bloodwave", "damage_prop": "main_skill_bloodwave_damage", "speed_node": "bloodwave_fire_speed", "tag": "blood_wave", "reward_prefixes": ["Bloodwave", "RBloodwave", "SRBloodwave", "SSRBloodwave", "URBloodwave"]},
		8: {"name": "饮血剑", "level_prop": "main_skill_bloodboardsword", "damage_prop": "main_skill_bloodboardsword_damage", "speed_node": "bloodboardsword_fire_speed", "tag": "blood_broadsword", "reward_prefixes": ["Bloodboardsword", "RBloodboardsword", "SRBloodboardsword", "SSRBloodboardsword", "URBloodboardsword"]},
		9: {"name": "冰刺术", "level_prop": "main_skill_ice", "damage_prop": "main_skill_ice_damage", "speed_node": "ice_flower_fire_speed", "tag": "ice_flower", "reward_prefixes": ["Ice", "RIce", "SRIce", "SSRIce", "URIce"]},
		10: {"name": "天雷破", "level_prop": "main_skill_thunder_break", "damage_prop": "main_skill_thunder_break_damage", "speed_node": "thunder_break_fire_speed", "tag": "thunder_break", "reward_prefixes": ["ThunderBreak", "Thunderbreak", "RThunderBreak", "SRThunderBreak", "SSRThunderBreak", "URThunderBreak", "RThunderbreak", "SRThunderbreak", "SSRThunderbreak", "URThunderbreak"]},
		11: {"name": "光弹", "level_prop": "main_skill_light_bullet", "damage_prop": "main_skill_light_bullet_damage", "speed_node": "light_bullet_fire_speed", "tag": "light_bullet", "reward_prefixes": ["Lightbullet", "RLightbullet", "SRLightbullet", "SSRLightbullet", "URLightbullet"]},
		12: {"name": "坎水诀", "level_prop": "main_skill_water", "damage_prop": "main_skill_water_damage", "speed_node": "water_fire_speed", "tag": "water", "reward_prefixes": ["Water", "RWater", "SRWater", "SSRWater", "URWater"]},
		13: {"name": "乾坤双剑", "level_prop": "main_skill_qiankun", "damage_prop": "main_skill_qiankun_damage", "speed_node": "qiankun_fire_speed", "tag": "qiankun", "reward_prefixes": ["Qiankun", "RQiankun", "SRQiankun", "SSRQiankun", "URQiankun"]},
		14: {"name": "玄武盾", "level_prop": "main_skill_xuanwu", "damage_prop": "main_skill_xuanwu_damage", "speed_node": "xuanwu_fire_speed", "tag": "xuanwu", "reward_prefixes": ["Xuanwu", "RXuanwu", "SRXuanwu", "SSRXuanwu", "URXuanwu"]},
		15: {"name": "巽风诀", "level_prop": "main_skill_xunfeng", "damage_prop": "main_skill_xunfeng_damage", "speed_node": "xunfeng_fire_speed", "tag": "xunfeng", "reward_prefixes": ["Xunfeng", "RXunfeng", "SRXunfeng", "SSRXunfeng", "URXunfeng"]},
		16: {"name": "艮山诀", "level_prop": "main_skill_genshan", "damage_prop": "main_skill_genshan_damage", "speed_node": "genshan_fire_speed", "tag": "genshan", "reward_prefixes": ["Genshan", "RGenshan", "SRGenshan", "SSRGenshan", "URGenshan"]},
		17: {"name": "兑泽诀", "level_prop": "main_skill_duize", "damage_prop": "main_skill_duize_damage", "speed_node": "duize_fire_speed", "tag": "duize", "reward_prefixes": ["Duize", "RDuize", "SRDuize", "SSRDuize", "URDuize"]},
		18: {"name": "圣光术", "level_prop": "main_skill_holylight", "damage_prop": "main_skill_holylight_damage", "speed_node": "holy_light_fire_speed", "tag": "holylight", "reward_prefixes": ["Holylight", "RHolylight", "SRHolylight", "SSRHolylight", "URHolylight"]},
		19: {"name": "气功波", "level_prop": "main_skill_qigong", "damage_prop": "main_skill_qigong_damage", "speed_node": "qigong_fire_speed", "tag": "qigong", "reward_prefixes": ["Qigong", "RQigong", "SRQigong", "SSRQigong", "URQigong"]},
		20: {"name": "风龙杖", "level_prop": "main_skill_dragonwind", "damage_prop": "main_skill_dragonwind_damage", "speed_node": "dragonwind_fire_speed", "tag": "dragonwind", "reward_prefixes": ["Dragonwind", "RDragonwind", "SRDragonwind", "SSRDragonwind", "URDragonwind"]},
		21: {"name": "爪爪巨锤", "level_prop": "main_skill_zhuazhuajuchui", "damage_prop": "", "speed_node": "zhuazhuajuchui_fire_speed", "tag": "zhuazhuajuchui", "reward_prefixes": ["Zhuazhuajuchui", "RZhuazhuajuchui", "SRZhuazhuajuchui", "SSRZhuazhuajuchui", "URZhuazhuajuchui"]}
	}

	if not skill_data.has(skill_index):
		return
		
	var data = skill_data[skill_index]
	
	var level = PC.get(data.level_prop) if PC.get(data.level_prop) != null else 1
	var damage_multi = PC.get(data.damage_prop) if str(data.damage_prop) != "" else ZHUAZHUAJUCHUI_SCRIPT.main_skill_zhuazhuajuchui_damage
	if data.tag == "thunder":
		damage_multi = 0.7 * (PC.main_skill_thunder_damage / 0.85)
	if damage_multi == null:
		# 尝试从单例获取或使用默认值1.0
		if data.tag == "blood_wave" and ClassDB.class_exists("BloodWave"):
			damage_multi = load("res://Script/skill/blood_wave.gd").main_skill_bloodwave_damage
		elif data.tag == "ice_flower" and ClassDB.class_exists("IceFlower"):
			damage_multi = load("res://Script/skill/ice_flower.gd").main_skill_ice_flower_damage
		else:
			damage_multi = 1.0

	var speed_timer = player_node.get(data.speed_node)
	var speed = speed_timer.wait_time if speed_timer else 1.0
	
	var w_dps = Global.get_weapon_dps().get(data.tag, 0.0)
	
	var text = "" + data.name + "  LV. " + str(level) + ""
	var weapon_damage_bonus: float = SettingStudyTreeUp.get_total_damage_bonus(str(data.tag))
	weapon_damage_bonus += _get_skill_own_damage_bonus(str(data.tag), damage_multi)
	text += "\n武器伤害加成： " + str(int(round(weapon_damage_bonus * 100.0))) + "%"
	text += "\n基本攻击速度：" + str("%.2f" % speed) + "秒/次"
	text += "\n秒伤：[color=orange]" + str(int(w_dps)) + "[/color]"
	
	# text += "\n进化："
	# var has_evolution = false
	# for reward_id in PC.selected_rewards:
	# 	for i in range(1, data.reward_prefixes.size()): # 跳过第0个基础武器前缀，只匹配进化前缀(R/SR/SSR/UR)
	# 		if str(reward_id).begins_with(data.reward_prefixes[i]):
	# 			var reward_name = _get_reward_name(reward_id)
	# 			if reward_name != "":
	# 				text += "\n" + reward_name
	# 				has_evolution = true
	# 			break
	
	# if not has_evolution:
	# 	text += "\n无"
		
	skill_label1.text = text
	skill_label1.visible = true
	if _skill_label_tween and _skill_label_tween.is_valid():
		_skill_label_tween.kill()
	skill_label1.modulate.a = 0.0
	_skill_label_tween = create_tween()
	_skill_label_tween.tween_property(skill_label1, "modulate:a", 1.0, 0.2)

func hide_skill_label() -> void:
	if _skill_label_tween and _skill_label_tween.is_valid():
		_skill_label_tween.kill()
	if not skill_label1.visible:
		return
	_skill_label_tween = create_tween()
	_skill_label_tween.tween_property(skill_label1, "modulate:a", 0.0, 0.2)
	_skill_label_tween.tween_callback(func():
		skill_label1.visible = false
		skill_label1.modulate.a = 1.0
	)

func _get_reward_name(reward_id: String) -> String:
	# 从 LvUp 单例的 all_rewards_list 中查找奖励名称
	if LvUp and LvUp.has_method("get") and LvUp.get("all_rewards_list"):
		var reward_list = LvUp.get("all_rewards_list")
		for reward in reward_list:
			if reward.id == reward_id:
				return reward.reward_name
	return ""

# 兼容旧代码
func show_skill1_label(player_node: Node) -> void:
	show_skill_label(1, player_node)

func hide_skill1_label() -> void:
	hide_skill_label()

# ============== 纹章鼠标事件 ==============

func show_emblem_detail(emblem_index: int) -> void:
	var detail: RichTextLabel
	var panel: Panel
	match emblem_index:
		1: detail = emblem1_detail; panel = emblem1_panel
		2: detail = emblem2_detail; panel = emblem2_panel
		3: detail = emblem3_detail; panel = emblem3_panel
		4: detail = emblem4_detail; panel = emblem4_panel
		5: detail = emblem5_detail; panel = emblem5_panel
		6: detail = emblem6_detail; panel = emblem6_panel
		7: detail = emblem7_detail; panel = emblem7_panel
		8: detail = emblem8_detail; panel = emblem8_panel
		_: return
	
	if detail and detail.text != "":
		var old_tw = _emblem_tweens.get(emblem_index) as Tween
		if old_tw and old_tw.is_valid():
			old_tw.kill()
		detail.visible = true
		panel.visible = true
		panel.modulate.a = 0.0
		detail.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(panel, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(detail, "modulate:a", 1.0, 0.2)
		_emblem_tweens[emblem_index] = tw

func hide_emblem_detail(emblem_index: int) -> void:
	var detail: RichTextLabel
	var panel: Panel
	match emblem_index:
		1: detail = emblem1_detail; panel = emblem1_panel
		2: detail = emblem2_detail; panel = emblem2_panel
		3: detail = emblem3_detail; panel = emblem3_panel
		4: detail = emblem4_detail; panel = emblem4_panel
		5: detail = emblem5_detail; panel = emblem5_panel
		6: detail = emblem6_detail; panel = emblem6_panel
		7: detail = emblem7_detail; panel = emblem7_panel
		8: detail = emblem8_detail; panel = emblem8_panel
		_: return
	
	if detail:
		var old_tw = _emblem_tweens.get(emblem_index) as Tween
		if old_tw and old_tw.is_valid():
			old_tw.kill()
		var tw = create_tween()
		tw.tween_property(panel, "modulate:a", 0.0, 0.2)
		tw.parallel().tween_property(detail, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			detail.visible = false
			panel.visible = false
			panel.modulate.a = 1.0
			detail.modulate.a = 1.0
		)
		_emblem_tweens[emblem_index] = tw

# ============== 游戏结果显示 ==============

func set_victory_summary_data(data: Dictionary) -> void:
	victory_summary_data = data.duplicate(true)

func show_game_over() -> void:
	_reset_game_speed()
	_defer_level_up_until_chant_end = false
	_chant_level_up_resume_id += 1
	gameover_label.visible = true
	# game over 瞬间隐藏升级按钮，防止继续点击
	if lv_up_start_button:
		lv_up_start_button.visible = false
	if instant_level_up_button:
		instant_level_up_button.visible = false
	if instant_level_up_button_label:
		instant_level_up_button_label.visible = false
	# 强制清理升级界面，防止advance弹出后卡死
	if level_up_manager:
		level_up_manager._force_cleanup_level_up_ui()

func show_victory() -> void:
	_reset_game_speed()
	victory_label.visible = true

func play_victory_sequence() -> void:
	show_victory()
	await get_tree().create_timer(1.0).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(victory_label, "modulate:a", 0.0, 0.6)
	await fade_tween.finished
	victory_label.visible = false
	victory_label.modulate = Color(1, 1, 1, 1)
	_prepare_victory_summary()
	await _show_victory_summary_sequence()
	emit_signal("victory_evaluation_finished")

func _prepare_victory_summary() -> void:
	victory_summary_container.visible = true
	var summary_labels = _get_victory_summary_labels()
	for label in summary_labels:
		label.visible = false

func _show_victory_summary_sequence() -> void:
	var summary_labels = _get_victory_summary_labels()
	var summary_texts = _build_victory_summary_texts()
	for i in range(summary_labels.size()):
		var label = summary_labels[i]
		label.text = summary_texts[i]
		label.visible = true
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(3.0).timeout

func _get_victory_summary_labels() -> Array:
	return [victory_time_label, victory_score_label, victory_kill_label, victory_total_label]

func _build_victory_summary_texts() -> Array:
	var boss_defeat_time = float(victory_summary_data.get("boss_defeat_time", PC.real_time))
	var kill_count = int(victory_summary_data.get("kill_count", GU.get_kill_count()))
	var highest_dps = float(victory_summary_data.get("highest_dps", Global.get_highest_dps()))
	var lost_hp = float(victory_summary_data.get("lost_hp", 0.0))
	var time_line = _build_data_summary_line("击败首领用时", _format_summary_time(boss_defeat_time))
	var kill_line = _build_data_summary_line("击败敌人数量", str(kill_count))
	var dps_line = _build_data_summary_line("最高秒伤", _format_summary_raw_number(highest_dps))
	var lost_hp_line = _build_data_summary_line("损失体力", _format_summary_number(lost_hp))
	return [time_line, kill_line, dps_line, lost_hp_line]

func _build_data_summary_line(title: String, value_text: String) -> String:
	return "[right][font_size=28]" + title + "：" + value_text + "[/font_size][/right]"

func _format_summary_time(seconds_float: float) -> String:
	var total_seconds = max(0, int(Global.get_battle_display_time(seconds_float)))
	return "%02d : %02d" % [int(total_seconds / 60), total_seconds % 60]

func _format_summary_number(value: float) -> String:
	if value >= 10000000.0:
		return "%.3fm" % (value / 1000000.0)
	if value >= 100000.0:
		return "%.2fk" % (value / 1000.0)
	if abs(value - round(value)) < 0.05:
		return str(int(round(value)))
	return "%.1f" % value

func _format_summary_raw_number(value: float) -> String:
	return str(int(round(value)))

func _build_summary_line(title: String, value_text: String, grade_info: Dictionary) -> String:
	var grade_name = grade_info["name"]
	var grade_color = grade_info["color"]
	var grade_size = grade_info["size"]
	var line = "[right][font_size=28]" + title + "：" + value_text + "  评级：" + "[/font_size]"
	line += "[font_size=" + str(grade_size) + "][color=" + grade_color + "]" + grade_name + "[/color][/font_size][/right]"
	return line

func _get_time_seconds_from_text(time_text: String) -> int:
	var parts = time_text.split(":")
	var minutes_text = parts[0].strip_edges()
	var seconds_text = parts[1].strip_edges()
	var minutes = int(minutes_text)
	var seconds = int(seconds_text)
	return minutes * 60 + seconds

func _get_score_value_from_text(score_text: String) -> int:
	for line in score_text.split("\n"):
		if line.contains("真气"):
			score_text = line
			break
	var clean_text = score_text.replace("真气", "").strip_edges()
	var value = 0.0
	if clean_text.ends_with("m"):
		var num_text = clean_text.trim_suffix("m")
		value = float(num_text) * 1000000.0
	elif clean_text.ends_with("k"):
		var num_text = clean_text.trim_suffix("k")
		value = float(num_text) * 1000.0
	else:
		value = float(clean_text)
	return int(value)

func _get_time_grade_name(seconds: int) -> String:
	if seconds <= 450:
		return "神"
	if seconds <= 540:
		return "极"
	if seconds <= 600:
		return "优"
	if seconds <= 720:
		return "良"
	return "可"

func _get_score_grade_name(score_value: int) -> String:
	if score_value > 40000:
		return "神"
	if score_value >= 25000:
		return "极"
	if score_value >= 15000:
		return "优"
	if score_value >= 5000:
		return "良"
	return "可"

func _get_kill_grade_name(kill_count: int) -> String:
	if kill_count > 1250:
		return "神"
	if kill_count >= 1150:
		return "极"
	if kill_count >= 1000:
		return "优"
	if kill_count >= 800:
		return "良"
	return "可"

func _get_total_grade_name(total_score: int) -> String:
	if total_score >= 140:
		return "神"
	if total_score >= 110:
		return "极"
	if total_score >= 80:
		return "优"
	if total_score >= 50:
		return "良"
	return "可"

func _get_grade_info(grade_name: String) -> Dictionary:
	var color = "#ffffff"
	var size = 28
	var score = 10
	if grade_name == "神":
		color = "#ff3b30"
		size = 36
		score = 50
	elif grade_name == "极":
		color = "#f5c400"
		size = 34
		score = 40
	elif grade_name == "优":
		color = "#b14cff"
		size = 32
		score = 30
	elif grade_name == "良":
		color = "#4aa3ff"
		size = 30
		score = 20
	return {"name": grade_name, "color": color, "size": size, "score": score}

# ============== 升级管理 ==============

## 初始化手动升级按钮
func _init_lv_up_start_button() -> void:
	# 每局开始重置为即时弹出模式
	PC.instant_level_up = true
	if instant_level_up_button:
		instant_level_up_button.button_pressed = false
		instant_level_up_button.visible = false # 初始不可见，随升级选项界面渐入渐出
		instant_level_up_button.modulate.a = 1.0
		if not instant_level_up_button.toggled.is_connected(_on_instant_level_up_button_toggled):
			instant_level_up_button.toggled.connect(_on_instant_level_up_button_toggled)
	if instant_level_up_button_label:
		instant_level_up_button_label.visible = false
		instant_level_up_button_label.modulate.a = 1.0
	if lv_up_start_button:
		lv_up_start_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if not lv_up_start_button.pressed.is_connected(_on_lv_up_start_button_pressed):
			lv_up_start_button.pressed.connect(_on_lv_up_start_button_pressed)
		lv_up_start_button.visible = false # 初始不可见，由 _update_lv_up_start_button_badge 统一控制
		_update_lv_up_start_button_badge()

func _find_level_up_exit_button() -> Button:
	var candidate_paths := [
		"exitbutton",
		"ExitButton",
		"exit_button",
		"Button"
	]
	for path in candidate_paths:
		var button := lv_up_change.get_node_or_null(path) as Button
		if button:
			return button
	return null

func _init_level_up_exit_button() -> void:
	if not lv_up_exit_button:
		return
	lv_up_exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	lv_up_exit_button.visible = false
	lv_up_exit_button.disabled = true
	if not lv_up_exit_button.pressed.is_connected(_on_level_up_exit_button_pressed):
		lv_up_exit_button.pressed.connect(_on_level_up_exit_button_pressed)

func set_level_up_exit_button_visible(show: bool) -> void:
	if not lv_up_exit_button:
		return
	lv_up_exit_button.visible = show
	lv_up_exit_button.disabled = not show
	lv_up_exit_button.modulate.a = 1.0

func set_level_up_exit_button_enabled(enabled: bool) -> void:
	if not lv_up_exit_button:
		return
	if lv_up_exit_button.visible:
		lv_up_exit_button.disabled = not enabled

func _on_level_up_exit_button_pressed() -> void:
	if not level_up_manager:
		return
	if level_up_manager.has_method("_is_mobile_level_up_input_guard_active") and level_up_manager._is_mobile_level_up_input_guard_active():
		return
	if not lv_up_change or not lv_up_change.visible:
		return
	set_level_up_exit_button_visible(false)
	level_up_manager.skip_current_level_up()
	_refresh_faze_ui()
	_update_refresh_lock_display()
	_update_lv_up_start_button_badge()

## 初始化速度切换按钮
func _init_speed_change_button() -> void:
	_current_speed_index = 0
	Global.reset_game_speed()
	if not speed_change_button:
		speed_change_button = get_node_or_null("speed_change")
	if speed_change_button:
		speed_change_button.expand_icon = true
		speed_change_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not speed_change_button.pressed.is_connected(_on_speed_change_button_pressed):
			speed_change_button.pressed.connect(_on_speed_change_button_pressed)
		_update_speed_button_icon()

func _on_speed_change_button_pressed() -> void:
	_current_speed_index = (_current_speed_index + 1) % SPEED_VALUES.size()
	Global.game_speed = SPEED_VALUES[_current_speed_index]
	Engine.time_scale = Global.game_speed
	_update_speed_button_icon()

func _update_speed_button_icon() -> void:
	if not speed_change_button:
		return
	var icon_path = SPEED_ICON_PATHS[_current_speed_index]
	var tex = load(icon_path)
	if tex:
		speed_change_button.icon = tex

func set_speed_button_visible(show: bool) -> void:
	if not speed_change_button:
		return
	if show:
		speed_change_button.visible = true
		var tw = create_tween()
		tw.tween_property(speed_change_button, "modulate:a", 1.0, 0.25)
	else:
		var tw = create_tween()
		tw.tween_property(speed_change_button, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			speed_change_button.visible = false
		)

func _reset_game_speed() -> void:
	_current_speed_index = 0
	Global.reset_game_speed()
	_update_speed_button_icon()
	set_speed_button_visible(true)

## 切换即时/手动升级模式
func _on_instant_level_up_button_toggled(pressed: bool) -> void:
	PC.instant_level_up = not pressed
	_update_lv_up_start_button_badge()

## 更新手动升级按钮的待升级徽标
func _update_lv_up_start_button_badge() -> void:
	if not lv_up_start_button:
		return
	var pending_count = level_up_manager.get_pending_level_ups()
	var advance_count = level_up_manager.count_pending_advances()
	var total = pending_count + advance_count
	lv_up_start_button.visible = not _manual_level_up_shop_hidden and not PC.instant_level_up and total > 0 and not Global.is_level_up
	# 动态创建或查找右下角 badge
	var badge = lv_up_start_button.get_node_or_null("PendingBadge")
	if badge == null:
		badge = Label.new()
		badge.name = "PendingBadge"
		badge.add_theme_font_size_override("font_size", 32)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv_up_start_button.add_child(badge)
	badge.text = str(total)
	badge.position = Vector2(lv_up_start_button.size.x - 24, lv_up_start_button.size.y - 24)

func set_qi_vortex_shop_manual_level_up_hidden(hidden: bool) -> void:
	_manual_level_up_shop_hidden = hidden
	if _manual_level_up_shop_tween and _manual_level_up_shop_tween.is_valid():
		_manual_level_up_shop_tween.kill()
	if hidden:
		_shop_restore_instant_level_up_button_visible = instant_level_up_button != null and instant_level_up_button.visible
		_shop_restore_instant_level_up_label_visible = instant_level_up_button_label != null and instant_level_up_button_label.visible
		_manual_level_up_shop_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_manual_level_up_shop_tween.set_ignore_time_scale(true)
		_manual_level_up_shop_tween.set_parallel(true)
		var has_visible_control := false
		for control in _get_manual_level_up_controls():
			if control and control.visible:
				has_visible_control = true
				if control is BaseButton:
					(control as BaseButton).disabled = true
				_manual_level_up_shop_tween.tween_property(control, "modulate:a", 0.0, 0.2)
		if not has_visible_control:
			_manual_level_up_shop_tween.kill()
			_hide_manual_level_up_controls_for_shop()
			return
		_manual_level_up_shop_tween.chain().tween_callback(func():
			_hide_manual_level_up_controls_for_shop()
		)
	else:
		if lv_up_start_button:
			lv_up_start_button.disabled = false
		if instant_level_up_button:
			instant_level_up_button.disabled = false
			_restore_manual_level_up_control(instant_level_up_button, _shop_restore_instant_level_up_button_visible)
		if instant_level_up_button_label:
			_restore_manual_level_up_control(instant_level_up_button_label, _shop_restore_instant_level_up_label_visible)
		_update_lv_up_start_button_badge()
		_shop_restore_instant_level_up_button_visible = false
		_shop_restore_instant_level_up_label_visible = false

func _hide_manual_level_up_controls_for_shop() -> void:
	for control in _get_manual_level_up_controls():
		if control:
			control.visible = false
			control.modulate.a = 1.0

func _get_manual_level_up_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if lv_up_start_button:
		controls.append(lv_up_start_button)
	if instant_level_up_button:
		controls.append(instant_level_up_button)
	if instant_level_up_button_label:
		controls.append(instant_level_up_button_label)
	return controls

func _restore_manual_level_up_control(control: Control, should_show: bool) -> void:
	if not control:
		return
	if not should_show:
		control.visible = false
		control.modulate.a = 1.0
		return
	control.visible = true
	control.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.2)

## 手动升级按钮点击
func _on_lv_up_start_button_pressed() -> void:
	if Global.is_level_up or _manual_level_up_shop_hidden:
		return
	if PC.is_game_over:
		return
	level_up_manager.check_and_process_pending_level_ups(get_tree(), get_viewport())
	_refresh_faze_ui()
	_update_lv_up_start_button_badge()

func _on_level_up(main_skill_name: String = '', refresh_id: int = 0) -> void:
	if PC.is_game_over:
		_defer_level_up_until_chant_end = false
		return
	# 每达REFRESH_LEVEL_STEP级，额外获得REFRESH_BONUS_PER_STEP次刷新次数
	if main_skill_name == '' and refresh_id == 0 and PC.pc_lv % REFRESH_LEVEL_STEP == 0:
		PC.refresh_num += REFRESH_BONUS_PER_STEP
		print("[Refresh] 第", PC.pc_lv, "级奖励刷新+", REFRESH_BONUS_PER_STEP, "，当前刷新次数：", PC.refresh_num)
	# 每达LOCK_LEVEL_STEP级，额外获得LOCK_BONUS_PER_STEP次锁定次数
	if main_skill_name == '' and refresh_id == 0 and PC.pc_lv % LOCK_LEVEL_STEP == 0:
		PC.lock_num += LOCK_BONUS_PER_STEP
		print("[Lock] 第", PC.pc_lv, "级奖励锁定+", LOCK_BONUS_PER_STEP, "，当前锁定次数：", PC.lock_num)
	_update_refresh_lock_display()
	# 【修复】防止同时段多次升级时重复调用 handle_level_up，导致 pending_level_ups 被重复减1
	if Global.is_level_up and refresh_id == 0:
		return
	if _should_defer_level_up_for_chant(main_skill_name, refresh_id):
		_defer_level_up_until_chant_end = true
		_update_lv_up_start_button_badge()
		return
	if PC.instant_level_up:
		level_up_manager.handle_level_up(main_skill_name, refresh_id, get_tree(), get_viewport())
	else:
		# 手动模式：stage脚本已经调用过 add_pending_level_up，此处不再重复
		_update_lv_up_start_button_badge()

func _check_and_process_pending_level_ups() -> void:
	if PC.is_game_over:
		_defer_level_up_until_chant_end = false
		if level_up_manager:
			level_up_manager._force_cleanup_level_up_ui()
		return
	# 手动模式：不通过信号自动链式处理，等待玩家点击按钮
	if not PC.instant_level_up:
		_update_lv_up_start_button_badge()
		return
	if _should_defer_level_up_for_chant():
		_defer_level_up_until_chant_end = true
		_update_lv_up_start_button_badge()
		return
	level_up_manager.check_and_process_pending_level_ups(get_tree(), get_viewport())
	_refresh_faze_ui()
	_update_lv_up_start_button_badge()

## 手动模式下，还有待升级项时的回调
func _on_manual_level_up_pending() -> void:
	_update_lv_up_start_button_badge()

func handle_refresh_button(button_id: int) -> void:
	if level_up_manager and level_up_manager.has_method("_is_mobile_level_up_input_guard_active") and level_up_manager._is_mobile_level_up_input_guard_active():
		return
	if level_up_manager and level_up_manager.now_main_skill_name != "":
		return
	# 如果该栏位是临时锁定，取消锁定并返还次数，然后继续刷新
	if level_up_manager and level_up_manager.tentative_locked_rewards.has(button_id):
		level_up_manager.tentative_locked_rewards.erase(button_id)
		PC.lock_num += 1
		print("[Lock] 刷新取消临时锁定 位置", button_id, "，返还锁定次数")
		# 恢复按钮颜色（在刷新动画中会重新设置）
		var target_btn: Button
		match button_id:
			1: target_btn = lv_up_change_b1
			2: target_btn = lv_up_change_b2
			3: target_btn = lv_up_change_b3
		if is_instance_valid(target_btn):
			target_btn.modulate = Color(1, 1, 1, 1.0)
		_update_refresh_lock_display()
		# 继续执行下面的刷新逻辑
	
	# 如果该栏位是已确认锁定，拒绝刷新
	if level_up_manager and level_up_manager.locked_rewards.has(button_id):
		var tip = lv_up_tip if lv_up_tip else get_node_or_null("TipsLayer/Tip")
		if tip and tip.has_method("start_animation"):
			tip.start_animation("该栏位已锁定", 0.5)
		return
	
	if PC.refresh_num <= 0:
		# 刷新次数不足，显示Tip提示
		var tip = lv_up_tip if lv_up_tip else get_node_or_null("TipsLayer/Tip")
		if tip and tip.has_method("start_animation"):
			tip.start_animation("刷新次数不足", 0.5)
		return
	
	# 找对应的大按钮
	var target_btn: Button
	match button_id:
		1: target_btn = lv_up_change_b1
		2: target_btn = lv_up_change_b2
		3: target_btn = lv_up_change_b3
	if is_instance_valid(target_btn):
		_do_refresh_with_transition(target_btn, button_id)
	else:
		level_up_manager.handle_refresh_button(button_id, get_tree(), get_viewport())
		_update_refresh_lock_display()

func handle_refresh_all_button() -> void:
	if level_up_manager and level_up_manager.has_method("_is_mobile_level_up_input_guard_active") and level_up_manager._is_mobile_level_up_input_guard_active():
		return
	if level_up_manager == null or level_up_manager.now_main_skill_name != "":
		return
	if PC.refresh_num <= 0:
		_show_level_up_tip("刷新次数不足")
		return
	var buttons_to_refresh: Array[Button] = []
	for button_id in [1, 2, 3]:
		if level_up_manager.locked_rewards.has(button_id) or level_up_manager.tentative_locked_rewards.has(button_id):
			continue
		var target_btn := _get_level_up_reward_button(button_id)
		if is_instance_valid(target_btn) and target_btn.visible:
			buttons_to_refresh.append(target_btn)
	if buttons_to_refresh.is_empty():
		_show_level_up_tip("没有可刷新的栏位")
		return
	_do_refresh_all_with_transition(buttons_to_refresh)

func get_required_lv_up_value(level: int) -> int:
	var base_value := int(level_up_manager.get_required_lv_up_value(level))
	return int(ceil(float(base_value) * Global.get_core_required_exp_multiplier()))

func add_pending_level_up() -> void:
	level_up_manager.add_pending_level_up()

func _should_defer_level_up_for_chant(main_skill_name: String = "", refresh_id: int = 0) -> bool:
	if main_skill_name != "" or refresh_id != 0:
		return false
	if not PC.instant_level_up:
		return false
	return PC.is_chanting or _spell_chant_active

func _schedule_deferred_chant_level_up() -> void:
	if not _defer_level_up_until_chant_end:
		return
	if PC.is_game_over:
		_defer_level_up_until_chant_end = false
		return
	if PC.is_chanting or _spell_chant_active:
		return
	_defer_level_up_until_chant_end = false
	_chant_level_up_resume_id += 1
	var request_id: int = _chant_level_up_resume_id
	_resume_deferred_chant_level_up(request_id)

func _resume_deferred_chant_level_up(request_id: int) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	if request_id != _chant_level_up_resume_id:
		return
	if PC.is_game_over or Global.is_level_up or PC.is_chanting or _spell_chant_active:
		return
	_check_and_process_pending_level_ups()

## 刷新/锁定次数显示（0.2s过渡动画）
func _update_refresh_lock_display() -> void:
	var refresh_text := "%d  " % PC.refresh_num
	var lock_text := "%d " % PC.lock_num
	var ban_text := "%d " % PC.ban_num
	_update_count_label_if_changed(refresh_num_label, refresh_text, "_last_refresh_display_text")
	_update_count_label_if_changed(lock_num_label, lock_text, "_last_lock_display_text")
	_update_count_label_if_changed(ban_num_label, ban_text, "_last_ban_display_text")
	_update_ban_button_states()

func _update_count_label_if_changed(label: RichTextLabel, text: String, cache_property: String) -> void:
	if label == null:
		set(cache_property, text)
		return
	if str(get(cache_property)) == text:
		label.text = text
		label.modulate.a = 1.0
		return
	var first_update := str(get(cache_property)).is_empty()
	set(cache_property, text)
	if first_update:
		label.text = text
		label.modulate.a = 1.0
		return
	var fade_out := create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(label, "modulate:a", 0.0, 0.1)
	fade_out.tween_callback(func():
		label.text = text
	)
	fade_out.tween_property(label, "modulate:a", 1.0, 0.1)

## 刷新按钮完整过渡：淡出→更新内容，淡入由LevelUpManager统一处理
func _do_refresh_with_transition(button: Button, button_id: int, consume_refresh: bool = true) -> void:
	var tween = button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 第一段：淡出（0.15s），子节点一起消失
	tween.tween_property(button, "modulate", Color(1, 1, 1, 0), 0.15)
	# 淡出完成后立即更新内容（level_up.gd刚刚去掉了refresh的延迟）
	tween.tween_callback(func():
		if consume_refresh:
			level_up_manager.handle_refresh_button(button_id, get_tree(), get_viewport())
		else:
			level_up_manager.handle_refresh_button_without_cost(button_id, get_tree(), get_viewport())
		_update_refresh_lock_display()
	)

func _do_refresh_all_with_transition(buttons: Array[Button]) -> void:
	var fade_out := create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.set_parallel(true)
	for button in buttons:
		if is_instance_valid(button):
			fade_out.tween_property(button, "modulate", Color(1, 1, 1, 0), 0.15)
	fade_out.finished.connect(func():
		level_up_manager.handle_refresh_unlocked_buttons(get_tree(), get_viewport())
		_update_refresh_lock_display()
	)

## 按钮点击闪白效果（0.3s）
func _flash_button_white(button: Button) -> void:
	if not is_instance_valid(button):
		return
	# 确保按钮 modulate 从正常状态开始
	button.modulate = Color(1, 1, 1, 1)
	var tween = button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "modulate", Color(3, 3, 3, 1), 0.08)
	tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.22)

# ============== Warning动画 ==============

func _set_warning_mouse_filter_ignore() -> void:
	if warning_node == null:
		return
	_set_control_tree_mouse_filter(warning_node, Control.MOUSE_FILTER_IGNORE)

func _set_control_tree_mouse_filter(node: Node, filter: int) -> void:
	var control := node as Control
	if control != null:
		control.mouse_filter = filter
	for child in node.get_children():
		_set_control_tree_mouse_filter(child, filter)

func play_warning_animation() -> void:
	warning_active = true
	_set_warning_mouse_filter_ignore()
	warning_node.process_mode = Node.PROCESS_MODE_ALWAYS
	warning_node.visible = false
	warning_node.modulate = Color(1, 1, 1, 0)
	
	var warning_audio = warning_node.get_node("warning") as AudioStreamPlayer
	warning_audio.play()
	
	warning_node.visible = true
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(warning_node, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(warning_node, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		warning_node.visible = false
		warning_active = false
	)

func _build_treasure_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("宝器法则"))
	lines.append(_color_owned_weapons("宝器类武器：仙枝，风龙杖，玄武盾"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：宝器类武器伤害提升 15%，天命提升 4 点"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：天命提升 6 点，每点天命使宝器类武器伤害提升 3%，每升 2 级获得 1 次刷新次数"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：宝器类武器攻击速度提升 25% ，天命提升 12 点"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：宝器类武器伤害提升 35% ，天命提升 8 点，每升 1 级获得 1 次刷新次数"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：宝器类武器伤害提升 100% ，天命提升 12 点，每点天命使宝器类武器对精英及首领的伤害提升 6%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_deep_faze_detail(level: int) -> String:
	var tiers = [4, 9, 16, 22, 29]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("沉渊法则"))
	lines.append(_color_owned_weapons("沉渊系武器：爪爪巨锤，撼地诀，噬魂镰"))
	lines.append(_format_faze_line(level, current_tier, 4, "4阶：沉渊系武器伤害提升20%，击退幅度增加20%"))
	lines.append(_format_faze_line(level, current_tier, 9, "9阶：沉渊系武器让敌人强制位移后，会额外结算一次伤害，每点击退幅度造成4%的伤害，对于首领敌人，会直接附加该伤害并额外造成100%伤害"))
	lines.append(_format_faze_line(level, current_tier, 16, "16阶：沉渊系武器伤害提升45%，击退幅度增加25%"))
	lines.append(_format_faze_line(level, current_tier, 22, "22阶：沉渊系武器伤害提升60%，沉渊系武器强制位移的结算伤害，每点击退幅度造成的伤害提升至10%，对于首领敌人的额外伤害提升到300%"))
	lines.append(_format_faze_line(level, current_tier, 29, "29阶：沉渊系武器伤害提升90%，击退幅度增加75%，沉渊系武器强制位移的结算伤害对于首领敌人的额外伤害提升到1000%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

func _build_chaos_faze_detail(level: int) -> String:
	var tiers = [3, 5, 8, 11]
	var current_tier = 0
	for tier in tiers:
		if level >= tier:
			current_tier = tier
	var lines: Array = []
	lines.append(_build_law_title("混沌法则"))
	lines.append("每个达到 6、10 层的法则使混沌法则层数 +1")
	lines.append(_format_faze_line(level, current_tier, 3, "3阶：最终伤害、经验获得率、真气获取率提升 15%"))
	lines.append(_format_faze_line(level, current_tier, 5, "5阶：最终伤害、经验获得率再次提升 30%，真气获取率再次提升 25%"))
	lines.append(_format_faze_line(level, current_tier, 8, "8阶：最终伤害、经验获得率再次提升 60%，真气获取率再次提升 40%"))
	lines.append(_format_faze_line(level, current_tier, 11, "11阶：最终伤害、经验获得率再次提升 120%，真气获取率再次提升 80%"))
	var text = ""
	for i in range(lines.size()):
		text += lines[i]
		if i < lines.size() - 1:
			text += "\n"
	return text

# ============== 暂停菜单 ==============

func _init_stop_layer() -> void:
	if stop_button:
		stop_button.process_mode = Node.PROCESS_MODE_ALWAYS
		stop_button.z_as_relative = false
		stop_button.z_index = 5000
		stop_button.move_to_front()
		stop_button.pressed.connect(_on_stop_button_pressed)
	if stop_layer and setting_layer:
		stop_layer.setup(setting_layer)

func _on_stop_button_pressed() -> void:
	if stop_layer:
		if stop_layer.has_method("can_open_pause_menu") and not stop_layer.can_open_pause_menu():
			return
		stop_layer.open()

# ============== 咏唱魔法 UI ==============
func _init_spell_ui() -> void:
	"""初始化玩家咏唱魔法UI，动态创建子节点到spell控件内"""
	if not spell:
		return
	spell.visible = false
	
	var font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	var outline_color = Color(0.37, 0.17, 0.0, 1.0) # 褒色勾边，复刻boss chant样式
	
	# === 左侧技能图标 ===
	_spell_icon = TextureRect.new()
	_spell_icon.name = "SpellIcon"
	_spell_icon.position = Vector2(4, 4)
	_spell_icon.size = Vector2(60, 60)
	_spell_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spell_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spell.add_child(_spell_icon)
	
	# === 第一行：技能名 ===
	_spell_name_label = Label.new()
	_spell_name_label.name = "SpellName"
	_spell_name_label.position = Vector2(70, 0)
	_spell_name_label.size = Vector2(200, 22)
	_spell_name_label.add_theme_font_override("font", font)
	_spell_name_label.add_theme_font_size_override("font_size", 24)
	_spell_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	_spell_name_label.add_theme_color_override("font_outline_color", outline_color)
	_spell_name_label.add_theme_constant_override("outline_size", 6)
	_spell_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spell_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spell.add_child(_spell_name_label)
	
	# === 第二行：咏唱条（更窄更长） ===
	# 用一个带clip_contents的容器包裹，确保精确控制高度为11px
	var bar_container = Control.new()
	bar_container.name = "SpellChantBarContainer"
	bar_container.position = Vector2(70, 24)
	bar_container.size = Vector2(200, 11)
	bar_container.clip_contents = true
	spell.add_child(bar_container)
	
	_spell_chant_bar = ProgressBar.new()
	_spell_chant_bar.name = "SpellChantBar"
	_spell_chant_bar.position = Vector2.ZERO
	_spell_chant_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spell_chant_bar.show_percentage = false
	_spell_chant_bar.max_value = 1.0
	_spell_chant_bar.value = 0.0
	_spell_chant_bar.add_theme_font_size_override("font_size", 1)
	# 填充样式：复刻boss chant颜色
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.98, 0.96, 0.82, 1.0)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.border_width_left = 1
	fill_style.border_width_top = 1
	fill_style.border_width_right = 1
	fill_style.border_width_bottom = 1
	fill_style.border_color = Color(0.45, 0.30, 0.12, 0.9)
	fill_style.shadow_color = Color(0.45, 0.30, 0.12, 0.45)
	fill_style.shadow_size = 2
	fill_style.content_margin_top = 0
	fill_style.content_margin_bottom = 0
	fill_style.content_margin_left = 0
	fill_style.content_margin_right = 0
	_spell_chant_bar.add_theme_stylebox_override("fill", fill_style)
	# 背景样式
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.12, 0.08, 0.5)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.55, 0.40, 0.22, 0.7)
	bg_style.shadow_color = Color(0.55, 0.40, 0.22, 0.35)
	bg_style.shadow_size = 2
	bg_style.content_margin_top = 0
	bg_style.content_margin_bottom = 0
	bg_style.content_margin_left = 0
	bg_style.content_margin_right = 0
	_spell_chant_bar.add_theme_stylebox_override("background", bg_style)
	bar_container.add_child(_spell_chant_bar)
	
	# === 第三行左侧："发动中...." 状态文字（咏唱条下方） ===
	_spell_status_label = Label.new()
	_spell_status_label.name = "SpellStatus"
	_spell_status_label.position = Vector2(70, 38)
	_spell_status_label.size = Vector2(100, 22)
	_spell_status_label.add_theme_font_override("font", font)
	_spell_status_label.add_theme_font_size_override("font_size", 20)
	_spell_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	_spell_status_label.add_theme_color_override("font_outline_color", outline_color)
	_spell_status_label.add_theme_constant_override("outline_size", 6)
	_spell_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spell_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spell_status_label.text = "发动中...."
	spell.add_child(_spell_status_label)
		
	# === 第三行右侧：剩余咏唱时间（咏唱条下方） ===
	_spell_time_label = Label.new()
	_spell_time_label.name = "SpellTime"
	_spell_time_label.position = Vector2(170, 38)
	_spell_time_label.size = Vector2(100, 22)
	_spell_time_label.add_theme_font_override("font", font)
	_spell_time_label.add_theme_font_size_override("font_size", 20)
	_spell_time_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	_spell_time_label.add_theme_color_override("font_outline_color", outline_color)
	_spell_time_label.add_theme_constant_override("outline_size", 6)
	_spell_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spell_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spell.add_child(_spell_time_label)
	
	# 创建咏唱刷新Timer（设为PAUSABLE，暂停时停止tick）
	_spell_chant_timer = Timer.new()
	_spell_chant_timer.wait_time = 0.1
	_spell_chant_timer.one_shot = false
	_spell_chant_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_spell_chant_timer.timeout.connect(_on_spell_chant_timer_tick)
	add_child(_spell_chant_timer)

func _on_player_chant_start(skill_display_name: String, chant_duration: float, icon_path: String) -> void:
	"""玩家咏唱开始，显示spell UI"""
	_chant_level_up_resume_id += 1
	_spell_chant_total_time = chant_duration
	_spell_chant_elapsed = 0.0
	_spell_chant_active = true
	
	# 设置技能图标
	if _spell_icon and icon_path != "":
		var tex = load(icon_path)
		if tex:
			_spell_icon.texture = tex
	
	# 设置技能名
	if _spell_name_label:
		_spell_name_label.text = skill_display_name
	
	# 设置咏唱条
	if _spell_chant_bar:
		_spell_chant_bar.max_value = chant_duration
		_spell_chant_bar.value = 0.0
	
	# 设置时间显示
	if _spell_time_label:
		_spell_time_label.text = str(snapped(chant_duration, 0.1)) + "s"
	
	# 显示spell控件
	if spell:
		spell.visible = true
	
	# 启动刷新计时器
	if _spell_chant_timer:
		if not _spell_chant_timer.is_stopped():
			_spell_chant_timer.stop()
		_spell_chant_timer.start()

func _on_player_chant_end() -> void:
	"""玩家咏唱结束，隐藏spell UI"""
	_spell_chant_active = false
	_end_mobile_chant_aim_session()
	if _spell_chant_timer and not _spell_chant_timer.is_stopped():
		_spell_chant_timer.stop()
	if spell:
		spell.visible = false
	_schedule_deferred_chant_level_up()

func _process(delta: float) -> void:
	_process_mobile_skill_touch(delta)
	_process_ban_hold(delta)
	# 咏唱条平滑更新（游戏暂停时不更新）
	if _spell_chant_active and not get_tree().paused:
		_spell_chant_elapsed += delta
		if _spell_chant_bar:
			_spell_chant_bar.value = min(_spell_chant_elapsed, _spell_chant_total_time)
		if _spell_chant_elapsed >= _spell_chant_total_time:
			_spell_chant_active = false
			if _spell_chant_timer and not _spell_chant_timer.is_stopped():
				_spell_chant_timer.stop()
			if spell:
				spell.visible = false
			_schedule_deferred_chant_level_up()

func _on_spell_chant_timer_tick() -> void:
	"""每0.1秒刷新咏唱剩余时间文字"""
	if not _spell_chant_active:
		_spell_chant_timer.stop()
		return
	var remaining = max(_spell_chant_total_time - _spell_chant_elapsed, 0.0)
	if _spell_time_label:
		_spell_time_label.text = str(snapped(remaining, 0.1)) + "s"


# ============== Buff通知弹出系统 ==============

## 返回BuffManager引用（供外部查找）
func get_buff_manager() -> BuffManager:
	return buff_manager

## 弹出Buff通知（图标+文字，位于玩家右侧30px，白字红描边）
func show_buff_notification(icon_path: String, buff_name: String, prefix: String = "+ ") -> void:
	# 创建通知容器（挂到CanvasLayer下，使用屏幕坐标）
	var notif = Control.new()
	notif.name = "BuffNotification"
	notif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notif)

	# 获取玩家屏幕位置
	var player_screen_pos = _get_player_screen_position()
	notif.position = player_screen_pos + Vector2(30, 0)

	# 图标
	var icon = TextureRect.new()
	icon.size = Vector2(36, 36)
	icon.position = Vector2(0, 0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	notif.add_child(icon)

	# 文字标签（白字红描边）
	var custom_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	var label = Label.new()
	label.size = Vector2(200, 28)
	label.position = Vector2(32, 0)
	label.text = prefix + buff_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.RED)
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notif.add_child(label)

	# 初始透明
	notif.modulate.a = 0.0

	# 动画：淡入 → 停留 → 淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notif, "modulate:a", 1.0, 0.2)
	tween.tween_property(notif, "position:y", notif.position.y - 20, 0.2)
	await tween.finished

	await get_tree().create_timer(1.2).timeout

	var fade_tween = create_tween()
	fade_tween.tween_property(notif, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	notif.queue_free()

## 获取玩家在屏幕上的位置（用于UI坐标转换）
func _get_player_screen_position() -> Vector2:
	if not PC.player_instance or not is_instance_valid(PC.player_instance):
		return Vector2(200, 400) # 默认位置
	# 世界坐标 → 屏幕坐标：用 canvas_transform 正向变换
	return get_viewport().get_canvas_transform() * PC.player_instance.global_position
