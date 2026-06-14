extends Node2D

const CORRUPTED_ELITE_CONTROLLER_SCRIPT: Script = preload("res://Script/system/corrupted_elite_controller.gd")
const FROG_ATTACK_SCRIPT: Script = preload("res://Script/skill/frog_attack.gd")
const SLIME_BLUE_SCENE: PackedScene = preload("res://Scenes/moster/slime_blue.tscn")
const ARMOR_STONE_SCENE: PackedScene = preload("res://Scenes/moster/armor_stone.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	await _check_radial_skill("slime_blue", SLIME_BLUE_SCENE, errors)
	await _check_radial_skill("smile_blue", SLIME_BLUE_SCENE, errors)
	await _check_radial_skill("armor_stone", ARMOR_STONE_SCENE, errors)
	if errors.is_empty():
		print("corrupted_elite_radial_skill_test passed")
		get_tree().quit(0)
		return
	for error in errors:
		push_error(error)
	get_tree().quit(1)


func _check_radial_skill(monster_id: String, monster_scene: PackedScene, errors: Array[String]) -> void:
	_clear_test_projectiles()
	var monster := monster_scene.instantiate() as MonsterBase
	if monster == null:
		errors.append("%s failed to instantiate MonsterBase" % monster_id)
		return
	monster.global_position = Vector2(20.0, 30.0)
	monster.set_meta("is_corrupted_elite", true)
	monster.set_meta("corrupted_elite_monster_id", monster_id)
	monster.add_to_group("core_corrupted_elite")
	add_child(monster)
	await get_tree().process_frame

	var controller := CORRUPTED_ELITE_CONTROLLER_SCRIPT.new() as CorruptedEliteController
	controller.setup(monster, monster_id)
	monster.add_child(controller)
	await get_tree().process_frame
	controller.call("_use_periodic_skill")

	var projectiles := _collect_projectiles()
	if projectiles.size() != 8:
		errors.append("%s created %d radial bullets, expected 8" % [monster_id, projectiles.size()])
	else:
		_check_projectile_directions(monster_id, projectiles, errors)
		_check_projectile_values(monster_id, monster, projectiles, errors)

	monster.queue_free()
	_clear_test_projectiles()
	await get_tree().process_frame


func _collect_projectiles() -> Array[Area2D]:
	var result: Array[Area2D] = []
	for child in get_children():
		if child is Area2D and child.get_script() == FROG_ATTACK_SCRIPT:
			result.append(child as Area2D)
	return result


func _clear_test_projectiles() -> void:
	for projectile in _collect_projectiles():
		projectile.queue_free()


func _check_projectile_directions(monster_id: String, projectiles: Array[Area2D], errors: Array[String]) -> void:
	for i in range(8):
		var expected := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		if not _has_direction(projectiles, expected):
			errors.append("%s missing radial bullet direction %s" % [monster_id, str(expected)])


func _has_direction(projectiles: Array[Area2D], expected: Vector2) -> bool:
	for projectile in projectiles:
		var direction: Vector2 = projectile.get("direction")
		if direction.distance_to(expected) <= 0.01:
			return true
	return false


func _check_projectile_values(monster_id: String, monster: MonsterBase, projectiles: Array[Area2D], errors: Array[String]) -> void:
	var expected_atk := float(monster.get("atk"))
	for projectile in projectiles:
		if projectile.global_position.distance_to(monster.global_position) > 0.01:
			errors.append("%s radial bullet spawned at %s, expected %s" % [monster_id, str(projectile.global_position), str(monster.global_position)])
		var projectile_atk := float(projectile.get("atk"))
		if not is_equal_approx(projectile_atk, expected_atk):
			errors.append("%s radial bullet atk %s, expected %s" % [monster_id, str(projectile_atk), str(expected_atk)])
