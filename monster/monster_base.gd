extends Area2D
class_name MonsterBase

const HEALTH_BAR_SCENE = preload("res://Scenes/global/hp_bar.tscn")
const ROUND_SWORD_QI_BULLET_SCENE = preload("res://Scenes/bullet.tscn")
const MONSTER_FIREBALL_SCENE = preload("res://Scenes/moster/frog_attack.tscn")
const CORRUPTED_ELITE_DEFAULT_DROP_ID: String = "item_102"
const CORRUPTED_ELITE_CHARGE_PREPARING_META: String = "corrupted_elite_charge_preparing"
const CORRUPTED_ELITE_CHARGING_META: String = "corrupted_elite_charging"
const CORRUPTED_ELITE_CHARGE_DIRECTION_META: String = "corrupted_elite_charge_direction"
const CORRUPTED_SPREAD_ANGLE_DEGREES: float = 35.0

var debuff_manager: EnemyDebuffManager
var is_dead: bool = false
var is_elite: bool = false
var drop_rate_multiplier: float = 1.0
var _corrupted_elite_drop_emitted: bool = false

var health_bar_shown: bool = false
var health_bar: Node2D
var progress_bar: ProgressBar
var health_bar_offset: Vector2 = Vector2(-15, -10)
var health_bar_tween_duration: float = 0.3
var _health_bar_tween: Tween = null
var _health_bar_tween_target: float = -1.0

var player_hit_emit_self: bool = false
var use_debuff_take_damage_multiplier: bool = true
var check_action_disabled_on_body_entered: bool = true

const CONTACT_DAMAGE_INTERVAL: float = 0.7
const CONTACT_DAMAGE_CHECK_INTERVAL: float = 0.1
const CONTACT_COLLISION_EXPAND_PIXELS: float = 1.0
const OFFSCREEN_SPEED_MARGIN_PIXELS: float = 50.0
const OFFSCREEN_SPEED_MULTIPLIER_MIN: float = 1 # 超出视野后，移动速度额外提升100%~300%（随机）
const OFFSCREEN_SPEED_MULTIPLIER_MAX: float = 5.0
const RANDOM_SPEED_VARIATION_MIN: float = 0.85
const RANDOM_SPEED_VARIATION_MAX: float = 1.15
const PLAYER_DAMAGE_VARIANCE_MIN: float = 0.95
const PLAYER_DAMAGE_VARIANCE_MAX: float = 1.05
const CAMERA_WANDER_VIEW_MARGIN: float = 48.0

# 离屏优化：缓存每帧的离屏状态，避免重复计算
const OFFSCREEN_OPTIMIZATION_MARGIN: float = 40.0
var _is_offscreen: bool = false
var _movement_bounds_cache_frame: int = -1
var _movement_bounds_cache: Rect2 = Rect2()

var movement_speed_variation_multiplier: float = 1.0
var _hit_flash_tween: Tween = null
var _hit_flash_frame: int = -1
var _hit_flash_base_modulate: Color = Color.WHITE
var _spawn_protection_active: bool = false
var _property_name_cache: Dictionary = {}
var _property_name_cache_ready: bool = false
var _action_skip_cache_frame: int = -1
var _action_skip_cache_value: bool = false
var _last_contact_damage_msec: int = -1000000
var _contact_damage_timer: Timer = null
var _contact_player_body: CharacterBody2D = null

const HIT_FLASH_MAX_PER_FRAME: int = 12
static var _hit_flash_budget_frame: int = -1
static var _hit_flash_budget_count: int = 0

signal debuff_applied(debuff_id: String)

func setup_monster_base(add_elite_group: bool = false) -> void:
	CharacterEffects.configure_enemy_collision(self)
	_expand_contact_collision_shape()
	_setup_contact_overlap_signals()
	_setup_contact_damage_timer()
	if add_elite_group:
		add_to_group("elite")
	_setup_debuff_manager()
	_setup_common_movement_data()
	# Boss出场保护：1.5秒内不对玩家造成碰撞伤害
	if is_in_group("boss"):
		start_spawn_protection()

func _setup_debuff_manager() -> void:
	if debuff_manager != null and is_instance_valid(debuff_manager):
		return
	debuff_manager = EnemyDebuffManager.new(self )
	add_child(debuff_manager)
	var debuff_callable = Callable(debuff_manager, "add_debuff")
	if not debuff_applied.is_connected(debuff_callable):
		debuff_applied.connect(debuff_callable)

func _setup_common_movement_data() -> void:
	_randomize_base_speed_if_available()

