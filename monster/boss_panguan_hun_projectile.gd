extends Area2D

const OUTLINE_COLOR: Color = Color(1.0, 0.0, 0.0, 1.0)
const OUTLINE_THICKNESS: float = 0.9
const DEFAULT_MAX_RANGE: float = 3000.0
const VISUAL_SCALE_MULTIPLIER: float = 0.85

static var _outline_shader: Shader = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.DOWN
var speed: float = 50.96
var atk: float = 0.0
var source_name: String = "泼墨·墨灵"
var source_attacker: Node2D = null
var max_range: float = DEFAULT_MAX_RANGE
var traveled_distance: float = 0.0


func _ready() -> void:
	_setup_outline()
	if sprite != null:
		sprite.scale *= VISUAL_SCALE_MULTIPLIER
		sprite.play("default")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup_projectile(spawn_position: Vector2, projectile_direction: Vector2, damage: float, projectile_speed: float, attacker: Node2D, projectile_source_name: String = "泼墨·墨灵") -> void:
	global_position = spawn_position
	direction = projectile_direction.normalized() if projectile_direction.length_squared() > 0.001 else Vector2.DOWN
	atk = damage
	speed = projectile_speed
	source_attacker = attacker
	source_name = projectile_source_name
	traveled_distance = 0.0
	rotation = direction.angle() - Vector2.DOWN.angle()
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	traveled_distance += step.length()
	if traveled_distance >= max_range:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.is_in_group("player")):
		return
	var attacker := source_attacker if is_instance_valid(source_attacker) else self
	PC.player_hit(int(atk), attacker, source_name)
	queue_free()


func _setup_outline() -> void:
	if sprite == null:
		return
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _get_outline_shader()
	shader_material.set_shader_parameter("line_color", OUTLINE_COLOR)
	shader_material.set_shader_parameter("line_thickness", OUTLINE_THICKNESS)
	sprite.material = shader_material


static func _get_outline_shader() -> Shader:
	if _outline_shader != null:
		return _outline_shader
	_outline_shader = Shader.new()
	_outline_shader.code = """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0, 4) = 0.9;

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
