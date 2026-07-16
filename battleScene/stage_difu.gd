extends "res://Script/battleScene/base_stage.gd"

@export var youling_scene: PackedScene
@export var paper_scene: PackedScene
@export var lantern_scene: PackedScene
@export var ghost_scene: PackedScene

const GHOST_MAX: int = 3
const DIFU_MAGIC_CORE_IDS := ["item_097", "item_098", "item_099", "item_100", "item_101"]

const DIFU_TOP_Y: float = -10.0
const DIFU_TOP_X_MIN: float = -100.0
const DIFU_TOP_X_MAX: float = 100.0
const DIFU_LEFT_X: float = -300.0
const DIFU_LEFT_Y_MIN: float = 175.0
const DIFU_LEFT_Y_MAX: float = 750.0
const DIFU_RIGHT_X: float = 300.0
const DIFU_RIGHT_Y_MIN: float = 100.0
const DIFU_RIGHT_Y_MAX: float = 750.0
const DIFU_BOTTOM_Y: float = 750.0
const DIFU_BOTTOM_X_MIN: float = -275.0
const DIFU_BOTTOM_X_MAX: float = 275.0

var ghost_alive: int = 0
var difu_magic_core_drop_count: int = 0


func _setup_stage_config() -> void:
	STAGE_ID = "difu"
	SPAWN_INTERVAL_SECONDS = 3.85
	INITIAL_MONSTER_LIMIT = 30
	WAVE_SPAWN_INCREASE_STEP = 11
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.3
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 5.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.3
	LOW_POPULATION_FORCE_WAVE_MIN_TIME_LEFT = 1.25
	LATE_GAME_TIME_THRESHOLD = 180.0
	LATE_GAME_LOW_POPULATION_RATIO = 0.35
	BASIC_TYPES = ["youling", "paper", "lantern"]
	OTHER_TYPE_PER_WAVE_MAX = 1
	OTHER_TYPE_TOTAL_MAX = 3
	ELITE_MAX = 3
	stage_spawn_pool = [
		{"type": "youling", "weight": 300, "blocked_early": false},
		{"type": "paper", "weight": 300, "blocked_early": false},
		{"type": "lantern", "weight": 300, "blocked_early": false},
		{"type": "ghost", "weight": 100, "blocked_early": false}
	]


func _get_corrupted_elite_spawn_data(spawn_type: String) -> Dictionary:
	match spawn_type:
		"youling":
			return {"scene": youling_scene, "monster_id": "youling"}
		"paper":
			return {"scene": paper_scene, "monster_id": "paper"}
		"lantern":
			return {"scene": lantern_scene, "monster_id": "lantern"}
		"ghost":
			return {"scene": ghost_scene, "monster_id": "ghost"}
		_:
			return {}


func _can_choose_spawn_entry(entry: Dictionary, wave_other_type_counts: Dictionary) -> bool:
	var spawn_type := str(entry.get("type", ""))
	match spawn_type:
		"youling":
			return youling_scene != null
		"paper":
			return paper_scene != null
		"lantern":
			return lantern_scene != null
		"ghost":
			var planned_ghost_count := int(wave_other_type_counts.get("ghost", 0))
			return ghost_scene != null and ghost_alive + planned_ghost_count < GHOST_MAX
		_:
			return false


func _ready() -> void:
	super()
	$Player.camera.zoom = Vector2(2.7, 2.7)
	$Player.min_zoom = 2.5
	GU.reset_kill_count()
	Global.emit_signal("stage_bgm", "cave")


func _get_boss_position() -> Vector2:
	return Vector2(0.0, 225.0)


func _on_warning_finished() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree() or boss_robot_scene == null:
		return

	var boss_node := boss_robot_scene.instantiate()
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return

	boss_node.position = _get_boss_position()
	boss_node.modulate.a = 0.0
	get_tree().current_scene.add_child(boss_node)
	_apply_mobile_boss_balance(boss_node)
	var boss_tween := boss_node.create_tween()
	boss_tween.tween_property(boss_node, "modulate:a", 1.0, 0.8)
	_clear_non_boss_enemies()


func _spawn_wave() -> void:
	await _spawn_weighted_wave(Callable(self, "_spawn_single_by_type"))


func _spawn_single_by_type(spawn_type: String) -> void:
	match spawn_type:
		"youling":
			_spawn_basic_monster(youling_scene, _get_inner_spawn_position())
		"paper":
			_spawn_basic_monster(paper_scene, _get_inner_spawn_position())
		"lantern":
			_spawn_basic_monster(lantern_scene, _get_inner_spawn_position())
		"ghost":
			_spawn_ghost()


func _spawn_basic_monster(scene: PackedScene, spawn_position: Vector2) -> void:
	if not is_inside_tree() or get_tree().current_scene == null or scene == null:
		return
	var monster_node = scene.instantiate()
	if monster_node.get("move_direction") != null:
		monster_node.set("move_direction", 2)
	monster_node.position = spawn_position
	get_tree().current_scene.add_child(monster_node)
	_register_spawned_monster(monster_node, false)


func _spawn_ghost() -> void:
	if not is_inside_tree() or get_tree().current_scene == null or ghost_scene == null:
		other_type_alive = max(0, other_type_alive - 1)
		return
	if ghost_alive >= GHOST_MAX:
		other_type_alive = max(0, other_type_alive - 1)
		_spawn_basic_monster(youling_scene, _get_inner_spawn_position())
		return
	var ghost_node = ghost_scene.instantiate()
	ghost_node.position = _get_outer_spawn_position()
	get_tree().current_scene.add_child(ghost_node)
	ghost_alive += 1
	_register_spawned_monster(ghost_node, true, true, true)
	ghost_node.tree_exiting.connect(Callable(self, "_on_ghost_tree_exiting"))


