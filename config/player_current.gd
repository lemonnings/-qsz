extends Node

@export var player_instance: Node = null
@export var player_name: String = "yiqiu"
@export var pc_atk: int = 50 # 局内攻击
@export var pc_start_atk: int = 50 # 局内攻击
@export var pc_final_atk: float = 0.0 # 局内最终伤害（例如0.1代表最后结算时伤害为110%）
@export var pc_hp: int = 100 # 局内HP
@export var pc_lv: int = 1 # 局内等级
@export var pc_exp: int = 0 # 局内经验
@export var pc_max_hp: int = 100 # 局内最大hp
@export var pc_start_max_hp: int = 100 # 进入关卡时的初始HP上限
@export var pc_speed: float = 0 # 局内移速
@export var pc_atk_speed: float = 0 # 局内攻速加成
@export var crit_chance: float = 0.0 # 局内暴击率
@export var crit_damage_multi: float = 0.5 # 局内暴击伤害倍率 (例如0.5代表150%伤害)
@export var damage_reduction_rate: float = 0.0 # 局内减伤率 (例如0.1代表10%减伤)
@export var bullet_size: float = 0
@export var point_multi: float = 0 # 额外真气获取率
@export var exp_multi: float = 0 # 额外exp获取率
@export var drop_multi: float = 0 # 额外掉落率
@export var body_size: float = 1

@export var invincible: bool = false

@export var current_time: float = 0
@export var real_time: float = 0

@export var now_main_skill_num: int = 1
@export var last_lunky_level: int = 1
@export var last_speed: float = 0
@export var last_atk_speed: float = 0

# 魔焰相关变量
@export var main_skill_moyan = 0
@export var main_skill_moyan_advance = 0
@export var has_moyan: bool = false
@export var first_has_moyan: bool = true
@export var main_skill_moyan_damage: float = 1.0 # 魔焰基础伤害倍率
@export var moyan_range: float = 220.0 # 魔焰基础射程

# 跟升级抽卡有关系的
@export var now_lunky_level: int = 1
@export var now_red_p: float = 2
@export var now_gold_p: float = 5
@export var now_purple_p: float = 15
@export var now_blue_p: float = 35
@export var now_green_p: float = 43
@export var selected_rewards = []

# 存储主要技能等级
@export var main_skill_swordQi = 0
@export var main_skill_swordQi_advance = 0

# 剑气相关属性
@export var main_skill_swordQi_damage: float = 1
@export var swordQi_penetration_count: int = 1
@export var swordQi_other_sword_wave_damage: float = 0.5
@export var swordQi_range: float = 120
@export var jinghong_attack_count: int = 0

# 树枝相关属性
@export var main_skill_branch = 0
@export var main_skill_branch_advance = 0
@export var has_branch: bool = false
@export var first_has_branch: bool = true
@export var main_skill_branch_damage: float = 1
@export var branch_split_count: int = 3
@export var branch_range: float = 90

# 日炎相关变量
@export var main_skill_riyan = 0
@export var main_skill_riyan_advance = 0
@export var main_skill_riyan_damage: float = 1
@export var has_riyan: bool = false
@export var first_has_riyan: bool = true
@export var first_has_riyan_pc: bool = true
@export var riyan_range: float = 70.0
@export var riyan_cooldown: float = 0.5
@export var riyan_hp_max_damage: float = 0.12
@export var riyan_atk_damage: float = 0.08

# 环火相关量
@export var main_skill_ringFire = 0
@export var main_skill_ringFire_advance = 0
@export var main_skill_ringFire_damage: float = 1
@export var has_ringFire: bool = false
@export var first_has_ringFire: bool = true

# 反弹子弹相关属性
@export var rebound_size_multiplier: float = 0.4 # 反弹子弹大小倍数
@export var rebound_damage_multiplier: float = 0.35 # 反弹子弹伤害倍数

# 环形子弹相关属性
@export var ring_bullet_enabled: bool = false
@export var ring_bullet_count: int = 8
@export var ring_bullet_size_multiplier: float = 0.7
@export var ring_bullet_damage_multiplier: float = 1
@export var ring_bullet_interval: float = 2.5
@export var ring_bullet_last_shot_time: float = 0.0

# 浪形子弹相关属性
@export var wave_bullet_enabled: bool = false
@export var wave_bullet_interval: float = 4.0
@export var wave_bullet_last_shot_time: float = 0.0
@export var wave_bullet_damage_multiplier: float = 0.5 # 浪形子弹伤害倍数（默认50%攻击）
@export var wave_bullet_count: int = 8 # 浪形子弹每轮发射的弹体数量，默认8

