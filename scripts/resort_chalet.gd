extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STORY_CAR_SCRIPT := preload("res://scripts/story_car.gd")
const RETRO_SKELETON_SCRIPT := preload("res://scripts/retro_skeleton.gd")

var world_env: WorldEnvironment = null
var dad_node: Node3D = null
var cutscene_camera: Camera3D = null
var interior_light: OmniLight3D = null
var porch_light: OmniLight3D = null
var hud_canvas: CanvasLayer = null
var fade_rect: ColorRect = null
var dialogue_box: PanelContainer = null
var dialogue_speaker_label: Label = null
var dialogue_text_label: Label = null
var objective_label: Label = null
var carry_prompt_label: Label = null
var inventory_panel: Control = null
var inventory_slots: Array[PanelContainer] = []
var inventory_bag_icon: TextureRect = null
var inventory_full_hand_overlay: PanelContainer = null
var inventory_weight_label: Label = null
var inventory_item_label: Label = null
var active_inventory_slot: int = 0

var elapsed_time: float = 0.0
var is_intro_cutscene: bool = true
var dialogue_lines: Array[Dictionary] = []
var dialogue_idx: int = 0
var dialogue_line_timer: float = 0.0

var parked_cars: Array[Node3D] = []
var bags: Array[Node3D] = []
var bag_states: Dictionary = {} # bag_name -> { "owner": int, "state": int (0=trunk, 1=carried, 2=inside), "node": Node3D }
var carrying_bag_name: String = ""

var has_all_bags_inside: bool = false
var has_triggered_disturbance: bool = false
var flicker_timer: float = 0.0

const DROP_ZONE_POS := Vector3(0.0, 0.72, -11.5)


func _ready() -> void:
	_setup_environment()
	_setup_house_ambience()
	_setup_beach_and_chalet()
	_setup_parked_player_cars()
	_setup_dad_bean()
	_setup_players()
	_setup_player_bags()
	_setup_hud()
	_start_dad_cutscene()


func _unhandled_input(event: InputEvent) -> void:
	# Intro cutscene is unskippable so all co-op players stay synchronized
	if is_intro_cutscene:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		_handle_interact_press()

	# Mouse wheel hotbar slot switching (Lethal Company style - locked when carrying two-handed bag)
	if event is InputEventMouseButton and event.pressed:
		if not carrying_bag_name.is_empty():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active_inventory_slot = (active_inventory_slot + 1) % 4
			_update_slot_visuals()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			active_inventory_slot = (active_inventory_slot + 3) % 4
			_update_slot_visuals()


func _process(delta: float) -> void:
	elapsed_time += delta

	# Subtle atmospheric idle pose for Dad
	if is_instance_valid(dad_node) and dad_node.has_method("update_pose"):
		dad_node.update_pose(0.0, false, false, delta)

	if is_intro_cutscene:
		# In multiplayer, Host drives the unskippable cutscene timer for all peers
		var is_host_or_solo := _is_solo_mode() or multiplayer == null or not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
		if is_host_or_solo:
			dialogue_line_timer += delta
			if dialogue_line_timer >= 4.2:
				dialogue_line_timer = 0.0
				var next_idx := dialogue_idx + 1
				if multiplayer != null and multiplayer.has_multiplayer_peer() and not _is_solo_mode():
					rpc_sync_dialogue_step.rpc(next_idx)
				else:
					_set_dialogue_step(next_idx)
		return

	_update_bag_prompts()

	if has_all_bags_inside and not has_triggered_disturbance:
		flicker_timer += delta
		if flicker_timer >= 3.2:
			has_triggered_disturbance = true
			_trigger_first_disturbance()
		elif is_instance_valid(interior_light) and flicker_timer > 1.2:
			interior_light.light_energy = 1.8 if randf() > 0.25 else 0.35


func _setup_environment() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.02)
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.08)
	env.fog_density = 0.012
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.32)
	env.ambient_light_energy = 1.15
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.76, 0.95)
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	add_child(moon)


func _setup_house_ambience() -> void:
	var ambience_stream := load("res://assets/audio/ambience_house_wind.wav") as AudioStreamWAV
	if ambience_stream:
		ambience_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var ambience_player := AudioStreamPlayer.new()
		ambience_player.name = "HouseInteriorAmbience"
		ambience_player.stream = ambience_stream
		ambience_player.volume_db = -19.0  # Subtle, calm, low windy breeze for chalet interior
		ambience_player.autoplay = true
		add_child(ambience_player)
		ambience_player.play()


