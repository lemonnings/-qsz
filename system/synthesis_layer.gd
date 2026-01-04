extends CanvasLayer

# 物品合成管理器 - 专门负责合成逻辑

@export var shang_button: Button # 合成分类：上
@export var xia_button: Button # 合成分类：下
@export var yitai_button: Button # 合成分类：以太，诺姆入队后开启

@export var synthesis_detail: RichTextLabel # 合成信息具体详情
# 已持有：0
# 合成材料需求：
# 材料A  （ [color=#777]0[/color] / 1） 用#777表示没有满足的，这个要随着合成数量变动
# 材料B  （ [color=green]2[/color] / 1） 用green表示已经满足的，这个要随着合成数量变动
@export var synthesis_confirm_button: Button # 合成确认按钮
@export var synthesis_num: LineEdit # 合成数量输入框

@export var v_box_container: VBoxContainer # 选择了合成分类后，用来装载item_msg这些button的容器，按竖排排列
@export var item_msg: Button # 选择了合成分类后，该分类的具体合成物品的点击button

# 合成配方数据
var recipes_data = {
	"recipe_001": {
		"recipe_name": "玄露丹",
		"recipe_description": "使玄元（HP）修炼上限提升4阶",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xuanludan.png",
		"category": "shang", # 上部
		"required_items": [
			{"item_id": "item_018", "count": 6},
			{"item_id": "item_002", "count": 3}
		],
		"result_items": [
			{"item_id": "item_036", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_002": {
		"recipe_name": "化脉丹",
		"recipe_description": "使破虚（攻击）修炼上限提升4阶",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_018", "count": 6},
			{"item_id": "item_003", "count": 1}
		],
		"result_items": [
			{"item_id": "item_037", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_003": {
		"recipe_name": "汲灵丹",
		"recipe_description": "使化灵（灵气获取）修炼上限提升4阶",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_018", "count": 6},
			{"item_id": "item_023", "count": 1}
		],
		"result_items": [
			{"item_id": "item_038", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_004": {
		"recipe_name": "迅风丹",
		"recipe_description": "攻速方向上限+2",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_019", "count": 6},
			{"item_id": "item_024", "count": 1}
		],
		"result_items": [
			{"item_id": "item_039", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_005": {
		"recipe_name": "回春露",
		"recipe_description": "果实回复效果提升10%（最多10次）",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huichunlu.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_002", "count": 5}
		],
		"result_items": [
			{"item_id": "item_040", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_006": {
		"recipe_name": "仙枝",
		"recipe_description": "解锁武器-仙枝",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xianzhi.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_023", "count": 4}
		],
		"result_items": [
			{"item_id": "item_041", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_007": {
		"recipe_name": "柔水",
		"recipe_description": "解锁武器-柔水",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/roushui.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_003", "count": 4}
		],
		"result_items": [
			{"item_id": "item_042", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	},
	"recipe_009": {
		"recipe_name": "元水",
		"recipe_description": "水灵叶转化为3个元水",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanshui2.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_009", "count": 1}
		],
		"result_items": [
			{"item_id": "item_018", "min_count": 3, "max_count": 3, "probability": 1.0}
		]
	},
	"recipe_010": {
		"recipe_name": "元风",
		"recipe_description": "风灵草转化为3个元风",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanfeng2.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_010", "count": 1}
		],
		"result_items": [
			{"item_id": "item_019", "min_count": 3, "max_count": 3, "probability": 1.0}
		]
	},
	"recipe_011": {
		"recipe_name": "元火",
		"recipe_description": "火灵晶转化为3个元火",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanhuo2.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_015", "count": 1}
		],
		"result_items": [
			{"item_id": "item_022", "min_count": 3, "max_count": 3, "probability": 1.0}
		]
	},
	"recipe_012": {
		"recipe_name": "元雷",
		"recipe_description": "雷灵丝转化为3个元雷",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanlei2.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_017", "count": 1}
		],
		"result_items": [
			{"item_id": "item_020", "min_count": 3, "max_count": 3, "probability": 1.0}
		]
	},
	"recipe_013": {
		"recipe_name": "元土",
		"recipe_description": "土灵矿转化为3个元土",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuantu2.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_014", "count": 1}
		],
		"result_items": [
			{"item_id": "item_021", "min_count": 3, "max_count": 3, "probability": 1.0}
		]
	},
	"recipe_014": {
		"recipe_name": "下篇契纸",
		"recipe_description": "开启新的合成篇 下篇",
		"recipe_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/qizhi.png",
		"category": "shang",
		"required_items": [
			{"item_id": "item_011", "count": 10}
		],
		"result_items": [
			{"item_id": "item_043", "min_count": 1, "max_count": 1, "probability": 1.0}
		]
	}
}

# 当前选中的分类和配方
var current_category = "shang"
var current_recipe_id = ""
var current_craft_count = 1

# 界面状态变量
var transition_tween: Tween

func _ready():
	# 连接按钮信号
	if shang_button:
		shang_button.pressed.connect(_on_shang_button_pressed)
	if xia_button:
		xia_button.pressed.connect(_on_xia_button_pressed)
	if yitai_button:
		yitai_button.pressed.connect(_on_yitai_button_pressed)
	if synthesis_confirm_button:
		synthesis_confirm_button.pressed.connect(_on_synthesis_confirm_pressed)
	if synthesis_num:
		synthesis_num.text_changed.connect(_on_synthesis_num_changed)
	
	# 设置默认合成数量
	if synthesis_num:
		synthesis_num.text = "1"
	
	# 隐藏item_msg模板节点
	if item_msg:
		item_msg.visible = false
	
	# 默认选择qi分类
	_select_category("normal")

# 分类按钮点击事件
func _on_shang_button_pressed():
	_select_category("shang")

func _on_xia_button_pressed():
	_select_category("xia")

func _on_yitai_button_pressed():
	_select_category("yitai")

# 选择分类
func _select_category(category: String):
	current_category = category
	current_recipe_id = ""
	_update_recipe_list()
	_clear_synthesis_detail()

# 更新配方列表
func _update_recipe_list():
	if !v_box_container:
		return
	
	# 清空现有的按钮，但保留item_msg模板节点
	for child in v_box_container.get_children():
		# 跳过item_msg模板节点，只删除动态创建的按钮
		if child.name != "item":
			child.queue_free()
	
	# 获取当前分类的配方
	var category_recipes = _get_recipes_by_category(current_category)
	
	# 为每个配方创建按钮
	for recipe_id in category_recipes:
		var recipe = get_recipe_data(recipe_id)
		if recipe.is_empty():
			continue
		
		# 检查配方是否已解锁
		#if !Global.is_recipe_unlocked(recipe_id):
			#continue
		
		# 复制item_msg按钮样式
		var recipe_button = item_msg.duplicate()
		recipe_button.visible = true
		recipe_button.text = recipe.recipe_name
		
		# 设置配方图标
		if recipe.has("recipe_icon") and recipe.recipe_icon != "":
			var icon_texture = load(recipe.recipe_icon)
			if icon_texture:
				recipe_button.icon = icon_texture
		
		# 连接按钮信号
		recipe_button.pressed.connect(_on_recipe_button_pressed.bind(recipe_id))
		
		# 添加到容器
		v_box_container.add_child(recipe_button)

# 获取指定分类的配方
func _get_recipes_by_category(category: String) -> Array:
	var category_recipes = []
	for recipe_id in recipes_data.keys():
		var recipe = recipes_data[recipe_id]
		if recipe.has("category") and recipe.category == category:
			category_recipes.append(recipe_id)
	return category_recipes

# 配方按钮点击事件
func _on_recipe_button_pressed(recipe_id: String):
	current_recipe_id = recipe_id
	_update_synthesis_detail()

# 更新合成详情
func _update_synthesis_detail():
	if !synthesis_detail or current_recipe_id.is_empty():
		return
	
	var recipe = get_recipe_data(current_recipe_id)
	if recipe.is_empty():
		return
	
	# 获取合成数量
	var craft_count = current_craft_count
	
	# 构建详情文本
	var detail_text = ""
	
	# 配方名称和描述
	detail_text += recipe.recipe_description + "\n"
	
	# 已持有数量（显示第一个结果物品的持有数量）
	if recipe.result_items.size() > 0:
		var result_item_id = recipe.result_items[0].item_id
		var owned_count = Global.player_inventory.get(result_item_id, 0)
		detail_text += "\n已持有 " + str(owned_count) + "\n\n"
	
	# 合成材料需求
	detail_text += "合成材料需求\n"
	for required_item in recipe.required_items:
		var item_id = required_item.item_id
		var needed_count = required_item.count * craft_count
		var owned_count = Global.player_inventory.get(item_id, 0)
		var item_name = ItemManager.get_item_property(item_id, "item_name")
		if item_name == null:
			item_name = item_id
		
		# 根据是否满足需求设置颜色
		var color = "green" if owned_count >= needed_count else "#777"
		detail_text += item_name + "  （[color=" + color + "]" + str(owned_count) + "[/color] / " + str(needed_count) + "）\n"
	
	synthesis_detail.text = detail_text

# 清空合成详情
func _clear_synthesis_detail():
	if synthesis_detail:
		synthesis_detail.text = "请选择要合成的物品"

# 合成数量改变事件
func _on_synthesis_num_changed(new_text: String):
	var num = new_text.to_int()
	if num <= 0:
		num = 1
		if synthesis_num:
			synthesis_num.text = "1"
	current_craft_count = num
	_update_synthesis_detail()

# 合成确认按钮点击事件
func _on_synthesis_confirm_pressed():
	if current_recipe_id.is_empty():
		_show_message("请先选择要合成的物品")
		return
	
	var craft_result = craft_items(current_recipe_id, current_craft_count)
	if craft_result.success:
		_show_message("合成成功！获得物品：" + _format_obtained_items(craft_result.obtained_items))
		_update_synthesis_detail() # 更新显示
	else:
		_show_message("合成失败：" + craft_result.message)

# 格式化获得的物品信息
func _format_obtained_items(obtained_items: Array) -> String:
	var items_text = ""
	for i in range(obtained_items.size()):
		var item_info = obtained_items[i]
		var item_name = ItemManager.get_item_property(item_info.item_id, "item_name")
		if item_name == null:
			item_name = item_info.item_id
		items_text += item_name + " *" + str(item_info.count)
		if i < obtained_items.size() - 1:
			items_text += ", "
	return items_text

# 显示消息
func _show_message(message: String):
	var main_town = get_parent()
	main_town.tip.start_animation(message, 0.5)

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
	#if !Global.is_recipe_unlocked(recipe_id):
		#return false
	
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
	#if !Global.is_recipe_unlocked(recipe_id):
		#result.message = "配方尚未解锁"
		#return result
	
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


func _on_exit_2_pressed() -> void:
	# 保存游戏
	Global.save_game()
	Global.in_synthesis = false
	_transition_to_layer()

# 界面过渡动画
func _transition_to_layer():
	# 先淡出当前界面
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# 淡出当前层的所有子节点
	for child in get_children():
		if child.has_method("set_modulate"):
			transition_tween.tween_property(child, "modulate:a", 0.0, 0.125)
	
	# 等待淡出完成后处理退出逻辑
	transition_tween.tween_callback(_handle_exit).set_delay(0.125)

# 处理退出逻辑
func _handle_exit():
	# 调用main_town的_on_exit_pressed方法来处理dark_overlay
	var main_town = get_parent()
	if main_town and main_town.has_method("_on_exit_pressed"):
		main_town._on_exit_pressed()
	
	# 调用本地的_switch_layers来隐藏界面
	_switch_layers()

# 切换界面层
func _switch_layers():
	# 隐藏当前层
	visible = false
	# 重置所有子节点的透明度
	for child in get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 1.0
	
	# 保存游戏
	Global.save_game()
	
	# 恢复玩家控制和游戏状态
	PC.movement_disabled = false
	get_tree().paused = false
