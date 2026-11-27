class_name StoryDrive
extends Node3D

signal drive_checkpoint_reached(checkpoint_id: int)

# --- Highway & Route Configuration ---
const HIGHWAY_LENGTH: float = 2550.0
const LANE_WIDTH: float = 4.2
const LAMP_INTERVAL: float = 55.0

# Checkpoint Z Milestones (Referenced to Real-World Route: Masjid Mukim Kuala Semerak -> Kandiez Sunrise Beach Resort)
const CP_KUALA_SEMERAK_Z: float = -720.0    # 30s timer ends -> Starts onroad at Masjid Mukim Kuala Semerak
const CP_BRIDGE_CREST_Z: float = -1100.0     # Jambatan Tok Bali bridge peak over Terusan Semerak & Harbour
const CP_JUNCTION_1_Z: float = -1600.0       # Junction 1: Persimpangan Tok Bali (Take Right to Laluan 189 Telong/Kandis)
const CP_JUNCTION_2_Z: float = -1950.0       # Junction 2: Simpang Pantai Kandis (Take Right to Kg Tok Kederat)
const CP_RESORT_ARRIVAL_Z: float = -2330.0   # Final Destination: Kandiez Sunrise Beach Resort

# --- Cutscene Timing ---
const CUTSCENE_DURATION: float = 8.5
var elapsed_time: float = 0.0
var is_cutscene_active: bool = true
var skip_hold_time: float = 0.0

# --- Phase & Timer System ---
var highway_timer: float = 30.0           # Active countdown timer during Phase 1
var is_timer_active: bool = false
var current_checkpoint_idx: int = 0
var has_reached_home: bool = false
var arrived_car_names: Dictionary = {}
var waiting_card: PanelContainer = null

# --- Sibling Cars ---
const STORY_CAR_SCRIPT := preload("res://scripts/story_car.gd")
var cars: Array[CharacterBody3D] = []
var player_car: CharacterBody3D = null
var car_container: Node3D = null

# --- Oncoming NPC Traffic System (Sparse, Malaysian Right Lane +2.1m) ---
var traffic_container: Node3D = null
var oncoming_spawn_timer: float = 0.0
var same_lane_spawn_timer: float = 0.0
var oncoming_sync_timer: float = 0.0
var next_oncoming_interval: float = 12.0 # First NPC appears ~12s into driving
var next_same_lane_interval: float = 16.0
var active_oncoming_cars: Array[Node3D] = []
var active_same_lane_cars: Array[Node3D] = []
var exploded_npc_names: Dictionary = {}
var next_traffic_id: int = 100

# --- Camera & Visual Nodes ---
@onready var camera: Camera3D = $CutsceneCamera
var world_env: WorldEnvironment = null
var highway_root: Node3D = null
var trees_root: Node3D = null
var lamps_root: Node3D = null

# --- HUD & Cinematic Canvas ---
var drive_canvas: CanvasLayer = null
var top_bar: ColorRect = null
var bottom_bar: ColorRect = null
var subtitle_label: Label = null
var time_stamp_label: Label = null
var tutorial_card: PanelContainer = null
var tutorial_label: Label = null
var speedo_label: Label = null
var speedo_container: PanelContainer = null
var boost_button: Button = null
var timer_container: PanelContainer = null
var timer_label: Label = null
var skip_label: Label = null
var skip_bar: ProgressBar = null
var checkpoint_card: PanelContainer = null
var mobile_controls_box: Control = null

# --- Crash Camera Reaction ---
var crash_cam_shake_timer: float = 0.0


func _ready() -> void:
	_setup_environment()
	_setup_highway()
	_setup_streetlights()
	_setup_environment_decorations()
	_setup_cars()
	_setup_traffic()
	_setup_hud()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	elapsed_time += delta

	if is_cutscene_active:
		_process_cutscene(delta)

	_update_hud(delta)


func _physics_process(delta: float) -> void:
	if not is_cutscene_active:
		_process_gameplay_driving(delta)
		_process_oncoming_traffic(delta)


# --- Cars & Networking Mode Helper ---
func _get_speaker(preferred: String, fallback_idx: int = 0) -> String:
	var active_chars: Array[String] = []
	for c in cars:
		if is_instance_valid(c):
			var c_name: String = str(c.get("character_name"))
			if not c_name.is_empty() and c_name != "random" and not (c_name in active_chars):
				active_chars.append(c_name)
	if active_chars.is_empty():
		return preferred
	if preferred in active_chars:
		return preferred
	return active_chars[fallback_idx % active_chars.size()]


func _is_solo_mode() -> bool:
	var net := get_node_or_null("/root/NetworkManager")
	if net == null:
		return true
	if bool(net.get("is_singleplayer")):
		return true
	var players_dict = net.get("players")
	if players_dict is Dictionary and (players_dict as Dictionary).size() > 1:
		return false
	return true


# --- Cutscene & Camera Choreography ---
func _process_cutscene(delta: float) -> void:
	var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
	var is_skipping := Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept")
	if is_mobile and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_skipping = true

	if is_skipping:
		skip_hold_time += delta
		if skip_bar:
			skip_bar.visible = true
			skip_bar.value = (skip_hold_time / 0.75) * 100.0
		if skip_hold_time >= 0.75:
			if multiplayer.has_multiplayer_peer() and not _is_solo_mode():
				rpc_sync_transition_to_driving.rpc()
			else:
				_transition_to_driving()
			return
	else:
		skip_hold_time = maxf(0.0, skip_hold_time - delta * 2.0)
		if skip_bar:
			skip_bar.value = (skip_hold_time / 0.75) * 100.0
			if skip_hold_time <= 0.05:
				skip_bar.visible = false

	# Cutscene Car Speeds (Realistic night convoy ~18-20 m/s)
	for i in range(cars.size()):
		var car: CharacterBody3D = cars[i]
		if is_instance_valid(car):
			var cutscene_speed := 18.0 + sin(elapsed_time * 1.5 + i * 1.8) * 2.8
			car.set("current_speed", cutscene_speed)
			car.position.z -= cutscene_speed * delta

			# Malaysian Left-Hand Traffic: All convoy cars travel in the left lane (-2.1m)
			var lane_target := -2.1 + (0.12 if (i % 2 == 1) else -0.12)
			var road_cx := _get_road_center_x(car.position.z)
			car.position.x = lerpf(car.position.x, road_cx + lane_target + sin(elapsed_time * 2.0 + i) * 0.25, delta * 1.8)
			car.position.y = _get_road_elevation(car.position.z) + 0.04

			car.call("_update_wheel_and_chassis_animations", delta)

	# Cinematic Camera Shots
	var lead_z: float = cars[0].position.z if not cars.is_empty() else 0.0
	var net := get_node_or_null("/root/NetworkManager")
	var is_solo: bool = _is_solo_mode()

	# Shot 1 (0.0s - 3.2s): Low-Angle Roadside Pass on Left Verge
	if elapsed_time < 3.2:
		var cam_pos := Vector3(-4.6, 0.85, -45.0)
		camera.position = cam_pos
		var target_look := Vector3(-2.1, 0.85, lead_z)
		if camera.position.distance_to(target_look) > 0.5:
			camera.look_at(target_look, Vector3.UP)
		if subtitle_label:
			if is_solo:
				subtitle_label.text = "Laluan 189 • 11:42 PM. Driving alone through the coastal mist after a long journey..."
			else:
				subtitle_label.text = "Laluan 189 • 11:42 PM. Heading back to Pantai Kandis together."

	# Shot 2 (3.2s - 6.0s): High-Speed Chase Follow Cam (Left Lane Convoy)
	elif elapsed_time < 6.0:
		var last_z: float = cars.back().position.z if not cars.is_empty() else lead_z
		var cam_pos := Vector3(-1.8, 3.2, last_z + 13.5)
		camera.position = cam_pos
		var look_target := Vector3(-2.1, 1.15, lead_z - 12.0)
		if camera.position.distance_to(look_target) > 0.5:
			camera.look_at(look_target, Vector3.UP)
		if subtitle_label:
			if is_solo:
				subtitle_label.text = "The highway stretches into the dark. Only the low hum of the engine and the radio static."
			else:
				subtitle_label.text = "%s: 'Don't drive too fast, it's already late. Just follow behind.'" % _get_speaker("Aleysa", 1)

	# Shot 3 (6.0s - 8.5s): Dynamic Front Angle under Roadlamps (Framing Driver at Right)
	elif elapsed_time < CUTSCENE_DURATION:
		var cam_pos := Vector3(-2.1, 1.35, lead_z - 12.0)
		camera.position = cam_pos
		var look_target := Vector3(-2.1, 0.95, lead_z + 2.5)
		if camera.position.distance_to(look_target) > 0.5:
			camera.look_at(look_target, Vector3.UP)
		if subtitle_label:
			if is_solo:
				subtitle_label.text = "Almost at Kuala Semerak. Time to take over the wheel."
			else:
				subtitle_label.text = "%s: 'Okay, almost at Kuala Semerak. Stay on the left lane.'" % _get_speaker("Syazril", 0)

	else:
		if multiplayer.has_multiplayer_peer() and not _is_solo_mode():
			if multiplayer.is_server():
				rpc_sync_transition_to_driving.rpc()
		else:
			_transition_to_driving()


@rpc("any_peer", "call_local", "reliable")
func rpc_sync_transition_to_driving() -> void:
	_transition_to_driving()


# --- Seamless Transition to Player Driving ---
func _transition_to_driving() -> void:
	if not is_cutscene_active:
		return
	is_cutscene_active = false
	is_timer_active = true
	highway_timer = 30.0

	# Hide cinematic bars & subtitles
	if top_bar: top_bar.visible = false
	if bottom_bar: bottom_bar.visible = false
	if subtitle_label: subtitle_label.visible = false
	if skip_label: skip_label.visible = false
	if skip_bar: skip_bar.visible = false

	# Show tutorial, speedometer, timer, and boost HUD
	if tutorial_card: tutorial_card.visible = true
	if speedo_container: speedo_container.visible = true
	if boost_button: boost_button.visible = true
	if timer_container: timer_container.visible = true
	if mobile_controls_box:
		var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
		mobile_controls_box.visible = is_mobile

	# Activate driving physics for all cars (gentle 8.0 m/s cruise start, ensure clean ground clearance)
	for car in cars:
		if is_instance_valid(car):
			var r_elev := _get_road_elevation(car.position.z)
			if car.position.y < r_elev + 0.04:
				car.position.y = r_elev + 0.04
			car.set("current_speed", 8.0)
			car.set("is_active_driving", true)

	# Fade tutorial prompt out after 6 seconds
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(tutorial_card, "modulate:a", 0.0, 1.2)


func _process_gameplay_driving(delta: float) -> void:
	if not player_car or not is_instance_valid(player_car):
		return

	# Smooth Third-Person Chase Camera behind player's car
	var car_pos: Vector3 = player_car.global_position
	var car_forward: Vector3 = -player_car.global_transform.basis.z.normalized()
	var car_up := Vector3.UP

	var desired_cam_pos: Vector3 = car_pos - (car_forward * 5.8) + (car_up * 2.3)
	camera.global_position = camera.global_position.lerp(desired_cam_pos, delta * 9.0)

	var look_target: Vector3 = car_pos + (car_forward * 12.0) + (car_up * 0.8)
	camera.look_at(look_target, Vector3.UP)

	# Dynamic speed FOV & High-Speed Boost Camera Shake
	var is_car_boosting: bool = bool(player_car.get("is_boosting"))
	var top_ref: float = float(player_car.get("boost_speed")) if is_car_boosting else float(player_car.get("max_speed"))
	var cur_speed: float = float(player_car.get("current_speed"))
	var speed_ratio := clampf(absf(cur_speed) / maxf(top_ref, 1.0), 0.0, 1.0)
	var target_fov := lerpf(68.0, 78.0, speed_ratio)
	if is_car_boosting:
		target_fov += 9.0
		# High-speed tactile vibration
		var shake := Vector3(randf_range(-0.02, 0.02), randf_range(-0.015, 0.015), 0.0)
		camera.global_position += shake

	# High-impact crash violent camera shake & barrier scrape micro-tremor
	if crash_cam_shake_timer > 0.0:
		var intensity := (crash_cam_shake_timer / 0.85)
		var c_shake := Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.25), 0.0) * intensity
		camera.global_position += c_shake
		crash_cam_shake_timer = maxf(0.0, crash_cam_shake_timer - delta)
	elif float(player_car.get("divider_scrape_intensity")) > 0.05:
		var s_int := float(player_car.get("divider_scrape_intensity")) * 0.055
		camera.global_position += Vector3(randf_range(-s_int, s_int), randf_range(-s_int * 0.7, s_int * 0.7), 0.0)

	camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)

	# Phase 1 Highway Timer countdown
	if is_timer_active:
		highway_timer -= delta
		if highway_timer <= 0.0:
			highway_timer = 0.0
			is_timer_active = false
			_trigger_kuala_semerak_transition()

	# Checkpoint & Milestone progression
	_check_milestones(car_pos.z)


func trigger_car_bump_camera_shake(intensity: float = 0.28) -> void:
	crash_cam_shake_timer = maxf(crash_cam_shake_timer, intensity)


# --- Oncoming NPC Traffic System (Sparse, Malaysian Right Lane +2.1m) ---
func _setup_traffic() -> void:
	traffic_container = Node3D.new()
	traffic_container.name = "OncomingTraffic"
	add_child(traffic_container)


