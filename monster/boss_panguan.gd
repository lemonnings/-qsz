extends "res://Script/monster/boss_base.gd"

const DARK_BALL_SCENE: PackedScene = preload("res://Scenes/moster/boss_skill/dark_ball.tscn")
const HUN_SCENE: PackedScene = preload("res://Scenes/moster/boss_skill/hun.tscn")
const MAGIC_TEXTURE: Texture2D = preload("res://AssetBundle/Sprites/SpecialEffects/magic.png")

const KEEP_DISTANCE_X: float = 90.0
const MOVE_TARGET_REFRESH: float = 0.5
const DARK_BALL_CHANT_TIME: float = 3.0
const DARK_BALL_RADIUS: float = 120.0
const MOLING_CHANT_TIME: float = 1.0
const MOLING_BULLET_SPEED: float = 72.8 * 0.7
const MOLING_BULLET_START_X: float = -270.0
const MOLING_BULLET_SPAWN_Y: float = -10.0
const MOLING_BULLET_SPACING: float = 32.0
const MOLING_BULLET_COUNT: int = 15
const MOFA_WIDTH: float = 82.0
const MOFA_LENGTH: float = 1200.0
const MOFA_REPEAT_COUNT: int = 3
const DEPRIVATION_DURATION: float = 20.0
const DEPRIVE_MOVE_AMOUNT: float = 0.40
const DEPRIVE_ATTACK_SPEED_AMOUNT: float = 0.70
const ANSWER_CIRCLE_RADIUS: float = 46.0
const DIFU_ARENA_CENTER: Vector2 = Vector2(0.0, 225.0)
const ANSWER_CIRCLE_Y: float = 375.0
const DIFU_TOP_Y: float = -10.0
const DIFU_TOP_LEFT_X: float = -100.0
const DIFU_TOP_RIGHT_X: float = 100.0
const DIFU_LEFT_X: float = -300.0
const DIFU_LEFT_TOP_Y: float = 175.0
const DIFU_RIGHT_X: float = 300.0
const DIFU_RIGHT_TOP_Y: float = 100.0
const DIFU_BOTTOM_Y: float = 750.0
const DIFU_BOTTOM_LEFT_X: float = -275.0
const DIFU_BOTTOM_RIGHT_X: float = 275.0

@onready var sprite: AnimatedSprite2D = $BossStone

var is_attacking: bool = false
var allow_turning: bool = true
var target_position: Vector2 = Vector2.ZERO
var update_move_timer: Timer = null
var attack_timer: Timer = null
var attack_sequence_index: int = 0
var pending_ink_skill: String = ""
var stage_difficulty: String = Global.STAGE_DIFFICULTY_SHALLOW
var speed: float = SettingMoster.youling("speed") * 1.2
var hpMax: float = SettingMoster.youling("hp") * 12.0
var hp: float = hpMax
var atk: float = SettingMoster.youling("atk")
var get_point: int = int(SettingMoster.youling("point")) * 50
var get_exp: int = 0
var active_deprivation: Dictionary = {}
var deprivation_timer: Timer = null
var answer_circle_nodes: Array[Node2D] = []
var attack_animation_name: String = ""
var defeat_cleanup_scheduled: bool = false
var active_answer_add_buff_id: String = ""


func _ready() -> void:
	stage_difficulty = setup_boss_base("boss_panguan", true)
	player_hit_emit_self = true
	use_debuff_take_damage_multiplier = false
	check_action_disabled_on_body_entered = false
	CharacterEffects.create_shadow(self, 50.0, 16.0, 24.0)
	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "判官")
	Global.emit_signal("boss_hp_bar_show")

	target_position = _get_arena_center()
	update_move_timer = Timer.new()
	add_child(update_move_timer)
	update_move_timer.wait_time = MOVE_TARGET_REFRESH
	update_move_timer.timeout.connect(_update_target_position)
	update_move_timer.start()
	_update_target_position()

	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 1.5
	attack_timer.timeout.connect(_start_next_skill)
	attack_timer.start()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if PC.player_instance != null and allow_turning and not is_attacking:
		CharacterEffects.face_player_x(self, sprite, false)
	if not is_attacking:
		_move_pattern(delta)
		_play_sprite_animation("run")
	else:
		global_position = _clamp_to_difu_arena(global_position)
		_play_sprite_animation(attack_animation_name if not attack_animation_name.is_empty() else "idle")
	_update_answer_circle_buff()
	if attack_timer != null:
		attack_timer.paused = is_attacking


