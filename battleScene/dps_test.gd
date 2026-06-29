extends Node2D

@export var player: CharacterBody2D
@export var layer_ui: BattleCanvasLayer
@export var small_dummy_scene: PackedScene
@export var big_dummy_scene: PackedScene
@export var predictive_aiming_scene: PackedScene
@export var ring_fire_helper_scene: PackedScene
@export var riyan_scene: PackedScene

const ZHUAZHUAJUCHUI_SCRIPT = preload("res://Script/skill/zhuazhuajuchui.gd")
const MAX_DUMMIES: int = 50
const MAX_WEAPONS: int = 5
const CONTROL_BUTTON_SIZE: Vector2 = Vector2(112, 32)
const CONTROL_PANEL_POSITION: Vector2 = Vector2(12, 82)
const CONTROL_PANEL_MIN_SIZE: Vector2 = Vector2(378, 146)
const TEST_UI_FONT: FontFile = preload("res://AssetBundle/Uranus_Pixel_11Px.ttf")
const RING_FIRE_WEAPON_ID: String = "RingFire"
const RING_FIRE_REWARD_ID: String = "Ringfire"
const RING_FIRE_SKILL_ICON: String = "res://AssetBundle/Sprites/Sprite sheets/skillIcon/lihuo.png"
const PLAYER_ATTACK_NODE_NAMES: Array[String] = [
	"BloodWave",
	"BloodBroadsword",
	"IceFlower",
	"LightBullet",
	"Water",
	"Thunder",
	"ThunderBreak",
	"Xuanwu",
	"Xunfeng",
	"Genshan",
	"Duize",
	"HolyLight",
	"DragonWind",
	"Qigong",
	"Zhuazhuajuchui",
]
const PLAYER_ATTACK_SCRIPT_PATHS: Array[String] = [
	"res://Script/skill/blood_wave.gd",
	"res://Script/skill/blood_broadsword.gd",
	"res://Script/skill/ice_flower.gd",
	"res://Script/skill/light_bullet.gd",
	"res://Script/skill/water.gd",
	"res://Script/skill/thunder.gd",
	"res://Script/skill/thunder_break.gd",
	"res://Script/skill/xuanwu.gd",
	"res://Script/skill/xunfeng.gd",
	"res://Script/skill/genshan.gd",
	"res://Script/skill/duize.gd",
	"res://Script/skill/holy_light.gd",
	"res://Script/skill/dragon_wind.gd",
	"res://Script/skill/qigong.gd",
	"res://Script/config/moyan.gd",
	"res://Script/config/branch.gd",
	"res://Script/config/bullet.gd",
	"res://Script/skill/zhuazhuajuchui.gd",
]
const WEAPON_TIMER_PROPERTIES: Dictionary = {
	"SwordQi": "fire_speed",
	"Branch": "branch_fire_speed",
	"Moyan": "moyan_fire_speed",
	"Riyan": "riyan_fire_speed",
	"RingFire": "ringFire_fire_speed",
	"Thunder": "thunder_fire_speed",
	"Bloodwave": "bloodwave_fire_speed",
	"BloodBoardSword": "bloodboardsword_fire_speed",
	"Ice": "ice_flower_fire_speed",
	"ThunderBreak": "thunder_break_fire_speed",
	"LightBullet": "light_bullet_fire_speed",
	"Water": "water_fire_speed",
	"Qiankun": "qiankun_fire_speed",
	"Xuanwu": "xuanwu_fire_speed",
	"Xunfeng": "xunfeng_fire_speed",
	"Genshan": "genshan_fire_speed",
	"Duize": "duize_fire_speed",
	"HolyLight": "holy_light_fire_speed",
	"DragonWind": "dragonwind_fire_speed",
	"Qigong": "qigong_fire_speed",
	"Zhuazhuajuchui": "zhuazhuajuchui_fire_speed",
}
const EXTRA_WEAPON_NAMES: Dictionary = {
	"Zhuazhuajuchui": "爪爪巨锤",
	"Zhuazhuajuchui1": "震击",
	"Zhuazhuajuchui2": "震慑",
	"Zhuazhuajuchui3": "震撼",
	"Zhuazhuajuchui4": "震爆",
	"Zhuazhuajuchui11": "震击-震爆",
	"Zhuazhuajuchui22": "震慑-震击",
	"Zhuazhuajuchui33": "震撼-震爆",
}
const EXTRA_WEAP_TO_FACTION: Dictionary = {
	"Zhuazhuajuchui": "Zhuazhuajuchui",
}
const EXTRA_ADVANCEMENTS: Dictionary = {
	"Zhuazhuajuchui": [
		{"id": "Zhuazhuajuchui1", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui2", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui3", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui4", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui11", "precondition": "check_Zhuazhuajuchui1", "requires": ["Zhuazhuajuchui1", "Zhuazhuajuchui4"]},
		{"id": "Zhuazhuajuchui22", "precondition": "check_Zhuazhuajuchui2", "requires": ["Zhuazhuajuchui2", "Zhuazhuajuchui1"]},
		{"id": "Zhuazhuajuchui33", "precondition": "check_Zhuazhuajuchui3", "requires": ["Zhuazhuajuchui3", "Zhuazhuajuchui4"]},
	],
}

var point: int = 0
var spirit: int = 0
var spirit_raw: float = 0.0
var map_mechanism_num: float = 0.0
var map_mechanism_num_max: float = 1.0
var boss_event_triggered: bool = false

