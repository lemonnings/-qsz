@warning_ignore("unused_signal")
extends Node

const CONFIG_PATH = "user://game_config.cfg"
const LINGSHI_ITEM_ID := "item_084"
const DEBUG_F1_ZHENQI_AMOUNT := 1000000

# 测试模式：跳过开屏动画，直接进入游戏
var is_test: bool = false
var time_slow_enabled: bool = false
var is_debug: bool = true

# 保存指示器相关
const SAVE_INDICATOR_SCENE := preload("res://Scenes/global/loading_anime.tscn")
var _save_indicator_layer: CanvasLayer
var _save_indicator_tween: Tween

# 关卡难度ID常量。
# 这里统一用英文ID存数据，显示时再转换成中文，
# 这样后续存档和代码判断会更稳定，不容易因为中文改字而出问题。
const STAGE_DIFFICULTY_SHALLOW := "shallow"
const STAGE_DIFFICULTY_DEEP := "deep"
const STAGE_DIFFICULTY_CORE := "core"
const STAGE_DIFFICULTY_POETRY := "poetry"
const STAGE_DIFFICULTY_LIST := [
	STAGE_DIFFICULTY_SHALLOW,
	STAGE_DIFFICULTY_DEEP,
	STAGE_DIFFICULTY_CORE,
	STAGE_DIFFICULTY_POETRY
]

# 关卡ID列表。
# 这里只先接你当前提出的 4 个正式关卡。
const STAGE_ID_LIST := ["peach_grove", "ruin", "cave", "forest"]

# 各关卡在不同难度下的属性倍率。
const STAGE_DIFFICULTY_MULTIPLIERS := {
	"peach_grove": {
		STAGE_DIFFICULTY_SHALLOW: 1.0, # 30
		STAGE_DIFFICULTY_DEEP: 1.63, # 55
		STAGE_DIFFICULTY_CORE: 1.63 * 1.52, # 95
		STAGE_DIFFICULTY_POETRY: 1.63 * 1.52
	},
	"ruin": {
		STAGE_DIFFICULTY_SHALLOW: 1.0, # 45
		STAGE_DIFFICULTY_DEEP: 1.39, # 65
		STAGE_DIFFICULTY_CORE: 1.39 * 1.52, # 110
		STAGE_DIFFICULTY_POETRY: 1.39 * 1.52
	},
	"cave": {
		STAGE_DIFFICULTY_SHALLOW: 1.0, # 80
		STAGE_DIFFICULTY_DEEP: 1.4625, # 125
		STAGE_DIFFICULTY_CORE: 1.4625 * 1.2416, # 155
		STAGE_DIFFICULTY_POETRY: 1.4625 * 1.2416
	},
	"forest": {
		STAGE_DIFFICULTY_SHALLOW: 1.0, # 140
		STAGE_DIFFICULTY_DEEP: 1.1843, # 170
		STAGE_DIFFICULTY_CORE: 1.1843 * 1.069, # 185
		STAGE_DIFFICULTY_POETRY: 1.1843 * 1.069
	}
}

# 合成界面状态 - 用于禁用缩放等操作
var in_synthesis: bool = false

# Victory结算吸取阶段标志 - 物品自动飞向玩家时不实际回血
var victory_collecting: bool = false


# 纹章配置管理器
var setting_emblem = preload("res://Script/config/setting_emblem.gd").new()

# 音频管理器
var audio_manager = preload("res://Script/system/audio_manager.gd").new()

# 设置管理器
var settings_manager = preload("res://Script/system/settings_manager.gd").new()

# 滤镜管理器
var soft_glow_manager = preload("res://Script/system/soft_glow_manager.gd").new()

# 主动技能管理器
var active_skill_manager = preload("res://Script/config/active_skill_manager.gd").new()

# 装备管理器
var equipment_manager = preload("res://Script/config/equipment_manager.gd").new()

# 经验光点系统
var exp_orb_system = preload("res://Script/system/exp_orb_system.gd").new()

@export var total_points: int = 1000

@export var unlock_moning: bool = true
@export var unlock_yiqiu: bool = true
@export var unlock_noam: bool = true
@export var unlock_kansel: bool = true

@export var exp_multi: float = 0
@export var drop_multi: float = 0
@export var body_size: float = 1
@export var attack_range: float = 1.0
@export var heal_multi: float = 0
@export var sheild_multi: float = 0
@export var normal_monster_multi: float = 0
@export var boss_multi: float = 0
@export var cooldown: float = 0
@export var active_skill_multi: float = 0

@export var max_main_skill_num: int = 3
@export var max_weapon_num: int = 5

# 纹章相关字段
@export var emblem_slots_max: int = 4 # 纹章数量上限
@export var emblem_effect_rate: float = 0.0 # 纹章提升率

# 果实回复效果
@export var fruit_heal_multi: float = 1
@export var fruit_heal_multi_used_count: int = 0 # 回春露已使用次数（最多10次）

# 特殊秘丹使用上限
@export var special_pill_lower_max_uses: int = 50
@export var special_pill_middle_max_uses: int = 20
@export var special_pill_upper_max_uses: int = 10

# 丹药使用次数记录 {item_id: 已使用次数}
@export var pill_used_counts: Dictionary = {}

# 玩家背包与进度变量 
var player_inventory: Dictionary = {}
@export var lingshi: int = 0
@export var shop_level: int = 1
@export var shop_battle_refresh_count: int = 0
@export var shop_lingshi_unit_price: int = 50

# 仅在当前存档第一次进入货摊时自动刷新一次
@export var shop_first_entered: bool = false

# 当前货摊商品列表会保存在存档里，保证再次进入时仍显示上次的货物状态。
var shop_saved_items: Array = []

# 关卡难度通关记录
@export var stage_difficulty_clear_progress: Dictionary = {
	"peach_grove": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	},
	"ruin": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	},
	"cave": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	},
	"forest": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	}
}

# 当前在关卡选择界面里选中的难度
var selected_stage_difficulty: String = STAGE_DIFFICULTY_SHALLOW

# 当前真正进入战斗的关卡ID与难度
# 怪物配置会读这里，决定本次战斗应该套用哪一个倍率
var current_stage_id: String = ""
var current_stage_difficulty: String = STAGE_DIFFICULTY_SHALLOW

@export var recipe_unlock_progress: Dictionary = {
	"recipe_001": true,
	"recipe_002": false,
	"recipe_003": false,
	"recipe_004": false,
	"recipe_noam": false,
	"recipe_028": true
}

# lunky概率
@export var lunky_level: int = 1
@export var red_p: float = 0.5
@export var gold_p: float = 4
@export var darkorchid_p: float = 25.5
@export var blue_p: float = 70

