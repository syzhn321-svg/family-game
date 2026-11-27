extends Node3D

signal cutscene_finished()

# --- Config & Timing ---
const CUTSCENE_DURATION: float = 11.5
const CAR_SPEED_CRUISE: float = 24.0   # ~86 km/h
const CAR_SPEED_SLOW: float = 8.0     # ~28 km/h
const HIGHWAY_LENGTH: float = 380.0
const LANE_WIDTH: float = 4.2

# --- State ---
var elapsed_time: float = 0.0
var is_skipping: bool = false
var skip_hold_time: float = 0.0
var cars: Array[Node3D] = []
var car_wheels: Array[Array] = []  # Array of Array[MeshInstance3D]
var car_brake_lights: Array[Array] = []  # Array of Array[MeshInstance3D or Light3D]
var lead_car: Node3D = null

# --- Nodes ---
@onready var camera: Camera3D = $CutsceneCamera
var world_environment: WorldEnvironment = null
var cinematic_canvas: CanvasLayer = null
var top_letterbox: ColorRect = null
var bottom_letterbox: ColorRect = null
var fade_overlay: ColorRect = null
var subtitle_label: Label = null
var location_label: Label = null
var skip_prompt: Label = null
var skip_progress: ProgressBar = null
var audio_player: AudioStreamPlayer = null
var audio_gen_playback: AudioStreamGeneratorPlayback = null

# Audio synthesis state
var engine_phase: float = 0.0
var wind_phase: float = 0.0


func _ready() -> void:
	_setup_environment()
	_setup_highway()
	_setup_trees()
	_setup_road_sign()
	_setup_cars()
	_setup_camera()
	_setup_cinematic_ui()
	_setup_audio()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	elapsed_time += delta

	# Handle skip input (Hold Space on PC, or Tap on mobile)
	_handle_skip_input(delta)

	# Update car positions & wheel spins
	_update_cars(delta)

	# Update camera choreography
	_update_camera(delta)

	# Update subtitle text & cinematic fades
	_update_story_text()

	# Synthesize procedural audio (engine hum & road rumble)
	_update_audio()

	# Check end of cutscene
	if elapsed_time >= CUTSCENE_DURATION and not is_skipping:
		_finish_cutscene()


func _handle_skip_input(delta: float) -> void:
	if is_skipping:
		return

	var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
	var skip_pressed := Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept")

	if is_mobile:
		# On mobile: tap anywhere on screen to skip
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			skip_pressed = true

	if skip_pressed:
		skip_hold_time += delta
		if skip_progress:
			skip_progress.visible = true
			skip_progress.value = (skip_hold_time / 0.8) * 100.0
		if skip_hold_time >= 0.8:
			_trigger_skip()
	else:
		skip_hold_time = maxf(0.0, skip_hold_time - delta * 2.0)
		if skip_progress:
			skip_progress.value = (skip_hold_time / 0.8) * 100.0
			if skip_hold_time <= 0.05:
				skip_progress.visible = false


func _trigger_skip() -> void:
	if is_skipping:
		return
	is_skipping = true
	# Fast fade to black then finish
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.45)
	tween.tween_callback(_finish_cutscene)


func _finish_cutscene() -> void:
	if not is_instance_valid(self):
		return
	set_process(false)
	cutscene_finished.emit()


# --- Procedural Environment & Highway Setup ---
func _setup_environment() -> void:
	world_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.02)
	env.background_energy_multiplier = 0.2

	# Deep, moody, cinematic night fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.08)
	env.fog_density = 0.009
	env.fog_sky_affect = 0.0

	# Night ambient light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.32)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	world_environment.environment = env
	add_child(world_environment)

	# Faint moon DirectionalLight3D casting subtle silhouette shadows
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.68, 0.88)
	moon.light_energy = 0.75
	moon.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	moon.shadow_enabled = false
	add_child(moon)