var _dummies: Array[Node2D] = []
var _available_weapons: Array[String] = []
var _added_weapons: Array[String] = []
var _selected_advancements: Dictionary = {}
var _controls_layer: CanvasLayer
var _weapon_popup_layer: CanvasLayer
var _weapon_popup: Panel
var _weapon_select: OptionButton
var _adv_list: VBoxContainer
var _status_label: Label
var _dps_label: Label
var _weapon_count_label: Label
var _add_weapon_button: Button
var _adv_checkboxes: Dictionary = {}
var _ui_update_accumulator: float = 0.0
var _post_reset_weapon_cleanup_time: float = 0.0

func _enter_tree() -> void:
	Global.current_stage_id = "dps_test"
	Global.current_stage_difficulty = Global.STAGE_DIFFICULTY_SHALLOW
	Global.current_core_depth = Global.CORE_DEPTH_MIN
	Global.corrupted_elite_enabled = false
	Global.in_town = false
	Global.in_menu = false
	Global.is_level_up = false
	Global.victory_collecting = false
	Global.reset_game_speed()
	if PC != null and PC.has_method("reset_player_attr"):
		PC.reset_player_attr()
	_reset_dps_test_weapons(false)
	Global.reset_dps_counter()
	DpsManager.reset_dps_counter()

func _ready() -> void:
	y_sort_enabled = true
	if player == null:
		player = get_node_or_null("Player") as CharacterBody2D
	if layer_ui == null:
		layer_ui = get_node_or_null("CanvasLayer") as BattleCanvasLayer
	PC.player_instance = player
	spirit = 0
	spirit_raw = 0.0
	PC.sync_spirit(spirit_raw)
	_setup_player_helpers()
	_clear_default_weapons()
	_init_available_weapons()
	_build_controls()
	_build_weapon_popup()
	_update_battle_ui(0.0)

func _exit_tree() -> void:
	Global.reset_dps_test_timer()

func _process(delta: float) -> void:
	_ui_update_accumulator += delta
	if _ui_update_accumulator >= 0.1:
		_ui_update_accumulator = 0.0
		_update_test_dps_label()
		_update_dummy_and_weapon_status()
	if _post_reset_weapon_cleanup_time > 0.0:
		_post_reset_weapon_cleanup_time = max(0.0, _post_reset_weapon_cleanup_time - delta)
		if _added_weapons.is_empty():
			_clear_active_weapon_nodes()
	if layer_ui != null and player != null:
		layer_ui.check_and_update_skill_icons(player)
		layer_ui.update_dps_display()
		_sync_ring_fire_static_icon()

func _physics_process(delta: float) -> void:
	PC.real_time += delta
	PC.current_time = PC.real_time
	PC.update_shields(delta)
	_update_battle_ui(delta)

func _setup_player_helpers() -> void:
	if player == null:
		return
	if predictive_aiming_scene != null and player.get_node_or_null("predictiveAiming") == null:
		var predictive: Node = predictive_aiming_scene.instantiate()
		predictive.name = "predictiveAiming"
		player.add_child(predictive)
	if ring_fire_helper_scene != null and player.get_node_or_null("ringFire") == null:
		var ring_helper: Node = ring_fire_helper_scene.instantiate()
		ring_helper.name = "ringFire"
		player.add_child(ring_helper)
	if riyan_scene != null:
		player.set("riyan_scene", riyan_scene)

func _clear_default_weapons() -> void:
	_reset_dps_test_weapons(true)
	Global.reset_dps_counter()
	DpsManager.reset_dps_counter()
	_update_dummy_and_weapon_status()
	_update_test_dps_label()

func _reset_dps_test_weapons(clear_config_selection: bool) -> void:
	if clear_config_selection:
		_added_weapons.clear()
		_selected_advancements.clear()
	PC.selected_rewards.clear()
	PC.current_weapon_num = 0
	PC.new_weapon_obtained_count = 0
	_reset_faze_state()
	_reset_main_weapon_state()
	_reset_first_weapon_flags()
	_reset_weapon_runtime_data()
	_clear_active_weapon_nodes()
	PC.ring_bullet_enabled = false
	PC.wave_bullet_enabled = false
	PC.ring_bullet_count = 8
	PC.ring_bullet_size_multiplier = 0.9
	PC.ring_bullet_damage_multiplier = 0.7
	PC.ring_bullet_interval = 2.5
	PC.ring_bullet_last_shot_time = PC.real_time + 999999.0
	PC.wave_bullet_count = 8
	PC.wave_bullet_damage_multiplier = 0.5
	PC.wave_bullet_interval = 4.0
	PC.wave_bullet_last_shot_time = PC.real_time + 999999.0
	if player != null:
		if player.has_method("stop_all_skill_cooldowns"):
			player.stop_all_skill_cooldowns()
		if player.has_method("cancel_weapon_runtime_actions"):
			player.cancel_weapon_runtime_actions()
		if player.has_method("update_skill_attack_speeds"):
			player.update_skill_attack_speeds()
	if layer_ui != null:
		if layer_ui.has_method("stop_all_skill_cooldowns"):
			layer_ui.stop_all_skill_cooldowns()
		_hide_all_skill_icons()
		if layer_ui.has_method("refresh_faze_ui"):
			layer_ui.refresh_faze_ui()
	if _weapon_popup_layer != null and _weapon_popup_layer.visible:
		_populate_weapon_popup()
	_post_reset_weapon_cleanup_time = 0.35