func _process_oncoming_traffic(delta: float) -> void:
	if not player_car or not is_instance_valid(player_car) or has_reached_home:
		return

	# 1. Host authoritative spawn timer
	if (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server():
		oncoming_spawn_timer += delta
		if oncoming_spawn_timer >= next_oncoming_interval:
			oncoming_spawn_timer = 0.0
			next_oncoming_interval = randf_range(18.0, 28.0)

			# Only spawn if at most 1 active oncoming car exists
			if active_oncoming_cars.size() < 1:
				var lead_z: float = player_car.global_position.z
				for c in cars:
					if is_instance_valid(c):
						lead_z = minf(lead_z, c.global_position.z)
				var spawn_z := lead_z - 300.0
				# Only spawn before final resort arrival
				if spawn_z > CP_RESORT_ARRIVAL_Z + 60.0:
					var color_idx := randi() % 5
					var speed := randf_range(20.0, 23.5) # ~72 - 85 km/h
					var tid := next_traffic_id
					next_traffic_id += 1

					if multiplayer.has_multiplayer_peer() and not _is_solo_mode():
						rpc_spawn_oncoming_npc.rpc(tid, color_idx, speed, spawn_z)
					else:
						_spawn_oncoming_npc(tid, color_idx, speed, spawn_z)

		# 1b. Host authoritative same-lane slower NPC spawn timer (left lane -2.1m, driving forward -Z)
		same_lane_spawn_timer += delta
		if same_lane_spawn_timer >= next_same_lane_interval:
			same_lane_spawn_timer = 0.0
			next_same_lane_interval = randf_range(20.0, 30.0)
			if active_same_lane_cars.size() < 1:
				var lead_z_sl: float = player_car.global_position.z
				for c in cars:
					if is_instance_valid(c):
						lead_z_sl = minf(lead_z_sl, c.global_position.z)
				var spawn_z_sl := lead_z_sl - 180.0
				if spawn_z_sl > CP_RESORT_ARRIVAL_Z + 80.0:
					var color_idx_sl := randi() % 5
					var speed_sl := randf_range(12.0, 15.5) # ~43 - 56 km/h cruising ahead
					var tid_sl := next_traffic_id
					next_traffic_id += 1
					if multiplayer.has_multiplayer_peer() and not _is_solo_mode():
						rpc_spawn_same_lane_npc.rpc(tid_sl, color_idx_sl, speed_sl, spawn_z_sl)
					else:
						_spawn_same_lane_npc(tid_sl, color_idx_sl, speed_sl, spawn_z_sl)

	# 2. Update all active oncoming cars (move along +Z in opposing Malaysian right lane +2.1m)
	var rear_z: float = player_car.global_position.z
	for c in cars:
		if is_instance_valid(c):
			rear_z = maxf(rear_z, c.global_position.z)

	var to_remove: Array[Node3D] = []
	for npc in active_oncoming_cars:
		if not is_instance_valid(npc):
			to_remove.append(npc)
			continue

		var speed: float = float(npc.get_meta("speed", 21.0))
		npc.position.z += speed * delta

		var road_cx := _get_road_center_x(npc.position.z)
		var road_cy := _get_road_elevation(npc.position.z)
		# Opposing Malaysian lane (+2.1m from road center)
		npc.position.x = road_cx + 2.1
		npc.position.y = road_cy + 0.04

		# Heading & slope pitch aligned with highway (+Z direction)
		var next_cx := _get_road_center_x(npc.position.z + 8.0)
		var next_cy := _get_road_elevation(npc.position.z + 4.0)
		npc.rotation.y = atan2(next_cx - road_cx, 8.0)
		npc.rotation.x = atan2(road_cy - next_cy, 4.0)

		# Roll wheels along axle
		var wheel_spins = npc.get_meta("wheel_spins", [])
		var roll_step: float = (speed * delta) / 0.34
		for sp in wheel_spins:
			if is_instance_valid(sp):
				sp.rotation.x += roll_step

		# Frame-rate-independent swept collision detection against local player's authoritative car
		if player_car.has_method("is_local_authority") and player_car.call("is_local_authority"):
			if not exploded_npc_names.has(npc.name):
				var dx := absf(player_car.global_position.x - npc.global_position.x)
				var dy := absf(player_car.global_position.y - npc.global_position.y)
				var dz := absf(player_car.global_position.z - npc.global_position.z)
				var sweep_z := (absf(float(player_car.get("current_speed"))) + speed) * delta * 0.70
				if dx < 1.85 and dy < 2.0 and dz < (4.35 + sweep_z):
					var push_dir: float = -1.0 if player_car.global_position.x <= npc.global_position.x else 1.0
					print("StoryDrive: Oncoming collision triggered with %s (dx=%.2f dz=%.2f)" % [npc.name, dx, dz])
					trigger_npc_explosion(npc)
					if player_car.has_method("trigger_crash"):
						player_car.call("trigger_crash", push_dir)
					continue

		# Despawn once safely behind all player convoy cars
		if npc.position.z > rear_z + 80.0:
			to_remove.append(npc)

	for npc in to_remove:
		active_oncoming_cars.erase(npc)
		if is_instance_valid(npc):
			npc.queue_free()

	# 2b. Update all active same-lane NPC cars (drive forward -Z in player's left lane -2.1m)
	var to_remove_sl: Array[Node3D] = []
	for npc in active_same_lane_cars:
		if not is_instance_valid(npc):
			to_remove_sl.append(npc)
			continue
		var speed: float = float(npc.get_meta("speed", 13.5))
		npc.position.z -= speed * delta
		var road_cx := _get_road_center_x(npc.position.z)
		var road_cy := _get_road_elevation(npc.position.z)
		npc.position.x = road_cx - 2.1
		npc.position.y = road_cy + 0.04
		var next_cx := _get_road_center_x(npc.position.z - 8.0)
		var next_cy := _get_road_elevation(npc.position.z - 4.0)
		npc.rotation.y = -atan2(next_cx - road_cx, 8.0) + PI
		npc.rotation.x = -atan2(next_cy - road_cy, 4.0)

		if player_car.has_method("is_local_authority") and player_car.call("is_local_authority"):
			if not exploded_npc_names.has(npc.name):
				var dx := absf(player_car.global_position.x - npc.global_position.x)
				var dy := absf(player_car.global_position.y - npc.global_position.y)
				var dz := absf(player_car.global_position.z - npc.global_position.z)
				var sweep_z := absf(float(player_car.get("current_speed")) - speed) * delta * 0.70
				if dx < 1.85 and dy < 2.0 and dz < (4.35 + sweep_z):
					var push_dir: float = -1.0 if player_car.global_position.x <= npc.global_position.x else 1.0
					trigger_npc_explosion(npc)
					if player_car.has_method("trigger_crash"):
						player_car.call("trigger_crash", push_dir)
					continue

		if npc.position.z > rear_z + 60.0 or npc.position.z < CP_RESORT_ARRIVAL_Z + 20.0:
			to_remove_sl.append(npc)

	for npc in to_remove_sl:
		active_same_lane_cars.erase(npc)
		if is_instance_valid(npc):
			npc.queue_free()

	# 3. Host periodic position sync (~10Hz) so all traffic NPCs stay aligned between all peers
	if multiplayer.has_multiplayer_peer() and not _is_solo_mode() and multiplayer.is_server() and (not active_oncoming_cars.is_empty() or not active_same_lane_cars.is_empty()):
		oncoming_sync_timer += delta
		if oncoming_sync_timer >= 0.10:
			oncoming_sync_timer = 0.0
			var pos_map := {}
			for npc in active_oncoming_cars:
				if is_instance_valid(npc):
					pos_map[npc.name] = npc.position.z
			for npc in active_same_lane_cars:
				if is_instance_valid(npc):
					pos_map[npc.name] = npc.position.z
			if not pos_map.is_empty():
				rpc_sync_oncoming_positions.rpc(pos_map)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_oncoming_positions(pos_map: Dictionary) -> void:
	if not traffic_container:
		return
	for npc_name in pos_map.keys():
		var npc := traffic_container.get_node_or_null(str(npc_name)) as Node3D
		if is_instance_valid(npc):
			var target_z := float(pos_map[npc_name])
			if absf(npc.position.z - target_z) > 6.0:
				npc.position.z = target_z
			else:
				npc.position.z = lerpf(npc.position.z, target_z, 0.35)


@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_oncoming_npc(tid: int, color_idx: int, speed: float, spawn_z: float) -> void:
	_spawn_oncoming_npc(tid, color_idx, speed, spawn_z)


@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_same_lane_npc(tid: int, color_idx: int, speed: float, spawn_z: float) -> void:
	_spawn_same_lane_npc(tid, color_idx, speed, spawn_z)


func _spawn_same_lane_npc(tid: int, color_idx: int, speed: float, spawn_z: float) -> void:
	_spawn_traffic_npc(tid, color_idx, speed, spawn_z, true)


func _spawn_oncoming_npc(tid: int, color_idx: int, speed: float, spawn_z: float) -> void:
	_spawn_traffic_npc(tid, color_idx, speed, spawn_z, false)


func _spawn_traffic_npc(tid: int, color_idx: int, speed: float, spawn_z: float, is_same_lane: bool = false) -> void:
	if not traffic_container:
		return

	var npc := CharacterBody3D.new()
	npc.name = ("SameLaneNPC_%d" if is_same_lane else "OncomingNPC_%d") % tid
	npc.set_meta("speed", speed)
	npc.set_meta("is_same_lane", is_same_lane)
	npc.add_to_group("traffic_cars")

	# Collision box for oncoming traffic impact across slopes & high closing speed
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.00, 1.15, 4.35)
	col.shape = box
	col.position.y = 0.72
	npc.add_child(col)

	# Paint palettes
	var palette: Array[Color] = [
		Color(0.88, 0.88, 0.90), # Glacier White
		Color(0.65, 0.68, 0.72), # Silver Metallic
		Color(0.08, 0.14, 0.28), # Deep Navy
		Color(0.38, 0.08, 0.10), # Crimson Maroon
		Color(0.12, 0.12, 0.14)  # Midnight Charcoal
	]
	var paint_color: Color = palette[color_idx % palette.size()]

	var npc_layer_mask: int = 1 << 5
	var npc_other_lights_mask: int = 0xFFFFF & ~npc_layer_mask

	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = paint_color
	paint_mat.metallic = 0.16
	paint_mat.roughness = 0.56
	paint_mat.metallic_specular = 0.16

	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.06, 0.09, 0.13, 0.72)
	glass_mat.metallic = 0.0
	glass_mat.roughness = 0.52
	glass_mat.metallic_specular = 0.10

	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.05, 0.05, 0.05)
	tire_mat.roughness = 0.9

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.58, 0.61, 0.66)
	rim_mat.metallic = 0.35
	rim_mat.roughness = 0.52
	rim_mat.metallic_specular = 0.20

	# 1. Main Body
	var body := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(1.80, 0.60, 4.2)
	b_box.material = paint_mat
	body.mesh = b_box
	body.position.y = 0.58
	npc.add_child(body)

	# 2. Cabin Roof
	var cabin := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(1.48, 0.54, 2.1)
	c_box.material = paint_mat
	cabin.mesh = c_box
	cabin.position = Vector3(0.0, 1.12, -0.15)
	npc.add_child(cabin)

	# 3. Windshield & Rear Glass (NPC faces +Z, so front windshield is at +Z)
	var windshield := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(1.44, 0.46, 0.08)
	w_box.material = glass_mat
	windshield.mesh = w_box
	windshield.position = Vector3(0.0, 1.06, 0.95)
	windshield.rotation_degrees.x = 24.0
	npc.add_child(windshield)

	var rear_glass := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(1.44, 0.44, 0.08)
	r_box.material = glass_mat
	rear_glass.mesh = r_box
	rear_glass.position = Vector3(0.0, 1.06, -1.25)
	rear_glass.rotation_degrees.x = -22.0
	npc.add_child(rear_glass)

	# 4. RHD Driver Silhouette (inside cockpit on right side, which is -X when facing +Z)
	var torso := MeshInstance3D.new()
	var t_box := BoxMesh.new()
	t_box.size = Vector3(0.36, 0.40, 0.2)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.14, 0.16, 0.2)
	torso.mesh = t_box
	torso.material_override = body_mat
	torso.position = Vector3(-0.38, 0.95, -0.1) # Malaysian RHD
	npc.add_child(torso)

	var head := MeshInstance3D.new()
	var h_mesh := SphereMesh.new()
	h_mesh.radius = 0.11
	h_mesh.height = 0.22
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.6, 0.5, 0.42)
	head.mesh = h_mesh
	head.material_override = head_mat
	head.position = Vector3(-0.38, 1.25, -0.08)
	npc.add_child(head)

	# 5. Wheels
	var wheel_spins: Array[Node3D] = []
	for w_offset in [Vector3(-0.95, 0.34, 1.25), Vector3(0.95, 0.34, 1.25), Vector3(-0.95, 0.34, -1.35), Vector3(0.95, 0.34, -1.35)]:
		var w_mount := Node3D.new()
		w_mount.position = w_offset
		npc.add_child(w_mount)

		var sp := Node3D.new()
		w_mount.add_child(sp)
		wheel_spins.append(sp)

		var tire := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.34
		cyl.height = 0.22
		cyl.material = tire_mat
		tire.mesh = cyl
		tire.rotation_degrees.z = 90.0
		sp.add_child(tire)

		var rim := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius = 0.22
		rim_cyl.bottom_radius = 0.22
		rim_cyl.height = 0.224
		rim_cyl.material = rim_mat
		rim.mesh = rim_cyl
		rim.rotation_degrees.z = 90.0
		sp.add_child(rim)

	npc.set_meta("wheel_spins", wheel_spins)

	# 6. High-Beam Headlights (Pointing towards +Z into oncoming fog)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.98, 0.9)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.98, 0.9)
	bulb_mat.emission_energy_multiplier = 4.5

	for side in [-0.65, 0.65]:
		var bulb := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.12
		s_mesh.height = 0.24
		bulb.mesh = s_mesh
		bulb.material_override = bulb_mat
		bulb.position = Vector3(side, 0.62, 2.14)
		npc.add_child(bulb)

		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.96, 0.88)
		spot.light_energy = 8.5
		spot.spot_range = 75.0
		spot.spot_angle = 38.0
		spot.spot_attenuation = 0.7
		spot.shadow_enabled = true
		spot.position = Vector3(side, 0.62, 2.16)
		spot.rotation_degrees = Vector3(6.0, 180.0, 0.0)
		npc.add_child(spot)

	# Ground bounce light (excluded from NPC's own body/glass to prevent glare)
	var bounce := OmniLight3D.new()
	bounce.light_color = Color(0.95, 0.92, 0.85)
	bounce.light_energy = 3.5
	bounce.omni_range = 12.0
	bounce.light_cull_mask = npc_other_lights_mask
	bounce.position = Vector3(0.0, 0.42, 4.4)
	npc.add_child(bounce)

	# 7. Red Taillights (Facing -Z — excluded from NPC's own body/glass)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.95, 0.08, 0.08)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(0.95, 0.08, 0.08)
	tail_mat.emission_energy_multiplier = 2.4

	for t_side in [-0.7, 0.7]:
		var tail_mesh := MeshInstance3D.new()
		var tail_box := BoxMesh.new()
		tail_box.size = Vector3(0.24, 0.12, 0.04)
		tail_mesh.mesh = tail_box
		tail_mesh.material_override = tail_mat
		tail_mesh.position = Vector3(t_side, 0.65, -2.14)
		npc.add_child(tail_mesh)

		var red_glow := OmniLight3D.new()
		red_glow.light_color = Color(0.95, 0.08, 0.08)
		red_glow.light_energy = 0.8
		red_glow.omni_range = 3.8
		red_glow.light_cull_mask = npc_other_lights_mask
		red_glow.position = Vector3(t_side, 0.55, -2.35)
		npc.add_child(red_glow)

	_apply_render_layers(npc, npc_layer_mask)
	var road_cx := _get_road_center_x(spawn_z)
	var lane_x := (road_cx - 2.1) if is_same_lane else (road_cx + 2.1)
	npc.position = Vector3(lane_x, _get_road_elevation(spawn_z) + 0.04, spawn_z)
	if is_same_lane:
		npc.rotation.y = PI
		active_same_lane_cars.append(npc)
	else:
		active_oncoming_cars.append(npc)
	traffic_container.add_child(npc)
	print("StoryDrive: %s NPC Car %d spawned at Z=%.1f (lane %.1fm, speed=%.1f m/s)" % ["Same-lane" if is_same_lane else "Oncoming", tid, spawn_z, -2.1 if is_same_lane else 2.1, speed])

	# 8. Spatial Audio for Doppler passing whoosh (played after entering scene tree)
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	audio.stream = gen
	audio.volume_db = 0.0
	audio.unit_size = 14.0
	audio.max_distance = 80.0
	npc.add_child(audio)
	audio.play()
	var playback := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := playback.get_frames_available()
		for f in range(frames):
			var tone := sin(float(f) * 0.035) * 0.14
			playback.push_frame(Vector2(tone, tone))

	print("StoryDrive: Oncoming NPC Car %d spawned at Z=%.1f (opposing lane +2.1m, speed=%.1f m/s)" % [tid, spawn_z, speed])