func _get_inner_spawn_position() -> Vector2:
	return _get_spawn_position()


func _get_outer_spawn_position() -> Vector2:
	return _get_spawn_position()


func _get_spawn_position() -> Vector2:
	return _get_player_spawn_safe_position(
		_get_raw_spawn_position(),
		Callable(self, "_get_raw_spawn_position")
	)


func _get_raw_spawn_position() -> Vector2:
	var spawn_edge := randi_range(0, 3)
	var fallback_position := Vector2.ZERO
	match spawn_edge:
		0:
			fallback_position = Vector2(randf_range(DIFU_TOP_X_MIN, DIFU_TOP_X_MAX), DIFU_TOP_Y)
		1:
			fallback_position = Vector2(randf_range(DIFU_BOTTOM_X_MIN, DIFU_BOTTOM_X_MAX), DIFU_BOTTOM_Y)
		2:
			fallback_position = Vector2(DIFU_LEFT_X, randf_range(DIFU_LEFT_Y_MIN, DIFU_LEFT_Y_MAX))
		_:
			fallback_position = Vector2(DIFU_RIGHT_X, randf_range(DIFU_RIGHT_Y_MIN, DIFU_RIGHT_Y_MAX))
	return _get_difu_monster_spawn_position_for_edge(spawn_edge, fallback_position)


func _get_difu_monster_spawn_position_for_edge(edge: int, fallback_position: Vector2) -> Vector2:
	var player := $Player as Node2D
	var camera := (player.get_node_or_null("Camera2D") as Camera2D) if player != null else null
	var visible_rect := _get_camera_visible_rect(camera)
	if camera == null or visible_rect.size == Vector2.ZERO:
		return fallback_position
	match edge:
		0:
			var spawn_y := clampf(visible_rect.position.y - MONSTER_SPAWN_OFFSCREEN_MARGIN, DIFU_TOP_Y, DIFU_BOTTOM_Y)
			return Vector2(clampf(fallback_position.x, DIFU_TOP_X_MIN, DIFU_TOP_X_MAX), spawn_y)
		1:
			var spawn_y := clampf(visible_rect.position.y + visible_rect.size.y + MONSTER_SPAWN_OFFSCREEN_MARGIN, DIFU_TOP_Y, DIFU_BOTTOM_Y)
			return Vector2(clampf(fallback_position.x, DIFU_BOTTOM_X_MIN, DIFU_BOTTOM_X_MAX), spawn_y)
		2:
			var spawn_x := clampf(visible_rect.position.x - MONSTER_SPAWN_OFFSCREEN_MARGIN, DIFU_LEFT_X, DIFU_RIGHT_X)
			return Vector2(spawn_x, clampf(fallback_position.y, DIFU_LEFT_Y_MIN, DIFU_LEFT_Y_MAX))
		_:
			var spawn_x := clampf(visible_rect.position.x + visible_rect.size.x + MONSTER_SPAWN_OFFSCREEN_MARGIN, DIFU_LEFT_X, DIFU_RIGHT_X)
			return Vector2(spawn_x, clampf(fallback_position.y, DIFU_RIGHT_Y_MIN, DIFU_RIGHT_Y_MAX))


func _on_ghost_tree_exiting() -> void:
	ghost_alive = max(0, ghost_alive - 1)


func add_kill_rewards(monster_node: Node, point_gain: int) -> void:
	super.add_kill_rewards(monster_node, point_gain)
	if _is_difu_magic_core_source(monster_node):
		_try_drop_difu_elite_magic_core(monster_node.global_position)


func _is_difu_magic_core_source(monster_node: Node) -> bool:
	if monster_node == null:
		return false
	return monster_node.get_meta("is_elite_monster", false) == true or monster_node.get_meta("is_corrupted_elite", false) == true or monster_node.is_in_group("elite")


func _try_drop_difu_elite_magic_core(drop_position: Vector2) -> void:
	var force_drop := _should_force_difu_magic_core_drop()
	if not force_drop and randf() > _get_difu_magic_core_drop_chance():
		return
	var core_id := str(DIFU_MAGIC_CORE_IDS[randi() % DIFU_MAGIC_CORE_IDS.size()])
	Global.emit_signal("drop_out_item", core_id, 1, drop_position)
	difu_magic_core_drop_count += 1


func _should_force_difu_magic_core_drop() -> bool:
	var pity_times := _get_difu_magic_core_pity_times()
	for i in range(pity_times.size()):
		if difu_magic_core_drop_count <= i and PC.real_time >= float(pity_times[i]):
			return true
	return false


func _get_difu_magic_core_drop_chance() -> float:
	var difficulty_id := Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	if difficulty_id == Global.STAGE_DIFFICULTY_DEEP:
		return 0.035
	if difficulty_id == Global.STAGE_DIFFICULTY_CORE:
		var depth := Global.get_current_core_depth()
		if depth >= 10:
			return 0.095
		if depth >= 7:
			return 0.08
		if depth >= 4:
			return 0.065
		return 0.05
	return 0.02


func _get_difu_magic_core_pity_times() -> Array[float]:
	var difficulty_id := Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	if difficulty_id == Global.STAGE_DIFFICULTY_DEEP:
		return [360.0]
	if difficulty_id == Global.STAGE_DIFFICULTY_CORE:
		var depth := Global.get_current_core_depth()
		if depth >= 10:
			return [150.0, 240.0, 330.0, 420.0]
		if depth >= 7:
			return [180.0, 300.0, 420.0]
		return [240.0, 420.0]
	return [300.0]