func _setup_beach_and_chalet() -> void:
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.24, 0.20, 0.14)
	sand_mat.roughness = 0.96

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.26, 0.17, 0.10)
	wood_mat.roughness = 0.88

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.36, 0.25, 0.17)
	wall_mat.roughness = 0.85

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.16, 0.10, 0.07)

	# Ground & Driveway
	var ground := StaticBody3D.new()
	var g_mesh := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	g_box.size = Vector3(80.0, 0.4, 80.0)
	g_box.material = sand_mat
	g_mesh.mesh = g_box
	g_mesh.position.y = -0.2
	ground.add_child(g_mesh)
	var g_col := CollisionShape3D.new()
	var gc_box := BoxShape3D.new()
	gc_box.size = Vector3(80.0, 0.4, 80.0)
	g_col.shape = gc_box
	g_col.position.y = -0.2
	ground.add_child(g_col)
	add_child(ground)

	# Ocean Plane behind chalet (-Z)
	var ocean := MeshInstance3D.new()
	var o_plane := PlaneMesh.new()
	o_plane.size = Vector2(120.0, 60.0)
	var o_mat := StandardMaterial3D.new()
	o_mat.albedo_color = Color(0.02, 0.05, 0.10)
	o_mat.metallic = 0.92
	o_mat.roughness = 0.12
	o_plane.material = o_mat
	ocean.mesh = o_plane
	ocean.position = Vector3(0.0, -0.35, -45.0)
	add_child(ocean)

	# Chalet Stilt Deck & Porch (Z = -4.0 to -18.0, top surface at Y = 0.70)
	var deck := StaticBody3D.new()
	deck.position = Vector3(0.0, 0.35, -11.0)
	var d_mesh := MeshInstance3D.new()
	var d_box := BoxMesh.new()
	d_box.size = Vector3(12.0, 0.7, 14.0)
	d_box.material = wood_mat
	d_mesh.mesh = d_box
	deck.add_child(d_mesh)
	var d_col := CollisionShape3D.new()
	var dc_box := BoxShape3D.new()
	dc_box.size = Vector3(12.0, 0.7, 14.0)
	d_col.shape = dc_box
	deck.add_child(d_col)
	add_child(deck)

	# Visual Porch Steps in front of deck (Z = -2.5 to -4.0) + smooth walkable ramp collider
	for s_i in range(3):
		var step_vis := MeshInstance3D.new()
		var st_b := BoxMesh.new()
		var step_h := 0.22 * float(s_i + 1)
		st_b.size = Vector3(3.6, step_h, 0.52)
		st_b.material = wood_mat
		step_vis.mesh = st_b
		step_vis.position = Vector3(0.0, step_h * 0.5, -2.72 - float(s_i) * 0.50)
		add_child(step_vis)

	var stair_ramp := StaticBody3D.new()
	stair_ramp.name = "PorchStairRamp"
	# Ramp from ground (z=-2.2, y=0.0) up to porch edge (z=-4.05, y=0.70)
	stair_ramp.position = Vector3(0.0, 0.28, -3.15)
	stair_ramp.rotation_degrees.x = 20.5
	var ramp_col := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(3.6, 0.22, 2.2)
	ramp_col.shape = ramp_box
	stair_ramp.add_child(ramp_col)
	add_child(stair_ramp)

	# Chalet Cabin Walls (Open front doorway onto porch)
	var walls := [
		[Vector3(-5.8, 2.3, -12.5), Vector3(0.3, 3.2, 10.5)],
		[Vector3(5.8, 2.3, -12.5), Vector3(0.3, 3.2, 10.5)],
		[Vector3(0.0, 2.3, -17.6), Vector3(11.8, 3.2, 0.3)],
		[Vector3(-3.6, 2.3, -7.4), Vector3(4.5, 3.2, 0.3)],
		[Vector3(3.6, 2.3, -7.4), Vector3(4.5, 3.2, 0.3)],
	]
	for w_def in walls:
		var wb := StaticBody3D.new()
		wb.position = w_def[0]
		var wm := MeshInstance3D.new()
		var wbox := BoxMesh.new()
		wbox.size = w_def[1]
		wbox.material = wall_mat
		wm.mesh = wbox
		wb.add_child(wm)
		var wc := CollisionShape3D.new()
		var wcb := BoxShape3D.new()
		wcb.size = w_def[1]
		wc.shape = wcb
		wb.add_child(wc)
		add_child(wb)

	# Roof
	var roof := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(13.2, 0.45, 15.2)
	r_box.material = roof_mat
	roof.mesh = r_box
	roof.position = Vector3(0.0, 4.1, -11.0)
	add_child(roof)

	# Luggage Drop-Off Mat inside the Chalet
	var drop_mat_mesh := MeshInstance3D.new()
	var dm_box := BoxMesh.new()
	dm_box.size = Vector3(3.2, 0.04, 2.0)
	var dm_mat := StandardMaterial3D.new()
	dm_mat.albedo_color = Color(0.45, 0.28, 0.16)
	dm_box.material = dm_mat
	drop_mat_mesh.mesh = dm_box
	drop_mat_mesh.position = DROP_ZONE_POS
	add_child(drop_mat_mesh)

	# Warm Porch & Interior Lights
	porch_light = OmniLight3D.new()
	porch_light.light_color = Color(1.0, 0.82, 0.45)
	porch_light.light_energy = 2.6
	porch_light.omni_range = 14.0
	porch_light.position = Vector3(0.0, 3.5, -5.5)
	add_child(porch_light)

	interior_light = OmniLight3D.new()
	interior_light.light_color = Color(1.0, 0.86, 0.58)
	interior_light.light_energy = 2.2
	interior_light.omni_range = 16.0
	interior_light.position = Vector3(0.0, 3.4, -12.5)
	add_child(interior_light)


