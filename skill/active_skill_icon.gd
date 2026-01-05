extends TextureButton

# 主动技能图标
# 与自动攻击技能不同，只有主动使用时才会进入冷却

var skill_name: String = "" # 技能名称ID（对应Global.player_now_active_skill中的name）
var slot_key: String = "" # 槽位键（space/q/e）
var cooldown_time: float = 0.0 # 冷却时间
var current_cooldown: float = 0.0 # 当前剩余冷却
var is_on_cooldown: bool = false # 是否在冷却中
var is_paused: bool = false

# 快捷键标签 - 使用运行时获取，不使用@export（因为脚本是动态替换的）
var hotkey_label: Label = null
var cooldown_label: Label = null
var cooldown_progress: TextureProgressBar = null

func _ready() -> void:
	# 获取或创建UI节点
	_setup_ui_nodes()
	
	if cooldown_label:
		cooldown_label.hide()
	if cooldown_progress:
		cooldown_progress.value = 0
		cooldown_progress.texture_progress = texture_normal
	
	# 连接主动技能管理器信号
	if Global.ActiveSkillManager:
		Global.ActiveSkillManager.skill_cooldown_started.connect(_on_skill_cooldown_started)
		Global.ActiveSkillManager.skill_cooldown_finished.connect(_on_skill_cooldown_finished)

func _setup_ui_nodes() -> void:
	"""设置UI节点引用"""
	cooldown_label = get_node_or_null("Label")
	cooldown_progress = get_node_or_null("TextureProgressBar")
	
	# 创建HotkeyLabel
	hotkey_label = Label.new()
	hotkey_label.name = "HotkeyLabel"
	hotkey_label.position = Vector2(-5, -5)
	hotkey_label.size = Vector2(50, 20)
	
	# 设置样式
	var font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	hotkey_label.add_theme_font_override("font", font)
	hotkey_label.add_theme_color_override("font_color", Color(1, 1, 0.7, 1))
	hotkey_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hotkey_label.add_theme_constant_override("outline_size", 3)
	hotkey_label.add_theme_font_size_override("font_size", 28)
	
	add_child(hotkey_label)
	hotkey_label.show()
	
	# 连接主动技能管理器信号（因为脚本是动态替换的，_ready不会被调用）
	if Global.ActiveSkillManager:
		if not Global.ActiveSkillManager.skill_cooldown_started.is_connected(_on_skill_cooldown_started):
			Global.ActiveSkillManager.skill_cooldown_started.connect(_on_skill_cooldown_started)
		if not Global.ActiveSkillManager.skill_cooldown_finished.is_connected(_on_skill_cooldown_finished):
			Global.ActiveSkillManager.skill_cooldown_finished.connect(_on_skill_cooldown_finished)

func setup_active_skill(slot: String, hotkey_text: String) -> void:
	"""初始化主动技能图标"""
	slot_key = slot
	
	# 设置快捷键显示
	if hotkey_label:
		hotkey_label.text = hotkey_text
		hotkey_label.show()
	
	# 从Global获取该槽位绑定的技能
	var skill_config = Global.player_now_active_skill.get(slot, {})
	skill_name = skill_config.get("name", "")
	
	if skill_name == "":
		visible = false
		return
	
	visible = true
	
	# 加载技能图标
	var icon_path = _get_skill_icon_path(skill_name)
	if icon_path != "":
		var icon_texture = load(icon_path)
		if icon_texture:
			texture_normal = icon_texture
			if cooldown_progress:
				cooldown_progress.texture_progress = icon_texture
	
	# 获取技能冷却时间
	cooldown_time = _get_skill_cooldown(skill_name)
	
	# 重置冷却状态
	is_on_cooldown = false
	current_cooldown = 0.0
	if cooldown_label:
		cooldown_label.hide()
	if cooldown_progress:
		cooldown_progress.value = 0

func _get_skill_icon_path(skill_id: String) -> String:
	"""根据技能ID获取图标路径"""
	match skill_id:
		"dodge":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/dodge.png"
		"random_strike":
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/random_strike.png"
		_:
			return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png"

func _get_skill_cooldown(skill_id: String) -> float:
	"""根据技能ID和等级计算冷却时间"""
	var skill_data = Global.player_active_skill_data.get(skill_id, {})
	var level = skill_data.get("level", 1)
	
	match skill_id:
		"dodge":
			# 闪避：基础冷却6秒，等级3，5，7，9，11，13，15时冷却-0.5秒
			var base_cd = 6.0
			var cd_reduction = 0.0
			for lv in [3, 5, 7, 9, 11, 13, 15]:
				if level >= lv:
					cd_reduction += 0.5
			return max(1.0, base_cd - cd_reduction)
		"random_strike":
			# 乱击：基础冷却20秒，等级4，7，10，13时冷却-1秒
			var base_cd = 20.0
			var cd_reduction = 0.0
			for lv in [4, 7, 10, 13]:
				if level >= lv:
					cd_reduction += 1.0
			return max(5.0, base_cd - cd_reduction)
		_:
			return 10.0

func _process(delta: float) -> void:
	# 检查游戏是否暂停
	if get_tree().paused or is_paused:
		return
		
	if is_on_cooldown:
		current_cooldown -= delta
		if current_cooldown <= 0:
			current_cooldown = 0
			is_on_cooldown = false
			if cooldown_label:
				cooldown_label.hide()
			if cooldown_progress:
				cooldown_progress.value = 0
		else:
			if cooldown_label:
				cooldown_label.text = "%.1f" % current_cooldown
			if cooldown_time > 0 and cooldown_progress:
				cooldown_progress.value = int((current_cooldown / cooldown_time) * 100)

func start_cooldown(cd_time: float = -1.0) -> void:
	"""开始冷却（主动调用或由技能使用触发）"""
	if cd_time > 0:
		cooldown_time = cd_time
	
	current_cooldown = cooldown_time
	is_on_cooldown = true
	if cooldown_label:
		cooldown_label.show()
		cooldown_label.text = "%.1f" % current_cooldown
	if cooldown_progress:
		cooldown_progress.value = 100

func _on_skill_cooldown_started(skill_id: String, cd_time: float) -> void:
	"""当技能进入冷却时（由ActiveSkillManager触发）"""
	if skill_id == skill_name:
		start_cooldown(cd_time)

func _on_skill_cooldown_finished(skill_id: String) -> void:
	"""当技能冷却完成时"""
	if skill_id == skill_name:
		is_on_cooldown = false
		current_cooldown = 0.0
		if cooldown_label:
			cooldown_label.hide()
		if cooldown_progress:
			cooldown_progress.value = 0

func is_skill_ready() -> bool:
	"""检查技能是否可用"""
	return not is_on_cooldown and skill_name != ""

func set_game_paused(pause: bool) -> void:
	"""暂停/恢复冷却"""
	is_paused = pause

func refresh_skill_config() -> void:
	"""刷新技能配置（当技能绑定变化时调用）"""
	setup_active_skill(slot_key, hotkey_label.text if hotkey_label else "")
