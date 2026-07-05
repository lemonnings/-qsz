extends Area2D

@onready var animated_sprite_2d = $AnimatedSprite2D

const DEFAULT_SPEED: float = 150.0
const DEFAULT_MAX_RANGE: float = 900.0
const OUTLINE_COLOR: Color = Color(1.0, 0.0, 0.0, 1.0)
const OUTLINE_THICKNESS: float = 0.8
static var _outline_shader: Shader = null

var speed: float = DEFAULT_SPEED # 火球飞行速度
var direction = Vector2.RIGHT # 火球默认飞行方向
var atk: float = SettingMoster.frog("atk") # 火球攻击力，与青蛙一致
var max_range: float = DEFAULT_MAX_RANGE # 默认保持原 6 秒 * 150 速度的销毁距离
var traveled_distance: float = 0.0

func _ready() -> void:
	_resolve_nodes()
	traveled_distance = 0.0
	add_to_group(Global.MORETIP_OUTLINE_TARGET_GROUP)
	_setup_outline_material()
	set_outline_enabled(Global.moretip)

func _resolve_nodes() -> void:
	if not animated_sprite_2d:
		animated_sprite_2d = get_node_or_null("AnimatedSprite2D")

func _setup_outline_material() -> void:
	_resolve_nodes()
	if animated_sprite_2d == null:
		return
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _get_outline_shader()
	shader_material.set_shader_parameter("line_color", OUTLINE_COLOR)
	shader_material.set_shader_parameter("line_thickness", OUTLINE_THICKNESS)
	animated_sprite_2d.material = shader_material

func set_outline_enabled(enabled: bool) -> void:
	_resolve_nodes()
	if animated_sprite_2d == null:
		return
	if animated_sprite_2d.material == null:
		_setup_outline_material()
	animated_sprite_2d.use_parent_material = not enabled

func setup_projectile(spawn_position: Vector2, dir: Vector2, p_atk: float, p_speed: float = DEFAULT_SPEED, p_max_range: float = DEFAULT_MAX_RANGE) -> void:
	_resolve_nodes()
	global_position = spawn_position
	traveled_distance = 0.0
	atk = p_atk
	speed = p_speed
	max_range = p_max_range
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	set_direction(dir)
	play_animation("fire")

func _physics_process(delta):
	# 每帧更新火球位置
	var step = direction * speed * delta
	position += step
	traveled_distance += step.length()
	if traveled_distance >= max_range:
		ObjectPool.recycle(self )

# 设置火球的飞行方向 (支持任意方向)
func set_direction(dir: Vector2):
	_resolve_nodes()
	# 标准化方向向量
	direction = dir.normalized()
	# 根据方向设置sprite的旋转角度
	if animated_sprite_2d:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		# 设置sprite旋转以匹配飞行方向
		animated_sprite_2d.rotation = angle

# 播放指定的动画
func play_animation(anim_name: String):
	_resolve_nodes()
	if animated_sprite_2d:
		animated_sprite_2d.play(anim_name)

# 当火球碰撞到其他物体时触发
func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	if not PC.invincible:
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate)) # 计算实际伤害，考虑减伤
		PC.player_hit(int(actual_damage), self , "") # 扣除玩家血量
	ObjectPool.recycle(self ) # 火球击中目标后消失

func reset_for_pool() -> void:
	speed = DEFAULT_SPEED
	direction = Vector2.RIGHT
	atk = SettingMoster.frog("atk")
	max_range = DEFAULT_MAX_RANGE
	traveled_distance = 0.0
	global_position = Vector2.ZERO
	rotation = 0.0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_resolve_nodes()
	if animated_sprite_2d:
		animated_sprite_2d.rotation = 0.0
		animated_sprite_2d.animation = "fire"
		animated_sprite_2d.frame = 0
		animated_sprite_2d.play("fire")
	set_outline_enabled(Global.moretip)

static func _get_outline_shader() -> Shader:
	if _outline_shader != null:
		return _outline_shader
	_outline_shader = Shader.new()
	_outline_shader.code = """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0, 4) = 0.8;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
	float outline = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
	outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
	outline = min(outline, 1.0);
	vec4 tex_color = texture(TEXTURE, UV) * COLOR;
	COLOR = mix(tex_color, line_color, max(outline - tex_color.a, 0.0));
}
"""
	return _outline_shader
