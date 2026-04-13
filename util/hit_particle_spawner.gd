# 击中粒子特效工具类
# 用于在武器/技能击中敌人时生成像素风格的崩散粒子
# 使用 CPUParticles2D 实现，性能开销极低（单次 6~10 个粒子，one-shot 自动回收）
# 调用方式: HitParticleSpawner.spawn(scene_tree, world_position)
class_name HitParticleSpawner

# 像素纹理缓存 —— 全局共享，避免每次击中都重新创建
static var _pixel_tex: ImageTexture = null

# ====== 可调参数 ======
const DEFAULT_AMOUNT: int = 7 # 默认粒子数量
const PARTICLE_LIFETIME: float = 0.5 # 粒子存活时间(秒)
const VELOCITY_MIN: float = 210.0 # 初始飞散速度下限
const VELOCITY_MAX: float = 270.0 # 初始飞散速度上限
const DAMPING_MIN: float = 220.0 # 阻尼下限（使粒子减速）
const DAMPING_MAX: float = 300.0 # 阻尼上限
const GRAVITY: Vector2 = Vector2(0, 240) # 重力（轻微向下）
const SCALE_MIN: float = 1.3 # 粒子最小缩放
const SCALE_MAX: float = 2 # 粒子最大缩放
const ANGLE_VEL_MIN: float = 60.0 # 粒子自旋速度下限（度/秒）
const ANGLE_VEL_MAX: float = 240.0 # 粒子自旋速度上限（度/秒）
const DEFAULT_COLOR: Color = Color(1.0, 0.45, 0.4, 1.0) # 默认浅红色（swordQi）

# ====== 武器粒子配置映射 ======
# 格式: "weapon_tag": {"color": Color, "amount": int}
const WEAPON_PARTICLE_CONFIG: Dictionary = {
	"branch": {"color": Color(0.6, 0.4, 0.3, 1.0), "amount": 5}, # 褐色
	"riyan": {"color": Color(1.0, 0.6, 0.2, 1.0), "amount": 5}, # 橙色
	"thunder": {"color": Color(1.0, 0.78, 0.24, 1.0), "amount": 5}, # 偏橙黄
	"thunder_break": {"color": Color(0.5, 0.7, 1.0, 1.0), "amount": 7}, # 浅蓝色
	"water": {"color": Color(0.4, 0.7, 1.0, 1.0), "amount": 5}, # 淡蓝色
	"blood_wave": {"color": Color(1.0, 0.2, 0.2, 1.0), "amount": 5}, # 红色
	"blood_broadsword": {"color": Color(1.0, 0.2, 0.2, 1.0), "amount": 6}, # 红色
	"light_bullet": {"color": Color(1.0, 0.9, 0.3, 1.0), "amount": 5}, # 黄色
	"xuanwu": {"color": Color(0.5, 0.6, 0.65, 1.0), "amount": 6}, # 青灰色
	"xunfeng": {"color": Color(0.5, 1.0, 0.5, 1.0), "amount": 7}, # 浅绿色
	"genshan": {"color": Color(0.6, 0.4, 0.3, 1.0), "amount": 7}, # 褐色
	"qigong": {"color": Color(0.5, 1.0, 0.5, 1.0), "amount": 7}, # 浅绿色
	"ice_flower": {"color": Color(0.6, 0.85, 1.0, 1.0), "amount": 7}, # 浅蓝色
}


## 根据武器标签生成击中崩散粒子
## [br][param weapon_tag] 武器标签，用于查找预设的粒子配置
## [br]若武器标签不在映射中，使用默认浅红色、5个粒子
static func spawn_by_weapon(tree: SceneTree, world_pos: Vector2, weapon_tag: String) -> void:
	var config = WEAPON_PARTICLE_CONFIG.get(weapon_tag, {})
	var color: Color = config.get("color", DEFAULT_COLOR)
	var amount: int = config.get("amount", DEFAULT_AMOUNT)
	spawn(tree, world_pos, amount, color)


## 在指定位置生成击中崩散粒子
## [br][param amount] 粒子数量，默认6
## [br][param color] 粒子颜色，不同武器/技能可传入各自的颜色，默认浅红色
## [br]自动检查 [code]Global.settings_manager.is_particle_enabled()[/code]
static func spawn(tree: SceneTree, world_pos: Vector2, amount: int = DEFAULT_AMOUNT, color: Color = DEFAULT_COLOR) -> void:
	# 粒子开关检查
	if not Global.settings_manager.is_particle_enabled():
		return
	if tree == null or tree.current_scene == null:
		return

	var p := CPUParticles2D.new()

	# —— 基础设置 ——
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = PARTICLE_LIFETIME
	p.explosiveness = 1.0 # 所有粒子瞬间释放

	# —— 方向与速度 ——
	p.direction = Vector2(0, -1) # 基准方向向上
	p.spread = 180.0 # 全方向随机飞散
	p.initial_velocity_min = VELOCITY_MIN
	p.initial_velocity_max = VELOCITY_MAX

	# —— 物理 ——
	p.gravity = GRAVITY
	p.damping_min = DAMPING_MIN
	p.damping_max = DAMPING_MAX

	# —— 外观 ——
	p.scale_amount_min = SCALE_MIN
	p.scale_amount_max = SCALE_MAX
	p.color = color
	p.texture = _get_pixel_texture()

	# —— 自旋：赋予粒子随机旋转速度，增加像素崩散质感 ——
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = ANGLE_VEL_MIN
	p.angular_velocity_max = ANGLE_VEL_MAX

	# —— 渐隐：前35%保持不透明，之后平滑渐隐至完全透明 ——
	# 注意：必须先 set_color 设好两端，再 add_point 插入中间点，否则 index 错位导致渐变异常
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1.0)) # index 0, offset 0.0: 出生完全不透明
	gradient.set_color(1, Color(1, 1, 1, 0.0)) # index 1, offset 1.0: 消失完全透明
	gradient.add_point(0.35, Color(1, 1, 1, 1.0)) # 在 35% 处插入保持不透明点，之后才渐变
	p.color_ramp = gradient

	# —— 定位与层级 ——
	p.global_position = world_pos
	p.z_index = 10

	# 添加到场景
	tree.current_scene.add_child(p)

	# 生命周期结束后自动销毁节点
	tree.create_timer(PARTICLE_LIFETIME + 0.15).timeout.connect(
		func():
			if is_instance_valid(p):
				p.queue_free()
	)


## 获取 / 懒创建 2×2 白色像素纹理（像素风格核心）
static func _get_pixel_texture() -> ImageTexture:
	if _pixel_tex != null:
		return _pixel_tex
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_pixel_tex = ImageTexture.create_from_image(img)
	return _pixel_tex
