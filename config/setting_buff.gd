extends Node

# Buff类型枚举
enum BuffType {
	PERMANENT,  # 永久buff
	TEMPORARY   # 临时buff
}

# Buff数据结构
class BuffData:
	var id: String
	var name: String
	var icon_path: String
	var type: BuffType
	var max_stack: int = 1
	var description: String = ""
	
	func _init(buff_id: String, buff_name: String, buff_icon_path: String, buff_type: BuffType, buff_max_stack: int = 1, buff_description: String = ""):
		id = buff_id
		name = buff_name
		icon_path = buff_icon_path
		type = buff_type
		max_stack = buff_max_stack
		description = buff_description

# Buff配置字典
var buff_configs: Dictionary = {}

func _ready():
	# 初始化buff配置
	_init_buff_configs()

func _init_buff_configs():
	# 示例buff配置，你可以根据需要添加更多
	buff_configs["xueqi"] = BuffData.new(
		"xueqi",
		"血气",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.TEMPORARY,
		5,
		"基础武器攻击附带2*层数%当前HP的伤害。"
	)
	
	buff_configs["pozhen"] = BuffData.new(
		"pozhen",
		"破阵",
		"res://AssetBundle/Sprites/UI/buff_speed.png",
		BuffType.TEMPORARY,
		3,
		"基础武器攻击有5*层数%概率直击，额外造成30%无视敌方减伤的伤害."
	)
	
	buff_configs["health_regen"] = BuffData.new(
		"health_regen",
		"生命回复",
		"res://AssetBundle/Sprites/UI/buff_health.png",
		BuffType.PERMANENT,
		1,
		"持续回复生命值，每秒回复最大生命值的2%。这是一个永久性的被动效果。"
	)
	
	buff_configs["crit_chance"] = BuffData.new(
		"crit_chance",
		"暴击率提升",
		"res://AssetBundle/Sprites/UI/buff_crit.png",
		BuffType.TEMPORARY,
		10,
		"增加暴击几率，每层提升5%暴击率。暴击时造成200%伤害。"
	)
	
	buff_configs["damage_reduction"] = BuffData.new(
		"damage_reduction",
		"伤害减免",
		"res://AssetBundle/Sprites/UI/buff_shield.png",
		BuffType.TEMPORARY,
		1,
		"减少受到的伤害，提供20%的伤害减免效果。在危险时刻保护你的安全。"
	)
	
	buff_configs["rebound"] = BuffData.new(
		"rebound",
		"续剑",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		1,
		"剑气击中敌人后会反弹"
	)
	
	buff_configs["three_way"] = BuffData.new(
		"three_way",
		"三向剑气",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		1,
		"剑气会对前方三个方向射出"
	)
	
	buff_configs["five_way"] = BuffData.new(
		"five_way",
		"五向剑气",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		1,
		"剑气会对前方五个方向射出"
	)

func get_buff_data(buff_id: String) -> BuffData:
	if buff_configs.has(buff_id):
		return buff_configs[buff_id]
	else:
		print("Warning: Buff ID '" + buff_id + "' not found in configs")
		return null

func get_all_buff_ids() -> Array:
	return buff_configs.keys()