func _setup_highway() -> void:
	var road_root := Node3D.new()
	road_root.name = "Highway"
	add_child(road_root)

	# 1. Main Asphalt Road (Two Lanes, 8.4m wide, 380m long)
	var asphalt_mesh := BoxMesh.new()
	asphalt_mesh.size = Vector3(8.4, 0.1, HIGHWAY_LENGTH)
	var asphalt_mat := StandardMaterial3D.new()
	asphalt_mat.albedo_color = Color(0.09, 0.095, 0.11)
	asphalt_mat.roughness = 0.88
	asphalt_mesh.material = asphalt_mat

	var road_inst := MeshInstance3D.new()
	road_inst.mesh = asphalt_mesh
	road_inst.position = Vector3(0.0, -0.05, -HIGHWAY_LENGTH * 0.5 + 50.0)
	road_root.add_child(road_inst)

	# 2. Road Shoulders (Dark dirt/gravel on left & right)
	var shoulder_mat := StandardMaterial3D.new()
	shoulder_mat.albedo_color = Color(0.04, 0.045, 0.04)
	shoulder_mat.roughness = 0.95

	for side in [-1.0, 1.0]:
		var shoulder_mesh := BoxMesh.new()
		shoulder_mesh.size = Vector3(4.0, 0.08, HIGHWAY_LENGTH)
		shoulder_mesh.material = shoulder_mat
		var sh_inst := MeshInstance3D.new()
		sh_inst.mesh = shoulder_mesh
		sh_inst.position = Vector3(side * (4.2 + 2.0), -0.06, road_inst.position.z)
		road_root.add_child(sh_inst)

	# 3. Endless Dark Terrain on Both Sides
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.018, 0.024, 0.015)
	ground_mat.roughness = 1.0
	for side in [-1.0, 1.0]:
		var ground_mesh := BoxMesh.new()
		ground_mesh.size = Vector3(120.0, 0.05, HIGHWAY_LENGTH)
		ground_mesh.material = ground_mat
		var gr_inst := MeshInstance3D.new()
		gr_inst.mesh = ground_mesh
		gr_inst.position = Vector3(side * (6.2 + 60.0), -0.07, road_inst.position.z)
		road_root.add_child(gr_inst)

	# 4. Dashed Center Line (Two-lane divider line, yellow/white dashes, NO physical divider)
	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.85, 0.78, 0.32)
	dash_mat.roughness = 0.5
	dash_mat.emission_enabled = true
	dash_mat.emission = Color(0.3, 0.28, 0.12)
	dash_mat.emission_energy_multiplier = 0.35

	var start_z: float = 40.0
	var end_z: float = -HIGHWAY_LENGTH + 50.0
	var cur_z: float = start_z
	while cur_z > end_z:
		var dash_box := BoxMesh.new()
		dash_box.size = Vector3(0.18, 0.006, 3.2)
		dash_box.material = dash_mat
		var d_inst := MeshInstance3D.new()
		d_inst.mesh = dash_box
		d_inst.position = Vector3(0.0, 0.005, cur_z)
		road_root.add_child(d_inst)
		cur_z -= 6.4  # 3.2m dash + 3.2m gap

	# 5. Solid Edge Lines (Outer borders of the two lanes)
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.85, 0.86, 0.9)
	edge_mat.roughness = 0.6
	for side in [-1.0, 1.0]:
		var edge_box := BoxMesh.new()
		edge_box.size = Vector3(0.14, 0.006, HIGHWAY_LENGTH)
		edge_box.material = edge_mat
		var e_inst := MeshInstance3D.new()
		e_inst.mesh = edge_box
		e_inst.position = Vector3(side * 4.0, 0.005, road_inst.position.z)
		road_root.add_child(e_inst)


func _setup_trees() -> void:
	var tree_root := Node3D.new()
	tree_root.name = "PineTrees"
	add_child(tree_root)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.08, 0.05, 0.03)

	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.02, 0.06, 0.03)
	foliage_mat.roughness = 0.9

	# Scatter trees alongside the highway
	var z_pos: float = 30.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765

	while z_pos > -HIGHWAY_LENGTH + 40.0:
		for side: float in [-1.0, 1.0]:
			# Keep camera zone clear for Shot 1 (z between -25 and -50 on the left side)
			if side < 0.0 and z_pos > -55.0 and z_pos < -25.0:
				continue
			var x_dist: float = side * rng.randf_range(6.5, 32.0)
			var tree := _create_pine_tree(rng.randf_range(5.0, 9.5), trunk_mat, foliage_mat)
			tree.position = Vector3(x_dist, 0.0, z_pos + rng.randf_range(-4.0, 4.0))
			tree.rotation.y = rng.randf_range(0.0, TAU)
			tree_root.add_child(tree)
		z_pos -= rng.randf_range(7.0, 14.0)


