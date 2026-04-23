extends "res://Script/monster/monster_base.gd"

@onready var sprite = $BossStone # 使用与 boss_stone 相同的节点结构
var is_attacking: bool = false
var allow_turning: bool = true

# 屏幕边界
@export var top_boundary: float = 250.0
@export var bottom_boundary: float = 750.0
@export var left_boundary: float = -205.0
@export var right_boundary: float = 210.0

# 移动
var move_direction: int = 4
var target_position: Vector2
var update_move_timer: Timer

# 属性
var speed: float = SettingMoster.stone_man("speed") * 1.2
var hpMax: float = SettingMoster.stone_man("hp") * 12 # 正式版50
var hp: float = hpMax
var atk: float = SettingMoster.stone_man("atk") * 0.75
var get_point: int = SettingMoster.stone_man("point") * 50
var get_exp: int = 0

# 难度系统
var stage_difficulty: String = Global.STAGE_DIFFICULTY_SHALLOW

# 冰刺术场景
const ICE_SCENE = preload("res://Scenes/moster/boss_skill/ice.tscn")

# 难度常量
const CORE_ICE_SPIKE_ANGLE: float = 270.0

func _drop_boss_rewards() -> void:
	# 15%基础概率掉落1种以太（火风雷水土其一）
	var ether_ids = ["item_031", "item_032", "item_033", "item_034", "item_035"]
	if randf() <= 0.75:
		var chosen_ether = ether_ids[randi() % ether_ids.size()]
		Global.emit_signal("drop_out_item", chosen_ether, 1, global_position)
	# 魔核+凝灵碎片掉落
	drop_items_from_table(SettingMoster.get_boss_extra_drop())
	# 固定掉落1个随机魔核
	var magic_cores = ["item_097", "item_098", "item_099", "item_100", "item_101"]
	var fixed_core = magic_cores[randi() % magic_cores.size()]
	Global.emit_signal("drop_out_item", fixed_core, 1, global_position)

var attack_timer: Timer

# 连环咏唱相关
var is_chain_chanting: bool = false
var chain_skills_queue: Array = []
var chain_symbols_node: Node2D = null

# 头顶符号绘制
var symbol_node: Node2D = null
const SPELL_ICON_TEXTURE: Texture2D = preload("res://AssetBundle/Sprites/SpecialEffects/tripe_spell.png")
const SPELL_ICON_ORDER := {
	"fire": 0,
	"ice": 1,
	"thunder": 2,
	"cross": 3,
	"x": 4,
}
const CHAIN_CHANT_COMBINATIONS := [
	[5, 6, 3], # 十字火 + x形冰 + 环雷
	[3, 1, 5], # 环雷 + 爆炎 + 十字火
	[3, 1, 6], # 环雷 + 爆炎 + x形冰
	[5, 3, 2], # 十字火 + 环雷 + 极冰
	[5, 3, 2], # 十字火 + 环雷 + 极冰
	[5, 3, 6], # 十字火 + 环雷 +  x形冰
	[2, 3, 6], # 极冰 + 环雷 +  x形冰
	[2, 3, 5], # 极冰 + 环雷 +  十字火
	[6, 3, 2], # x形冰 + 环雷 + 极冰
	[6, 3, 2], # x形冰 + 环雷 + 极冰
	[6, 3, 5], # x形冰 + 环雷 + 十字火
	[5, 1, 6], # 十字火 + 爆炎 + x形冰
	[6, 1, 5], # x形冰 + 爆炎 + 十字火
	[5, 1, 6], # 十字火 + 爆炎 + x形冰
	[6, 1, 5], # x形冰 + 爆炎 + 十字火
]
const POETRY_CHAIN_CHANT_PAIRS := [
	[1, 2], # 炽炎+极冰
	[3, 5], # 环雷+十字火
	[3, 6], # 环雷+x形冰
	[2, 6], # 极冰+x形冰
	[1, 5], # 炽炎+十字火
]

func _ready():
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	stage_difficulty = Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	# 根据玩家DPS和难度增加Boss HP
	var dps_multiplier := 8
	match Global.current_stage_difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			dps_multiplier = 11
		Global.STAGE_DIFFICULTY_CORE:
			dps_multiplier = 14
		Global.STAGE_DIFFICULTY_POETRY:
			dps_multiplier = 14
	hpMax += Global.get_current_dps() * dps_multiplier
	hp = hpMax
	
	# 浅层难度下Boss只造成25%伤害
	if stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW:
		atk *= 0.5

	setup_monster_base()
	player_hit_emit_self = true
	use_debuff_take_damage_multiplier = false
	check_action_disabled_on_body_entered = false

	CharacterEffects.create_shadow(self , 50.0, 16.0, 40.0)

	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "坎塞尔")
	Global.emit_signal("boss_hp_bar_show")

	update_move_timer = Timer.new()
	add_child(update_move_timer)
	update_move_timer.wait_time = 0.5
	update_move_timer.timeout.connect(_update_target_position)
	update_move_timer.start()
	_update_target_position()

	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 1.5
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()
	
	symbol_node = Node2D.new()
	symbol_node.position = Vector2(0, -70) # Boss头顶，下移 30 像素
	symbol_node.z_index = 10
	add_child(symbol_node)

	# 从场景 StaticBody2D 动态读取场地边界，覆盖硬编码默认值
	_read_arena_boundaries()


func _update_target_position():
	if not is_instance_valid(PC.player_instance): return
	var player_pos = PC.player_instance.global_position
	var x_offset = 80
	if global_position.x < player_pos.x:
		x_offset = -80
	target_position = Vector2(player_pos.x + x_offset, player_pos.y)

## 从当前场景的 Boundry 节点中读取 StaticBody2D，动态计算场地边界。
## 覆盖 @export 的硬编码默认值，使耀星等技能适配任意大小场地。
func _read_arena_boundaries() -> void:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	var boundary_node = current_scene.find_child("Boundry", true, false)
	if not boundary_node:
		return
	var result: Dictionary = {}
	var margin := 0.1 # 角度容差
	for child in boundary_node.get_children():
		if not child is StaticBody2D:
			continue
		var static_body: StaticBody2D = child
		var col_shape: CollisionShape2D = null
		for sub in static_body.get_children():
			if sub is CollisionShape2D:
				col_shape = sub
				break
		if col_shape == null:
			continue
		if col_shape.shape == null or not col_shape.shape is WorldBoundaryShape2D:
			continue
		# 将旋转角度归一化到 [-PI, PI]
		var rot = fposmod(static_body.global_rotation, TAU)
		if rot > PI:
			rot -= TAU
		var abs_rot = absf(rot)
		if abs_rot < margin or absf(abs_rot - PI) < margin:
			# 水平墙壁 → 决定 Y 边界
			var y_val = col_shape.global_position.y
			if abs_rot < margin:
				# 旋转≈0 → 底部墙壁 → max_y
				if not result.has("max_y") or y_val < result["max_y"]:
					result["max_y"] = y_val
			else:
				# 旋转≈±π → 顶部墙壁 → min_y
				if not result.has("min_y") or y_val > result["min_y"]:
					result["min_y"] = y_val
		elif absf(abs_rot - PI / 2.0) < margin:
			# 垂直墙壁 → 决定 X 边界
			var x_val = col_shape.global_position.x
			if rot < 0:
				# 旋转≈-π/2 → 右侧墙壁 → max_x
				if not result.has("max_x") or x_val < result["max_x"]:
					result["max_x"] = x_val
			else:
				# 旋转≈+π/2 → 左侧墙壁 → min_x
				if not result.has("min_x") or x_val > result["min_x"]:
					result["min_x"] = x_val
	if result.has("min_y"):
		top_boundary = result["min_y"]
	if result.has("max_y"):
		bottom_boundary = result["max_y"]
	if result.has("min_x"):
		left_boundary = result["min_x"]
	if result.has("max_x"):
		right_boundary = result["max_x"]
	print("[BossCansel] 动态边界: top=", top_boundary, " bottom=", bottom_boundary,
		" left=", left_boundary, " right=", right_boundary)

