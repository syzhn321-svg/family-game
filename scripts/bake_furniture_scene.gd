@tool
extends SceneTree

const HOUSE_DECORATIONS_SCRIPT := preload("res://scripts/house_decorations.gd")

func _init() -> void:
	print("--- Baking house_furniture.tscn ---")
	var root := Node3D.new()
	root.name = "HouseFurniture"

	var dec = HOUSE_DECORATIONS_SCRIPT.new()
	dec.build(root, null)

	var dec_root = root.get_node_or_null("DecorationsRoot")
	if not dec_root:
		print("ERROR: DecorationsRoot not found!")
		quit(1)
		return

	# Move all room children directly under root
	var children = dec_root.get_children()
	for child in children:
		dec_root.remove_child(child)
		root.add_child(child)
	dec_root.free()

	# Assign owner = root recursively to every node in tree
	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		print("ERROR: pack failed with code:", err)
		quit(1)
		return

	err = ResourceSaver.save(packed, "res://scenes/house_furniture.tscn")
	if err != OK:
		print("ERROR: ResourceSaver.save failed with code:", err)
		quit(1)
		return

	print("SUCCESS: res://scenes/house_furniture.tscn baked cleanly!")
	root.free()
	quit(0)

func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	if node != owner_root:
		node.owner = owner_root
	for child in node.get_children():
		_set_owner_recursive(child, owner_root)
