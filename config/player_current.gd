extends Node

@export var player_instance: Node = null
@export var pc_atk : int = 50 # 局内攻击
@export var pc_final_atk : float = 0.0 # 局内最终伤害（例如0.1代表最后结算时伤害为110%）
@export var pc_hp : int = 100 # 局内HP
@export var pc_lv : int = 1 # 局内等级
@export var pc_exp : int = 0 # 局内经验
@export var pc_max_hp : int = 100 # 局内最大hp
@export var pc_speed : float = 0 # 局内移速
@export var pc_atk_speed : float = 0 # 局内攻速加成
@export var crit_chance : float = 0.0  # 局内暴击率
@export var crit_damage_multiplier : float = 0.5  # 局内暴击伤害倍率 (例如0.5代表150%伤害) 
@export var damage_reduction_rate : float = 0.0 # 局内减伤率 (例如0.1代表10%减伤)
@export var bullet_size : float = 0
@export var bullet_type1 : int = 0
@export var bullet_type2 : int = 0
@export var body_size : float = 1
@export var invincible : bool = false
@export var current_time : float = 0
@export var real_time : float = 0

@export var now_main_skill_num : int = 1
@export var last_lunky_level : int = 1
@export var last_speed : float = 0
@export var last_atk_speed : float = 0

# 魔焰相关变量
@export var main_skill_moyan = 0
@export var main_skill_moyan_advance = 0
@export var has_moyan : bool = false
@export var first_has_moyan : bool = true
@export var main_skill_moyan_damage : float = 1.0  # 魔焰基础伤害倍率
@export var moyan_range : float = 220.0  # 魔焰基础射程

# 跟升级抽卡有关系的
@export var now_lunky_level : int = 1
@export var now_red_p : float = 2
@export var now_gold_p : float = 5
@export var now_purple_p : float = 15
@export var now_blue_p : float = 35
@export var now_green_p : float = 43
@export var selected_rewards = []

# 存储主要技能等级
@export var main_skill_swordQi = 0
@export var main_skill_swordQi_advance = 0

# 剑气相关属性
@export var main_skill_swordQi_damage : float = 1
@export var swordQi_penetration_count : int = 1
@export var swordQi_other_sword_wave_damage : float = 0.5
@export var swordQi_range :float = 120

# 树枝相关属性
@export var main_skill_branch = 0
@export var main_skill_branch_advance = 0
@export var has_branch : bool = false
@export var first_has_branch : bool = true
@export var main_skill_branch_damage : float = 1
@export var branch_split_count : int = 3
@export var branch_range :float = 90

# 日炎相关变量
@export var main_skill_riyan = 0
@export var main_skill_riyan_advance = 0
@export var main_skill_riyan_damage : float = 1
@export var has_riyan : bool = false
@export var first_has_riyan : bool = true
@export var first_has_riyan_pc : bool = true
@export var riyan_range : float = 70.0
@export var riyan_cooldown : float = 0.5
@export var riyan_hp_max_damage : float = 0.12
@export var riyan_atk_damage : float = 0.08

# 环火相关量
@export var main_skill_ringFire = 0
@export var main_skill_ringFire_advance = 0
@export var main_skill_ringFire_damage : float = 1
@export var has_ringFire : bool = false
@export var first_has_ringFire : bool = true

# 反弹子弹相关属性
@export var rebound_size_multiplier : float = 0.4  # 反弹子弹大小倍数
@export var rebound_damage_multiplier : float = 0.35  # 反弹子弹伤害倍数

# 环形子弹相关属性
@export var ring_bullet_enabled : bool = false
@export var ring_bullet_count : int = 8
@export var ring_bullet_size_multiplier : float = 0.7
@export var ring_bullet_damage_multiplier : float = 1
@export var ring_bullet_interval : float = 2.5
@export var ring_bullet_last_shot_time : float = 0.0

# 召唤物相关属性
@export var summon_count : int = 0  # 当前召唤物数量
@export var summon_count_max : int = 3  # 当前召唤物数量
@export var new_summon : String 
@export var summon_damage_multiplier : float = 1.0  # 召唤物伤害倍数
@export var summon_interval_multiplier : float = 1.0  # 召唤物发射间隔倍数
@export var summon_bullet_size_multiplier : float = 1.0  # 召唤物子弹大小倍数 


