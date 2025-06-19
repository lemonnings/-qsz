extends Area2D

# Signal emitted when the item is picked up
signal item_picked_up

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the area_entered signal to our handler function
	connect("area_entered", self, "_on_area_entered")

# Called when another Area2D enters this area
func _on_area_entered(area: Area2D) -> void:
	# Check if the entering area belongs to the 'player' group
	# Assuming the player's Area2D is in the 'player' group
	# and has a method or property to identify it as the player's pickup area.
	# For simplicity, we'll assume any Area2D in the 'player' group can pick up.
	if area.is_in_group("player"):
		print("Player picked up item: ", get_parent().name) # Assuming the item scene is the parent
		_pickup_item()

func _pickup_item() -> void:
	# Disable collision so it can't be picked up again
	monitoring = false
	monitorable = false

	# Create a new Tween node
	var tween = Tween.new()
	add_child(tween)

	# Make the item fade out
	# Assuming the item's visual representation is a child of this Area2D or the parent Node2D/Sprite
	# For this example, let's assume the parent of this Area2D is the item itself (e.g., a Sprite or Node2D)
	var item_node = get_parent()
	if item_node and item_node.has_method("set_modulate"):
		tween.interpolate_property(item_node, "modulate", item_node.modulate, Color(item_node.modulate.r, item_node.modulate.g, item_node.modulate.b, 0), 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	else:
		# Fallback if the parent doesn't have modulate (e.g. if this Area2D is the root of the item)
		if self.has_method("set_modulate"):
			tween.interpolate_property(self, "modulate", self.modulate, Color(self.modulate.r, self.modulate.g, self.modulate.b, 0), 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		else:
			# If no modulate property, try to hide all visible children
			for child in get_children():
				if child is CanvasItem and child != tween:
					tween.interpolate_property(child, "modulate", child.modulate, Color(child.modulate.r, child.modulate.g, child.modulate.b, 0), 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

	# Start the tween
	tween.start()

	# Wait for the tween to complete, then remove the item
	yield(tween, "tween_completed")

	emit_signal("item_picked_up")

	# Remove the tween node itself
	tween.queue_free()

	# Remove the item from the scene
	# If this script is on the root of the item scene:
	queue_free()
	# If this script is on a child Area2D of the item scene:
	# get_parent().queue_free()


# Note: For this script to work as intended:
# 1. This script should be attached to an Area2D node within your DroppedItemScene.
# 2. The Area2D should have a CollisionShape2D as a child to define its pickup area.
# 3. The player character's scene should also have an Area2D (e.g., a pickup radius) that is part of the "player" group.
# 4. The visual part of the item (e.g., a Sprite) should ideally be a parent or sibling that can be targeted by the tween for the modulate property.
#    If this Area2D is the root of the item scene and also contains the visuals, the tween will target 'self'.
# 1. 此脚本应附加到 DroppedItemScene 中的 Area2D 节点（即掉落物品场景的根节点）。
# 2. 该 Area2D 需要 包含一个 CollisionShape2D 子节点，用于定义拾取检测区域。
# 3. 玩家角色场景中应包含一个 Area2D（例如：拾取半径），并将其加入名为 "player" 的 节点组。
# 4. 物品的视觉表现部分（如 Sprite）应作为此 Area2D 的 父节点或兄弟节点 存在，以便通过 Tween 控制其 modulate（颜色调节）属性。
# 如果当前 Area2D 是物品场景的根节点且已包含视觉元素，则 Tween 将直接作用于 "self"（自身）。