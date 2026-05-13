extends Area2D

## 升级动画效果：播放完毕后渐变消失

@export var sprite: AnimatedSprite2D

func _ready():
	z_index = 2 # 比角色高
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D2")
	if sprite:
		sprite.stop()
		sprite.visible = true
		sprite.frame = 0
		sprite.play("default")
		sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
	else:
		# 无动画时延迟销毁
		await get_tree().create_timer(0.33).timeout
		queue_free()

func _on_animation_finished():
	"""动画播完后0.1秒渐变消失"""
	var tween = create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)