# 召唤物相关属性
@export var summon_count: int = 0 # 当前召唤物数量
@export var summon_count_max: int = 3 # 当前召唤物数量
@export var new_summon: String
@export var summon_damage_multiplier: float = 1.0 # 召唤物伤害倍数
@export var summon_interval_multiplier: float = 1.0 # 召唤物发射间隔倍数
@export var summon_bullet_size_multiplier: float = 1.0 # 召唤物子弹大小倍数


# 刷新次数
@export var refresh_num: int = 3

# 纹章相关字段
@export var emblem_slots_max: int = 4
@export var current_emblems: Dictionary = {} # 当前持有的纹章 {emblem_id: stack}

@export var is_game_over: bool = false
@export var movement_disabled: bool = false # 控制玩家移动是否被禁用

func _ready():
	Global.connect("lucky_level_up", Callable(self, "_on_lucky_level_up"))

func _on_lucky_level_up(lunky_up: float) -> void:
	now_red_p = now_red_p + lunky_up * 0.2
	now_gold_p = now_gold_p + lunky_up * 0.4
	now_purple_p = now_purple_p + lunky_up * 0.6
	now_blue_p = now_blue_p + lunky_up * 1

func get_reward_acquisition_count(fallback_reward_id: String):
	return selected_rewards.count(fallback_reward_id)


func reset_player_attr() -> void:
	# 重置玩家奖励权重
	if PlayerRewardWeights:
		PlayerRewardWeights.reset_all_weights()

	# 初始化一系列单局内会发生变化的变量
	Global.in_menu = false
	PC.is_game_over = false
	
	PC.selected_rewards = [""]
	
	exec_pc_atk()
	exec_pc_hp()
	exec_pc_bullet_size()
	exec_lucky_level()
	
	# 根据已学习的技能初始化剑气等级和伤害
	exec_swordqi_skills()
	
	# 应用装备属性加成
	apply_equipment_bonuses()
	
	PC.real_time = 0
	PC.current_time = 0
	
	PC.pc_lv = 1
	PC.pc_exp = 0
	PC.pc_speed = 0 + (Global.cultivation_zhuifeng_level * 0.02)
	PC.pc_atk_speed = 0 + (Global.cultivation_liuguang_level * 0.02)
	
	PC.invincible = false
	
	PC.ring_bullet_enabled = false
	PC.ring_bullet_count = 8
	PC.ring_bullet_size_multiplier = 0.9
	PC.ring_bullet_damage_multiplier = 0.7
	PC.ring_bullet_interval = 2.5
	PC.ring_bullet_last_shot_time = 0.0

	# 初始化浪形子弹冷却与时间
	PC.wave_bullet_enabled = false
	PC.wave_bullet_count = 8
	PC.wave_bullet_damage_multiplier = 0.5
	PC.wave_bullet_interval = 4.0
	PC.wave_bullet_last_shot_time = 0.0
	
	# 重置反弹子弹相关属性
	PC.rebound_size_multiplier = 0.9
	PC.rebound_damage_multiplier = 0.35
	
	PC.summon_count = 0
	PC.summon_count_max = 3
	PC.summon_damage_multiplier = 0.0
	PC.summon_interval_multiplier = 1.0
	PC.summon_bullet_size_multiplier = 1.0
	
	# 重置暴击相关属性
	PC.crit_chance = 0.1 + (Global.cultivation_fengrui_level * 0.005) # 基础暴击率 + 局外成长
	PC.crit_damage_multi = 1.5 + (Global.cultivation_liejin_level * 0.01) # 基础暴击伤害倍率 + 局外成长
	
	PC.damage_reduction_rate = min(0.0 + (Global.cultivation_huti_level * 0.002), 0.7) # 基础减伤率 + 局外成长，最高70%
	PC.body_size = 0
	PC.last_atk_speed = 0
	PC.last_speed = 0
	PC.last_lunky_level = 1
	
	# 重置主要技能等级
	PC.main_skill_swordQi = 0
	PC.main_skill_swordQi_advance = 0
	PC.main_skill_swordQi_damage = 1
	PC.swordQi_penetration_count = 1
	PC.swordQi_other_sword_wave_damage = 0.5
	PC.swordQi_range = 120
	
	# 重置魔焰相关属性
	PC.main_skill_moyan = 0
	PC.main_skill_moyan_advance = 0
	PC.has_moyan = false
	PC.first_has_moyan = true
	PC.main_skill_moyan_damage = 1.0
	PC.moyan_range = 220.0
	
	# 重置树枝相关属性
	PC.main_skill_branch = 0
	PC.main_skill_branch_advance = 0
	PC.has_branch = false
	PC.first_has_branch = true
	PC.main_skill_branch_damage = 1
	PC.branch_split_count = 3
	PC.branch_range = 90
	
	# 重置日炎相关属性
	PC.main_skill_riyan = 0
	PC.main_skill_riyan_advance = 0
	PC.main_skill_riyan_damage = 1
	PC.has_riyan = false
	PC.first_has_riyan = true
	PC.first_has_riyan_pc = true
	PC.riyan_range = 70.0
	PC.riyan_cooldown = 0.5
	PC.riyan_hp_max_damage = 0.12
	PC.riyan_atk_damage = 0.08
	
	# 重置环火相关属性
	PC.main_skill_ringFire = 0
	PC.main_skill_ringFire_advance = 0
	PC.main_skill_ringFire_damage = 1
	PC.has_ringFire = false
	PC.first_has_ringFire = true
	
	PC.refresh_num = Global.refresh_max_num
	# BuffManager.clear_all_buffs() # 已由下面的EmblemManager.clear_all_emblems()替代
	
	# 重置纹章系统
	PC.current_emblems.clear()
	EmblemManager.clear_all_emblems()