# 刷新次数
@export var refresh_max_num: int = 999

# 修炼解锁进度Cultivation
@export var cultivation_unlock_progress: int = 0

# 装备系统相关
@export var max_carry_equipment_slots: int = 2 # 当前解锁的随身法宝槽位数量（初始2个，最大5个）

# 修炼等级变量
@export var cultivation_poxu_level: int = 0 # 破虚 - 提升攻击力
@export var cultivation_xuanyuan_level: int = 0 # 玄元 - 提升生命值
@export var cultivation_liuguang_level: int = 0 # 流光 - 提升攻速
@export var cultivation_hualing_level: int = 0 # 化灵 - 提升真气获取
@export var cultivation_fengrui_level: int = 0 # 锋锐 - 提升暴击率
@export var cultivation_huti_level: int = 0 # 护体 - 提升减伤率
@export var cultivation_zhuifeng_level: int = 0 # 追风 - 提升移速
@export var cultivation_liejin_level: int = 0 # 烈劲 - 提升暴击伤害
@export var cultivation_heyi_level: int = 0 # 合一 - 提升技能冷却
@export var cultivation_tongxiao_level: int = 0 # 通晓 - 提升最终伤害

# 修炼等级上限
@export var cultivation_poxu_level_max: int = 50
@export var cultivation_xuanyuan_level_max: int = 50
@export var cultivation_liuguang_level_max: int = 25
@export var cultivation_hualing_level_max: int = 50
@export var cultivation_fengrui_level_max: int = 25
@export var cultivation_huti_level_max: int = 25
@export var cultivation_zhuifeng_level_max: int = 25
@export var cultivation_liejin_level_max: int = 50

# 玩家修习技能数据
@export var player_study_data: Dictionary = {
	"yiqiu": {
		"study_level": 0,
		"learned_skills": [],
		"skill_levels": {}
	},
	"moning": {
		"study_level": 0,
		"learned_skills": [],
		"skill_levels": {}
	}
}

# 天赋树节点等级 { "weapon1-1": 0, "weapon2-2": 1, ... }
@export var player_study_tree: Dictionary = {}

@export var player_active_skill_data: Dictionary = {
	"dodge": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shanbi.png"
	},
	"mizongbu": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mizongbu.png"
	},
	"huanling": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mingxiang.png"
	},
	"random_strike": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/luanji.png"
	},
	"beastify": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shouhua.png"
	},
	"heal_hot": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yuliao.png"
	},
	"water_sheild": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shuiliumu.png"
	},
	"holy_fire": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png"
	},
	"wind_thunder": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/fengleipo.png"
	}
}


@export var player_now_active_skill: Dictionary = {
	"space": {"name": "dodge"},
	"q": {"name": "random_strike"},
	"e": {"name": "beastify"}
}

# 世界等级
@export var world_level_multiple: float = 1
@export var world_level_reward_multiple: float = 1
@export var world_level: int = 1

@export var in_menu: bool = true
@export var in_town: bool = false
@export var is_level_up: bool = false
@export var main_menu_instance: PackedScene = null
@export var has_visited_town: bool = false
@export var is_first_game: bool = true

# 信号定义
@warning_ignore("unused_signal")
signal player_hit(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String)
@warning_ignore("unused_signal")
signal player_hit_ignore_invincible(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String)
@warning_ignore("unused_signal")
signal player_instakill(attacker: Node2D, world_position: Vector2, source_name: String)
@warning_ignore("unused_signal")
signal player_lv_up
@warning_ignore("unused_signal")
signal lucky_level_up
@warning_ignore("unused_signal")
signal setup_summons
@warning_ignore("unused_signal")
signal level_up_selection_complete
@warning_ignore("unused_signal")
signal manual_level_up_pending
@warning_ignore("unused_signal")
signal player_heal(heal_value: float, world_position: Vector2)
@warning_ignore("unused_signal")
signal monster_damage
@warning_ignore("unused_signal")
signal monster_mechanism_gained
@warning_ignore("unused_signal")
signal monster_killed
@warning_ignore("unused_signal")
signal boss_defeated(get_point: int, boss_position: Vector2)
@warning_ignore("unused_signal")
signal skill_attack_speed_updated
@warning_ignore("unused_signal")
signal start_dialog(dialog_file_path: String)
@warning_ignore("unused_signal")
signal stage_bgm(stage_id: String)
@warning_ignore("unused_signal")
signal stage_ambient(stage_id: String)
@warning_ignore("unused_signal")
signal stop_ambient
@warning_ignore("unused_signal")
signal zoom_camera
@warning_ignore("unused_signal")
signal reset_camera
@warning_ignore("unused_signal")
signal boss_hp_bar_show
@warning_ignore("unused_signal")
signal boss_hp_bar_hide
@warning_ignore("unused_signal")
signal boss_hp_bar_initialize(max_hp: float, current_hp: float, bar_num: int)
@warning_ignore("unused_signal")
signal boss_hp_bar_take_damage(damage: float)
@warning_ignore("unused_signal")
signal boss_chant_start(skill_display_name: String, chant_duration: float)
@warning_ignore("unused_signal")
signal boss_chant_end
@warning_ignore("unused_signal")
signal player_chant_start(skill_display_name: String, chant_duration: float, icon_path: String)
@warning_ignore("unused_signal")
signal player_chant_end
@warning_ignore("unused_signal")
signal buff_added(buff_id: String, duration: float, stack: int)
@warning_ignore("unused_signal")
signal buff_removed(buff_id: String)
@warning_ignore("unused_signal")
signal buff_updated(buff_id: String, remaining_time: float, stack: int)
@warning_ignore("unused_signal")
signal buff_stack_changed(buff_id: String, new_stack: int)
@warning_ignore("unused_signal")
signal emblem_added(emblem_id: String, stack: int)
@warning_ignore("unused_signal")
signal emblem_removed(emblem_id: String)
@warning_ignore("unused_signal")
signal emblem_stack_changed(emblem_id: String, new_stack: int)
@warning_ignore("unused_signal")
signal skill_cooldown_complete
@warning_ignore("unused_signal")
signal skill_cooldown_complete_branch
@warning_ignore("unused_signal")
signal skill_cooldown_complete_moyan
@warning_ignore("unused_signal")
signal skill_cooldown_complete_riyan
@warning_ignore("unused_signal")
signal skill_cooldown_complete_ringFire
@warning_ignore("unused_signal")
signal skill_cooldown_complete_thunder
@warning_ignore("unused_signal")
signal skill_cooldown_complete_bloodwave
@warning_ignore("unused_signal")
signal skill_cooldown_complete_bloodboardsword
@warning_ignore("unused_signal")
signal skill_cooldown_complete_ice
@warning_ignore("unused_signal")
signal skill_cooldown_complete_thunder_break
@warning_ignore("unused_signal")
signal skill_cooldown_complete_light_bullet
@warning_ignore("unused_signal")
signal skill_cooldown_complete_water
@warning_ignore("unused_signal")
signal skill_cooldown_complete_qiankun
@warning_ignore("unused_signal")
signal skill_cooldown_complete_xuanwu
@warning_ignore("unused_signal")
signal skill_cooldown_complete_xunfeng
@warning_ignore("unused_signal")
signal skill_cooldown_complete_genshan
@warning_ignore("unused_signal")
signal skill_cooldown_complete_duize
@warning_ignore("unused_signal")
signal skill_cooldown_complete_holylight(skill_id)
@warning_ignore("unused_signal")
signal skill_cooldown_complete_qigong(skill_id)
@warning_ignore("unused_signal")
signal skill_cooldown_complete_dragonwind(skill_id)
@warning_ignore("unused_signal")
signal riyan_damage_triggered
@warning_ignore("unused_signal")
signal ringFire_damage_triggered
@warning_ignore("unused_signal")
signal createSwordWave
@warning_ignore("unused_signal")
signal _fire_ring_bullets
@warning_ignore("unused_signal")
signal drop_out_item(item_id: String, quantity: int, position: Vector2)
@warning_ignore("unused_signal")
signal drop_exp_orb(exp_value: int, position: Vector2, is_elite: bool)
@warning_ignore("unused_signal")
signal press_f
@warning_ignore("unused_signal")
signal press_g
@warning_ignore("unused_signal")
signal press_h
@warning_ignore("unused_signal")
signal dps_updated(total_dps: float, weapon_dps: Dictionary)