func _reset_faze_state() -> void:
	PC.faze_blood_level = 0
	PC.faze_sword_level = 0
	PC.faze_thunder_level = 0
	PC.faze_heal_level = 0
	PC.faze_summon_level = 0
	PC.faze_shield_level = 0
	PC.faze_fire_level = 0
	PC.faze_destroy_level = 0
	PC.faze_life_level = 0
	PC.faze_bullet_level = 0
	PC.faze_wide_level = 0
	PC.faze_bagua_level = 0
	PC.faze_treasure_level = 0
	PC.faze_chaos_level = 0
	PC.faze_skill_level = 0
	PC.faze_sixsense_level = 0
	PC.faze_wind_level = 0
	PC.faze_bagua_progress = 0
	PC.faze_bagua_completed_layers = 0
	PC.faze_bagua_next_threshold = 100
	PC.faze_bagua_damage_bonus = 0.0
	PC.faze_bagua_gain_multiplier = 1.0
	PC.faze_wide_range_bonus = 0.0
	PC.faze_wide_damage_bonus = 0.0
	PC.faze_wide_range_to_damage_ratio = 0.0
	PC.faze_sword_coldlight_stack = 0
	PC.faze_heal_shield_bonus = 0.0
	PC.has_summoned_bipolar_sword = false
	PC.has_summoned_sword_spirit = false

func _reset_main_weapon_state() -> void:
	PC.main_skill_swordQi = 0
	PC.main_skill_swordQi_advance = 0
	PC.main_skill_swordQi_damage = 1.0
	PC.swordQi_penetration_count = 1
	PC.swordQi_other_sword_wave_damage = 0.3
	PC.swordQi_range = 132
	PC.main_skill_moyan = 0
	PC.main_skill_moyan_advance = 0
	PC.main_skill_moyan_damage = 2.25
	PC.moyan_range = 220.0
	PC.main_skill_branch = 0
	PC.main_skill_branch_advance = 0
	PC.main_skill_branch_damage = 1.0
	PC.branch_split_count = 3
	PC.branch_range = 90
	PC.main_skill_riyan = 0
	PC.main_skill_riyan_advance = 0
	PC.main_skill_riyan_damage = 1.0
	PC.riyan_range = 70.0
	PC.riyan_cooldown = 1.0
	PC.riyan_hp_max_damage = 0.08
	PC.riyan_atk_damage = 0.24
	PC.main_skill_ringFire = 0
	PC.main_skill_ringFire_advance = 0
	PC.main_skill_ringFire_damage = 0.4
	PC.main_skill_thunder = 0
	PC.main_skill_thunder_advance = 0
	PC.main_skill_thunder_damage = 0.85
	PC.thunder_range = 260.0
	PC.main_skill_bloodwave = 0
	PC.main_skill_bloodwave_advance = 0
	PC.main_skill_bloodboardsword = 0
	PC.main_skill_bloodboardsword_advance = 0
	PC.main_skill_bloodboardsword_damage = 0.80
	PC.main_skill_ice = 0
	PC.main_skill_ice_advance = 0
	PC.main_skill_thunder_break = 0
	PC.main_skill_thunder_break_advance = 0
	PC.main_skill_thunder_break_damage = 0.65
	PC.thunder_break_final_damage_multi = 1.0
	PC.main_skill_light_bullet = 0
	PC.main_skill_light_bullet_advance = 0
	PC.main_skill_light_bullet_damage = 0.45
	PC.light_bullet_final_damage_multi = 1.0
	PC.main_skill_water = 0
	PC.main_skill_water_advance = 0
	PC.main_skill_water_damage = 0.40
	PC.water_final_damage_multi = 1.0
	PC.main_skill_qiankun = 0
	PC.main_skill_qiankun_advance = 0
	PC.main_skill_xuanwu = 0
	PC.main_skill_xuanwu_advance = 0
	PC.main_skill_xunfeng = 0
	PC.main_skill_xunfeng_advance = 0
	PC.main_skill_dragonwind = 0
	PC.main_skill_dragonwind_advance = 0
	PC.main_skill_dragonwind_damage = 1.0
	PC.main_skill_genshan = 0
	PC.main_skill_genshan_advance = 0
	PC.main_skill_duize = 0
	PC.main_skill_duize_advance = 0
	PC.main_skill_holylight = 0
	PC.main_skill_holylight_advance = 0
	PC.main_skill_qigong = 0
	PC.main_skill_qigong_advance = 0
	PC.main_skill_qigong_damage = 0.0
	PC.main_skill_zhuazhuajuchui = 0
	PC.main_skill_zhuazhuajuchui_advance = 0

func _reset_first_weapon_flags() -> void:
	PC.first_has_swordqi = true
	PC.first_has_branch = true
	PC.first_has_moyan = true
	PC.first_has_riyan = true
	PC.first_has_riyan_pc = true
	PC.first_has_ringFire = true
	PC.first_has_thunder = true
	PC.first_has_bloodwave = true
	PC.first_has_bloodboardsword = true
	PC.first_has_ice = true
	PC.first_has_thunder_break = true
	PC.first_has_light_bullet = true
	PC.first_has_water = true
	PC.first_has_qiankun = true
	PC.first_has_xuanwu = true
	PC.first_has_xunfeng = true
	PC.first_has_genshan = true
	PC.first_has_duize = true
	PC.first_has_holylight = true
	PC.first_has_qigong = true
	PC.first_has_dragonwind = true
	PC.first_has_zhuazhuajuchui = true