func _create_pine_tree(height: float, trunk_mat: Material, foliage_mat: Material) -> Node3D:
	var tree := Node3D.new()

	# Trunk
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.28
	cyl.height = height * 0.35
	cyl.material = trunk_mat
	trunk.mesh = cyl
	trunk.position.y = cyl.height * 0.5
	tree.add_child(trunk)

	# 3 Stacked Cones for Pine Needles
	var tiers := 3
	for i in range(tiers):
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = (tiers - i) * 0.55 + 0.4
		cone_mesh.height = height * 0.38
		cone_mesh.material = foliage_mat

		var foliage := MeshInstance3D.new()
		foliage.mesh = cone_mesh
		foliage.position.y = (trunk.position.y * 1.2) + (i * height * 0.22)
		tree.add_child(foliage)

	return tree


func _setup_road_sign() -> void:
	# Wooden roadside sign ahead on the right: "BLACKWOOD ROAD"
	var sign_root := Node3D.new()
	sign_root.position = Vector3(5.2, 0.0, -170.0)
	sign_root.rotation_degrees.y = -15.0

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.18, 0.12, 0.08)

	# Posts
	for x_off in [-0.9, 0.9]:
		var post := MeshInstance3D.new()
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.12, 2.2, 0.12)
		p_mesh.material = wood_mat
		post.mesh = p_mesh
		post.position = Vector3(x_off, 1.1, 0.0)
		sign_root.add_child(post)

	# Signboard
	var board := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(2.2, 1.0, 0.08)
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.08, 0.09, 0.06)
	b_mesh.material = board_mat
	board.mesh = b_mesh
	board.position = Vector3(0.0, 1.8, 0.04)
	sign_root.add_child(board)

	# Text on signboard
	var sign_text := Label3D.new()
	sign_text.text = "BLACKWOOD ESTATE\nPRIVATE ACCESS"
	sign_text.font_size = 28
	sign_text.modulate = Color(0.85, 0.8, 0.6)
	sign_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_text.position = Vector3(0.0, 1.8, 0.09)
	sign_root.add_child(sign_text)

	add_child(sign_root)


# --- Procedural Cars Setup (Each Player in Their Own Car) ---
func _setup_cars() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	var player_roster: Array[Dictionary] = []

	if net and not net.players.is_empty():
		for pid in net.players:
			var p_info: Dictionary = net.players[pid]
			var p_name: String = str(p_info.get("name", "Player %d" % pid))
			var is_host: bool = (pid == 1)
			player_roster.append({
				"id": pid,
				"name": p_name,
				"is_host": is_host
			})
	else:
		# Fallback solo play
		var p_name := "Player"
		if net and not net.local_player_name.is_empty():
			p_name = net.local_player_name
		player_roster.append({
			"id": 1,
			"name": p_name,
			"is_host": true
		})

	# Sort so Host leads the convoy
	player_roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["is_host"]: return true
		if b["is_host"]: return false
		return a["id"] < b["id"]
	)

	var car_colors: Array[Color] = [
		Color(0.12, 0.12, 0.14),  # Host: Sleek Midnight Black
		Color(0.18, 0.05, 0.05),  # Player 2: Dark Maroon
		Color(0.06, 0.12, 0.18),  # Player 3: Deep Navy
		Color(0.08, 0.15, 0.09)   # Player 4: Forest Charcoal
	]

	# Build cars in convoy down the right lane (x ~ 2.1)
	var z_spacing: float = 14.0
	for i in range(player_roster.size()):
		var p_data := player_roster[i]
		var color := car_colors[i % car_colors.size()]
		var car := _build_car(p_data["name"], p_data["is_host"], color, i)

		# Initial position: lead car starts at z = 18.0, trailing cars behind it
		var lane_x: float = -2.1 + (0.15 if (i % 2 == 1) else -0.15)
		var start_z: float = 18.0 + (i * z_spacing)
		car.position = Vector3(lane_x, 0.0, start_z)
		add_child(car)
		cars.append(car)

		if i == 0:
			lead_car = car


