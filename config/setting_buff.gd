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
	buff_configs["faze_bullet"] = BuffData.new(
		"faze_bullet",
		"弹雨法则",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		99,
		"弹雨法则层数"
	)
	
	buff_configs["barrage_charge"] = BuffData.new(
		"barrage_charge",
		"弹幕积累",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		9999,
		"弹幕积累层数"
	)
	
	buff_configs["bagua_progress"] = BuffData.new(
		"bagua_progress",
		"推衍度",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		9999,
		"推衍度，下一层需要" + str(PC.faze_bagua_next_threshold) + "推衍度"
	)
	
	buff_configs["bagua_completed"] = BuffData.new(
		"bagua_completed",
		"推衍完成",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		9999,
		"已完成推衍的层数，每层提升4%的八卦类武器伤害加成与经验获取"
	)
	
	buff_configs["huanfeng"] = BuffData.new(
		"huanfeng",
		"唤风",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.TEMPORARY,
		500,
		"唤风层数，每层提升0.1%攻击速度与移动速度，持续30秒"
	)
	
	buff_configs["mizongbu"] = BuffData.new(
		"mizongbu",
		"迷踪步",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.TEMPORARY,
		1,
		"移动速度提升50%，减伤40%，造成伤害降低50%"
	)


func get_buff_data(buff_id: String) -> BuffData:
	if buff_configs.has(buff_id):
		return buff_configs[buff_id]
	else:
		print("Warning: Buff ID '" + buff_id + "' not found in configs")
		return null

func get_all_buff_ids() -> Array:
	return buff_configs.keys()
