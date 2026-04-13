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
var hpMax: float = SettingMoster.stone_man("hp") * 1
var hp: float = hpMax
var atk: float = SettingMoster.stone_man("atk") * 1.5
var get_point: int = SettingMoster.stone_man("point") * 50
var get_exp: int = 0

func _drop_boss_rewards() -> void:
	drop_items_from_table(SettingMoster.cave_boss("itemdrop"))

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


func _ready():
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hp = hpMax

	setup_monster_base()
	player_hit_emit_self = true
	use_debuff_take_damage_multiplier = false
	check_action_disabled_on_body_entered = false

	CharacterEffects.create_shadow(self, 50.0, 16.0, 14.0)

	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "Cansel")
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


func _update_target_position():
	if not is_instance_valid(PC.player_instance): return
	var player_pos = PC.player_instance.global_position
	var x_offset = 80
	if global_position.x < player_pos.x:
		x_offset = -80
	target_position = Vector2(player_pos.x + x_offset, player_pos.y)

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
			sprite.play("idle")
		attack_timer.paused = true
	if not is_attacking:
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
			sprite.play("run")
		attack_timer.paused = false

func _move_pattern(delta: float):
	var direction = position.direction_to(target_position)
	if position.distance_to(target_position) > 5:
		position += direction * speed * delta

# 攻击阶段状态控制
var attack_phase: int = 0 # 0: 首次循环, 1: 后续循环
var phase_skills_pool: Array = []

func _choose_attack():
	if is_dead: return
	is_attacking = true
	
	if is_chain_chanting and chain_skills_queue.size() > 0:
		var skill_id = chain_skills_queue.pop_front()
		_execute_skill(skill_id)
		return
	
	if is_chain_chanting and chain_skills_queue.size() == 0:
		is_chain_chanting = false
		is_attacking = false
		return

	var pick = 0
	
	if attack_phase == 0:
		if phase_skills_pool.size() == 0 and not is_chain_chanting:
			# 初始化阶段0
			pick = 4 # 地火
			phase_skills_pool = [1, 2, 3, 5, 6]
			phase_skills_pool.shuffle()
			attack_phase = 1
		else:
			pass
	elif attack_phase == 1:
		if phase_skills_pool.size() > 0:
			pick = phase_skills_pool.pop_front()
		else:
			pick = 7 # 连续咏唱
			attack_phase = 2
	elif attack_phase == 2:
		pick = 4 # 地火
		attack_phase = 3
	elif attack_phase == 3:
		var random_pool = [1, 2, 3, 5, 6]
		pick = random_pool[randi() % random_pool.size()]
		attack_phase = 4
	elif attack_phase == 4:
		pick = 7 # 连续咏唱
		attack_phase = 2

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
		_:
			is_attacking = false

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
	for child in symbol_node.get_children():
		var tw = create_tween()
		tw.tween_property(child, "modulate:a", 0.0, 0.2)
		tw.tween_callback(child.queue_free)

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
					var heal_amount = int(PC.pc_max_hp * 0.3)
					PC.pc_hp = min(PC.pc_hp + heal_amount, PC.pc_max_hp)
					Global.emit_signal("player_heal", float(heal_amount), player_pos)
					consumed = true
				else:
					# 否则：扣除当前生命30% + 叠加燃烧
					Global.emit_signal("player_hit", self )
					var actual_damage = int(PC.pc_hp * 0.3)
					PC.pc_hp -= actual_damage
					Global.emit_signal("player_take_damage", float(actual_damage), 0.0, player_pos)
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
					var heal_amount = int(PC.pc_max_hp * 0.3)
					PC.pc_hp = min(PC.pc_hp + heal_amount, PC.pc_max_hp)
					Global.emit_signal("player_heal", float(heal_amount), player_pos)
					consumed = true
				else:
					# 否则：扣除当前生命30% + 叠加冰冻
					Global.emit_signal("player_hit", self )
					var actual_damage = int(PC.pc_hp * 0.3)
					PC.pc_hp -= actual_damage
					Global.emit_signal("player_take_damage", float(actual_damage), 0.0, player_pos)
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
	Global.emit_signal("boss_chant_start", "爆炎", chant_time)
	
	await get_tree().create_timer(chant_time).timeout
	if not is_instance_valid(self ) or is_dead: return
	
	var player_pos = PC.player_instance.global_position if is_instance_valid(PC.player_instance) else global_position
	var warn = WarnCircleUtil.new()
	warn.attacker = self # 设置攻击者
	get_tree().current_scene.add_child(warn) # 添加到场景，独立于boss生命周期
	var fire_radius = 144.0 * 0.9
	warn.warning_finished.connect(func():
		if is_instance_valid(warn): warn.cleanup()
		_spawn_particles(player_pos, Color(1.0, 0.2, 0.0), 60, fire_radius)
		_screen_shake(8.0, 0.3)
		
		# 释放6个火花
		var base_angle = randf() * TAU
		for i in range(6):
			var dir = Vector2.RIGHT.rotated(base_angle + i * (TAU / 6.0))
			_create_spark_bullet(true, player_pos, dir)
	)
	var warn_dur = 2.0 if is_chain_chanting else chant_time
	warn.start_warning(player_pos, 1.0, fire_radius, warn_dur, atk * 1.2, null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)
	
	_hide_symbol()
	if is_chain_chanting:
		_choose_attack()
	else:
		is_attacking = false