# 应用装备属性加成
func apply_equipment_bonuses() -> void:
	# 获取所有装备提供的属性加成
	var equipment_stats = Global.EquipmentManager.calculate_total_equipment_stats()
	
	# 应用装备属性到玩家属性
	PC.pc_atk += equipment_stats["pc_atk"]
	PC.pc_start_atk += equipment_stats["pc_atk"]
	PC.pc_max_hp += equipment_stats["pc_hp"]
	PC.pc_start_max_hp += equipment_stats["pc_hp"]
	PC.pc_hp += equipment_stats["pc_hp"]
	PC.pc_speed += equipment_stats["pc_speed"]
	PC.pc_atk_speed += equipment_stats["pc_atk_speed"]
	PC.crit_chance += equipment_stats["crit_chance"]
	PC.crit_damage_multi += equipment_stats["crit_damage_multi"]
	PC.pc_final_atk += equipment_stats["pc_final_atk"]
	PC.point_multi += equipment_stats["point_multi"]
	PC.exp_multi += equipment_stats["exp_multi"]
	PC.drop_multi += equipment_stats["drop_multi"]
	PC.bullet_size += equipment_stats["bullet_size"]
	PC.damage_reduction_rate += equipment_stats["damage_reduction_rate"]
	
	# 确保减伤率不超过上限
	PC.damage_reduction_rate = min(PC.damage_reduction_rate, 0.9)
	
	print("装备属性加成已应用")
	print("装备提供的攻击力: ", equipment_stats["pc_atk"])
	print("装备提供的生命值: ", equipment_stats["pc_hp"])
	print("装备提供的暴击率: ", equipment_stats["crit_chance"])
	

func exec_pc_atk() -> void:
	PC.pc_atk = int(15 + int(Global.cultivation_poxu_level * 2))
	PC.pc_start_atk = PC.pc_atk
	
func exec_pc_hp() -> void:
	PC.pc_max_hp = int(15 + int(Global.cultivation_xuanyuan_level * 4))
	PC.pc_start_max_hp = PC.pc_max_hp
	PC.pc_hp = PC.pc_max_hp
	
func exec_pc_bullet_size() -> void:
	PC.bullet_size = 1

func exec_lucky_level() -> void:
	PC.now_lunky_level = Global.lunky_level
	PC.now_red_p = Global.red_p + Global.lunky_level * 0.25
	PC.now_gold_p = Global.gold_p + Global.lunky_level * 0.5
	PC.now_purple_p = Global.purple_p + Global.lunky_level * 0.8
	PC.now_blue_p = Global.blue_p + Global.lunky_level * 1

