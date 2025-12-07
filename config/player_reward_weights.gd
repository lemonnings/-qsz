extends Node

# 用于存储不同稀有度下各派系的动态权重
# 结构: { "rarity_name": { "faction_name": weight_value, ... }, ... }
var rarity_faction_weights: Dictionary = {}

# 默认的初始权重，根据新的分类体系
var INITIAL_FACTION_WEIGHTS: Dictionary = {
	"normal": 4.0,           # 通用，通用型、基础属性提升
	"branch": 2.0,           # 树枝
	"moyan": 2.0,           # 魔焰
	"riyan": 2.0,           # 日炎
	"ringFire": 2.0,           # 环火
	"swordQi": 4.0,           # 剑气
	"summon": 2.0,           # 召唤，召唤物数量、召唤物属性提升等
	#"bullet": 1.0,           # 剑气，弹体大小、反弹、分裂（三向、五向）等
	"lucky": 2.0,           # 天命，与幸运值、特殊几率触发等相关的
	"craft": 2.0,           # 技艺，与主动技能，环形伤害等特殊攻击方式相关的
	#"live": 1.0,           # 炼体，与生存能力，反击相关的
}

# 定义游戏中存在的稀有度等级
const RARITY_LEVELS: Array[String] = ["normal_white", "pro_green", "rare_blue", "super_rare_purple", "super2_rare_orange", "unbelievable_gold"] 

func _init():
	print("PlayerRewardWeights initialized.")
	reset_all_weights()

# 重置所有稀有度的所有派系权重到初始值
func reset_all_weights():
	rarity_faction_weights.clear()
	for rarity in RARITY_LEVELS:
		rarity_faction_weights[rarity] = INITIAL_FACTION_WEIGHTS.duplicate(true) # 深拷贝
	
# 获取特定稀有度下特定派系的权重
func get_faction_weight(rarity: String, faction: String) -> float:
	if rarity_faction_weights.has(rarity) and rarity_faction_weights[rarity].has(faction):
		return rarity_faction_weights[rarity][faction]
	elif INITIAL_FACTION_WEIGHTS.has(faction): # 如果特定稀有度没有，尝试返回初始默认值
		return INITIAL_FACTION_WEIGHTS[faction]
	printerr("Attempted to get weight for unknown rarity/faction: %s / %s" % [rarity, faction])
	return 1.0 # 返回一个默认安全值

# 更新特定稀有度下特定派系的权重 (直接设置新权重)
func set_faction_weight(rarity: String, faction: String, new_weight: float):
	if rarity_faction_weights.has(rarity):
		if rarity_faction_weights[rarity].has(faction) or faction == "normal": # 允许更新已知派系或公共派系
			rarity_faction_weights[rarity][faction] = new_weight
		else:
			printerr("Attempted to set weight for unknown faction '%s' in rarity '%s'" % [faction, rarity])
	else:
		printerr("Attempted to set weight for unknown rarity: %s" % rarity)
