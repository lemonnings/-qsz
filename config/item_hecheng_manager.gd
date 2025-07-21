extends Node

# 物品合成管理器 - 专门负责合成逻辑
# 配方数据结构说明:
# recipe_id: 配方唯一ID
# required_items: 需求物品列表 [{"item_id": String, "count": int}]
# result_items: 合成结果列表 [{"item_id": String, "min_count": int, "max_count": int, "probability": float}]
# recipe_name: 配方名称
# recipe_description: 配方描述

# 合成配方数据
var recipes_data = {
	"recipe_001": {
		"recipe_name": "贤者之石",
		"recipe_description": "使用贤者之石碎片合成完整的贤者之石",
		"required_items": [
			{"item_id": "item_003", "count": 10}
		],
		"result_items": [
			{"item_id": "item_005", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_002": {
		"recipe_name": "九幽秘钥",
		"recipe_description": "使用九幽秘钥碎片合成完整的九幽秘钥",
		"required_items": [
			{"item_id": "item_004", "count": 10}
		],
		"result_items": [
			{"item_id": "item_006", "min_count": 1, "max_count": 1, "probability": 0.8},
			{"item_id": "item_004", "min_count": 1, "max_count": 3, "probability": 0.2}
		]
	},
	"recipe_003": {
		"recipe_name": "强化野果",
		"recipe_description": "使用多个野果合成强化野果",
		"required_items": [
			{"item_id": "item_001", "count": 5}
		],
		"result_items": [
			{"item_id": "item_007", "min_count": 1, "max_count": 2, "probability": 0.7},
			{"item_id": "item_001", "min_count": 1, "max_count": 1, "probability": 0.3}
		]
	},
	"recipe_004": {
		"recipe_name": "复合装备",
		"recipe_description": "使用力量之戒和贤者之石碎片合成复合装备",
		"required_items": [
			{"item_id": "item_002", "count": 1},
			{"item_id": "item_003", "count": 3}
		],
		"result_items": [
			{"item_id": "item_008", "min_count": 1, "max_count": 1, "probability": 0.6},
			{"item_id": "item_002", "min_count": 1, "max_count": 1, "probability": 0.4}
		]
	}
	# 更多配方可以添加到这里
}

# 获取配方信息
func get_recipe_data(recipe_id: String) -> Dictionary:
	if recipes_data.has(recipe_id):
		return recipes_data[recipe_id]
	else:
		printerr("Recipe not found: ", recipe_id)
		return {}

# 检查是否有足够的材料进行合成
func can_craft(recipe_id: String, craft_count: int = 1) -> bool:
	var recipe = get_recipe_data(recipe_id)
	if recipe.is_empty():
		return false
	
	# 检查配方是否已解锁
	if !Global.is_recipe_unlocked(recipe_id):
		return false
	
	# 检查每个需求物品是否足够
	for required_item in recipe.required_items:
		var item_id = required_item.item_id
		var needed_count = required_item.count * craft_count
		
		# 检查玩家背包中是否有足够的物品
		if !Global.player_inventory.has(item_id):
			return false
		if Global.player_inventory[item_id] < needed_count:
			return false
	
	return true

# 执行合成操作
func craft_items(recipe_id: String, craft_count: int = 1) -> Dictionary:
	var result = {
		"success": false,
		"message": "",
		"obtained_items": []
	}
	
	# 检查配方是否存在
	var recipe = get_recipe_data(recipe_id)
	if recipe.is_empty():
		result.message = "配方不存在"
		return result
	
	# 检查配方是否已解锁
	if !Global.is_recipe_unlocked(recipe_id):
		result.message = "配方尚未解锁"
		return result
	
	# 检查材料是否足够
	if !can_craft(recipe_id, craft_count):
		result.message = "材料不足"
		return result
	
	# 消耗材料
	for required_item in recipe.required_items:
		var item_id = required_item.item_id
		var consume_count = required_item.count * craft_count
		Global.player_inventory[item_id] -= consume_count
		
		# 如果物品数量为0，从背包中移除
		if Global.player_inventory[item_id] <= 0:
			Global.player_inventory.erase(item_id)
	
	# 执行合成并获得物品
	var total_obtained_items = []
	for i in range(craft_count):
		var obtained_items = _process_craft_results(recipe.result_items)
		total_obtained_items.append_array(obtained_items)
	
	# 将获得的物品添加到背包
	for item_info in total_obtained_items:
		var item_id = item_info.item_id
		var count = item_info.count
		
		if !Global.player_inventory.has(item_id):
			Global.player_inventory[item_id] = count
		else:
			Global.player_inventory[item_id] += count
	
	result.success = true
	result.message = "合成成功"
	result.obtained_items = total_obtained_items
	return result

# 处理合成结果（包含概率和随机数量）
func _process_craft_results(result_items: Array) -> Array:
	var obtained_items = []
	
	for result_item in result_items:
		var probability = result_item.probability
		
		# 根据概率判断是否获得该物品
		if randf() <= probability:
			var min_count = result_item.min_count
			var max_count = result_item.max_count
			var actual_count = randi_range(min_count, max_count)
			
			obtained_items.append({
				"item_id": result_item.item_id,
				"count": actual_count
			})
	
	return obtained_items

# 获取所有可用的配方列表
func get_all_recipes() -> Array:
	return recipes_data.keys()

# 获取玩家可以制作的配方列表（已解锁且材料充足）
func get_craftable_recipes() -> Array:
	var craftable = []
	for recipe_id in recipes_data.keys():
		if can_craft(recipe_id):
			craftable.append(recipe_id)
	return craftable

# 获取已解锁的配方列表（不考虑材料是否充足）
func get_unlocked_recipes() -> Array:
	var unlocked = []
	for recipe_id in recipes_data.keys():
		if Global.is_recipe_unlocked(recipe_id):
			unlocked.append(recipe_id)
	return unlocked

# 示例用法:
# func _ready():
# 	# 检查配方解锁状态
# 	print("贤者之石配方是否解锁: ", Global.is_recipe_unlocked("recipe_001"))
# 	
# 	# 获取已解锁的配方
# 	var unlocked_recipes = get_unlocked_recipes()
# 	print("已解锁的配方: ", unlocked_recipes)
# 	
# 	# 获取可制作的配方（已解锁且材料充足）
# 	var craftable_recipes = get_craftable_recipes()
# 	print("可制作的配方: ", craftable_recipes)
# 	
# 	# 尝试合成贤者之石
# 	var craft_result = craft_items("recipe_001", 1)
# 	if craft_result.success:
# 		print("合成成功！获得物品: ", craft_result.obtained_items)
# 	else:
# 		print("合成失败: ", craft_result.message)
# 		# 可能的失败原因：配方不存在、配方未解锁、材料不足
