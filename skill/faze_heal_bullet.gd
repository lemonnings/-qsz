extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var target: Node2D
var damage: float = 0.0
var is_crit: bool = false
var speed: float = 120.0

func setup(p_target: Node2D, p_damage: float, p_is_crit: bool) -> void:
	target = p_target
	damage = p_damage
	is_crit = p_is_crit
	if _ensure_target():
		look_at(target.global_position)
	else:
		queue_free()

func _process(delta: float) -> void:
	if not _ensure_target():
		queue_free()
		return

	var target_offset = target.global_position - global_position
	if target_offset.length() < 20.0:
		_on_hit()
		return

	var direction = target_offset.normalized()
	rotation = direction.angle()
	global_position += direction * speed * delta
	
	if global_position.distance_to(target.global_position) < 20.0:
		_on_hit()

func _on_hit() -> void:
	if _is_valid_target(target):
		target.take_damage(int(damage), is_crit, false, "faze_heal")
	queue_free()

func _ensure_target() -> bool:
	if _is_valid_target(target):
		return true
	target = _find_nearest_target()
	return target != null

func _find_nearest_target() -> Node2D:
	var tree = get_tree()
	if tree == null:
		return null
	var targets: Array = []
	targets.append_array(tree.get_nodes_in_group("enemies"))
	targets.append_array(tree.get_nodes_in_group("boss"))
	var checked := {}
	var nearest_target: Node2D = null
	var min_dist = INF
	
	for candidate in targets:
		if not _is_valid_target(candidate):
			continue
		var candidate_id = candidate.get_instance_id()
		if checked.has(candidate_id):
			continue
		checked[candidate_id] = true
		var target_node := candidate as Node2D
		var dist = global_position.distance_to(target_node.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_target = target_node

	return nearest_target

func _is_valid_target(candidate: Node) -> bool:
	if not is_instance_valid(candidate):
		return false
	if not (candidate is Node2D):
		return false
	if not candidate.has_method("take_damage"):
		return false
	if candidate.get("is_dead") == true:
		return false
	return candidate.is_in_group("enemies") or candidate.is_in_group("boss")