func _setup_parked_player_cars() -> void:
	var player_entries := _get_active_player_entries()
	var fallback_chars: Array[String] = ["Syazril", "Syahirul", "Aleysa", "Amelya"]
	for i in range(player_entries.size()):
		var entry: Dictionary = player_entries[i]
		var char_name: String = str(entry.get("character", "Syazril"))
		if char_name.is_empty() or char_name == "random":
			char_name = fallback_chars[i % fallback_chars.size()]
		var p_name: String = str(entry.get("name", "Player"))

		var car = STORY_CAR_SCRIPT.new()
		car.name = "ParkedCar_%d" % i
		car.character_name = char_name
		car.set_meta("character_name", char_name)
		car.sibling_name = "%s (%s)" % [p_name, char_name]
		car.trunk_open = true
		car.is_active_driving = false
		car.is_parked_at_destination = true
		var x_pos := -4.8 + float(i) * 3.4
		car.position = Vector3(x_pos, 0.04, 6.5)
		car.rotation_degrees.y = 12.0
		add_child(car)
		car.apply_character_visuals(char_name, Color.BLACK, car.sibling_name)
		parked_cars.append(car)


func _setup_dad_bean() -> void:
	dad_node = RETRO_SKELETON_SCRIPT.create_character("Dad")
	dad_node.name = "Dad"
	dad_node.position = Vector3(2.2, 0.70, -5.8)
	dad_node.rotation_degrees.y = 175.0
	add_child(dad_node)

	var tag := Label3D.new()
	tag.name = "DadNameTag"
	tag.text = "Dad"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 24
	tag.outline_size = 5
	tag.modulate = Color(1.0, 0.88, 0.45)
	tag.position = Vector3(0.0, 2.05, 0.0)
	dad_node.add_child(tag)

	# Zoomed-in Cutscene Camera facing Dad on the porch
	cutscene_camera = Camera3D.new()
	cutscene_camera.name = "DadCutsceneCamera"
	cutscene_camera.fov = 52.0
	add_child(cutscene_camera)
	cutscene_camera.position = Vector3(1.5, 2.2, -2.6)
	cutscene_camera.look_at(Vector3(2.2, 2.05, -5.8), Vector3.UP)


func _setup_players() -> void:
	var entries := _get_active_player_entries()
	var my_id := multiplayer.get_unique_id() if (multiplayer != null and multiplayer.has_multiplayer_peer()) else 1

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var pid: int = int(entry.get("peer_id", 1))
		var p_name: String = str(entry.get("name", "Player"))
		var p_char: String = str(entry.get("character", "Syazril"))

		var p := PLAYER_SCENE.instantiate()
		p.name = str(pid)
		p.set_multiplayer_authority(pid)
		p.player_name = "%s (%s)" % [p_name, p_char]
		p.flashlight_mode = "normal"
		p.is_in_cutscene = true
		p.position = Vector3(-3.0 + float(i) * 2.2, 0.2, 2.6)
		p.set_meta("character_name", p_char)
		p.set_meta("player_name", p_name)
		add_child(p, true)
		p.look_at(Vector3(2.2, p.global_position.y, -5.8), Vector3.UP)
		p.rotation.x = 0.0
		p.rotation.z = 0.0
		if p.has_method("setup_character_model"):
			p.setup_character_model(p_char)
		if pid == my_id and p.has_method("set_cutscene_mode"):
			p.set_cutscene_mode(true)


