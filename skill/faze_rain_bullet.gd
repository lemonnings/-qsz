extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var damage: float = 0.0
var speed: float = 320.0
var range_val: float = 320.0
var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var traveled_distance: float = 0.0
var has_hit: bool = false

func _ready() -> void:
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	remove_from_group("bullet")
	if sprite:
		sprite.play("default")
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func setup_barrage_bullet(pos: Vector2, dir: Vector2, p_damage: float) -> void:
	global_position = pos
	start_position = pos
	direction = dir.normalized()
	damage = p_damage
	rotation = direction.angle()

func _process(delta: float) -> void:
	position += direction * speed * delta
	traveled_distance = start_position.distance_to(global_position)
	var fade_start_distance = range_val * 0.9
	if traveled_distance >= fade_start_distance:
		var fade_distance = range_val - fade_start_distance
		var fade_ratio = 0.0
		if fade_distance > 0.0:
			fade_ratio = (traveled_distance - fade_start_distance) / fade_distance
		if fade_ratio > 1.0:
			fade_ratio = 1.0
		modulate.a = 1.0 - fade_ratio
	if traveled_distance >= range_val:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return
	if not area.is_in_group("enemies"):
		return
	has_hit = true
	var is_crit = false
	var final_damage = damage
	if randf() < PC.crit_chance:
		is_crit = true
		final_damage *= PC.crit_damage_multi
	if area.has_method("take_damage"):
		area.take_damage(int(final_damage), is_crit, false, "faze_rain")
	queue_free()