# --------------------------
# --- DPS 计数逻辑 ---
var dps_damage_records = [] # [{"damage": float, "time": float, "weapon": String}]
@export var current_dps: float = 0.0
var weapon_dps: Dictionary = {}
var dps_timer: Timer

# 显示配置
@export var damage_show_type: int = 2
@export var damage_show_enabled: bool = true
@export var particle_enable: bool = true
@export var screen_shake_enabled: bool = true

const MAX_DAMAGE_LABELS: int = 500
var _active_damage_label_count: int = 0
var _damage_label_scene = preload("res://Scenes/global/damage.tscn")

# 对象池 —— 减少高频 instantiate/queue_free 的 GC 开销
var damage_label_pool: ObjectPool
var rain_bullet_pool: ObjectPool
var light_bullet_pool: ObjectPool
var ice_flower_pool: ObjectPool
var branch_pool: ObjectPool
var debuff_burn_pool: ObjectPool
var faze_thunder_pool: ObjectPool
var faze_destory_pool: ObjectPool

func _init_dps_counter() -> void:
	dps_timer = Timer.new()
	dps_timer.wait_time = 1.0
	dps_timer.timeout.connect(_calculate_dps)
	dps_timer.autostart = true
	add_child(dps_timer)

func record_damage_for_dps(damage: float, weapon_name: String = "Unknown") -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	dps_damage_records.append({"damage": damage, "time": current_time, "weapon": weapon_name})

func _calculate_dps() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var total_damage = 0.0
	var weapon_totals = {}
	for i in range(dps_damage_records.size() - 1, -1, -1):
		var record = dps_damage_records[i]
		if current_time - record["time"] > 30.0:
			dps_damage_records.remove_at(i)
		else:
			total_damage += record["damage"]
			var w_name = record["weapon"]
			weapon_totals[w_name] = weapon_totals.get(w_name, 0.0) + record["damage"]
	current_dps = total_damage / 30.0
	weapon_dps.clear()
	for w_name in weapon_totals:
		weapon_dps[w_name] = weapon_totals[w_name] / 30.0
	emit_signal("dps_updated", current_dps, weapon_dps)

# ---------------------------------

func _ready():
	set_process_input(true)
	monster_damage.connect(_on_monster_damage)
	player_heal.connect(_on_player_heal)
	player_hit.connect(_on_player_hit)
	player_hit_ignore_invincible.connect(_on_player_hit_ignore_invincible)
	add_child(setting_emblem)
	add_child(audio_manager)
	add_child(soft_glow_manager)
	add_child(settings_manager)
	add_child(equipment_manager)
	add_child(active_skill_manager)
	add_child(exp_orb_system)
	load_game()
	_init_dps_counter()
	if dps_timer:
		dps_timer.start()
	MouseAnimation.start_mouse_animation()
	_init_object_pools()

func _init_object_pools() -> void:
	damage_label_pool = ObjectPool.new(_damage_label_scene, 30)
	add_child(damage_label_pool)
	rain_bullet_pool = ObjectPool.new(preload("res://Scenes/player/faze_rain_bullet.tscn"), 50)
	add_child(rain_bullet_pool)
	light_bullet_pool = ObjectPool.new(preload("res://Scenes/player/light_bullet.tscn"), 20)
	add_child(light_bullet_pool)
	ice_flower_pool = ObjectPool.new(preload("res://Scenes/player/ice_flower.tscn"), 20)
	add_child(ice_flower_pool)
	branch_pool = ObjectPool.new(preload("res://Scenes/branch.tscn"), 20)
	add_child(branch_pool)
	debuff_burn_pool = ObjectPool.new(preload("res://Scenes/player/debuff_burn.tscn"), 10)
	add_child(debuff_burn_pool)
	faze_thunder_pool = ObjectPool.new(preload("res://Scenes/player/faze_thunder.tscn"), 5)
	add_child(faze_thunder_pool)
	faze_destory_pool = ObjectPool.new(preload("res://Scenes/player/faze_destory.tscn"), 5)
	add_child(faze_destory_pool)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_debug_function_key(event.keycode)

func _handle_debug_function_key(keycode: Key) -> void:
	match keycode:
		KEY_F1:
			_debug_command_f1()
		KEY_F2:
			_debug_command_f2()
		KEY_F3:
			_debug_command_f3()
		KEY_F4:
			_debug_command_f4()
		KEY_F5:
			_debug_command_f5()
		KEY_F6:
			_debug_command_f6()
		KEY_F7:
			_debug_command_f7()
		KEY_F8:
			_debug_command_f8()
		KEY_F9:
			_debug_command_f9()
		KEY_F10:
			_debug_command_f10()
		KEY_F11:
			_debug_command_f11()
		KEY_F12:
			_debug_command_f12()

func _debug_command_f1() -> void:
	total_points += DEBUG_F1_ZHENQI_AMOUNT
	save_game()
	_refresh_debug_resource_views()
	_show_debug_command_feedback("调试指令 F1：真气 +%d，当前 %d" % [DEBUG_F1_ZHENQI_AMOUNT, total_points])