func _setup_player_bags() -> void:
	var entries := _get_active_player_entries()
	var bag_count_per_player := 3 if entries.size() == 1 else 2
	var bag_colors: Array[Color] = [
		Color(0.18, 0.24, 0.34),
		Color(0.32, 0.16, 0.14),
		Color(0.16, 0.28, 0.20)
	]

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var pid: int = int(entry.get("peer_id", 1))
		var p_char: String = str(entry.get("character", "Syazril"))
		var car_node: Node3D = parked_cars[i] if i < parked_cars.size() else null
		var trunk_z_offset := 1.78
		match p_char:
			"Syazril": trunk_z_offset = 1.56
			"Aleysa": trunk_z_offset = 1.44
			"Syahirul": trunk_z_offset = 1.88
			"Amelya": trunk_z_offset = 1.74

		for b_i in range(bag_count_per_player):
			var bag := Node3D.new()
			bag.name = "Bag_%d_%d" % [pid, b_i]
			var local_x := -0.34 + float(b_i) * 0.34
			if is_instance_valid(car_node):
				var b_basis := car_node.transform.basis
				bag.position = car_node.position + b_basis.x * local_x + b_basis.z * trunk_z_offset + Vector3(0.0, 0.78, 0.0)
				bag.rotation.y = car_node.rotation.y
			else:
				bag.position = Vector3(-4.8 + float(i) * 3.4 + local_x, 0.78, 8.2)

			var mesh := MeshInstance3D.new()
			var b_box := BoxMesh.new()
			b_box.size = Vector3(0.32, 0.24, 0.48)
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = bag_colors[(i + b_i) % bag_colors.size()]
			b_mat.roughness = 0.82
			b_box.material = b_mat
			mesh.mesh = b_box
			bag.add_child(mesh)

			var lbl := Label3D.new()
			lbl.name = "BagLabel"
			lbl.text = "%s's Bag [E]" % p_char
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.font_size = 18
			lbl.modulate = Color(1.0, 0.9, 0.5)
			lbl.position.y = 0.45
			lbl.visible = false
			bag.add_child(lbl)

			add_child(bag)
			bags.append(bag)
			bag_states[bag.name] = {
				"owner": pid,
				"char": p_char,
				"state": 0,
				"node": bag
			}


func _get_active_player_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var net := get_node_or_null("/root/NetworkManager")
	if net and not bool(net.get("is_singleplayer")) and net.players.size() > 0:
		var p_ids: Array = net.players.keys()
		p_ids.sort()
		for pid in p_ids:
			var info: Dictionary = net.players[pid]
			var c_name: String = str(info.get("character", "Syazril"))
			if c_name == "random" or c_name.is_empty():
				c_name = "Syazril"
			out.append({
				"peer_id": int(pid),
				"name": str(info.get("name", "Player %d" % pid)),
				"character": c_name
			})
	else:
		var solo_name := "Player"
		if net and not str(net.local_player_name).is_empty():
			solo_name = str(net.local_player_name)
		out.append({
			"peer_id": 1,
			"name": solo_name,
			"character": "Syazril"
		})
	return out