func _has_property(property_name: String) -> bool:
	if not _property_name_cache_ready:
		_property_name_cache.clear()
		for property_info: Dictionary in get_property_list():
			_property_name_cache[String(property_info.get("name", ""))] = true
		_property_name_cache_ready = true
	return _property_name_cache.has(property_name)

func clear_property_name_cache() -> void:
	_property_name_cache.clear()
	_property_name_cache_ready = false

func _has_property_uncached(property_name: String) -> bool:
	for property_info: Dictionary in get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

func _randomize_base_speed_if_available() -> void:
	if is_in_group("boss") or not _has_property("base_speed"):
		return
	movement_speed_variation_multiplier = randf_range(RANDOM_SPEED_VARIATION_MIN, RANDOM_SPEED_VARIATION_MAX)
	var randomized_base_speed: float = float(get("base_speed")) * movement_speed_variation_multiplier
	set("base_speed", randomized_base_speed)
	if _has_property("speed"):
		set("speed", randomized_base_speed)

func _is_beyond_camera_margin(margin_pixels: float = OFFSCREEN_SPEED_MARGIN_PIXELS) -> bool:
	if is_in_group("boss"):
		return false
	var _vp := get_viewport()
	var camera := _vp.get_camera_2d() if _vp else null
	if camera == null:
		return false
	# 将怪物的全局坐标转换为相对于相机的偏移
	var cam_center := camera.get_screen_center_position()
	var offset := global_position - cam_center
	var zoom := camera.zoom
	# 将世界坐标偏移转换为屏幕像素偏移
	var screen_offset := Vector2(offset.x * zoom.x, offset.y * zoom.y)
	var screen_size := get_viewport().get_visible_rect().size
	var half_screen := screen_size / 2.0
	# 检查屏幕像素偏移是否超出屏幕范围（加边距）
	return (
		screen_offset.x < -half_screen.x - margin_pixels
		or screen_offset.x > half_screen.x + margin_pixels
		or screen_offset.y < -half_screen.y - margin_pixels
		or screen_offset.y > half_screen.y + margin_pixels
	)

## 更新离屏缓存（每帧调用一次，供子类判断是否跳过非必要逻辑）
func update_offscreen_status() -> void:
	_is_offscreen = _is_beyond_camera_margin(OFFSCREEN_OPTIMIZATION_MARGIN)

func get_effective_move_speed(base_speed_value: float, extra_multiplier: float = 1.0, apply_offscreen_boost: bool = true) -> float:
	var speed_multiplier := extra_multiplier
	# 应用关卡内敌人移速倍率
	speed_multiplier *= PC.enemy_move_speed_multiplier
	if debuff_manager != null and is_instance_valid(debuff_manager):
		speed_multiplier *= debuff_manager.get_speed_multiplier()
	# 只在已确认离屏（>40px）时才进一步检测50px阈值
	if apply_offscreen_boost and _is_offscreen and _is_beyond_camera_margin():
		speed_multiplier *= randf_range(OFFSCREEN_SPEED_MULTIPLIER_MIN, OFFSCREEN_SPEED_MULTIPLIER_MAX)
	return base_speed_value * speed_multiplier

func apply_debuff_effect(debuff_id: String):
	emit_signal("debuff_applied", debuff_id)

func grant_kill_point_rewards(point_gain: int) -> void:
	_emit_corrupted_elite_guaranteed_drop_once()
	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.has_method("add_kill_rewards"):
		current_scene.add_kill_rewards(self, point_gain)
		return
	if current_scene != null:
		for property_info in current_scene.get_property_list():
			if String(property_info.get("name", "")) == "point":
				current_scene.set("point", int(current_scene.get("point")) + point_gain)
				break
	Global.total_points += point_gain

func is_corrupted_elite_monster() -> bool:
	return get_meta("is_corrupted_elite", false) == true or is_in_group("core_corrupted_elite")

func is_corrupted_elite_charge_motion_locked() -> bool:
	return get_meta(CORRUPTED_ELITE_CHARGE_PREPARING_META, false) == true or get_meta(CORRUPTED_ELITE_CHARGING_META, false) == true

func _emit_corrupted_elite_guaranteed_drop_once() -> void:
	if _corrupted_elite_drop_emitted:
		return
	if not is_corrupted_elite_monster():
		return
	_corrupted_elite_drop_emitted = true
	var drop_id := str(get_meta("corrupted_elite_guaranteed_drop_id", CORRUPTED_ELITE_DEFAULT_DROP_ID))
	if drop_id.is_empty():
		drop_id = CORRUPTED_ELITE_DEFAULT_DROP_ID
	Global.emit_signal("drop_out_item", drop_id, 1, global_position)