# 难度辅助方法
func _is_deep_or_harder() -> bool:
	return stage_difficulty in [Global.STAGE_DIFFICULTY_DEEP, Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY]

func _is_core_or_harder() -> bool:
	return stage_difficulty in [Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY]

func _is_poetry() -> bool:
	return stage_difficulty == Global.STAGE_DIFFICULTY_POETRY

func _physics_process(delta: float) -> void:
	if PC.player_instance and allow_turning:
		var player_pos = PC.player_instance.global_position
		if player_pos.x < global_position.x:
			if sprite: sprite.flip_h = true
		else:
			if sprite: sprite.flip_h = false

	if not is_dead and not is_attacking:
		_move_pattern(delta)

	if is_attacking:
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			if sprite.animation != "idle":
				sprite.play("idle")
		attack_timer.paused = true
	if not is_attacking:
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
			if sprite.animation != "run":
				sprite.play("run")
		attack_timer.paused = false

func _move_pattern(delta: float):
	var direction = position.direction_to(target_position)
	if position.distance_to(target_position) > 5:
		position += direction * speed * delta

# 攻击阶段状态控制
var attack_phase: int = 0 # 0: 首次循环, 1: 后续循环
var phase_skills_pool: Array = []
var chain_chant_count: int = 0 # 连环咏唱计数，用于诗想终极技能轮换
var _combo_pending: int = 0 # 组合技能待完成计数
var _combo_mode: bool = false # 组合技能模式：跳过单独咏唱/符号

func _choose_attack():
	if is_dead: return
	is_attacking = true
	
	if is_chain_chanting and chain_skills_queue.size() > 0:
		var item = chain_skills_queue.pop_front()
		if item is Array:
			_execute_combo_pair(item)
		else:
			_execute_skill(item)
		return
	
	if is_chain_chanting and chain_skills_queue.size() == 0:
		is_chain_chanting = false
		is_attacking = false
		return
	
	var pick = 0
	
	if attack_phase == 0:
		# 诗想难度直接进入二阶段循环
		if _is_poetry():
			attack_phase = 2
			_choose_attack()
			return
		else:
			# 一阶段：首次耀星，然后洗牌技能池
			if phase_skills_pool.size() == 0 and not is_chain_chanting:
				pick = 4 # 耀星
				phase_skills_pool = [1, 2, 3, 5, 6, 8]
				phase_skills_pool.shuffle()
				attack_phase = 1
			else:
				pass
	elif attack_phase == 1:
		# 一阶段：按洗牌顺序释放技能
		if phase_skills_pool.size() > 0:
			pick = phase_skills_pool.pop_front()
		else:
			attack_phase = 2 # 进入二阶段循环
	elif attack_phase == 2:
		# 二阶段循环：耀星 → 冰刺术 → 三连咏唱 → 蓄力(诗想)
		pick = 4 # 耀星
		attack_phase = 3
	elif attack_phase == 3:
		pick = 8 # 冰刺术
		attack_phase = 4
	elif attack_phase == 4:
		chain_chant_count += 1
		pick = 7 # 三连咏唱
		if _is_poetry():
			attack_phase = 5 # 诗想：三连咏唱后固定接蓄力
		else:
			attack_phase = 2
	elif attack_phase == 5:
		# 诗想专属：蓄力技能
		pick = 9
		attack_phase = 2 # 回到二阶段循环
	
	if pick != 0:
		_execute_skill(pick)
	else:
		is_attacking = false

func _execute_skill(skill_id: int):
	match skill_id:
		1: _attack_blazing_fire()
		2: _attack_extreme_ice()
		3: _attack_ring_thunder()
		4: _attack_ground_fire()
		5: _attack_cross_fire()
		6: _attack_x_ice()
		7: _attack_chain_chant()
		8: _attack_ice_spike()
		9: _attack_poetry_ultimate()
		_:
			is_attacking = false

# 诗想组合技能：同时释放两种技能
func _execute_combo_pair(pair: Array):
	_combo_mode = true
	_combo_pending = 2
	
	# 显示组合符号（两个图标并排）
	for child in symbol_node.get_children():
		child.queue_free()
	var map_str = {1: "fire", 2: "ice", 3: "thunder", 5: "cross", 6: "x", 8: "ice"}
	var icon1 = _create_spell_icon(map_str.get(pair[0], "fire"))
	icon1.position = Vector2(-12, 0)
	symbol_node.add_child(icon1)
	var icon2 = _create_spell_icon(map_str.get(pair[1], "ice"))
	icon2.position = Vector2(12, 0)
	symbol_node.add_child(icon2)
	
	# 组合咏唱
	Global.emit_signal("boss_chant_start", "组合咏唱", 1.0)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self ) or is_dead:
		_combo_mode = false
		return
	Global.emit_signal("boss_chant_end")
	
	# 同时释放两个技能（使用call_deferred确保真正并行，不被await阻塞）
	_execute_skill(pair[0])
	_execute_skill(pair[1])

