extends Node

# 预加载掉落物场景，如果还没有，你需要创建一个
# 例如: res://scenes/dropped_item.tscn
# 这个场景应该有一个根节点 (比如 Area2D 或 RigidBody2D)
# 和一个 Sprite2D 来显示物品图标，以及一个 CollisionShape2D 用于拾取
var DroppedItemScene = preload("res://path/to/your/dropped_item.tscn") # 请替换为实际路径

func _ready():
	# 连接到全局信号
	if Global.has_signal("drop_out_item"):
		Global.drop_out_item.connect(_on_drop_out_item)
	else:
		printerr("Global signal 'drop_out_item' not found!")

func _on_drop_out_item(item_id: String, quantity: int, drop_position: Vector2):
	var item_data = itemManager.get_item_all_data(item_id)
	if not item_data:
		printerr("Failed to drop item: Unknown item_id '", item_id, "'")
		return

	for i in range(quantity):
		var dropped_item_instance = DroppedItemScene.instantiate()
		
		# 设置掉落物属性
		dropped_item_instance.item_id = item_id
		dropped_item_instance.global_position = drop_position
		
		# 设置图标 (假设你的 DroppedItemScene 有一个名为 Sprite2D 的子节点)
		if dropped_item_instance.has_node("Sprite2D"):
			var sprite = dropped_item_instance.get_node("Sprite2D")
			var icon_texture = load(item_data.item_icon)
			sprite.texture = icon_texture
		else:
			printerr("DroppedItemScene is missing a Sprite2D node!")

		# 添加到场景树 (通常添加到当前场景或一个专门的掉落物容器节点下)
		# 这里假设你希望将掉落物添加到当前主场景的直接子节点
		# 你可能需要根据你的场景结构调整 get_tree().current_scene
		var current_scene = get_tree().current_scene
		if current_scene:
			current_scene.add_child(dropped_item_instance)
		else:
			printerr("Could not find current scene to add dropped item.")
			return

		# 应用掉落动画 (短弧线)
		apply_drop_animation(dropped_item_instance)

func apply_drop_animation(item_node):
	# 简单的抛物线效果
	# 你可以使用 Tween 来实现更平滑的动画
	var tween = get_tree().create_tween()
	
	# 随机一个小的水平偏移，使掉落看起来更自然
	var random_x_offset = randf_range(-30.0, 30.0)
	var target_y_offset = randf_range(40.0, 60.0) # 掉落到地面的大致距离
	
	var initial_pos = item_node.global_position
	var control_offset = Vector2(random_x_offset / 2.0, -randf_range(30.0, 70.0)) # 控制点，用于形成弧线
	var final_pos = initial_pos + Vector2(random_x_offset, target_y_offset)
	
	# 使用 quadratic_bezier 插值模拟弧线
	# Godot 4.x Tween 属性插值
	# 主要掉落动画
	tween.tween_method(Callable(self, "_update_item_position_bezier").bind(item_node, initial_pos, initial_pos + control_offset, final_pos), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 第一次反弹
	# 计算第一次反弹的起始点 (即主要掉落的终点)
	var first_bounce_start_pos = final_pos
	# 第一次反弹的高度和水平偏移量可以小一些
	var first_bounce_height = -target_y_offset * 0.3 # 反弹为其初始掉落高度的30%
	var first_bounce_x_offset = random_x_offset * 0.2
	var first_bounce_control = Vector2(first_bounce_x_offset / 2.0, first_bounce_height * 1.5) # 控制点影响弧度
	var first_bounce_end_pos = Vector2(first_bounce_start_pos.x + first_bounce_x_offset, final_pos.y) # Y轴与初始落点一致
	
	tween.chain() # 链接到上一个tween动画之后执行
	tween.tween_method(Callable(self, "_update_item_position_bezier").bind(item_node, first_bounce_start_pos, first_bounce_start_pos + first_bounce_control, first_bounce_end_pos), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 第二次反弹 (更小幅)
	var second_bounce_start_pos = first_bounce_end_pos
	var second_bounce_height = -target_y_offset * 0.1 # 反弹为其初始掉落高度的10%
	var second_bounce_x_offset = first_bounce_x_offset * 0.3
	var second_bounce_control = Vector2(second_bounce_x_offset / 2.0, second_bounce_height * 1.5)
	var second_bounce_end_pos = Vector2(second_bounce_start_pos.x + second_bounce_x_offset, final_pos.y) # Y轴与初始落点一致

	tween.chain()
	tween.tween_method(Callable(self, "_update_item_position_bezier").bind(item_node, second_bounce_start_pos, second_bounce_start_pos + second_bounce_control, second_bounce_end_pos), 0.0, 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 可选：掉落后轻微缩放动画，模拟触地效果
	# tween.chain()
	# tween.tween_property(item_node, "scale", item_node.scale * Vector2(1.1, 0.8), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# tween.tween_property(item_node, "scale", item_node.scale, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# 这个方法被 Tween 调用，用于更新物品位置以形成弧线
func _update_item_position_bezier(t: float, node, start_pos: Vector2, control_pos: Vector2, end_pos: Vector2):
	if is_instance_valid(node):
		node.global_position = start_pos.quadratic_interpolate(control_pos, end_pos, t)

# 注意: 
# 1. 你需要在 Godot 编辑器中创建一个 `dropped_item.tscn` 场景。
#    这个场景至少需要一个 Sprite2D 来显示图标。
#    为了拾取，你可能还需要一个 Area2D 和 CollisionShape2D。
#    并在该场景的脚本中处理拾取逻辑 (例如 `_on_body_entered` 或 `_on_area_entered`)。
# 2. 将 `res://path/to/your/dropped_item.tscn` 替换为你的实际路径。
# 3. 确保 `ItemManager` (即之前的 `itemManager.gd`) 作为一个自动加载的单例 (Autoload singleton)
#    在项目中设置，并且其类名（或自动加载名称）为 `ItemManager`，以便 `get_node("/root/ItemManager")` 能正确找到它。
# 4. 这个脚本 (`item_drop_system.gd`) 也应该被添加到你的主场景中，或者作为一个自动加载的单例，
#    以便它可以接收 `drop_out_item` 信号。