# 刷新次数
@export var refresh_num : int = 3 

@export var is_game_over : bool = false
@export var movement_disabled : bool = false  # 控制玩家移动是否被禁用

func _ready():
	Global.connect("lucky_level_up", Callable(self, "_on_lucky_level_up"))

func _on_lucky_level_up(lunky_up: float) -> void:
	now_red_p = now_red_p + lunky_up * 0.25
	now_gold_p = now_gold_p + lunky_up * 0.5
	now_purple_p = now_purple_p + lunky_up * 0.8
	now_blue_p = now_blue_p + lunky_up * 1

func get_reward_acquisition_count(fallback_reward_id: String):
	return selected_rewards.count(fallback_reward_id)


func reset_player_attr() -> void :
	# 重置玩家奖励权重
	if PlayerRewardWeights:
		PlayerRewardWeights.reset_all_weights()

	# 初始化一系列单局内会发生变化的变量
	Global.in_menu = false
	PC.is_game_over = false
	
	PC.selected_rewards = [""] # "swordWaveTrace"
	
	exec_pc_atk()
	exec_pc_hp()
	exec_pc_bullet_size()
	exec_lucky_level()
	
	PC.real_time = 0
	PC.current_time = 0
	
	PC.pc_lv = 1
	PC.pc_exp = 0
	PC.pc_speed = 0
	PC.pc_atk_speed = 0 + (Global.cultivation_liuguang_level * 0.03)
	
	PC.invincible = false
	
	PC.ring_bullet_enabled = false
	PC.ring_bullet_count = 8
	PC.ring_bullet_size_multiplier = 0.9
	PC.ring_bullet_damage_multiplier = 1
	PC.ring_bullet_interval = 2.5
	PC.ring_bullet_last_shot_time = 0.0
	
	# 重置反弹子弹相关属性
	PC.rebound_size_multiplier = 0.9
	PC.rebound_damage_multiplier = 0.35
	
	PC.summon_count = 0 
	PC.summon_count_max  = 3
	PC.summon_damage_multiplier = 0.0
	PC.summon_interval_multiplier = 1.0
	PC.summon_bullet_size_multiplier = 1.0
	
	# 重置暴击相关属性
	PC.crit_chance = 0.1 + (Global.cultivation_fengrui_level * 0.005) # 基础暴击率 + 局外成长
	PC.crit_damage_multiplier = 1.5 + (Global.cultivation_liejin_level * 0.01) # 基础暴击伤害倍率 + 局外成长
	
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
	BuffManager.clear_all_buffs()
	

func exec_pc_atk() -> void:
	PC.pc_atk = int (15 + int(get_total_increase(Global.cultivation_poxu_level)))
	
func exec_pc_hp() -> void:
	PC.pc_max_hp = int (15 + int(get_total_increase_hp(Global.cultivation_xuanyuan_level)))
	PC.pc_hp = PC.pc_max_hp
	
func exec_pc_bullet_size() -> void:
	PC.bullet_size = 1

func exec_lucky_level() -> void:
	PC.now_lunky_level = Global.lunky_level
	PC.now_red_p = Global.red_p
	PC.now_gold_p = Global.gold_p
	PC.now_purple_p = Global.purple_p
	PC.now_blue_p = Global.blue_p
	PC.now_green_p = Global.green_p


func get_total_increase(level) -> String:
	var total_attack = 1
	var current_level = 1  # 当前已经处理到第几级
	var attack_value = 1   # 当前每级增加的攻击力
	var duration = 2       # 第一个攻击值(+1)持续2次升级

	while current_level < level:
		var remaining_levels = level - current_level
		var add_times = min(duration, remaining_levels)

		total_attack += attack_value * add_times
		current_level += add_times

		if current_level < level:
			attack_value += 1
			duration = int(attack_value * attack_value)  # 每个攻击力持续attack_value + 1次
	return str(total_attack)

func get_total_increase_hp(level) -> String:
	var total_hp = 1
	var current_level = 1  # 当前已经处理到第几级
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
