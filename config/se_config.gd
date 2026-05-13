class_name SEConfig

static var _data: Dictionary = {}
static var _loaded := false

static func load_data() -> void:
	if _loaded:
		return
	var file = FileAccess.open("res://Config/se.csv", FileAccess.READ)
	if file == null:
		printerr("无法打开 se.csv")
		return
	var headers: Array = []
	var first_line := true
	while not file.eof_reached():
		var csv_line = file.get_csv_line()
		if csv_line.is_empty() or (csv_line.size() == 1 and csv_line[0].is_empty()):
			continue
		if first_line:
			for h in csv_line:
				headers.append(h.strip_edges())
			first_line = false
		else:
			var entry := {}
			for i in range(min(headers.size(), csv_line.size())):
				entry[headers[i]] = csv_line[i].strip_edges()
			var id = entry.get("id", "")
			if id != "":
				_data[id] = entry
	file.close()
	_loaded = true

static func get_entry(id: String) -> Dictionary:
	if not _loaded:
		load_data()
	return _data.get(id, {})

static func get_pitch_range(id: String) -> Array:
	var entry = get_entry(id)
	var raw = entry.get("random_pitch_range", "")
	if raw == "":
		return []
	var parts = raw.split(",")
	if parts.size() != 2:
		return []
	return [parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float()]

static func has_entry(id: String) -> bool:
	if not _loaded:
		load_data()
	return _data.has(id)
