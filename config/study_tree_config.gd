class_name StudyTreeConfig

static var _data: Dictionary = {}
static var _loaded := false

static func load_data() -> void:
	if _loaded:
		return
	var file = FileAccess.open("res://Config/study_tree.csv", FileAccess.READ)
	if file == null:
		printerr("无法打开 study_tree.csv")
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