func fire_monster_projectile(direction: Vector2, spawn_position: Vector2 = Vector2.INF, projectile_speed_multiplier: float = 1.0) -> Area2D:
	if direction.length_squared() <= 0.001 or get_tree() == null:
		return null
	var projectile_parent := _get_projectile_parent()
	if projectile_parent == null:
		return null
	var resolved_spawn_position := global_position if spawn_position == Vector2.INF else spawn_position
	var projectile: Area2D = null
	if Global.frog_attack_pool:
		projectile = Global.frog_attack_pool.acquire(projectile_parent) as Area2D
	else:
		projectile = MONSTER_FIREBALL_SCENE.instantiate() as Area2D
	if projectile == null:
		return null
	var damage_value = get("atk")
	var projectile_atk: float = SettingMoster.frog("atk")
	if damage_value != null:
		projectile_atk = float(damage_value)
	if projectile.has_method("setup_projectile"):
		projectile.setup_projectile(resolved_spawn_position, direction.normalized(), projectile_atk)
	else:
		if projectile.get_parent() == null:
			projectile_parent.add_child(projectile)
		projectile.global_position = resolved_spawn_position
		if projectile.get("atk") != null:
			projectile.set("atk", projectile_atk)
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction.normalized())
		if projectile.has_method("play_animation"):
			projectile.play_animation("fire")
	if not is_equal_approx(projectile_speed_multiplier, 1.0):
		var projectile_speed = projectile.get("speed")
		if projectile_speed != null:
			projectile.set("speed", float(projectile_speed) * projectile_speed_multiplier)
		else:
			var bullet_speed = projectile.get("bullet_speed")
			if bullet_speed != null:
				projectile.set("bullet_speed", float(bullet_speed) * projectile_speed_multiplier)
	return projectile

func _get_projectile_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	var parent := get_parent()
	if parent != null:
		return parent
	return tree.root

func fire_corrupted_spread_burst(base_direction: Vector2, repeat_delay: float = 0.5, projectile_speed_multiplier: float = 1.0) -> void:
	if base_direction.length_squared() <= 0.001:
		return
	var shoot_direction := base_direction.normalized()
	_fire_corrupted_three_way(shoot_direction, projectile_speed_multiplier)
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(repeat_delay).timeout.connect(Callable(self, "_fire_corrupted_three_way_if_alive").bind(shoot_direction, projectile_speed_multiplier), CONNECT_ONE_SHOT)

func fire_corrupted_perpendicular_rounds(charge_direction: Vector2, rounds: int = 3, interval: float = 0.2) -> void:
	if charge_direction.length_squared() <= 0.001:
		return
	var shoot_direction := charge_direction.normalized()
	for round_index in range(maxi(1, rounds)):
		if round_index == 0:
			_fire_corrupted_perpendicular_pair(shoot_direction)
			continue
		var tree := get_tree()
		if tree == null:
			return
		tree.create_timer(interval * float(round_index)).timeout.connect(Callable(self, "_fire_corrupted_perpendicular_pair_if_alive").bind(shoot_direction), CONNECT_ONE_SHOT)

func fire_corrupted_radial_bullet_ring(count: int = 8) -> void:
	var bullet_count := maxi(1, count)
	for i in range(bullet_count):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / float(bullet_count))
		fire_monster_projectile(direction)

func _fire_corrupted_three_way(base_direction: Vector2, projectile_speed_multiplier: float = 1.0) -> void:
	fire_monster_projectile(base_direction.rotated(deg_to_rad(-CORRUPTED_SPREAD_ANGLE_DEGREES)), Vector2.INF, projectile_speed_multiplier)
	fire_monster_projectile(base_direction, Vector2.INF, projectile_speed_multiplier)
	fire_monster_projectile(base_direction.rotated(deg_to_rad(CORRUPTED_SPREAD_ANGLE_DEGREES)), Vector2.INF, projectile_speed_multiplier)

func _fire_corrupted_perpendicular_pair(charge_direction: Vector2) -> void:
	var perpendicular := charge_direction.orthogonal().normalized()
	fire_monster_projectile(perpendicular)
	fire_monster_projectile(-perpendicular)

func _fire_corrupted_three_way_if_alive(base_direction: Vector2, projectile_speed_multiplier: float = 1.0) -> void:
	if is_dead:
		return
	_fire_corrupted_three_way(base_direction, projectile_speed_multiplier)

func _fire_corrupted_perpendicular_pair_if_alive(charge_direction: Vector2) -> void:
	if is_dead:
		return
	_fire_corrupted_perpendicular_pair(charge_direction)