func _build_car(p_name: String, is_host: bool, paint_color: Color, index: int) -> Node3D:
	var car := Node3D.new()
	car.name = "Car_%d" % index

	var own_layer_mask: int = 1 << (1 + (index % 4))
	var world_and_others_mask: int = 0xFFFFF & ~own_layer_mask

	# Materials (Satin finish & tinted dielectric glass to eliminate mirror glare spots)
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
	tire_mat.albedo_color = Color(0.04, 0.04, 0.04)
	tire_mat.roughness = 0.9

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.58, 0.61, 0.66)
	rim_mat.metallic = 0.35
	rim_mat.roughness = 0.52
	rim_mat.metallic_specular = 0.20

	# 1. Lower Chassis Box (4.3m long, 1.85m wide, 0.62m high)
	var body := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(1.85, 0.62, 4.3)
	b_mesh.material = paint_mat
	body.mesh = b_mesh
	body.position.y = 0.58
	car.add_child(body)

	# 2. Cabin / Roof (2.3m long, 1.5m wide, 0.55m high)
	var cabin := MeshInstance3D.new()
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(1.5, 0.55, 2.3)
	c_mesh.material = paint_mat
	cabin.mesh = c_mesh
	cabin.position = Vector3(0.0, 1.1, 0.2)
	car.add_child(cabin)

	# 3. Windshield & Glass Windows
	var windshield := MeshInstance3D.new()
	var w_mesh := BoxMesh.new()
	w_mesh.size = Vector3(1.42, 0.48, 0.06)
	w_mesh.material = glass_mat
	windshield.mesh = w_mesh
	windshield.position = Vector3(0.0, 1.08, -0.96)
	windshield.rotation_degrees.x = -25.0
	car.add_child(windshield)

	var rear_glass := MeshInstance3D.new()
	var rg_mesh := BoxMesh.new()
	rg_mesh.size = Vector3(1.42, 0.48, 0.06)
	rg_mesh.material = glass_mat
	rear_glass.mesh = rg_mesh
	rear_glass.position = Vector3(0.0, 1.08, 1.36)
	rear_glass.rotation_degrees.x = 22.0
	car.add_child(rear_glass)

	# Side Windows
	for s_side in [-0.74, 0.74]:
		var swin := MeshInstance3D.new()
		var sw_box := BoxMesh.new()
		sw_box.size = Vector3(0.04, 0.44, 1.85)
		swin.mesh = sw_box
		swin.material_override = glass_mat
		swin.position = Vector3(s_side, 1.10, 0.2)
		car.add_child(swin)

	# RHD Dashboard & Glowing Cluster (+X = 0.38)
	var dash := MeshInstance3D.new()
	var d_box := BoxMesh.new()
	d_box.size = Vector3(1.42, 0.24, 0.42)
	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.08, 0.08, 0.1)
	dash.mesh = d_box
	dash.material_override = dash_mat
	dash.position = Vector3(0.0, 0.88, -0.42)
	car.add_child(dash)

	var cluster := MeshInstance3D.new()
	var cl_box := BoxMesh.new()
	cl_box.size = Vector3(0.36, 0.16, 0.04)
	var cluster_mat := StandardMaterial3D.new()
	cluster_mat.albedo_color = Color(0.05, 0.12, 0.18)
	cluster_mat.emission_enabled = true
	cluster_mat.emission = Color(0.14, 0.55, 0.72)
	cluster_mat.emission_energy_multiplier = 0.75
	cluster.mesh = cl_box
	cluster.material_override = cluster_mat
	cluster.position = Vector3(0.38, 0.90, -0.40)
	cluster.rotation_degrees.x = -18.0
	car.add_child(cluster)

	# RHD Steering Wheel (+X = 0.38)
	var steering_col := Node3D.new()
	steering_col.position = Vector3(0.38, 0.94, -0.30)
	steering_col.rotation_degrees.x = 22.0
	car.add_child(steering_col)

	var wheel_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.18
	wheel_mesh.mesh = torus
	wheel_mesh.material_override = dash_mat
	wheel_mesh.rotation_degrees.x = 90.0
	steering_col.add_child(wheel_mesh)

	# RHD Driver Silhouette (+X = 0.38)
	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = Color(0.12, 0.13, 0.15)
	var d_seat := Node3D.new()
	d_seat.position = Vector3(0.38, 0.58, 0.04)
	car.add_child(d_seat)

	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.36, 0.42, 0.2)
	torso.mesh = torso_mesh
	torso.position = Vector3(0.0, 0.38, 0.08)
	torso.rotation_degrees.x = 10.0
	d_seat.add_child(torso)

	var head := MeshInstance3D.new()
	var h_mesh := SphereMesh.new()
	h_mesh.radius = 0.11
	h_mesh.height = 0.22
	head.mesh = h_mesh
	head.position = Vector3(0.0, 0.68, 0.1)
	d_seat.add_child(head)

	# Left Passenger Seat (-X = -0.38)
	var p_seat := Node3D.new()
	p_seat.position = Vector3(-0.38, 0.58, 0.04)
	car.add_child(p_seat)

	# 4. Four Wheels
	var wheels: Array[Node3D] = []
	var wheel_offsets: Array[Vector3] = [
		Vector3(-0.95, 0.34, -1.25),  # Front Left
		Vector3(0.95, 0.34, -1.25),   # Front Right
		Vector3(-0.95, 0.34, 1.35),   # Rear Left
		Vector3(0.95, 0.34, 1.35)     # Rear Right
	]

	for w_pos in wheel_offsets:
		var wheel_mount := Node3D.new()
		wheel_mount.position = w_pos

		var wheel_spin := Node3D.new()
		wheel_spin.name = "WheelSpin"
		wheel_mount.add_child(wheel_spin)

		# Rubber Tire (cylinder oriented along X axis)
		var tire := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.34
		cyl.height = 0.22
		cyl.material = tire_mat
		tire.mesh = cyl
		tire.rotation_degrees.z = 90.0
		wheel_spin.add_child(tire)

		# Silver Inner Rim
		var rim := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius = 0.22
		rim_cyl.bottom_radius = 0.22
		rim_cyl.height = 0.224
		rim_cyl.material = rim_mat
		rim.mesh = rim_cyl
		rim.rotation_degrees.z = 90.0
		wheel_spin.add_child(rim)

		# Metallic Wheel Spokes (makes rolling spin clearly visible)
		var is_left: bool = (w_pos.x < 0.0)
		var face_x: float = -0.113 if is_left else 0.113
		for s_deg in [0.0, 60.0, 120.0]:
			var spoke := MeshInstance3D.new()
			var sp_box := BoxMesh.new()
			sp_box.size = Vector3(0.012, 0.38, 0.04)
			sp_box.material = rim_mat
			spoke.mesh = sp_box
			spoke.position.x = face_x
			spoke.rotation_degrees.x = s_deg
			wheel_spin.add_child(spoke)

		car.add_child(wheel_mount)
		wheels.append(wheel_spin)
	car_wheels.append(wheels)

	# 5. Front Headlights (Two SpotLights cutting through the fog)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(1.0, 0.98, 0.9)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.98, 0.9)
	head_mat.emission_energy_multiplier = 4.0

	for h_side in [-0.65, 0.65]:
		# Emissive bulb mesh
		var bulb := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.1
		s_mesh.height = 0.2
		s_mesh.material = head_mat
		bulb.mesh = s_mesh
		bulb.position = Vector3(h_side, 0.62, -2.15)
		car.add_child(bulb)

		# High-beam spotlight
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.97, 0.88)
		spot.light_energy = 14.0
		spot.spot_range = 75.0
		spot.spot_angle = 35.0
		spot.spot_attenuation = 0.65
		spot.shadow_enabled = true
		spot.position = Vector3(h_side, 0.62, -2.18)
		spot.rotation_degrees = Vector3(-2.0, 0.0, 0.0)  # Aim forward down the road in -Z
		car.add_child(spot)

	# Soft ground bounce light (excludes own car layer to prevent hood/windshield glare)
	var bounce := OmniLight3D.new()
	bounce.light_color = Color(0.95, 0.92, 0.85)
	bounce.light_energy = 3.2
	bounce.omni_range = 10.0
	bounce.light_cull_mask = world_and_others_mask
	bounce.position = Vector3(0.0, 0.4, -4.2)
	car.add_child(bounce)

	# 6. Rear Taillights (Red glowing road lights — excluded from own car layers)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.95, 0.08, 0.08)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(0.95, 0.08, 0.08)
	tail_mat.emission_energy_multiplier = 3.0

	var brake_nodes: Array = []
	for t_side in [-0.7, 0.7]:
		var t_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.24, 0.12, 0.04)
		box.material = tail_mat
		t_mesh.mesh = box
		t_mesh.position = Vector3(t_side, 0.65, 2.15)
		car.add_child(t_mesh)
		brake_nodes.append(t_mesh)

		var red_glow := OmniLight3D.new()
		red_glow.light_color = Color(0.95, 0.08, 0.08)
		red_glow.light_energy = 0.9
		red_glow.omni_range = 4.2
		red_glow.light_cull_mask = world_and_others_mask
		red_glow.position = Vector3(t_side, 0.55, 2.35)
		car.add_child(red_glow)
		brake_nodes.append(red_glow)

	car_brake_lights.append(brake_nodes)

	# Isolate car meshes onto own_layer_mask so own spill lights never cause body/glass glare
	_set_subtree_render_layers(car, own_layer_mask)

	# 7. Player Name Tag floating over car
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 26
	var host_prefix := "[HOST] " if is_host else ""
	tag.text = "%s%s" % [host_prefix, p_name]
	tag.modulate = Color(0.4, 0.95, 0.6) if is_host else Color(0.85, 0.9, 0.98)
	tag.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	tag.outline_size = 6
	tag.position = Vector3(0.0, 2.05, 0.0)
	car.add_child(tag)

	return car


