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
		5,
		"基础武器攻击有5*层数%概率直击，额外造成30%无视敌方减伤的伤害。"
	)
	
	buff_configs["tiegu"] = BuffData.new(
		"tiegu",
		"铁骨",
		"res://AssetBundle/Sprites/UI/buff_health.png",
		BuffType.PERMANENT,
		5,
		"受到伤害后，反弹被角色减伤率而降低的25*层数%的伤害。"
	)
	
	buff_configs["jinghong"] = BuffData.new(
		"jinghong",
		"惊鸿",
		"res://AssetBundle/Sprites/UI/buff_crit.png",
		BuffType.TEMPORARY,
		5,
		"基础武器每攻击3次，额外攻击1次，该次攻击造成15*层数%的伤害。"
	)
	
	buff_configs["tafeng"] = BuffData.new(
		"tafeng",
		"踏风",
		"res://AssetBundle/Sprites/UI/buff_shield.png",
		BuffType.TEMPORARY,
		5,
		"每10%的移动速度加成转化为0.5*层数%的冷却缩减。"
	)
	
	buff_configs["chenjing"] = BuffData.new(
		"chenjing",
		"沉静",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		5,
		"1秒内没有移动，提升6*层数%的最终伤害。"
	)
	
	buff_configs["lianti"] = BuffData.new(
		"lianti",
		"炼体",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		5,
		"每1%的减伤率额外提升0.2*层数%的最终伤害。"
	)
	
	buff_configs["jianbu"] = BuffData.new(
		"jianbu",
		"健步",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		5,
		"当移动速度加成>20%时，提升4*层数%的最终伤害。"
	)

	buff_configs["manli"] = BuffData.new(
		"manli",
		"蛮力",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		5,
		"当移动速度加成<0%时，提升5*层数%的最终伤害。"
	)

	buff_configs["ronghui"] = BuffData.new(
		"ronghui",
		"融会贯通",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		5,
		"当前每拥有一个buff，提升0.8*层数%最终伤害。"
	)

func get_buff_data(buff_id: String) -> BuffData:
	if buff_configs.has(buff_id):
		return buff_configs[buff_id]
	else:
		print("Warning: Buff ID '" + buff_id + "' not found in configs")
		return null

func get_all_buff_ids() -> Array:
	return buff_configs.keys()
