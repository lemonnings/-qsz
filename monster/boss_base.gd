extends MonsterBase
class_name BossBase

const BOSS_DPS_HP_MULTIPLIER: float = 11.0
const BOSS_DEEP_DPS_HP_MULTIPLIER: float = 1.05
const BOSS_CORE_DPS_HP_MULTIPLIER: float = 1.1
const BOSS_GLOBAL_HP_MULTIPLIER: float = 1.5
const BOSS_CORE_EXTRA_HP_MULTIPLIER: float = 1.1
const BOSS_SHALLOW_ATK_MULTIPLIER: float = 0.75
const BOSS_BODY_BLOCKER_NAME: String = "BossBodyBlocker"

func setup_boss_base(boss_id: String, use_difficulty_hp_multiplier: bool = false) -> String:
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var difficulty := Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	if use_difficulty_hp_multiplier:
		set("hpMax", float(get("hpMax")) * get_boss_difficulty_hp_multiplier(difficulty))
	if difficulty == Global.STAGE_DIFFICULTY_POETRY:
		set("hpMax", Global.get_poetry_boss_max_hp(boss_id, float(get("hpMax"))))
	else:
		set("hpMax", float(get("hpMax")) + get_boss_dps_hp_bonus(difficulty))
	set("hpMax", float(get("hpMax")) * get_boss_global_hp_multiplier(difficulty))
	set("hp", float(get("hpMax")))
	if difficulty == Global.STAGE_DIFFICULTY_SHALLOW and _has_property_uncached("atk"):
		set("atk", float(get("atk")) * BOSS_SHALLOW_ATK_MULTIPLIER)
	setup_monster_base()
	_setup_boss_body_blocker()
	return difficulty

func get_boss_dps_hp_bonus(difficulty: String) -> float:
	return Global.get_current_dps() * get_boss_dps_hp_multiplier(difficulty)

func get_boss_dps_hp_multiplier(difficulty: String) -> float:
	var multiplier := BOSS_DPS_HP_MULTIPLIER
	match difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			multiplier *= BOSS_DEEP_DPS_HP_MULTIPLIER
		Global.STAGE_DIFFICULTY_CORE:
			multiplier *= BOSS_CORE_DPS_HP_MULTIPLIER
	return multiplier

func get_boss_difficulty_hp_multiplier(difficulty: String) -> float:
	match difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			return 1.2
		Global.STAGE_DIFFICULTY_CORE:
			return 1.4
		Global.STAGE_DIFFICULTY_POETRY:
			return 1.5
		_:
			return 1.0

func get_boss_global_hp_multiplier(difficulty: String) -> float:
	var multiplier := BOSS_GLOBAL_HP_MULTIPLIER
	if difficulty == Global.STAGE_DIFFICULTY_CORE:
		multiplier *= BOSS_CORE_EXTRA_HP_MULTIPLIER
	return multiplier

func _setup_boss_body_blocker() -> void:
	if get_node_or_null(BOSS_BODY_BLOCKER_NAME) != null:
		return
	var source_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if source_shape == null or source_shape.shape == null:
		return
	var blocker := StaticBody2D.new()
	blocker.name = BOSS_BODY_BLOCKER_NAME
	blocker.collision_layer = CharacterEffects.DEFAULT_COLLISION_LAYER
	blocker.collision_mask = 0
	blocker.process_mode = Node.PROCESS_MODE_PAUSABLE
	var blocker_shape := CollisionShape2D.new()
	blocker_shape.name = "CollisionShape2D"
	blocker_shape.position = source_shape.position
	blocker_shape.rotation = source_shape.rotation
	blocker_shape.scale = source_shape.scale
	blocker_shape.shape = source_shape.shape.duplicate()
	blocker.add_child(blocker_shape)
	add_child(blocker)

func set_boss_body_blocker_enabled(enabled: bool) -> void:
	var blocker := get_node_or_null(BOSS_BODY_BLOCKER_NAME) as StaticBody2D
	if blocker == null:
		return
	blocker.collision_layer = CharacterEffects.DEFAULT_COLLISION_LAYER if enabled else 0
	var blocker_shape := blocker.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if blocker_shape != null:
		blocker_shape.disabled = not enabled