func apply_knockback(direction: Vector2, force: float):
	var tween = create_tween()
	tween.tween_property(self , "position", global_position + direction * force, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_health_bar_percentage() -> float:
	var max_hp = float(get("hpMax"))
	if max_hp <= 0.0:
		return 0.0
	return clamp((float(get("hp")) / max_hp) * 100.0, 0.0, 100.0)

func show_health_bar() -> void:
	if health_bar == null or not is_instance_valid(health_bar):
		health_bar = HEALTH_BAR_SCENE.instantiate()
		add_child(health_bar)
		health_bar.z_index = 100
		progress_bar = health_bar.get_node("HPBar") as ProgressBar
		if progress_bar:
			progress_bar.top_level = true
			progress_bar.value = get_health_bar_percentage()
		health_bar_shown = true
	if progress_bar and progress_bar.is_inside_tree():
		progress_bar.position = global_position + health_bar_offset
		var target_value_hp = get_health_bar_percentage()
		if abs(_health_bar_tween_target - target_value_hp) < 0.01:
			return
		_health_bar_tween_target = target_value_hp
		if _health_bar_tween != null and _health_bar_tween.is_valid():
			_health_bar_tween.kill()
		_health_bar_tween = create_tween()
		_health_bar_tween.tween_property(progress_bar, "value", target_value_hp, health_bar_tween_duration)

func free_health_bar() -> void:
	if _health_bar_tween != null and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
	_health_bar_tween = null
	_health_bar_tween_target = -1.0
	if health_bar != null and is_instance_valid(health_bar) and health_bar.is_inside_tree():
		health_bar.queue_free()
	health_bar = null
	progress_bar = null
	health_bar_shown = false

func is_alive_for_action_logic() -> bool:
	if is_dead:
		return false
	if _has_property("hp") and float(get("hp")) <= 0.0:
		return false
	return true

func should_skip_actions_for_debuff() -> bool:
	var current_frame := Engine.get_physics_frames()
	if _action_skip_cache_frame == current_frame:
		return _action_skip_cache_value
	_action_skip_cache_frame = current_frame
	_action_skip_cache_value = false
	if is_alive_for_action_logic():
		_action_skip_cache_value = debuff_manager != null and is_instance_valid(debuff_manager) and debuff_manager.is_action_disabled()
	return _action_skip_cache_value

func move_away_from_dead_player(delta: float, base_speed_value: float, sprite_node: Node = null, flip_h_when_moving_right: bool = true, extra_multiplier: float = 1.0) -> bool:
	if not CharacterEffects.is_player_dead_or_game_over():
		return false
	var scatter_direction := CharacterEffects.get_player_death_scatter_direction(self)
	if scatter_direction == Vector2.ZERO:
		return false
	var scatter_speed := get_effective_move_speed(base_speed_value, extra_multiplier)
	position += scatter_direction * scatter_speed * delta
	if sprite_node != null and is_instance_valid(sprite_node):
		var flip_value := (scatter_direction.x > 0.0) if flip_h_when_moving_right else (scatter_direction.x < 0.0)
		CharacterEffects.set_enemy_flip_h(self, sprite_node, flip_value)
	return true

func get_scene_movement_bounds(padding: float = 12.0) -> Rect2:
	var current_frame := Engine.get_physics_frames()
	if _movement_bounds_cache_frame == current_frame:
		return _movement_bounds_cache
	_movement_bounds_cache_frame = current_frame
	_movement_bounds_cache = _build_scene_movement_bounds(padding)
	return _movement_bounds_cache

func clamp_self_to_scene_bounds(padding: float = 12.0) -> bool:
	var bounds := get_scene_movement_bounds(padding)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return false
	var clamped_position := global_position.clamp(bounds.position, bounds.position + bounds.size)
	if clamped_position.is_equal_approx(global_position):
		return false
	global_position = clamped_position
	return true

func steer_direction_toward_scene_bounds_center(current_direction: Vector2, random_degrees: float = 30.0, padding: float = 12.0) -> Vector2:
	var bounds := get_scene_movement_bounds(padding)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return current_direction
	var center := bounds.position + bounds.size * 0.5
	var to_center := center - global_position
	if to_center.length_squared() <= 0.0001:
		return current_direction
	return to_center.normalized().rotated(deg_to_rad(randf_range(-random_degrees, random_degrees)))

func get_camera_visible_world_rect(margin_pixels: float = 0.0) -> Rect2:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d() if viewport != null else null
	if camera == null:
		return Rect2()
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var zoom := camera.zoom
	var visible_size := Vector2(
		viewport_size.x / maxf(zoom.x, 0.01),
		viewport_size.y / maxf(zoom.y, 0.01)
	)
	var margin := Vector2(
		margin_pixels / maxf(zoom.x, 0.01),
		margin_pixels / maxf(zoom.y, 0.01)
	)
	var rect := Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size)
	if margin_pixels > 0.0:
		rect = rect.grow_individual(-margin.x, -margin.y, -margin.x, -margin.y)
	return rect if rect.size.x > 0.0 and rect.size.y > 0.0 else Rect2()

