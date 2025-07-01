extends Node

@export var player_instance: Node = null
@export var pc_atk : int = 50
@export var pc_hp : int = 100
@export var pc_lv : int = 1
@export var pc_exp : int = 0
@export var pc_max_hp : int = 100
@export var pc_speed : float = 0
@export var pc_atk_speed : float = 0
@export var bullet_size : float = 0
@export var bullet_type1 : int = 0
@export var bullet_type2 : int = 0
@export var body_size : float = 1
@export var invincible : bool = false
@export var current_time : float = 0
@export var real_time : float = 0

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

# 日炎相关变量
@export var has_riyan : bool = false
@export var first_has_riyan : bool = true
@export var first_has_riyan_pc : bool = true
@export var riyan_range : float = 40.0
@export var riyan_cooldown : float = 0.5
@export var riyan_hp_max_damage : float = 0.4


# 跟升级抽卡有关系的
@export var now_lunky_level : int = 1
@export var now_red_p : float = 2
@export var now_gold_p : float = 5
@export var now_purple_p : float = 15
@export var now_blue_p : float = 35
@export var now_green_p : float = 44
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


# 暴击相关属性
@export var crit_chance : float = 0.0  # 局内暴击率
@export var crit_damage_multiplier : float = 0.5  # 局内暴击伤害倍率 (例如1.5代表150%伤害) 
@export var damage_reduction_rate : float = 0.0 # 局内减伤率 (例如0.1代表10%减伤)

# 刷新次数
@export var refresh_num : int = 3 

@export var is_game_over : bool = false

func _ready():
	Global.connect("lucky_level_up", Callable(self, "_on_lucky_level_up"))

func _on_lucky_level_up(lunky_up: float) -> void:
	now_red_p = now_red_p + lunky_up * 0.25
	now_gold_p = now_gold_p + lunky_up * 0.5
	now_purple_p = now_purple_p + lunky_up * 0.8
	now_blue_p = now_blue_p + lunky_up * 1

func get_reward_acquisition_count(fallback_reward_id: String):
	return selected_rewards.count(fallback_reward_id)
