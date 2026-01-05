extends Node

# 测试合成系统的脚本
# 在游戏开始时运行此脚本来解锁配方和添加测试物品

func _ready():
	# 等待一帧确保Global已经初始化
	await get_tree().process_frame
	setup_test_data()

func setup_test_data():
	#print("设置合成系统测试数据...")
	pass