func _debug_command_f2() -> void:
	PC.pc_atk += 100
	_show_debug_command_feedback("调试指令 F2：攻击力 +100，当前 %d" % PC.pc_atk)

func _debug_command_f3() -> void:
	PC.pc_atk -= 100
	_show_debug_command_feedback("调试指令 F3：攻击力 -100，当前 %d" % PC.pc_atk)

func _debug_command_f4() -> void:
	PC.pc_max_hp += 1000
	PC.pc_hp = mini(PC.pc_hp + 1000, PC.pc_max_hp)
	_show_debug_command_feedback("调试指令 F4：体力上限 +1000，当前 %d" % PC.pc_max_hp)

func _debug_command_f5() -> void:
	PC.pc_max_hp -= 1000
	PC.pc_hp = mini(PC.pc_hp, PC.pc_max_hp)
	_show_debug_command_feedback("调试指令 F5：体力上限 -1000，当前 %d" % PC.pc_max_hp)

func _debug_command_f6() -> void:
	pass

func _debug_command_f7() -> void:
	pass

func _debug_command_f8() -> void:
	pass

func _debug_command_f9() -> void:
	pass

func _debug_command_f10() -> void:
	pass

func _debug_command_f11() -> void:
	pass

var _debug_console: CanvasLayer = null

func _debug_command_f12() -> void:
	if _debug_console == null:
		_debug_console = preload("res://Script/system/debug_console.gd").new()
		add_child(_debug_console)
	_debug_console.toggle()

func _refresh_debug_resource_views() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if current_scene.has_method("refresh_point"):
		current_scene.refresh_point()
	var battle_layer := current_scene.get_node_or_null("CanvasLayer")
	if battle_layer != null and battle_layer.has_method("update_score_display"):
		battle_layer.update_score_display(total_points)

func _show_debug_command_feedback(message: String) -> void:
	print("[DebugHotkey] %s" % message)
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if "tip" in current_scene and current_scene.tip != null and current_scene.tip.has_method("start_animation"):
		current_scene.tip.start_animation(message, 0.6)
		return
	var fallback_tip := current_scene.get_node_or_null("TipsLayer/Tip")
	if fallback_tip != null and fallback_tip.has_method("start_animation"):
		fallback_tip.start_animation(message, 0.6)

func get_item_count(item_id: String) -> int:
	if item_id == LINGSHI_ITEM_ID:
		return lingshi
	return player_inventory.get(item_id, 0)

func add_item_count(item_id: String, count: int) -> void:
	if count == 0:
		return
	if item_id == LINGSHI_ITEM_ID:
		lingshi = max(lingshi + count, 0)
		return
	player_inventory[item_id] = player_inventory.get(item_id, 0) + count
	if player_inventory[item_id] <= 0:
		player_inventory.erase(item_id)

