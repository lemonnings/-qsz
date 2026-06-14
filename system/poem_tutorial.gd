extends CanvasLayer

@export var tutorial_title: RichTextLabel
@export var tutorial_sprite: Sprite2D
@export var tutorial_detail: RichTextLabel
@export var tutorial_next_page_button: Button
@export var tutorial_prev_page_button: Button

var current_page: int = 0
var pages: Array = [
	{
		"title": "教程：诗想难度（1 / 2）",
		"image": "res://AssetBundle/Sprites/image/town_poem.png",
		"detail": "在击破关卡的核心难度后，就可以挑战诗想难度了！\n在这个难度下，需要提前做好备战，备战完成后进入关卡可以直接挑战首领。\n该难度下的首领体力会随着角色成长而获得小幅度的修正，并且技能方面会添加更多机制，会比普通难度更复杂，更具威胁。\n[color=yellow]该难度并不是强制需要攻略的，请随心所欲的选择是否挑战吧！[/color]"
	},
	{
		"title": "教程：诗想难度（2 / 2）",
		"image": "res://AssetBundle/Sprites/image/town_poem2.png",
		"detail": "备战的四把武器与进阶项均选择完毕后，会在界面上方产生一个备战码。\n你可以将当前的构筑组合其存储下来，在下次想要使用的时候直接在输入框内粘贴套用即可。\n当然，也可以从别人那里获取到备战码后，套用他人的构筑思路。\n[color=gray]* 如果备战码中包含当前未解锁的武器，将无法套用方案[/color]"
	}
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	for child in get_children():
		if child is CanvasItem:
			child.modulate.a = 0.0

	var scene_change = get_node_or_null("/root/SceneChange")
	if scene_change and scene_change.visible:
		if scene_change.get("animation") and scene_change.animation.is_playing():
			await scene_change.animation.animation_finished
		else:
			await get_tree().create_timer(0.5).timeout

	get_tree().paused = true

	if tutorial_next_page_button:
		tutorial_next_page_button.pressed.connect(_on_next_pressed)
	if tutorial_prev_page_button:
		tutorial_prev_page_button.pressed.connect(_on_prev_pressed)

	update_page()

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
		tutorial_title.text = page_data["title"]

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
	if current_page == 0:
		if tutorial_prev_page_button and tutorial_prev_page_button.visible:
			_fade_node(tutorial_prev_page_button, 0.0, 0.3, false)
	else:
		if tutorial_prev_page_button and (not tutorial_prev_page_button.visible or tutorial_prev_page_button.modulate.a < 1.0):
			_fade_node(tutorial_prev_page_button, 1.0, 0.3, true)

	if tutorial_next_page_button:
		if current_page == pages.size() - 1:
			tutorial_next_page_button.text = "明白！"
		else:
			tutorial_next_page_button.text = "下一页"

func _on_next_pressed():
	if current_page == pages.size() - 1:
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

func _fade_node(node: CanvasItem, target_alpha: float, duration: float, make_visible: bool):
	if make_visible and not node.visible:
		node.visible = true
		node.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(node, "modulate:a", target_alpha, duration)

	if not make_visible:
		tween.tween_callback(func(): node.visible = false)
