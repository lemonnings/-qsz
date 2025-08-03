extends Node

# 测试合成系统的脚本
# 在游戏开始时运行此脚本来解锁配方和添加测试物品

func _ready():
	# 等待一帧确保Global已经初始化
	await get_tree().process_frame
	setup_test_data()

func setup_test_data():
	print("设置合成系统测试数据...")
	
	# 解锁所有配方用于测试
	Global.unlock_recipe("recipe_001")  # 贤者之石
	Global.unlock_recipe("recipe_002")  # 九幽秘钥
	Global.unlock_recipe("recipe_003")  # 强化野果
	Global.unlock_recipe("recipe_004")  # 复合装备
	
	# 添加测试物品到背包
	Global.player_inventory["item_001"] = 10  # 野果
	Global.player_inventory["item_002"] = 5   # 力量之戒
	Global.player_inventory["item_003"] = 3   # 贤者之石碎片
	Global.player_inventory["item_004"] = 15  # 九幽秘钥碎片
	
	print("测试数据设置完成！")
	print("已解锁配方：", Global.recipe_unlock_progress)
	print("背包物品：", Global.player_inventory)