# ================= 辅助绘制 =================
func _create_spell_icon(symbol_type: String, icon_scale: Vector2 = Vector2.ONE) -> Sprite2D:
	var icon_sprite := Sprite2D.new()
	var icon_index = SPELL_ICON_ORDER.get(symbol_type, -1)
	if icon_index < 0:
		return icon_sprite
	var frame_width = int(SPELL_ICON_TEXTURE.get_width() / 5.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = SPELL_ICON_TEXTURE
	atlas.region = Rect2(frame_width * icon_index, 0, frame_width, SPELL_ICON_TEXTURE.get_height())
	icon_sprite.texture = atlas
	icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_sprite.centered = true
	icon_sprite.scale = icon_scale
	return icon_sprite

func _show_symbol(type: String):
	if _combo_mode: return
	for child in symbol_node.get_children():
		child.queue_free()
	var icon_sprite = _create_spell_icon(type)
	symbol_node.add_child(icon_sprite)
	var tw = create_tween()
	icon_sprite.modulate.a = 0
	icon_sprite.position.y = 20
	tw.set_parallel(true)
	tw.tween_property(icon_sprite, "modulate:a", 1.0, 0.3)
	tw.tween_property(icon_sprite, "position:y", 0.0, 0.3)


func _hide_symbol():
	if _combo_mode: return
	for child in symbol_node.get_children():
		var tw = create_tween()
		tw.tween_property(child, "modulate:a", 0.0, 0.2)
		tw.tween_callback(child.queue_free)

# 组合技能完成辅助：跟踪_combo_pending，全部完成后推进队列
func _finish_skill():
	if is_chain_chanting:
		if _combo_pending > 0:
			_combo_pending -= 1
			if _combo_pending <= 0:
				_combo_mode = false
				# 组合技能全部完成，清除头顶图标
				for child in symbol_node.get_children():
					child.queue_free()
				# 诗想组合咏唱：组间间隔0.5秒
				if _is_poetry():
					await get_tree().create_timer(0.5).timeout
					if not is_instance_valid(self ) or is_dead: return
				_choose_attack()
		else:
			_choose_attack()
	else:
		is_attacking = false

class _SymbolDrawer extends Node2D:
	var symbol_type: String = ""
	func _draw():
		var P := 4
		var base_color := Color.WHITE
		var shadow_color := Color(0, 0, 0, 0.6)
		var outline_color := Color.WHITE
		
		var draw_funcs = []
		var inner_funcs = []
		
		if symbol_type == "fire":
			base_color = Color(0.9, 0.2, 0.1)
			outline_color = Color(1.0, 0.7, 0.0)
			draw_funcs = [
				func(offset, c): draw_rect(Rect2(-2 * P + offset.x, 0 * P + offset.y, 4 * P, 3 * P), c),
				func(offset, c): draw_rect(Rect2(-3 * P + offset.x, 1 * P + offset.y, 6 * P, 2 * P), c),
				func(offset, c): draw_rect(Rect2(-1 * P + offset.x, -2 * P + offset.y, 2 * P, 2 * P), c),
				func(offset, c): draw_rect(Rect2(0 * P + offset.x, -4 * P + offset.y, 1 * P, 2 * P), c),
				func(offset, c): draw_rect(Rect2(-2 * P + offset.x, -1 * P + offset.y, 1 * P, 2 * P), c),
			]
			inner_funcs = [
				func(offset, c): draw_rect(Rect2(-1 * P + offset.x, 1 * P + offset.y, 2 * P, 2 * P), c),
				func(offset, c): draw_rect(Rect2(0 * P + offset.x, -1 * P + offset.y, 1 * P, 2 * P), c),
			]
		elif symbol_type == "ice":
			base_color = Color(0.1, 0.5, 0.9)
			outline_color = Color(0.6, 0.9, 1.0)
			draw_funcs = [
				func(offset, c): draw_rect(Rect2(-2 * P + offset.x, -2 * P + offset.y, 4 * P, 4 * P), c),
				func(offset, c): draw_rect(Rect2(-3 * P + offset.x, 1 * P + offset.y, 6 * P, 2 * P), c),
				func(offset, c): draw_rect(Rect2(-1 * P + offset.x, -3 * P + offset.y, 2 * P, 6 * P), c),
			]
			inner_funcs = [
				func(offset, c): draw_rect(Rect2(-1 * P + offset.x, -1 * P + offset.y, 2 * P, 2 * P), c),
				func(offset, c): draw_rect(Rect2(1 * P + offset.x, -2 * P + offset.y, 1 * P, 1 * P), c),
			]
		elif symbol_type == "thunder":
			base_color = Color(0.5, 0.1, 0.9)
			outline_color = Color(0.9, 0.7, 1.0)
			draw_funcs = [
				func(offset, c): draw_rect(Rect2(0.5 * P + offset.x, -4 * P + offset.y, 1.5 * P, 3 * P), c),
				func(offset, c): draw_rect(Rect2(-1 * P + offset.x, -1 * P + offset.y, 2.5 * P, 2.5 * P), c),
				func(offset, c): draw_rect(Rect2(-2 * P + offset.x, 0.5 * P + offset.y, 2.5 * P, 2.5 * P), c),
				func(offset, c): draw_rect(Rect2(-1 * P + offset.x, 2 * P + offset.y, 1.5 * P, 2.5 * P), c),
			]
			inner_funcs = [
				func(offset, c): draw_rect(Rect2(0.75 * P + offset.x, -3 * P + offset.y, 0.75 * P, 1.5 * P), c),
				func(offset, c): draw_rect(Rect2(-0.5 * P + offset.x, -0.5 * P + offset.y, 1.5 * P, 1.5 * P), c),
				func(offset, c): draw_rect(Rect2(-1.25 * P + offset.x, 1 * P + offset.y, 1 * P, 1 * P), c),
			]
		elif symbol_type == "cross":
			base_color = Color(0.9, 0.4, 0.0)
			outline_color = Color(1.0, 0.9, 0.2)
			draw_funcs = [
				func(offset, c): draw_rect(Rect2(-1.5 * P + offset.x, -4 * P + offset.y, 3 * P, 8 * P), c),
				func(offset, c): draw_rect(Rect2(-4 * P + offset.x, -1.5 * P + offset.y, 8 * P, 3 * P), c)
			]
			inner_funcs = [
				func(offset, c): draw_rect(Rect2(-0.5 * P + offset.x, -3 * P + offset.y, 1 * P, 6 * P), c),
				func(offset, c): draw_rect(Rect2(-3 * P + offset.x, -0.5 * P + offset.y, 6 * P, 1 * P), c)
			]
		elif symbol_type == "x":
			base_color = Color(0.0, 0.4, 0.8)
			outline_color = Color(0.4, 0.9, 1.0)
			for i in range(-3, 4):
				draw_funcs.append(func(offset, c, idx = i): draw_rect(Rect2(idx * P * 0.8 + offset.x, idx * P * 0.8 + offset.y, P * 1.5, P * 1.5), c))
				draw_funcs.append(func(offset, c, idx = i): draw_rect(Rect2(-idx * P * 0.8 + offset.x, idx * P * 0.8 + offset.y, P * 1.5, P * 1.5), c))
			for i in range(-2, 3):
				inner_funcs.append(func(offset, c, idx = i): draw_rect(Rect2(idx * P * 0.8 + offset.x + P * 0.25, idx * P * 0.8 + offset.y + P * 0.25, P * 1.0, P * 1.0), c))
				inner_funcs.append(func(offset, c, idx = i): draw_rect(Rect2(-idx * P * 0.8 + offset.x + P * 0.25, idx * P * 0.8 + offset.y + P * 0.25, P * 1.0, P * 1.0), c))

		for f in draw_funcs: f.call(Vector2(3, 3), shadow_color)
		for dx in [-1.5, 0, 1.5]:
			for dy in [-1.5, 0, 1.5]:
				if dx == 0 and dy == 0: continue
				for f in draw_funcs: f.call(Vector2(dx, dy), outline_color)
		for f in draw_funcs: f.call(Vector2.ZERO, base_color)
		for f in inner_funcs: f.call(Vector2(-1, -1), base_color.lightened(0.6))
		for f in inner_funcs: f.call(Vector2.ZERO, base_color.lightened(0.4))

# ================= 技能特效与弹幕 =================
func _create_spark_bullet(is_fire: bool, pos: Vector2, _direction: Vector2):
	var bullet = Area2D.new()
	bullet.global_position = pos
	bullet.z_index = z_index - 1
	bullet.add_to_group("boss_projectile")
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0 # 增大碰撞半径以便于踩踏
	col.shape = shape
	bullet.add_child(col)

	var drawer = _SparkDrawer.new()
	drawer.is_fire = is_fire
	drawer.modulate.a = 0.7
	drawer.scale = Vector2(0.56, 0.56)
	bullet.add_child(drawer)
	
	get_tree().current_scene.add_child(bullet)
	
	var spark_speed = 230.0
	var bullet_tween = bullet.create_tween()
	
	var dest = Vector2(randf_range(left_boundary + 30, right_boundary - 30), randf_range(top_boundary + 30, bottom_boundary - 30))
			
	var dist = pos.distance_to(dest)
	var travel_time = max(dist / spark_speed, 0.2)

	
	var trigger_damage = func(body: Node2D):
		if body is CharacterBody2D and body.is_in_group("player"):
			var consumed = false
			var player_pos = body.global_position
			if is_fire:
				# 身上有冰冻：解除冰冻 + 回复最大生命30% + 不受燃烧
				if BuffManager.has_buff("frozen"):
					var stacks = BuffManager.get_buff_stack("frozen")
					if stacks > 1:
						Global.emit_signal("buff_added", "frozen", 12.0, stacks - 1)
					else:
						BuffManager.remove_buff("frozen")
					var heal_amount = int(PC.pc_max_hp * 0.2)
					PC.pc_hp = min(PC.pc_hp + heal_amount, PC.pc_max_hp)
					Global.emit_signal("player_heal", float(heal_amount), player_pos)
					consumed = true
				else:
					# 否则：扣除当前生命30% + 叠加燃烧
					Global.emit_signal("player_hit", self )
					var actual_damage = int(PC.pc_hp * 0.3)
					PC.pc_hp -= actual_damage
					Global.emit_signal("player_hit", float(actual_damage), 0.0, self , player_pos, "灵火碎片")
					var stacks = 1
					if BuffManager.has_buff("burning_fire"):
						stacks = BuffManager.get_buff_stack("burning_fire") + 1
					Global.emit_signal("buff_added", "burning_fire", 12.0, stacks)
					consumed = true
			else:
				# 身上有燃烧：解除燃烧 + 回复最大生命30% + 不受冰冻
				if BuffManager.has_buff("burning_fire"):
					var stacks = BuffManager.get_buff_stack("burning_fire")
					if stacks > 1:
						Global.emit_signal("buff_added", "burning_fire", 12.0, stacks - 1)
					else:
						BuffManager.remove_buff("burning_fire")
					var heal_amount = int(PC.pc_max_hp * 0.2)
					PC.pc_hp = min(PC.pc_hp + heal_amount, PC.pc_max_hp)
					Global.emit_signal("player_heal", float(heal_amount), player_pos)
					consumed = true
				else:
					# 否则：扣除当前生命30% + 叠加冰冻
					var actual_damage = int(PC.pc_hp * 0.3)
					PC.pc_hp -= actual_damage
					Global.emit_signal("player_hit", float(actual_damage), 0.0, self , player_pos, "星冰碎片")
					var stacks = 1
					if BuffManager.has_buff("frozen"):
						stacks = BuffManager.get_buff_stack("frozen") + 1
					Global.emit_signal("buff_added", "frozen", 12.0, stacks)
					consumed = true
			
			if consumed:
				if PC.pc_hp <= 0:
					PC.player_instance.game_over()
				if is_instance_valid(bullet):
					bullet.queue_free()
	
	bullet_tween.tween_property(bullet, "global_position", dest, travel_time).set_ease(Tween.EASE_OUT)
	bullet_tween.tween_callback(func():
		for body in bullet.get_overlapping_bodies():
			trigger_damage.call(body)
		var timer = get_tree().create_timer(45.0)
		timer.timeout.connect(func():
			if is_instance_valid(bullet):
				bullet.queue_free()
		)
	)
	
	bullet.body_entered.connect(func(body: Node2D):
		trigger_damage.call(body)
	)

class _SparkDrawer extends Node2D:
	var is_fire: bool = true
	var rot: float = randf() * TAU
	func _process(delta):
		rot += delta * 1.5
		rotation = rot
	func _draw():
		var P := 3
		var base_color = Color(1.0, 1.0, 0.5) if is_fire else Color(0.5, 1.0, 1.0)
		var outline_color = Color(1.0, 0.0, 0.0) if is_fire else Color(0.0, 0.0, 1.0)
		
		var draw_funcs = [
			func(offset, c): draw_rect(Rect2(-1 * P + offset.x, -5 * P + offset.y, 2 * P, 2 * P), c),
			func(offset, c): draw_rect(Rect2(-2 * P + offset.x, -3 * P + offset.y, 4 * P, 2 * P), c),
			func(offset, c): draw_rect(Rect2(-5 * P + offset.x, -1 * P + offset.y, 2 * P, 2 * P), c),
			func(offset, c): draw_rect(Rect2(-3 * P + offset.x, -2 * P + offset.y, 2 * P, 4 * P), c),
			func(offset, c): draw_rect(Rect2(-2 * P + offset.x, -2 * P + offset.y, 4 * P, 4 * P), c),
			func(offset, c): draw_rect(Rect2(1 * P + offset.x, -2 * P + offset.y, 2 * P, 4 * P), c),
			func(offset, c): draw_rect(Rect2(3 * P + offset.x, -1 * P + offset.y, 2 * P, 2 * P), c),
			func(offset, c): draw_rect(Rect2(-2 * P + offset.x, 1 * P + offset.y, 4 * P, 2 * P), c),
			func(offset, c): draw_rect(Rect2(-1 * P + offset.x, 3 * P + offset.y, 2 * P, 2 * P), c),
		]
		var inner_funcs = [
			func(offset, c): draw_rect(Rect2(-1 * P + offset.x, -2 * P + offset.y, 2 * P, 1 * P), c),
			func(offset, c): draw_rect(Rect2(-2 * P + offset.x, -1 * P + offset.y, 1 * P, 2 * P), c),
			func(offset, c): draw_rect(Rect2(1 * P + offset.x, -1 * P + offset.y, 1 * P, 2 * P), c),
			func(offset, c): draw_rect(Rect2(-1 * P + offset.x, 1 * P + offset.y, 2 * P, 1 * P), c),
			func(offset, c): draw_rect(Rect2(-1 * P + offset.x, -1 * P + offset.y, 2 * P, 2 * P), c),
		]


		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				for f in draw_funcs: f.call(Vector2(dx, dy) * 1.5, outline_color)
		for f in draw_funcs: f.call(Vector2.ZERO, base_color)
		var inner_col = Color(1.0, 1.0, 0.5) if is_fire else Color(0.5, 1.0, 1.0)
		for f in inner_funcs: f.call(Vector2.ZERO, inner_col)

# 十字形（上下左右四方向）粒子喷射
func _spawn_cross_particles(pos: Vector2, color: Color, amount: int, radius: float):
	var axes = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	var per_axis = int(amount / 4)
	for axis in axes:
		for i in range(per_axis):
			var p = _ParticleDot.new()
			p.color = color
			p.global_position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
			get_tree().current_scene.add_child(p)
			var spread = randf_range(-0.3, 0.3) # ±约17度扩散
			var dir = axis.rotated(spread)
			var dist = randf_range(radius * 0.2, radius)
			var target = p.global_position + dir * dist
			var tw = p.create_tween().set_parallel(true)
			var fly_time = randf_range(0.3, 0.6)
			tw.tween_property(p, "global_position", target, fly_time).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 0.0, fly_time)
			tw.finished.connect(p.queue_free)

