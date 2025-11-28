extends Area2D

var item_id: String
var quantity: int

func _ready():
	# 连接 body_entered 信号
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# 检查碰撞的是否为玩家
	if body.is_in_group("player"):
		var item_type = ItemManager.get_item_property(item_id, "item_type")
		var can_pick_up := false
		if item_type == "immediate":
			var item_func_name = ItemManager.item_function.get(item_id)
			if item_func_name != null and ItemManager.has_method(item_func_name):
				can_pick_up = ItemManager.call(item_func_name, body, item_id)
			else:
				can_pick_up = true
		else:
			can_pick_up = ItemManager.on_item_picked_up(body, item_id)

		if can_pick_up:
			var tween = create_tween().set_parallel(true)
			tween.tween_property(self, "position:y", position.y - 50, 0.4)
			tween.tween_property(self, "modulate:a", 0, 0.4)
			await tween.finished
			queue_free()
