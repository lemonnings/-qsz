extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var target: Node2D
var damage: float
var is_crit: bool
var speed: float = 240.0

func setup(p_target: Node2D, p_damage: float, p_is_crit: bool) -> void:
	target = p_target
	damage = p_damage
	is_crit = p_is_crit
	look_at(target.global_position)

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
		
	var direction = (target.global_position - global_position).normalized()
	rotation = direction.angle()
	global_position += direction * speed * delta
	
	if global_position.distance_to(target.global_position) < 20.0:
		_on_hit()

func _on_hit() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(int(damage), is_crit, false, "faze_heal")
	queue_free()
