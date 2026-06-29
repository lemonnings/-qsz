extends CanvasLayer

@export var tutorial_title: RichTextLabel
@export var tutorial_sprite: Sprite2D
@export var tutorial_detail: RichTextLabel
@export var tutorial_next_page_button: Button
@export var tutorial_prev_page_button: Button

var current_page: int = 0
var _was_tree_paused: bool = false
var _paused_battle_timers: bool = false
var pages: Array = [
	{
		"title": "教程：战斗基础（1 / 6）：基础操作方式",
		"image": "res://AssetBundle/Sprites/image/battle_base.png",
		"detail": "键鼠操作，键盘W为向上移动，S为向下移动，A为向左移动，D为向右移动。\n主动技能默认按键为Space（空格键），Q，E\nEsc键暂停游戏"
	},
	{
		"title": "教程：战斗基础（2 / 6）：武器栏与技能栏",
		"image": "res://AssetBundle/Sprites/image/study_weapon_and_active.png",
		"detail": "右侧武器栏：显示持有武器及攻击时间，多把武器冷却并行计算。\n下方技能栏：当前携带的主动技能，快捷键为空格（Space），Q，E，可在城镇中自由配置携带技能、分配键位。"
	},
	{
		"title": "教程 - 战斗基础（3 / 6）：资源栏",
		"image": "res://AssetBundle/Sprites/image/study_exp_and_mech.png",
		"detail": "最下面的经验条：在满值后会升级，提升攻击力与最大体力，并进行一次领悟选择。\n领悟从低到高分为四种级别：通明(蓝)、悟道(紫)、臻境(金)、逆天(红)\n右下为探索进度，到达满值后出现首领，战胜后即可通关。\n右上为已获取的真气、精魄。真气可在城镇中进行修炼，精魄可在灵气漩涡中进行领悟。"
	},
	{
		"title": "教程 - 战斗基础（4 / 6）：法则栏",
		"image": "res://AssetBundle/Sprites/image/study_faze.png",
		"detail": "法则是局内成长最重要的一环！\n在领悟选择中，有的领悟项会提供法则层数加成。\n法则一旦达到指定的层数，便会获得对应法则之力的强大加成。\n近20种法则各具特色，向着最高层法则努力吧！"
	},
	{
		"title": "教程 - 战斗基础（5 / 6）：纹章栏",
		"image": "res://AssetBundle/Sprites/image/study_wenzhang.png",
		"detail": "纹章可以给角色带来当局内永久存在的各种特殊能力或者动态变化的属性加成。\n战局越到后期，纹章带来的增益效果就越明显。"
	},
	{
		"title": "教程 - 战斗基础（6 / 6）：状态栏",
		"image": "res://AssetBundle/Sprites/image/study_buff.png",
		"detail": "显示角色当前的状态，异常状态会以红色描边显示。\n部分首领的技能也会给角色附加各种状态，鼠标放到图标上面可以显示状态详情。"
	}
]

func _ready():
	# 确保教程在游戏暂停时仍能处理输入和动画
	process_mode = Node.PROCESS_MODE_ALWAYS

	for child in get_children():
		if child is CanvasItem:
			child.modulate.a = 0.0

	# 如果此时正在场景切换，耐心等待黑幕退去
	var scene_change = get_node_or_null("/root/SceneChange")
	if scene_change and scene_change.visible:
		if scene_change.get("animation") and scene_change.animation.is_playing():
			await scene_change.animation.animation_finished
		else:
			await get_tree().create_timer(0.5).timeout

	# 暂停游戏
	_was_tree_paused = get_tree().paused
	_set_battle_timers_paused(true)
	get_tree().paused = true

	if tutorial_next_page_button:
		tutorial_next_page_button.pressed.connect(_on_next_pressed)
	if tutorial_prev_page_button:
		tutorial_prev_page_button.pressed.connect(_on_prev_pressed)
		
	update_page()
	
	# 界面渐入效果 (0.3秒)
	var tween = create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate:a", 1.0, 0.3)

func update_page():
	if pages.is_empty():
		return
		
	current_page = clampi(current_page, 0, pages.size() - 1)
	var page_data = pages[current_page]
	
	if tutorial_title:
		tutorial_title.text = "" + page_data["title"] + ""
		
	if tutorial_detail:
		tutorial_detail.text = page_data["detail"]
		
	if tutorial_sprite:
		var img_path = page_data["image"]
		if ResourceLoader.exists(img_path):
			tutorial_sprite.texture = load(img_path)
		else:
			tutorial_sprite.texture = null
			
	_update_buttons()

func _update_buttons():
	# 上一页按钮逻辑：第一页不显示，并附带渐入渐出效果
	if current_page == 0:
		if tutorial_prev_page_button and tutorial_prev_page_button.visible:
			_fade_node(tutorial_prev_page_button, 0.0, 0.3, false)
	else:
		if tutorial_prev_page_button and (not tutorial_prev_page_button.visible or tutorial_prev_page_button.modulate.a < 1.0):
			_fade_node(tutorial_prev_page_button, 1.0, 0.3, true)
			
	# 下一页按钮逻辑：最后一页文字改为“明白！”
	if tutorial_next_page_button:
		if current_page == pages.size() - 1:
			tutorial_next_page_button.text = "明白！"
		else:
			tutorial_next_page_button.text = "下一页"

func _on_next_pressed():
	if current_page == pages.size() - 1:
		# 最后一页，点击后渐出并消失1把+12,3把+3，5蓝3紫2金
		var tween = create_tween()
		for child in get_children():
			if child is CanvasItem:
				tween.parallel().tween_property(child, "modulate:a", 0.0, 0.3)
		tween.tween_callback(_on_tutorial_finish)
	else:
		current_page += 1
		update_page()

func _on_prev_pressed():
	if current_page > 0:
		current_page -= 1
		update_page()

func _on_tutorial_finish():
	if _paused_battle_timers and not _was_tree_paused:
		_set_battle_timers_paused(false)
	get_tree().paused = _was_tree_paused
	queue_free()

# 辅助函数：处理节点的渐入渐出
func _fade_node(node: CanvasItem, target_alpha: float, duration: float, make_visible: bool):
	if make_visible and not node.visible:
		node.visible = true
		node.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", target_alpha, duration)
	
	if not make_visible:
		tween.tween_callback(func(): node.visible = false)

func _set_battle_timers_paused(pause: bool) -> void:
	_paused_battle_timers = pause
	if PC.player_instance and is_instance_valid(PC.player_instance) and PC.player_instance.has_method("pause_all_skill_cooldowns"):
		PC.player_instance.pause_all_skill_cooldowns(pause)
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		return
	var skill_nodes := root.find_children("", "TextureButton", true, false)
	for child in skill_nodes:
		if child.has_method("set_game_paused"):
			child.set_game_paused(pause)
