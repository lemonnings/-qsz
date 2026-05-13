extends Area2D

@export var bullet_speed: float # Boss子弹速度
@export var bullet_damage: float # Boss子弹伤害
@export var bullet_range: float = 4000.0 # 子弹射程
@export var rotation_speed_degrees: float = 680.0
@export var source_name: String = "远程攻击" # 伤害来源名称，可由外部设置

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var traveled_distance: float = 0.0
var bounce_count: int = 0
var max_bounces: int = 10

func _ready() -> void:
	# 记录子弹起始位置
	start_position = global_position
	
	# 添加到bullet组
	add_to_group("boss_bullet")
	
	# 红色描边
	var anim_sprite = get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.material = ShaderMaterial.new()
		anim_sprite.material.shader = _get_outline_shader()
		anim_sprite.material.set_shader_parameter("outline_color", Color.RED)
		anim_sprite.material.set_shader_parameter("outline_width", 2.0)
	
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 3秒后自动销毁
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# 子弹移动
	position += direction * bullet_speed * delta
	rotation += deg_to_rad(rotation_speed_degrees * delta)
	# 更新已飞行距离
	traveled_distance = start_position.distance_to(global_position)
	
	# 检查是否超出射程
	if traveled_distance >= bullet_range:
		queue_free()


func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	# 设置子弹旋转角度
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	# 击中玩家
	if body.is_in_group("player"):
		PC.player_hit(int(int(bullet_damage)), self , source_name)
		queue_free()
		return
	
	# 击中石块 — 基于入射角反弹
	if body.is_in_group("stone_block") or (body.get_parent() and body.get_parent().is_in_group("stone_block")):
		_bounce_off_stone(body)
		return

func _bounce_off_stone(body: Node2D) -> void:
	bounce_count += 1
	if bounce_count > max_bounces:
		# 超过反弹次数，渐隐销毁
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
		return
	
	# 计算反弹方向：基于石块表面的法线
	# body 是 StaticBody2D，其 global_position 就是石块位置
	var stone_pos = body.global_position
	
	# 入射方向到石块中心的反方向即为法线近似
	var normal = (global_position - stone_pos).normalized()
	if normal == Vector2.ZERO:
		normal = -direction
	
	# 反射公式：出射 = 入射 - 2*(入射·法线)*法线
	var reflected = direction - 2.0 * direction.dot(normal) * normal
	direction = reflected.normalized()
	rotation = direction.angle()
	
	# 将子弹推出石块避免重复碰撞
	global_position += normal * 8.0

func _on_area_entered(area: Area2D) -> void:
	# 可以在这里处理与其他区域的碰撞
	pass

## 生成描边shader代码
static func _get_outline_shader() -> Shader:
	var code = """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
	float a = max(max(max(
		texture(TEXTURE, UV + vec2(ps.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(ps.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, ps.y)).a,
			texture(TEXTURE, UV - vec2(0.0, ps.y)).a)),
		max(max(
			texture(TEXTURE, UV + vec2(ps.x, ps.y)).a,
			texture(TEXTURE, UV - vec2(ps.x, ps.y)).a),
			max(texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a,
				texture(TEXTURE, UV - vec2(-ps.x, ps.y)).a)));
	if (col.a < 0.01 && a > 0.01) {
		col = outline_color;
		col.a = a;
	}
	COLOR = col;
}
"""
	var s = Shader.new()
	s.code = code
	return s
