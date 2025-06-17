extends Node

func parse_rect_from_func_string(str: String) -> Rect2:
	var clean = str.replace("Rect2(", "").replace(")", "")
	var parts = clean.split(",")
	if parts.size() == 4:
		return Rect2(
			float(parts[0]), float(parts[1]),
			float(parts[2]), float(parts[3])
		)
	return Rect2(0, 0, 0, 0)
