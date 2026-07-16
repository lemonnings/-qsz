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
var hit_targets: Dictionary = {}
var pierce_hit_count: int = 0
var shared_wave_hit_counts: Dictionary = {}
var shared_wave_hit_limit: int = 0
const PIERCE_DAMAGE_DECAY: float = 0.70

func _ready() -> void:
	CharacterEffects.include_enemy_collision_mask(self)
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	remove_from_group("bullet")
	if sprite:
		sprite.play("default")
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func setup_barrage_bullet(pos: Vector2, dir: Vector2, p_damage: float, options: Dictionary = {}) -> void:
	global_position = pos
	start_position = pos
	direction = dir.normalized()
	damage = p_damage
	shared_wave_hit_counts = options.get("shared_wave_hit_counts", {})
	shared_wave_hit_limit = int(options.get("shared_wave_hit_limit", 0))
	rotation = direction.angle()

func _process(delta: float) -> void:
	if Global.in_menu or Global.in_town:
		if sprite:
			sprite.pause()
		return
	if sprite and not sprite.is_playing():
		sprite.play("default")
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
		ObjectPool.recycle(self )

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemies"):
		return
	var enemy_id := area.get_instance_id()
	if hit_targets.has(enemy_id):
		return
	hit_targets[enemy_id] = true
	if shared_wave_hit_limit > 0:
		var shared_hit_count: int = int(shared_wave_hit_counts.get(enemy_id, 0))
		if shared_hit_count >= shared_wave_hit_limit:
			return
		shared_wave_hit_counts[enemy_id] = shared_hit_count + 1
	var is_crit = false
	var final_damage = damage * pow(PIERCE_DAMAGE_DECAY, pierce_hit_count)
	if randf() < PC.crit_chance:
		is_crit = true
		final_damage *= PC.crit_damage_multi
	if area.has_method("take_damage"):
		area.take_damage(int(final_damage), is_crit, false, "faze_rain")
	pierce_hit_count += 1

## 对象池重置：清除状态供复用
func reset_for_pool() -> void:
	damage = 0.0
	direction = Vector2.RIGHT
	start_position = Vector2.ZERO
	traveled_distance = 0.0
	has_hit = false
	hit_targets = {}
	pierce_hit_count = 0
	shared_wave_hit_counts = {}
	shared_wave_hit_limit = 0
	modulate.a = 1.0
	rotation = 0.0
	global_position = Vector2.ZERO
	if sprite:
		sprite.play("default")
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
