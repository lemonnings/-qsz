extends Node
class_name CorruptedEliteController

const CHARGE_MONSTER_IDS := ["paper", "shen", "slime_grey", "stone_man"]
const POISON_MONSTER_IDS := ["slime"]
const PLAYER_AOE_MONSTER_IDS := ["lantern", "peach_yao"]
const MONSTER_ID_ALIASES := {
	"smile_blue": "slime_blue",
}
const RADIAL_MONSTER_IDS := ["slime_blue", "armor_stone"]
const POISON_CIRCLE_SCENE: PackedScene = preload("res://Scenes/moster/poison_circle.tscn")

const CHARGE_INTERVAL: float = 5.0
const CHARGE_DISTANCE: float = 220.0
const CHARGE_DURATION: float = 0.55
const CHARGE_WARNING_TIME: float = 0.85
const CHARGE_WARNING_WIDTH: float = 44.0
const CHARGE_BULLET_ROUNDS: int = 3
const CHARGE_BULLET_INTERVAL: float = 0.18
const PERIODIC_SKILL_INTERVAL: float = 3.0
const POISON_SCALE_MULTIPLIER: float = 1.3
const PLAYER_AOE_RADIUS: float = 40.0
const PLAYER_AOE_WARNING_TIME: float = 2.0
const PLAYER_AOE_OFFSET_MIN: float = 18.0
const PLAYER_AOE_OFFSET_MAX: float = 58.0
const RADIAL_BULLET_COUNT: int = 8

var monster: MonsterBase = null
var monster_id: String = ""
var _charge_timer: Timer = null
var _periodic_timer: Timer = null
var _charge_warning_node: WarnRectUtil = null
var _charge_active: bool = false
var _charge_elapsed: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_start_position: Vector2 = Vector2.ZERO

func setup(monster_node: MonsterBase, resolved_monster_id: String) -> void:
	monster = monster_node
	monster_id = _normalize_monster_id(resolved_monster_id)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if monster == null:
		monster = get_parent() as MonsterBase
	if monster == null:
		queue_free()
		return
	if monster_id.is_empty():
		monster_id = str(monster.get_meta("corrupted_elite_monster_id", ""))
	monster_id = _normalize_monster_id(monster_id)
	_setup_skill_timers()

func _normalize_monster_id(raw_monster_id: String) -> String:
	var normalized := raw_monster_id.strip_edges()
	return str(MONSTER_ID_ALIASES.get(normalized, normalized))

func _physics_process(delta: float) -> void:
	if not _charge_active:
		return
	if not _is_monster_valid() or CharacterEffects.is_player_dead_or_game_over():
		_stop_charge()
		return
	_charge_elapsed += delta
	var progress := clampf(_charge_elapsed / CHARGE_DURATION, 0.0, 1.0)
	var target_position: Vector2 = _charge_start_position + _charge_direction * CHARGE_DISTANCE * progress
	monster.global_position = target_position
	var sprite := monster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.flip_h = _charge_direction.x > 0.0
	if progress >= 1.0:
		_stop_charge()

func _setup_skill_timers() -> void:
	if CHARGE_MONSTER_IDS.has(monster_id):
		_charge_timer = Timer.new()
		_charge_timer.wait_time = CHARGE_INTERVAL
		_charge_timer.one_shot = false
		add_child(_charge_timer)
		_charge_timer.timeout.connect(_try_start_charge_skill)
		_charge_timer.start()
	if POISON_MONSTER_IDS.has(monster_id) or PLAYER_AOE_MONSTER_IDS.has(monster_id) or RADIAL_MONSTER_IDS.has(monster_id):
		_periodic_timer = Timer.new()
		_periodic_timer.wait_time = PERIODIC_SKILL_INTERVAL
		_periodic_timer.one_shot = false
		add_child(_periodic_timer)
		_periodic_timer.timeout.connect(_use_periodic_skill)
		_periodic_timer.start()

func _is_monster_valid() -> bool:
	return monster != null and is_instance_valid(monster) and monster.is_inside_tree() and monster.is_alive_for_action_logic()