func _attack_extreme_ice():
	_show_symbol("ice")
	var chant_time = 1.0 if is_chain_chanting else 2.0
	Global.emit_signal("boss_chant_start", "冰封", chant_time)
	
	var boss_pos = global_position
	var warn = WarnCircleUtil.new()
	warn.attacker = self
	get_tree().current_scene.add_child(warn)
	var ice_radius = 200.0 * 0.85
	warn.warning_finished.connect(func():
		if is_instance_valid(warn): warn.cleanup()
		_spawn_particles(boss_pos, Color(0.0, 0.8, 1.0), 80, ice_radius)
		_screen_shake(8.0, 0.3)
		
		var base_angle = randf() * TAU
		for i in range(6):
			var dir = Vector2.RIGHT.rotated(base_angle + i * (TAU / 6.0))
			_create_spark_bullet(false, boss_pos, dir)
			
		_hide_symbol()
		if is_chain_chanting:
			_choose_attack()
		else:
			is_attacking = false
	)
	warn.start_warning(boss_pos, 1.0, ice_radius, chant_time, atk * 1.2, null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)

func _attack_ring_thunder():
	_show_symbol("thunder")
	var chant_time = 1.0 if is_chain_chanting else 2.0
	Global.emit_signal("boss_chant_start", "暴雷", chant_time)
	
	var boss_pos = global_position
	
	# 自定义环形警告
	var ring_warn = _RingWarn.new()
	ring_warn.center = boss_pos
	ring_warn.inner_r = 75.0
	ring_warn.duration = chant_time
	get_tree().current_scene.add_child(ring_warn)
	
	await get_tree().create_timer(chant_time).timeout
	if is_instance_valid(ring_warn): ring_warn.queue_free()
	
	_spawn_particles(boss_pos, Color(0.6, 0.0, 1.0), 100, 400.0)
	_screen_shake(6.0, 0.3)
	
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		var diff = PC.player_instance.global_position - boss_pos
		# 判断是否在内圈 75 (3:2 椭圆，即 x轴=75, y轴=75/(3/2)=50.0)
		var norm_x = diff.x / 75.0
		var norm_y = diff.y / 50.0
		if (norm_x * norm_x + norm_y * norm_y) > 1.0:
			PC.apply_damage(int(atk * 1.5 * (1.0 - PC.damage_reduction_rate)))
			Global.emit_signal("player_hit", self )
			if PC.pc_hp <= 0: PC.player_instance.game_over()
			
	_hide_symbol()
	if is_chain_chanting:
		_choose_attack()
	else:
		is_attacking = false

class _RingWarn extends Node2D:
	var center: Vector2
	var inner_r: float = 75.0
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

