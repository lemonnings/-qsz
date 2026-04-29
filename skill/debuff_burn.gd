extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision: CollisionShape2D

var _elapsed: float = 0.0
var _duration: float = 0.6
var _is_active: bool = false

func _ready() -> void:
	set_process(false)

## 每次从对象池取出后调用，启动燃烧特效
func setup() -> void:
	_elapsed = 0.0
	_is_active = true
	modulate.a = 1.0
	if sprite:
		sprite.frame = 0
		sprite.play("default")
	if collision:
		collision.set_deferred("disabled", false)
	set_process(true)

func _process(delta: float) -> void:
	if not _is_active:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_is_active = false
		ObjectPool.recycle(self )

## 对象池重置：清除状态供复用
func reset_for_pool() -> void:
	_elapsed = 0.0
	_is_active = false
	modulate.a = 1.0
	scale = Vector2.ONE
	global_position = Vector2.ZERO
	set_process(false)
	if sprite:
		sprite.stop()
		sprite.frame = 0
	if collision:
		collision.set_deferred("disabled", true)