func _play_sprite_animation(animation_name: String) -> void:
	if sprite == null or animation_name.is_empty():
		return
	if sprite.sprite_frames != null and not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func _move_pattern(delta: float) -> void:
	target_position = _clamp_to_difu_arena(target_position)
	var distance := global_position.distance_to(target_position)
	if distance <= 5.0:
		return
	var direction := global_position.direction_to(target_position)
	var step: float = minf(speed * delta, distance)
	global_position = _clamp_to_difu_arena(global_position + direction * step)


func _update_target_position() -> void:
	if not is_instance_valid(PC.player_instance):
		return
	var player_pos: Vector2 = PC.player_instance.global_position
	var x_offset := KEEP_DISTANCE_X
	if global_position.x < player_pos.x:
		x_offset = -KEEP_DISTANCE_X
	target_position = _clamp_to_difu_arena(Vector2(player_pos.x + x_offset, player_pos.y))


func _get_arena_center() -> Vector2:
	return DIFU_ARENA_CENTER


func _clamp_to_difu_arena(world_position: Vector2) -> Vector2:
	var y := clampf(world_position.y, DIFU_TOP_Y, DIFU_BOTTOM_Y)
	var x_limits := _get_difu_arena_x_limits(y)
	return Vector2(clampf(world_position.x, x_limits.x, x_limits.y), y)


func _get_difu_arena_x_limits(y: float) -> Vector2:
	var left_limit := DIFU_LEFT_X
	if y < DIFU_LEFT_TOP_Y:
		var left_t := inverse_lerp(DIFU_TOP_Y, DIFU_LEFT_TOP_Y, y)
		left_limit = lerpf(DIFU_TOP_LEFT_X, DIFU_LEFT_X, clampf(left_t, 0.0, 1.0))
	else:
		var left_bottom_t := inverse_lerp(DIFU_LEFT_TOP_Y, DIFU_BOTTOM_Y, y)
		left_limit = lerpf(DIFU_LEFT_X, DIFU_BOTTOM_LEFT_X, clampf(left_bottom_t, 0.0, 1.0))
	var right_limit := DIFU_RIGHT_X
	if y < DIFU_RIGHT_TOP_Y:
		var right_t := inverse_lerp(DIFU_TOP_Y, DIFU_RIGHT_TOP_Y, y)
		right_limit = lerpf(DIFU_TOP_RIGHT_X, DIFU_RIGHT_X, clampf(right_t, 0.0, 1.0))
	else:
		var right_bottom_t := inverse_lerp(DIFU_RIGHT_TOP_Y, DIFU_BOTTOM_Y, y)
		right_limit = lerpf(DIFU_RIGHT_X, DIFU_BOTTOM_RIGHT_X, clampf(right_bottom_t, 0.0, 1.0))
	return Vector2(left_limit, right_limit)


func _start_next_skill() -> void:
	if is_dead or is_attacking:
		return
	is_attacking = true
	var skill_id := _pop_next_skill_id()
	await _execute_skill(skill_id)
	if is_inside_tree() and not is_dead:
		is_attacking = false


func _pop_next_skill_id() -> String:
	match attack_sequence_index:
		0:
			attack_sequence_index = 1
			return "moling"
		1:
			pending_ink_skill = "mozhu" if randf() < 0.5 else "mofa"
			attack_sequence_index = 2
			return pending_ink_skill
		2:
			attack_sequence_index = 3
			return "deprive"
		3:
			attack_sequence_index = 4
			return "answer"
		_:
			var other_skill := "mofa" if pending_ink_skill == "mozhu" else "mozhu"
			pending_ink_skill = ""
			attack_sequence_index = 0
			return other_skill


func _execute_skill(skill_id: String) -> void:
	attack_animation_name = ""
	match skill_id:
		"moling":
			await _attack_moling()
		"mozhu":
			await _attack_mozhu()
		"mofa":
			await _attack_mofa()
		"deprive":
			await _attack_deprive()
		"answer":
			await _attack_answer()
	attack_animation_name = ""


