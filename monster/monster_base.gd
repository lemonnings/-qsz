extends Area2D
class_name MonsterBase

const HEALTH_BAR_SCENE = preload("res://Scenes/global/hp_bar.tscn")
const ROUND_SWORD_QI_BULLET_SCENE = preload("res://Scenes/bullet.tscn")
const MONSTER_FIREBALL_SCENE = preload("res://Scenes/moster/frog_attack.tscn")
const CORRUPTED_ELITE_DEFAULT_DROP_ID: String = "item_102"
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

const OFFSCREEN_SPEED_MARGIN_PIXELS: float = 50.0
const OFFSCREEN_SPEED_MULTIPLIER_MIN: float = 1 # 超出视野后，移动速度额外提升100%~300%（随机）
const OFFSCREEN_SPEED_MULTIPLIER_MAX: float = 5.0
const RANDOM_SPEED_VARIATION_MIN: float = 0.85
const RANDOM_SPEED_VARIATION_MAX: float = 1.15

# 离屏优化：缓存每帧的离屏状态，避免重复计算
const OFFSCREEN_OPTIMIZATION_MARGIN: float = 40.0
var _is_offscreen: bool = false

var movement_speed_variation_multiplier: float = 1.0
var _hit_flash_tween: Tween = null
var _hit_flash_frame: int = -1
var _hit_flash_base_modulate: Color = Color.WHITE
var _spawn_protection_active: bool = false

const HIT_FLASH_MAX_PER_FRAME: int = 12
static var _hit_flash_budget_frame: int = -1
static var _hit_flash_budget_count: int = 0

signal debuff_applied(debuff_id: String)

func setup_monster_base(add_elite_group: bool = false) -> void:
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
	for property_info in get_property_list():
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

func fire_monster_projectile(direction: Vector2, spawn_position: Vector2 = Vector2.INF) -> Area2D:
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

func fire_corrupted_spread_burst(base_direction: Vector2, repeat_delay: float = 0.5) -> void:
	if base_direction.length_squared() <= 0.001:
		return
	var shoot_direction := base_direction.normalized()
	_fire_corrupted_three_way(shoot_direction)
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(repeat_delay).timeout.connect(Callable(self, "_fire_corrupted_three_way_if_alive").bind(shoot_direction), CONNECT_ONE_SHOT)

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

func _fire_corrupted_three_way(base_direction: Vector2) -> void:
	fire_monster_projectile(base_direction.rotated(deg_to_rad(-CORRUPTED_SPREAD_ANGLE_DEGREES)))
	fire_monster_projectile(base_direction)
	fire_monster_projectile(base_direction.rotated(deg_to_rad(CORRUPTED_SPREAD_ANGLE_DEGREES)))

func _fire_corrupted_perpendicular_pair(charge_direction: Vector2) -> void:
	var perpendicular := charge_direction.orthogonal().normalized()
	fire_monster_projectile(perpendicular)
	fire_monster_projectile(-perpendicular)

func _fire_corrupted_three_way_if_alive(base_direction: Vector2) -> void:
	if is_dead:
		return
	_fire_corrupted_three_way(base_direction)

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
	if not is_alive_for_action_logic():
		return false
	return debuff_manager != null and is_instance_valid(debuff_manager) and debuff_manager.is_action_disabled()

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
		sprite_node.set("flip_h", flip_value)
	return true

func handle_common_body_entered(body: Node2D) -> void:
	if check_action_disabled_on_body_entered and should_skip_actions_for_debuff():
		return
	# 出场保护期间不对玩家造成碰撞伤害
	if _spawn_protection_active:
		return
	if body is CharacterBody2D and not is_dead and not PC.invincible:
		var actual_damage = float(get("atk")) * (1.0 - PC.damage_reduction_rate)
		if use_debuff_take_damage_multiplier and debuff_manager != null and is_instance_valid(debuff_manager):
			actual_damage *= debuff_manager.get_take_damage_multiplier()
		PC.player_hit(int(actual_damage), self , "")

func _on_body_entered(body: Node2D) -> void:
	handle_common_body_entered(body)

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
	var final_damage = BulletCalculator.apply_global_buff_effects(damage)
	final_damage *= get_player_total_damage_multiplier()
	return final_damage

func get_common_bullet_damage_value(base_damage: float) -> int:
	var final_damage = apply_common_final_damage_multipliers(base_damage)
	if debuff_manager != null and is_instance_valid(debuff_manager):
		final_damage *= debuff_manager.get_damage_multiplier()
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
	result["applied"] = true
	result["final_damage"] = final_damage

	if options.get("update_boss_hp_bar", false):
		Global.emit_signal("boss_hp_bar_take_damage", final_damage)

	var current_hp = float(get("hp")) - final_damage
	set("hp", current_hp)
	result["is_lethal"] = current_hp <= 0

	var show_damage_popup = options.get("show_damage_popup", true)
	if show_damage_popup and not is_dot_damage_type(damage_type):
		var popup_type_override = int(options.get("popup_type_override", -1))
		var popup_type = get_damage_popup_type(is_crit, is_summon, popup_type_override)
		var randomize_popup_offset = options.get("randomize_popup_offset", false)
		Global.emit_signal("monster_damage", popup_type, final_damage, get_damage_popup_position(randomize_popup_offset), damage_type)

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