func _check_milestones(car_z: float) -> void:
	var net := get_node_or_null("/root/NetworkManager")
	var is_solo: bool = _is_solo_mode()

	# Milestone 1: Masjid Mukim Kuala Semerak (30s timer ends or car reaches CP_KUALA_SEMERAK_Z)
	if current_checkpoint_idx == 0 and car_z <= CP_KUALA_SEMERAK_Z:
		current_checkpoint_idx = 1
		is_timer_active = false
		_trigger_kuala_semerak_transition()

	# Milestone 2: Jambatan Tok Bali Bridge Peak
	elif current_checkpoint_idx == 1 and car_z <= CP_BRIDGE_CREST_Z:
		current_checkpoint_idx = 2
		_show_milestone_banner("✦ JAMBATAN TOK BALI ✦", "Terusan Semerak • Pelabuhan Perikanan LKIM")
		if is_solo:
			_show_subtitle("Crossing Jambatan Tok Bali. The deep-sea trawlers at the harbour are quiet tonight...", 4.5)
		else:
			_show_subtitle("%s: 'Crossing Tok Bali bridge now. Quiet out here tonight.'" % _get_speaker("Syahirul", 0), 4.0)

	# Milestone 3: Junction 1 (Persimpangan Tok Bali)
	elif current_checkpoint_idx == 2 and car_z <= CP_JUNCTION_1_Z:
		current_checkpoint_idx = 3
		_show_milestone_banner("✦ PERSIMPANGAN TOK BALI ✦", "Take Right Fork: Laluan 189 (Telong / Kandis)")
		if is_solo:
			_show_subtitle("Taking the right fork onto Laluan 189 towards Telong and Kandis.", 4.0)
		else:
			_show_subtitle("%s: 'Take the right fork here onto Laluan 189 towards Telong and Kandis.'" % _get_speaker("Amelya", 1), 4.0)

	# Milestone 4: Junction 2 (Simpang Pantai Kandis / Kg Tok Kederat)
	elif current_checkpoint_idx == 3 and car_z <= CP_JUNCTION_2_Z:
		current_checkpoint_idx = 4
		_show_milestone_banner("✦ SIMPANG PANTAI KANDIS ✦", "Take Right Turn: Kg. Tok Kederat & Beach Resorts")
		if is_solo:
			_show_subtitle("Turning right into Kampung Tok Kederat towards the beach.", 4.0)
		else:
			_show_subtitle("%s: 'Turn right here into Kampung Tok Kederat. Almost there.'" % _get_speaker("Aleysa", 0), 4.0)

	# Milestone 5: Final Destination (Kandiez Sunrise Beach Resort) - stop each car on arrival & wait for all players
	elif current_checkpoint_idx == 4 and not has_reached_home:
		var total_humans: int = 0
		var arrived_humans: int = 0
		for car in cars:
			if not is_instance_valid(car) or bool(car.get("is_ai")):
				continue
			total_humans += 1
			if car.global_position.z <= CP_RESORT_ARRIVAL_Z and not arrived_car_names.has(car.name):
				arrived_car_names[car.name] = true
				car.set("is_parked_at_destination", true)
				if car.has_method("is_local_authority") and car.call("is_local_authority"):
					if multiplayer.has_multiplayer_peer() and not _is_solo_mode():
						rpc_notify_car_arrived.rpc(car.name)
			if arrived_car_names.has(car.name):
				arrived_humans += 1

		if total_humans > 0 and arrived_humans >= total_humans:
			has_reached_home = true
			current_checkpoint_idx = 5
			_hide_waiting_arrival_hud()
			_on_reach_resort()
		elif is_instance_valid(player_car) and arrived_car_names.has(player_car.name):
			_show_waiting_arrival_hud(arrived_humans, total_humans)


@rpc("any_peer", "call_local", "reliable")
func rpc_notify_car_arrived(car_name: String) -> void:
	arrived_car_names[car_name] = true
	for car in cars:
		if is_instance_valid(car) and car.name == car_name:
			car.set("is_parked_at_destination", true)
			break


func _trigger_kuala_semerak_transition() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	var is_solo: bool = _is_solo_mode()
	if current_checkpoint_idx == 0:
		current_checkpoint_idx = 1
	if timer_container:
		timer_container.visible = false
	_show_milestone_banner("✦ LALUAN 189 • KUALA SEMERAK ✦", "Masjid Mukim Kuala Semerak • Route to Tok Bali")
	if is_solo:
		_show_subtitle("Masjid Mukim Kuala Semerak... the emerald dome shines in the darkness. Jambatan Tok Bali is ahead.", 4.5)
	else:
		_show_subtitle("%s: 'There's Masjid Kuala Semerak on the left. Tok Bali bridge is right ahead.'" % _get_speaker("Aleysa", 1), 4.5)


func _on_reach_resort() -> void:
	drive_checkpoint_reached.emit(5)
	print("StoryDrive: Arrived at Kandiez Sunrise Beach Resort!")

	# Park and stop all cars cleanly at the resort checkpoint
	for car in cars:
		if is_instance_valid(car):
			car.set("is_parked_at_destination", true)
			car.set("input_gas", 0.0)
			car.set("input_brake", 1.0)
			car.set("is_ai", false)

	if boost_button:
		boost_button.visible = false

	var net := get_node_or_null("/root/NetworkManager")
	var is_solo: bool = _is_solo_mode()
	var num_players: int = 1 if is_solo else (net.players.size() if net else 1)

	# Auto-save progression to SaveManager
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr:
		if is_solo:
			save_mgr.save_campaign_progress(
				1,
				"Chapter 1: The Midnight Return",
				"kandiez_resort_arrival",
				"Kandiez Sunrise Beach Resort",
				{"highway_completed": true, "arrived_home": true}
			)
		else:
			if multiplayer.is_server():
				save_mgr.save_coop_host_progress(
					1,
					"Chapter 1: The Midnight Return",
					"kandiez_resort_arrival",
					"Kandiez Sunrise Beach Resort"
				)

	_show_resort_arrival_hud()
	if is_solo:
		_show_subtitle("Dad (on the chalet porch): 'Alhamdulillah, you made it back safe alone. Park the car. Let's talk inside.'", 6.0)
	elif num_players == 2:
		_show_subtitle("Dad (on the chalet porch): 'Alhamdulillah, you two made it back safe. Park the cars. Let's talk inside.'", 6.0)
	else:
		_show_subtitle("Dad (on the chalet porch): 'Alhamdulillah, you all made it back safe. Park the cars. Let's talk inside.'", 6.0)

	# Fade to black then transition cleanly to the Resort Chalet on-foot scene
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void:
		if multiplayer != null and multiplayer.has_multiplayer_peer() and not _is_solo_mode():
			if multiplayer.is_server():
				rpc_start_resort_fade.rpc()
		else:
			_play_resort_fade()
	)
	tw.tween_interval(1.1)
	tw.tween_callback(func() -> void:
		if multiplayer != null and multiplayer.has_multiplayer_peer() and not _is_solo_mode():
			if multiplayer.is_server():
				rpc_go_to_resort_chalet.rpc()
		else:
			get_tree().call_deferred("change_scene_to_file", "res://scenes/resort_chalet.tscn")
	)


@rpc("authority", "call_local", "reliable")
func rpc_start_resort_fade() -> void:
	_play_resort_fade()


func _play_resort_fade() -> void:
	if not is_instance_valid(drive_canvas):
		return
	var fade := ColorRect.new()
	fade.name = "ArrivalFadeRect"
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drive_canvas.add_child(fade)
	var f_tw := create_tween()
	f_tw.tween_property(fade, "color:a", 1.0, 0.95)


@rpc("authority", "call_local", "reliable")
func rpc_go_to_resort_chalet() -> void:
	set_process(false)
	set_physics_process(false)
	for car in cars:
		if is_instance_valid(car):
			car.set("is_active_driving", false)
	if is_inside_tree():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/resort_chalet.tscn")


# --- Road Path & Elevation Curves ---
func _get_road_elevation(z: float) -> float:
	# 1. Tok Bali Bridge Arch (Z = -950m to -1250m)
	if z <= -950.0 and z >= -1250.0:
		var bridge_t := (-z - 950.0) / 300.0  # 0.0 to 1.0
		return sin(bridge_t * PI) * 8.5       # Curves upward to +8.5m crest

	# 2. Kuala Semerak flat terrain & bridge approach (Z = -720m to -950m)
	elif z <= -720.0 and z > -950.0:
		var t := (-z - 720.0) / 230.0
		var base_elev := sin(-720.0 * 0.014) * 2.2 + sin(-720.0 * 0.005) * 1.0
		return lerpf(base_elev, 0.0, t)

	# 3. Post-Bridge & Coastal Highway (Z = -1250m to -1950m)
	elif z < -1250.0 and z >= -1950.0:
		return 0.0

	# 4. Beach Road to Kandiez Resort (Z < -1950m)
	elif z < -1950.0:
		return sin(z * 0.008) * 0.35  # Gentle coastal undulations

	# 5. Phase 1 Highway (Z > -720m)
	else:
		return sin(z * 0.014) * 2.2 + sin(z * 0.005) * 1.0


func _get_road_center_x(z: float) -> float:
	# Phase 1: Highway with straights and gentle S-curves
	if z > -720.0:
		return sin(z * 0.012) * 5.2 + sin(z * 0.005) * 2.4

	# Kuala Semerak transition aligning straight past mosque towards bridge
	elif z <= -720.0 and z > -900.0:
		var t := clampf((-z - 720.0) / 180.0, 0.0, 1.0)
		var prev_x := sin(-720.0 * 0.012) * 5.2 + sin(-720.0 * 0.005) * 2.4
		return lerpf(prev_x, 0.0, t)

	# Kuala Semerak & Tok Bali Bridge (straight along Z = -900m to -1600m)
	elif z <= -900.0 and z > -1600.0:
		return 0.0

	# Junction 1 (Z = -1600m): Right branch onto Laluan 189 Telong / Kandis corridor (X = +20m)
	elif z <= -1600.0 and z > -1950.0:
		var t1 := clampf((-z - 1600.0) / 125.0, 0.0, 1.0)
		return (1.0 - cos(t1 * PI)) * 0.5 * 20.0

	# Junction 2 (Z = -1950m): Sharper right turn onto Pesisir Pantai Kandis (X = +42m)
	elif z <= -1950.0:
		var t2 := clampf((-z - 1950.0) / 68.0, 0.0, 1.0)
		return 20.0 + (1.0 - cos(t2 * PI)) * 0.5 * 22.0

	return 0.0


# --- Highway & Environment Generation ---
func _setup_environment() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.02)
	env.background_energy_multiplier = 0.25

	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.09)
	env.fog_density = 0.0065
	env.fog_sky_affect = 0.0

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.26, 0.38)
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	world_env.environment = env
	add_child(world_env)

	# Moonlight
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.68, 0.78, 0.96)
	moon.light_energy = 1.15
	moon.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	moon.shadow_enabled = false
	add_child(moon)


func _setup_highway() -> void:
	highway_root = Node3D.new()
	highway_root.name = "Highway"
	add_child(highway_root)

	var seg_length: float = 10.0
	var cur_z: float = 60.0

	# Materials
	var asphalt_mat := StandardMaterial3D.new()
	asphalt_mat.albedo_color = Color(0.10, 0.105, 0.12)
	asphalt_mat.roughness = 0.88

	var beach_road_mat := StandardMaterial3D.new()
	beach_road_mat.albedo_color = Color(0.14, 0.135, 0.13)
	beach_road_mat.roughness = 0.92

	var shoulder_mat := StandardMaterial3D.new()
	shoulder_mat.albedo_color = Color(0.04, 0.045, 0.04)
	shoulder_mat.roughness = 0.95

	var sand_shoulder_mat := StandardMaterial3D.new()
	sand_shoulder_mat.albedo_color = Color(0.22, 0.19, 0.14)
	sand_shoulder_mat.roughness = 0.98

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.018, 0.024, 0.016)
	ground_mat.roughness = 1.0

	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.9, 0.82, 0.35)
	dash_mat.emission_enabled = true
	dash_mat.emission = Color(0.3, 0.28, 0.12)
	dash_mat.emission_energy_multiplier = 0.4

	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.88, 0.9, 0.95)
	edge_mat.roughness = 0.6

	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.52, 0.55, 0.60)
	rail_mat.metallic = 0.25
	rail_mat.roughness = 0.65
	rail_mat.metallic_specular = 0.18

	var bridge_balustrade_mat := StandardMaterial3D.new()
	bridge_balustrade_mat.albedo_color = Color(0.78, 0.80, 0.82)
	bridge_balustrade_mat.roughness = 0.55

	var wood_fence_mat := StandardMaterial3D.new()
	wood_fence_mat.albedo_color = Color(0.26, 0.18, 0.12)
	wood_fence_mat.roughness = 0.9

	while cur_z > -HIGHWAY_LENGTH:
		var z_start := cur_z
		var z_end := cur_z - seg_length
		var x_start := _get_road_center_x(z_start)
		var x_end := _get_road_center_x(z_end)
		var y_start := _get_road_elevation(z_start)
		var y_end := _get_road_elevation(z_end)

		var cx := (x_start + x_end) * 0.5
		var cy := (y_start + y_end) * 0.5
		var cz := (z_start + z_end) * 0.5

		var dx := x_end - x_start
		var dy := y_end - y_start
		var yaw := -atan2(dx, seg_length)
		var slope_pitch := atan2(dy, seg_length)

		var is_beach := (cz <= -1950.0)
		var is_bridge := (cz <= -950.0 and cz >= -1250.0)
		var is_countryside := (cz <= -720.0 and not is_beach and not is_bridge)

		# 1. Main Asphalt Surface
		var road_mesh := BoxMesh.new()
		road_mesh.size = Vector3(8.6, 0.15, seg_length + 0.35)
		road_mesh.material = beach_road_mat if is_beach else asphalt_mat

		var road_inst := MeshInstance3D.new()
		road_inst.mesh = road_mesh
		road_inst.position = Vector3(cx, cy - 0.07, cz)
		road_inst.rotation = Vector3(slope_pitch, yaw, 0.0)
		highway_root.add_child(road_inst)

		# 2. Road Collision Surface (Solid 16.4m floor spanning road & shoulders)
		var col_body := StaticBody3D.new()
		col_body.name = "RoadColBody"
		col_body.add_to_group("road")
		col_body.position = Vector3(cx, cy - 0.10, cz)
		col_body.rotation = Vector3(slope_pitch, yaw, 0.0)
		var col_shape := CollisionShape3D.new()
		var col_box := BoxShape3D.new()
		col_box.size = Vector3(16.4, 0.22, seg_length + 0.45)
		col_shape.shape = col_box
		col_body.add_child(col_shape)
		highway_root.add_child(col_body)

		# 3. Shoulders
		for side in [-1.0, 1.0]:
			var sh_mesh := BoxMesh.new()
			sh_mesh.size = Vector3(3.8, 0.12, seg_length + 0.35)
			sh_mesh.material = sand_shoulder_mat if is_beach else shoulder_mat
			var sh_inst := MeshInstance3D.new()
			sh_inst.mesh = sh_mesh
			sh_inst.position = Vector3(cx + side * (4.3 + 1.9), cy - 0.08, cz)
			sh_inst.rotation = Vector3(slope_pitch, yaw, 0.0)
			highway_root.add_child(sh_inst)

		# 4. Outer Ground (Omit on Tok Bali bridge span to show open water below)
		if not is_bridge:
			for side in [-1.0, 1.0]:
				var gr_mesh := BoxMesh.new()
				gr_mesh.size = Vector3(110.0, 0.1, seg_length + 0.35)
				gr_mesh.material = ground_mat
				var gr_inst := MeshInstance3D.new()
				gr_inst.mesh = gr_mesh
				gr_inst.position = Vector3(cx + side * (6.1 + 55.0), cy - 0.09, cz)
				highway_root.add_child(gr_inst)

		# 5. Road Lines
		var dash := MeshInstance3D.new()
		var dash_box := BoxMesh.new()
		dash_box.size = Vector3(0.18, 0.008, 4.0)
		dash_box.material = dash_mat
		dash.mesh = dash_box
		dash.position = Vector3(cx, cy + 0.01, cz)
		dash.rotation = Vector3(slope_pitch, yaw, 0.0)
		highway_root.add_child(dash)

		var in_left_fork_opening := (
			(cz <= CP_JUNCTION_1_Z + 4.0 and cz >= CP_JUNCTION_1_Z - 56.0) or
			(cz <= CP_JUNCTION_2_Z + 4.0 and cz >= CP_JUNCTION_2_Z - 34.0)
		)
		var in_resort_driveway := (cz <= CP_RESORT_ARRIVAL_Z - 4.0 and cz >= CP_RESORT_ARRIVAL_Z - 44.0)

		for side in [-1.0, 1.0]:
			if side < 0.0 and in_left_fork_opening:
				continue
			var edge := MeshInstance3D.new()
			var edge_box := BoxMesh.new()
			edge_box.size = Vector3(0.14, 0.008, seg_length + 0.35)
			edge_box.material = edge_mat
			edge.mesh = edge_box
			edge.position = Vector3(cx + side * 4.1, cy + 0.01, cz)
			edge.rotation = Vector3(slope_pitch, yaw, 0.0)
			highway_root.add_child(edge)

		# 6. Side Barriers & Guardrails (Leave left fork opening clear at 3-way junctions & resort driveway)
		for side in [-1.0, 1.0]:
			if (side < 0.0 and in_left_fork_opening) or in_resort_driveway:
				continue
			var barrier_offset := 6.2
			var barrier_mesh: BoxMesh = BoxMesh.new()

			if is_bridge:
				barrier_offset = 5.2
				barrier_mesh.size = Vector3(0.35, 1.05, seg_length + 0.35)
				barrier_mesh.material = bridge_balustrade_mat
			elif is_countryside or is_beach:
				barrier_mesh.size = Vector3(0.18, 0.65, seg_length + 0.35)
				barrier_mesh.material = wood_fence_mat
			else:
				barrier_mesh.size = Vector3(0.16, 0.52, seg_length + 0.35)
				barrier_mesh.material = rail_mat

			var bar_inst := MeshInstance3D.new()
			bar_inst.mesh = barrier_mesh
			bar_inst.position = Vector3(cx + side * barrier_offset, cy + 0.45, cz)
			bar_inst.rotation = Vector3(slope_pitch, yaw, 0.0)
			highway_root.add_child(bar_inst)

			# Tall solid collision barrier
			var rail_body := StaticBody3D.new()
			rail_body.add_to_group("side_dividers")
			var div_type := "bridge" if is_bridge else ("wood" if (is_countryside or is_beach) else "metal")
			rail_body.set_meta("divider_type", div_type)
			rail_body.position = bar_inst.position
			rail_body.rotation = bar_inst.rotation
			var rail_col := CollisionShape3D.new()
			var r_box := BoxShape3D.new()
			r_box.size = Vector3(0.4, 2.5, seg_length + 0.5)
			rail_col.shape = r_box
			rail_col.position.y = 0.8
			rail_body.add_child(rail_col)
			highway_root.add_child(rail_body)

		cur_z -= seg_length

	# Setup Real-World Features: Masjid Kuala Semerak, Tok Bali Bridge & Trawlers, Junctions, Beach Ocean & Kandiez Resort
	_setup_masjid_kuala_semerak()
	_setup_tok_bali_bridge()
	_setup_junction_forks()
	_setup_beach_ocean()
	_setup_kandiez_beach_resort()


