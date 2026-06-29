extends "res://Script/monster/monster_base.gd"

@export var is_boss_dummy: bool = false
@export var max_hp_value: float = 999999999.0
@export var shadow_width: float = 24.0
@export var shadow_height: float = 8.0
@export var shadow_offset_y: float = 12.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var boss_sprite: AnimatedSprite2D = get_node_or_null("BossStone") as AnimatedSprite2D

var hpMax: float = max_hp_value
var hp: float = max_hp_value
var atk: float = 0.0
var get_point: int = 0
var get_exp: int = 0
var last_sword_wave_damage_time: float = 0.0

const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

func _ready() -> void:
	hpMax = max_hp_value
	hp = hpMax
	is_dead = false
	player_hit_emit_self = false
	use_debuff_take_damage_multiplier = true
	check_action_disabled_on_body_entered = false
	if is_boss_dummy:
		add_to_group("boss")
	add_to_group("enemies")
	setup_monster_base(false)
	CharacterEffects.create_shadow(self, shadow_width, shadow_height, shadow_offset_y)

func _physics_process(_delta: float) -> void:
	if hp < hpMax:
		hp = hpMax

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if damage <= 0:
		return
	if damage_type == "sword_wave":
		var time_scale: float = 0.5 if PC.selected_rewards.has("SplitSwordQi22") else 1.0
		if not can_apply_interval_damage("last_sword_wave_damage_time", SWORD_WAVE_DAMAGE_INTERVAL, time_scale):
			return
	var options: Dictionary = {
		"play_hit_animation": true,
		"randomize_popup_offset": is_boss_dummy,
		"update_boss_hp_bar": false,
	}
	apply_common_take_damage(damage, is_crit, is_summon, damage_type, options)
	hp = hpMax
	is_dead = false

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("bullet") or not area.has_method("get_bullet_damage_and_crit_status"):
		return
	var collision_result: Dictionary = BulletCalculator.handle_bullet_collision_full(area, self, is_boss_dummy)
	if bool(collision_result.get("should_rebound", false)):
		area.call_deferred("create_rebound")
	if bool(collision_result.get("should_delete_bullet", true)):
		area.queue_free()
	hp = hpMax
	is_dead = false

func _on_body_entered(_body: Node2D) -> void:
	pass

func _get_hit_flash_sprite() -> CanvasItem:
	if sprite != null:
		return sprite
	if boss_sprite != null:
		return boss_sprite
	return super._get_hit_flash_sprite()