# X形（四条对角线方向）粒子喷射
func _spawn_x_particles(pos: Vector2, color: Color, amount: int, radius: float):
	var diagonals = [
		Vector2(1, 1).normalized(),
		Vector2(-1, -1).normalized(),
		Vector2(1, -1).normalized(),
		Vector2(-1, 1).normalized(),
	]
	var per_diag = int(amount / 4)
	for diag in diagonals:
		for i in range(per_diag):
			var p = _ParticleDot.new()
			p.color = color
			p.global_position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
			get_tree().current_scene.add_child(p)
			var spread = randf_range(-0.3, 0.3)
			var dir = diag.rotated(spread)
			var dist = randf_range(radius * 0.2, radius)
			var target = p.global_position + dir * dist
			var tw = p.create_tween().set_parallel(true)
			var fly_time = randf_range(0.3, 0.6)
			tw.tween_property(p, "global_position", target, fly_time).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 0.0, fly_time)
			tw.finished.connect(p.queue_free)

func _spawn_particles(pos: Vector2, color: Color, amount: int, radius: float):
	for i in range(amount):
		var p = _ParticleDot.new()
		p.color = color
		p.global_position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		get_tree().current_scene.add_child(p)
		var angle = randf() * TAU
		var dist = randf_range(radius * 0.2, radius)
		var target = p.global_position + Vector2(cos(angle), sin(angle)) * dist
		var tw = p.create_tween().set_parallel(true)
		var fly_time = randf_range(0.3, 0.6)
		tw.tween_property(p, "global_position", target, fly_time).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, fly_time)
		tw.finished.connect(p.queue_free)

func _spawn_ring_particles(pos: Vector2, color: Color, amount: int, inner_rx: float, inner_ry: float, radius: float):
	for i in range(amount):
		var p = _ParticleDot.new()
		p.color = color
		var angle = randf() * TAU
		var edge_pos = pos + Vector2(cos(angle) * inner_rx, sin(angle) * inner_ry)
		p.global_position = edge_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		get_tree().current_scene.add_child(p)
		var dist = randf_range(radius * 0.2, radius)
		var target = p.global_position + Vector2(cos(angle), sin(angle)) * dist
		var tw = p.create_tween().set_parallel(true)
		var fly_time = randf_range(0.3, 0.6)
		tw.tween_property(p, "global_position", target, fly_time).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, fly_time)
		tw.finished.connect(p.queue_free)

class _ParticleDot extends Node2D:
	var color: Color
	func _draw():
		draw_rect(Rect2(-2, -2, 4, 4), color)

