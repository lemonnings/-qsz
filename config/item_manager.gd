extends Node

# 物品数据字典
# item_id: 唯一ID
# item_name: 道具名
# item_stack_max: 最大堆叠数量
# item_type: 物品类型 ("immediate"（拾取后直接使用，例如血药）, "equip"（法宝）, "material"（材料），"consumable"（消耗品），"special"（特殊的不可使用的物品，如钥匙）
# item_icon: 图标路径 (String)
# item_price: 价格 (Int/Float)
# item_source: 物品来源 (String)
# item_use_condition: 使用条件 (String)，为1个函数,一般都是空的，只有满足特殊条件才能使用的consumable才需要加上这个
# item_detail: 详情 (String)
# item_rare: 品质 (String/Int, e.g., "common", "rare", "epic", "legend", "artifact" / 1, 2, 3) 对应白色 蓝色 紫色 橙色 红色
# item_color: 掉落时显示的颜色 (Color / String, e.g., Color(1,1,1) / "white")
# item_anime: 掉落时显示的动画 (String - 动画资源路径或名称)

var items_data = {
	"item_001": {
		"item_name": "生命精华",
		"item_stack_max": 10,
		"item_type": "immediate", # 立即生效
		"item_icon": "res://AssetBundle/Sprites/Ghostpixxells_pixelfood/69_meatball.png",
		"item_price": 50,
		"item_source": "怪物掉落",
		"item_use_condition": "",
		"item_detail": "恢复少量生命值。",
		"item_rare": "common", # 普通
		"item_color": Color(0.8, 0.8, 0.8, 1), # 白色
		"item_anime": "res://assets/animations/item_pickup_common.tres"
	},
	"item_002": {
		"item_name": "聚灵珠",
		"item_stack_max": 1,
		"item_type": "equip", # 装备
		"item_icon": "res://assets/icons/ring_strength.png",
		"item_price": 500,
		"item_source": "任务奖励",
		"item_use_condition": "",
		"item_detail": "能加速真气的获取",
		"item_rare": "rare", # 稀有
		"item_color": Color(0.2, 0.5, 1.0, 1), # 蓝色
		"item_anime": "res://assets/animations/item_pickup_rare.tres"
	},
	"item_003": {
		"item_name": "聚灵石碎片",
		"item_stack_max": 999,
		"item_type": "material", 
		"item_icon": "res://AssetBundle/Sprites/Ghostpixxells_pixelfood/69_meatball.png",
		"item_price": 10, # 单个价格，或者表示其价值
		"item_source": "击败敌人获取",
		"item_use_condition": "",
		"item_detail": "集齐10个聚灵石碎片，可以合成1个聚灵石",
		"item_rare": "rare", # 史诗
		"item_color": Color(0.2, 0.5, 1.0, 1), # 蓝色
		"item_anime": "res://assets/animations/item_pickup_common.tres"
	},
	"item_004": {
		"item_name": "九幽秘钥碎片",
		"item_stack_max": 99,
		"item_type": "material", # 圣器 (或用于合成圣器的材料)
		"item_icon": "res://assets/icons/philosopher_stone_shard.png",
		"item_price": 1000, # 单个价格，或者表示其价值
		"item_source": "击败敌人获取",
		"item_use_condition": "",
		"item_detail": "九幽秘钥的碎片，蕴含着神秘的力量，收集满10个后可以合成一个完整的九幽秘钥",
		"item_rare": "epic", # 史诗
		"item_color": Color(0.7, 0.3, 0.9, 1), # 紫色
		"item_anime": "res://assets/animations/item_pickup_epic.tres"
	},
	"item_005": {
		"item_name": "聚灵石",
		"item_stack_max": 1,
		"item_type": "material", 
		"item_icon": "res://assets/icons/philosopher_stone.png",
		"item_price": 100,
		"item_source": "合成获得",
		"item_use_condition": "",
		"item_detail": "完整的聚灵石，蕴含着强大的力量。",
		"item_rare": "legendary", # 传说
		"item_color": Color(1.0, 0.8, 0.0, 1), # 金色
		"item_anime": "res://assets/animations/item_pickup_legendary.tres"
	},
	"item_006": {
		"item_name": "九幽秘钥",
		"item_stack_max": 1,
		"item_type": "special", 
		"item_icon": "res://assets/icons/jiuyou_key.png",
		"item_price": 10000,
		"item_source": "合成获得",
		"item_use_condition": "",
		"item_detail": "完整的九幽秘钥，可以开启通往九幽的神秘之门。",
		"item_rare": "legendary", # 传说
		"item_color": Color(1.0, 0.8, 0.0, 1), # 金色
		"item_anime": "res://assets/animations/item_pickup_legendary.tres"
	},
	"item_007": {
		"item_name": "破灵珠",
		"item_stack_max": 1,
		"item_type": "equip", # 装备
		"item_icon": "res://assets/icons/composite_equipment.png",
		"item_price": 2000,
		"item_source": "合成获得",
		"item_use_condition": "",
		"item_detail": "融合了聚灵珠和异界力量的法宝。",
		"item_rare": "epic", # 史诗
		"item_color": Color(0.7, 0.3, 0.9, 1), # 紫色
		"item_anime": "res://assets/animations/item_pickup_epic.tres"
	},
	"item_008": {
		"item_name": "异界矿石",
		"item_stack_max": 1,
		"item_type": "equip", # 装备
		"item_icon": "res://assets/icons/composite_equipment.png",
		"item_price": 500,
		"item_source": "击败敌人获取",
		"item_use_condition": "",
		"item_detail": "不属于这个世界的矿石，敲开后可以随机获得一些材料。",
		"item_rare": "epic", # 史诗
		"item_color": Color(0.7, 0.3, 0.9, 1), # 紫色
		"item_anime": "res://assets/animations/item_pickup_epic.tres"
	}
	# 更多物品可以添加到这里
}