func _try_start_charge_skill() -> void:
	if _charge_active or _charge_warning_node != null:
		return
	if not _is_monster_valid() or CharacterEffects.is_player_dead_or_game_over() or PC.player_instance == null:
		return
	if monster.should_skip_actions_for_debuff():
		return
	if monster.get("is_charge_warning") == true or monster.get("is_charging") == true:
		return
	var direction: Vector2 = (PC.player_instance.global_position - monster.global_position).normalized()
	if direction.length_squared() <= 0.001:
		return
	var start_position := monster.global_position
	var target_position: Vector2 = start_position + direction * CHARGE_DISTANCE
	_charge_direction = direction
	_charge_warning_node = WarnRectUtil.new()
	get_tree().current_scene.add_child(_charge_warning_node)
	_charge_warning_node.attacker = monster
	_charge_warning_node.warning_finished.connect(_on_charge_warning_finished, CONNECT_ONE_SHOT)
	_charge_warning_node.start_warning(
		start_position,
		target_position,
		CHARGE_WARNING_WIDTH,
		CHARGE_WARNING_TIME,
		0.0,
		"冲锋",
		null,
		0.18
	)

func _on_charge_warning_finished() -> void:
	_clear_charge_warning()
	if not _is_monster_valid() or CharacterEffects.is_player_dead_or_game_over():
		return
	_charge_active = true
	_charge_elapsed = 0.0
	_charge_start_position = monster.global_position
	monster.set_meta("corrupted_elite_charging", true)
	if monster.has_method("fire_corrupted_perpendicular_rounds"):
		monster.fire_corrupted_perpendicular_rounds(_charge_direction, CHARGE_BULLET_ROUNDS, CHARGE_BULLET_INTERVAL)

func _stop_charge() -> void:
	_charge_active = false
	_charge_elapsed = 0.0
	if monster != null and is_instance_valid(monster):
		monster.set_meta("corrupted_elite_charging", false)

func _use_periodic_skill() -> void:
	if not _is_monster_valid() or CharacterEffects.is_player_dead_or_game_over():
		return
	if monster.should_skip_actions_for_debuff():
		return
	if POISON_MONSTER_IDS.has(monster_id):
		_spawn_poison_circle()
	elif PLAYER_AOE_MONSTER_IDS.has(monster_id):
		_spawn_player_aoe_warnings()
	elif RADIAL_MONSTER_IDS.has(monster_id):
		if monster.has_method("fire_corrupted_radial_bullet_ring"):
			monster.fire_corrupted_radial_bullet_ring(RADIAL_BULLET_COUNT)

func _spawn_poison_circle() -> void:
	if get_tree().current_scene == null:
		return
	var poison_circle := POISON_CIRCLE_SCENE.instantiate() as Node2D
	if poison_circle == null:
		return
	poison_circle.global_position = monster.global_position
	poison_circle.scale *= POISON_SCALE_MULTIPLIER
	poison_circle.set("damage_per_tick", float(monster.get("atk")) * 0.5)
	poison_circle.set("attacker", monster)
	poison_circle.set("instant_damage_on_enter", false)
	poison_circle.set("tick_interval", 0.5)
	get_tree().current_scene.add_child(poison_circle)

func _spawn_player_aoe_warnings() -> void:
	if CharacterEffects.is_player_dead_or_game_over() or PC.player_instance == null or get_tree().current_scene == null:
		return
	var player_position: Vector2 = PC.player_instance.global_position
	for _i in range(2):
		var warning := WarnCircleUtil.new()
		warning.name = "CorruptedElitePlayerAOE"
		get_tree().current_scene.add_child(warning)
		warning.attacker = monster
		warning.player_ref = PC.player_instance
		warning.warning_finished.connect(Callable(warning, "queue_free"), CONNECT_ONE_SHOT)
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(PLAYER_AOE_OFFSET_MIN, PLAYER_AOE_OFFSET_MAX)
		warning.start_warning(
			player_position + offset,
			1.0,
			PLAYER_AOE_RADIUS,
			PLAYER_AOE_WARNING_TIME,
			float(monster.get("atk")),
			"侵蚀范围",
			null,
			WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE
		)

func _clear_charge_warning() -> void:
	if _charge_warning_node != null and is_instance_valid(_charge_warning_node):
		_charge_warning_node.cleanup()
	_charge_warning_node = null

func _exit_tree() -> void:
	_clear_charge_warning()
	_stop_charge()