# ================= 技能逻辑 =================
func _attack_blazing_fire():
	_show_symbol("fire")
	var chant_time = 1.0 if is_chain_chanting else 2.0
	if not _combo_mode:
		Global.emit_signal("boss_chant_start", "爆炎", chant_time)
		await get_tree().create_timer(chant_time).timeout
		if not is_instance_valid(self ) or is_dead: return
	
	var player_pos = PC.player_instance.global_position if is_instance_valid(PC.player_instance) else global_position
	var warn = WarnCircleUtil.new()
	warn.attacker = self
	get_tree().current_scene.add_child(warn)
	var fire_radius = 144.0 * 0.9
	warn.warning_finished.connect(func():
		if is_instance_valid(warn): warn.cleanup()
		_spawn_particles(player_pos, Color(1.0, 0.2, 0.0), 160, fire_radius)
		_screen_shake(8.0, 0.3)
		
		var base_angle = randf() * TAU
		for i in range(6):
			var dir = Vector2.RIGHT.rotated(base_angle + i * (TAU / 6.0))
			_create_spark_bullet(true, player_pos, dir)
	)
	var warn_dur = 2.0 if is_chain_chanting else chant_time
	warn.start_warning(player_pos, 1.0, fire_radius, warn_dur, atk * 1.2, "爆炎", null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)
	
	_hide_symbol()
	_finish_skill()

func _attack_extreme_ice():
	_show_symbol("ice")
	var chant_time = 1.0 if is_chain_chanting else 2.0
	if not _combo_mode:
		Global.emit_signal("boss_chant_start", "冰封", chant_time)
	
	var boss_pos = global_position
	var warn = WarnCircleUtil.new()
	warn.attacker = self
	get_tree().current_scene.add_child(warn)
	var ice_radius = 200.0 * 0.85
	warn.warning_finished.connect(func():
		if is_instance_valid(warn): warn.cleanup()
		_spawn_particles(boss_pos, Color(0.0, 0.8, 1.0), 160, ice_radius)
		_screen_shake(8.0, 0.3)
		
		var base_angle = randf() * TAU
		for i in range(6):
			var dir = Vector2.RIGHT.rotated(base_angle + i * (TAU / 6.0))
			_create_spark_bullet(false, boss_pos, dir)
		
		_hide_symbol()
		_finish_skill()
	)
	var warn_dur = chant_time if not _combo_mode else 1.0
	warn.start_warning(boss_pos, 1.0, ice_radius, warn_dur, atk * 1.2, "冰封", null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)

func _attack_ring_thunder():
	_show_symbol("thunder")
	var chant_time = 1.0 if is_chain_chanting else 2.0
	if not _combo_mode:
		Global.emit_signal("boss_chant_start", "环雷", chant_time)
	
	var boss_pos = global_position
	
	# 自定义环形警告
	var ring_warn = _RingWarn.new()
	ring_warn.center = boss_pos
	ring_warn.inner_r = 94
	ring_warn.duration = chant_time if not _combo_mode else 0.5
	get_tree().current_scene.add_child(ring_warn)
	
	if not _combo_mode:
		await get_tree().create_timer(chant_time).timeout
	else:
		await get_tree().create_timer(0.5).timeout
	if is_instance_valid(ring_warn): ring_warn.queue_free()
	
	_spawn_particles(boss_pos, Color(0.6, 0.0, 1.0), 160, 400.0)
	_screen_shake(6.0, 0.3)
	
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		var diff = PC.player_instance.global_position - boss_pos
		var norm_x = diff.x / 82.5
		var norm_y = diff.y / 55.0
		if (norm_x * norm_x + norm_y * norm_y) > 1.0:
			PC.player_hit(int(atk * 1.5 * (1.0 - PC.damage_reduction_rate)), self , "环雷")
			Global.emit_signal("player_hit", self )
			if PC.pc_hp <= 0: PC.player_instance.game_over()
	
	_hide_symbol()
	_finish_skill()

class _RingWarn extends Node2D:
	var center: Vector2
	var inner_r: float = 82.5
	var outer_r: float = 600.0
	var duration: float = 2.0
	var elapsed: float = 0.0
	func _process(delta):
		elapsed += delta
		queue_redraw()
	func _draw():
		var alpha = (elapsed / duration) * 0.5
		var c = Color(0.6, 0.0, 1.0, alpha)
		var pts = PackedVector2Array()
		var pts2 = PackedVector2Array()
		for i in range(33):
			var a = i * TAU / 32.0
			pts.append(center + Vector2(cos(a) * outer_r, sin(a) * outer_r))
			pts2.append(center + Vector2(cos(a) * inner_r, sin(a) * inner_r / 1.5))
		
		# 绘制空心环
		for i in range(32):
			var poly = PackedVector2Array([pts[i], pts[i + 1], pts2[i + 1], pts2[i]])
			draw_polygon(poly, PackedColorArray([c]))

## 耀星方向箭头指示器
## 在每个警告圈的指定半侧绘制像素风格 chevron 箭头（>>/<< 等），
## 帮助玩家快速判断地火的移动方向。
class _DirectionArrowIndicator extends Node2D:
	var move_dir: Vector2 = Vector2.RIGHT
	var warn_radius: float = 26.0
	var warn_aspect: float = 1.5
	var warn_duration: float = 1.0
	var _elapsed: float = 0.0
	const P := 2 # 像素块边长

	func _ready():
		z_index = 2 # 绘制在警告圈之上
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta):
		_elapsed += delta
		queue_redraw()

	func _draw():
		if _elapsed > warn_duration + 0.05:
			return
		var progress := _elapsed / warn_duration
		var alpha: float
		if progress <= 0.1:
			alpha = (progress / 0.1) * 0.85
		elif progress <= 0.75:
			alpha = 0.55 + 0.3 * sin(_elapsed * 7.0)
		else:
			alpha = 0.85 * (1.0 - (progress - 0.75) / 0.25)
		alpha = clampf(alpha, 0.0, 1.0)

		var arrow_color := Color(1.0, 0.85, 0.15, alpha)
		var shadow_color := Color(0.0, 0.0, 0.0, alpha * 0.6)
		var highlight_color := Color(1.0, 1.0, 0.8, alpha * 0.5)

		var half_w := warn_radius * warn_aspect
		var half_h := warn_radius

		if move_dir == Vector2.RIGHT:
			for i in 2:
				var cx := half_w * (0.2 + i * 0.3)
				_draw_chevron_right(Vector2(cx, 0), arrow_color, shadow_color, highlight_color)
		elif move_dir == Vector2.LEFT:
			for i in 2:
				var cx := -half_w * (0.2 + i * 0.3)
				_draw_chevron_left(Vector2(cx, 0), arrow_color, shadow_color, highlight_color)
		elif move_dir == Vector2.DOWN:
			for i in 2:
				var cy := half_h * (0.2 + i * 0.3)
				_draw_chevron_down(Vector2(0, cy), arrow_color, shadow_color, highlight_color)
		elif move_dir == Vector2.UP:
			for i in 2:
				var cy := -half_h * (0.2 + i * 0.3)
				_draw_chevron_up(Vector2(0, cy), arrow_color, shadow_color, highlight_color)

	# —— ">" 右向 chevron（5 像素块对角线）——
	func _draw_chevron_right(center: Vector2, color: Color, shadow: Color, highlight: Color):
		var offsets := [
			Vector2(-P, -2 * P), Vector2(0, -P), Vector2(P, 0),
			Vector2(0, P), Vector2(-P, 2 * P)
		]
		for off in offsets:
			draw_rect(Rect2(center + off + Vector2(1, 1), Vector2(P, P)), shadow)
		for off in offsets:
			draw_rect(Rect2(center + off, Vector2(P, P)), color)
		# 高亮对角线中点
		draw_rect(Rect2(center + Vector2(P, 0), Vector2(P, P)), highlight)

	# —— "<" 左向 chevron ——
	func _draw_chevron_left(center: Vector2, color: Color, shadow: Color, highlight: Color):
		var offsets := [
			Vector2(P, -2 * P), Vector2(0, -P), Vector2(-P, 0),
			Vector2(0, P), Vector2(P, 2 * P)
		]
		for off in offsets:
			draw_rect(Rect2(center + off + Vector2(1, 1), Vector2(P, P)), shadow)
		for off in offsets:
			draw_rect(Rect2(center + off, Vector2(P, P)), color)
		draw_rect(Rect2(center + Vector2(-P, 0), Vector2(P, P)), highlight)

	# —— "v" 下向 chevron ——
	func _draw_chevron_down(center: Vector2, color: Color, shadow: Color, highlight: Color):
		var offsets := [
			Vector2(-2 * P, -P), Vector2(-P, 0), Vector2(0, P),
			Vector2(P, 0), Vector2(2 * P, -P)
		]
		for off in offsets:
			draw_rect(Rect2(center + off + Vector2(1, 1), Vector2(P, P)), shadow)
		for off in offsets:
			draw_rect(Rect2(center + off, Vector2(P, P)), color)
		draw_rect(Rect2(center + Vector2(0, P), Vector2(P, P)), highlight)

	# —— "^" 上向 chevron ——
	func _draw_chevron_up(center: Vector2, color: Color, shadow: Color, highlight: Color):
		var offsets := [
			Vector2(-2 * P, P), Vector2(-P, 0), Vector2(0, -P),
			Vector2(P, 0), Vector2(2 * P, P)
		]
		for off in offsets:
			draw_rect(Rect2(center + off + Vector2(1, 1), Vector2(P, P)), shadow)
		for off in offsets:
			draw_rect(Rect2(center + off, Vector2(P, P)), color)
		draw_rect(Rect2(center + Vector2(0, -P), Vector2(P, P)), highlight)

