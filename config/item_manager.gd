extends Node

# 物品数据字典
# item_id: 唯一ID
# item_name: 道具名
# item_stack_max: 最大堆叠数量
# item_type: 物品类型 ("immediate", "equip", "artifact")
# item_icon: 图标路径 (String)
# item_price: 价格 (Int/Float)
# item_source: 物品来源 (String)
# item_use_condition: 使用条件 (String)
# item_detail: 详情 (String)
# item_rare: 品质 (String/Int, e.g., "common", "rare", "epic" / 1, 2, 3)
# item_color: 掉落时显示的颜色 (Color / String, e.g., Color(1,1,1) / "white")
# item_anime: 掉落时显示的动画 (String - 动画资源路径或名称)

var items_data = {
	"item_001": {
		"item_name": "野果",
		"item_stack_max": 10,
		"item_type": "immediate", # 立即生效
		"item_icon": "res://AssetBundle/Sprites/Ghostpixxells_pixelfood/69_meatball.png",
		"item_price": 50,
		"item_source": "怪物掉落, 商店购买",
		"item_use_condition": "HP < MaxHP",
		"item_detail": "恢复少量生命值。",
		"item_rare": "common", # 普通
		"item_color": Color(0.8, 0.8, 0.8, 1), # 白色
		"item_anime": "res://assets/animations/item_pickup_common.tres"
	},
	"item_002": {
		"item_name": "力量之戒",
		"item_stack_max": 1,
		"item_type": "equip", # 装备
		"item_icon": "res://assets/icons/ring_strength.png",
		"item_price": 500,
		"item_source": "宝箱开启, Boss掉落",
		"item_use_condition": "可装备栏位",
		"item_detail": "装备后增加攻击力。",
		"item_rare": "rare", # 稀有
		"item_color": Color(0.2, 0.5, 1.0, 1), # 蓝色
		"item_anime": "res://assets/animations/item_pickup_rare.tres"
	},
	"item_003": {
		"item_name": "贤者之石碎片",
		"item_stack_max": 99,
		"item_type": "artifact", # 圣器 (或用于合成圣器的材料)
		"item_icon": "res://assets/icons/philosopher_stone_shard.png",
		"item_price": 1000, # 单个价格，或者表示其价值
		"item_source": "特定事件, 隐藏任务",
		"item_use_condition": "收集特定数量可合成",
		"item_detail": "古老圣器的碎片，蕴含着神秘的力量。",
		"item_rare": "epic", # 史诗
		"item_color": Color(0.7, 0.3, 0.9, 1), # 紫色
		"item_anime": "res://assets/animations/item_pickup_epic.tres"
	}
	# 更多物品可以添加到这里
}

# 物品效果处理函数
var item_function = {
	"item_001": "_on_item_001_picked_up",
	"item_002": "_on_item_002_picked_up"
}

# 根据物品ID获取该物品的所有数据
func get_item_all_data(item_id: String) -> Dictionary:
	if items_data.has(item_id):
		return items_data[item_id]
	else:
		printerr("Item not found: ", item_id)
		return {}

# 根据物品ID和属性名获取特定属性值
func get_item_property(item_id: String, property_name: String):
	if items_data.has(item_id):
		var item_info = items_data[item_id]
		if item_info.has(property_name):
			return item_info[property_name]
		else:
			printerr("Property not found for item '", item_id, "': ", property_name)
			return null
	else:
		printerr("Item not found: ", item_id)
		return null

# 野果拾取函数
func _on_item_001_picked_up(player):
	# 只有满血时才能拾取
	if PC.pc_hp != PC.pc_max_hp:
		PC.pc_hp += PC.pc_max_hp * 0.2
		# 防止生命值超过上限
		if PC.pc_hp > PC.pc_max_hp:
			PC.pc_hp = PC.pc_max_hp
		return true # 表示成功拾取
	else:
		return false # 表示无法拾取

# 力量之戒拾取函数
func _on_item_002_picked_up(player):
	# 将力量之戒添加到 Global 的玩家背包中
	if !Global.player_inventory.has("item_002"):
		Global.player_inventory["item_002"] = 1
	else:
		Global.player_inventory["item_002"] += 1
	return true # 表示成功拾取

# 示例用法:
# func _ready():
# 	var potion_details = get_item_all_data("item_001")
# 	if potion_details:
# 		print("药水名称: ", potion_details.item_name)
# 		print("药水价格: ", potion_details.item_price)
#
# 	var ring_type = get_item_property("item_002", "item_type")
# 	if ring_type != null:
# 		print("戒指类型: ", ring_type)
#
# 	var non_existent_item = get_item_property("item_999", "item_name")
# 	if non_existent_item == null:
# 		print("尝试获取不存在的物品属性，返回null")