func _attack_mozhu() -> void:
	attack_animation_name = "skill"
	Global.emit_signal("boss_chant_start", "墨珠", DARK_BALL_CHANT_TIME)
	var interval := _get_mozhu_interval()
	var elapsed := 0.0
	while elapsed < DARK_BALL_CHANT_TIME:
		if not _can_continue_skill():
			return
		_spawn_dark_ball(_get_dark_ball_position())
		var wait_time: float = minf(interval, DARK_BALL_CHANT_TIME - elapsed)
		var alive := await _wait_seconds(wait_time)
		if not alive:
			return
		elapsed += wait_time
	Global.emit_signal("boss_chant_end")


func _get_mozhu_interval() -> float:
	return 0.3 if stage_difficulty == Global.STAGE_DIFFICULTY_CORE else 0.4


func _get_dark_ball_position() -> Vector2:
	var center := global_position
	if randf() < 0.5 and is_instance_valid(PC.player_instance):
		center = PC.player_instance.global_position
	var angle := randf() * TAU
	var distance := sqrt(randf()) * DARK_BALL_RADIUS
	var raw_position := center + Vector2.RIGHT.rotated(angle) * distance
	return _clamp_to_difu_arena(raw_position)


func _spawn_dark_ball(spawn_position: Vector2) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var dark_ball := DARK_BALL_SCENE.instantiate() as Area2D
	if dark_ball == null:
		return
	dark_ball.global_position = spawn_position
	get_tree().current_scene.add_child(dark_ball)
	var dark_sprite := dark_ball.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if dark_sprite != null:
		dark_sprite.play("default")
	var hit_radius := _get_area_circle_radius(dark_ball)
	if _is_player_in_circle(spawn_position, hit_radius):
		PC.player_hit(int(atk), self, "墨珠")
	get_tree().create_timer(1.25, false).timeout.connect(Callable(dark_ball, "queue_free"), CONNECT_ONE_SHOT)


func _get_area_circle_radius(area: Area2D) -> float:
	var collision_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 40.0
	if collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		return circle.radius * maxf(absf(collision_shape.global_scale.x), absf(collision_shape.global_scale.y))
	return 40.0


func _attack_moling() -> void:
	Global.emit_signal("boss_chant_start", "泼墨·墨灵", MOLING_CHANT_TIME)
	var alive := await _wait_seconds(MOLING_CHANT_TIME)
	if not alive:
		return
	Global.emit_signal("boss_chant_end")
	var rounds := 4 if _is_deep_or_harder() else 3
	var round_interval := 3.0 if _is_deep_or_harder() else 4.0
	for round_index in range(rounds):
		if not _can_continue_skill():
			return
		_spawn_moling_wave()
		if round_index < rounds - 1:
			alive = await _wait_seconds(round_interval)
			if not alive:
				return


func _spawn_moling_wave() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var blocked_indices := _get_moling_gap_indices()
	for i in range(MOLING_BULLET_COUNT):
		if blocked_indices.has(i):
			continue
		var bullet := HUN_SCENE.instantiate() as Area2D
		if bullet == null:
			continue
		get_tree().current_scene.add_child(bullet)
		var spawn_position := Vector2(MOLING_BULLET_START_X + MOLING_BULLET_SPACING * float(i), MOLING_BULLET_SPAWN_Y)
		if bullet.has_method("setup_projectile"):
			bullet.setup_projectile(spawn_position, Vector2.DOWN, atk, MOLING_BULLET_SPEED, self, "泼墨·墨灵")


func _get_moling_gap_indices() -> Dictionary:
	var blocked: Dictionary = {}
	var two_gap_start := randi_range(0, MOLING_BULLET_COUNT - 2)
	blocked[two_gap_start] = true
	blocked[two_gap_start + 1] = true
	var single_candidates: Array[int] = []
	for i in range(MOLING_BULLET_COUNT):
		if not blocked.has(i):
			single_candidates.append(i)
	if not single_candidates.is_empty():
		var single_index := single_candidates[randi_range(0, single_candidates.size() - 1)]
		blocked[single_index] = true
	return blocked


func _attack_mofa() -> void:
	attack_animation_name = "skill"
	for i in range(MOFA_REPEAT_COUNT):
		if not _can_continue_skill():
			return
		_face_player_once()
		var direction := _get_direction_to_player()
		var warning_time := _get_mofa_warning_time()
		_spawn_mofa_warning(direction, warning_time)
		var alive := await _wait_seconds(warning_time + 0.25)
		if not alive:
			return


