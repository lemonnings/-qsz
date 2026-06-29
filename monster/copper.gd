extends "res://Script/monster/monster_base.gd"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const ELEMENTAL_DROP_IDS: Array[String] = ["item_015", "item_009", "item_010", "item_017", "item_014"]
const ELEMENTAL_DROP_CHANCE: float = 0.02
const FRAGMENT_DROP_CHANCE: float = 0.10
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

var move_direction: int = 2
var base_speed: float = SettingMoster.copper("speed")
var speed: float
var hpMax: float = SettingMoster.copper("hp")
var hp: float = SettingMoster.copper("hp")
var atk: float = SettingMoster.copper("atk")
var get_point: int = SettingMoster.copper("point")
var get_exp: int = SettingMoster.copper("exp")
var last_sword_wave_damage_time: float = 0.0

func _ready() -> void:
	set_meta("never_elite", true)
	add_to_group("non_elite_enemy")
	setup_monster_base(false)
	speed = base_speed
	health_bar_offset = Vector2(-15, -22)
	CharacterEffects.create_shadow(self, 24.0, 8.0, 8.0)

func _physics_process(delta: float) -> void:
	if hp <= 0:
		_die()
		return

	update_offscreen_status()

	if not _is_offscreen and hp < hpMax and hp > 0:
		show_health_bar()

	if should_skip_actions_for_debuff():
		return

	if not is_dead and not _is_offscreen:
		CharacterEffects.apply_separation(self, 12.0, 14.0)

	if is_dead:
		return

	if hp > 0 and CharacterEffects.is_player_dead_or_game_over():
		move_away_from_dead_player(delta, base_speed, sprite, false)
		return

	if move_direction == 0:
		position += CharacterEffects.apply_soft_separation_to_direction(self, Vector2.RIGHT) * speed * delta
		if not _is_offscreen:
			CharacterEffects.set_enemy_flip_h(self, sprite, false)
	elif move_direction == 1:
		position += CharacterEffects.apply_soft_separation_to_direction(self, Vector2.LEFT) * speed * delta
		if not _is_offscreen:
			CharacterEffects.set_enemy_flip_h(self, sprite, true)
	elif PC.player_instance != null:
		var direction_to_player := CharacterEffects.get_tracking_direction_to_player(self)
		if direction_to_player != Vector2.ZERO:
			speed = get_effective_move_speed(base_speed)
			position += direction_to_player * speed * delta
			if not _is_offscreen:
				CharacterEffects.face_player_x(self, sprite, false)

	if move_direction == 0 and position.x <= -620:
		free_health_bar()
		queue_free()
	elif move_direction == 1 and position.x >= 620:
		free_health_bar()
		queue_free()

func _die() -> void:
	free_health_bar()
	if is_dead:
		return

	sprite.stop()
	sprite.play("death")
	var point_gain := int(get_point * Faze.get_point_multiplier())
	grant_kill_point_rewards(point_gain)
	var exp_gain := int(get_exp * Faze.get_exp_multiplier())
	Global.emit_signal("drop_exp_orb", exp_gain, global_position, false)
	if PC.selected_rewards.has("SplitSwordQi13") and randf() <= 0.05:
		Global.emit_signal("_fire_ring_bullets")
	if has_node("death"):
		$death.play()
	Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.material = null
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shadow := get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false
	_drop_copper_items()

	get_tree().create_timer(0.36).timeout.connect(Callable(self, "queue_free"), CONNECT_ONE_SHOT)

func _drop_copper_items() -> void:
	var drop_multiplier := Global.get_effective_drop_multiplier() * drop_rate_multiplier
	var elemental_drop_chance := ELEMENTAL_DROP_CHANCE * float(ELEMENTAL_DROP_IDS.size()) * drop_multiplier
	if randf() <= elemental_drop_chance:
		var item_id := ELEMENTAL_DROP_IDS[randi() % ELEMENTAL_DROP_IDS.size()]
		Global.emit_signal("drop_out_item", item_id, 1, global_position)

	var fragment_chance := FRAGMENT_DROP_CHANCE * drop_multiplier * (1.0 + Global.study_fragment_drop_chance)
	if randf() <= fragment_chance:
		Global.emit_signal("drop_out_item", "item_007", 1, global_position)

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if damage_type == "sword_wave":
		var time_scale := 0.5 if PC.selected_rewards.has("SplitSwordQi22") else 1.0
		if not can_apply_interval_damage("last_sword_wave_damage_time", SWORD_WAVE_DAMAGE_INTERVAL, time_scale):
			return
		apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"show_damage_popup": false})
		return
	apply_common_take_damage(damage, is_crit, is_summon, damage_type)

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result := BulletCalculator.handle_bullet_collision_full(area, self, false)
		if collision_result["should_delete_bullet"]:
			area.queue_free()
		var final_damage_val := get_common_bullet_damage_value(collision_result["final_damage"])
		hp -= int(final_damage_val)
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		if hp <= 0:
			if not is_dead:
				sprite.play("death")
		else:
			Global.play_hit_anime(position, collision_result["is_crit"])