func _reset_weapon_runtime_data() -> void:
	IceFlower.reset_data()
	BloodWave.reset_data()
	Qiankun.reset_data()
	Xuanwu.reset_data()
	Xunfeng.reset_data()
	DragonWind.reset_data()
	Genshan.reset_data()
	Duize.reset_data()
	HolyLight.reset_data()
	Qigong.sync_reward_modifiers()
	ZHUAZHUAJUCHUI_SCRIPT.reset_data()

func _clear_active_weapon_nodes() -> void:
	_clear_player_attack_group("bullet")
	_clear_player_attack_group("sword_wave_trace")
	_clear_named_player_attack_nodes()
	_clear_qiankun_instances()
	_reset_player_weapon_helpers()

func _clear_player_attack_group(group_name: String) -> void:
	var nodes: Array = get_tree().get_nodes_in_group(group_name)
	for raw_node in nodes:
		var node: Node = raw_node as Node
		if _has_group_ancestor(node, group_name):
			continue
		if _should_clear_player_attack_node(node):
			_dispose_weapon_node(node)

func _clear_named_player_attack_nodes() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	for raw_child in current_scene.get_children():
		var child: Node = raw_child as Node
		if _should_clear_player_attack_node(child) and _is_player_attack_root(child):
			_dispose_weapon_node(child)

func _has_group_ancestor(node: Node, group_name: String) -> bool:
	if node == null:
		return false
	var parent_node: Node = node.get_parent()
	while parent_node != null:
		if parent_node.is_in_group(group_name):
			return true
		parent_node = parent_node.get_parent()
	return false

func _should_clear_player_attack_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node == player or (player != null and player.is_ancestor_of(node)):
		return false
	if node.is_in_group("enemies") or node.is_in_group("boss") or node.is_in_group("boss_projectile") or node.is_in_group("boss_bullet"):
		return false
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and not current_scene.is_ancestor_of(node) and node != current_scene:
		return false
	return true

func _is_player_attack_root(node: Node) -> bool:
	if node == null:
		return false
	if PLAYER_ATTACK_NODE_NAMES.has(str(node.name)):
		return true
	var script: Script = node.get_script() as Script
	if script != null and PLAYER_ATTACK_SCRIPT_PATHS.has(script.resource_path):
		return true
	return false

func _dispose_weapon_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("_object_pool"):
		ObjectPool.recycle(node)
	else:
		node.queue_free()

func _clear_qiankun_instances() -> void:
	if Qiankun.qian_instance != null and is_instance_valid(Qiankun.qian_instance):
		Qiankun.qian_instance.queue_free()
	if Qiankun.kun_instance != null and is_instance_valid(Qiankun.kun_instance):
		Qiankun.kun_instance.queue_free()
	Qiankun.qian_instance = null
	Qiankun.kun_instance = null

func _reset_player_weapon_helpers() -> void:
	if player == null:
		return
	var ring_helper: Node = player.get_node_or_null("ringFire")
	if ring_helper != null:
		for raw_child in ring_helper.get_children():
			var child: Node = raw_child as Node
			_dispose_weapon_node(child)
	var riyan_helper: Node = player.get_node_or_null("Riyan")
	if riyan_helper != null:
		_reset_riyan_helper(riyan_helper)
	elif riyan_scene != null:
		var new_riyan: Node = riyan_scene.instantiate()
		new_riyan.name = "Riyan"
		player.add_child(new_riyan)
		player.set("riyan_scene", riyan_scene)

func _reset_riyan_helper(riyan_helper: Node) -> void:
	var damage_timer: Timer = riyan_helper.get_node_or_null("Timer") as Timer
	if damage_timer != null:
		damage_timer.stop()
	for raw_child in riyan_helper.get_children():
		var child: Node = raw_child as Node
		if child != damage_timer:
			_dispose_weapon_node(child)
	riyan_helper.set("player_node", null)
	riyan_helper.set("is_initialized", false)
	riyan_helper.set("draw_node", null)
	riyan_helper.set("collision_shape", null)
	riyan_helper.set("current_range_multiplier", 1.0)
	riyan_helper.set("current_speed_multiplier", 1.0)
	riyan_helper.set("pulse_time", 0.0)

func _hide_all_skill_icons() -> void:
	var skills: Array = [
		layer_ui.skill1, layer_ui.skill2, layer_ui.skill3, layer_ui.skill4, layer_ui.skill5,
		layer_ui.skill6, layer_ui.skill7, layer_ui.skill8, layer_ui.skill9, layer_ui.skill10,
		layer_ui.skill11, layer_ui.skill12, layer_ui.skill13, layer_ui.skill14, layer_ui.skill15,
		layer_ui.skill16, layer_ui.skill17, layer_ui.skill18, layer_ui.skill19, layer_ui.skill20,
		layer_ui.skill21
	]
	for icon in skills:
		if icon != null:
			if icon.has_method("stop_cooldown"):
				icon.stop_cooldown()
			icon.visible = false

func _init_available_weapons() -> void:
	_available_weapons.clear()
	for w_id in WeapDataExport.WEAPON_IDS:
		if _is_weapon_unlocked(w_id):
			_available_weapons.append(w_id)

