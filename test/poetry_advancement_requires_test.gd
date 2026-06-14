extends SceneTree

const WEAP_DATA_EXPORT = preload("res://Script/town/weap_data_export.gd")


func _init() -> void:
	var expected_requires := _parse_expected_requires()
	var errors: Array[String] = []
	
	for faction in WEAP_DATA_EXPORT.ADVANCEMENTS:
		for advancement in WEAP_DATA_EXPORT.ADVANCEMENTS[faction]:
			var precondition := str(advancement.get("precondition", ""))
			if precondition == "":
				continue
			if not expected_requires.has(precondition):
				errors.append("%s uses missing precondition %s" % [advancement.get("id", ""), precondition])
				continue
			
			var expected: Array = expected_requires[precondition]
			var actual: Array = advancement.get("requires", [])
			if not _same_members(actual, expected):
				errors.append("%s requires %s, expected %s from %s" % [
					advancement.get("id", ""),
					str(actual),
					str(expected),
					precondition,
				])
	
	if errors.is_empty():
		print("poetry_advancement_requires_test passed")
		quit(0)
		return
	
	for error in errors:
		push_error(error)
	quit(1)


func _parse_expected_requires() -> Dictionary:
	var file := FileAccess.open("res://Script/config/setting_level_up.gd", FileAccess.READ)
	if file == null:
		push_error("failed to open setting_level_up.gd")
		return {}
	
	var expected := {}
	var current_func := ""
	for raw_line in file.get_as_text().split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with("func check_") and line.find("() -> bool:") >= 0:
			var start := "func ".length()
			var end := line.find("()")
			current_func = line.substr(start, end - start)
			continue
		
		if current_func == "":
			continue
		
		if line.begins_with("return "):
			expected[current_func] = _extract_selected_reward_ids(line)
			current_func = ""
		elif line.begins_with("func "):
			current_func = ""
	
	return expected


func _extract_selected_reward_ids(line: String) -> Array:
	var ids: Array[String] = []
	var regex := RegEx.new()
	regex.compile("selected_rewards\\.has\\(\"([^\"]+)\"\\)")
	for result in regex.search_all(line):
		ids.append(result.get_string(1))
	return ids


func _same_members(actual: Array, expected: Array) -> bool:
	var actual_sorted := actual.duplicate()
	var expected_sorted := expected.duplicate()
	actual_sorted.sort()
	expected_sorted.sort()
	return actual_sorted == expected_sorted
