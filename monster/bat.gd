extends Area2D

@onready var sprite = $AnimatedSprite2D
var debuff_manager: EnemyDebuffManager
var is_dead : bool = false

# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色
var move_direction : int = 1

var base_speed : float = SettingMoster.bat("speed")
var speed : float # Actual speed after debuffs
var hpMax : float = SettingMoster.bat("hp")
var hp : float = SettingMoster.bat("hp")
var atk : float = SettingMoster.bat("atk")
var get_point : int = SettingMoster.bat("point")
var get_exp : int = SettingMoster.bat("exp")
var get_mechanism : int = SettingMoster.bat("mechanism")
var health_bar_shown: bool = false

signal debuff_applied(debuff_id: String)

var health_bar: Node2D
var progress_bar: ProgressBar

var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

func _ready():
	debuff_manager = EnemyDebuffManager.new(self)
	add_child(debuff_manager)
	debuff_applied.connect(debuff_manager.add_debuff)
	speed = base_speed # Initialize speed

func show_health_bar():
	if not health_bar_shown:
		health_bar = preload("res://Scenes/global/hp_bar.tscn").instantiate()
		add_child(health_bar)
		health_bar.z_index = 100
		progress_bar = health_bar.get_node("HPBar")
		progress_bar.position = global_position + Vector2(-15, -10)
		health_bar_shown = true
		progress_bar.top_level = true
	elif progress_bar and progress_bar.is_inside_tree():
		progress_bar.position = global_position + Vector2(-15, -10)
		var target_value_hp = (float(hp / hpMax)) * 100
		if progress_bar.value != target_value_hp:
			var tween = create_tween()
			tween.tween_property(progress_bar, "value", target_value_hp, 0.15)
		
func free_health_bar():
	if health_bar != null and health_bar.is_inside_tree():
		health_bar.queue_free()

func _physics_process(delta: float) -> void:
	if hp < hpMax and hp > 0:
		show_health_bar()

	# 处理敌人之间的碰撞
	var overlapping_bodies = get_overlapping_areas()
	for body in overlapping_bodies:
		if body.is_in_group("enemies") and body.is_in_group("fly") and body != self:
			var direction_to_other = global_position.direction_to(body.global_position)
			# 将自己推离另一个敌人
			# 这个力量可以根据需要调整
			var push_strength = 2.0 # 可以根据需要调整推力大小
			position -= direction_to_other * push_strength * delta * 100 # 乘以一个系数使效果更明显

		
	if not is_dead:
		if move_direction == 0:
			position += Vector2(speed, 0) * delta
			sprite.flip_h = true;
		if move_direction == 1:
			position -= Vector2(speed, 0) * delta
			sprite.flip_h = false;
		if move_direction >= 2:
			# 靠近角色的移动方式
			if PC.player_instance != null:
				var player_pos = PC.player_instance.global_position
				var direction_to_player = (player_pos - global_position).normalized()
				speed = base_speed * debuff_manager.get_speed_multiplier()
				position += direction_to_player * speed * delta
				# 根据移动方向设置精灵翻转
				if direction_to_player.x > 0:
					sprite.flip_h = true
				else:
					sprite.flip_h = false
	
	# 确保蝙蝠不会因为推动而移出边界太快，这里可以添加更复杂的边界检查逻辑
	# 例如: position.x = clamp(position.x, min_x, max_x)

	if move_direction == 0 and position.x <= -534:
		free_health_bar()
		queue_free()
		
	if move_direction == 1 and position.x >= 534:
		free_health_bar()
		queue_free()
		
	if hp <= 0:
		free_health_bar()
		if not is_dead: # Add this check
			$AnimatedSprite2D.stop()
			$AnimatedSprite2D.play("death")
			get_tree().current_scene.point += get_point
			Global.total_points += get_point
			PC.pc_exp += get_exp
			Global.emit_signal("monster_mechanism_gained", get_mechanism)
			var change = randf()
			if PC.selected_rewards.has("SplitSwordQi13") and change <= 0.05:
				Global.emit_signal("_fire_ring_bullets")
			$death.play()
			is_dead = true
			if SettingMoster.bat("itemdrop") != null:
				for key in SettingMoster.bat("itemdrop"):
					var drop_chance = SettingMoster.bat("itemdrop")[key]
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 1, global_position)

			await get_tree().create_timer(0.35).timeout
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if(body is CharacterBody2D and not is_dead and not PC.invincible) :
		Global.emit_signal("player_hit")
		var damage_before_debuff = atk * (1.0 - PC.damage_reduction_rate)
		var actual_damage = int(damage_before_debuff * debuff_manager.get_take_damage_multiplier())
		PC.pc_hp -= actual_damage
		if PC.pc_hp <= 0:
			body.game_over()


func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	var final_damage = int(damage * debuff_manager.get_damage_multiplier())
	if damage_type == "sword_wave":
		var current_time = Time.get_ticks_msec() / 1000.0
		if PC.selected_rewards.has("SplitSwordQi22"):
			current_time = current_time / 2
		if current_time - last_sword_wave_damage_time >= SWORD_WAVE_DAMAGE_INTERVAL:
			hp -= final_damage
			last_sword_wave_damage_time = current_time
	else:
		hp -= final_damage


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		# 使用BulletCalculator处理完整的子弹碰撞逻辑
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, false)
		
		# 根据穿透逻辑决定是否销毁子弹
		if collision_result["should_delete_bullet"]:
			area.queue_free()
			
		var base_bullet_damage = collision_result["final_damage"]
		var final_damage_val = int(base_bullet_damage * debuff_manager.get_damage_multiplier())
		var is_crit = collision_result["is_crit"]
		
		# 处理子弹反弹
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
			
		hp -= int(final_damage_val)
		if hp <= 0:
			# 如果已经死亡，则不重复播放死亡动画，也不播放受击动画
			if not is_dead:
				$AnimatedSprite2D.play("death")
		else:
			Global.play_hit_anime(position, is_crit)

func apply_debuff_effect(debuff_id: String):
	emit_signal("debuff_applied", debuff_id)

func apply_knockback(direction: Vector2, force: float):
	var tween = create_tween()
	tween.tween_property(self, "position", global_position + direction * force, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