# --- Masjid Mukim Kuala Semerak (Masjid Al-Hasanain, Laluan 189) ---
func _setup_masjid_kuala_semerak() -> void:
	var mosque_group := Node3D.new()
	mosque_group.name = "MasjidMukimKualaSemerak"
	var mosque_z := CP_KUALA_SEMERAK_Z
	var road_cx := _get_road_center_x(mosque_z)
	var road_cy := _get_road_elevation(mosque_z)
	mosque_group.position = Vector3(road_cx - 21.5, road_cy - 0.12, mosque_z)
	highway_root.add_child(mosque_group)

	# 1. Main Prayer Hall
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.92, 0.90, 0.86)
	wall_mat.roughness = 0.8

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.08, 0.26, 0.14)  # Islamic Forest Green
	roof_mat.roughness = 0.65

	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = Color(0.12, 0.65, 0.32)
	dome_mat.emission_enabled = true
	dome_mat.emission = Color(0.15, 0.85, 0.38)
	dome_mat.emission_energy_multiplier = 2.2

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.82, 0.25)
	gold_mat.metallic = 0.9
	gold_mat.roughness = 0.2

	# Main Prayer Hall Box
	var hall := MeshInstance3D.new()
	var h_box := BoxMesh.new()
	h_box.size = Vector3(18.0, 6.5, 22.0)
	h_box.material = wall_mat
	hall.mesh = h_box
	hall.position = Vector3(0.0, 3.25, 0.0)
	mosque_group.add_child(hall)

	# Multi-tiered Malay Pitched Roof (Tier 1 & Tier 2)
	var tier1 := MeshInstance3D.new()
	var t1_box := BoxMesh.new()
	t1_box.size = Vector3(20.4, 1.2, 24.4)
	t1_box.material = roof_mat
	tier1.mesh = t1_box
	tier1.position = Vector3(0.0, 6.9, 0.0)
	mosque_group.add_child(tier1)

	var tier2 := MeshInstance3D.new()
	var t2_box := BoxMesh.new()
	t2_box.size = Vector3(14.0, 1.6, 17.0)
	t2_box.material = roof_mat
	tier2.mesh = t2_box
	tier2.position = Vector3(0.0, 8.2, 0.0)
	mosque_group.add_child(tier2)

	# Central Glowing Emerald Dome
	var dome := MeshInstance3D.new()
	var d_sphere := SphereMesh.new()
	d_sphere.radius = 3.4
	d_sphere.height = 4.8
	d_sphere.material = dome_mat
	dome.mesh = d_sphere
	dome.position = Vector3(0.0, 10.8, 0.0)
	mosque_group.add_child(dome)

	# Dome Finial Crescent
	var finial := MeshInstance3D.new()
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 0.05
	f_cyl.bottom_radius = 0.15
	f_cyl.height = 1.6
	f_cyl.material = gold_mat
	finial.mesh = f_cyl
	finial.position = Vector3(0.0, 13.5, 0.0)
	mosque_group.add_child(finial)

	# 2. Minaret Tower (Menara Masjid)
	var minaret := MeshInstance3D.new()
	var m_cyl := CylinderMesh.new()
	m_cyl.top_radius = 1.1
	m_cyl.bottom_radius = 1.6
	m_cyl.height = 17.0
	m_cyl.material = wall_mat
	minaret.mesh = m_cyl
	minaret.position = Vector3(9.5, 8.5, 11.5)
	mosque_group.add_child(minaret)

	# Minaret Balcony
	var m_balcony := MeshInstance3D.new()
	var mb_cyl := CylinderMesh.new()
	mb_cyl.top_radius = 1.8
	mb_cyl.bottom_radius = 1.8
	mb_cyl.height = 0.6
	mb_cyl.material = roof_mat
	m_balcony.mesh = mb_cyl
	m_balcony.position = Vector3(9.5, 16.5, 11.5)
	mosque_group.add_child(m_balcony)

	# Minaret Dome
	var m_dome := MeshInstance3D.new()
	var md_sphere := SphereMesh.new()
	md_sphere.radius = 1.2
	md_sphere.height = 1.8
	md_sphere.material = dome_mat
	m_dome.mesh = md_sphere
	m_dome.position = Vector3(9.5, 17.8, 11.5)
	mosque_group.add_child(m_dome)

	# Minaret Green Architectural Glow Light
	var m_light := OmniLight3D.new()
	m_light.light_color = Color(0.2, 0.95, 0.45)
	m_light.light_energy = 4.5
	m_light.omni_range = 22.0
	m_light.position = Vector3(9.5, 18.2, 11.5)
	mosque_group.add_child(m_light)

	# 3. Front Verandah & Arch Pillars
	var porch := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(10.0, 4.2, 4.5)
	var porch_mat := StandardMaterial3D.new()
	porch_mat.albedo_color = Color(0.95, 0.93, 0.88)
	p_box.material = porch_mat
	porch.mesh = p_box
	porch.position = Vector3(8.5, 2.1, 0.0)
	mosque_group.add_child(porch)

	# Warm Verandah Ambient Light
	var v_light := OmniLight3D.new()
	v_light.light_color = Color(1.0, 0.88, 0.6)
	v_light.light_energy = 3.5
	v_light.omni_range = 16.0
	v_light.position = Vector3(9.0, 2.8, 0.0)
	mosque_group.add_child(v_light)

	# 4. Authentic Roadside Signboard (Grounded outside left guardrail, facing approaching traffic)
	var sign_z := mosque_z + 10.0
	var sign_world_x := _get_road_center_x(sign_z) - 8.6
	var sign_world_y := _get_road_elevation(sign_z) - 0.12
	var sign_node := Node3D.new()
	sign_node.position = Vector3(sign_world_x, sign_world_y, sign_z)
	sign_node.rotation_degrees = Vector3(0.0, -18.0, 0.0)

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.28, 0.30, 0.34)
	post_mat.metallic = 0.65
	post_mat.roughness = 0.45

	for px in [-1.65, 1.65]:
		var leg := MeshInstance3D.new()
		var leg_cyl := CylinderMesh.new()
		leg_cyl.top_radius = 0.09
		leg_cyl.bottom_radius = 0.10
		leg_cyl.height = 3.2
		leg_cyl.material = post_mat
		leg.mesh = leg_cyl
		leg.position = Vector3(px, 1.35, 0.0)
		sign_node.add_child(leg)

	var s_board := MeshInstance3D.new()
	var sb_box := BoxMesh.new()
	sb_box.size = Vector3(4.6, 1.6, 0.22)
	var sb_mat := StandardMaterial3D.new()
	sb_mat.albedo_color = Color(0.06, 0.24, 0.12)
	sb_mat.roughness = 0.72
	sb_box.material = sb_mat
	s_board.mesh = sb_box
	s_board.position = Vector3(0.0, 2.35, 0.0)
	sign_node.add_child(s_board)

	var s_label := Label3D.new()
	s_label.text = "MASJID MUKIM KUALA SEMERAK\n(MASJID AL-HASANAIN)\nDAERAH SEMERAK • LALUAN 189"
	s_label.font_size = 20
	s_label.modulate = Color(1.0, 0.92, 0.55)
	s_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_label.position = Vector3(0.0, 2.35, 0.13)
	sign_node.add_child(s_label)

	var sign_light := SpotLight3D.new()
	sign_light.light_color = Color(1.0, 0.95, 0.75)
	sign_light.light_energy = 3.2
	sign_light.spot_range = 8.0
	sign_light.spot_angle = 55.0
	sign_light.position = Vector3(0.0, 1.0, 2.2)
	sign_light.rotation_degrees = Vector3(22.0, 0.0, 0.0)
	sign_node.add_child(sign_light)

	highway_root.add_child(sign_node)

	# 5. Nearby Malay Traditional Kampung Houses & Keropok Lekor Stall
	_setup_kampung_houses_and_warung()


func _setup_kampung_houses_and_warung() -> void:
	var village_group := Node3D.new()
	village_group.name = "KualaSemerakVillage"
	highway_root.add_child(village_group)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.32, 0.22, 0.14)

	var zinc_mat := StandardMaterial3D.new()
	zinc_mat.albedo_color = Color(0.55, 0.58, 0.6)
	zinc_mat.metallic = 0.7
	zinc_mat.roughness = 0.45

	# Traditional Malay Stilt Houses along the roadside
	for h_idx in range(3):
		var h_z: float = -770.0 - float(h_idx) * 65.0
		var h_side: float = 1.0 if (h_idx % 2 == 0) else -1.0
		var house := Node3D.new()
		house.position = Vector3(_get_road_center_x(h_z) + h_side * 18.0, _get_road_elevation(h_z) - 0.1, h_z)

		# Stilts (Pillars)
		for px in [-3.0, 3.0]:
			for pz in [-2.5, 2.5]:
				var stilt := MeshInstance3D.new()
				var s_mesh := CylinderMesh.new()
				s_mesh.top_radius = 0.12
				s_mesh.bottom_radius = 0.14
				s_mesh.height = 1.8
				s_mesh.material = wood_mat
				stilt.mesh = s_mesh
				stilt.position = Vector3(px, 0.9, pz)
				house.add_child(stilt)

		# Wooden Living Room
		var living := MeshInstance3D.new()
		var l_mesh := BoxMesh.new()
		l_mesh.size = Vector3(7.5, 2.8, 6.2)
		l_mesh.material = wood_mat
		living.mesh = l_mesh
		living.position.y = 3.2
		house.add_child(living)

		# Zinc Pitched Roof
		var roof := MeshInstance3D.new()
		var r_mesh := BoxMesh.new()
		r_mesh.size = Vector3(8.5, 1.4, 7.2)
		r_mesh.material = zinc_mat
		roof.mesh = r_mesh
		roof.position.y = 5.2
		house.add_child(roof)

		# Warm Window Light
		var w_light := OmniLight3D.new()
		w_light.light_color = Color(1.0, 0.85, 0.55)
		w_light.light_energy = 2.2
		w_light.omni_range = 12.0
		w_light.position = Vector3(0.0, 3.2, 0.0)
		house.add_child(w_light)

		village_group.add_child(house)

	# Roadside Keropok Lekor & Fresh Coconut Warung Stall at Z = -820m
	var warung := Node3D.new()
	warung.position = Vector3(_get_road_center_x(-820.0) + 12.5, _get_road_elevation(-820.0) - 0.1, -820.0)

	var w_base := MeshInstance3D.new()
	var wb_mesh := BoxMesh.new()
	wb_mesh.size = Vector3(5.5, 2.4, 3.8)
	wb_mesh.material = wood_mat
	w_base.mesh = wb_mesh
	w_base.position.y = 1.2
	warung.add_child(w_base)

	var w_sign := Label3D.new()
	w_sign.text = "WARUNG KEROPOK LEKOR KUALA SEMERAK\nIKAN SEGAR • KELAPA MUDA"
	w_sign.font_size = 18
	w_sign.modulate = Color(1.0, 0.85, 0.3)
	w_sign.position = Vector3(-2.85, 2.2, 0.0)
	w_sign.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	warung.add_child(w_sign)

	var w_bulb := OmniLight3D.new()
	w_bulb.light_color = Color(1.0, 0.8, 0.35)
	w_bulb.light_energy = 3.5
	w_bulb.omni_range = 10.0
	w_bulb.position = Vector3(-2.2, 2.0, 0.0)
	warung.add_child(w_bulb)

	village_group.add_child(warung)


