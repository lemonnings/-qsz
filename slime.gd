extends Area2D

@onready var sprite = $AnimatedSprite2D
var is_dead : bool = false
# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色
var move_direction : int = 1

var slime_speed : float = SettingMoster.slime("speed")
var hpMax : float = SettingMoster.slime("hp")
var hp : float = SettingMoster.slime("hp")
var atk : float = SettingMoster.slime("atk")
var get_point : int = SettingMoster.slime("point") 
var get_exp : int = SettingMoster.slime("exp")
var get_mechanism : int = SettingMoster.slime("mechanism")
var health_bar_shown: bool = false
var health_bar: Node2D
var progress_bar: ProgressBar

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
		
	if not is_dead:
		if move_direction == 0:
			position += Vector2(slime_speed, 0) * delta
			sprite.flip_h = true;
		if move_direction == 1:
			position -= Vector2(slime_speed, 0) * delta
			sprite.flip_h = false;
	
	if move_direction == 0 and position.x <= -534:
		free_health_bar()
		queue_free()
		
	if move_direction == 1 and position.x >= 534:
		free_health_bar()
		queue_free()


# 检查怪物是否在可伤害范围内（超出视野20px就不判定了）
func _is_monster_in_damage_range() -> bool:
	# 获取摄像头
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return true  # 如果没有摄像头，默认可以伤害
	
	# 获取视野范围
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_zoom = camera.zoom
	var visible_size = viewport_size / camera_zoom
	
	# 计算摄像头的可视区域边界
	var camera_pos = camera.global_position
	var half_visible_size = visible_size / 2
	
	var left_bound = camera_pos.x - half_visible_size.x
	var right_bound = camera_pos.x + half_visible_size.x
	var top_bound = camera_pos.y - half_visible_size.y
	var bottom_bound = camera_pos.y + half_visible_size.y
	
	var screen_pixel_margin = 20.0 
	if camera_zoom.x == 0.0 or camera_zoom.y == 0.0:
		pass
	else:
		var world_margin_x = screen_pixel_margin / camera_zoom.x
		var world_margin_y = screen_pixel_margin / camera_zoom.y
		
		left_bound -= world_margin_x
		right_bound += world_margin_x
		top_bound -= world_margin_y
		bottom_bound += world_margin_y
	
	# 检查怪物位置是否在可伤害范围内
	var monster_pos = global_position
	return (monster_pos.x >= left_bound and monster_pos.x <= right_bound and 
			monster_pos.y >= top_bound and monster_pos.y <= bottom_bound)


func _on_body_entered(body: Node2D) -> void:
	if(body is CharacterBody2D and not is_dead and not PC.invincible) :
		Global.emit_signal("player_hit")
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
		PC.pc_hp -= actual_damage
		if PC.pc_hp <= 0:
			body.game_over()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		# 检查怪物是否在视野范围内（超出视野20px才能被伤害）
		if not _is_monster_in_damage_range():
			return
		
		# 使用BulletCalculator处理完整的子弹碰撞逻辑
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, false)
		var final_damage_val = collision_result["final_damage"]
		var is_crit = collision_result["is_crit"]
		
		hp -= int(final_damage_val)
		
		# 处理子弹反弹
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
			
		if hp <= 0:
			free_health_bar()
			$AnimatedSprite2D.play("death")
			if not is_dead:
				get_tree().current_scene.point += get_point
				Global.total_points += get_point
				PC.pc_exp += get_exp
				Global.emit_signal("monster_mechanism_gained", get_mechanism)
				$death.play()
				area.queue_free()
			is_dead = true
			
			await get_tree().create_timer(0.35).timeout
			queue_free()
		else:
			Global.play_hit_anime(position, is_crit)
			area.queue_free()