func _set_subtree_render_layers(root: Node, layer_mask: int) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).layers = layer_mask
	for child in root.get_children():
		_set_subtree_render_layers(child, layer_mask)


# --- Cinematic Camera Choreography ---
func _setup_camera() -> void:
	if not camera:
		camera = get_node_or_null("CutsceneCamera") as Camera3D
	if camera:
		if world_environment and world_environment.environment:
			camera.environment = world_environment.environment


func _update_camera(delta: float) -> void:
	if not camera or not lead_car:
		return

	var lead_z: float = lead_car.position.z

	# Phase 1 (0.0s - 3.5s): Low-Angle Roadside Shot
	# Headlights pierce the deep fog in the distance, cars roar past camera
	if elapsed_time < 3.5:
		var t := elapsed_time / 3.5
		var cam_start := Vector3(-3.4, 0.65, -35.0)
		var cam_end := Vector3(-3.8, 0.8, -42.0)
		camera.position = cam_start.lerp(cam_end, t)

		# Track cars: look south towards oncoming cars, then pan as lead car passes
		var target_look: Vector3
		if lead_z > -28.0:
			target_look = Vector3(2.1, 0.75, lead_z)
		else:
			# Pan smoothly to watch cars zoom down the road into the night
			target_look = Vector3(2.1, 0.75, lead_z - 10.0)
		if camera.position.distance_to(target_look) > 0.5:
			camera.look_at(to_global(target_look), Vector3.UP)

	# Phase 2 (3.5s - 7.5s): Elevated Highway Convoy Chase Shot (Left Lane)
	elif elapsed_time < 7.5:
		var last_car: Node3D = cars.back() if not cars.is_empty() else lead_car
		var last_z: float = last_car.position.z

		var desired_pos := Vector3(-1.8, 3.2, last_z + 13.0)
		camera.position = desired_pos

		var look_target := Vector3(-2.1, 1.0, lead_z - 16.0)
		if camera.position.distance_to(look_target) > 0.5:
			camera.look_at(to_global(look_target), Vector3.UP)

	# Phase 3 (7.5s - 10.2s): Front Dynamic Angle & Approaching Roadside Sign
	elif elapsed_time < 10.2:
		var target_cam_pos := Vector3(-2.1, 1.25, lead_z - 9.5)
		camera.position = target_cam_pos

		# Look back at lead car and convoy headlights
		var look_target := Vector3(-2.1, 0.85, lead_z + 1.5)
		if camera.position.distance_to(look_target) > 0.5:
			camera.look_at(to_global(look_target), Vector3.UP)

	# Phase 4 (10.2s - 11.5s): Deceleration & Turning into Driveway
	else:
		var target_cam_pos := Vector3(-4.5, 2.2, lead_z + 6.0)
		camera.position = camera.position.lerp(target_cam_pos, delta * 3.0)
		var look_target := Vector3(-2.1, 0.8, lead_z - 15.0)
		if camera.position.distance_to(look_target) > 0.5:
			camera.look_at(to_global(look_target), Vector3.UP)