# --- Jambatan Tok Bali (Iconic Upward-Curved Estuary Bridge) ---
func _setup_tok_bali_bridge() -> void:
	var bridge_group := Node3D.new()
	bridge_group.name = "JambatanTokBali"
	highway_root.add_child(bridge_group)

	# 1. Dark Water Estuary River underneath (Z = -950m to -1250m)
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(280.0, 320.0)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.02, 0.04, 0.08)
	water_mat.metallic = 0.95
	water_mat.roughness = 0.08
	water_mesh.material = water_mat

	var water_inst := MeshInstance3D.new()
	water_inst.mesh = water_mesh
	water_inst.position = Vector3(0.0, -2.8, -1100.0)
	bridge_group.add_child(water_inst)

	# 2. Tok Bali Bridge Concrete Support Piers
	var pier_mat := StandardMaterial3D.new()
	pier_mat.albedo_color = Color(0.65, 0.68, 0.70)
	pier_mat.roughness = 0.6

	for pier_z in [-1000.0, -1070.0, -1130.0, -1200.0]:
		var deck_y := _get_road_elevation(pier_z)
		for side in [-1.0, 1.0]:
			var pier := MeshInstance3D.new()
			var p_mesh := BoxMesh.new()
			var p_height := deck_y + 3.0
			p_mesh.size = Vector3(1.2, p_height, 2.4)
			p_mesh.material = pier_mat
			pier.mesh = p_mesh
			pier.position = Vector3(side * 4.6, (deck_y - 2.8) * 0.5, pier_z)
			bridge_group.add_child(pier)

	# 3. Two Iconic Overhead Arch Ribs (Tok Bali characteristic bow arches)
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.72, 0.76, 0.80)
	arch_mat.metallic = 0.85
	arch_mat.roughness = 0.3

	for side in [-1.0, 1.0]:
		for step in range(12):
			var t1 := float(step) / 12.0
			var t2 := float(step + 1) / 12.0
			var z1 := lerpf(-970.0, -1230.0, t1)
			var z2 := lerpf(-970.0, -1230.0, t2)
			var y1 := _get_road_elevation(z1) + sin(t1 * PI) * 5.5 + 1.2
			var y2 := _get_road_elevation(z2) + sin(t2 * PI) * 5.5 + 1.2

			var segment := MeshInstance3D.new()
			var seg_box := BoxMesh.new()
			var dist := Vector3(0.0, y1, z1).distance_to(Vector3(0.0, y2, z2))
			seg_box.size = Vector3(0.35, 0.35, dist)
			seg_box.material = arch_mat
			segment.mesh = seg_box
			segment.position = Vector3(side * 5.2, (y1 + y2) * 0.5, (z1 + z2) * 0.5)
			segment.rotation.x = atan2(y2 - y1, z1 - z2)
			bridge_group.add_child(segment)

	# 4. Bridge Name Landmark Signboard
	var sign_label := Label3D.new()
	sign_label.text = "JAMBATAN TOK BALI\nTERUSAN SEMERAK • PASIR PUTEH"
	sign_label.font_size = 26
	sign_label.modulate = Color(0.95, 0.95, 0.95)
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.position = Vector3(0.0, _get_road_elevation(-960.0) + 4.5, -960.0)
	bridge_group.add_child(sign_label)

	# 5. Deep-Sea Fishing Trawlers docked in Terusan Semerak (Pelabuhan LKIM Tok Bali)
	var trawler_hull_mat := StandardMaterial3D.new()
	trawler_hull_mat.albedo_color = Color(0.12, 0.32, 0.52)
	trawler_hull_mat.roughness = 0.7

	var trawler_cabin_mat := StandardMaterial3D.new()
	trawler_cabin_mat.albedo_color = Color(0.9, 0.92, 0.92)

	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.35, 0.25, 0.18)

	for b_idx in range(3):
		var b_z: float = -1040.0 - float(b_idx) * 65.0
		var trawler := Node3D.new()
		trawler.position = Vector3(-35.0 - float(b_idx) * 3.0, -2.4, b_z)

		# Boat Hull
		var hull := MeshInstance3D.new()
		var h_mesh := BoxMesh.new()
		h_mesh.size = Vector3(5.8, 2.6, 17.5)
		h_mesh.material = trawler_hull_mat
		hull.mesh = h_mesh
		hull.position.y = 1.3
		trawler.add_child(hull)

		# Wheelhouse Cabin
		var cabin := MeshInstance3D.new()
		var c_mesh := BoxMesh.new()
		c_mesh.size = Vector3(3.8, 2.4, 5.2)
		c_mesh.material = trawler_cabin_mat
		cabin.mesh = c_mesh
		cabin.position = Vector3(0.0, 3.2, -1.5)
		trawler.add_child(cabin)

		# Mast & Rigging
		var mast := MeshInstance3D.new()
		var m_mesh := CylinderMesh.new()
		m_mesh.top_radius = 0.08
		m_mesh.bottom_radius = 0.16
		m_mesh.height = 7.5
		m_mesh.material = mast_mat
		mast.mesh = m_mesh
		mast.position = Vector3(0.0, 6.0, 2.5)
		trawler.add_child(mast)

		# Navigation Light (green/red)
		var nav_light := OmniLight3D.new()
		nav_light.light_color = Color(0.2, 0.9, 0.4) if (b_idx % 2 == 0) else Color(1.0, 0.25, 0.2)
		nav_light.light_energy = 2.8
		nav_light.omni_range = 14.0
		nav_light.position = Vector3(0.0, 9.8, 2.5)
		trawler.add_child(nav_light)

		bridge_group.add_child(trawler)

	# LKIM Harbour Signboard on Wharf
	var harbour_sign := Label3D.new()
	harbour_sign.text = "PELABUHAN PERIKANAN LKIM TOK BALI\nKOMPLEKS PENDARATAN IKAN"
	harbour_sign.font_size = 22
	harbour_sign.modulate = Color(0.85, 0.92, 1.0)
	harbour_sign.position = Vector3(-28.0, 1.2, -1070.0)
	bridge_group.add_child(harbour_sign)


# --- 3-Way Junctions & Branching Roads ---
func _setup_junction_forks() -> void:
	var junc_group := Node3D.new()
	junc_group.name = "Junctions"
	highway_root.add_child(junc_group)

	# Junction 1 (Z = -1600m): Persimpangan Tok Bali - Straight (Cherang Ruku/Pasir Puteh) vs Right (Laluan 189 Telong/Kandis)
	_build_junction_fork(
		junc_group,
		CP_JUNCTION_1_Z,
		0.0,
		125.0,
		"[↑ CHERANG RUKU / PASIR PUTEH]\n[→ LALUAN 189: TELONG / KANDIS / BACHOK]",
		false
	)

	# Junction 2 (Z = -1950m): Simpang Pantai Kandis (Sharper Turn) - Straight (Jelawat/Kota Bharu) vs Right (Pantai Kandis / Kg Tok Kederat)
	_build_junction_fork(
		junc_group,
		CP_JUNCTION_2_Z,
		20.0,
		68.0,
		"[↑ JELAWAT / KOTA BHARU]\n[→ PANTAI KANDIS / KG. TOK KEDERAT / RESORT PANTAI]",
		true
	)


func _build_junction_fork(parent: Node3D, z_junc: float, base_x: float, curve_len: float, gantry_text: String, is_beach_style: bool) -> void:
	var jy := _get_road_elevation(z_junc)
	var sep_dz: float = 56.0 if curve_len > 90.0 else 34.0

	# 1. Overhead Malaysian JKR Highway Gantry right at junction approach
	var gantry := _create_highway_gantry(Vector3(base_x, jy, z_junc + 12.0), gantry_text)
	parent.add_child(gantry)

	var asphalt_mat := StandardMaterial3D.new()
	asphalt_mat.albedo_color = Color(0.13, 0.125, 0.12) if is_beach_style else Color(0.10, 0.105, 0.12)
	asphalt_mat.roughness = 0.90

	var shoulder_mat := StandardMaterial3D.new()
	shoulder_mat.albedo_color = Color(0.22, 0.19, 0.14) if is_beach_style else Color(0.04, 0.045, 0.04)
	shoulder_mat.roughness = 0.96

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.018, 0.024, 0.016)
	ground_mat.roughness = 1.0

	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.9, 0.82, 0.35)
	dash_mat.emission_enabled = true
	dash_mat.emission = Color(0.3, 0.28, 0.12)
	dash_mat.emission_energy_multiplier = 0.4

	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.88, 0.9, 0.95)
	edge_mat.roughness = 0.6

	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = Color(0.26, 0.18, 0.12)
	fence_mat.roughness = 0.9

	# 2. Visible Straight Continuation Main Road (Unintended branch ahead, 90m long)
	for seg_i in range(9):
		var seg_cz := z_junc - 5.0 - float(seg_i) * 10.0
		var seg_y := _get_road_elevation(seg_cz)

		var st_road := MeshInstance3D.new()
		var sr_box := BoxMesh.new()
		sr_box.size = Vector3(8.6, 0.14, 10.35)
		sr_box.material = asphalt_mat
		st_road.mesh = sr_box
		st_road.position = Vector3(base_x, seg_y - 0.078, seg_cz)
		parent.add_child(st_road)

		# Solid floor under straight mouth so approaching vehicles remain grounded
		if seg_i < 5:
			var st_floor := StaticBody3D.new()
			st_floor.name = "StationFloor"
			st_floor.add_to_group("road")
			st_floor.position = Vector3(base_x, seg_y - 0.11, seg_cz)
			var sf_col := CollisionShape3D.new()
			var sf_box := BoxShape3D.new()
			sf_box.size = Vector3(14.0, 0.22, 10.4)
			sf_col.shape = sf_box
			st_floor.add_child(sf_col)
			parent.add_child(st_floor)

		# Left outer shoulder (and right shoulder past the gore separation)
		for side in [-1.0, 1.0]:
			if side > 0.0 and seg_cz > z_junc - sep_dz * 0.78:
				continue
			var sh := MeshInstance3D.new()
			var sh_box := BoxMesh.new()
			sh_box.size = Vector3(3.8, 0.11, 10.35)
			sh_box.material = shoulder_mat
			sh.mesh = sh_box
			sh.position = Vector3(base_x + side * 6.2, seg_y - 0.088, seg_cz)
			parent.add_child(sh)

			# Outer fences along straight continuation (skip right side until past fork)
			if not (side > 0.0 and seg_cz > z_junc - sep_dz):
				var rail := MeshInstance3D.new()
				var rl_box := BoxMesh.new()
				rl_box.size = Vector3(0.18, 0.65, 10.35)
				rl_box.material = fence_mat
				rail.mesh = rl_box
				rail.position = Vector3(base_x + side * 6.2, seg_y + 0.45, seg_cz)
				parent.add_child(rail)

		# Dashed center line & white edge lines on straight continuation
		var dash := MeshInstance3D.new()
		var d_box := BoxMesh.new()
		d_box.size = Vector3(0.18, 0.008, 4.0)
		d_box.material = dash_mat
		dash.mesh = d_box
		dash.position = Vector3(base_x, seg_y + 0.006, seg_cz)
		parent.add_child(dash)

		for side in [-1.0, 1.0]:
			if side > 0.0 and seg_cz > z_junc - sep_dz:
				continue
			var edge := MeshInstance3D.new()
			var e_box := BoxMesh.new()
			e_box.size = Vector3(0.14, 0.008, 10.35)
			e_box.material = edge_mat
			edge.mesh = e_box
			edge.position = Vector3(base_x + side * 4.1, seg_y + 0.006, seg_cz)
			parent.add_child(edge)

	# 3. Seamless Junction Asphalt Apron & Gore Chevron Nose bridging straight & right branch
	for frac in [0.18, 0.42, 0.68, 0.92]:
		var z_slice: float = z_junc - sep_dz * float(frac)
		var rcx := _get_road_center_x(z_slice)
		var sy := _get_road_elevation(z_slice)
		var span_min := base_x - 4.0
		var span_max := rcx + 4.0
		var apron := MeshInstance3D.new()
		var ap_box := BoxMesh.new()
		ap_box.size = Vector3(maxf(8.6, span_max - span_min), 0.13, sep_dz * 0.34)
		ap_box.material = asphalt_mat
		apron.mesh = ap_box
		apron.position = Vector3((span_min + span_max) * 0.5, sy - 0.076, z_slice)
		parent.add_child(apron)

	# Painted white V-gore chevron stripes in the split wedge between straight road and right turn
	for g_idx in range(4):
		var gz := z_junc - sep_dz * 0.65 - float(g_idx) * (sep_dz * 0.085)
		var gx := base_x + 2.2 + float(g_idx) * 0.68
		var stripe := MeshInstance3D.new()
		var st_box := BoxMesh.new()
		st_box.size = Vector3(1.1 + float(g_idx) * 0.35, 0.01, 0.30)
		st_box.material = edge_mat
		stripe.mesh = st_box
		stripe.position = Vector3(gx, _get_road_elevation(gz) + 0.014, gz)
		stripe.rotation_degrees = Vector3(0.0, -28.0, 0.0)
		parent.add_child(stripe)

	# Glowing Yellow/Black Right-Turn Chevron Signboard planted cleanly on the gore island
	var chev_node := Node3D.new()
	var chev_z := z_junc - sep_dz * 0.98
	chev_node.position = Vector3(base_x + 4.8, _get_road_elevation(chev_z), chev_z)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.25, 0.27, 0.30)
	post_mat.metallic = 0.7
	var c_post := MeshInstance3D.new()
	var cp_cyl := CylinderMesh.new()
	cp_cyl.top_radius = 0.08
	cp_cyl.bottom_radius = 0.09
	cp_cyl.height = 2.4
	cp_cyl.material = post_mat
	c_post.mesh = cp_cyl
	c_post.position.y = 1.2
	chev_node.add_child(c_post)

	var c_board := MeshInstance3D.new()
	var cb_box := BoxMesh.new()
	cb_box.size = Vector3(2.4, 1.0, 0.12)
	var cb_mat := StandardMaterial3D.new()
	cb_mat.albedo_color = Color(0.95, 0.72, 0.05)
	cb_mat.emission_enabled = true
	cb_mat.emission = Color(0.95, 0.72, 0.05)
	cb_mat.emission_energy_multiplier = 0.6
	cb_box.material = cb_mat
	c_board.mesh = cb_box
	c_board.position.y = 2.2
	chev_node.add_child(c_board)

	var c_lbl := Label3D.new()
	c_lbl.text = ">>> BELOK KANAN >>>"
	c_lbl.font_size = 24
	c_lbl.modulate = Color(0.08, 0.08, 0.08)
	c_lbl.position = Vector3(0.0, 2.2, 0.08)
	chev_node.add_child(c_lbl)
	parent.add_child(chev_node)

	# 4. Distant Streetlights & Road-Closed Hazard Barricades down unintended straight road
	var lamp_pole_mat := StandardMaterial3D.new()
	lamp_pole_mat.albedo_color = Color(0.2, 0.22, 0.25)
	var lamp_bulb_mat := StandardMaterial3D.new()
	lamp_bulb_mat.albedo_color = Color(1.0, 0.88, 0.65)
	lamp_bulb_mat.emission_enabled = true
	lamp_bulb_mat.emission = Color(1.0, 0.88, 0.65)
	lamp_bulb_mat.emission_energy_multiplier = 4.0

	for l_z_off in [34.0, 68.0]:
		var lz: float = z_junc - float(l_z_off)
		var ly := _get_road_elevation(lz)
		var sl := Node3D.new()
		sl.position = Vector3(base_x - 6.8, ly, lz)
		var p_m := MeshInstance3D.new()
		var pm_c := CylinderMesh.new()
		pm_c.top_radius = 0.09
		pm_c.bottom_radius = 0.13
		pm_c.height = 6.2
		pm_c.material = lamp_pole_mat
		p_m.mesh = pm_c
		p_m.position.y = 3.1
		sl.add_child(p_m)
		var b_m := MeshInstance3D.new()
		var bm_b := BoxMesh.new()
		bm_b.size = Vector3(0.45, 0.14, 0.3)
		b_m.mesh = bm_b
		b_m.material_override = lamp_bulb_mat
		b_m.position = Vector3(1.8, 6.0, 0.0)
		sl.add_child(b_m)
		parent.add_child(sl)

	var bz := z_junc - sep_dz * 0.84
	for b_idx in range(4):
		var barrier := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(1.55, 0.95, 0.35)
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.92, 0.42, 0.08) if (b_idx % 2 == 0) else Color(0.95, 0.95, 0.95)
		b_box.material = b_mat
		barrier.mesh = b_box
		barrier.position = Vector3(base_x - 3.6 + b_idx * 1.65, _get_road_elevation(bz) + 0.47, bz)
		parent.add_child(barrier)

	var warn_light := OmniLight3D.new()
	warn_light.light_color = Color(1.0, 0.5, 0.1)
	warn_light.light_energy = 3.6
	warn_light.omni_range = 14.0
	warn_light.position = Vector3(base_x - 1.2, _get_road_elevation(bz) + 1.4, bz)
	parent.add_child(warn_light)

	# 5. Seamless Continuous Curved Invisible Funnel Wall (Zero box seams or corner snags)
	var funnel_pts: Array[Vector3] = []
	var seg_count := 16
	var funnel_z_start := z_junc + 12.0
	var funnel_z_end := z_junc - sep_dz - 8.0
	for s_i in range(seg_count + 1):
		var frac := float(s_i) / float(seg_count)
		var pz := lerpf(funnel_z_start, funnel_z_end, frac)
		var px := _get_road_center_x(pz) - 5.1
		var py := _get_road_elevation(pz)
		funnel_pts.append(Vector3(px, py, pz))

	var faces := PackedVector3Array()
	for i in range(funnel_pts.size() - 1):
		var a := funnel_pts[i]
		var b := funnel_pts[i + 1]
		var a_bot := Vector3(a.x, a.y - 1.0, a.z)
		var a_top := Vector3(a.x, a.y + 4.0, a.z)
		var b_bot := Vector3(b.x, b.y - 1.0, b.z)
		var b_top := Vector3(b.x, b.y + 4.0, b.z)
		faces.append_array(PackedVector3Array([a_bot, b_bot, b_top, a_bot, b_top, a_top]))

	# Seamless backstop wing closing off the unintended straight road behind the barricades
	var wing_z := z_junc - sep_dz
	var wing_y := _get_road_elevation(wing_z)
	var w_right := Vector3(_get_road_center_x(wing_z) - 5.1, wing_y, wing_z)
	var w_left := Vector3(base_x - 8.5, wing_y, wing_z)
	faces.append_array(PackedVector3Array([
		Vector3(w_left.x, w_left.y - 1.0, w_left.z),
		Vector3(w_right.x, w_right.y - 1.0, w_right.z),
		Vector3(w_right.x, w_right.y + 4.0, w_right.z),
		Vector3(w_left.x, w_left.y - 1.0, w_left.z),
		Vector3(w_right.x, w_right.y + 4.0, w_right.z),
		Vector3(w_left.x, w_left.y + 4.0, w_left.z)
	]))

	var funnel_shape := ConcavePolygonShape3D.new()
	funnel_shape.backface_collision = true
	funnel_shape.set_faces(faces)
	var funnel_body := StaticBody3D.new()
	funnel_body.name = "InvisibleFunnelWall_%d" % int(absf(z_junc))
	funnel_body.add_to_group("invisible_walls")
	var funnel_col := CollisionShape3D.new()
	funnel_col.shape = funnel_shape
	funnel_body.add_child(funnel_col)
	parent.add_child(funnel_body)