func _is_weapon_unlocked(w_id: String) -> bool:
	var id_map: Dictionary = {
		"Qiankun": "qiankun", "DragonWind": "dragonwind", "Bloodwave": "bloodwave",
		"Water": "water", "Moyan": "baoyan", "Genshan": "genshan",
		"ThunderBreak": "thunder_break", "HolyLight": "holylight", "Xuanwu": "xuanwu"
	}
	var check_id: String = str(id_map.get(w_id, ""))
	if not check_id.is_empty():
		return SettingStudyTreeUp.is_weapon_unlocked(check_id)
	return true

func _build_controls() -> void:
	_controls_layer = CanvasLayer.new()
	_controls_layer.layer = 35
	add_child(_controls_layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "DpsTestControls"
	panel.position = CONTROL_PANEL_POSITION
	panel.size = CONTROL_PANEL_MIN_SIZE
	panel.custom_minimum_size = CONTROL_PANEL_MIN_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_controls_layer.add_child(panel)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.03, 0.78)
	style.border_color = Color(0.7, 0.78, 0.86, 0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	_status_label = Label.new()
	_status_label.text = "木桩 0 / 50    武器 0 / 5"
	_apply_test_label_style(_status_label, 20)
	vbox.add_child(_status_label)
	_dps_label = Label.new()
	_dps_label.text = "DPS测试：未开始"
	_apply_test_label_style(_dps_label, 20)
	vbox.add_child(_dps_label)
	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)
	_add_control_button(row1, "添加小桩", _on_add_small_dummy_pressed)
	_add_control_button(row1, "添加大桩", _on_add_big_dummy_pressed)
	_add_control_button(row1, "去除木桩", _on_remove_dummy_pressed)
	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)
	_add_control_button(row2, "武器配置", _on_weapon_config_pressed)
	_add_control_button(row2, "玩家升级", _on_player_level_up_pressed)
	_add_control_button(row2, "重置武器", _on_reset_weapons_pressed)
	var row3: HBoxContainer = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	vbox.add_child(row3)
	_add_control_button(row3, "开始计时", _on_start_timer_pressed)
	_add_control_button(row3, "停止计时", _on_stop_timer_pressed)
	_add_control_button(row3, "重置技能CD", _on_reset_active_skill_cooldowns_pressed)

func _add_control_button(parent: Control, text: String, callable: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = CONTROL_BUTTON_SIZE
	_apply_test_button_style(button, 20)
	button.pressed.connect(callable)
	parent.add_child(button)
	return button

func _apply_test_label_style(label: Label, font_size: int) -> void:
	label.add_theme_font_override("font", TEST_UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)

func _apply_test_button_style(button: Button, font_size: int) -> void:
	button.add_theme_font_override("font", TEST_UI_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.70, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.96, 0.70, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	button.add_theme_constant_override("outline_size", 4)
	if button is OptionButton:
		var option_button: OptionButton = button as OptionButton
		var popup: PopupMenu = option_button.get_popup()
		popup.add_theme_font_override("font", TEST_UI_FONT)
		popup.add_theme_font_size_override("font_size", font_size)
		popup.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86, 1.0))
		popup.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.70, 1.0))
		popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		popup.add_theme_constant_override("outline_size", 4)

func _build_weapon_popup() -> void:
	_weapon_popup_layer = CanvasLayer.new()
	_weapon_popup_layer.layer = 40
	_weapon_popup_layer.visible = false
	add_child(_weapon_popup_layer)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weapon_popup_layer.add_child(root)
	var blocker: ColorRect = ColorRect.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color(0, 0, 0, 0.35)
	root.add_child(blocker)
	_weapon_popup = Panel.new()
	_weapon_popup.position = Vector2(390, 92)
	_weapon_popup.size = Vector2(560, 560)
	root.add_child(_weapon_popup)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.035, 0.045, 0.95)
	panel_style.border_color = Color(0.75, 0.8, 0.86, 0.5)
	panel_style.set_border_width_all(1)
	_weapon_popup.add_theme_stylebox_override("panel", panel_style)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(14, 14)
	vbox.size = Vector2(532, 532)
	vbox.add_theme_constant_override("separation", 8)
	_weapon_popup.add_child(vbox)
	var title: Label = Label.new()
	title.text = "武器配置"
	_apply_test_label_style(title, 24)
	vbox.add_child(title)
	_weapon_count_label = Label.new()
	_weapon_count_label.text = ""
	_apply_test_label_style(_weapon_count_label, 18)
	vbox.add_child(_weapon_count_label)
	_weapon_select = OptionButton.new()
	_weapon_select.custom_minimum_size = Vector2(360, 34)
	_apply_test_button_style(_weapon_select, 18)
	_weapon_select.item_selected.connect(_on_weapon_selected)
	vbox.add_child(_weapon_select)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(532, 370)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_adv_list = VBoxContainer.new()
	_adv_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_adv_list)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)
	_add_weapon_button = Button.new()
	_add_weapon_button.text = "添加武器"
	_add_weapon_button.custom_minimum_size = Vector2(120, 34)
	_apply_test_button_style(_add_weapon_button, 18)
	_add_weapon_button.pressed.connect(_on_add_weapon_pressed)
	buttons.add_child(_add_weapon_button)
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(86, 34)
	_apply_test_button_style(close_button, 18)
	close_button.pressed.connect(_hide_weapon_popup)
	buttons.add_child(close_button)

