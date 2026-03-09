extends Area2D

@export var sprite : AnimatedSprite2D
@export var collision : CollisionShape2D

func _ready() -> void:
	sprite.play("default")
	collision.disabled = false
	await get_tree().create_timer(0.6).timeout
	queue_free()
