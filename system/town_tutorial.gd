extends CanvasLayer

@export var tutorial_title: RichTextLabel
@export var tutorial_sprite: Sprite2D
@export var tutorial_detail: RichTextLabel
@export var tutorial_next_page_button: Button
@export var tutorial_prev_page_button: Button

var current_page: int = 0
var pages: Array = [
	{
		"title": "教程：城镇指南（1 / 4）：乾长老（侠士切换）",
		"image": "res://AssetBundle/Sprites/image/town_qian.png",
		"detail": "在乾长老处可以按键盘F键进行侠士的切换。\n目前仅有墨宁和言秋两位侠士可供选择，随着后续剧情发展，会有更多的侠士加入。\n每个侠士都有其专有的初始武器与只有他自己能用的特殊主动技能\n[color=gray]* 后续版本会加入独有的天赋系统，强化差异性[/color]"
	},
	{
		"title": "教程：城镇指南（2 / 4）：巽长老（修习）",
		"image": "res://AssetBundle/Sprites/image/town_xun.png",
		"detail": "在巽长老处可以进行修习来强化自身初始属性，以便更好的攻略幻境。\n修习需要消耗在幻境中获得的真气。\n[color=gray]* 若已获得首领掉落的魔核，可以在接下来的剧情中开放的功能里使用[/color]"
	},
	{
		"title": "教程：城镇指南（3 / 4）：功能栏",
		"image": "res://AssetBundle/Sprites/image/town_setting.png",
		"detail": "右上角有三个按钮，分别是：技能配置，角色行囊，系统设置\n技能配置中可以修改[color=yellow]当前侠士[/color]携带的主动技能\n角色行囊中可以查看角色当前基本信息与行囊中的物品材料，丹药需要在行囊中使用。\n系统设置可以修改与游戏相关的设置。"
	},
	{
		"title": "教程：城镇指南（4 / 4）：衍阵（选择关卡）",
		"image": "res://AssetBundle/Sprites/image/town_yanzhen.png",
		"detail": "通过衍阵可以快速传送到幻境中的指定位置。\n幻境深度（难度选择）：有浅层、深层、核心三个级别。\n难度越高，敌人的强度就越高，可以参考推荐修为进行攻略（推荐修为可以在角色行囊中看到）\n高难度下，首领技能会出现显著变化，并且首领伤害也会大幅提升！"
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

	# 下一页按钮逻辑：最后一页文字改为"明白！"
	if tutorial_next_page_button:
		if current_page == pages.size() - 1:
			tutorial_next_page_button.text = "明白！"
		else:
			tutorial_next_page_button.text = "下一页"

func _on_next_pressed():
	if current_page == pages.size() - 1:
		# 最后一页，点击后渐出并消失
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
	get_tree().paused = false
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