# 物品效果处理函数
var item_function = {
	"item_001": "_on_item_001_picked_up",
	"item_002": "_on_item_002_picked_up",
	"item_003": "_on_item_003_picked_up",
	"item_004": "_on_item_004_picked_up"
}

# 可使用物品列表
# 注意：立即生效的物品（如野果）不应该在这里，它们在拾取时直接生效
var usable_items = {
	"item_008": true  # 异界矿石可以使用
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
	#if PC.pc_hp != PC.pc_max_hp:
		#PC.pc_hp += PC.pc_max_hp * 0.2
		## 防止生命值超过上限
		#if PC.pc_hp > PC.pc_max_hp:
			#PC.pc_hp = PC.pc_max_hp
		#return true # 表示成功拾取
	#else:
		#return false # 表示无法拾取
	PC.pc_hp += PC.pc_max_hp * 0.2
	# 防止生命值超过上限
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp

	
	return true # 表示成功拾取

# 力量之戒拾取函数
func _on_item_002_picked_up(player):
	# 将力量之戒添加到 Global 的玩家背包中
	if !Global.player_inventory.has("item_002"):
		Global.player_inventory["item_002"] = 1
	else:
		Global.player_inventory["item_002"] += 1
	return true # 表示成功拾取

# 聚灵石碎片拾取函数
func _on_item_003_picked_up(player):
	# 将聚灵石碎片添加到 Global 的玩家背包中
	if !Global.player_inventory.has("item_003"):
		Global.player_inventory["item_003"] = 1
	else:
		Global.player_inventory["item_003"] += 1
	return true # 表示成功拾取

func _on_item_004_picked_up(player):
	# 将九幽秘钥碎片添加到 Global 的玩家背包中
	if !Global.player_inventory.has("item_004"):
		Global.player_inventory["item_004"] = 1
	else:
		Global.player_inventory["item_004"] += 1
	return true # 表示成功拾取

# 使用物品（主要用于解锁配方）
func use_item(item_id: String, count: int = 1) -> Dictionary:
	var result = {
		"success": false,
		"message": "",
		"unlocked_recipes": []
	}
	
	# 检查物品是否存在
	if !items_data.has(item_id):
		result.message = "物品不存在"
		return result
	
	# 检查物品是否可使用
	if !usable_items.has(item_id) or !usable_items[item_id]:
		result.message = "该物品无法使用"
		return result
	
	# 检查背包中是否有足够的物品
	if !Global.player_inventory.has(item_id):
		result.message = "背包中没有该物品"
		return result
	
	if Global.player_inventory[item_id] < count:
		result.message = "物品数量不足"
		return result
	
	# 执行物品使用效果
	var use_success = _execute_item_use_effect(item_id, count)
	if !use_success:
		result.message = "物品使用失败"
		return result
	
	# 消耗物品（某些物品使用后不消耗，如装备）
	var item_type = get_item_property(item_id, "item_type")
	if item_type != "equip":  # 装备类物品不消耗
		Global.player_inventory[item_id] -= count
		if Global.player_inventory[item_id] <= 0:
			Global.player_inventory.erase(item_id)
	
	# 尝试解锁配方
	var unlocked_recipes = Global.unlock_recipes_by_item(item_id)
	result.unlocked_recipes = unlocked_recipes
	
	result.success = true
	result.message = "物品使用成功"
	if unlocked_recipes.size() > 0:
		result.message += "，解锁了新配方！"
	
	return result

# 执行物品使用效果
func _execute_item_use_effect(item_id: String, count: int) -> bool:
	match item_id:
		"item_008":
			return true
			
		_:
			printerr("未知的物品使用效果: ", item_id)
			return false

# 检查物品是否可使用
func can_use_item(item_id: String) -> bool:
	if !items_data.has(item_id):
		return false
	return usable_items.has(item_id) and usable_items[item_id]

# 获取物品使用描述
func get_item_use_description(item_id: String) -> String:
	match item_id:
		_:
			return "未知效果"

# 示例用法:
# func _ready():
# 	# 获取物品信息
# 	var ring_details = get_item_all_data("item_002")
# 	if ring_details:
# 		print("物品名称: ", ring_details.item_name)
# 		print("物品价格: ", ring_details.item_price)
#
# 	# 使用物品并解锁配方
# 	var use_result = use_item("item_003", 1)  # 使用聚灵石碎片
# 	if use_result.success:
# 		print("物品使用成功: ", use_result.message)
# 		if use_result.unlocked_recipes.size() > 0:
# 			print("解锁的配方: ", use_result.unlocked_recipes)
# 	else:
# 		print("物品使用失败: ", use_result.message)
#
# 	# 检查物品是否可使用
# 	if can_use_item("item_002"):
# 		print("力量之戒可以使用")
# 		print("使用描述: ", get_item_use_description("item_002"))
#
# 	# 查看已解锁的配方
# 	var unlocked_recipes = Global.get_unlocked_recipes()
# 	print("已解锁的配方: ", unlocked_recipes)
