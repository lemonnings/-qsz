extends Node

# 用于存储不同稀有度下各派系的动态权重
# 结构: { "rarity_name": { "faction_name": weight_value, ... }, ... }
var rarity_faction_weights: Dictionary = {}

# 默认的初始权重，根据新的分类体系
var INITIAL_FACTION_WEIGHTS: Dictionary = {
	"Normal": 4.0, # 通用，通用型、基础属性提升
	"Branch": 2.0, # 树枝
	"Moyan": 999.0, # 魔焰
	"Riyan": 2.0, # 日炎
	"Ringfire": 9999.0, # 环火
	"Thunderbreak": 2.0, # 雷破
	"Swordqi": 2.0, # 剑气
	"Thunder": 2.0,
	"Bloodwave": 2.0,
	"Bloodboardsword": 2.0,
	"Lightbullet": 2.0,
	"Water": 2.0,
	"Qiankun": 2.0,
	"Xuanwu": 2.0,
	"Xunfeng": 4.0,
	"Genshan": 2.0,
	"Duize": 4.0,
	"Qigong": 2.0,
	"Holylight": 2.0,
	"Ice": 4.0,
	"Six": 2.0,
	"Summon": 2.0,
	"Dragonwind": 2.0,
	"Lucky": 2.0,
	"Craft": 2.0,
	"Live": 1.0
}

# 定义游戏中存在的稀有度等级
const RARITY_LEVELS: Array[String] = ["normal_white", "pro_green", "rare_blue", "super_rare_darkorchid", "super2_rare_orange", "unbelievable_gold"]

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