func _create_highway_gantry(pos: Vector3, text: String) -> Node3D:
	var gantry := Node3D.new()
	gantry.position = pos

	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.25, 0.28, 0.32)
	metal_mat.metallic = 0.85

	for x_p in [-5.8, 5.8]:
		var col := MeshInstance3D.new()
		var col_box := BoxMesh.new()
		col_box.size = Vector3(0.4, 7.8, 0.4)
		col_box.material = metal_mat
		col.mesh = col_box
		col.position = Vector3(x_p, 3.9, 0.0)
		gantry.add_child(col)

	var beam := MeshInstance3D.new()
	var beam_box := BoxMesh.new()
	beam_box.size = Vector3(12.2, 0.45, 0.45)
	beam_box.material = metal_mat
	beam.mesh = beam_box
	beam.position = Vector3(0.0, 7.4, 0.0)
	gantry.add_child(beam)

	var sign_board := MeshInstance3D.new()
	var s_mesh := BoxMesh.new()
	s_mesh.size = Vector3(7.2, 1.5, 0.12)
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.05, 0.24, 0.14)  # Malaysian JKR Green Signage
	s_mesh.material = sign_mat
	sign_board.mesh = s_mesh
	sign_board.position = Vector3(0.0, 6.2, 0.0)
	gantry.add_child(sign_board)

	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.modulate = Color(0.96, 0.96, 0.96)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 6.2, 0.07)
	gantry.add_child(label)

	var amber := OmniLight3D.new()
	amber.light_color = Color(1.0, 0.75, 0.2)
	amber.light_energy = 3.8
	amber.omni_range = 16.0
	amber.position = Vector3(0.0, 5.3, 0.0)
	gantry.add_child(amber)

	return gantry


# --- Beach Road Ocean Landscape ---
func _setup_beach_ocean() -> void:
	var beach_group := Node3D.new()
	beach_group.name = "BeachOcean"
	highway_root.add_child(beach_group)

	# Ocean Water Plane spanning along the right side of the Beach Road (Z = -1920m to -2480m)
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(280.0, 600.0)
	var ocean_mat := StandardMaterial3D.new()
	ocean_mat.albedo_color = Color(0.02, 0.06, 0.12)
	ocean_mat.metallic = 0.94
	ocean_mat.roughness = 0.1
	ocean_mesh.material = ocean_mat

	var ocean_inst := MeshInstance3D.new()
	ocean_inst.mesh = ocean_mesh
	ocean_inst.position = Vector3(145.0, -1.2, -2200.0)
	beach_group.add_child(ocean_inst)

	# White Surf / Shoreline Sand
	var sand_mesh := PlaneMesh.new()
	sand_mesh.size = Vector2(36.0, 600.0)
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.35, 0.30, 0.22)
	sand_mat.roughness = 0.98
	sand_mesh.material = sand_mat

	var sand_inst := MeshInstance3D.new()
	sand_inst.mesh = sand_mesh
	sand_inst.position = Vector3(58.0, -0.9, -2200.0)
	beach_group.add_child(sand_inst)


# --- Final Destination: Kandiez Sunrise Beach Resort (Pantai Kandis, Bachok) ---
func _setup_kandiez_beach_resort() -> void:
	var resort_group := Node3D.new()
	resort_group.name = "KandiezSunriseBeachResort"
	var r_z: float = CP_RESORT_ARRIVAL_Z
	resort_group.position = Vector3(_get_road_center_x(r_z), _get_road_elevation(r_z), r_z)
	highway_root.add_child(resort_group)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.28, 0.18, 0.11)
	wood_mat.roughness = 0.88

	var chalet_wall_mat := StandardMaterial3D.new()
	chalet_wall_mat.albedo_color = Color(0.38, 0.26, 0.18)

	var chalet_roof_mat := StandardMaterial3D.new()
	chalet_roof_mat.albedo_color = Color(0.18, 0.12, 0.08)

	var warm_bulb_mat := StandardMaterial3D.new()
	warm_bulb_mat.albedo_color = Color(1.0, 0.82, 0.35)
	warm_bulb_mat.emission_enabled = true
	warm_bulb_mat.emission = Color(1.0, 0.82, 0.35)
	warm_bulb_mat.emission_energy_multiplier = 4.0

	# 1. Rustic Timber Entrance Gateway
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var p_cyl := CylinderMesh.new()
		p_cyl.top_radius = 0.3
		p_cyl.bottom_radius = 0.35
		p_cyl.height = 5.8
		p_cyl.material = wood_mat
		post.mesh = p_cyl
		post.position = Vector3(side * 5.4, 2.9, 0.0)
		resort_group.add_child(post)

		# Top post lantern
		var lantern := OmniLight3D.new()
		lantern.light_color = Color(1.0, 0.78, 0.4)
		lantern.light_energy = 3.8
		lantern.omni_range = 16.0
		lantern.position = Vector3(side * 5.4, 6.0, 0.0)
		resort_group.add_child(lantern)

	# Timber Crossbeam
	var beam := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(12.0, 0.55, 0.55)
	b_box.material = wood_mat
	beam.mesh = b_box
	beam.position = Vector3(0.0, 5.4, 0.0)
	resort_group.add_child(beam)

	# Carved Resort Name Signboard
	var sign_board := MeshInstance3D.new()
	var sb_box := BoxMesh.new()
	sb_box.size = Vector3(9.2, 1.8, 0.15)
	var sb_mat := StandardMaterial3D.new()
	sb_mat.albedo_color = Color(0.14, 0.09, 0.05)
	sb_box.material = sb_mat
	sign_board.mesh = sb_box
	sign_board.position = Vector3(0.0, 6.3, 0.0)
	resort_group.add_child(sign_board)

	var label := Label3D.new()
	label.text = "✦ KANDIEZ SUNRISE BEACH RESORT ✦\nLOT 2129, KG. TOK KEDERAT, PANTAI KANDIS, BACHOK\nCHALET & VILLA TEPI PANTAI • TEL: 013-4397892"
	label.font_size = 20
	label.modulate = Color(1.0, 0.9, 0.6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 6.3, 0.09)
	resort_group.add_child(label)

	# Hanging String Fairy Festoon Lights
	for f_i in range(8):
		var fx: float = lerpf(-4.8, 4.8, float(f_i) / 7.0)
		var fy: float = 4.8 - sin(float(f_i) / 7.0 * PI) * 0.75
		var bulb := MeshInstance3D.new()
		var b_sph := SphereMesh.new()
		b_sph.radius = 0.12
		b_sph.height = 0.22
		bulb.mesh = b_sph
		bulb.material_override = warm_bulb_mat
		bulb.position = Vector3(fx, fy, 0.0)
		resort_group.add_child(bulb)

	var string_glow := OmniLight3D.new()
	string_glow.light_color = Color(1.0, 0.8, 0.4)
	string_glow.light_energy = 4.5
	string_glow.omni_range = 22.0
	string_glow.position = Vector3(0.0, 4.5, -2.0)
	resort_group.add_child(string_glow)

	# 2. Resort Chalets & Villas on BOTH Right (Beachfront) and Left (Inland) Sides of the Road
	for side_dir in [1.0, -1.0]:
		var chalet_count: int = 3 if side_dir > 0.0 else 2
		for ch_i in range(chalet_count):
			var ch_node := Node3D.new()
			var ch_x: float = side_dir * (13.5 + float(ch_i) * 8.0)
			var ch_z: float = -12.0 - float(ch_i) * 16.0
			ch_node.position = Vector3(ch_x, 0.0, ch_z)

			# Elevated Wooden Stilt Deck
			var deck := MeshInstance3D.new()
			var d_box := BoxMesh.new()
			d_box.size = Vector3(8.5, 0.8, 7.5)
			d_box.material = wood_mat
			deck.mesh = d_box
			deck.position = Vector3(0.0, 0.4, 0.0)
			ch_node.add_child(deck)

			# Chalet Cabin Walls
			var cabin := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(7.2, 3.4, 6.0)
			c_box.material = chalet_wall_mat
			cabin.mesh = c_box
			cabin.position = Vector3(0.0, 2.4, 0.0)
			ch_node.add_child(cabin)

			# High-Pitched A-Frame Roof
			var roof := MeshInstance3D.new()
			var r_box := BoxMesh.new()
			r_box.size = Vector3(8.0, 1.8, 6.8)
			r_box.material = chalet_roof_mat
			roof.mesh = r_box
			roof.position = Vector3(0.0, 4.8, 0.0)
			ch_node.add_child(roof)

			# Porch Light facing the road
			var p_light := OmniLight3D.new()
			p_light.light_color = Color(1.0, 0.85, 0.5)
			p_light.light_energy = 2.8
			p_light.omni_range = 10.0
			p_light.position = Vector3(-side_dir * 3.2, 2.5, 0.0)
			ch_node.add_child(p_light)

			resort_group.add_child(ch_node)

	# 3. Beach Loungers & Thatched Umbrellas on Sand
	for u_i in range(2):
		var umb := Node3D.new()
		umb.position = Vector3(32.0 + float(u_i) * 8.0, -0.6, -18.0 - float(u_i) * 14.0)

		var pole := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.06
		p_mesh.bottom_radius = 0.08
		p_mesh.height = 2.6
		p_mesh.material = wood_mat
		pole.mesh = p_mesh
		pole.position.y = 1.3
		umb.add_child(pole)

		var canopy := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.1
		c_mesh.bottom_radius = 1.8
		c_mesh.height = 0.7
		var thatch_mat := StandardMaterial3D.new()
		thatch_mat.albedo_color = Color(0.55, 0.48, 0.32)
		c_mesh.material = thatch_mat
		canopy.mesh = c_mesh
		canopy.position.y = 2.4
		umb.add_child(canopy)

		resort_group.add_child(umb)

	# 4. Father's 4x4 Truck Parked in the Resort Driveway
	var dad_truck := MeshInstance3D.new()
	var dt_mesh := BoxMesh.new()
	dt_mesh.size = Vector3(2.2, 1.8, 4.6)
	var dt_mat := StandardMaterial3D.new()
	dt_mat.albedo_color = Color(0.18, 0.22, 0.28)  # Metallic Navy Blue
	dt_mat.metallic = 0.8
	dt_mesh.material = dt_mat
	dad_truck.mesh = dt_mesh
	dad_truck.position = Vector3(-6.5, 0.9, -14.0)
	dad_truck.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	resort_group.add_child(dad_truck)

	# 5. Dad Figure on the Chalet Porch
	var dad_fig := Node3D.new()
	dad_fig.position = Vector3(10.5, 0.8, -12.0)
	var body := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.6, 1.4, 0.4)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.2, 0.3, 0.45)
	b_mesh.material = b_mat
	body.mesh = b_mesh
	body.position.y = 0.7
	dad_fig.add_child(body)

	var head := MeshInstance3D.new()
	var h_mesh := SphereMesh.new()
	h_mesh.radius = 0.22
	h_mesh.height = 0.44
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.85, 0.7, 0.55)
	head.mesh = h_mesh
	head.material_override = h_mat
	head.position.y = 1.6
	dad_fig.add_child(head)

	resort_group.add_child(dad_fig)


# --- Streetlights & Environment Decorations ---
func _setup_streetlights() -> void:
	lamps_root = Node3D.new()
	lamps_root.name = "Streetlights"
	add_child(lamps_root)

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.22, 0.25)
	pole_mat.metallic = 0.85

	var lamp_bulb_mat := StandardMaterial3D.new()
	lamp_bulb_mat.albedo_color = Color(1.0, 0.9, 0.7)
	lamp_bulb_mat.emission_enabled = true
	lamp_bulb_mat.emission = Color(1.0, 0.9, 0.7)
	lamp_bulb_mat.emission_energy_multiplier = 5.0

	var z_pos: float = 30.0
	var lamp_index: int = 0

	while z_pos > -HIGHWAY_LENGTH + 40.0:
		var cx := _get_road_center_x(z_pos)
		var y_elev := _get_road_elevation(z_pos)
		var side: float = 1.0 if (lamp_index % 2 == 0) else -1.0
		var lamp := Node3D.new()
		lamp.position = Vector3(cx + side * 6.8, y_elev, z_pos)

		var pole := MeshInstance3D.new()
		var p_cyl := CylinderMesh.new()
		p_cyl.top_radius = 0.09
		p_cyl.bottom_radius = 0.14
		p_cyl.height = 6.5
		p_cyl.material = pole_mat
		pole.mesh = p_cyl
		pole.position.y = 3.25
		lamp.add_child(pole)

		var arm := MeshInstance3D.new()
		var a_box := BoxMesh.new()
		a_box.size = Vector3(2.2, 0.08, 0.08)
		a_box.material = pole_mat
		arm.mesh = a_box
		arm.position = Vector3(-side * 1.1, 6.4, 0.0)
		lamp.add_child(arm)

		var bulb := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.4, 0.12, 0.28)
		bulb.mesh = b_box
		bulb.material_override = lamp_bulb_mat
		bulb.position = Vector3(-side * 2.2, 6.32, 0.0)
		lamp.add_child(bulb)

		var light := SpotLight3D.new()
		light.light_color = Color(1.0, 0.88, 0.65)
		light.light_energy = 5.5
		light.spot_range = 28.0
		light.spot_angle = 55.0
		light.spot_attenuation = 0.65
		light.shadow_enabled = true
		light.position = Vector3(-side * 2.2, 6.2, 0.0)
		light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		lamp.add_child(light)

		var wide_glow := OmniLight3D.new()
		wide_glow.light_color = Color(1.0, 0.85, 0.62)
		wide_glow.light_energy = 3.2
		wide_glow.omni_range = 30.0
		wide_glow.position = Vector3(-side * 2.2, 5.8, 0.0)
		lamp.add_child(wide_glow)

		lamps_root.add_child(lamp)
		z_pos -= LAMP_INTERVAL
		lamp_index += 1