func _setup_hud() -> void:
	hud_canvas = CanvasLayer.new()
	hud_canvas.layer = 90
	add_child(hud_canvas)

	objective_label = Label.new()
	objective_label.position = Vector2(24, 20)
	objective_label.add_theme_font_size_override("font_size", 13)
	objective_label.add_theme_color_override("font_color", Color(0.24, 0.88, 0.84, 0.90))
	objective_label.visible = false
	hud_canvas.add_child(objective_label)

	carry_prompt_label = Label.new()
	carry_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carry_prompt_label.anchor_left = 0.30
	carry_prompt_label.anchor_right = 0.70
	carry_prompt_label.anchor_top = 0.55
	carry_prompt_label.anchor_bottom = 0.60
	carry_prompt_label.add_theme_font_size_override("font_size", 14)
	carry_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	var prompt_box := StyleBoxFlat.new()
	prompt_box.bg_color = Color(0.01, 0.03, 0.06, 0.70)
	prompt_box.border_color = Color(0.22, 0.85, 0.80, 0.75)
	prompt_box.set_border_width_all(1)
	prompt_box.set_corner_radius_all(4)
	prompt_box.content_margin_left = 12.0
	prompt_box.content_margin_right = 12.0
	prompt_box.content_margin_top = 4.0
	prompt_box.content_margin_bottom = 4.0
	carry_prompt_label.add_theme_stylebox_override("normal", prompt_box)
	carry_prompt_label.visible = false
	hud_canvas.add_child(carry_prompt_label)

	# Lethal Company Style Hotbar (Lower Mid Section / Bottom Center)
	inventory_panel = Control.new()
	inventory_panel.anchor_left = 0.5
	inventory_panel.anchor_right = 0.5
	inventory_panel.anchor_top = 1.0
	inventory_panel.anchor_bottom = 1.0
	inventory_panel.offset_left = -116.0
	inventory_panel.offset_right = 116.0
	inventory_panel.offset_top = -92.0
	inventory_panel.offset_bottom = -16.0
	inventory_panel.visible = false

	var inv_vbox := VBoxContainer.new()
	inv_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_vbox.add_theme_constant_override("separation", 5)

	var slots_container := Control.new()
	slots_container.custom_minimum_size = Vector2(202, 46)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 6)

	inventory_slots.clear()
	var bag_tex := _create_bag_icon_texture()

	for slot_i in range(4):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(46, 46)

		var s_style := StyleBoxFlat.new()
		s_style.set_corner_radius_all(3)
		if slot_i == 0:
			s_style.bg_color = Color(0.04, 0.10, 0.12, 0.65)
			s_style.border_color = Color(0.35, 1.0, 0.95, 0.95)
			s_style.set_border_width_all(2)
		else:
			s_style.bg_color = Color(0.02, 0.04, 0.06, 0.50)
			s_style.border_color = Color(0.12, 0.38, 0.38, 0.40)
			s_style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", s_style)

		# Slot index number watermark in top-left
		var num_lbl := Label.new()
		num_lbl.name = "SlotNum"
		num_lbl.text = str(slot_i + 1)
		num_lbl.add_theme_font_size_override("font_size", 9)
		num_lbl.add_theme_color_override("font_color", Color(0.24, 0.65, 0.65, 0.55))
		num_lbl.position = Vector2(4, 2)
		slot.add_child(num_lbl)

		# First slot holds the travel bag icon
		if slot_i == 0:
			var icon_center := CenterContainer.new()
			icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
			inventory_bag_icon = TextureRect.new()
			inventory_bag_icon.texture = bag_tex
			inventory_bag_icon.custom_minimum_size = Vector2(28, 28)
			inventory_bag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			inventory_bag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			inventory_bag_icon.visible = false
			icon_center.add_child(inventory_bag_icon)
			slot.add_child(icon_center)

		slots_hbox.add_child(slot)
		inventory_slots.append(slot)

	slots_container.add_child(slots_hbox)

	# Full Hand Overlay Banner across all 4 slots
	inventory_full_hand_overlay = PanelContainer.new()
	inventory_full_hand_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var full_style := StyleBoxFlat.new()
	full_style.bg_color = Color(0.02, 0.08, 0.10, 0.85)
	full_style.border_color = Color(0.35, 1.0, 0.95, 0.95)
	full_style.set_border_width_all(2)
	full_style.set_corner_radius_all(4)
	inventory_full_hand_overlay.add_theme_stylebox_override("panel", full_style)
	inventory_full_hand_overlay.visible = false

	var full_hbox := HBoxContainer.new()
	full_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	full_hbox.add_theme_constant_override("separation", 10)

	var full_icon := TextureRect.new()
	full_icon.texture = bag_tex
	full_icon.custom_minimum_size = Vector2(26, 26)
	full_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	full_hbox.add_child(full_icon)

	var full_lbl := Label.new()
	full_lbl.text = "FULL HAND"
	full_lbl.add_theme_font_size_override("font_size", 14)
	full_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.95, 0.98))
	full_hbox.add_child(full_lbl)

	inventory_full_hand_overlay.add_child(full_hbox)
	slots_container.add_child(inventory_full_hand_overlay)

	inv_vbox.add_child(slots_container)

	# Info row under slots: Item name on left, Weight on right
	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 8)

	inventory_item_label = Label.new()
	inventory_item_label.text = "[ 1 ] EMPTY"
	inventory_item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_item_label.add_theme_font_size_override("font_size", 11)
	inventory_item_label.add_theme_color_override("font_color", Color(0.24, 0.60, 0.60, 0.65))
	info_hbox.add_child(inventory_item_label)

	inventory_weight_label = Label.new()
	inventory_weight_label.text = "Weight: 0 lb"
	inventory_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_weight_label.add_theme_font_size_override("font_size", 11)
	inventory_weight_label.add_theme_color_override("font_color", Color(0.24, 0.85, 0.80, 0.80))
	info_hbox.add_child(inventory_weight_label)

	inv_vbox.add_child(info_hbox)
	inventory_panel.add_child(inv_vbox)
	hud_canvas.add_child(inventory_panel)

	# Dialogue Box (Bottom Center)
	dialogue_box = PanelContainer.new()
	dialogue_box.anchor_left = 0.5
	dialogue_box.anchor_right = 0.5
	dialogue_box.anchor_top = 0.78
	dialogue_box.anchor_bottom = 0.78
	dialogue_box.offset_left = -360.0
	dialogue_box.offset_right = 360.0
	dialogue_box.offset_top = -54.0
	dialogue_box.offset_bottom = 54.0

	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.03, 0.04, 0.07, 0.92)
	d_style.border_color = Color(0.95, 0.82, 0.42, 0.85)
	d_style.set_border_width_all(2)
	d_style.set_corner_radius_all(10)
	d_style.content_margin_left = 20.0
	d_style.content_margin_right = 20.0
	d_style.content_margin_top = 12.0
	d_style.content_margin_bottom = 12.0
	dialogue_box.add_theme_stylebox_override("panel", d_style)

	var d_vbox := VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 4)

	dialogue_speaker_label = Label.new()
	dialogue_speaker_label.add_theme_font_size_override("font_size", 14)
	dialogue_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	d_vbox.add_child(dialogue_speaker_label)

	dialogue_text_label = Label.new()
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text_label.add_theme_font_size_override("font_size", 15)
	dialogue_text_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	d_vbox.add_child(dialogue_text_label)

	dialogue_box.add_child(d_vbox)
	hud_canvas.add_child(dialogue_box)

	# Smooth fade-in from black arriving from StoryDrive
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_canvas.add_child(fade_rect)
	var f_tw := create_tween()
	f_tw.tween_property(fade_rect, "color:a", 0.0, 0.85)