func get_camera_wander_bounds(margin_pixels: float = CAMERA_WANDER_VIEW_MARGIN, scene_padding: float = 16.0) -> Rect2:
	var visible_rect := get_camera_visible_world_rect(margin_pixels)
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return get_scene_movement_bounds(scene_padding)
	var scene_bounds := get_scene_movement_bounds(scene_padding)
	if scene_bounds.size.x <= 0.0 or scene_bounds.size.y <= 0.0:
		return visible_rect
	var intersection := visible_rect.intersection(scene_bounds)
	return intersection if intersection.size.x > 0.0 and intersection.size.y > 0.0 else visible_rect

func is_position_outside_rect(world_position: Vector2, rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return not rect.has_point(world_position)

func choose_camera_wander_direction(current_direction: Vector2 = Vector2.LEFT, random_degrees: float = 35.0, margin_pixels: float = CAMERA_WANDER_VIEW_MARGIN, scene_padding: float = 16.0) -> Vector2:
	var bounds := get_camera_wander_bounds(margin_pixels, scene_padding)
	return choose_direction_to_rect(bounds, current_direction, random_degrees)

func choose_direction_to_rect(bounds: Rect2, current_direction: Vector2 = Vector2.LEFT, random_degrees: float = 35.0) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		var angle := randf() * TAU
		return Vector2(cos(angle), sin(angle))
	var target := Vector2(
		randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
		randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
	)
	var to_target := target - global_position
	if to_target.length_squared() > 0.0001:
		return to_target.normalized()
	if current_direction.length_squared() > 0.0001:
		return current_direction.normalized().rotated(deg_to_rad(randf_range(-random_degrees, random_degrees)))
	var angle := randf() * TAU
	return Vector2(cos(angle), sin(angle))

func _build_scene_movement_bounds(padding: float) -> Rect2:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return Rect2()
	var boundary_node := tree.current_scene.find_child("Boundry", true, false) as Node2D
	if boundary_node == null:
		var camera := get_viewport().get_camera_2d() if get_viewport() != null else null
		if camera != null:
			return _build_camera_limit_bounds(camera, padding)
		return Rect2()
	var values := _compute_world_boundary_values(boundary_node)
	if values.is_empty():
		return Rect2()
	var min_x := float(values.get("min_x", 0.0)) + padding
	var max_x := float(values.get("max_x", 0.0)) - padding
	var min_y := float(values.get("min_y", 0.0)) + padding
	var max_y := float(values.get("max_y", 0.0)) - padding
	if max_x <= min_x or max_y <= min_y:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _build_camera_limit_bounds(camera: Camera2D, padding: float) -> Rect2:
	if camera.limit_right <= camera.limit_left or camera.limit_bottom <= camera.limit_top:
		return Rect2()
	var min_x := float(camera.limit_left) + padding
	var max_x := float(camera.limit_right) - padding
	var min_y := float(camera.limit_top) + padding
	var max_y := float(camera.limit_bottom) - padding
	if max_x <= min_x or max_y <= min_y:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _compute_world_boundary_values(boundary_node: Node2D) -> Dictionary:
	var result: Dictionary = {}
	for child in boundary_node.get_children():
		if child is StaticBody2D:
			_read_world_boundary_shape(child as StaticBody2D, result)
	return result

func _read_world_boundary_shape(body: StaticBody2D, result: Dictionary) -> void:
	for child in body.get_children():
		var col_shape := child as CollisionShape2D
		if col_shape == null or col_shape.shape == null or not col_shape.shape is WorldBoundaryShape2D:
			continue
		var wb_shape := col_shape.shape as WorldBoundaryShape2D
		var normal := wb_shape.normal.normalized()
		var boundary_pos := col_shape.global_position + normal * wb_shape.distance
		if abs(normal.y) > abs(normal.x):
			var y_val := boundary_pos.y
			if normal.y > 0.0:
				result["min_y"] = y_val if not result.has("min_y") else maxf(float(result["min_y"]), y_val)
			else:
				result["max_y"] = y_val if not result.has("max_y") else minf(float(result["max_y"]), y_val)
		else:
			var x_val := boundary_pos.x
			if normal.x > 0.0:
				result["min_x"] = x_val if not result.has("min_x") else maxf(float(result["min_x"]), x_val)
			else:
				result["max_x"] = x_val if not result.has("max_x") else minf(float(result["max_x"]), x_val)

func _expand_contact_collision_shape() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return
	if collision_shape.has_meta("contact_collision_expanded"):
		return
	var shape := collision_shape.shape
	if shape is CircleShape2D:
		var circle := shape.duplicate() as CircleShape2D
		circle.radius += CONTACT_COLLISION_EXPAND_PIXELS
		collision_shape.shape = circle
	elif shape is CapsuleShape2D:
		var capsule := shape.duplicate() as CapsuleShape2D
		capsule.radius += CONTACT_COLLISION_EXPAND_PIXELS
		capsule.height += CONTACT_COLLISION_EXPAND_PIXELS * 2.0
		collision_shape.shape = capsule
	elif shape is RectangleShape2D:
		var rectangle := shape.duplicate() as RectangleShape2D
		rectangle.size += Vector2.ONE * CONTACT_COLLISION_EXPAND_PIXELS * 2.0
		collision_shape.shape = rectangle
	collision_shape.set_meta("contact_collision_expanded", true)

func _setup_contact_damage_timer() -> void:
	if _contact_damage_timer != null and is_instance_valid(_contact_damage_timer):
		return
	_contact_damage_timer = Timer.new()
	_contact_damage_timer.wait_time = CONTACT_DAMAGE_CHECK_INTERVAL
	_contact_damage_timer.one_shot = false
	_contact_damage_timer.autostart = true
	add_child(_contact_damage_timer)
	_contact_damage_timer.timeout.connect(_check_overlapping_player_contact_damage)

func _setup_contact_overlap_signals() -> void:
	if not body_exited.is_connected(_on_contact_body_exited):
		body_exited.connect(_on_contact_body_exited)

func _check_overlapping_player_contact_damage() -> void:
	if _contact_player_body == null or not is_instance_valid(_contact_player_body):
		_contact_player_body = null
		return
	handle_common_body_entered(_contact_player_body)

func handle_common_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_contact_player_body = body
	if check_action_disabled_on_body_entered and should_skip_actions_for_debuff():
		return
	# 出场保护期间不对玩家造成碰撞伤害
	if _spawn_protection_active:
		return
	if body is CharacterBody2D and not is_dead and not PC.invincible:
		var now_msec := Time.get_ticks_msec()
		if now_msec - _last_contact_damage_msec < int(CONTACT_DAMAGE_INTERVAL * 1000.0):
			return
		var actual_damage = float(get("atk")) * (1.0 - PC.damage_reduction_rate)
		if use_debuff_take_damage_multiplier and debuff_manager != null and is_instance_valid(debuff_manager):
			actual_damage *= debuff_manager.get_take_damage_multiplier()
		PC.player_hit(int(actual_damage), self , "")
		if _is_currently_charging_for_contact():
			CharacterEffects.apply_player_charge_side_knockback(body, _get_current_charge_direction_for_contact(body), global_position)
		_last_contact_damage_msec = now_msec

func _is_currently_charging_for_contact() -> bool:
	return get_meta(CORRUPTED_ELITE_CHARGING_META, false) == true or (_has_property("is_charging") and bool(get("is_charging")))

func _get_current_charge_direction_for_contact(body: Node2D) -> Vector2:
	if has_meta(CORRUPTED_ELITE_CHARGE_DIRECTION_META):
		var meta_direction = get_meta(CORRUPTED_ELITE_CHARGE_DIRECTION_META)
		if meta_direction is Vector2:
			var meta_charge_direction := meta_direction as Vector2
			if meta_charge_direction.length_squared() > 0.0001:
				return meta_charge_direction.normalized()
	if _has_property("charge_direction"):
		var charge_dir = get("charge_direction")
		if charge_dir is Vector2:
			var property_charge_direction := charge_dir as Vector2
			if property_charge_direction.length_squared() > 0.0001:
				return property_charge_direction.normalized()
	if _has_property("charge_indicator_direction"):
		var indicator_dir = get("charge_indicator_direction")
		if indicator_dir is Vector2:
			var indicator_charge_direction := indicator_dir as Vector2
			if indicator_charge_direction.length_squared() > 0.0001:
				return indicator_charge_direction.normalized()
	var fallback := body.global_position - global_position
	return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector2.RIGHT

func _on_body_entered(body: Node2D) -> void:
	handle_common_body_entered(body)

func _on_contact_body_exited(body: Node2D) -> void:
	if body == _contact_player_body:
		_contact_player_body = null

func release_round_sword_qi() -> void:
	var spawn_position = global_position
	var bullet_size = Global.get_attack_range_multiplier()
	var angles = [90.0, 270.0]
	for i in range(8):
		var angle = (360.0 / 8.0) * i
		if not (angle == 90.0 or angle == 270.0):
			angles.append(angle)
	for angle_deg in angles:
		var sword_qi = ROUND_SWORD_QI_BULLET_SCENE.instantiate()
		sword_qi.set_bullet_scale(Vector2(bullet_size, bullet_size))
		var direction = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
		sword_qi.set_direction(direction)
		sword_qi.position = spawn_position
		sword_qi.penetration_count = PC.swordQi_penetration_count
		sword_qi.is_other_sword_wave = true
		get_tree().current_scene.add_child(sword_qi)

func is_dot_damage_type(damage_type: String) -> bool:
	return damage_type in ["bleed", "burn", "electrified", "corrosion", "corrosion2", "posion"]

func get_damage_popup_type(is_crit: bool, is_summon: bool, override_type: int = -1) -> int:
	if override_type >= 0:
		return override_type
	if is_summon:
		return 4
	if is_crit:
		return 2
	return 1

func get_damage_popup_position(randomize_offset: bool = false) -> Vector2:
	var popup_position = global_position - Vector2(35, 20)
	if randomize_offset:
		popup_position += Vector2(randf_range(-15, 15), randf_range(-15, 15))
	return popup_position

func can_take_common_damage(require_damage_range_check: bool = false) -> bool:
	if is_dead:
		return false
	if require_damage_range_check and has_method("_is_monster_in_damage_range"):
		var in_range = call("_is_monster_in_damage_range")
		if not in_range:
			return false
	return true

func get_player_total_damage_multiplier() -> float:
	var damage_deal_multiplier := 1.0
	if typeof(PC) != TYPE_NIL and PC != null:
		damage_deal_multiplier = PC.damage_deal_multiplier
	return Faze.get_final_damage_multiplier() * damage_deal_multiplier

func apply_common_final_damage_multipliers(damage: float) -> float:
	if damage <= 0.0:
		return 0.0
	var global_buff_bonus := BulletCalculator.get_global_buff_damage_multiplier() - 1.0
	var additive_bonus := Faze.get_final_damage_additive_bonus() + global_buff_bonus
	var stage_boss_multiplier := Global.get_stage_boss_player_damage_multiplier()
	var damage_deal_multiplier := 1.0
	if typeof(PC) != TYPE_NIL and PC != null:
		damage_deal_multiplier = PC.damage_deal_multiplier
	return damage * maxf(0.0, 1.0 + additive_bonus) * stage_boss_multiplier * damage_deal_multiplier

func apply_player_outgoing_damage_variance(damage: float) -> float:
	if damage <= 0.0:
		return damage
	return damage * randf_range(PLAYER_DAMAGE_VARIANCE_MIN, PLAYER_DAMAGE_VARIANCE_MAX)

func get_common_bullet_damage_value(base_damage: float) -> int:
	var final_damage = apply_common_final_damage_multipliers(base_damage)
	if debuff_manager != null and is_instance_valid(debuff_manager):
		final_damage *= debuff_manager.get_damage_multiplier()
	final_damage = apply_player_outgoing_damage_variance(final_damage)
	return int(final_damage)

func get_non_bullet_damage_value(damage: float, use_debuff_multiplier: bool = true) -> int:
	var final_damage = Global.apply_enemy_damage_bonus(damage, self )
	final_damage = apply_common_final_damage_multipliers(final_damage)
	if use_debuff_multiplier and debuff_manager != null and is_instance_valid(debuff_manager):
		final_damage *= debuff_manager.get_damage_multiplier()
	return int(final_damage)


func can_apply_interval_damage(last_time_property: String, interval: float, time_scale: float = 1.0) -> bool:
	var current_time = (Time.get_ticks_msec() / 1000.0) * time_scale
	var last_time = float(get(last_time_property))
	if current_time - last_time < interval:
		return false
	set(last_time_property, current_time)
	return true

func apply_common_take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String, options: Dictionary = {}) -> Dictionary:
	var result = {
		"applied": false,
		"final_damage": 0,
		"is_lethal": false,
	}
	var require_damage_range_check = options.get("require_damage_range_check", false)
	if not can_take_common_damage(require_damage_range_check):
		return result

	var use_debuff_multiplier = options.get("use_debuff_multiplier", true)
	# 修习树武器篇伤害加成（根据 damage_type 对应的武器分类动态获取）
	var study_weapon_bonus = SettingStudyTreeUp.get_total_damage_bonus(damage_type)
	var adjusted_damage = float(damage) * (1.0 + study_weapon_bonus)
	var final_damage = get_non_bullet_damage_value(adjusted_damage, use_debuff_multiplier)
	if damage_type != "bullet":
		final_damage = int(apply_player_outgoing_damage_variance(float(final_damage)))
	result["applied"] = true
	result["final_damage"] = final_damage

	var previous_hp: float = float(get("hp"))
	var actual_damage: float = minf(float(final_damage), maxf(previous_hp, 0.0))

	if options.get("update_boss_hp_bar", false):
		Global.emit_signal("boss_hp_bar_take_damage", actual_damage)

	var current_hp: float = previous_hp - float(final_damage)
	set("hp", current_hp)
	result["is_lethal"] = current_hp <= 0

	var show_damage_popup = options.get("show_damage_popup", true)
	if show_damage_popup and not is_dot_damage_type(damage_type):
		var popup_type_override = int(options.get("popup_type_override", -1))
		var popup_type = get_damage_popup_type(is_crit, is_summon, popup_type_override)
		var randomize_popup_offset = options.get("randomize_popup_offset", false)
		Global.emit_signal("monster_damage", popup_type, actual_damage, get_damage_popup_position(randomize_popup_offset), damage_type)

	if options.get("play_hit_animation", false) and current_hp > 0 and not is_dot_damage_type(damage_type):
		Global.play_hit_anime(position, is_crit)

	# 击中白色闪烁效果（非DOT伤害才触发）
	if not is_dot_damage_type(damage_type):
		_play_hit_flash()

	return result

