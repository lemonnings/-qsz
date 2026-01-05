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
		
		# 整体缩小到四分之一
		dropped_item_instance.scale = Vector2(0.2, 0.2)
		
		# 设置掉落物属性
		dropped_item_instance.item_id = item_id
		# 多个物品时添加初始偏移，避免掉到同一位置
		var initial_offset = Vector2.ZERO
		if quantity > 1:
			initial_offset = Vector2(randf_range(-15.0, 15.0), randf_range(-10.0, 10.0))
		dropped_item_instance.global_position = drop_position + initial_offset
		
		# 设置图标
		if dropped_item_instance.has_node("Sprite2D"):
			var sprite = dropped_item_instance.get_node("Sprite2D")
			var icon_texture = load(item_data.item_icon)
			sprite.texture = icon_texture
			
		# 设置物品名称和颜色
		if dropped_item_instance.has_node("ItemNameLabel"):
			var name_label = dropped_item_instance.get_node("ItemNameLabel")
			name_label.text = item_data.item_name
			name_label.modulate = item_data.item_color
			
		# 添加到场景树 (通常添加到当前场景或一个专门的掉落物容器节点下)
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
	var tween = get_tree().create_tween()
	
	# 随机方向和幅度，增加掉落随机性
	var random_angle = randf_range(0, TAU) # 全方向随机 (0 ~ 2π)
	var random_distance = randf_range(20.0, 50.0) # 随机掉落距离
	var random_x_offset = cos(random_angle) * random_distance
	var random_y_offset = sin(random_angle) * random_distance * 0.5 # Y方向幅度稍小
	
	# 随机弧线高度
	var arc_height = randf_range(35.0, 80.0)
	
	var initial_pos = item_node.global_position
	var control_offset = Vector2(random_x_offset / 2.0, -arc_height) # 控制点，用于形成弧线
	var final_pos = initial_pos + Vector2(random_x_offset, random_y_offset)
	
	# 限制掉落范围在场景边界内
	final_pos = _clamp_position_to_scene_bounds(final_pos)
	
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

func _clamp_position_to_scene_bounds(pos: Vector2) -> Vector2:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return pos
		
	# 检查是否为 battle_forest 场景
	# 可以通过场景文件名或名称来判断，这里假设包含 battle_forest 字符串
	if "battle_forest" in current_scene.scene_file_path or current_scene.name == "BattleForest":
		var min_x = -275.0
		var max_x = 275.0
		var min_y = 110.0
		var max_y = 310.0
		
		pos.x = clamp(pos.x, min_x, max_x)
		pos.y = clamp(pos.y, min_y, max_y)
		
	return pos