func _attack_ground_fire():
	Global.emit_signal("boss_chant_start", "耀星", 1.0)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self ) or is_dead: return
	Global.emit_signal("boss_chant_end")
	
	# Boss读条结束后恢复行动，地火独立继续生成
	if is_chain_chanting:
		_choose_attack()
	else:
		is_attacking = false
	
	# 地火轮次独立运行（不阻塞boss行动）
	_run_ground_fire_rounds()

# 耀星地火独立生成协程
var _ground_fire_running: bool = false
func _run_ground_fire_rounds():
	if _ground_fire_running: return # 防止重叠
	_ground_fire_running = true
	var directions = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
	var size_scale = 1.3
	var total_rounds = 8 if _is_deep_or_harder() else 4
	var cached_atk = atk
	var cached_boundaries = {
		"top": top_boundary - 150, "bottom": bottom_boundary + 150,
		"left": left_boundary - 150, "right": right_boundary + 150
	}
	
	for round_idx in range(total_rounds):
		if not is_instance_valid(self ) or is_dead: break
		# 每4轮重新洗牌方向
		if round_idx % 4 == 0:
			directions.shuffle()
		var dir = directions[round_idx % 4]
		
		var step_dist = 0.0
		var count = 0
		var start_pos1 = Vector2.ZERO
		var start_pos2 = Vector2.ZERO
		
		if dir == Vector2.DOWN:
			step_dist = 48.0 * size_scale
			count = ceil((cached_boundaries["bottom"] - cached_boundaries["top"]) / step_dist)
			var valid_x = cached_boundaries["left"] + 30.0
			var max_x = cached_boundaries["right"] - 30.0
			var x1 = randf_range(valid_x, max_x)
			var x2 = randf_range(valid_x, max_x)
			while abs(x1 - x2) < 60.0:
				x2 = randf_range(valid_x, max_x)
			start_pos1 = Vector2(x1, cached_boundaries["top"] + 20.0)
			start_pos2 = Vector2(x2, cached_boundaries["top"] + 20.0)
			
		elif dir == Vector2.UP:
			step_dist = 48.0 * size_scale
			count = ceil((cached_boundaries["bottom"] - cached_boundaries["top"]) / step_dist)
			var valid_x = cached_boundaries["left"] + 30.0
			var max_x = cached_boundaries["right"] - 30.0
			var x1 = randf_range(valid_x, max_x)
			var x2 = randf_range(valid_x, max_x)
			while abs(x1 - x2) < 60.0:
				x2 = randf_range(valid_x, max_x)
			start_pos1 = Vector2(x1, cached_boundaries["bottom"] - 20.0)
			start_pos2 = Vector2(x2, cached_boundaries["bottom"] - 20.0)
			
		elif dir == Vector2.RIGHT:
			step_dist = 68.0 * size_scale
			count = ceil((cached_boundaries["right"] - cached_boundaries["left"]) / step_dist)
			var valid_y = cached_boundaries["top"] + 20.0
			var max_y = cached_boundaries["bottom"] - 20.0
			var y1 = randf_range(valid_y, max_y)
			var y2 = randf_range(valid_y, max_y)
			while abs(y1 - y2) < 40.0:
				y2 = randf_range(valid_y, max_y)
			start_pos1 = Vector2(cached_boundaries["left"] + 30.0, y1)
			start_pos2 = Vector2(cached_boundaries["left"] + 30.0, y2)
			
		elif dir == Vector2.LEFT:
			step_dist = 68.0 * size_scale
			count = ceil((cached_boundaries["right"] - cached_boundaries["left"]) / step_dist)
			var valid_y = cached_boundaries["top"] + 20.0
			var max_y = cached_boundaries["bottom"] - 20.0
			var y1 = randf_range(valid_y, max_y)
			var y2 = randf_range(valid_y, max_y)
			while abs(y1 - y2) < 40.0:
				y2 = randf_range(valid_y, max_y)
			start_pos1 = Vector2(cached_boundaries["right"] - 30.0, y1)
			start_pos2 = Vector2(cached_boundaries["right"] - 30.0, y2)
		
		_spawn_ground_fire_line(start_pos1, dir, step_dist, int(count), size_scale, cached_atk)
		_spawn_ground_fire_line(start_pos2, dir, step_dist, int(count), size_scale, cached_atk)
		
		await get_tree().create_timer(0.75).timeout
	
	_ground_fire_running = false

func _spawn_ground_fire_line(start_pos: Vector2, direction: Vector2, step_dist: float, count: int, size_scale: float = 1.0, cached_atk: float = -1.0):
	var current_pos = start_pos
	var actual_atk = atk if cached_atk < 0.0 else cached_atk
	var warning_radius = 20.7 * size_scale
	var particle_amount = int(ceil(40.0 * size_scale))
	var particle_radius = 120.0 * size_scale
	var warn_aspect = 1.6
	var warn_duration = 2.0
	
	for i in range(count):
		if not is_instance_valid(self ) or is_dead: break
		var warn = WarnCircleUtil.new()
		warn.attacker = self
		get_tree().current_scene.add_child(warn)
		warn.global_position = current_pos
		var pos_to_damage = current_pos
		warn.warning_finished.connect(func():
			if is_instance_valid(warn): warn.cleanup()
			if is_instance_valid(self ):
				_spawn_particles(pos_to_damage, Color(1.0, 0.18, 0.08), particle_amount, particle_radius)
		)
		warn.start_warning(current_pos, warn_aspect, warning_radius, warn_duration, actual_atk * 1.5, "耀星", null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)
		
		# 在警告圈上添加方向箭头指示器
		var arrow = _DirectionArrowIndicator.new()
		arrow.move_dir = direction
		arrow.warn_radius = warning_radius
		arrow.warn_aspect = warn_aspect
		arrow.warn_duration = warn_duration
		warn.add_child(arrow)
		
		await get_tree().create_timer(0.75).timeout
		current_pos += direction * step_dist

func _attack_cross_fire():
	_show_symbol("cross")
	var chant_time = 1.0 if is_chain_chanting else 1.5
	if not _combo_mode:
		Global.emit_signal("boss_chant_start", "炽焰十字", chant_time)
	var boss_pos = global_position
	
	# 伤害范围：基础-15%，核心难度+25%
	var cross_width = 96.0 * 0.85
	if _is_core_or_harder():
		cross_width *= 1.25
	if _is_poetry():
		cross_width *= 0.8
	
	var warn1 = WarnRectUtil.new(); add_child(warn1)
	var warn2 = WarnRectUtil.new(); add_child(warn2)
	warn1.attacker = self ; warn2.attacker = self
	
	var warn_dur = chant_time if not _combo_mode else 1.0
	warn1.start_warning(boss_pos + Vector2(-600, 0), boss_pos + Vector2(600, 0), cross_width, warn_dur, atk * 2.0, "炽焰十字")
	warn2.start_warning(boss_pos + Vector2(0, -600), boss_pos + Vector2(0, 600), cross_width, warn_dur, atk * 2.0, "炽焰十字")
	
	if not _combo_mode:
		await get_tree().create_timer(chant_time).timeout
	_hide_symbol()
	_spawn_cross_particles(boss_pos, Color(1.0, 0.5, 0.0), 160, 600.0)
	_screen_shake(4.0, 0.2)
	
	_finish_skill()

