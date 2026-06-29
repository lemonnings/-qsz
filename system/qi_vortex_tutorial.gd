extends CanvasLayer

@export var tutorial_title: RichTextLabel
@export var tutorial_sprite: Sprite2D
@export var tutorial_detail: RichTextLabel
@export var tutorial_next_page_button: Button
@export var tutorial_prev_page_button: Button

const JINGPO_ICON := "res://AssetBundle/Sprites/Sprite sheets/jingpo.png"

var current_page: int = 0
var _was_tree_paused: bool = false
var _paused_battle_timers: bool = false
var pages: Array = [
	{
		"title": "教程：灵气漩涡（1 / 3）",
		"image": "res://AssetBundle/Sprites/image/lingqi_1.png",
		"detail": "在关卡中，会不定期地出现灵气漩涡\n站在上面3秒后即可进入灵气漩涡中，消耗精魄开启特别的领悟。"
	},
	{
		"title": "教程：灵气漩涡（2 / 3）",
		"image": "res://AssetBundle/Sprites/image/lingqi_2.png",
		"detail": "灵气漩涡可能出现在当前视野之外，可以通过屏幕边缘的指示箭头前往。"
	},
	{
		"title": "教程：灵气漩涡（3 / 3）",
		"image": "res://AssetBundle/Sprites/image/lingqi_3.png",
		"detail": "使用精魄[img=32x32]%s[/img]可以开启领悟选择，随着开启次数增加，消耗精魄也会增加。\n每个灵气漩涡前两次领悟为二选一，第三次之后为三选一。" % JINGPO_ICON
	}
]

func _ready() -> void:
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

	_was_tree_paused = get_tree().paused
	_set_battle_timers_paused(true)
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

func update_page() -> void:
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

func _update_buttons() -> void:
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

func _on_next_pressed() -> void:
	if current_page == pages.size() - 1:
		var tween = create_tween()
		for child in get_children():
			if child is CanvasItem:
				tween.parallel().tween_property(child, "modulate:a", 0.0, 0.3)
		tween.tween_callback(_on_tutorial_finish)
	else:
		current_page += 1
		update_page()

func _on_prev_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		update_page()

func _on_tutorial_finish() -> void:
	if _paused_battle_timers and not _was_tree_paused:
		_set_battle_timers_paused(false)
	get_tree().paused = _was_tree_paused
	queue_free()

func _fade_node(node: CanvasItem, target_alpha: float, duration: float, make_visible: bool) -> void:
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