func _spawn_mofa_warning(direction: Vector2, warning_time: float) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	Global.emit_signal("boss_chant_start", "泼墨·墨罚", warning_time)
	var start_position := global_position
	var target_point := start_position + direction * MOFA_LENGTH
	var warning := WarnRectUtil.new()
	get_tree().current_scene.add_child(warning)
	warning.attacker = self
	warning.warning_finished.connect(func():
		Global.emit_signal("boss_chant_end")
		_spawn_mofa_ink_effect(start_position, direction)
		if is_instance_valid(warning):
			warning.cleanup()
	)
	warning.start_warning(start_position, target_point, MOFA_WIDTH, warning_time, atk, "泼墨·墨罚", null, 0.18)


func _spawn_mofa_ink_effect(start_position: Vector2, direction: Vector2) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var effect := _InkRayEffect.new()
	effect.global_position = start_position
	effect.rotation = direction.angle()
	effect.ray_width = MOFA_WIDTH
	effect.ray_length = MOFA_LENGTH
	get_tree().current_scene.add_child(effect)


func _get_mofa_warning_time() -> float:
	if stage_difficulty == Global.STAGE_DIFFICULTY_CORE:
		return 1.5
	if stage_difficulty == Global.STAGE_DIFFICULTY_DEEP:
		return 1.8
	return 2.0


func _attack_deprive() -> void:
	var deprive_type := "speed" if randf() < 0.5 else "atkspeed"
	var value := randi_range(1, 3)
	_apply_deprivation(deprive_type, value)
	var alive := await _wait_seconds(0.8)
	if not alive:
		return


func _apply_deprivation(deprive_type: String, value: int) -> void:
	_clear_deprivation_effect(false)
	var amount := DEPRIVE_MOVE_AMOUNT if deprive_type == "speed" else DEPRIVE_ATTACK_SPEED_AMOUNT
	var buff_id := "deprive_speed_%d" % value if deprive_type == "speed" else "deprive_atkspeed_%d" % value
	active_deprivation = {
		"type": deprive_type,
		"value": value,
		"amount": amount,
		"buff_id": buff_id,
	}
	if deprive_type == "speed":
		PC.move_speed_bonus -= amount
	else:
		PC.attack_speed_bonus -= amount
		_refresh_player_attack_speed()
	var buff_manager := _find_player_buff_manager()
	if buff_manager != null and buff_manager.has_method("add_buff"):
		buff_manager.add_buff(buff_id, DEPRIVATION_DURATION, 1)
	_show_buff_notification(buff_id, " + ")
	deprivation_timer = Timer.new()
	add_child(deprivation_timer)
	deprivation_timer.wait_time = DEPRIVATION_DURATION
	deprivation_timer.one_shot = true
	deprivation_timer.timeout.connect(Callable(self, "_on_deprivation_timeout"), CONNECT_ONE_SHOT)
	deprivation_timer.start()


func _on_deprivation_timeout() -> void:
	_clear_deprivation_effect(true)


func _clear_deprivation_effect(show_remove_notification: bool = true) -> void:
	if active_deprivation.is_empty():
		return
	var deprive_type := str(active_deprivation.get("type", ""))
	var amount := float(active_deprivation.get("amount", 0.0))
	var buff_id := str(active_deprivation.get("buff_id", ""))
	if deprive_type == "speed":
		PC.move_speed_bonus += amount
	elif deprive_type == "atkspeed":
		PC.attack_speed_bonus += amount
		_refresh_player_attack_speed()
	if show_remove_notification and not buff_id.is_empty():
		_show_buff_notification(buff_id, " - ")
	if not buff_id.is_empty():
		BuffManager.remove_buff(buff_id)
	active_deprivation.clear()
	if deprivation_timer != null and is_instance_valid(deprivation_timer):
		deprivation_timer.queue_free()
	deprivation_timer = null


func _attack_answer() -> void:
	attack_animation_name = "skill"
	_face_right()
	target_position = _get_arena_center()
	global_position = target_position
	if not _can_continue_skill():
		return
	_face_right()
	var query_id := _get_answer_query_id()
	var query_name := _get_answer_query_name(query_id)
	var chant_time := _get_answer_chant_time()
	Global.emit_signal("teammate_dialogue", "判官", "剥夺与法阵之数之和，即答问结果。")
	Global.emit_signal("boss_chant_start", "答问·" + query_name, chant_time)
	_spawn_answer_circles()
	var alive := await _wait_seconds(chant_time)
	if not alive:
		_clear_answer_circles()
		return
	Global.emit_signal("boss_chant_end")
	_resolve_answer(query_id)
	_clear_answer_circles()