func _attack_ground_fire():
	Global.emit_signal("boss_chant_start", "耀星", 1.0)
	var directions = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
	var size_scale = 1.3
	directions.shuffle()
	
	for round_idx in range(4):
		if is_dead: break
		var dir = directions[round_idx]
		
		var step_dist = 0.0
		var count = 0
		var start_pos1 = Vector2.ZERO
		var start_pos2 = Vector2.ZERO
		
		if dir == Vector2.DOWN:
			step_dist = 48.0 * size_scale # 40 + 8
			count = ceil((bottom_boundary - top_boundary) / step_dist)
			var valid_x = left_boundary + 30.0
			var max_x = right_boundary - 30.0
			var x1 = randf_range(valid_x, max_x)
			var x2 = randf_range(valid_x, max_x)
			while abs(x1 - x2) < 60.0:
				x2 = randf_range(valid_x, max_x)
			start_pos1 = Vector2(x1, top_boundary + 20.0)
			start_pos2 = Vector2(x2, top_boundary + 20.0)
			
		elif dir == Vector2.UP:
			step_dist = 48.0 * size_scale
			count = ceil((bottom_boundary - top_boundary) / step_dist)
			var valid_x = left_boundary + 30.0
			var max_x = right_boundary - 30.0
			var x1 = randf_range(valid_x, max_x)
			var x2 = randf_range(valid_x, max_x)
			while abs(x1 - x2) < 60.0:
				x2 = randf_range(valid_x, max_x)
			start_pos1 = Vector2(x1, bottom_boundary - 20.0)
			start_pos2 = Vector2(x2, bottom_boundary - 20.0)
			
		elif dir == Vector2.RIGHT:
			step_dist = 68.0 * size_scale # 60 + 8
			count = ceil((right_boundary - left_boundary) / step_dist)
			var valid_y = top_boundary + 20.0
			var max_y = bottom_boundary - 20.0
			var y1 = randf_range(valid_y, max_y)
			var y2 = randf_range(valid_y, max_y)
			while abs(y1 - y2) < 40.0:
				y2 = randf_range(valid_y, max_y)
			start_pos1 = Vector2(left_boundary + 30.0, y1)
			start_pos2 = Vector2(left_boundary + 30.0, y2)
			
		elif dir == Vector2.LEFT:
			step_dist = 68.0 * size_scale
			count = ceil((right_boundary - left_boundary) / step_dist)
			var valid_y = top_boundary + 20.0
			var max_y = bottom_boundary - 20.0
			var y1 = randf_range(valid_y, max_y)
			var y2 = randf_range(valid_y, max_y)
			while abs(y1 - y2) < 40.0:
				y2 = randf_range(valid_y, max_y)
			start_pos1 = Vector2(right_boundary - 30.0, y1)
			start_pos2 = Vector2(right_boundary - 30.0, y2)

		_spawn_ground_fire_line(start_pos1, dir, step_dist, int(count), size_scale)
		_spawn_ground_fire_line(start_pos2, dir, step_dist, int(count), size_scale)
		
		await get_tree().create_timer(0.75).timeout
		
	if is_chain_chanting:
		_choose_attack()
	else:
		is_attacking = false

func _spawn_ground_fire_line(start_pos: Vector2, direction: Vector2, step_dist: float, count: int, size_scale: float = 1.0):
	var current_pos = start_pos
	var actual_atk = atk
	var warning_radius = 20.0 * size_scale
	var particle_amount = int(ceil(10.0 * size_scale))
	var particle_radius = 45.0 * size_scale
	
	for i in range(count):
		if is_dead: break
		var warn = WarnCircleUtil.new()
		warn.attacker = self # 设置攻击者，用于player_hit信号
		get_tree().current_scene.add_child(warn)
		warn.global_position = current_pos
		var pos_to_damage = current_pos
		warn.warning_finished.connect(func():
			if is_instance_valid(warn): warn.cleanup()
			_spawn_particles(pos_to_damage, Color(1.0, 0.18, 0.08), particle_amount, particle_radius)
		)
		# 使用内置伤害判定：radius=26, aspect_ratio=1.5 得到 39x26 椭圆
		warn.start_warning(current_pos, 1.5, warning_radius, 1.0, actual_atk * 1.5, null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)
		
		await get_tree().create_timer(1.0).timeout
		current_pos += direction * step_dist