func _update_cars(delta: float) -> void:
	# Calculate speed: Cruise fast, then slow down near the Blackwood Road sign
	var speed: float = CAR_SPEED_CRUISE
	if elapsed_time > 7.2:
		var slow_factor := clampf((elapsed_time - 7.2) / 2.5, 0.0, 1.0)
		speed = lerpf(CAR_SPEED_CRUISE, CAR_SPEED_SLOW, slow_factor)

		# Brake lights flare bright red when slowing down
		for brake_group in car_brake_lights:
			for node in brake_group:
				if node is OmniLight3D:
					node.light_energy = lerpf(0.9, 2.6, slow_factor)

	for i in range(cars.size()):
		var car := cars[i]
		if not is_instance_valid(car):
			continue

		# Move along highway (towards negative Z)
		car.position.z -= speed * delta

		# If near the end (after sign), lead car starts subtle turn towards driveway
		if elapsed_time > 8.5:
			var turn_progress := clampf((elapsed_time - 8.5) / 3.0, 0.0, 1.0)
			car.position.x += turn_progress * delta * 1.5
			car.rotation.y = -turn_progress * 0.18

		# Procedural suspension bounce & chassis vibration
		var bounce := sin(elapsed_time * 8.0 + i * 1.5) * 0.012
		car.position.y = bounce

		# Spin wheels (rolling forward along the car's transverse X axle)
		if i < car_wheels.size():
			for wheel: Node3D in car_wheels[i]:
				wheel.rotate_x(-speed * delta / 0.34)


