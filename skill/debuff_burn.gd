extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision: CollisionShape2D

var _elapsed: float = 0.0
var _duration: float = 0.6
var _is_active: bool = false
var _is_persistent: bool = false
const PERSISTENT_ANIMATION_SPEED_SCALE: float = 0.6

func _ready() -> void:
	set_process(false)

## 每次从对象池取出后调用，启动燃烧特效
func setup() -> void:
	_is_persistent = false
	_elapsed = 0.0
	_is_active = true
	monitoring = true
	monitorable = true
	modulate.a = 0.5
	z_index = 0
	if sprite:
		sprite.speed_scale = 1.0
		sprite.frame = 0
		sprite.play("default")
	if collision:
		collision.set_deferred("disabled", false)
	set_process(true)

## 作为怪物身上的持续灼烧状态特效使用，不参与碰撞和对象池回收
func setup_persistent() -> void:
	_is_persistent = true
	_elapsed = 0.0
	_is_active = false
	monitoring = false
	monitorable = false
	position = Vector2.ZERO
	modulate.a = 0.3
	z_index = 50
	if sprite:
		sprite.speed_scale = PERSISTENT_ANIMATION_SPEED_SCALE
		sprite.frame = 0
		sprite.play("default")
		if not sprite.animation_finished.is_connected(_on_persistent_animation_finished):
			sprite.animation_finished.connect(_on_persistent_animation_finished)
	if collision:
		collision.set_deferred("disabled", true)
	set_process(false)

func _process(delta: float) -> void:
	if _is_persistent:
		return
	if not _is_active:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_is_active = false
		ObjectPool.recycle(self )

func _on_persistent_animation_finished() -> void:
	if _is_persistent and sprite:
		sprite.play("default")

## 对象池重置：清除状态供复用
func reset_for_pool() -> void:
	_is_persistent = false
	_elapsed = 0.0
	_is_active = false
	monitoring = true
	monitorable = true
	modulate.a = 0.5
	z_index = 0
	scale = Vector2.ONE
	global_position = Vector2.ZERO
	set_process(false)
	if sprite:
		sprite.speed_scale = 1.0
		sprite.stop()
		sprite.frame = 0
	if collision:
		collision.set_deferred("disabled", true)