func _attack_cross_fire():
	_show_symbol("cross")
	var chant_time = 1.0 if is_chain_chanting else 1.5
	Global.emit_signal("boss_chant_start", "炽焰十字", chant_time)
	var boss_pos = global_position
	
	var warn1 = WarnRectUtil.new(); add_child(warn1)
	var warn2 = WarnRectUtil.new(); add_child(warn2)
	
	warn1.start_warning(boss_pos + Vector2(-600, 0), boss_pos + Vector2(600, 0), 96.0, chant_time, atk * 2.0)
	warn2.start_warning(boss_pos + Vector2(0, -600), boss_pos + Vector2(0, 600), 96.0, chant_time, atk * 2.0)
	
	await get_tree().create_timer(chant_time).timeout
	_hide_symbol()
	_spawn_particles(boss_pos, Color(1.0, 0.5, 0.0), 60, 200.0)
	_screen_shake(4.0, 0.2)
	
	if is_chain_chanting:
		_choose_attack()
	else:
		is_attacking = false

func _attack_x_ice():
	_show_symbol("x")
	var chant_time = 1.0 if is_chain_chanting else 1.5
	Global.emit_signal("boss_chant_start", "霜牙交错", chant_time)
	var boss_pos = global_position
	
	var warn1 = WarnRectUtil.new(); add_child(warn1)
	var warn2 = WarnRectUtil.new(); add_child(warn2)
	
	warn1.start_warning(boss_pos + Vector2(-500, -500), boss_pos + Vector2(500, 500), 96.0, chant_time, atk * 2.0)
	warn2.start_warning(boss_pos + Vector2(-500, 500), boss_pos + Vector2(500, -500), 96.0, chant_time, atk * 2.0)
	
	await get_tree().create_timer(chant_time).timeout
	_hide_symbol()
	_spawn_particles(boss_pos, Color(0.0, 0.5, 1.0), 60, 200.0)
	_screen_shake(4.0, 0.2)
	
	if is_chain_chanting:
		_choose_attack()
	else:
		is_attacking = false

func _attack_chain_chant():
	is_chain_chanting = true
	Global.emit_signal("boss_chant_start", "三连咏唱", 4.0)
	
	var first_skill_pool = [1, 3, 5, 6]
	var skill_1 = first_skill_pool[randi() % first_skill_pool.size()]
	var skill_2 = [5, 6][randi() % 2]
	var possible_3 = [2, 3]
	if possible_3.has(skill_1):
		possible_3.erase(skill_1)
	var skill_3 = possible_3[randi() % possible_3.size()]
	
	chain_skills_queue = [skill_1, skill_2, skill_3]
	
	var map_str = {1: "fire", 2: "ice", 3: "thunder", 5: "cross", 6: "x"}
	
	for i in range(3):
		if is_dead: return
		var mini_symbol = _create_spell_icon(map_str[chain_skills_queue[i]], Vector2(0.7, 0.7))
		mini_symbol.position = Vector2((i - 1) * 45, 20)
		mini_symbol.modulate.a = 0
		symbol_node.add_child(mini_symbol)
		
		var tw = mini_symbol.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mini_symbol, "modulate:a", 1.0, 0.3)
		tw.tween_property(mini_symbol, "position:y", 0.0, 0.3).set_ease(Tween.EASE_OUT)

		
		await get_tree().create_timer(1.0).timeout
	
	await get_tree().create_timer(1.0).timeout
	Global.emit_signal("boss_chant_end")
	_hide_symbol()
	
	# 接下去的攻击循环由队列处理
	_choose_attack()

# ================= 通用交互 =================

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , true)
		var final_damage_val = collision_result["final_damage"]
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
