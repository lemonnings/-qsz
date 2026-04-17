extends Node2D

# 导出Label节点，用于在编辑器中指定
@export var damage_label: Label

# 定义伤害类型的常量，方便管理和引用
enum DamageType {
	PLAYER_BULLET, # 玩家子弹伤害
	PLAYER_BULLET_CRIT, # 玩家子弹暴击伤害
	SUMMON_DAMAGE, # 召唤物伤害
	PLAYER_SKILL, # 玩家技能伤害
	DOT_ELECTRIFIED, # 感电持续伤害
	DOT_BURN, # 燃烧持续伤害
	DOT_BLEED, # 流血持续伤害
	DOT_POISON, # 中毒持续伤害
	HEAL, # 治疗
	SHIELD_ABSORB, # 护盾吸收
	PLAYER_HURT # 玩家受伤
}

# 伤害类型对应的颜色
const DAMAGE_COLORS = {
	DamageType.PLAYER_BULLET: Color.WHITE,
	DamageType.PLAYER_BULLET_CRIT: Color.ORANGE, # 橙红色
	DamageType.SUMMON_DAMAGE: Color.SKY_BLUE, # 浅蓝色
	DamageType.PLAYER_SKILL: Color.YELLOW,
	DamageType.DOT_ELECTRIFIED: Color8(160, 210, 255),
	DamageType.DOT_BURN: Color8(255, 205, 160),
	DamageType.DOT_BLEED: Color8(255, 160, 160),
	DamageType.DOT_POISON: Color8(160, 230, 160),
	DamageType.HEAL: Color8(144, 238, 144), # 浅绿色
	DamageType.SHIELD_ABSORB: Color.GRAY, # 灰色
	DamageType.PLAYER_HURT: Color.RED # 红色
}

var base_font_size: int = 0

# 伤害层级
# 层级计算：数值 >= 1000 时，每多一个0层级+1
# 例如：1000=层级0，10000=层级1，100000=层级2

func _ready():
	# 初始化时确保Label节点已设置
	if not damage_label:
		printerr("DamageDisplay: Label node not assigned!")
		# 可以选择禁用节点或进行其他错误处理
		# set_process(false)
		# set_physics_process(false)
		# queue_free()
		return
	# 初始时可以隐藏Label
	damage_label.visible = false
	base_font_size = damage_label.get_theme_font_size("font_size")

