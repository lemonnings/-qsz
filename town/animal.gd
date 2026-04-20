extends CharacterBody2D

## 动物行为脚本：idle/run交替，随机方向移动，撞墙换向

@export var speed: float = 60.0
@export var shadow_scale: float = 0.0 ## 阴影缩放比例，0表示不绘制阴影

enum State {IDLE, RUN}

var state: State = State.IDLE
var state_timer: float = 0.0
var move_direction: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if shadow_scale > 0.0:
		var shadow_width = 22.0 * shadow_scale
		var shadow_height = 7.0 * shadow_scale
		var shadow_offset_y = 7.0 * shadow_scale
		CharacterEffects.create_shadow(self , shadow_width, shadow_height, shadow_offset_y)
	_enter_idle()


func _physics_process(delta: float) -> void:
	state_timer -= delta

	match state:
		State.IDLE:
			if state_timer <= 0.0:
				_enter_run()
		State.RUN:
			velocity = move_direction * speed
			move_and_slide()
			if is_on_wall():
				_change_direction()
			if state_timer <= 0.0:
				_enter_idle()


func _enter_idle() -> void:
	state = State.IDLE
	state_timer = randf_range(4.0, 8.0)
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.play("idle")


func _enter_run() -> void:
	state = State.RUN
	state_timer = randf_range(1.0, 4.0)
	_change_direction()
	if animated_sprite:
		animated_sprite.play("run")


func _change_direction() -> void:
	var angle := randf_range(0.0, TAU)
	move_direction = Vector2(cos(angle), sin(angle))
	if animated_sprite and move_direction.x != 0.0:
		animated_sprite.flip_h = move_direction.x < 0.0
