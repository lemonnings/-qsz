extends Node

var DroppedItemScene = preload("res://Scenes/global/drop_normal.tscn") # 请替换为实际路径

func _ready():
	# 连接到全局信号
	if Global.has_signal("drop_out_item"):
		Global.drop_out_item.connect(_on_drop_out_item)
	else:
		printerr("Global signal 'drop_out_item' not found!")

func _on_drop_out_item(item_id: String, quantity: int, drop_position: Vector2):
	var item_data = ItemManager.get_item_all_data(item_id)
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
	var random_x_offset = randf_range(-25.0, 25.0)
	#var target_y_offset = randf_range(40.0, 60.0) # 掉落到地面的大致距离
	var target_y_offset = 0
	
	var initial_pos = item_node.global_position
	var control_offset = Vector2(random_x_offset / 2.0, -randf_range(30.0, 70.0)) # 控制点，用于形成弧线
	var final_pos = initial_pos + Vector2(random_x_offset, target_y_offset)
	
	# 使用 quadratic_bezier 插值模拟弧线
	# Godot 4.x Tween 属性插值
	# 主要掉落动画
	tween.tween_method(Callable(self, "_update_item_position_bezier").bind(item_node, initial_pos, initial_pos + control_offset, final_pos), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# 这个方法被 Tween 调用，用于更新物品位置以形成弧线
func _update_item_position_bezier(t: float, node, start_pos: Vector2, control_pos: Vector2, end_pos: Vector2):
	if not is_instance_valid(node):
		return

	var one_minus_t = 1.0 - t
	var x = one_minus_t * one_minus_t * start_pos.x + 2.0 * one_minus_t * t * control_pos.x + t * t * end_pos.x
	var y = one_minus_t * one_minus_t * start_pos.y + 2.0 * one_minus_t * t * control_pos.y + t * t * end_pos.y

	node.global_position = Vector2(x, y)