func _populate_weapon_popup() -> void:
	if _weapon_select == null:
		return
	var current_selection: String = ""
	if _weapon_select.selected >= 0:
		current_selection = str(_weapon_select.get_item_metadata(_weapon_select.selected))
	_weapon_select.clear()
	_weapon_select.add_item("---")
	_weapon_select.set_item_metadata(0, "")
	var select_index: int = 0
	var idx: int = 1
	for w_id in _available_weapons:
		if _added_weapons.has(w_id):
			continue
		_weapon_select.add_item(_get_weapon_display_name(w_id))
		_weapon_select.set_item_metadata(idx, w_id)
		if w_id == current_selection:
			select_index = idx
		idx += 1
	_weapon_select.select(select_index)
	_update_advancement_list()
	_update_weapon_popup_status()

func _update_advancement_list() -> void:
	if _adv_list == null:
		return
	for child in _adv_list.get_children():
		child.queue_free()
	_adv_checkboxes.clear()
	var w_id: String = _get_selected_weapon_id()
	if w_id.is_empty():
		return
	var faction: String = _get_weapon_faction(w_id)
	var advancements: Array = _get_weapon_advancements(faction)
	if faction.is_empty() or advancements.is_empty():
		return
	var selected: Array[String] = _get_selected_advancement_ids()
	for adv in advancements:
		if typeof(adv) != TYPE_DICTIONARY:
			continue
		var adv_id: String = str(adv.get("id", ""))
		if adv_id.is_empty():
			continue
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = _get_weapon_display_name(adv_id)
		_apply_test_button_style(checkbox, 18)
		checkbox.set_meta("adv_id", adv_id)
		checkbox.button_pressed = selected.has(adv_id)
		checkbox.toggled.connect(_on_advancement_toggled.bind(adv_id))
		_adv_list.add_child(checkbox)
		_adv_checkboxes[adv_id] = checkbox
	_refresh_advancement_enable_states()

func _on_weapon_selected(_index: int) -> void:
	var w_id: String = _get_selected_weapon_id()
	if not w_id.is_empty() and not _selected_advancements.has(w_id):
		_selected_advancements[w_id] = []
	_update_advancement_list()
	_update_weapon_popup_status()

func _on_advancement_toggled(pressed: bool, adv_id: String) -> void:
	var w_id: String = _get_selected_weapon_id()
	if w_id.is_empty():
		return
	var selected: Array[String] = _get_selected_advancement_ids()
	if pressed:
		if not selected.has(adv_id):
			selected.append(adv_id)
	else:
		selected.erase(adv_id)
	_selected_advancements[w_id] = selected
	_remove_invalid_advancement_selections()
	_refresh_advancement_enable_states()

func _remove_invalid_advancement_selections() -> void:
	var changed: bool = true
	while changed:
		changed = false
		var selected: Array[String] = _get_selected_advancement_ids()
		var available_keys: Array[String] = _get_selection_keys_for_advancements(selected)
		for adv_id in selected.duplicate():
			for req in _get_adv_requires(adv_id):
				if not available_keys.has(req):
					selected.erase(adv_id)
					changed = true
					break
		_selected_advancements[_get_selected_weapon_id()] = selected

func _refresh_advancement_enable_states() -> void:
	var selected: Array[String] = _get_selected_advancement_ids()
	var available_keys: Array[String] = _get_selection_keys_for_advancements(selected)
	for adv_id in _adv_checkboxes.keys():
		var checkbox: CheckBox = _adv_checkboxes[adv_id] as CheckBox
		if checkbox == null:
			continue
		var can_select: bool = true
		for req in _get_adv_requires(adv_id):
			if not available_keys.has(req):
				can_select = false
				break
		checkbox.set_pressed_no_signal(selected.has(adv_id))
		checkbox.disabled = not selected.has(adv_id) and not can_select

func _get_selection_keys_for_advancements(selected: Array[String]) -> Array[String]:
	var keys: Array[String] = []
	var w_id: String = _get_selected_weapon_id()
	if not w_id.is_empty():
		_append_advancement_key(keys, w_id)
		var faction: String = _get_weapon_faction(w_id)
		if not faction.is_empty():
			_append_advancement_key(keys, faction)
	for adv_id in selected:
		_append_advancement_key(keys, adv_id)
	return keys

func _append_advancement_key(keys: Array[String], key: String) -> void:
	if key.is_empty():
		return
	if not keys.has(key):
		keys.append(key)
	var lower_key: String = key.to_lower()
	if not keys.has(lower_key):
		keys.append(lower_key)

func _get_adv_requires(adv_id: String) -> Array[String]:
	for faction in _get_all_advancement_factions():
		for adv in _get_weapon_advancements(faction):
			if typeof(adv) == TYPE_DICTIONARY and str(adv.get("id", "")) == adv_id:
				var requires: Array[String] = []
				for req in adv.get("requires", []):
					requires.append(str(req))
				return requires
	var empty_requires: Array[String] = []
	return empty_requires

func _get_selected_weapon_id() -> String:
	if _weapon_select == null or _weapon_select.selected < 0:
		return ""
	return str(_weapon_select.get_item_metadata(_weapon_select.selected))