func _attack_x_ice():
	_show_symbol("x")
	var chant_time = 1.0 if is_chain_chanting else 1.5
	if not _combo_mode:
		Global.emit_signal("boss_chant_start", "霜牙交错", chant_time)
	var boss_pos = global_position
	
	# 伤害范围：基础-15%，核心难度+25%
	var x_width = 96.0 * 0.85
	if _is_core_or_harder():
		x_width *= 1.25
	
	var warn1 = WarnRectUtil.new(); add_child(warn1)
	var warn2 = WarnRectUtil.new(); add_child(warn2)
	warn1.attacker = self ; warn2.attacker = self
	
	var warn_dur = chant_time if not _combo_mode else 1.0
	warn1.start_warning(boss_pos + Vector2(-500, -500), boss_pos + Vector2(500, 500), x_width, warn_dur, atk * 2.0, "霜牙交错")
	warn2.start_warning(boss_pos + Vector2(-500, 500), boss_pos + Vector2(500, -500), x_width, warn_dur, atk * 2.0, "霜牙交错")
	
	if not _combo_mode:
		await get_tree().create_timer(chant_time).timeout
	_hide_symbol()
	_spawn_x_particles(boss_pos, Color(0.0, 0.5, 1.0), 160, 600.0)
	_screen_shake(4.0, 0.2)
	
	_finish_skill()

# ================= 冰刺术 =================
func _attack_ice_spike():
	var ice_fan_angle = CORE_ICE_SPIKE_ANGLE if _is_core_or_harder() else 210.0
	var spike_angle_step = 15
	var spike_count = int(ice_fan_angle / spike_angle_step) + 1
	var hover_distance = 25.0
	var fly_speed = 350.0
	var spike_fly_range = 2000.0
	var spike_width = 17.0 # 与ice.tscn碰撞体一致
	
	var rounds: Array = [] # 每轮冰刺数据 [{"node": spike, "direction": dir}, ...]
	var round_warns: Array = [] # 每轮预警节点
	
	for round_idx in range(4):
		if is_dead: break
		
		Global.emit_signal("boss_chant_start", "冰刺术" + str(round_idx + 1), 1.2)
		
		await get_tree().create_timer(1.2).timeout
		if not is_instance_valid(self ) or is_dead: return
		Global.emit_signal("boss_chant_end")
		
		# 上一轮冰刺射出去，同时清除上一轮预警
		if round_idx > 0 and rounds.size() >= round_idx:
			_launch_ice_spikes(rounds[round_idx - 1], fly_speed)
		if round_idx > 0 and round_warns.size() >= round_idx:
			for w in round_warns[round_idx - 1]:
				if is_instance_valid(w): w.queue_free()
		
		# 获取玩家方向
		var player_pos = PC.player_instance.global_position if is_instance_valid(PC.player_instance) else global_position
		var base_angle = global_position.direction_to(player_pos).angle()
		var offset = deg_to_rad(randf_range(3.0, 15.0)) # 每轮随机偏移3~15度
		
		var current_spikes = []
		var current_warns = []
		for i in range(spike_count):
			var angle = base_angle - deg_to_rad(ice_fan_angle / 2.0) + deg_to_rad(i * spike_angle_step) + offset
			var spike = ICE_SCENE.instantiate()
			spike.global_position = global_position
			spike.rotation = angle + PI / 2.0 # 默认图标上下朝向，补偿90度
			spike.add_to_group("boss_projectile")
			get_tree().current_scene.add_child(spike)
			
			# 碰撞伤害
			spike.body_entered.connect(_on_ice_spike_hit.bind(spike))
			
			var spike_dir = Vector2.RIGHT.rotated(angle)
			var target_pos = global_position + spike_dir * hover_distance
			var tw = spike.create_tween()
			tw.tween_property(spike, "global_position", target_pos, 0.3).set_ease(Tween.EASE_OUT)
			
			current_spikes.append({"node": spike, "direction": spike_dir})
			
			# 为每个冰刺绘制路径预警矩形
			var warn_start = target_pos
			var warn_end = target_pos + spike_dir * spike_fly_range
			var spike_warn = WarnRectUtil.new()
			spike_warn.attacker = self
			get_tree().current_scene.add_child(spike_warn)
			# 预警持续到冰刺发射（约2.4秒）
			spike_warn.start_warning(warn_start, warn_end, spike_width, 3.0, 0.0, "冰刺术")
			current_warns.append(spike_warn)
		
		rounds.append(current_spikes)
		round_warns.append(current_warns)
		_screen_shake(3.0, 0.15)
	
	# 最后一轮冰刺延迟后射出
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self ) or is_dead: return
	if rounds.size() >= 4:
		_launch_ice_spikes(rounds[3], fly_speed)
	# 清除最后一轮预警
	if round_warns.size() >= 4:
		for w in round_warns[3]:
			if is_instance_valid(w): w.queue_free()
	
	_finish_skill()

func _on_ice_spike_hit(body: Node2D, spike: Node2D):
	if body is CharacterBody2D and body.is_in_group("player"):
		PC.player_hit(int(atk * 1.5), self , "冰刺术")
		Global.emit_signal("player_hit", self )
		if PC.pc_hp <= 0:
			PC.player_instance.game_over()
		if is_instance_valid(spike):
			spike.queue_free()

func _launch_ice_spikes(spike_list: Array, p_speed: float):
	for spike_data in spike_list:
		if not is_instance_valid(spike_data["node"]): continue
		var spike = spike_data["node"]
		var direction = spike_data["direction"]
		var target = spike.global_position + direction * 2000.0
		var dist = spike.global_position.distance_to(target)
		var tw = spike.create_tween()
		tw.tween_property(spike, "global_position", target, dist / p_speed)
		tw.tween_callback(spike.queue_free)