func _move_to_answer_position() -> void:
	var max_time := 1.2
	var elapsed := 0.0
	while elapsed < max_time and global_position.distance_to(target_position) > 8.0:
		if not _can_continue_skill():
			return
		var delta := get_physics_process_delta_time()
		_move_pattern(delta)
		elapsed += delta
		await get_tree().process_frame


func _spawn_answer_circles() -> void:
	_clear_answer_circles()
	if get_tree() == null or get_tree().current_scene == null:
		return
	var positions: Array[Vector2] = [
		Vector2(-150.0, ANSWER_CIRCLE_Y),
		Vector2(0.0, ANSWER_CIRCLE_Y),
		Vector2(150.0, ANSWER_CIRCLE_Y),
	]
	for i in range(3):
		var circle_node := _create_answer_circle(positions[i], i + 1)
		get_tree().current_scene.add_child(circle_node)
		answer_circle_nodes.append(circle_node)


func _create_answer_circle(circle_position: Vector2, value: int) -> Node2D:
	var root := Node2D.new()
	root.global_position = circle_position
	root.z_index = -10
	root.set_meta("answer_value", value)
	root.set_meta("answer_radius", ANSWER_CIRCLE_RADIUS)
	var magic_sprite := Sprite2D.new()
	magic_sprite.texture = MAGIC_TEXTURE
	magic_sprite.modulate = Color(0.18, 0.18, 0.18, 0.86)
	if MAGIC_TEXTURE != null:
		var tex_size := MAGIC_TEXTURE.get_size()
		var max_size: float = maxf(tex_size.x, tex_size.y)
		if max_size > 0.0:
			magic_sprite.scale = Vector2.ONE * (ANSWER_CIRCLE_RADIUS * 2.0 / max_size)
	root.add_child(magic_sprite)
	var label := Label.new()
	label.text = _to_chinese_number(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.modulate = Color(0.78, 0.78, 0.78, 0.95)
	label.size = Vector2(56.0, 36.0)
	label.position = Vector2(-28.0, -58.0)
	root.add_child(label)
	var label_tween := root.create_tween()
	label_tween.set_loops()
	label_tween.tween_property(label, "position:y", -66.0, 0.5)
	label_tween.tween_property(label, "position:y", -58.0, 0.5)
	var flash_tween := root.create_tween()
	flash_tween.set_loops()
	flash_tween.tween_property(root, "modulate:a", 0.7, 0.45)
	flash_tween.tween_property(root, "modulate:a", 1.0, 0.45)
	return root


func _resolve_answer(query_id: String) -> void:
	var deprivation_value := int(active_deprivation.get("value", 0))
	var circle_value := _get_player_answer_circle_value()
	var final_value := deprivation_value + circle_value
	var passed := _is_answer_passed(query_id, final_value)
	if passed:
		_clear_deprivation_effect(true)
		return
	var damage_ratio := _get_answer_fail_damage_ratio()
	var damage := maxi(1, int(ceil(float(PC.pc_hp) * damage_ratio)))
	PC.player_hit(damage, self, "答问")


func _get_player_answer_circle_value() -> int:
	if not is_instance_valid(PC.player_instance):
		return 0
	var hitbox_info := PC.get_player_hitbox_info()
	var player_pos: Vector2 = PC.player_instance.global_position
	var player_radius := 0.0
	if not hitbox_info.is_empty() and hitbox_info.get("type") == "circle":
		player_pos = hitbox_info.get("position", player_pos)
		player_radius = float(hitbox_info.get("radius", 0.0))
	for circle_node in answer_circle_nodes:
		if not is_instance_valid(circle_node):
			continue
		var radius := float(circle_node.get_meta("answer_radius", ANSWER_CIRCLE_RADIUS))
		if player_pos.distance_to(circle_node.global_position) <= radius + player_radius:
			return int(circle_node.get_meta("answer_value", 0))
	return 0


func _update_answer_circle_buff() -> void:
	if answer_circle_nodes.is_empty():
		_clear_answer_add_buff()
		return
	var circle_value := _get_player_answer_circle_value()
	var next_buff_id := "answer_add_%d" % circle_value if circle_value > 0 else ""
	if next_buff_id == active_answer_add_buff_id:
		return
	_clear_answer_add_buff()
	if next_buff_id.is_empty():
		return
	active_answer_add_buff_id = next_buff_id
	var buff_manager := _find_player_buff_manager()
	if buff_manager != null and buff_manager.has_method("add_buff"):
		buff_manager.add_buff(active_answer_add_buff_id, 99.0, 1)
	_show_buff_notification(active_answer_add_buff_id, " + ")


func _clear_answer_add_buff() -> void:
	if active_answer_add_buff_id.is_empty():
		return
	BuffManager.remove_buff(active_answer_add_buff_id)
	active_answer_add_buff_id = ""


func _is_answer_passed(query_id: String, final_value: int) -> bool:
	match query_id:
		"odd":
			return final_value % 2 == 1
		"even":
			return final_value % 2 == 0
		"three":
			return final_value == 3
		"four":
			return final_value == 4
		_:
			return false


func _get_answer_query_id() -> String:
	var query_ids: Array[String] = ["odd", "even", "three", "four"]
	return query_ids[randi_range(0, query_ids.size() - 1)]


func _get_answer_query_name(query_id: String) -> String:
	match query_id:
		"odd":
			return "奇数"
		"even":
			return "偶数"
		"three":
			return "得三"
		"four":
			return "得四"
		_:
			return "奇数"


func _get_answer_chant_time() -> float:
	return 8.0 if stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW else 5.0


func _get_answer_fail_damage_ratio() -> float:
	if stage_difficulty == Global.STAGE_DIFFICULTY_CORE:
		return 0.70
	if stage_difficulty == Global.STAGE_DIFFICULTY_DEEP:
		return 0.50
	return 0.30


func _clear_answer_circles() -> void:
	_clear_answer_add_buff()
	for circle_node in answer_circle_nodes:
		if is_instance_valid(circle_node):
			circle_node.queue_free()
	answer_circle_nodes.clear()


func _to_chinese_number(value: int) -> String:
	match value:
		1:
			return "壹"
		2:
			return "贰"
		3:
			return "叁"
		_:
			return str(value)


func _is_player_in_circle(center: Vector2, radius: float) -> bool:
	if not is_instance_valid(PC.player_instance):
		return false
	var hitbox_info := PC.get_player_hitbox_info()
	var player_pos: Vector2 = PC.player_instance.global_position
	var player_radius := 0.0
	if not hitbox_info.is_empty() and hitbox_info.get("type") == "circle":
		player_pos = hitbox_info.get("position", player_pos)
		player_radius = float(hitbox_info.get("radius", 0.0))
	return player_pos.distance_to(center) <= radius + player_radius


func _get_direction_to_player() -> Vector2:
	if is_instance_valid(PC.player_instance):
		var direction: Vector2 = global_position.direction_to(PC.player_instance.global_position)
		if direction.length_squared() > 0.001:
			return direction
	return Vector2.DOWN


func _face_player_once() -> void:
	if not is_instance_valid(PC.player_instance):
		return
	if PC.player_instance.global_position.x < global_position.x:
		CharacterEffects.set_enemy_flip_h(self, sprite, true, 0.0)
	else:
		CharacterEffects.set_enemy_flip_h(self, sprite, false, 0.0)


func _face_right() -> void:
	CharacterEffects.set_enemy_flip_h(self, sprite, false, 0.0)


func _is_deep_or_harder() -> bool:
	return stage_difficulty == Global.STAGE_DIFFICULTY_DEEP or stage_difficulty == Global.STAGE_DIFFICULTY_CORE


func _can_continue_skill() -> bool:
	return is_inside_tree() and not is_dead and not PC.is_game_over


func _wait_seconds(seconds: float) -> bool:
	if seconds <= 0.0:
		return _can_continue_skill()
	await get_tree().create_timer(seconds, false).timeout
	return _can_continue_skill()


func _refresh_player_attack_speed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("update_skill_attack_speeds"):
		player.update_skill_attack_speeds()
	Global.emit_signal("skill_attack_speed_updated")


func _find_player_buff_manager() -> Node:
	if get_tree() == null or get_tree().current_scene == null:
		return null
	var canvas := get_tree().current_scene.get_node_or_null("CanvasLayer")
	if canvas != null and canvas.has_method("get_buff_manager"):
		return canvas.get_buff_manager()
	return get_tree().current_scene.find_child("BuffManager", true, false)


func _show_buff_notification(buff_id: String, prefix: String = " + ") -> void:
	var buff_config := BuffManager.get_buff_data(buff_id)
	if buff_config == null or get_tree() == null or get_tree().current_scene == null:
		return
	var canvas := get_tree().current_scene.get_node_or_null("CanvasLayer")
	if canvas != null and canvas.has_method("show_buff_notification"):
		canvas.show_buff_notification(buff_config.icon_path, buff_config.name, prefix)


func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result: Dictionary = BulletCalculator.handle_bullet_collision_full(area, self, true)
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		if collision_result["should_delete_bullet"]:
			area.queue_free()
		var raw_damage: float = get_common_bullet_damage_value(collision_result["final_damage"])
		take_damage(int(raw_damage), bool(collision_result["is_crit"]), false, "bullet")


func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if is_dead:
		return
	var damage_result := apply_common_take_damage(damage, is_crit, is_summon, damage_type, {
		"use_debuff_multiplier": false,
		"update_boss_hp_bar": true,
		"play_hit_animation": true,
		"randomize_popup_offset": true,
		"require_damage_range_check": true
	})
	if damage_result["applied"] and damage_result["is_lethal"]:
		_die()


func _on_body_entered(body: Node2D) -> void:
	handle_common_body_entered(body)


func _drop_boss_rewards() -> void:
	var ether_ids: Array[String] = ["item_031", "item_032", "item_033", "item_034", "item_035"]
	if randf() <= 0.75:
		var chosen_ether := ether_ids[randi() % ether_ids.size()]
		Global.emit_signal("drop_out_item", chosen_ether, 1, global_position)
	drop_items_from_table(SettingMoster.get_boss_extra_drop())
	var magic_cores: Array[String] = ["item_097", "item_098", "item_099", "item_100", "item_101"]
	Global.emit_signal("drop_out_item", magic_cores[randi() % magic_cores.size()], 1, global_position)


func _die() -> void:
	if not is_dead:
		_drop_boss_rewards()
		Global.emit_signal("boss_defeated", get_point, global_position)
		Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	is_attacking = false
	Global.emit_signal("boss_chant_end")
	_clear_deprivation_effect(false)
	_clear_answer_circles()
	if attack_timer != null and is_instance_valid(attack_timer):
		attack_timer.stop()
	if update_move_timer != null and is_instance_valid(update_move_timer):
		update_move_timer.stop()
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shadow := get_node_or_null("Shadow")
	if shadow != null:
		shadow.visible = false
	_schedule_defeat_cleanup()


func _schedule_defeat_cleanup() -> void:
	if defeat_cleanup_scheduled:
		return
	defeat_cleanup_scheduled = true
	_play_sprite_animation("defeat")
	if sprite != null:
		sprite.animation_finished.connect(_on_defeat_animation_finished, CONNECT_ONE_SHOT)
	if get_tree() != null:
		get_tree().create_timer(1.2, false).timeout.connect(_queue_free_after_defeat, CONNECT_ONE_SHOT)


func _on_defeat_animation_finished() -> void:
	if sprite != null and sprite.animation == "defeat":
		_queue_free_after_defeat()


func _queue_free_after_defeat() -> void:
	if is_inside_tree():
		queue_free()


func _exit_tree() -> void:
	_clear_deprivation_effect(false)
	_clear_answer_circles()


class _InkRayEffect extends Node2D:
	var elapsed: float = 0.0
	var duration: float = 0.55
	var ray_width: float = 82.0
	var ray_length: float = 1200.0
	var _x_positions: PackedFloat32Array = []

	func _ready() -> void:
		for x in range(0, int(ray_length), 8):
			_x_positions.append(float(x))

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var alpha := 1.0 - clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var outer_color := Color(0.02, 0.018, 0.014, 0.68 * alpha)
		var inner_color := Color(0.40, 0.40, 0.38, 0.82 * alpha)
		var current_width := ray_width * (0.9 + 0.1 * alpha)
		for x in _x_positions:
			var outer_h := current_width * randf_range(0.78, 1.08)
			draw_rect(Rect2(x, -outer_h * 0.5, 8.0, outer_h), outer_color)
			var inner_h := current_width * 0.58 * randf_range(0.72, 1.0)
			draw_rect(Rect2(x, -inner_h * 0.5, 8.0, inner_h), inner_color)