func exec_swordqi_skills() -> void:
	# 根据已学习的技能初始化剑气等级和伤害
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		
		# 检查剑气初始强化技能
		if learned_skills.has("up4_1"):
			PC.main_skill_swordQi += 1
		if learned_skills.has("up4_2"):
			PC.main_skill_swordQi += 1
		
		# 检查剑气伤害提升技能
		if learned_skills.has("up41_1"):
			PC.main_skill_swordQi_damage += 0.06
		if learned_skills.has("up41_2"):
			PC.main_skill_swordQi_damage += 0.06
		if learned_skills.has("up41_3"):
			PC.main_skill_swordQi_damage += 0.06


func get_total_increase(level) -> String:
	var total_attack = 1
	var current_level = 1 # 当前已经处理到第几级
	var attack_value = 1 # 当前每级增加的攻击力
	var duration = 2 # 第一个攻击值(+1)持续2次升级

	while current_level < level:
		var remaining_levels = level - current_level
		var add_times = min(duration, remaining_levels)

		total_attack += attack_value * add_times
		current_level += add_times

		if current_level < level:
			attack_value += 1
			duration = int(attack_value * attack_value) # 每个攻击力持续attack_value + 1次
	return str(total_attack)

func get_total_increase_hp(level) -> String:
	var total_hp = 1
	var current_level = 1 # 当前已经处理到第几级
	var hp_value = 1
	var duration = 6

	while current_level < level:
		var remaining_levels = level - current_level
		var add_times = min(duration, remaining_levels)

		total_hp += hp_value * add_times
		current_level += add_times

		if current_level < level:
			hp_value += 1
			duration = 6 + int((hp_value + 4) * hp_value)
	return str(total_hp)

# 角色数据配置 - 用于背包界面显示
var character_data = {
	"yiqiu": {
		"display_name": "奕秋",
		"animation_path": "res://AssetBundle/Sprites/idle.png",
		"animation_name": "idle"
	}
}

# 获取角色显示名称
func get_character_display_name(char_name: String = "") -> String:
	if char_name.is_empty():
		char_name = player_name
	if character_data.has(char_name):
		return character_data[char_name].display_name
	return char_name

# 获取角色动画资源路径
func get_character_animation_path(char_name: String = "") -> String:
	if char_name.is_empty():
		char_name = player_name
	if character_data.has(char_name):
		return character_data[char_name].animation_path
	return ""

# 获取角色动画名称
func get_character_animation_name(char_name: String = "") -> String:
	if char_name.is_empty():
		char_name = player_name
	if character_data.has(char_name):
		return character_data[char_name].animation_name
	return "idle"

# 获取角色属性文本（用于背包界面显示）
func get_character_attributes_text() -> String:
	# 计算基础属性值
	var base_atk = int(15 + int(Global.cultivation_poxu_level * 2))
	var base_hp = int(15 + int(Global.cultivation_xuanyuan_level * 4))
	
	# 获取装备加成
	var equipment_stats = Global.EquipmentManager.calculate_total_equipment_stats()
	
	# 计算最终属性
	var final_atk = base_atk + equipment_stats["pc_atk"]
	var final_hp = base_hp + equipment_stats["pc_hp"]
	var atk_speed = (Global.cultivation_liuguang_level * 0.02 + equipment_stats["pc_atk_speed"]) * 100
	var move_speed = (Global.cultivation_zhuifeng_level * 0.02 + equipment_stats["pc_speed"]) * 100
	var damage_reduction = min((Global.cultivation_huti_level * 0.002) + equipment_stats["damage_reduction_rate"], 0.7) * 100
	var crit_rate = (0.1 + Global.cultivation_fengrui_level * 0.005 + equipment_stats["crit_chance"]) * 100
	var crit_damage = (1.5 + Global.cultivation_liejin_level * 0.01 + equipment_stats["crit_damage_multi"]) * 100
	var point_rate = (1 + Global.cultivation_hualing_level * 0.05 + equipment_stats["point_multi"]) * 100
	var exp_rate = (1 + equipment_stats["exp_multi"]) * 100
	var drop_rate = (1 + equipment_stats["drop_multi"]) * 100
	
	# 计算修为
	var cultivation_power = _calculate_cultivation_power(
		final_atk, final_hp, atk_speed, move_speed, damage_reduction,
		crit_rate, crit_damage, point_rate, exp_rate, drop_rate
	)
	
	var attr_text = ""
	# 修为使用金红过渡色和稍大字号显示
	attr_text += _get_cultivation_bbcode(cultivation_power) + "\n"
	attr_text += "攻击  " + str(final_atk) + "\n"
	attr_text += "体力  " + str(final_hp) + "\n"
	attr_text += "攻击速度  " + str(int(atk_speed)) + "%\n"
	attr_text += "移动速度  " + str(int(move_speed)) + "%\n"
	attr_text += "减伤率  " + str(int(damage_reduction)) + "%\n"
	attr_text += "暴击率  " + str(int(crit_rate)) + "%\n"
	attr_text += "暴击伤害  " + str(int(crit_damage)) + "%\n"
	attr_text += "真气获取  " + str(int(point_rate)) + "%\n"
	attr_text += "经验获取  " + str(int(exp_rate)) + "%\n"
	attr_text += "掉落率  " + str(int(drop_rate)) + "%"
	
	return attr_text

