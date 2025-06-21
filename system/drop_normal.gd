extends Area2D

var item_id: String
var quantity: int

func _ready():
	# 连接 body_entered 信号
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# 检查碰撞的是否为玩家
	if body.is_in_group("player"):
		var item_func_name = ItemManager.item_function.get(item_id)

		# 检查是否有对应的处理函数
		if ItemManager.has_method(item_func_name):
			# 调用函数并传递玩家节点作为参数
			var can_pick_up = ItemManager.call(item_func_name, body)
			
			# 如果函数返回true，表示可以拾取
			if can_pick_up:
				# 创建渐隐和向上飘动动画
				var tween = create_tween().set_parallel(true)
				tween.tween_property(self, "position:y", position.y - 50, 0.5) # 向上飘动50个像素
				tween.tween_property(self, "modulate:a", 0, 0.5)
				await tween.finished
				queue_free() # 动画结束后销毁物品