func drop_items_from_table(itemdrop: Dictionary) -> void:
	if itemdrop == null:
		return
	for item_id in itemdrop:
		var drop_entry = itemdrop[item_id]
		var drop_chance := 0.0
		var drop_quantity := 1
		if typeof(drop_entry) == TYPE_DICTIONARY:
			drop_chance = float(drop_entry.get("chance", 0.0))
			drop_quantity = int(drop_entry.get("quantity", 1))
		else:
			drop_chance = float(drop_entry)
		if randf() <= drop_chance:
			Global.emit_signal("drop_out_item", item_id, max(1, drop_quantity), global_position)

func _play_hit_flash() -> void:
	# 防止同一帧内重复闪烁（子弹伤害可能同时经过 BulletCalculator 和 apply_common_take_damage）
	var current_frame = Engine.get_process_frames()
	if _hit_flash_frame == current_frame:
		return
	if not _consume_hit_flash_budget(current_frame):
		return
	_hit_flash_frame = current_frame
	var sprite = _get_hit_flash_sprite()
	if sprite == null:
		return
	# 如果有正在进行的闪烁动画，kill掉但不更新底色（底色已由首次闪白记录）
	# 如果没有活动动画，说明是全新的闪白，记录当前modulate作为底色
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	else:
		_hit_flash_base_modulate = sprite.modulate
	# 白色闪烁：RGB > 1 使精灵过曝变白（modulate是乘法，值越大越亮）
	sprite.modulate = Color(3, 3, 3, 1)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(sprite, "modulate", _hit_flash_base_modulate, 0.25)