# --- Cinematic UI, Letterbox & Subtitles ---
func _setup_cinematic_ui() -> void:
	cinematic_canvas = CanvasLayer.new()
	cinematic_canvas.layer = 99
	add_child(cinematic_canvas)

	# 1. Top & Bottom Letterbox Bars (Cinematic 2.35:1 Widescreen)
	top_letterbox = ColorRect.new()
	top_letterbox.color = Color(0.0, 0.0, 0.0, 1.0)
	top_letterbox.anchor_left = 0.0
	top_letterbox.anchor_right = 1.0
	top_letterbox.anchor_top = 0.0
	top_letterbox.anchor_bottom = 0.10
	cinematic_canvas.add_child(top_letterbox)

	bottom_letterbox = ColorRect.new()
	bottom_letterbox.color = Color(0.0, 0.0, 0.0, 1.0)
	bottom_letterbox.anchor_left = 0.0
	bottom_letterbox.anchor_right = 1.0
	bottom_letterbox.anchor_top = 0.90
	bottom_letterbox.anchor_bottom = 1.0
	cinematic_canvas.add_child(bottom_letterbox)

	# 2. Location / Time Stamp (Top Left)
	location_label = Label.new()
	location_label.text = "ROUTE 409 • 11:43 PM"
	location_label.add_theme_font_size_override("font_size", 13)
	location_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.85))
	location_label.offset_left = 32.0
	location_label.offset_top = 18.0
	cinematic_canvas.add_child(location_label)

	# 3. Cinematic Subtitle (Bottom Center)
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
	cinematic_canvas.add_child(subtitle_label)

	# 4. Skip Indicator (Bottom Right)
	var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
	skip_prompt = Label.new()
	skip_prompt.text = "TAP TO SKIP" if is_mobile else "HOLD [SPACE] TO SKIP"
	skip_prompt.add_theme_font_size_override("font_size", 11)
	skip_prompt.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.65))
	skip_prompt.anchor_left = 1.0
	skip_prompt.anchor_top = 1.0
	skip_prompt.anchor_right = 1.0
	skip_prompt.anchor_bottom = 1.0
	skip_prompt.offset_left = -160.0
	skip_prompt.offset_top = -32.0
	cinematic_canvas.add_child(skip_prompt)

	skip_progress = ProgressBar.new()
	skip_progress.show_percentage = false
	skip_progress.anchor_left = 1.0
	skip_progress.anchor_top = 1.0
	skip_progress.anchor_right = 1.0
	skip_progress.anchor_bottom = 1.0
	skip_progress.offset_left = -160.0
	skip_progress.offset_top = -12.0
	skip_progress.offset_right = -20.0
	skip_progress.offset_bottom = -8.0
	skip_progress.visible = false
	cinematic_canvas.add_child(skip_progress)

	# 5. Fullscreen Fade Transition Overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_overlay.anchor_left = 0.0
	fade_overlay.anchor_top = 0.0
	fade_overlay.anchor_right = 1.0
	fade_overlay.anchor_bottom = 1.0
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_canvas.add_child(fade_overlay)

	# Fade in from black at the beginning
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 1.2)


