extends Node
class_name Faze

var bath_blood_thud_scene: PackedScene = preload("res://Scenes/player/faze_bath_blood_thud.tscn")
var player: Node2D
var shock_interval: float = 3.0
var shock_hit_cooldown: float = 1.5
var shock_timer: float = 0.0
var last_hit_shock_time: float = -100.0
var last_blood_level: int = 0

func setup(p_player: Node2D) -> void:
	player = p_player
	Global.connect("player_hit", Callable(self, "_on_player_hit"))

func _process(delta: float) -> void:
	if PC.is_game_over:
		return
	_update_blood_debuff_bonus()
	if PC.faze_blood_level < 4:
		return
	shock_timer += delta
	if shock_timer >= shock_interval:
		shock_timer -= shock_interval
		_trigger_shock()

func _on_player_hit(attacker: Node2D = null) -> void:
	if PC.is_game_over:
		return
	if PC.faze_blood_level < 4:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_hit_shock_time < shock_hit_cooldown:
		return
	last_hit_shock_time = current_time
	_trigger_shock()

func _trigger_shock() -> void:
	assert(player != null, "faze.gd: player is null")
	var level = PC.faze_blood_level
	var damage_multiplier = _get_blood_shock_damage_multiplier(level)
	var elite_bonus = _get_blood_shock_elite_bonus(level)
	var bleed_chance = _get_blood_bleed_chance(level)
	var range_scale = _get_blood_shock_range_scale(level)
	var shield_ratio = _get_blood_shield_ratio(level)
	var damage = PC.pc_atk * damage_multiplier
	var shield_amount = int(ceil(float(PC.pc_max_hp) * shield_ratio))
	var thud_instance = bath_blood_thud_scene.instantiate()
	get_tree().current_scene.add_child(thud_instance)
	thud_instance.setup_thud(player.global_position, damage, bleed_chance, range_scale, elite_bonus)
	PC.add_shield(shield_amount, 7.0)

func _get_blood_shock_damage_multiplier(level: int) -> float:
	if level >= 13:
		return 5.0
	if level >= 7:
		return 2.0
	return 1.0

func _get_blood_shock_elite_bonus(level: int) -> float:
	if level >= 7:
		return 1.0
	return 0.0

func _get_blood_bleed_chance(level: int) -> float:
	if level >= 10:
		return 1.0
	return 0.5

func _get_blood_shock_range_scale(level: int) -> float:
	if level >= 13:
		return 4.0
	if level >= 10:
		return 2.0
	return 1.0

func _get_blood_shield_ratio(level: int) -> float:
	if level >= 13:
		return 0.07
	return 0.04

func _update_blood_debuff_bonus() -> void:
	var level = PC.faze_blood_level
	if level == last_blood_level:
		return
	last_blood_level = level
	var bleed_elite_bonus = 0.0
	if level >= 10:
		bleed_elite_bonus = 1.0
	EnemyDebuffManager.set_debuff_elite_boss_bonus("bleed", bleed_elite_bonus)