func _start_dad_cutscene() -> void:
	is_intro_cutscene = true
	if cutscene_camera:
		cutscene_camera.current = true
		cutscene_camera.call_deferred("make_current")

	dialogue_lines = _build_intro_dialogue_lines()
	dialogue_idx = 0
	dialogue_line_timer = 0.0
	_show_current_dialogue_line()


func _build_intro_dialogue_lines() -> Array[Dictionary]:
	var entries := _get_active_player_entries()
	var lines: Array[Dictionary] = []

	if entries.size() == 1:
		var c1: String = str(entries[0]["character"])
		lines.append({"speaker": "Dad", "text": "Eh %s, you're back earlier than I expected... you must've been driving fast on the highway, huh?" % c1})
		lines.append({"speaker": c1, "text": "No lah Ayah, normal speed only. The road was just empty tonight."})
		lines.append({"speaker": "Dad", "text": "Haha, sure lah. Anyway, go bring your bags in from your car trunk before the mosquitoes get inside."})
		return lines

	var c1: String = str(entries[0]["character"])
	var c2: String = str(entries[1]["character"])
	lines.append({"speaker": "Dad", "text": "Eh, you're all back earlier than I expected... you must've been speeding on the highway, huh?"})
	lines.append({"speaker": c1, "text": "Mana ada Ayah, we drove normal speed only. Traffic was just smooth tonight."})
	lines.append({"speaker": c2, "text": "Normal speed konon... %s was boosting past Tok Bali bridge earlier!" % c1})
	if entries.size() == 2:
		lines.append({"speaker": c1, "text": "Hey, you were right behind me trying to keep up too!"})
	elif entries.size() >= 3:
		var c3: String = str(entries[2]["character"])
		lines.append({"speaker": c3, "text": "Don't lie lah %s, even I had trouble keeping up with you two." % c1})
		if entries.size() >= 4:
			var c4: String = str(entries[3]["character"])
			lines.append({"speaker": c4, "text": "Both of you same only. Let's just hope no speed trap caught us."})
	lines.append({"speaker": "Dad", "text": "Haha, alright lah. Go grab your bags from your car trunks and bring them inside."})
	return lines


@rpc("authority", "call_local", "reliable")
func rpc_sync_dialogue_step(step_idx: int) -> void:
	_set_dialogue_step(step_idx)


func _set_dialogue_step(step_idx: int) -> void:
	dialogue_idx = step_idx
	dialogue_line_timer = 0.0
	_show_current_dialogue_line()


func _show_current_dialogue_line() -> void:
	if dialogue_idx >= dialogue_lines.size():
		_end_dad_cutscene()
		return
	var line: Dictionary = dialogue_lines[dialogue_idx]
	dialogue_speaker_label.text = str(line.get("speaker", "Dad"))
	dialogue_text_label.text = str(line.get("text", ""))


func _end_dad_cutscene() -> void:
	is_intro_cutscene = false
	if dialogue_box:
		dialogue_box.visible = false
	if cutscene_camera:
		cutscene_camera.current = false

	var my_id := multiplayer.get_unique_id() if (multiplayer != null and multiplayer.has_multiplayer_peer()) else 1
	var local_p := get_node_or_null(str(my_id))
	if local_p and local_p.has_method("set_cutscene_mode"):
		local_p.set_cutscene_mode(false)
		var cam := local_p.get_node_or_null("nek/head/eyes/Camera3D") as Camera3D
		if cam:
			cam.current = true
			cam.call_deferred("make_current")

	if objective_label:
		objective_label.visible = true
	if inventory_panel:
		inventory_panel.visible = true
	_refresh_bag_objective_text()
	_refresh_inventory_hud()


func _handle_drop_item(_player: Node3D = null) -> void:
	_handle_interact_press()