# ================= 诗想终极技能 =================
func _attack_poetry_ultimate():
	var is_fire_ultimate = randi() % 2 == 0
	var charge_level = (randi() % 2) + 1 # I or II
	# 蓄力I → 释放 II or III, 蓄力II → 释放 III or IV
	var release_level = charge_level + 1 + (randi() % 2)
	var release_time = 3.0
	
	if is_fire_ultimate:
		var charge_name = "星火蓄力I" if charge_level == 1 else "星火蓄力II"
		var release_names = ["", "", "核爆II", "核爆III", "核爆IV"]
		var release_name = release_names[release_level]
		
		# 阶段1：蓄力读条 2秒
		_show_symbol("fire")
		Global.emit_signal("boss_chant_start", charge_name, 2.5)
		await get_tree().create_timer(2.5).timeout
		if not is_instance_valid(self ) or is_dead: return
		Global.emit_signal("boss_chant_end")
		
		# 阶段2：释放读条 2秒
		Global.emit_signal("boss_chant_start", release_name, release_time)
		await get_tree().create_timer(release_time).timeout
		if not is_instance_valid(self ) or is_dead: return
		Global.emit_signal("boss_chant_end")
		
		# 判定：全屏特效 + 伤害
		_screen_shake(15.0, 0.5)
		_spawn_particles(global_position, Color(1.0, 0.3, 0.0), 180, 600.0)
		
		if is_instance_valid(PC.player_instance) and not PC.invincible:
			var frozen_stacks = BuffManager.get_buff_stack("frozen") if BuffManager.has_buff("frozen") else 0
			if frozen_stacks < release_level:
				# 冰冻层数不足，秒杀
				PC.pc_hp = 0
				Global.emit_signal("player_take_damage", float(PC.pc_max_hp), 0.0, PC.player_instance.global_position)
				PC.player_instance.game_over()
			else:
				# 冰冻层数足够：消耗层数，每层回复30%最大生命
				var remaining = frozen_stacks - release_level
				if remaining > 0:
					Global.emit_signal("buff_added", "frozen", 12.0, remaining)
				else:
					BuffManager.remove_buff("frozen")
				for _s in range(release_level):
					var heal_amount = int(PC.pc_max_hp * 0.2)
					PC.pc_hp = min(PC.pc_hp + heal_amount, PC.pc_max_hp)
					Global.emit_signal("player_heal", float(heal_amount), PC.player_instance.global_position)
	else:
		var charge_name = "灵冰蓄力I" if charge_level == 1 else "灵冰蓄力II"
		var release_names = ["", "", "玄冰II", "玄冰III", "玄冰IV"]
		var release_name = release_names[release_level]
		
		# 阶段1：蓄力读条 2秒
		_show_symbol("ice")
		Global.emit_signal("boss_chant_start", charge_name, 2.5)
		await get_tree().create_timer(2.5).timeout
		if not is_instance_valid(self ) or is_dead: return
		Global.emit_signal("boss_chant_end")
		
		# 阶段2：释放读条 2秒
		Global.emit_signal("boss_chant_start", release_name, release_time)
		await get_tree().create_timer(release_time).timeout
		if not is_instance_valid(self ) or is_dead: return
		Global.emit_signal("boss_chant_end")
		
		# 判定：全屏特效 + 伤害
		_screen_shake(15.0, 0.5)
		_spawn_particles(global_position, Color(0.0, 0.5, 1.0), 180, 600.0)
		
		if is_instance_valid(PC.player_instance) and not PC.invincible:
			var fire_stacks = BuffManager.get_buff_stack("burning_fire") if BuffManager.has_buff("burning_fire") else 0
			if fire_stacks < release_level:
				# 燃烧层数不足，秒杀
				PC.pc_hp = 0
				Global.emit_signal("player_take_damage", float(PC.pc_max_hp), 0.0, PC.player_instance.global_position)
				PC.player_instance.game_over()
			else:
				# 燃烧层数足够：消耗层数，每层回复30%最大生命
				var remaining = fire_stacks - release_level
				if remaining > 0:
					Global.emit_signal("buff_added", "burning_fire", 12.0, remaining)
				else:
					BuffManager.remove_buff("burning_fire")
				for _s in range(release_level):
					var heal_amount = int(PC.pc_max_hp * 0.2)
					PC.pc_hp = min(PC.pc_hp + heal_amount, PC.pc_max_hp)
					Global.emit_signal("player_heal", float(heal_amount), PC.player_instance.global_position)
	
	_hide_symbol()
	_finish_skill()

func _attack_chain_chant():
	is_chain_chanting = true
	Global.emit_signal("boss_chant_start", "三连咏唱", 4.0)
	
	var map_str = {1: "fire", 2: "ice", 3: "thunder", 5: "cross", 6: "x", 8: "ice"}
	
	if _is_poetry():
		# 诗想：3组技能对，每组同时释放两种，相邻组不重复技能
		var selected_pairs: Array = []
		var used_skills: Array = [] # 已用技能ID
		for i in range(3):
			var available = []
			for pair_idx in range(POETRY_CHAIN_CHANT_PAIRS.size()):
				var pair = POETRY_CHAIN_CHANT_PAIRS[pair_idx]
				# 检查当前pair是否与已用技能有交集
				var has_overlap = false
				for s in pair:
					if s in used_skills:
						has_overlap = true
						break
				if not has_overlap:
					available.append(pair_idx)
			# 如果没有可用的（极端情况），放宽限制
			if available.size() == 0:
				available = range(POETRY_CHAIN_CHANT_PAIRS.size())
			var chosen_idx = available[randi() % available.size()]
			var chosen_pair = POETRY_CHAIN_CHANT_PAIRS[chosen_idx].duplicate()
			selected_pairs.append(chosen_pair)
			# 记录这组用到的技能，供下一组检查
			for s in chosen_pair:
				if not (s in used_skills):
					used_skills.append(s)
		chain_skills_queue = selected_pairs
		
		var symbol_interval = 1.3
		for i in range(3):
			if is_dead: return
			if i < chain_skills_queue.size():
				var pair = chain_skills_queue[i]
				# 每组显示两个小图标
				var icon1 = _create_spell_icon(map_str.get(pair[0], "fire"), Vector2(0.5, 0.5))
				icon1.position = Vector2((i - 1) * 40 - 8, 20)
				icon1.modulate.a = 0
				symbol_node.add_child(icon1)
				var tw1 = icon1.create_tween()
				tw1.set_parallel(true)
				tw1.tween_property(icon1, "modulate:a", 1.0, 0.3)
				tw1.tween_property(icon1, "position:y", 0.0, 0.3).set_ease(Tween.EASE_OUT)
				
				var icon2 = _create_spell_icon(map_str.get(pair[1], "ice"), Vector2(0.5, 0.5))
				icon2.position = Vector2((i - 1) * 40 + 8, 20)
				icon2.modulate.a = 0
				symbol_node.add_child(icon2)
				var tw2 = icon2.create_tween()
				tw2.set_parallel(true)
				tw2.tween_property(icon2, "modulate:a", 1.0, 0.3)
				tw2.tween_property(icon2, "position:y", 0.0, 0.3).set_ease(Tween.EASE_OUT)
			
			await get_tree().create_timer(symbol_interval).timeout
	else:
		# 非诗想：原有顺序逻辑
		var combo_pool = CHAIN_CHANT_COMBINATIONS
		var selected_combo: Array = combo_pool[randi() % combo_pool.size()]
		chain_skills_queue = selected_combo.duplicate()
		
		var symbol_interval = 1.0
		if _is_deep_or_harder():
			symbol_interval = 0.8
		
		for i in range(3):
			if is_dead: return
			if i < chain_skills_queue.size():
				var mini_symbol = _create_spell_icon(map_str[chain_skills_queue[i]], Vector2(0.7, 0.7))
				mini_symbol.position = Vector2((i - 1) * 45, 20)
				mini_symbol.modulate.a = 0
				symbol_node.add_child(mini_symbol)
				
				var tw = mini_symbol.create_tween()
				tw.set_parallel(true)
				tw.tween_property(mini_symbol, "modulate:a", 1.0, 0.3)
				tw.tween_property(mini_symbol, "position:y", 0.0, 0.3).set_ease(Tween.EASE_OUT)
			
			await get_tree().create_timer(symbol_interval).timeout
	
	await get_tree().create_timer(1.0).timeout
	Global.emit_signal("boss_chant_end")
	_hide_symbol()
	
	# 接下去的攻击循环由队列处理
	_choose_attack()

# ================= 通用交互 =================

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , true)
		var final_damage_val = get_common_bullet_damage_value(collision_result["final_damage"])
		var is_crit = collision_result["is_crit"]

		Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
		hp -= int(final_damage_val)

		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		if collision_result["should_delete_bullet"]:
			area.queue_free()

		if hp <= 0:
			_die()
		else:
			Global.play_hit_anime(position, is_crit)

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	var damage_result = apply_common_take_damage(damage, is_crit, is_summon, damage_type, {
		"use_debuff_multiplier": false,
		"update_boss_hp_bar": true,
		"play_hit_animation": true,
		"randomize_popup_offset": true
	})
	if damage_result["applied"] and damage_result["is_lethal"]:
		_die()
func _die():
	if not is_dead:
		_drop_boss_rewards()
		Global.emit_signal("boss_defeated", get_point, global_position)
		Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	is_attacking = false
	attack_timer.stop()
	Global.emit_signal("boss_chant_end")

	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shadow = get_node_or_null("Shadow")
	if shadow: shadow.visible = false
	queue_free()

func _screen_shake(intensity: float = 6.0, duration: float = 0.3):
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	var original_offset = camera.offset
	var elapsed := 0.0
	while elapsed < duration:
		var dt = get_process_delta_time()
		elapsed += dt
		var strength = intensity * (1.0 - elapsed / duration)
		camera.offset = original_offset + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		await get_tree().process_frame
	camera.offset = original_offset