func consume_item_count(item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if get_item_count(item_id) < count:
		return false
	add_item_count(item_id, -count)
	return true

func add_shop_battle_refresh(count: int = 1) -> void:
	shop_battle_refresh_count = clampi(shop_battle_refresh_count + count, 0, refresh_max_num)

func consume_shop_battle_refresh(count: int = 1) -> bool:
	if shop_battle_refresh_count < count:
		return false
	shop_battle_refresh_count -= count
	return true

# 把外部传进来的难度ID校正成可识别的值。
# 这样就算按钮配置错了，或者旧数据里写了别的字符串，
# 也会自动回退到“浅层”，不至于把逻辑跑崩。
func validate_stage_difficulty_id(difficulty_id: String) -> String:
	match difficulty_id:
		STAGE_DIFFICULTY_SHALLOW, STAGE_DIFFICULTY_DEEP, STAGE_DIFFICULTY_CORE, STAGE_DIFFICULTY_POETRY:
			return difficulty_id
		_:
			return STAGE_DIFFICULTY_SHALLOW

func get_stage_difficulty_display_name(difficulty_id: String) -> String:
	match validate_stage_difficulty_id(difficulty_id):
		STAGE_DIFFICULTY_SHALLOW:
			return "浅层"
		STAGE_DIFFICULTY_DEEP:
			return "深层"
		STAGE_DIFFICULTY_CORE:
			return "核心"
		STAGE_DIFFICULTY_POETRY:
			return "诗想"
		_:
			return "浅层"

# 返回进入某一层之前，必须先通关的前置层。
# 比如：想进“深层”，就必须先通关“浅层”。
func get_required_stage_clear_difficulty(difficulty_id: String) -> String:
	match validate_stage_difficulty_id(difficulty_id):
		STAGE_DIFFICULTY_DEEP:
			return STAGE_DIFFICULTY_SHALLOW
		STAGE_DIFFICULTY_CORE:
			return STAGE_DIFFICULTY_DEEP
		STAGE_DIFFICULTY_POETRY:
			return STAGE_DIFFICULTY_CORE
		_:
			return ""

# 旧存档里可能没有新字段，这里统一补齐。
func _normalize_stage_difficulty_clear_progress() -> void:
	if typeof(stage_difficulty_clear_progress) != TYPE_DICTIONARY:
		stage_difficulty_clear_progress = {}
	for stage_id in STAGE_ID_LIST:
		if typeof(stage_difficulty_clear_progress.get(stage_id, {})) != TYPE_DICTIONARY:
			stage_difficulty_clear_progress[stage_id] = {}
		var stage_progress: Dictionary = stage_difficulty_clear_progress[stage_id]
		for difficulty_id in [STAGE_DIFFICULTY_SHALLOW, STAGE_DIFFICULTY_DEEP, STAGE_DIFFICULTY_CORE, STAGE_DIFFICULTY_POETRY]:
			stage_progress[difficulty_id] = bool(stage_progress.get(difficulty_id, false))
		stage_difficulty_clear_progress[stage_id] = stage_progress

func set_selected_stage_difficulty(difficulty_id: String) -> void:
	selected_stage_difficulty = validate_stage_difficulty_id(difficulty_id)

func is_stage_difficulty_cleared(stage_id: String, difficulty_id: String) -> bool:
	_normalize_stage_difficulty_clear_progress()
	if not stage_difficulty_clear_progress.has(stage_id):
		return false
	var stage_progress = stage_difficulty_clear_progress.get(stage_id, {})
	if typeof(stage_progress) != TYPE_DICTIONARY:
		return false
	return bool(stage_progress.get(validate_stage_difficulty_id(difficulty_id), false))

func is_stage_cleared(stage_id: String) -> bool:
	for difficulty_id in [STAGE_DIFFICULTY_SHALLOW, STAGE_DIFFICULTY_DEEP, STAGE_DIFFICULTY_CORE, STAGE_DIFFICULTY_POETRY]:
		if is_stage_difficulty_cleared(stage_id, difficulty_id):
			return true
	return false

func get_previous_stage_id(stage_id: String) -> String:
	var stage_index := STAGE_ID_LIST.find(stage_id)
	if stage_index <= 0:
		return ""
	return str(STAGE_ID_LIST[stage_index - 1])

func is_stage_unlocked(stage_id: String) -> bool:
	return can_enter_stage_difficulty(stage_id, STAGE_DIFFICULTY_SHALLOW)

func has_any_stage_difficulty_cleared(difficulty_id: String) -> bool:
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	for stage_id in STAGE_ID_LIST:
		if is_stage_difficulty_cleared(stage_id, valid_difficulty):
			return true
	return false

func is_stage_difficulty_unlocked(difficulty_id: String) -> bool:
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	for stage_id in STAGE_ID_LIST:
		if can_enter_stage_difficulty(stage_id, valid_difficulty):
			return true
	return false

# 判断某个“关卡 + 难度”组合是否已经解锁。
# 规则：
# 1) 壹·浅层 初始解锁；
# 2) 浅层只会按关卡顺序横向解锁下一关；
# 3) 深层 / 核心 / 诗想 只会在同一关内纵向解锁下一难度；
# 4) 通关本格后保持已解锁。
func can_enter_stage_difficulty(stage_id: String, difficulty_id: String) -> bool:
	_normalize_stage_difficulty_clear_progress()
	var resolved_stage_id := str(stage_id)
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	var stage_index := STAGE_ID_LIST.find(resolved_stage_id)
	if stage_index == -1:
		return false
	if is_stage_difficulty_cleared(resolved_stage_id, valid_difficulty):
		return true
	var difficulty_index := STAGE_DIFFICULTY_LIST.find(valid_difficulty)
	if difficulty_index == -1:
		return false
	if difficulty_index == 0:
		if stage_index == 0:
			return true
		var previous_stage_id := str(STAGE_ID_LIST[stage_index - 1])
		return is_stage_difficulty_cleared(previous_stage_id, valid_difficulty)
	var previous_difficulty_id := str(STAGE_DIFFICULTY_LIST[difficulty_index - 1])
	return is_stage_difficulty_cleared(resolved_stage_id, previous_difficulty_id)

# 战斗胜利时调用，用来解锁下一层难度。
func mark_stage_difficulty_cleared(stage_id: String, difficulty_id: String) -> void:
	_normalize_stage_difficulty_clear_progress()
	if not stage_difficulty_clear_progress.has(stage_id):
		return
	var stage_progress = stage_difficulty_clear_progress.get(stage_id, {})
	if typeof(stage_progress) != TYPE_DICTIONARY:
		stage_progress = {}
	stage_progress[validate_stage_difficulty_id(difficulty_id)] = true
	stage_difficulty_clear_progress[stage_id] = stage_progress

# 取得某个关卡在某个难度下的倍率。
# 如果不传参数，就默认读取“当前已进入关卡”的上下文。
func get_stage_difficulty_stat_multiplier(stage_id: String = "", difficulty_id: String = "") -> float:
	var resolved_stage_id := stage_id
	if resolved_stage_id.is_empty():
		resolved_stage_id = current_stage_id
	var resolved_difficulty_id := difficulty_id
	if resolved_difficulty_id.is_empty():
		resolved_difficulty_id = current_stage_difficulty
	resolved_difficulty_id = validate_stage_difficulty_id(resolved_difficulty_id)
	if not STAGE_DIFFICULTY_MULTIPLIERS.has(resolved_stage_id):
		return 1.0
	var stage_multiplier_data = STAGE_DIFFICULTY_MULTIPLIERS.get(resolved_stage_id, {})
	if typeof(stage_multiplier_data) != TYPE_DICTIONARY:
		return 1.0
	return float(stage_multiplier_data.get(resolved_difficulty_id, 1.0))

func get_current_stage_stat_multiplier() -> float:
	return get_stage_difficulty_stat_multiplier(current_stage_id, current_stage_difficulty)

# 推荐修为固定值配置（关卡 × 难度 → 修为值）
const STAGE_RECOMMENDED_POWER := {
	"peach_grove": {
		"shallow": 1200,
		"deep": 4500,
		"core": 7000,
		"poetry": 7000
	},
	"ruin": {
		"shallow": 3200,
		"deep": 8000,
		"core": 12000,
		"poetry": 12000
	},
	"cave": {
		"shallow": 9000,
		"deep": 14000,
		"core": 19000,
		"poetry": 19000
	},
	"forest": {
		"shallow": 16000,
		"deep": 22000,
		"core": 26000,
		"poetry": 26000
	}
}

# 返回指定关卡和难度的推荐修为（固定值）
func get_stage_recommended_power(stage_id: String, difficulty_id: String) -> int:
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	if not STAGE_RECOMMENDED_POWER.has(stage_id):
		return 0
	var stage_data = STAGE_RECOMMENDED_POWER.get(stage_id, {})
	if typeof(stage_data) != TYPE_DICTIONARY:
		return 0
	return int(stage_data.get(valid_difficulty, 0))

func _get_effective_normal_monster_bonus() -> float:
	if typeof(PC) != TYPE_NIL:
		return PC.normal_monster_multi
	return normal_monster_multi

func _get_effective_boss_bonus() -> float:
	if typeof(PC) != TYPE_NIL:
		return PC.boss_multi
	return boss_multi

func get_effective_exp_multiplier() -> float:
	var effective_exp_bonus = exp_multi
	if typeof(PC) != TYPE_NIL:
		effective_exp_bonus = PC.exp_multi
	return max(0.0, 1.0 + effective_exp_bonus)

func get_effective_drop_multiplier() -> float:
	var effective_drop_bonus = drop_multi
	if typeof(PC) != TYPE_NIL:
		effective_drop_bonus = PC.drop_multi
	return max(0.0, 1.0 + effective_drop_bonus)

func get_attack_range_multiplier() -> float:
	var effective_attack_range = attack_range
	if typeof(PC) != TYPE_NIL and PC != null:
		effective_attack_range = float(PC.attack_range)
	return max(0.01, effective_attack_range)

func get_emblem_effect_multiplier() -> float:
	return max(0.0, 1.0 + emblem_effect_rate)

func get_scaled_emblem_value(base_value: float) -> float:
	return base_value * get_emblem_effect_multiplier()

func get_total_skill_cooldown_reduction() -> float:
	var effective_cooldown := cooldown
	if typeof(PC) != TYPE_NIL and PC != null:
		effective_cooldown = PC.cooldown
	return clampf(effective_cooldown, 0.0, 0.5)

func get_cultivation_final_damage_bonus() -> float:
	return max(0.0, cultivation_tongxiao_level * 0.01)

func get_special_pill_max_uses(tier: String) -> int:
	match tier:
		"lower":
			return special_pill_lower_max_uses
		"middle":
			return special_pill_middle_max_uses
		"upper":
			return special_pill_upper_max_uses
		_:
			return 0

func is_elite_or_boss_target(target: Node) -> bool:
	if target == null or !is_instance_valid(target):
		return false
	return target.is_in_group("elite") or target.is_in_group("boss")

func get_enemy_damage_bonus_multiplier(target: Node) -> float:
	var bonus = _get_effective_normal_monster_bonus()
	if is_elite_or_boss_target(target):
		bonus = _get_effective_boss_bonus()
	return max(0.0, 1.0 + bonus)

func apply_enemy_damage_bonus(damage: float, target: Node) -> float:
	if damage <= 0.0:
		return damage
	return damage * get_enemy_damage_bonus_multiplier(target)

## 显示保存指示器动画（右下角，渐进渐出，持续2秒）
func _show_save_indicator() -> void:
	# 如果已有动画在播放，先清理
	if _save_indicator_tween and _save_indicator_tween.is_running():
		_save_indicator_tween.kill()
	if _save_indicator_layer and is_instance_valid(_save_indicator_layer):
		_save_indicator_layer.queue_free()
	
	# 创建CanvasLayer确保显示在最上层
	_save_indicator_layer = CanvasLayer.new()
	_save_indicator_layer.layer = 100
	add_child(_save_indicator_layer)
	
	# 实例化loading动画场景
	var indicator = SAVE_INDICATOR_SCENE.instantiate()
	# 将动画精灵位置设置为容器中心
	var animated_sprite = indicator.get_child(0) if indicator.get_child_count() > 0 else null
	if animated_sprite:
		animated_sprite.position = Vector2(30, 30)
	
	# 用Control包裹，通过锚点定位到屏幕右下角
	var container = Control.new()
	container.name = "SaveIndicatorContainer"
	# 锚点到右下角
	container.anchor_left = 1.0
	container.anchor_top = 1.0
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = -70
	container.offset_top = -70
	container.offset_right = -10
	container.offset_bottom = -10
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.modulate.a = 0.0
	container.add_child(indicator)
	_save_indicator_layer.add_child(container)
	
	# 创建渐进渐出动画：0.3秒淡入 + 1.4秒保持 + 0.3秒淡出 = 2秒
	_save_indicator_tween = create_tween()
	_save_indicator_tween.tween_property(container, "modulate:a", 1.0, 0.3)
	_save_indicator_tween.tween_interval(1.4)
	_save_indicator_tween.tween_property(container, "modulate:a", 0.0, 0.3)
	_save_indicator_tween.tween_callback(func():
		if is_instance_valid(_save_indicator_layer):
			_save_indicator_layer.queue_free()
	)

func save_game():
	# 显示保存指示器动画
	_show_save_indicator()

	var config = ConfigFile.new()
	var data = {
		"total_points": total_points,
		"player_name": PC.player_name,
		"world_level": world_level,
		"world_level_multiple": world_level_multiple,
		"world_level_reward_multiple": world_level_reward_multiple,
		"lunky_level": lunky_level,
		"red_p": red_p,
		"gold_p": gold_p,
		"darkorchid_p": darkorchid_p,
		"blue_p": blue_p,
		"exp_multi": exp_multi,
		"drop_multi": drop_multi,
		"body_size": body_size,
		"attack_range": attack_range,
		"heal_multi": heal_multi,
		"sheild_multi": sheild_multi,
		"normal_monster_multi": normal_monster_multi,
		"boss_multi": boss_multi,
		"cooldown": cooldown,
		"active_skill_multi": active_skill_multi,
		"fruit_heal_multi": fruit_heal_multi,
		"fruit_heal_multi_used_count": fruit_heal_multi_used_count,
		"pill_used_counts": pill_used_counts,
		"player_inventory": player_inventory,
		"lingshi": lingshi,
		"shop_level": shop_level,
		"shop_battle_refresh_count": shop_battle_refresh_count,
		"shop_lingshi_unit_price": shop_lingshi_unit_price,
		"shop_first_entered": shop_first_entered,
		"shop_saved_items": shop_saved_items,
		"has_visited_town": has_visited_town,
		"is_first_game": is_first_game,
		"stage_difficulty_clear_progress": stage_difficulty_clear_progress,
		"recipe_unlock_progress": recipe_unlock_progress,


		"unlock_moning": unlock_moning,
		"unlock_yiqiu": unlock_yiqiu,
		"unlock_noam": unlock_noam,
		"unlock_kansel": unlock_kansel,
		"refresh_max_num": refresh_max_num,
		"cultivation_unlock_progress": cultivation_unlock_progress,
		"cultivation_poxu_level": cultivation_poxu_level,
		"cultivation_xuanyuan_level": cultivation_xuanyuan_level,
		"cultivation_liuguang_level": cultivation_liuguang_level,
		"cultivation_hualing_level": cultivation_hualing_level,
		"cultivation_fengrui_level": cultivation_fengrui_level,
		"cultivation_huti_level": cultivation_huti_level,
		"cultivation_zhuifeng_level": cultivation_zhuifeng_level,
		"cultivation_liejin_level": cultivation_liejin_level,
		"cultivation_heyi_level": cultivation_heyi_level,
		"cultivation_tongxiao_level": cultivation_tongxiao_level,
		"cultivation_poxu_level_max": cultivation_poxu_level_max,
		"cultivation_xuanyuan_level_max": cultivation_xuanyuan_level_max,
		"cultivation_liuguang_level_max": cultivation_liuguang_level_max,
		"cultivation_hualing_level_max": cultivation_hualing_level_max,
		"cultivation_fengrui_level_max": cultivation_fengrui_level_max,
		"cultivation_huti_level_max": cultivation_huti_level_max,
		"cultivation_zhuifeng_level_max": cultivation_zhuifeng_level_max,
		"cultivation_liejin_level_max": cultivation_liejin_level_max,
		"player_study_data": player_study_data,
		"player_study_tree": player_study_tree,
		"player_active_skill_data": player_active_skill_data,
		"player_now_active_skill": player_now_active_skill,
		"max_main_skill_num": max_main_skill_num,
		"max_weapon_num": max_weapon_num,
		"emblem_slots_max": emblem_slots_max,
		"emblem_effect_rate": emblem_effect_rate,
		"max_carry_equipment_slots": max_carry_equipment_slots,
		"equipment_data": equipment_manager.save_equipment_data(),
		"master_volume": audio_manager.get_master_volume(),
		"bgm_volume": audio_manager.get_bgm_volume(),
		"sfx_volume": audio_manager.get_sfx_volume(),
		"bg_volume": audio_manager.get_bg_volume(),
		"damage_show_enabled": damage_show_enabled,
		"damage_show_type": damage_show_type,
		"particle_enable": particle_enable,
		"screen_shake_enabled": screen_shake_enabled,
		"time_slow_enabled": time_slow_enabled,
		"is_test": is_test,
		"resolution_index": settings_manager.get_current_resolution_index() if settings_manager else 6,
		"is_fullscreen": settings_manager.is_fullscreen_enabled() if settings_manager else true,
		"noborder_enabled": settings_manager.is_noborder_enabled() if settings_manager else true,
		"vignetting_enabled": settings_manager.is_vignetting_enabled() if settings_manager else true,
	}

	for key in data:
		config.set_value("save", key, data[key])
	
	var err = config.save(CONFIG_PATH)
	if err == OK:
		print("save success")
	else:
		push_error("save error")
	
	audio_manager.save_audio_settings()

func load_game():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK: return
	
	total_points = config.get_value("save", "total_points", total_points)
	PC.player_name = config.get_value("save", "player_name", PC.player_name)
	world_level = config.get_value("save", "world_level", world_level)
	world_level_multiple = config.get_value("save", "world_level_multiple", world_level_multiple)
	world_level_reward_multiple = config.get_value("save", "world_level_reward_multiple", world_level_reward_multiple)
	lunky_level = config.get_value("save", "lunky_level", lunky_level)
	red_p = config.get_value("save", "red_p", red_p)
	gold_p = config.get_value("save", "gold_p", gold_p)
	darkorchid_p = config.get_value("save", "darkorchid_p", darkorchid_p)
	blue_p = config.get_value("save", "blue_p", blue_p)
	exp_multi = config.get_value("save", "exp_multi", exp_multi)
	drop_multi = config.get_value("save", "drop_multi", drop_multi)
	body_size = config.get_value("save", "body_size", body_size)
	heal_multi = config.get_value("save", "heal_multi", heal_multi)
	sheild_multi = config.get_value("save", "sheild_multi", sheild_multi)
	attack_range = config.get_value("save", "attack_range", attack_range)
	normal_monster_multi = config.get_value("save", "normal_monster_multi", normal_monster_multi)
	boss_multi = config.get_value("save", "boss_multi", boss_multi)
	cooldown = config.get_value("save", "cooldown", cooldown)
	active_skill_multi = config.get_value("save", "active_skill_multi", active_skill_multi)
	fruit_heal_multi = config.get_value("save", "fruit_heal_multi", fruit_heal_multi)
	fruit_heal_multi_used_count = config.get_value("save", "fruit_heal_multi_used_count", fruit_heal_multi_used_count)
	pill_used_counts = config.get_value("save", "pill_used_counts", {})
	player_inventory = config.get_value("save", "player_inventory", {})
	lingshi = config.get_value("save", "lingshi", lingshi)
	refresh_max_num = int(config.get_value("save", "refresh_max_num", refresh_max_num))
	shop_level = clampi(int(config.get_value("save", "shop_level", shop_level)), 1, 8)
	shop_battle_refresh_count = clampi(int(config.get_value("save", "shop_battle_refresh_count", shop_battle_refresh_count)), 0, refresh_max_num)
	shop_lingshi_unit_price = max(int(config.get_value("save", "shop_lingshi_unit_price", shop_lingshi_unit_price)), 50)
	shop_first_entered = bool(config.get_value("save", "shop_first_entered", shop_first_entered))
	has_visited_town = bool(config.get_value("save", "has_visited_town", false))
	is_first_game = bool(config.get_value("save", "is_first_game", true))
	var loaded_shop_items = config.get_value("save", "shop_saved_items", [])
	if typeof(loaded_shop_items) == TYPE_ARRAY:
		shop_saved_items = (loaded_shop_items as Array).duplicate(true)
	else:
		shop_saved_items = []
	var loaded_stage_clear_progress = config.get_value("save", "stage_difficulty_clear_progress", stage_difficulty_clear_progress)
	if typeof(loaded_stage_clear_progress) == TYPE_DICTIONARY:
		stage_difficulty_clear_progress = (loaded_stage_clear_progress as Dictionary).duplicate(true)
	else:
		stage_difficulty_clear_progress = stage_difficulty_clear_progress.duplicate(true)
	_normalize_stage_difficulty_clear_progress()
	if player_inventory.has(LINGSHI_ITEM_ID):
		lingshi += int(player_inventory[LINGSHI_ITEM_ID])
		player_inventory.erase(LINGSHI_ITEM_ID)
	recipe_unlock_progress = config.get_value("save", "recipe_unlock_progress", recipe_unlock_progress)
	# 补齐旧存档缺失的配方解锁项
	if not recipe_unlock_progress.has("recipe_028"):
		recipe_unlock_progress["recipe_028"] = true


	unlock_moning = config.get_value("save", "unlock_moning", true)
	unlock_yiqiu = config.get_value("save", "unlock_yiqiu", true)
	unlock_noam = config.get_value("save", "unlock_noam", true)
	unlock_kansel = config.get_value("save", "unlock_kansel", true)
	refresh_max_num = config.get_value("save", "refresh_max_num", 3)
	cultivation_unlock_progress = config.get_value("save", "cultivation_unlock_progress", 0)
	cultivation_poxu_level = config.get_value("save", "cultivation_poxu_level", 0)
	cultivation_xuanyuan_level = config.get_value("save", "cultivation_xuanyuan_level", 0)
	cultivation_liuguang_level = config.get_value("save", "cultivation_liuguang_level", 0)
	cultivation_hualing_level = config.get_value("save", "cultivation_hualing_level", 0)
	cultivation_fengrui_level = config.get_value("save", "cultivation_fengrui_level", 0)
	cultivation_huti_level = config.get_value("save", "cultivation_huti_level", 0)
	cultivation_zhuifeng_level = config.get_value("save", "cultivation_zhuifeng_level", 0)
	cultivation_liejin_level = config.get_value("save", "cultivation_liejin_level", 0)
	cultivation_poxu_level_max = config.get_value("save", "cultivation_poxu_level_max", 50)
	cultivation_xuanyuan_level_max = config.get_value("save", "cultivation_xuanyuan_level_max", 50)
	cultivation_liuguang_level_max = config.get_value("save", "cultivation_liuguang_level_max", 25)
	cultivation_hualing_level_max = config.get_value("save", "cultivation_hualing_level_max", 50)
	cultivation_fengrui_level_max = config.get_value("save", "cultivation_fengrui_level_max", 25)
	cultivation_huti_level_max = config.get_value("save", "cultivation_huti_level_max", 25)
	cultivation_zhuifeng_level_max = config.get_value("save", "cultivation_zhuifeng_level_max", 25)
	cultivation_liejin_level_max = config.get_value("save", "cultivation_liejin_level_max", 50)
	var loaded_study_data = config.get_value("save", "player_study_data", player_study_data)
	for p_name in loaded_study_data.keys():
		if not loaded_study_data[p_name].has("zhenqi_points"): loaded_study_data[p_name]["zhenqi_points"] = 100
	player_study_data = loaded_study_data
	player_study_tree = config.get_value("save", "player_study_tree", player_study_tree)
	player_active_skill_data = config.get_value("save", "player_active_skill_data", player_active_skill_data)
	# 强制修正技能图标路径，防止存档里的旧路径覆盖代码中更新的图标
	var _skill_icon_table: Dictionary = {
		"dodge": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shanbi.png",
		"mizongbu": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mizongbu.png",
		"huanling": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mingxiang.png",
		"random_strike": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/luanji.png",
		"beastify": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shouhua.png",
		"heal_hot": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yuliao.png",
		"water_sheild": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shuiliumu.png",
		"holy_fire": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png",
	}
	for _sid in _skill_icon_table:
		if player_active_skill_data.has(_sid):
			player_active_skill_data[_sid]["icon"] = _skill_icon_table[_sid]
	player_now_active_skill = config.get_value("save", "player_now_active_skill", player_now_active_skill)
	max_main_skill_num = config.get_value("save", "max_main_skill_num", 3)
	max_weapon_num = config.get_value("save", "max_weapon_num", 5)
	
	emblem_slots_max = config.get_value("save", "emblem_slots_max", 4)
	emblem_effect_rate = config.get_value("save", "emblem_effect_rate", emblem_effect_rate)
	max_carry_equipment_slots = config.get_value("save", "max_carry_equipment_slots", 2)
	equipment_manager.load_equipment_data(config.get_value("save", "equipment_data", {}))
	audio_manager.set_master_volume(config.get_value("save", "master_volume", 1.0))
	audio_manager.set_bgm_volume(config.get_value("save", "bgm_volume", 1.0))
	audio_manager.set_sfx_volume(config.get_value("save", "sfx_volume", 1.0))
	audio_manager.set_bg_volume(config.get_value("save", "bg_volume", 1.0))
	damage_show_enabled = config.get_value("save", "damage_show_enabled", true)
	damage_show_type = config.get_value("save", "damage_show_type", 2)
	particle_enable = config.get_value("save", "particle_enable", true)
	screen_shake_enabled = config.get_value("save", "screen_shake_enabled", true)
	time_slow_enabled = config.get_value("save", "time_slow_enabled", false)
	is_test = config.get_value("save", "is_test", is_test)
	if settings_manager:
		settings_manager.particle_enabled = particle_enable
		settings_manager.damage_show_enabled = damage_show_enabled
		# 从存档加载分辨率、全屏、暗角设置
		var _res_idx = config.get_value("save", "resolution_index", 6)
		var _fullscreen = config.get_value("save", "is_fullscreen", true)
		var _noborder = config.get_value("save", "noborder_enabled", true)
		var _vignetting = config.get_value("save", "vignetting_enabled", true)
		settings_manager.current_resolution_index = _res_idx
		settings_manager.is_fullscreen = _fullscreen
		settings_manager.noborder_enabled = _noborder
		settings_manager.vignetting_enabled = _vignetting
		# 应用设置
		settings_manager.apply_all_settings()

func reset_battle_modifiers():
	# 这些字段现在承载局外长期加成（如秘丹效果），进入战斗时不再在这里清空。
	pass

var hit_scene = null
signal player_healed(amount: float)
signal player_shield_damaged(amount: float)

func play_hit_anime(position: Vector2, is_crit: bool = false, anime: int = 1):
	if anime == 0: return
	if hit_scene == null: hit_scene = ResourceLoader.load("res://Scenes/global/hit.tscn")
	var hit = hit_scene.instantiate()
	hit.position = position + Vector2(-1, 5)
	get_tree().current_scene.add_child(hit)
	if hit.get_node_or_null("GunHitSound"): hit.get_node("GunHitSound").bus = "SFX"
	if hit.get_node_or_null("GunHitCriSound"): hit.get_node("GunHitCriSound").bus = "SFX"
	if is_crit:
		hit.get_node("GunHitCri").play("hit"); hit.get_node("GunHitCriSound").play(0.0); hit.emit_signal("critical_hit_played")
	else:
		hit.get_node("GunHit").play("hit"); hit.get_node("GunHitSound").play(0.0)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(hit): hit.queue_free()

func _on_monster_damage(damage_type_int: int, damage_value: float, world_position: Vector2, weapon_name: String = "Unknown"):
	if damage_show_enabled:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(damage_type_int, damage_value, world_position)
	record_damage_for_dps(damage_value, weapon_name)

func _on_player_heal(heal_value: float, world_position: Vector2):
	emit_signal("player_healed", heal_value)
	if damage_show_enabled:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(9, heal_value, world_position)

func _on_player_hit(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String = "受击"):
	if not damage_show_enabled: return
	if shield_val > 0:
		emit_signal("player_shield_damaged", shield_val)
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(10, shield_val, world_position, source_name)
	if damage_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(11, damage_val, world_position, source_name)

func _on_player_hit_ignore_invincible(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String = "受击"):
	# 无视无敌伤害的弹幕显示（同player_hit，但不发射player_shield_damaged信号）
	if not damage_show_enabled: return
	if shield_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(10, shield_val, world_position, source_name)
	if damage_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(11, damage_val, world_position, source_name)

func _create_damage_label() -> Node2D:
	if _active_damage_label_count >= MAX_DAMAGE_LABELS: return null
	var instance = damage_label_pool.acquire(self )
	instance.z_index = 100
	_active_damage_label_count += 1
	# 回收时递减计数（兼容池化和非池化）
	if not instance.has_meta("_dmg_label_counted"):
		instance.set_meta("_dmg_label_counted", true)
		instance.tree_exiting.connect(func(): _active_damage_label_count = max(_active_damage_label_count - 1, 0))
	else:
		# 池化复用的实例，手动递减将在回收时处理
		pass
	return instance

func get_current_dps() -> float: return current_dps
func get_weapon_dps() -> Dictionary: return weapon_dps

# 兼容旧逻辑函数
func reset_dps_counter() -> void:
	dps_damage_records.clear(); current_dps = 0.0; weapon_dps.clear()
	if dps_timer: dps_timer.start()
func stop_dps_counter() -> void:
	if dps_timer: dps_timer.stop()