func _get_selected_advancement_ids() -> Array[String]:
	var w_id: String = _get_selected_weapon_id()
	if w_id.is_empty():
		var empty_selection: Array[String] = []
		return empty_selection
	if not _selected_advancements.has(w_id):
		_selected_advancements[w_id] = []
	var result: Array[String] = []
	for adv_id in _selected_advancements[w_id]:
		result.append(str(adv_id))
	return result

func _update_weapon_popup_status() -> void:
	if _weapon_count_label != null:
		_weapon_count_label.text = "已添加武器：%d / %d" % [_added_weapons.size(), MAX_WEAPONS]
	if _add_weapon_button != null:
		_add_weapon_button.disabled = _get_selected_weapon_id().is_empty() or _added_weapons.size() >= MAX_WEAPONS

func _on_add_weapon_pressed() -> void:
	var w_id: String = _get_selected_weapon_id()
	if w_id.is_empty():
		_show_status_tip("请选择武器")
		return
	if _added_weapons.has(w_id):
		_show_status_tip("该武器已经添加")
		return
	if _added_weapons.size() >= MAX_WEAPONS:
		_show_status_tip("最多只能添加 5 把武器")
		return
	var adv_ids: Array[String] = _get_selected_advancement_ids()
	_grant_reward_without_level_growth(w_id)
	for adv_id in adv_ids:
		_grant_reward_without_level_growth(str(adv_id))
	_start_weapon_timer(w_id)
	_added_weapons.append(w_id)
	if layer_ui != null:
		layer_ui.check_and_update_skill_icons(player)
		if w_id == RING_FIRE_WEAPON_ID:
			_sync_ring_fire_static_icon()
		if layer_ui.has_method("refresh_faze_ui"):
			layer_ui.refresh_faze_ui()
	_update_dummy_and_weapon_status()
	_populate_weapon_popup()
	_show_status_tip("已添加：" + _get_weapon_display_name(w_id))

func _get_weapon_display_name(weapon_id: String) -> String:
	if EXTRA_WEAPON_NAMES.has(weapon_id):
		return str(EXTRA_WEAPON_NAMES[weapon_id])
	return str(WeapDataExport.WEAPON_NAMES.get(weapon_id, weapon_id))

func _get_weapon_faction(weapon_id: String) -> String:
	if EXTRA_WEAP_TO_FACTION.has(weapon_id):
		return str(EXTRA_WEAP_TO_FACTION[weapon_id])
	return str(WeapDataExport.WEAP_TO_FACTION.get(weapon_id, ""))

func _get_weapon_advancements(faction: String) -> Array:
	if EXTRA_ADVANCEMENTS.has(faction):
		return EXTRA_ADVANCEMENTS[faction]
	if WeapDataExport.ADVANCEMENTS.has(faction):
		return WeapDataExport.ADVANCEMENTS[faction]
	return []

func _get_all_advancement_factions() -> Array[String]:
	var factions: Array[String] = []
	for faction in WeapDataExport.ADVANCEMENTS.keys():
		factions.append(str(faction))
	for faction in EXTRA_ADVANCEMENTS.keys():
		if not factions.has(str(faction)):
			factions.append(str(faction))
	return factions

func _grant_reward_without_level_growth(reward_id: String) -> void:
	var fn_name: String = "reward_" + reward_id
	if not LvUp.has_method(fn_name):
		push_warning("DPS test reward function missing: " + fn_name)
		return
	LvUp.begin_qi_vortex_shop_reward_context()
	LvUp.call(fn_name)
	LvUp.clear_reward_context()
	get_tree().paused = false
	Global.in_menu = false
	Global.is_level_up = false

func _start_weapon_timer(w_id: String) -> void:
	if player == null:
		return
	if player.has_method("update_skill_attack_speeds"):
		player.update_skill_attack_speeds()
	if w_id == RING_FIRE_WEAPON_ID:
		_activate_ring_fire_weapon()
		return
	var prop_name: String = str(WEAPON_TIMER_PROPERTIES.get(w_id, ""))
	if prop_name.is_empty():
		return
	var timer: Timer = player.get(prop_name) as Timer
	if timer != null:
		timer.paused = false
		timer.start()
	if w_id == "Riyan":
		Global.emit_signal("riyan_damage_triggered")
	elif w_id == "Qiankun" and player.has_method("init_qiankun"):
		player.init_qiankun()

func _activate_ring_fire_weapon() -> void:
	var timer: Timer = player.get("ringFire_fire_speed") as Timer
	if timer != null:
		timer.stop()
	var ring_helper: Node = player.get_node_or_null("ringFire")
	if ring_helper == null and ring_fire_helper_scene != null:
		ring_helper = ring_fire_helper_scene.instantiate()
		ring_helper.name = "ringFire"
		player.add_child(ring_helper)
	Global.emit_signal("ringFire_damage_triggered")
	_sync_ring_fire_static_icon()

func _sync_ring_fire_static_icon() -> void:
	if layer_ui == null or not PC.selected_rewards.has(RING_FIRE_REWARD_ID):
		return
	var icon: TextureButton = layer_ui.skill5
	if icon == null:
		return
	icon.visible = true
	if icon.has_method("set_static_skill"):
		icon.call("set_static_skill", 5, RING_FIRE_SKILL_ICON)
	elif icon.has_method("stop_cooldown"):
		icon.call("stop_cooldown")