# 信号处理函数
# damage_type: 使用 DamageType 枚举的值
# damage_value: 具体的伤害数值
# display_position: 伤害数字显示的世界坐标 (可选, 如果不提供，则使用此节点的当前位置)
func show_damage_number(damage_type_int: int, damage_value: float, display_position: Vector2 = global_position, source_name: String = ""):
	if not damage_label:
		printerr("DamageDisplay: Label node not assigned, cannot show damage.")
		return
	if damage_value <= 0:
		return
	var damage_type = DamageType.PLAYER_BULLET
	if damage_type_int == 2:
		damage_type = DamageType.PLAYER_BULLET_CRIT
	if damage_type_int == 3:
		damage_type = DamageType.PLAYER_SKILL
	if damage_type_int == 4:
		damage_type = DamageType.SUMMON_DAMAGE
	if damage_type_int == 5:
		damage_type = DamageType.DOT_ELECTRIFIED
	if damage_type_int == 6:
		damage_type = DamageType.DOT_BURN
	if damage_type_int == 7:
		damage_type = DamageType.DOT_BLEED
	if damage_type_int == 8:
		damage_type = DamageType.DOT_POISON
	if damage_type_int == 9:
		damage_type = DamageType.HEAL
	if damage_type_int == 10:
		damage_type = DamageType.SHIELD_ABSORB
	if damage_type_int == 11:
		damage_type = DamageType.PLAYER_HURT
		
	# 设置显示位置
	global_position = display_position

	# 设置颜色文本
	var base_color = Color.WHITE
	if DAMAGE_COLORS.has(damage_type):
		base_color = DAMAGE_COLORS[damage_type]
	
	# 设置颜色
	damage_label.modulate = base_color

	var format_result = _format_damage(damage_value)
	var text_to_display: String = format_result["text"]
	var font_bonus: int = format_result["font_bonus"]
	
	# 加入伤害来源名称前缀
	if (damage_type == DamageType.PLAYER_HURT or damage_type == DamageType.SHIELD_ABSORB) and source_name != "":
		text_to_display = source_name + " " + text_to_display
	
	damage_label.scale = damage_label.scale * 0.8
	
	# 整体字号在现有基础上 -2；DOT/护盾类型额外 -2；是万/k时+2，是亿/m时+4
	var final_font_size: int
	if damage_type == DamageType.DOT_ELECTRIFIED or damage_type == DamageType.DOT_BURN or damage_type == DamageType.DOT_BLEED or damage_type == DamageType.DOT_POISON or damage_type == DamageType.SHIELD_ABSORB:
		final_font_size = base_font_size - 4 + font_bonus
	else:
		final_font_size = base_font_size - 2 + font_bonus
	damage_label.add_theme_font_size_override("font_size", final_font_size)
	if damage_type == DamageType.PLAYER_BULLET_CRIT:
		text_to_display += " !"
		damage_label.scale = damage_label.scale * 1.15
	
	if damage_type == DamageType.SHIELD_ABSORB:
		# 护盾损失：向右偏移25，向上偏移10
		global_position.x -= 5.0
		global_position.y -= 25.0
	elif damage_type == DamageType.PLAYER_HURT or damage_type == DamageType.HEAL:
		# 玩家受伤：向上偏移10
		global_position.x -= 25.0
		global_position.y -= 25.0
	else:
		pass
	global_position.x += randf_range(-3.0, 3.0)
	global_position.y += randf_range(-3.0, 3.0)
	
	damage_label.text = text_to_display
	# 初始透明度为0，用于渐入
	damage_label.modulate.a = 0.0
	damage_label.visible = true

	# 创建动画
	var tween = create_tween()
	tween.set_parallel(false) # 确保动画按顺序播放
	tween.set_trans(Tween.TRANS_QUINT) # 使用缓动函数使动画更平滑
	tween.set_ease(Tween.EASE_OUT) # 缓动类型

	# 1. 初始显示 (渐入)
	tween.tween_property(damage_label, "modulate:a", 1.0, 0.25)

	# 2. 保持显示1s，暴击额外0.6s
	# 注意：tween_interval 会等待前面的动画完成后再执行
	if damage_type == DamageType.PLAYER_BULLET_CRIT:
		tween.tween_interval(1)
	else:
		tween.tween_interval(0.5)

	# 3. 向上飘动并渐隐
	# 获取当前damage_label的相对位置
	var current_label_pos = damage_label.position
	
	tween.tween_property(damage_label, "position:y", current_label_pos.y - 20.0, 0.5)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.5)

	# 动画完成后自动销毁节点
	tween.finished.connect(queue_free)

# 根据 Global.damage_show_type 对伤害数字进行格式化
# 返回字典: {"text": 显示文本, "font_bonus": 字号加成（小单位+2，大单位+4）}
func _format_damage(damage_value: float) -> Dictionary:
	var show_type: int = Global.damage_show_type
	var raw: int = int(round(damage_value))
	var text: String
	var font_bonus: int = 0
	if show_type == 1:
		# 中式缩写：超过10亿显示xx.xx亿，超过10万显示xx.xx万
		if damage_value >= 1000000000:
			text = "%.2f亿" % (damage_value / 100000000.0)
			font_bonus = 4
		elif damage_value >= 100000:
			text = "%.2f万" % (damage_value / 10000.0)
			font_bonus = 2
		else:
			text = str(raw)
	elif show_type == 2:
		# 英式缩写：超过10亿显示xx.xxb，超过1000万显示xx.xxm，超过1万显示xx.xxk
		if damage_value >= 1000000000:
			text = "%.2fb" % (damage_value / 1000000000.0)
			font_bonus = 5
		elif damage_value >= 10000000:
			text = "%.2fm" % (damage_value / 1000000.0)
			font_bonus = 3
		elif damage_value >= 10000:
			text = "%.2fk" % (damage_value / 1000.0)
			font_bonus = 1
		else:
			text = str(raw)
	else:
		text = str(raw)
	return {"text": text, "font_bonus": font_bonus}

# 计算伤害层级
# 层级计算：数值 >= 1000 时，每多一个0层级+1
# 1000=层级0, 10000=层级1, 100000=层级2, ...
func _get_damage_tier(damage_value: float) -> int:
	if damage_value < 1000:
		return -1 # 低于1000无层级
	var tier = 0
	var val = damage_value
	while val >= 10000:
		val /= 10
		tier += 1
		if tier >= 7: # 最高层级7
			break
	return tier
