@tool
extends Node3D

@onready var players_container: Node3D = $Players
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var spawn_point: Vector3 = Vector3(11.89, 1.02, 3.24)

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HOUSE_ENV_SCRIPT := preload("res://scripts/house_environment.gd")

var house_env: Node = null


func _ready() -> void:
	# Clean up any previous editor preview children if reopening/reloading
	for old_name in ["HouseEnvironment", "PerimeterBrickWall", "PathAndRoad", "TropicalFoliage", "GroundTerrain", "DecorationsRoot"]:
		var old_node := get_node_or_null(old_name)
		if old_node and is_instance_valid(old_node):
			old_node.queue_free()

	house_env = HOUSE_ENV_SCRIPT.new()
	add_child(house_env)
	house_env.build(self)

	# When running inside the Godot Editor 3D viewport, stop here (preview mode only)
	if Engine.is_editor_hint():
		return

	_apply_host_environment_settings()

	var net := get_node_or_null("/root/NetworkManager")
	var is_singleplayer_game: bool = (net == null) or net.is_singleplayer or (net.host_settings.get("max_players", 4) == 1 and net.players.size() <= 1 and not net.is_webrtc_mode)

	var is_offline: bool = (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		or (net == null) \
		or (net.get("peer") == null and net.get("webrtc_mp") == null) \
		or is_singleplayer_game

	# If running in single-player / test mode without active multiplayer session
	if is_offline:
		_spawn_player(1)
		return

	# Only the host/server spawns players; MultiplayerSpawner replicates them to all clients
	if multiplayer.is_server():
		if net:
			net.player_connected.connect(_on_player_connected)
			net.player_disconnected.connect(_on_player_disconnected)
			
			# Ensure host itself is always spawned
			if not net.players.has(1):
				_spawn_player(1)

			for peer_id in net.players:
				_spawn_player(peer_id)
		else:
			_spawn_player(1)


func _apply_host_environment_settings() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	var atmosphere: String = "Midnight"
	if net:
		atmosphere = net.host_settings.get("atmosphere", "Midnight")
	
	if not world_env or not world_env.environment:
		return
	
	# Duplicate environment instance so edits don't contaminate disk cache
	world_env.environment = world_env.environment.duplicate()
	var env := world_env.environment
	
	if atmosphere == "Midnight":
		# 1. Extinguish sun completely
		if sun_light:
			sun_light.visible = false
			sun_light.light_energy = 0.0
		
		# 2. Complete pitch black background (no glowing sky)
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.0, 0.0, 0.0, 1.0)
		env.background_energy_multiplier = 0.0
		
		# 3. Disable all ambient bounce lighting
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.0, 0.0, 0.0, 1.0)
		env.ambient_light_energy = 0.0
		
		# 4. Disable sky reflections & glowing aura
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.glow_enabled = false
		print("World: Midnight atmosphere applied — PITCH BLACK mode active.")
	else:
		# Dim twilight dusk
		if sun_light:
			sun_light.visible = true
			sun_light.light_energy = 0.25
			sun_light.light_color = Color(0.9, 0.55, 0.35)
		
		env.background_mode = Environment.BG_SKY
		env.background_energy_multiplier = 0.3
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.12, 0.1, 0.15, 1.0)
		env.ambient_light_energy = 0.15
		print("World: Dusk atmosphere applied.")


func _on_player_connected(peer_id: int, _info: Dictionary) -> void:
	_spawn_player(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	var player_node := players_container.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()


func _spawn_player(peer_id: int) -> void:
	if players_container.has_node(str(peer_id)):
		return
	
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	
	var net := get_node_or_null("/root/NetworkManager")
	var role_to_assign: String = "normal"
	var char_to_assign: String = "Syazril"
	if net and net.players.has(peer_id):
		player.player_name = str(net.players[peer_id].get("name", "Player %d" % peer_id))
		role_to_assign = str(net.players[peer_id].get("role", "normal"))
		char_to_assign = str(net.players[peer_id].get("character", "Syazril"))
	else:
		player.player_name = "Player %d" % peer_id
	
	if role_to_assign.is_empty() or role_to_assign == "random":
		if net:
			var mode: String = str(net.host_settings.get("flashlight_mode", "normal"))
			if mode in ["crank", "battery", "lantern", "uv", "normal", "disabled"]:
				role_to_assign = mode
			else:
				role_to_assign = "battery"
		else:
			role_to_assign = "normal"

	if char_to_assign.is_empty() or char_to_assign == "random":
		char_to_assign = "Syazril"

	player.flashlight_mode = role_to_assign
	player.character_name = char_to_assign
	player.set_meta("character_name", char_to_assign)
	
	var offset := Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
	player.position = spawn_point + offset
	
	players_container.add_child(player, true)
	print("World: Spawned '%s' (Authority ID: %d, Character: %s, Role: %s)" % [player.player_name, peer_id, char_to_assign, role_to_assign])