# 计算修为值
# 公式: 攻击*攻速*暴击期望 + 体力*移动速度*减伤期望 + 真气获取 + 经验获取加成 + 掉落率加成
func _calculate_cultivation_power(final_atk: int, final_hp: int, atk_speed: float, move_speed: float,
								   damage_reduction: float, crit_rate: float, crit_damage: float,
								   point_rate: float, exp_rate: float, drop_rate: float) -> int:
	# 攻速实际倍率 = 1 + atk_speed/100
	var atk_speed_multi = 1.0 + atk_speed / 100.0
	# 暴击期望 = 1 + 暴击率 * (暴击伤害倍率 - 1)
	# crit_damage 是百分比形式(如150表示150%)，需要转换为倍率
	var crit_expectation = 1.0 + (crit_rate / 100.0) * (crit_damage / 100.0 - 1.0)
	# 攻击部分 = 攻击 * 攻速 * 暴击期望
	var atk_part = final_atk * 8 * atk_speed_multi * crit_expectation
	
	# 移动速度实际倍率 = 1 + move_speed/100
	var move_speed_multi = 1.0 + move_speed / 100.0
	# 减伤期望 = 1 / (1 - 减伤率)，例如50%减伤可以抗原来200%的伤害
	# damage_reduction 是百分比形式(如50表示50%)
	var damage_reduction_ratio = damage_reduction / 100.0
	var reduction_expectation = 1.0 / max(1.0 - damage_reduction_ratio, 0.1) # 防止除以0
	# 体力部分 = 体力 * 移动速度 * 减伤期望
	var hp_part = final_hp * 5 * move_speed_multi * reduction_expectation
	
	# 真气获取部分直接加入
	var point_part = max(point_rate - 100, 0) * 6
	
	# 经验获取每超出100%的1%加6点
	var exp_bonus = max(exp_rate - 100, 0) * 9
	
	# 掉落率每超出100%的1%加8点
	var drop_bonus = max(drop_rate - 100, 0) * 12
	
	# === 属性额外加成（不参与乘算） ===
	# 攻速每1%额外加4点修为
	var atk_speed_bonus = atk_speed * 16.0
	# 移动速度每1%额外加4点修为
	var move_speed_bonus = move_speed * 16.0
	# 暴击率每0.5%额外加8点修为（即每1%加16点）
	var crit_rate_bonus = crit_rate * 64.0
	# 暴击伤害在150%基础上，每1%额外加8点修为
	var crit_damage_bonus = max(crit_damage - 150, 0) * 16.0
	# 减伤率每0.1%额外加3点修为（即每1%加30点）
	var damage_reduction_bonus = damage_reduction * 120.0
	
	# 总修为
	var total_cultivation = atk_part + hp_part + point_part + exp_bonus + drop_bonus \
		+ atk_speed_bonus + move_speed_bonus + crit_rate_bonus + crit_damage_bonus + damage_reduction_bonus
	
	return int(total_cultivation)

# 生成修为的BBCode文本（金红过渡色，稍大字号）
func _get_cultivation_bbcode(cultivation_power: int) -> String:
	# 将修为值转换为字符串
	var power_str = str(cultivation_power)
	var result = "[font_size=36][color=#FFD700]修为   [/color]"
	
	# 为每个字符应用金红渐变色
	# 金色(FFD700)
	var colors = [
		"#FF4500"
	]
	
	var char_count = power_str.length()
	for i in range(char_count):
		# 根据字符位置选择颜色
		var color_index = int(float(i) / float(max(char_count - 1, 1)) * (colors.size() - 1))
		color_index = clamp(color_index, 0, colors.size() - 1)
		result += "[color=" + colors[color_index] + "]" + power_str[i] + "[/color]"
	
	result += "[/font_size]"
	return result
