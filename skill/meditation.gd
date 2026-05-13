extends Area2D

## 冒想：咏唱期间在自身显示的视觉效果（图层比角色低）

@export var sprite: AnimatedSprite2D

func _ready():
	z_index = -1 # 图层比角色低
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D2")
	if sprite:
		sprite.stop()
		sprite.visible = false

func start():
	"""开始播放冒想动画"""
	if sprite:
		sprite.visible = true
		sprite.frame = 0
		sprite.play("default")
