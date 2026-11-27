@tool
extends Node3D

var _preview_env: Node = null


func _ready() -> void:
	# If instanced inside main/world, let main.gd handle building
	if get_parent() and (get_parent().name == "world" or "Main" in get_parent().name):
		return

	# Standalone preview in Godot editor when viewing home.tscn directly
	if Engine.is_editor_hint():
		call_deferred("_setup_preview")


func _setup_preview() -> void:
	for old_name in ["HouseEnvironment", "DecorationsRoot", "PerimeterBrickWall", "PathAndRoad", "TropicalFoliage", "GroundTerrain"]:
		var old := get_node_or_null(old_name)
		if old and is_instance_valid(old):
			old.queue_free()

	_preview_env = preload("res://scripts/house_environment.gd").new()
	add_child(_preview_env)
	_preview_env.build(self)