static func _consume_hit_flash_budget(frame: int) -> bool:
	if frame != _hit_flash_budget_frame:
		_hit_flash_budget_frame = frame
		_hit_flash_budget_count = 0
	if _hit_flash_budget_count >= HIT_FLASH_MAX_PER_FRAME:
		return false
	_hit_flash_budget_count += 1
	return true

## 获取用于闪烁效果的精灵节点，子类可覆盖以适配不同节点名
func _get_hit_flash_sprite() -> CanvasItem:
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite != null:
		return sprite
	# 兼容Boss节点名
	sprite = get_node_or_null("BossStone")
	if sprite != null:
		return sprite
	sprite = get_node_or_null("BossA")
	if sprite != null:
		return sprite
	return null

## 启动出场保护，在指定时间内不对玩家造成碰撞伤害（Boss专用）
func start_spawn_protection(duration: float = 1) -> void:
	_spawn_protection_active = true
	get_tree().create_timer(duration).timeout.connect(Callable(self, "_finish_spawn_protection"), CONNECT_ONE_SHOT)

func _finish_spawn_protection() -> void:
	_spawn_protection_active = false

## 子弹命中闪烁回调，由 BulletCalculator.handle_bullet_collision_full 调用
func on_bullet_hit_response() -> void:
	_play_hit_flash()
