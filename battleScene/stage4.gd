extends "res://Script/battleScene/base_stage.gd"

# ============== stage4 特有的怪物场景 ==============
@export var slime_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var extra_scene: PackedScene

# ============== 实现基类虚方法：关卡配置 ==============
func _setup_stage_config() -> void:
	STAGE_ID = "forest"
	SPAWN_INTERVAL_SECONDS = 3.85
	INITIAL_MONSTER_LIMIT = 39
	MAX_MONSTER_CAP = 104
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.3
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 5.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.3
	BASIC_TYPES = ["slime", "bat"]
	OTHER_TYPE_PER_WAVE_MAX = 2
	OTHER_TYPE_TOTAL_MAX = 5
	ELITE_MAX = 3

	# FOREST: slime(6), bat(2), frog(3), extra(3)
	stage_spawn_pool = [
		{"type": "slime", "weight": 6, "blocked_early": false},
		{"type": "bat", "weight": 2, "blocked_early": false},
		{"type": "frog", "weight": 3, "blocked_early": false},
		{"type": "extra", "weight": 3, "blocked_early": false}
	]

# ============== 覆盖 _ready：stage4 特有初始化 ==============
func _ready() -> void:
	super ()
	$Player.camera.zoom = Vector2(2.7, 2.7)
	$Player.min_zoom = 2.5
	GU.reset_kill_count()

	# stage4 固定使用31000（不区分难度）
	map_mechanism_num_max = 31000

	# 播放密林BGM
	Global.emit_signal("stage_bgm", "forest")

# ============== 实现基类虚方法：Boss位置 ==============
func _get_boss_position() -> Vector2:
	return Vector2(-370, randf_range(185, 259))

# ============== 实现基类虚方法：生成一波怪物 ==============
func _spawn_wave() -> void:
	if boss_event_triggered:
		return

	var current_frame = Engine.get_process_frames()
	if current_frame == last_wave_spawn_frame:
		return
	last_wave_spawn_frame = current_frame

	spawn_count += 1
	_update_wave_monster_limit()
	if current_monster_count >= max_monster_limit:
		monster_spawn_timer.start()
		return

	# 计算动态平衡参数
	var spawn_multiplier = _calculate_spawn_count_multiplier()
	current_wave_hp_reduction = _calculate_hp_reduction()

	var base_wave_spawn_count = _get_wave_spawn_count()
	var wave_spawn_count = int(ceil(float(base_wave_spawn_count) * spawn_multiplier))
	var available_slots = max_monster_limit - current_monster_count
	var spawn_target_count = min(wave_spawn_count, available_slots)
	if spawn_target_count <= 0:
		monster_spawn_timer.start()
		return

	var wave_other_type_counts: Dictionary = {}
	var spawn_list: Array[String] = []
	for i in range(spawn_target_count):
		var chosen_type = _choose_individual_type(wave_other_type_counts)
		if not BASIC_TYPES.has(chosen_type):
			if not wave_other_type_counts.has(chosen_type):
				wave_other_type_counts[chosen_type] = 0
			wave_other_type_counts[chosen_type] += 1
			other_type_alive += 1
		spawn_list.append(chosen_type)

	for i in range(spawn_list.size()):
		if current_monster_count >= max_monster_limit:
			break
		match spawn_list[i]:
			"slime":
				_spawn_single_slime()
			"bat":
				_spawn_single_bat()
			"frog":
				_spawn_single_frog()
			"extra":
				_spawn_single_extra()
		if i < spawn_list.size() - 1:
			if not is_inside_tree():
				return
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				return

	monster_spawn_timer.start()

# ============== 各怪物生成方法 ==============
func _spawn_single_slime() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var slime_node = slime_scene.instantiate()
	slime_node.move_direction = 2
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-310, 305), -15)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), -560)
		2: # Left
			spawn_position = Vector2(-310, randf_range(-15, -560))
		3: # Right
			spawn_position = Vector2(305, randf_range(-15, -560))
	slime_node.position = spawn_position
	get_tree().current_scene.add_child(slime_node)
	_try_make_elite(slime_node)
	_apply_dynamic_hp_reduction(slime_node)
	slime_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(slime_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	slime_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_bat() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var bat_node = bat_scene.instantiate()
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-310, 305), -15)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), -560)
		2: # Left
			spawn_position = Vector2(-310, randf_range(-15, -560))
		3: # Right
			spawn_position = Vector2(305, randf_range(-15, -560))
	bat_node.position = spawn_position
	get_tree().current_scene.add_child(bat_node)
	_try_make_elite(bat_node)
	_apply_dynamic_hp_reduction(bat_node)
	bat_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(bat_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	bat_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_frog() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var frog_node = frog_scene.instantiate()
	frog_node.move_direction = 2
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-310, 305), -10)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 650)
		2: # Left
			spawn_position = Vector2(-400, randf_range(15, 650))
		3: # Right
			spawn_position = Vector2(400, randf_range(15, 650))
	frog_node.position = spawn_position
	get_tree().current_scene.add_child(frog_node)
	_try_make_elite(frog_node)
	_apply_dynamic_hp_reduction(frog_node)
	frog_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(frog_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	frog_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	frog_node.connect("tree_exiting", func(): other_type_alive = max(0, other_type_alive - 1))

func _spawn_single_extra() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var extra_node = extra_scene.instantiate()
	extra_node.move_direction = 2
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-310, 305), -10)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 650)
		2: # Left
			spawn_position = Vector2(-400, randf_range(15, 650))
		3: # Right
			spawn_position = Vector2(400, randf_range(15, 650))
	extra_node.position = spawn_position
	get_tree().current_scene.add_child(extra_node)
	_try_make_elite(extra_node)
	_apply_dynamic_hp_reduction(extra_node)
	extra_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(extra_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	extra_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	extra_node.connect("tree_exiting", func(): other_type_alive = max(0, other_type_alive - 1))
