@warning_ignore("unused_signal")
extends Node

const CONFIG_PATH = "user://game_config.cfg"
const LINGSHI_ITEM_ID := "item_084"

# 合成界面状态 - 用于禁用缩放等操作
var in_synthesis: bool = false


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

# 果实回复效果
@export var fruit_heal_multi: float = 1
@export var fruit_heal_multi_used_count: int = 0 # 回春露已使用次数（最多10次）

# 特殊秘丹使用上限
@export var special_pill_lower_max_uses: int = 50
@export var special_pill_middle_max_uses: int = 20
@export var special_pill_upper_max_uses: int = 10

# 丹药使用次数记录 {item_id: 已使用次数}
@export var pill_used_counts: Dictionary = {}

# 玩家背包与进度变量 (修复缺失声明)
var player_inventory: Dictionary = {}
@export var lingshi: int = 0
@export var shop_level: int = 1
@export var shop_battle_refresh_count: int = 0
@export var shop_lingshi_unit_price: int = 50
# 仅在当前存档第一次进入货摊时自动刷新一次；之后除非手动刷新，否则保持当前货物。
@export var shop_first_entered: bool = false
# 当前货摊商品列表会保存在存档里，保证再次进入时仍显示上次的货物状态。
var shop_saved_items: Array = []
@export var recipe_unlock_progress: Dictionary = {



	"recipe_001": true,
	"recipe_002": false,
	"recipe_003": false,
	"recipe_004": false,
	"recipe_noam": false
}

# lunky概率
@export var lunky_level: int = 1
@export var red_p: float = 3.5
@export var gold_p: float = 50
@export var darkorchid_p: float = 18
@export var blue_p: float = 25
@export var green_p: float = 30

# 刷新次数
@export var refresh_max_num: int = 3

# 修炼解锁进度Cultivation
@export var cultivation_unlock_progress: int = 0

# 装备系统相关
@export var max_carry_equipment_slots: int = 2 # 当前解锁的随身法宝槽位数量（初始2个，最大5个）

# 修炼等级变量
@export var cultivation_poxu_level: int = 0 # 破虚 - 提升攻击力
@export var cultivation_xuanyuan_level: int = 0 # 玄元 - 提升生命值
@export var cultivation_liuguang_level: int = 0 # 流光 - 提升攻速
@export var cultivation_hualing_level: int = 0 # 化灵 - 提升灵气获取
@export var cultivation_fengrui_level: int = 0 # 锋锐 - 提升暴击率
@export var cultivation_huti_level: int = 0 # 护体 - 提升减伤率
@export var cultivation_zhuifeng_level: int = 0 # 追风 - 提升移速
@export var cultivation_liejin_level: int = 0 # 烈劲 - 提升暴击伤害

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

@export var player_active_skill_data: Dictionary = {
	"dodge": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/dodge.png"
	},
	"mizongbu": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/dodge.png"
	},
	"huanling": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/random_strike.png"
	},
	"random_strike": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/random_strike.png"
	},
	"beastify": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png"
	},
	"heal_hot": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_heal.png"
	},
	"water_sheild": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_sheild.png"
	},
	"holy_fire": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_fire.png"
	}
}


@export var player_now_active_skill: Dictionary = {
	"space": { "name": "holy_fire" },
	"q": { "name": "water_sheild" },
	"e": { "name": "heal_hot" }
}

# 世界等级
@export var world_level_multiple: float = 1
@export var world_level_reward_multiple: float = 1
@export var world_level: int = 1

@export var in_menu: bool = true
@export var in_town: bool = false
@export var is_level_up: bool = false
@export var main_menu_instance: PackedScene = null

# 信号定义
@warning_ignore("unused_signal")
signal player_hit(attacker: Node2D)
@warning_ignore("unused_signal")
signal player_lv_up
@warning_ignore("unused_signal")
signal lucky_level_up
@warning_ignore("unused_signal")
signal setup_summons
@warning_ignore("unused_signal")
signal level_up_selection_complete
@warning_ignore("unused_signal")
signal monster_damage
@warning_ignore("unused_signal")
signal player_heal(heal_value, world_position)
@warning_ignore("unused_signal")
signal player_take_damage(damage_val, shield_val, world_position)
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
signal boss_bgm
@warning_ignore("unused_signal")
signal normal_bgm
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

const MAX_DAMAGE_LABELS: int = 500
var _active_damage_label_count: int = 0
var _damage_label_scene = preload("res://Scenes/global/damage.tscn")

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
	monster_damage.connect(_on_monster_damage)
	player_heal.connect(_on_player_heal)
	player_take_damage.connect(_on_player_take_damage)
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

func _get_effective_normal_monster_bonus() -> float:

	if typeof(PC) != TYPE_NIL:
		return PC.normal_monster_multi
	return normal_monster_multi