func _handle_interact_press() -> void:
	var my_id := multiplayer.get_unique_id() if (multiplayer != null and multiplayer.has_multiplayer_peer()) else 1
	var local_p := get_node_or_null(str(my_id)) as Node3D
	if not local_p:
		return

	# Drop carried bag if inside the chalet
	if not carrying_bag_name.is_empty():
		if local_p.global_position.z <= -8.0:
			var delivered_name := carrying_bag_name
			carrying_bag_name = ""
			if multiplayer != null and multiplayer.has_multiplayer_peer() and not _is_solo_mode():
				rpc_update_bag_state.rpc(delivered_name, 2, my_id)
			else:
				_apply_bag_state(delivered_name, 2, my_id)
			_refresh_inventory_hud()
		return

	# Otherwise pick up nearest bag from own car trunk
	var best_bag_name := ""
	var best_dist := 3.8
	for b_name in bag_states:
		var info: Dictionary = bag_states[b_name]
		if int(info["owner"]) != my_id or int(info["state"]) != 0:
			continue
		var b_node: Node3D = info["node"]
		var d := local_p.global_position.distance_to(b_node.global_position)
		if d < best_dist:
			best_dist = d
			best_bag_name = b_name

	if not best_bag_name.is_empty():
		carrying_bag_name = best_bag_name
		if multiplayer != null and multiplayer.has_multiplayer_peer() and not _is_solo_mode():
			rpc_update_bag_state.rpc(best_bag_name, 1, my_id)
		else:
			_apply_bag_state(best_bag_name, 1, my_id)
		_refresh_inventory_hud()


func _create_bag_icon_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cyan := Color(0.35, 1.0, 0.95, 0.95)
	var cyan_dark := Color(0.06, 0.22, 0.24, 0.90)

	# Main Suitcase Body (24 wide, 16 high) from (4, 11) to (27, 26)
	img.fill_rect(Rect2i(4, 11, 24, 16), cyan)
	img.fill_rect(Rect2i(6, 13, 20, 12), cyan_dark)

	# Twin Straps (2px vertical bands)
	img.fill_rect(Rect2i(10, 11, 2, 16), cyan)
	img.fill_rect(Rect2i(20, 11, 2, 16), cyan)

	# Top Handle
	img.fill_rect(Rect2i(12, 6, 8, 2), cyan)
	img.fill_rect(Rect2i(12, 8, 2, 3), cyan)
	img.fill_rect(Rect2i(18, 8, 2, 3), cyan)

	# Metal Buckles on Straps
	var gold := Color(1.0, 0.85, 0.35, 1.0)
	img.fill_rect(Rect2i(10, 18, 2, 2), gold)
	img.fill_rect(Rect2i(20, 18, 2, 2), gold)

	return ImageTexture.create_from_image(img)


func _update_slot_visuals() -> void:
	if not carrying_bag_name.is_empty():
		# All 4 slots occupied together by two-handed travel bag
		if inventory_full_hand_overlay:
			inventory_full_hand_overlay.visible = true
		for slot_panel in inventory_slots:
			var s := slot_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if s:
				s.border_color = Color(0.35, 1.0, 0.95, 0.95)
				s.set_border_width_all(2)
				s.bg_color = Color(0.04, 0.12, 0.15, 0.70)
		if inventory_item_label:
			inventory_item_label.text = "[ FULL HAND ] TRAVEL BAG"
			inventory_item_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.95, 0.95))
		if inventory_weight_label:
			inventory_weight_label.text = "Weight: 18 lb"
			inventory_weight_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 0.95))
		if inventory_bag_icon:
			inventory_bag_icon.visible = true
	else:
		if inventory_full_hand_overlay:
			inventory_full_hand_overlay.visible = false
		for i in range(inventory_slots.size()):
			var slot_panel := inventory_slots[i]
			var style := slot_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				if i == active_inventory_slot:
					style.border_color = Color(0.35, 1.0, 0.95, 0.95)
					style.set_border_width_all(2)
					style.bg_color = Color(0.04, 0.10, 0.12, 0.65)
				else:
					style.border_color = Color(0.12, 0.38, 0.38, 0.40)
					style.set_border_width_all(1)
					style.bg_color = Color(0.02, 0.04, 0.06, 0.50)

		if inventory_item_label:
			inventory_item_label.text = "[ %d ] EMPTY" % (active_inventory_slot + 1)
			inventory_item_label.add_theme_color_override("font_color", Color(0.24, 0.60, 0.60, 0.65))
		if inventory_weight_label:
			inventory_weight_label.text = "Weight: 0 lb"
			inventory_weight_label.add_theme_color_override("font_color", Color(0.24, 0.85, 0.80, 0.80))
		if inventory_bag_icon:
			inventory_bag_icon.visible = false


