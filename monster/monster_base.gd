extends Area2D
class_name MonsterBase

const HEALTH_BAR_SCENE = preload("res://Scenes/global/hp_bar.tscn")
const ROUND_SWORD_QI_BULLET_SCENE = preload("res://Scenes/bullet.tscn")

var debuff_manager: EnemyDebuffManager
var is_dead: bool = false
var is_elite: bool = false
var drop_rate_multiplier: float = 1.0

var health_bar_shown: bool = false
var health_bar: Node2D
var progress_bar: ProgressBar
var health_bar_offset: Vector2 = Vector2(-15, -10)
var health_bar_tween_duration: float = 0.3

var player_hit_emit_self: bool = false
var use_debuff_take_damage_multiplier: bool = true
var check_action_disabled_on_body_entered: bool = true

const OFFSCREEN_SPEED_MARGIN_PIXELS: float = 30.0
const OFFSCREEN_SPEED_MULTIPLIER_MIN: float = 2.5 # 超出视野后，移动速度额外提升100%~300%（随机）
const OFFSCREEN_SPEED_MULTIPLIER_MAX: float = 5.0
const RANDOM_SPEED_VARIATION_MIN: float = 0.9
const RANDOM_SPEED_VARIATION_MAX: float = 1.1

var movement_speed_variation_multiplier: float = 1.0
var _hit_flash_tween: Tween = null
var _hit_flash_frame: int = -1
var _hit_flash_base_modulate: Color = Color.WHITE
var _spawn_protection_active: bool = false

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
	var camera := get_viewport().get_camera_2d()
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

func get_effective_move_speed(base_speed_value: float, extra_multiplier: float = 1.0, apply_offscreen_boost: bool = true) -> float:
	var speed_multiplier := extra_multiplier
	if debuff_manager != null and is_instance_valid(debuff_manager):
		speed_multiplier *= debuff_manager.get_speed_multiplier()
	if apply_offscreen_boost and _is_beyond_camera_margin():
		speed_multiplier *= randf_range(OFFSCREEN_SPEED_MULTIPLIER_MIN, OFFSCREEN_SPEED_MULTIPLIER_MAX)
	return base_speed_value * speed_multiplier

func apply_debuff_effect(debuff_id: String):
	emit_signal("debuff_applied", debuff_id)

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
		if progress_bar.value != target_value_hp:
			var tween = create_tween()
			tween.tween_property(progress_bar, "value", target_value_hp, health_bar_tween_duration)

func free_health_bar() -> void:
	if health_bar != null and is_instance_valid(health_bar) and health_bar.is_inside_tree():
		health_bar.queue_free()
	health_bar = null
	progress_bar = null
	health_bar_shown = false

func handle_common_body_entered(body: Node2D) -> void:
	if check_action_disabled_on_body_entered and debuff_manager != null and is_instance_valid(debuff_manager) and debuff_manager.is_action_disabled():
		return
	# 出场保护期间不对玩家造成碰撞伤害
	if _spawn_protection_active:
		return
	if body is CharacterBody2D and not is_dead and not PC.invincible:
		var actual_damage = float(get("atk")) * (1.0 - PC.damage_reduction_rate)
		if use_debuff_take_damage_multiplier and debuff_manager != null and is_instance_valid(debuff_manager):
			actual_damage *= debuff_manager.get_take_damage_multiplier()
		PC.player_hit(int(actual_damage), self , "攻击")
		if PC.pc_hp <= 0:
			body.game_over()

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
	var final_damage = get_non_bullet_damage_value(damage, use_debuff_multiplier)
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
func start_spawn_protection(duration: float = 1.5) -> void:
	_spawn_protection_active = true
	get_tree().create_timer(duration).timeout.connect(func(): _spawn_protection_active = false)

## 子弹命中闪烁回调，由 BulletCalculator.handle_bullet_collision_full 调用
func on_bullet_hit_response() -> void:
	_play_hit_flash()