func _get_effective_boss_bonus() -> float:
	if typeof(PC) != TYPE_NIL:
		return PC.boss_multi
	return boss_multi

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

func save_game():


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
		"green_p": green_p,
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
		"cultivation_poxu_level_max": cultivation_poxu_level_max,
		"cultivation_xuanyuan_level_max": cultivation_xuanyuan_level_max,
		"cultivation_liuguang_level_max": cultivation_liuguang_level_max,
		"cultivation_hualing_level_max": cultivation_hualing_level_max,
		"cultivation_fengrui_level_max": cultivation_fengrui_level_max,
		"cultivation_huti_level_max": cultivation_huti_level_max,
		"cultivation_zhuifeng_level_max": cultivation_zhuifeng_level_max,
		"cultivation_liejin_level_max": cultivation_liejin_level_max,
		"player_study_data": player_study_data,
		"player_active_skill_data": player_active_skill_data,
		"player_now_active_skill": player_now_active_skill,
		"max_main_skill_num": max_main_skill_num,
		"max_weapon_num": max_weapon_num,
		"emblem_slots_max": emblem_slots_max,
		"max_carry_equipment_slots": max_carry_equipment_slots,
		"equipment_data": equipment_manager.save_equipment_data(),
		"master_volume": audio_manager.get_master_volume(),
		"bgm_volume": audio_manager.get_bgm_volume(),
		"sfx_volume": audio_manager.get_sfx_volume(),
		"bg_volume": audio_manager.get_bg_volume(),
		"damage_show_enabled": damage_show_enabled,
		"damage_show_type": damage_show_type,
		"particle_enable": particle_enable
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
	green_p = config.get_value("save", "green_p", green_p)
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
	var loaded_shop_items = config.get_value("save", "shop_saved_items", [])
	if typeof(loaded_shop_items) == TYPE_ARRAY:
		shop_saved_items = (loaded_shop_items as Array).duplicate(true)
	else:
		shop_saved_items = []
	if player_inventory.has(LINGSHI_ITEM_ID):
		lingshi += int(player_inventory[LINGSHI_ITEM_ID])
		player_inventory.erase(LINGSHI_ITEM_ID)
	recipe_unlock_progress = config.get_value("save", "recipe_unlock_progress", recipe_unlock_progress)



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
	player_active_skill_data = config.get_value("save", "player_active_skill_data", player_active_skill_data)
	player_now_active_skill = config.get_value("save", "player_now_active_skill", player_now_active_skill)
	max_main_skill_num = config.get_value("save", "max_main_skill_num", 3)
	max_weapon_num = config.get_value("save", "max_weapon_num", 5)
	
	emblem_slots_max = config.get_value("save", "emblem_slots_max", 4)
	max_carry_equipment_slots = config.get_value("save", "max_carry_equipment_slots", 2)
	equipment_manager.load_equipment_data(config.get_value("save", "equipment_data", {}))
	audio_manager.set_master_volume(config.get_value("save", "master_volume", 1.0))
	audio_manager.set_bgm_volume(config.get_value("save", "bgm_volume", 1.0))
	audio_manager.set_sfx_volume(config.get_value("save", "sfx_volume", 1.0))
	audio_manager.set_bg_volume(config.get_value("save", "bg_volume", 1.0))
	damage_show_enabled = config.get_value("save", "damage_show_enabled", true)
	damage_show_type = config.get_value("save", "damage_show_type", 2)
	particle_enable = config.get_value("save", "particle_enable", true)
	if settings_manager:
		settings_manager.particle_enabled = particle_enable
		settings_manager.damage_show_enabled = damage_show_enabled

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

func _on_player_take_damage(damage_val: float, shield_val: float, world_position: Vector2):
	if not damage_show_enabled: return
	if shield_val > 0:
		emit_signal("player_shield_damaged", shield_val)
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(10, shield_val, world_position)
	if damage_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(11, damage_val, world_position)

func _create_damage_label() -> Node2D:
	if _active_damage_label_count >= MAX_DAMAGE_LABELS: return null
	var instance = _damage_label_scene.instantiate()
	add_child(instance)
	instance.z_index = 100
	_active_damage_label_count += 1
	instance.tree_exiting.connect(func(): _active_damage_label_count -= 1)
	return instance

func get_current_dps() -> float: return current_dps
func get_weapon_dps() -> Dictionary: return weapon_dps

# 兼容旧逻辑函数
func reset_dps_counter() -> void:
	dps_damage_records.clear(); current_dps = 0.0; weapon_dps.clear()
	if dps_timer: dps_timer.start()
func stop_dps_counter() -> void:
	if dps_timer: dps_timer.stop()
