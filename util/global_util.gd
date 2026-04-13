extends Node

var kill_count: int = 0

func _ready() -> void:
	Global.monster_killed.connect(_on_monster_killed)

func reset_kill_count() -> void:
	kill_count = 0

func add_kill_count(amount: int) -> void:
	kill_count += amount

func get_kill_count() -> int:
	return kill_count

func _on_monster_killed() -> void:
	add_kill_count(1)

func parse_rect_from_func_string(rect_str: String) -> Rect2:
	var clean = rect_str.replace("Rect2(", "").replace(")", "")
	var parts = clean.split(",")
	if parts.size() == 4:
		return Rect2(
			float(parts[0]), float(parts[1]),
			float(parts[2]), float(parts[3])
		)
	return Rect2(0, 0, 0, 0)