func _setup_environment_decorations() -> void:
	trees_root = Node3D.new()
	trees_root.name = "TreesAndFoliage"
	add_child(trees_root)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.12, 0.08, 0.05)

	var pine_foliage := StandardMaterial3D.new()
	pine_foliage.albedo_color = Color(0.02, 0.05, 0.025)

	var palm_foliage := StandardMaterial3D.new()
	palm_foliage.albedo_color = Color(0.04, 0.12, 0.04)

	var z_pos: float = 40.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 998877

	while z_pos > -HIGHWAY_LENGTH + 40.0:
		# Don't spawn trees on the Tok Bali water estuary bridge
		if z_pos <= -950.0 and z_pos >= -1250.0:
			z_pos -= 16.0
			continue

		var cx := _get_road_center_x(z_pos)
		var y_elev := _get_road_elevation(z_pos)
		var is_coastal := (z_pos <= -1900.0)
		var is_country := (z_pos <= -750.0 and not is_coastal)

		for side in [-1.0, 1.0]:
			# Keep Masjid compound front & side clear of overlapping trees
			if side < 0.0 and z_pos <= -692.0 and z_pos >= -748.0:
				continue
			# Keep straight-ahead junction continuation roads clear of trees
			if side < 0.0 and ((z_pos <= -1588.0 and z_pos >= -1705.0) or (z_pos <= -1938.0 and z_pos >= -2055.0)):
				continue
			# On beach road, only spawn palms on the inland side (left side) so beach is open
			if is_coastal and side > 0.0:
				continue

			var x_dist: float = cx + side * rng.randf_range(8.5, 32.0)
			var tree: Node3D = null

			if is_coastal or (is_country and rng.randf() < 0.6):
				tree = _create_palm_tree(rng.randf_range(6.0, 9.5), trunk_mat, palm_foliage)
			else:
				tree = _create_pine_tree(rng.randf_range(5.5, 9.5), trunk_mat, pine_foliage)

			tree.position = Vector3(x_dist, y_elev, z_pos + rng.randf_range(-3.0, 3.0))
			tree.rotation.y = rng.randf_range(0.0, TAU)
			trees_root.add_child(tree)

		z_pos -= rng.randf_range(10.0, 18.0)


func _create_pine_tree(height: float, trunk_mat: Material, foliage_mat: Material) -> Node3D:
	var tree := Node3D.new()
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.26
	cyl.height = height * 0.35
	cyl.material = trunk_mat
	trunk.mesh = cyl
	trunk.position.y = cyl.height * 0.5
	tree.add_child(trunk)

	for i in range(3):
		var cone := MeshInstance3D.new()
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = (3 - i) * 0.55 + 0.4
		cone_mesh.height = height * 0.38
		cone_mesh.material = foliage_mat
		cone.mesh = cone_mesh
		cone.position.y = (trunk.position.y * 1.2) + (i * height * 0.22)
		tree.add_child(cone)

	return tree


func _create_palm_tree(height: float, trunk_mat: Material, foliage_mat: Material) -> Node3D:
	var tree := Node3D.new()
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.22
	cyl.height = height
	cyl.material = trunk_mat
	trunk.mesh = cyl
	trunk.position.y = height * 0.5
	trunk.rotation_degrees.z = 6.0  # Characteristic gentle tropical tilt
	tree.add_child(trunk)

	# Palm Fronds Crown
	for f in range(6):
		var frond := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.35, 0.05, 2.8)
		f_box.material = foliage_mat
		frond.mesh = f_box
		frond.position = Vector3(0.0, height, 0.0)
		frond.rotation_degrees = Vector3(25.0, f * 60.0, 0.0)
		tree.add_child(frond)

	return tree


# --- Cars Setup (Solo Lone Driver vs Coop Squad - Strictly No AI) ---
func _setup_cars() -> void:
	car_container = Node3D.new()
	car_container.name = "Cars"
	add_child(car_container)

	var net := get_node_or_null("/root/NetworkManager")
	var is_solo: bool = _is_solo_mode()

	if is_solo:
		# --- SOLO CAMPAIGN: Exactly 1 Lone Car (No AI cars) ---
		var host_name := "Player"
		if net and not net.local_player_name.is_empty():
			host_name = net.local_player_name

		var car = STORY_CAR_SCRIPT.new()
		car.name = "StoryCar_1"
		car.sibling_id = 1
		car.sibling_name = host_name
		car.character_name = "Syazril"
		car.is_host = true
		car.car_layer_index = 1
		car.paint_color = Color(0.14, 0.12, 0.15) # Deep Obsidian Charcoal
		car.is_ai = false

		# Malaysian Left-Hand Traffic: Drive in left lane (-2.1m)
		var start_lane: float = -2.1
		var start_z: float = 25.0
		var road_cx := _get_road_center_x(start_z)
		car.position = Vector3(road_cx + start_lane, _get_road_elevation(start_z) + 0.04, start_z)

		car.car_crashed.connect(_on_car_crashed)

		car_container.add_child(car)
		cars.append(car)
		player_car = car
		print("StoryDrive: Solo Campaign mode active - 1 lone car spawned in left lane (no AI).")
	else:
		# --- CO-OP STORY: Strictly Human Cars with Network Authority ---
		var palette: Array[Color] = [
			Color(0.14, 0.12, 0.15), # Car 1 (Host): Charcoal
			Color(0.08, 0.16, 0.28), # Car 2: Navy
			Color(0.28, 0.14, 0.06), # Car 3: Amber Bronze
			Color(0.07, 0.22, 0.12)  # Car 4: Emerald
		]

		var p_ids: Array = net.players.keys()
		# Deterministic sorting: Host (pid=1) is ALWAYS car 0 on all peers
		p_ids.sort_custom(func(a: int, b: int) -> bool: 
			if a == 1: return true
			if b == 1: return false
			return a < b
		)
		var my_id := multiplayer.get_unique_id()

		var fallback_chars: Array[String] = ["Syazril", "Syahirul", "Aleysa", "Amelya"]
		for i in range(min(p_ids.size(), 4)):
			var pid: int = p_ids[i]
			var p_info: Dictionary = net.players.get(pid, {})
			var p_name: String = str(p_info.get("name", "Player %d" % pid))
			var p_char: String = str(p_info.get("character", ""))
			if p_char.is_empty() or p_char == "random":
				p_char = fallback_chars[i % fallback_chars.size()]

			var car = STORY_CAR_SCRIPT.new()
			car.name = "StoryCar_%d" % pid
			car.sibling_id = pid
			car.sibling_name = ("%s (%s)" % [p_name, p_char]) if not p_char.is_empty() else p_name
			car.character_name = p_char
			car.set_meta("character_name", p_char)
			car.is_host = (pid == 1)
			car.car_layer_index = 1 + i
			car.paint_color = palette[i % palette.size()]
			car.is_ai = false # Strictly human player, no bots!
			car.set_multiplayer_authority(pid)

			# Malaysian Left-Hand Traffic: All cars travel in left lane (-2.1m) in single file convoy
			var start_lane: float = -2.1 + (0.10 if (i % 2 == 1) else -0.10)
			var start_z: float = 25.0 + (i * 12.0)
			var road_cx := _get_road_center_x(start_z)
			car.position = Vector3(road_cx + start_lane, _get_road_elevation(start_z) + 0.04, start_z)

			car.car_crashed.connect(_on_car_crashed)

			car_container.add_child(car)
			car.apply_character_visuals(p_char, car.paint_color, car.sibling_name)
			cars.append(car)

			if pid == my_id or (i == 0 and player_car == null):
				player_car = car

		print("StoryDrive: Co-op Story mode active - %d human cars spawned (no AI bots)." % cars.size())


func spawn_test_peer_car(offset_x: float = 1.75, offset_z: float = -6.0, char_name: String = "Syahirul") -> CharacterBody3D:
	if not car_container or not player_car:
		return null
	var car = STORY_CAR_SCRIPT.new()
	car.name = "StoryCar_TestPeer_%s" % char_name
	car.sibling_id = 2
	car.sibling_name = char_name
	car.character_name = char_name
	car.set_meta("character_name", char_name)
	car.car_layer_index = 2
	car.is_ai = false
	car.is_host = false
	car.position = player_car.position + Vector3(offset_x, 0.0, offset_z)
	car.current_speed = player_car.current_speed
	car.car_crashed.connect(_on_car_crashed)
	car_container.add_child(car)
	car.apply_character_visuals(char_name)
	cars.append(car)
	return car


# --- HUD, Cinematic Letterbox, Timer & Speedometer ---
func _setup_hud() -> void:
	drive_canvas = CanvasLayer.new()
	drive_canvas.layer = 95
	add_child(drive_canvas)

	# 1. Letterbox Bars
	top_bar = ColorRect.new()
	top_bar.color = Color(0.0, 0.0, 0.0, 1.0)
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.10
	drive_canvas.add_child(top_bar)

	bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0.0, 0.0, 0.0, 1.0)
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 0.90
	bottom_bar.anchor_bottom = 1.0
	drive_canvas.add_child(bottom_bar)

	# 2. Time Stamp
	time_stamp_label = Label.new()
	time_stamp_label.text = "LALUAN 189 • 11:42 PM"
	time_stamp_label.add_theme_font_size_override("font_size", 13)
	time_stamp_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85, 0.85))
	time_stamp_label.offset_left = 32.0
	time_stamp_label.offset_top = 18.0
	drive_canvas.add_child(time_stamp_label)

	# 3. Cinematic Subtitles
	subtitle_label = Label.new()
	subtitle_label.text = ""
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.95))
	subtitle_label.anchor_left = 0.1
	subtitle_label.anchor_right = 0.9
	subtitle_label.anchor_top = 0.84
	subtitle_label.anchor_bottom = 0.90
	drive_canvas.add_child(subtitle_label)

	# 4. Skip Indicator
	var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
	skip_label = Label.new()
	skip_label.text = "TAP TO SKIP" if is_mobile else "HOLD [SPACE] TO SKIP"
	skip_label.add_theme_font_size_override("font_size", 11)
	skip_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.65))
	skip_label.anchor_left = 1.0
	skip_label.anchor_top = 1.0
	skip_label.anchor_right = 1.0
	skip_label.anchor_bottom = 1.0
	skip_label.offset_left = -160.0
	skip_label.offset_top = -32.0
	drive_canvas.add_child(skip_label)

	skip_bar = ProgressBar.new()
	skip_bar.show_percentage = false
	skip_bar.anchor_left = 1.0
	skip_bar.anchor_top = 1.0
	skip_bar.anchor_right = 1.0
	skip_bar.anchor_bottom = 1.0
	skip_bar.offset_left = -160.0
	skip_bar.offset_top = -12.0
	skip_bar.offset_right = -20.0
	skip_bar.offset_bottom = -8.0
	skip_bar.visible = false
	drive_canvas.add_child(skip_bar)

	# 5. Tutorial Card
	tutorial_card = PanelContainer.new()
	tutorial_card.anchor_left = 0.5
	tutorial_card.anchor_right = 0.5
	tutorial_card.anchor_top = 0.05
	tutorial_card.anchor_bottom = 0.05
	tutorial_card.offset_left = -260.0
	tutorial_card.offset_right = 260.0
	tutorial_card.offset_bottom = 54.0
	tutorial_card.visible = false

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	card_style.border_color = Color(0.25, 0.35, 0.48, 0.8)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_top = 8.0
	card_style.content_margin_bottom = 8.0
	tutorial_card.add_theme_stylebox_override("panel", card_style)

	tutorial_label = Label.new()
	if is_mobile:
		tutorial_label.text = "TAKE THE WHEEL!\n[◀ / ▶] Steer (Heavier)  •  [BRAKE] Slow  •  [⚡ BOOST] (HOLD) to 140 KM/H\n(Auto-Throttle: Vehicle slowly crawls up to 100 KM/H)"
	else:
		tutorial_label.text = "TAKE THE WHEEL!\n[A / D] Steer (Heavier)  •  [S / DOWN] Brake  •  [SPACE] (HOLD) Boost to 140 KM/H\n(Auto-Throttle: Vehicle slowly crawls up to 100 KM/H)"
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 12)
	tutorial_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	tutorial_card.add_child(tutorial_label)
	drive_canvas.add_child(tutorial_card)

	# 6. Highway Phase 1 Timer Card (Top Center)
	timer_container = PanelContainer.new()
	timer_container.anchor_left = 0.5
	timer_container.anchor_right = 0.5
	timer_container.anchor_top = 0.02
	timer_container.anchor_bottom = 0.02
	timer_container.offset_left = -170.0
	timer_container.offset_right = 170.0
	timer_container.offset_bottom = 36.0
	timer_container.visible = false

	var timer_style := StyleBoxFlat.new()
	timer_style.bg_color = Color(0.04, 0.06, 0.09, 0.88)
	timer_style.border_color = Color(0.85, 0.65, 0.2, 0.85)
	timer_style.set_border_width_all(1)
	timer_style.set_corner_radius_all(6)
	timer_container.add_theme_stylebox_override("panel", timer_style)

	timer_label = Label.new()
	timer_label.text = "⏱️ TOK BALI TURN-OFF: 00:30"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 13)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	timer_container.add_child(timer_label)
	drive_canvas.add_child(timer_container)

	# 7. Speedometer (Bottom Right)
	speedo_container = PanelContainer.new()
	speedo_container.anchor_left = 1.0
	speedo_container.anchor_top = 1.0
	speedo_container.anchor_right = 1.0
	speedo_container.anchor_bottom = 1.0
	speedo_container.offset_left = -135.0
	speedo_container.offset_top = -80.0
	speedo_container.offset_right = -24.0
	speedo_container.offset_bottom = -24.0
	speedo_container.visible = false

	var speedo_style := StyleBoxFlat.new()
	speedo_style.bg_color = Color(0.05, 0.07, 0.10, 0.82)
	speedo_style.border_color = Color(0.25, 0.4, 0.55, 0.6)
	speedo_style.set_border_width_all(1)
	speedo_style.set_corner_radius_all(6)
	speedo_container.add_theme_stylebox_override("panel", speedo_style)

	speedo_label = Label.new()
	speedo_label.text = "0\nKM/H"
	speedo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speedo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speedo_label.add_theme_font_size_override("font_size", 16)
	speedo_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.65))
	speedo_container.add_child(speedo_label)
	drive_canvas.add_child(speedo_container)

	# 8. Dedicated Boost Button
	boost_button = Button.new()
	boost_button.anchor_left = 1.0
	boost_button.anchor_top = 1.0
	boost_button.anchor_right = 1.0
	boost_button.anchor_bottom = 1.0
	boost_button.offset_left = -315.0
	boost_button.offset_top = -80.0
	boost_button.offset_right = -148.0
	boost_button.offset_bottom = -24.0
	boost_button.visible = false

	var boost_style := StyleBoxFlat.new()
	boost_style.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	boost_style.border_color = Color(0.9, 0.75, 0.2, 0.9)
	boost_style.set_border_width_all(2)
	boost_style.set_corner_radius_all(8)
	boost_button.add_theme_stylebox_override("normal", boost_style)
	boost_button.add_theme_font_size_override("font_size", 13)
	boost_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	boost_button.text = "⚡ BOOST [HOLD]"
	boost_button.button_down.connect(func() -> void:
		if player_car:
			player_car.set("touch_boost", true)
	)
	boost_button.button_up.connect(func() -> void:
		if player_car:
			player_car.set("touch_boost", false)
	)
	drive_canvas.add_child(boost_button)

	# 9. Mobile Touch Controls
	if is_mobile:
		_setup_mobile_touch_controls()