func _on_add_small_dummy_pressed() -> void:
	_spawn_dummy(small_dummy_scene)

func _on_add_big_dummy_pressed() -> void:
	_spawn_dummy(big_dummy_scene)

func _spawn_dummy(scene: PackedScene) -> void:
	if scene == null or player == null:
		return
	_prune_invalid_dummies()
	if _dummies.size() >= MAX_DUMMIES:
		_show_status_tip("最多只能添加 50 个木桩")
		return
	var dummy: Node2D = scene.instantiate() as Node2D
	if dummy == null:
		return
	add_child(dummy)
	dummy.global_position = player.global_position
	_dummies.append(dummy)
	_update_dummy_and_weapon_status()

func _on_remove_dummy_pressed() -> void:
	_prune_invalid_dummies()
	if _dummies.is_empty():
		return
	var dummy: Node2D = _dummies.pop_back()
	if is_instance_valid(dummy):
		dummy.queue_free()
	_update_dummy_and_weapon_status()

func _prune_invalid_dummies() -> void:
	for i in range(_dummies.size() - 1, -1, -1):
		if not is_instance_valid(_dummies[i]):
			_dummies.remove_at(i)

func _on_weapon_config_pressed() -> void:
	_populate_weapon_popup()
	_weapon_popup_layer.visible = true
	Global.in_menu = true

func _hide_weapon_popup() -> void:
	_weapon_popup_layer.visible = false
	Global.in_menu = false

func _on_player_level_up_pressed() -> void:
	if layer_ui == null or PC.is_game_over:
		return
	var required_exp: int = layer_ui.get_required_lv_up_value(PC.pc_lv)
	layer_ui.add_pending_level_up()
	PC.pc_exp = clamp(PC.pc_exp - required_exp, 0, layer_ui.get_required_lv_up_value(PC.pc_lv + 1))
	PC.pc_lv += 1
	if Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY:
		LvUp.pre_apply_level_growth_for_pending_level()
	Global.emit_signal("player_lv_up")
	_update_battle_ui(0.0)

func _on_reset_weapons_pressed() -> void:
	_reset_dps_test_weapons(true)
	Global.reset_dps_counter()
	DpsManager.reset_dps_counter()
	_update_dummy_and_weapon_status()
	_update_test_dps_label()
	_show_status_tip("已重置武器")

func _on_start_timer_pressed() -> void:
	Global.start_dps_test_timer()
	_update_test_dps_label()

func _on_stop_timer_pressed() -> void:
	Global.stop_dps_test_timer()
	_update_test_dps_label()

func _on_reset_active_skill_cooldowns_pressed() -> void:
	if Global.active_skill_manager == null:
		_show_status_tip("主动技能管理器未初始化")
		return
	if Global.active_skill_manager.has_method("reset_all_skill_cooldowns"):
		Global.active_skill_manager.reset_all_skill_cooldowns()
		_show_status_tip("已重置主动技能CD")

func _update_test_dps_label() -> void:
	if _dps_label == null:
		return
	if not Global.has_dps_test_timer_data():
		_dps_label.text = "DPS测试：未开始"
		return
	var elapsed: float = Global.get_dps_test_elapsed_seconds()
	var total_dps: float = Global.get_dps_test_total_dps()
	var state: String = "计时中" if Global.is_dps_test_timer_active() else "已停止"
	_dps_label.text = "DPS测试：%s  %.1f 秒  DPS %s" % [state, elapsed, _format_number(total_dps)]

func _update_dummy_and_weapon_status() -> void:
	if _status_label != null:
		_status_label.text = "木桩 %d / %d    武器 %d / %d" % [_dummies.size(), MAX_DUMMIES, _added_weapons.size(), MAX_WEAPONS]
	if _weapon_count_label != null:
		_update_weapon_popup_status()

func _show_status_tip(text: String) -> void:
	if layer_ui != null and layer_ui.lv_up_tip != null and layer_ui.lv_up_tip.has_method("start_animation"):
		layer_ui.lv_up_tip.start_animation(text, 0.7)
		return
	if _status_label != null:
		_status_label.text = text

func _update_battle_ui(_delta: float) -> void:
	if layer_ui == null:
		return
	layer_ui.update_score_display(point, spirit)
	layer_ui.update_time_display(PC.real_time)
	layer_ui.update_hp_bar(PC.pc_hp, PC.pc_max_hp, PC.get_total_shield())
	layer_ui.update_lv_up_visibility()
	layer_ui.update_exp_bar(PC.pc_exp, layer_ui.get_required_lv_up_value(PC.pc_lv))
	layer_ui.update_mechanism_bar(map_mechanism_num, map_mechanism_num_max, boss_event_triggered)
	layer_ui.update_level_display(PC.pc_lv)
	layer_ui.update_skill_cooldowns(player)
	_sync_ring_fire_static_icon()

func add_spirit(amount: float) -> void:
	if amount <= 0.0:
		return
	spirit_raw += floor(amount * 10.0) / 10.0
	spirit = PC.get_display_spirit(spirit_raw)
	PC.sync_spirit(spirit_raw)

func spend_spirit(amount: int) -> bool:
	if spirit < amount:
		return false
	spirit_raw = max(0.0, spirit_raw - float(amount))
	spirit = PC.get_display_spirit(spirit_raw)
	PC.sync_spirit(spirit_raw)
	return true

func _format_number(value: float) -> String:
	return str(int(round(value)))