func _update_bag_prompts() -> void:
	var my_id := multiplayer.get_unique_id() if (multiplayer != null and multiplayer.has_multiplayer_peer()) else 1
	var local_p := get_node_or_null(str(my_id)) as Node3D
	if not local_p:
		return

	if not carrying_bag_name.is_empty():
		var can_drop := (local_p.global_position.z <= -8.0)
		if carry_prompt_label:
			carry_prompt_label.visible = true
			if can_drop:
				carry_prompt_label.text = "[E] Drop : Travel Bag"
			else:
				carry_prompt_label.text = "Bring luggage inside chalet"
		if local_p.has_method("set_drop_available"):
			local_p.set_drop_available(true)
		if local_p.has_method("set_interact_available"):
			local_p.set_interact_available(false)
		return

	if local_p.has_method("set_drop_available"):
		local_p.set_drop_available(false)

	var nearest_dist := 3.8
	var nearest_name := ""
	for b_name in bag_states:
		var info: Dictionary = bag_states[b_name]
		var b_node: Node3D = info["node"]
		var lbl := b_node.get_node_or_null("BagLabel") as Label3D
		var is_mine_at_car := (int(info["owner"]) == my_id and int(info["state"]) == 0)
		if lbl:
			lbl.visible = is_mine_at_car and local_p.global_position.distance_to(b_node.global_position) < 6.0
		if is_mine_at_car:
			var d := local_p.global_position.distance_to(b_node.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_name = b_name

	if carry_prompt_label:
		if not nearest_name.is_empty():
			carry_prompt_label.visible = true
			carry_prompt_label.text = "[E] Pick up : Travel Bag"
		else:
			carry_prompt_label.visible = false

	if local_p.has_method("set_interact_available"):
		local_p.set_interact_available(not nearest_name.is_empty())


func _refresh_inventory_hud() -> void:
	if not inventory_panel:
		return
	_update_slot_visuals()


@rpc("any_peer", "call_local", "reliable")
func rpc_update_bag_state(bag_name: String, state: int, carrier_pid: int) -> void:
	_apply_bag_state(bag_name, state, carrier_pid)


func _apply_bag_state(bag_name: String, state: int, _carrier_pid: int) -> void:
	if not bag_states.has(bag_name):
		return
	bag_states[bag_name]["state"] = state
	var b_node: Node3D = bag_states[bag_name]["node"]
	if is_instance_valid(b_node):
		if state == 1:
			b_node.visible = false
		elif state == 2:
			var delivered_count := 0
			for bn in bag_states:
				if int(bag_states[bn]["state"]) == 2:
					delivered_count += 1
			b_node.visible = true
			b_node.position = DROP_ZONE_POS + Vector3(-1.1 + float(delivered_count % 4) * 0.65, 0.14, -0.4 + float(delivered_count / 4) * 0.65)
			var lbl := b_node.get_node_or_null("BagLabel") as Label3D
			if lbl:
				lbl.visible = false
	_refresh_bag_objective_text()


func _refresh_bag_objective_text() -> void:
	var my_id := multiplayer.get_unique_id() if (multiplayer != null and multiplayer.has_multiplayer_peer()) else 1
	var my_done := 0
	var my_total := 0
	var all_done := 0
	var all_total := bag_states.size()
	for bn in bag_states:
		var info: Dictionary = bag_states[bn]
		if int(info["state"]) == 2:
			all_done += 1
		if int(info["owner"]) == my_id:
			my_total += 1
			if int(info["state"]) == 2:
				my_done += 1

	if all_total > 0 and all_done >= all_total:
		has_all_bags_inside = true
		if objective_label:
			objective_label.text = "> ALL LUGGAGE SECURED. SETTLE IN FOR THE NIGHT."
	elif objective_label:
		objective_label.text = "> OBJECTIVE: Bring luggage from car trunk (%d/%d)" % [my_done, my_total]


func _is_solo_mode() -> bool:
	var net := get_node_or_null("/root/NetworkManager")
	if net == null:
		return true
	if bool(net.get("is_singleplayer")):
		return true
	return net.players.size() <= 1


func _trigger_first_disturbance() -> void:
	if is_instance_valid(interior_light):
		interior_light.light_energy = 0.45
	if objective_label:
		objective_label.text = "> INVESTIGATE: Check strange noise near parked cars."
	if dialogue_box and dialogue_speaker_label and dialogue_text_label:
		dialogue_speaker_label.text = "???"
		dialogue_text_label.text = "A sharp knock echoes from the back door facing the dark beach..."
		dialogue_box.visible = true
		var tw := create_tween()
		tw.tween_interval(4.5)
		tw.tween_callback(func() -> void:
			if is_instance_valid(dialogue_box):
				dialogue_box.visible = false
		)