func _setup_mobile_touch_controls() -> void:
	mobile_controls_box = Control.new()
	mobile_controls_box.anchor_left = 0.0
	mobile_controls_box.anchor_top = 0.0
	mobile_controls_box.anchor_right = 1.0
	mobile_controls_box.anchor_bottom = 1.0
	mobile_controls_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls_box.visible = false
	drive_canvas.add_child(mobile_controls_box)

	var btn_left := Button.new()
	btn_left.text = "◀"
	btn_left.anchor_left = 0.0
	btn_left.anchor_top = 1.0
	btn_left.offset_left = 28.0
	btn_left.offset_top = -120.0
	btn_left.offset_right = 105.0
	btn_left.offset_bottom = -45.0
	btn_left.button_down.connect(func() -> void: if player_car: player_car.set("touch_steer", -1.0))
	btn_left.button_up.connect(func() -> void: if player_car: player_car.set("touch_steer", 0.0))
	mobile_controls_box.add_child(btn_left)

	var btn_right := Button.new()
	btn_right.text = "▶"
	btn_right.anchor_left = 0.0
	btn_right.anchor_top = 1.0
	btn_right.offset_left = 120.0
	btn_right.offset_top = -120.0
	btn_right.offset_right = 197.0
	btn_right.offset_bottom = -45.0
	btn_right.button_down.connect(func() -> void: if player_car: player_car.set("touch_steer", 1.0))
	btn_right.button_up.connect(func() -> void: if player_car: player_car.set("touch_steer", 0.0))
	mobile_controls_box.add_child(btn_right)

	var btn_brake := Button.new()
	btn_brake.text = "🛑 BRAKE"
	btn_brake.anchor_left = 1.0
	btn_brake.anchor_top = 1.0
	btn_brake.offset_left = -235.0
	btn_brake.offset_top = -120.0
	btn_brake.offset_right = -140.0
	btn_brake.offset_bottom = -45.0
	btn_brake.button_down.connect(func() -> void: if player_car: player_car.set("touch_brake", 1.0))
	btn_brake.button_up.connect(func() -> void: if player_car: player_car.set("touch_brake", 0.0))
	mobile_controls_box.add_child(btn_brake)

	var btn_mobile_boost := Button.new()
	btn_mobile_boost.text = "⚡ BOOST (HOLD)"
	btn_mobile_boost.anchor_left = 1.0
	btn_mobile_boost.anchor_top = 1.0
	btn_mobile_boost.offset_left = -145.0
	btn_mobile_boost.offset_top = -125.0
	btn_mobile_boost.offset_right = -25.0
	btn_mobile_boost.offset_bottom = -45.0
	btn_mobile_boost.button_down.connect(func() -> void: if player_car: player_car.set("touch_boost", true))
	btn_mobile_boost.button_up.connect(func() -> void: if player_car: player_car.set("touch_boost", false))
	mobile_controls_box.add_child(btn_mobile_boost)


func _update_hud(delta: float) -> void:
	if not player_car or not is_instance_valid(player_car):
		return

	if speedo_label:
		var kmh := int(absf(float(player_car.get("current_speed"))) * 3.6)
		speedo_label.text = "%d\nKM/H" % kmh
		if bool(player_car.get("is_boosting")):
			speedo_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
		else:
			speedo_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.65))

	if boost_button:
		var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
		if bool(player_car.get("is_boosting")):
			boost_button.text = "⚡ BOOSTING (140 KM/H) ⚡"
			boost_button.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
		else:
			boost_button.text = "⚡ BOOST (HOLD)" if is_mobile else "⚡ BOOST [SPACE] (HOLD)"
			boost_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))

	if timer_label and is_timer_active:
		var secs := int(ceil(highway_timer))
		timer_label.text = "⏱️ TIME TO KUALA SEMERAK: 00:%02d" % secs


func _show_milestone_banner(title_text: String, sub_text: String) -> void:
	if not is_instance_valid(drive_canvas):
		return

	if checkpoint_card and is_instance_valid(checkpoint_card):
		checkpoint_card.queue_free()

	checkpoint_card = PanelContainer.new()
	checkpoint_card.anchor_left = 0.5
	checkpoint_card.anchor_right = 0.5
	checkpoint_card.anchor_top = 0.15
	checkpoint_card.anchor_bottom = 0.15
	checkpoint_card.offset_left = -260.0
	checkpoint_card.offset_right = 260.0
	checkpoint_card.offset_top = -40.0
	checkpoint_card.offset_bottom = 40.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.92)
	style.border_color = Color(0.85, 0.65, 0.22, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	checkpoint_card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = sub_text
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95, 0.85))
	vbox.add_child(sub)

	checkpoint_card.add_child(vbox)
	drive_canvas.add_child(checkpoint_card)

	# Fade out after 4.5 seconds
	var tween := create_tween()
	tween.tween_interval(4.5)
	tween.tween_property(checkpoint_card, "modulate:a", 0.0, 1.0)
	tween.tween_callback(checkpoint_card.queue_free)


func _show_subtitle(text: String, duration: float = 4.0) -> void:
	if not subtitle_label:
		return
	subtitle_label.text = text
	subtitle_label.visible = true
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		subtitle_label.text = ""
		subtitle_label.modulate.a = 1.0
	)


func _show_waiting_arrival_hud(arrived_count: int, total_count: int) -> void:
	if not is_instance_valid(drive_canvas):
		return
	if is_instance_valid(waiting_card):
		var lbl := waiting_card.find_child("WaitingLabel", true, false) as Label
		if lbl:
			lbl.text = "✦ ARRIVED AT KANDIEZ RESORT ✦\nWaiting for other players to arrive (%d / %d)..." % [arrived_count, total_count]
		return

	waiting_card = PanelContainer.new()
	waiting_card.anchor_left = 0.5
	waiting_card.anchor_right = 0.5
	waiting_card.anchor_top = 0.24
	waiting_card.anchor_bottom = 0.24
	waiting_card.offset_left = -250.0
	waiting_card.offset_right = 250.0
	waiting_card.offset_top = -36.0
	waiting_card.offset_bottom = 36.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.92)
	style.border_color = Color(0.95, 0.82, 0.35, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	waiting_card.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.name = "WaitingLabel"
	lbl.text = "✦ ARRIVED AT KANDIEZ RESORT ✦\nWaiting for other players to arrive (%d / %d)..." % [arrived_count, total_count]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	waiting_card.add_child(lbl)
	drive_canvas.add_child(waiting_card)


func _hide_waiting_arrival_hud() -> void:
	if is_instance_valid(waiting_card):
		waiting_card.queue_free()
		waiting_card = null


func _show_resort_arrival_hud() -> void:
	if not is_instance_valid(drive_canvas):
		return

	var net := get_node_or_null("/root/NetworkManager")
	var is_solo: bool = _is_solo_mode()
	var num_players: int = 1 if is_solo else (net.players.size() if net else 1)

	var arrival_card := PanelContainer.new()
	arrival_card.anchor_left = 0.5
	arrival_card.anchor_right = 0.5
	arrival_card.anchor_top = 0.30
	arrival_card.anchor_bottom = 0.30
	arrival_card.offset_left = -320.0
	arrival_card.offset_right = 320.0
	arrival_card.offset_top = -60.0
	arrival_card.offset_bottom = 60.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.95)
	style.border_color = Color(0.95, 0.82, 0.35, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	arrival_card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "✦ KANDIEZ SUNRISE BEACH RESORT ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	vbox.add_child(title)

	var sub := Label.new()
	if is_solo:
		sub.text = "LOT 2129, KG. TOK KEDERAT, PANTAI KANDIS, BACHOK\nYou Have Safely Reached The Family Chalet\n[ ✔ Progress Saved • Chapter 1 Complete ]"
	elif num_players == 2:
		sub.text = "LOT 2129, KG. TOK KEDERAT, PANTAI KANDIS, BACHOK\nBoth Siblings Have Safely Reached The Resort\n[ ✔ Progress Saved • Chapter 1 Complete ]"
	else:
		sub.text = "LOT 2129, KG. TOK KEDERAT, PANTAI KANDIS, BACHOK\nAll %d Siblings Have Safely Reached The Resort\n[ ✔ Progress Saved • Chapter 1 Complete ]" % num_players

	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98, 0.9))
	vbox.add_child(sub)

	arrival_card.add_child(vbox)
	drive_canvas.add_child(arrival_card)


# --- Oncoming Impact & Synced Disappearing NPC Explosion ---

func _on_car_crashed(car: StoryCar) -> void:
	if not is_instance_valid(car):
		return

	var funny_dialogs: Array[String] = [
		"WEH DIA MELETUP LAH?! KAU LANGGAR APA TU?!",
		"ASTAGHFIRULLAH KERETA TU MELETUP MACAM FILEM MICHAEL BAY!",
		"Macam mana boleh meletup siot?! Tangki minyak dia bocor ke?!",
		"Habis la kita... JPJ cari, bomba cari, polis cari!",
		"Oi! Siapa bagi kau lesen hah?! Kereta orang dah jadi bunga api!"
	]
	var chosen: String = funny_dialogs[randi() % funny_dialogs.size()]

	if car == player_car:
		crash_cam_shake_timer = 1.25
		_show_subtitle(chosen, 4.2)
	elif is_instance_valid(player_car):
		var dist := car.global_position.distance_to(player_car.global_position)
		if dist < 95.0:
			crash_cam_shake_timer = maxf(crash_cam_shake_timer, 0.55)
		_show_subtitle("%s: '%s'" % [car.sibling_name, chosen], 4.2)


func trigger_npc_explosion(npc: Node3D) -> void:
	if not is_instance_valid(npc):
		return
	if exploded_npc_names.has(npc.name):
		return
	var explosion_pos: Vector3 = npc.global_position
	if multiplayer.has_multiplayer_peer() and not _is_solo_mode():
		rpc_trigger_npc_explosion.rpc(npc.name, explosion_pos)
	else:
		_apply_npc_explosion(npc.name, explosion_pos)


@rpc("any_peer", "call_local", "reliable")
func rpc_trigger_npc_explosion(npc_name: String, explosion_pos: Vector3) -> void:
	_apply_npc_explosion(npc_name, explosion_pos)


func _apply_npc_explosion(npc_name: String, explosion_pos: Vector3) -> void:
	if not traffic_container or exploded_npc_names.has(npc_name):
		return
	exploded_npc_names[npc_name] = true

	# Immediately remove and disappear the collided NPC car across all peers
	var npc := traffic_container.get_node_or_null(npc_name)
	if is_instance_valid(npc):
		active_oncoming_cars.erase(npc)
		active_same_lane_cars.erase(npc)
		npc.queue_free()

	# 1. Giant Fiery Fireball Burst at collision site
	var fb_mat := StandardMaterial3D.new()
	fb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fb_mat.vertex_color_use_as_albedo = true
	fb_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	var fb_grad := Gradient.new()
	fb_grad.colors = PackedColorArray([Color(1.0, 0.95, 0.4, 1.0), Color(1.0, 0.45, 0.05, 0.9), Color(0.2, 0.05, 0.02, 0.6), Color(0.1, 0.1, 0.1, 0.0)])
	fb_grad.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	var fb_tex := GradientTexture2D.new()
	fb_tex.gradient = fb_grad
	fb_tex.fill = GradientTexture2D.FILL_RADIAL
	fb_tex.fill_from = Vector2(0.5, 0.5)
	fb_tex.fill_to = Vector2(0.5, 0.0)
	fb_tex.width = 48
	fb_tex.height = 48
	fb_mat.albedo_texture = fb_tex

	var fb_quad := QuadMesh.new()
	fb_quad.size = Vector2(2.4, 2.4)
	fb_quad.material = fb_mat

	var fireball := CPUParticles3D.new()
	fireball.name = "FireballBurst"
	fireball.mesh = fb_quad
	fireball.amount = 52
	fireball.lifetime = 1.25
	fireball.one_shot = true
	fireball.explosiveness = 0.92
	fireball.direction = Vector3(0.0, 1.0, 0.0)
	fireball.spread = 180.0
	fireball.gravity = Vector3(0.0, 3.5, 0.0)
	fireball.initial_velocity_min = 6.0
	fireball.initial_velocity_max = 16.0
	fireball.scale_amount_min = 1.2
	fireball.scale_amount_max = 4.2
	fireball.emitting = true
	traffic_container.add_child(fireball)
	fireball.global_position = explosion_pos + Vector3(0.0, 0.6, 0.0)

	# 2. High-Velocity Burning Shrapnel Sparks
	var spk_mat := StandardMaterial3D.new()
	spk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spk_mat.albedo_color = Color(1.0, 0.85, 0.25)
	var spk_mesh := BoxMesh.new()
	spk_mesh.size = Vector3(0.14, 0.14, 0.14)
	spk_mesh.material = spk_mat

	var sparks := CPUParticles3D.new()
	sparks.name = "SparksShrapnel"
	sparks.mesh = spk_mesh
	sparks.amount = 55
	sparks.lifetime = 1.4
	sparks.one_shot = true
	sparks.explosiveness = 0.98
	sparks.direction = Vector3(0.0, 1.0, 0.0)
	sparks.spread = 180.0
	sparks.gravity = Vector3(0.0, -19.0, 0.0)
	sparks.initial_velocity_min = 14.0
	sparks.initial_velocity_max = 28.0
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.8
	sparks.emitting = true
	traffic_container.add_child(sparks)
	sparks.global_position = explosion_pos + Vector3(0.0, 0.6, 0.0)

	# 3. Lingering Black Smoke Plume at impact spot
	var smoke_plume := CPUParticles3D.new()
	smoke_plume.mesh = fb_quad
	smoke_plume.amount = 28
	smoke_plume.lifetime = 1.8
	smoke_plume.one_shot = true
	smoke_plume.explosiveness = 0.75
	smoke_plume.direction = Vector3(0.0, 1.0, 0.0)
	smoke_plume.spread = 45.0
	smoke_plume.gravity = Vector3(0.0, 2.8, 0.0)
	smoke_plume.initial_velocity_min = 2.0
	smoke_plume.initial_velocity_max = 6.0
	smoke_plume.scale_amount_min = 1.4
	smoke_plume.scale_amount_max = 3.5
	smoke_plume.color = Color(0.12, 0.10, 0.09, 0.72)
	smoke_plume.emitting = true
	traffic_container.add_child(smoke_plume)
	smoke_plume.global_position = explosion_pos + Vector3(0.0, 0.6, 0.0)

	# 4. Explosion Flash Light (quickly fades cleanly)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.65, 0.12)
	flash.light_energy = 24.0
	flash.omni_range = 45.0
	flash.omni_attenuation = 1.1
	traffic_container.add_child(flash)
	flash.global_position = explosion_pos + Vector3(0.0, 1.2, 0.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 5. Procedural Cinematic Hollywood Explosion Audio (Sub-bass thump + blast crunch)
	var exp_audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.5
	exp_audio.stream = gen
	exp_audio.unit_size = 40.0
	exp_audio.max_distance = 180.0
	exp_audio.volume_db = 8.0
	traffic_container.add_child(exp_audio)
	exp_audio.global_position = explosion_pos
	exp_audio.play()

	var playback := exp_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var sample_rate := 22050.0
		var frames := playback.get_frames_available()
		for f in range(frames):
			var t := float(f) / sample_rate
			var sub_bass := sin(t * 42.0 * TAU) * exp(-t * 3.6) * 0.75
			var noise := randf_range(-1.0, 1.0) * exp(-t * 5.0) * 0.65
			var rumble := randf_range(-0.35, 0.35) * exp(-t * 1.4) * 0.4
			var wave := clampf(sub_bass + noise + rumble, -0.95, 0.95)
			playback.push_frame(Vector2(wave, wave))

	# Cleanup explosion effects after they finish
	get_tree().create_timer(3.2).timeout.connect(func() -> void:
		if is_instance_valid(exp_audio): exp_audio.queue_free()
		if is_instance_valid(fireball): fireball.queue_free()
		if is_instance_valid(sparks): sparks.queue_free()
		if is_instance_valid(smoke_plume): smoke_plume.queue_free()
		if is_instance_valid(flash): flash.queue_free()
	)


func _apply_render_layers(root: Node, layer_mask: int) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).layers = layer_mask
	for child in root.get_children():
		_apply_render_layers(child, layer_mask)