func _update_story_text() -> void:
	if not subtitle_label:
		return

	if elapsed_time < 0.8:
		subtitle_label.text = ""
	elif elapsed_time < 3.8:
		subtitle_label.text = "A dark two-lane highway cut through the mountain pines."
	elif elapsed_time < 7.2:
		var squad_text := "The squad moves together in silent convoy." if cars.size() > 1 else "A solitary traveler drives deeper into the night."
		subtitle_label.text = squad_text
	elif elapsed_time < 10.0:
		subtitle_label.text = "Approaching the Blackwood Estate. No phone reception."
	else:
		subtitle_label.text = "No way back now."

	# Fade to black in the final seconds
	if elapsed_time >= (CUTSCENE_DURATION - 1.2) and fade_overlay and not is_skipping:
		var fade_t := (elapsed_time - (CUTSCENE_DURATION - 1.2)) / 1.2
		fade_overlay.color.a = clampf(fade_t, 0.0, 1.0)


# --- Procedural Atmospheric Audio ---
func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	audio_player.stream = gen
	audio_player.volume_db = -4.0
	add_child(audio_player)
	audio_player.play()
	audio_gen_playback = audio_player.get_stream_playback()


func _update_audio() -> void:
	if not audio_gen_playback or not audio_player.playing:
		return

	var frames_avail: int = audio_gen_playback.get_frames_available()
	if frames_avail <= 0:
		return

	var sample_rate: float = 22050.0
	var buffer := PackedVector2Array()
	buffer.resize(frames_avail)

	# Engine hum frequency (~55 Hz) + road rumble + night wind
	var base_freq: float = 52.0
	if elapsed_time < 3.5:
		# Doppler whoosh when cars pass camera
		var car_dist := absf(lead_car.position.z - camera.position.z) if lead_car else 20.0
		base_freq = lerpf(72.0, 48.0, clampf(car_dist / 30.0, 0.0, 1.0))

	for i in range(frames_avail):
		engine_phase += TAU * base_freq / sample_rate
		if engine_phase > TAU: engine_phase -= TAU

		wind_phase += TAU * 140.0 / sample_rate
		if wind_phase > TAU: wind_phase -= TAU

		var engine := sin(engine_phase) * 0.45 + sin(engine_phase * 2.0) * 0.25 + sin(engine_phase * 0.5) * 0.15
		var noise := (randf() * 2.0 - 1.0) * 0.12
		var val := clampf((engine * 0.7 + noise) * 0.35, -1.0, 1.0)
		buffer[i] = Vector2(val, val)

	audio_gen_playback.push_buffer(buffer)
