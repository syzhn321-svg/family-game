class_name ItemModels
extends RefCounted

## Factory for 3D Flashlight, Hand-Crank Dynamo, UV Blacklight, and Lantern models.
## Used in both 1st Person (FPS view rig) and 3rd Person (held in character hand).

static func create_item(mode: String, is_fp: bool = false, is_active: bool = false) -> Node3D:
	var item: Node3D = null
	match mode.to_lower():
		"crank":
			item = build_crank_flashlight(is_fp)
		"uv":
			item = build_uv_flashlight(is_fp)
		"lantern":
			item = build_lantern(is_fp)
		_:
			# "normal", "battery", and default
			item = build_normal_flashlight(is_fp)
	if item:
		set_item_light_state(item, is_active, mode)
	return item


static func build_normal_flashlight(is_fp: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "NormalFlashlight"
	var scale_factor: float = 1.0 if is_fp else 0.85

	var mat_body := _make_mat(Color(0.12, 0.12, 0.14), 0.7, 0.35) # Matte black metal
	var mat_bezel := _make_mat(Color(0.72, 0.74, 0.78), 0.3, 0.85) # Silver aluminum bezel
	var mat_lens := _make_mat(Color(0.11, 0.11, 0.13), 0.25, 0.15) # Default unlit dark grey/black
	var mat_switch := _make_mat(Color(0.24, 0.24, 0.28), 0.8, 0.2)

	# 1. Main cylindrical handle barrel
	var barrel := _create_cylinder(0.022 * scale_factor, 0.022 * scale_factor, 0.16 * scale_factor, mat_body)
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 0.0, 0.02 * scale_factor)
	root.add_child(barrel)

	# 2. Grip ribs
	for i in range(3):
		var rib := _create_cylinder(0.0235 * scale_factor, 0.0235 * scale_factor, 0.012 * scale_factor, _make_mat(Color(0.18, 0.18, 0.22), 0.9, 0.1))
		rib.rotation_degrees.x = 90.0
		rib.position = Vector3(0.0, 0.0, (-0.03 + i * 0.035) * scale_factor)
		root.add_child(rib)

	# 3. Flared front reflector head
	var bezel := _create_cylinder(0.035 * scale_factor, 0.022 * scale_factor, 0.045 * scale_factor, mat_bezel)
	bezel.rotation_degrees.x = 90.0
	bezel.position = Vector3(0.0, 0.0, -0.08 * scale_factor)
	root.add_child(bezel)

	# 4. Front lens face
	var lens := _create_cylinder(0.032 * scale_factor, 0.032 * scale_factor, 0.005 * scale_factor, mat_lens)
	lens.name = "Lens"
	lens.rotation_degrees.x = 90.0
	lens.position = Vector3(0.0, 0.0, -0.103 * scale_factor)
	root.add_child(lens)

	# 5. Power switch toggle on top (+Y)
	var sw := _create_box(Vector3(0.012, 0.008, 0.024) * scale_factor, mat_switch)
	sw.position = Vector3(0.0, 0.023 * scale_factor, -0.01 * scale_factor)
	root.add_child(sw)

	# Metadata markers
	root.set_meta("lens_mesh", lens)
	root.set_meta("item_mode", "normal")
	root.set_meta("light_offset", Vector3(0.0, 0.0, -0.11 * scale_factor))
	return root


static func build_crank_flashlight(is_fp: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "CrankFlashlight"
	var scale_factor: float = 1.0 if is_fp else 0.85

	var mat_casing := _make_mat(Color(0.92, 0.70, 0.14), 0.65, 0.15) # Industrial safety amber/yellow
	var mat_rubber := _make_mat(Color(0.10, 0.10, 0.12), 0.85, 0.1) # Black rubberized grip
	var mat_lens := _make_mat(Color(0.11, 0.11, 0.13), 0.25, 0.15) # Default unlit dark grey/black
	var mat_metal := _make_mat(Color(0.75, 0.76, 0.80), 0.25, 0.85)

	# 1. Main chunky rectangular housing
	var body := _create_box(Vector3(0.062, 0.082, 0.155) * scale_factor, mat_casing)
	body.position = Vector3(0.0, 0.0, 0.01 * scale_factor)
	root.add_child(body)

	# 2. Side rubber grip inserts (left & right)
	for sx in [-1.0, 1.0]:
		var grip := _create_box(Vector3(0.006, 0.065, 0.095) * scale_factor, mat_rubber)
		grip.position = Vector3(sx * 0.032 * scale_factor, 0.0, 0.02 * scale_factor)
		root.add_child(grip)

	# 3. Front lens cluster bezel
	var bezel := _create_box(Vector3(0.058, 0.076, 0.022) * scale_factor, mat_rubber)
	bezel.position = Vector3(0.0, 0.0, -0.075 * scale_factor)
	root.add_child(bezel)

	# 4. Front triple-LED transparent emitter window
	var lens := _create_box(Vector3(0.048, 0.062, 0.006) * scale_factor, mat_lens)
	lens.name = "Lens"
	lens.position = Vector3(0.0, 0.0, -0.087 * scale_factor)
	root.add_child(lens)

	# 5. Mechanical Crank Assembly on side (+X)
	var crank_pivot := Node3D.new()
	crank_pivot.name = "CrankPivot"
	crank_pivot.position = Vector3(0.033 * scale_factor, 0.0, 0.02 * scale_factor)
	root.add_child(crank_pivot)

	# Hub pin
	var hub := _create_cylinder(0.016 * scale_factor, 0.016 * scale_factor, 0.012 * scale_factor, mat_rubber)
	hub.rotation_degrees.z = 90.0
	crank_pivot.add_child(hub)

	# Rotatable Crank Arm node
	var crank_arm := Node3D.new()
	crank_arm.name = "CrankArm"
	crank_pivot.add_child(crank_arm)

	var lever := _create_box(Vector3(0.008, 0.055, 0.012) * scale_factor, mat_metal)
	lever.position = Vector3(0.006 * scale_factor, 0.022 * scale_factor, 0.0)
	crank_arm.add_child(lever)

	var knob := _create_cylinder(0.012 * scale_factor, 0.012 * scale_factor, 0.022 * scale_factor, mat_rubber)
	knob.name = "Knob"
	knob.rotation_degrees.z = 90.0
	knob.position = Vector3(0.018 * scale_factor, 0.045 * scale_factor, 0.0)
	crank_arm.add_child(knob)

	root.set_meta("crank_arm", crank_arm)
	root.set_meta("lens_mesh", lens)
	root.set_meta("item_mode", "crank")
	root.set_meta("light_offset", Vector3(0.0, 0.0, -0.095 * scale_factor))
	return root


static func build_uv_flashlight(is_fp: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "UVFlashlight"
	var scale_factor: float = 1.0 if is_fp else 0.85

	var mat_body := _make_mat(Color(0.14, 0.13, 0.16), 0.65, 0.45) # Tactical anodized dark slate
	var mat_purple_ring := _make_mat(Color(0.68, 0.18, 0.95), 0.35, 0.65) # Metallic violet anodized bezel ring
	var mat_lens := _make_mat(Color(0.11, 0.11, 0.13), 0.25, 0.15) # Default unlit dark grey/black
	var mat_button := _make_mat(Color(0.20, 0.18, 0.24), 0.8, 0.2)

	# 1. Main tactical knurled cylindrical barrel
	var barrel := _create_cylinder(0.023 * scale_factor, 0.023 * scale_factor, 0.17 * scale_factor, mat_body)
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 0.0, 0.015 * scale_factor)
	root.add_child(barrel)

	# 2. Knurling pattern bands
	for i in range(4):
		var band := _create_cylinder(0.0245 * scale_factor, 0.0245 * scale_factor, 0.015 * scale_factor, _make_mat(Color(0.22, 0.20, 0.25), 0.9, 0.3))
		band.rotation_degrees.x = 90.0
		band.position = Vector3(0.0, 0.0, (-0.035 + i * 0.032) * scale_factor)
		root.add_child(band)

	# 3. Flared tactical bezel with Purple Ring
	var bezel_base := _create_cylinder(0.032 * scale_factor, 0.023 * scale_factor, 0.030 * scale_factor, mat_body)
	bezel_base.rotation_degrees.x = 90.0
	bezel_base.position = Vector3(0.0, 0.0, -0.075 * scale_factor)
	root.add_child(bezel_base)

	# Signature Violet Anodized Accent Ring
	var purple_ring := _create_cylinder(0.0345 * scale_factor, 0.032 * scale_factor, 0.016 * scale_factor, mat_purple_ring)
	purple_ring.rotation_degrees.x = 90.0
	purple_ring.position = Vector3(0.0, 0.0, -0.095 * scale_factor)
	root.add_child(purple_ring)

	# 4. Deep Violet/Purple UV Filter Lens
	var lens := _create_cylinder(0.031 * scale_factor, 0.031 * scale_factor, 0.005 * scale_factor, mat_lens)
	lens.name = "Lens"
	lens.rotation_degrees.x = 90.0
	lens.position = Vector3(0.0, 0.0, -0.105 * scale_factor)
	root.add_child(lens)

	# 5. Tactical tailcap button on back (+Z)
	var button := _create_cylinder(0.015 * scale_factor, 0.015 * scale_factor, 0.010 * scale_factor, mat_button)
	button.rotation_degrees.x = 90.0
	button.position = Vector3(0.0, 0.0, 0.103 * scale_factor)
	root.add_child(button)

	root.set_meta("lens_mesh", lens)
	root.set_meta("item_mode", "uv")
	root.set_meta("light_offset", Vector3(0.0, 0.0, -0.11 * scale_factor))
	return root


static func build_lantern(is_fp: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Lantern"
	# Enlarged lantern model for both first-person and third-person view
	var scale_factor: float = 1.38 if is_fp else 1.25

	var mat_metal := _make_mat(Color(0.22, 0.24, 0.20), 0.55, 0.65) # Weathered dark forest bronze
	var mat_cap := _make_mat(Color(0.18, 0.19, 0.16), 0.65, 0.55)
	var mat_glass := StandardMaterial3D.new()
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.albedo_color = Color(0.18, 0.18, 0.20, 0.35) # Default unlit dark grey tinted glass
	mat_glass.roughness = 0.25
	var mat_mantle := _make_mat(Color(0.12, 0.12, 0.12), 0.9, 0.0) # Default unlit cold dark grey/black wick
	var mat_wire := _make_mat(Color(0.35, 0.35, 0.38), 0.4, 0.85)

	# The root origin (0,0,0) is placed at the TOP HANDLE GRIP so hand holds it naturally,
	# and the lantern body hangs down beneath it (-Y).

	# 1. Wire Bail Handle (arch looping down from grip to hood)
	var grip_bar := _create_cylinder(0.010 * scale_factor, 0.010 * scale_factor, 0.065 * scale_factor, _make_mat(Color(0.45, 0.32, 0.18), 0.8, 0.1)) # Wooden grip
	grip_bar.rotation_degrees.z = 90.0
	grip_bar.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(grip_bar)

	# Left & Right wire arms hanging down to the lantern body
	for sx in [-1.0, 1.0]:
		var wire := _create_cylinder(0.0035 * scale_factor, 0.0035 * scale_factor, 0.14 * scale_factor, mat_wire)
		wire.position = Vector3(sx * 0.048 * scale_factor, -0.065 * scale_factor, 0.0)
		wire.rotation_degrees.z = sx * -8.0
		root.add_child(wire)

	# 2. Top Vented Heat Dome Cap
	var cap_y := -0.13 * scale_factor
	var cap_hood := _create_cylinder(0.044 * scale_factor, 0.052 * scale_factor, 0.035 * scale_factor, mat_cap)
	cap_hood.position = Vector3(0.0, cap_y, 0.0)
	root.add_child(cap_hood)

	var chimney_cap := _create_cylinder(0.024 * scale_factor, 0.024 * scale_factor, 0.022 * scale_factor, mat_metal)
	chimney_cap.position = Vector3(0.0, cap_y + 0.026 * scale_factor, 0.0)
	root.add_child(chimney_cap)

	# 3. Cylindrical Glass Chimney / Globe
	var globe_y := cap_y - 0.055 * scale_factor
	var globe := _create_cylinder(0.038 * scale_factor, 0.038 * scale_factor, 0.082 * scale_factor, mat_glass)
	globe.name = "Globe"
	globe.position = Vector3(0.0, globe_y, 0.0)
	root.add_child(globe)

	# 4. Glowing Internal Wick / Mantle
	var wick := _create_cylinder(0.009 * scale_factor, 0.009 * scale_factor, 0.036 * scale_factor, mat_mantle)
	wick.name = "Wick"
	wick.position = Vector3(0.0, globe_y, 0.0)
	root.add_child(wick)

	# 5. Base Fuel Reservoir Tank
	var base_y := globe_y - 0.062 * scale_factor
	var tank := _create_cylinder(0.052 * scale_factor, 0.052 * scale_factor, 0.048 * scale_factor, mat_metal)
	tank.position = Vector3(0.0, base_y, 0.0)
	root.add_child(tank)

	root.set_meta("globe_mesh", globe)
	root.set_meta("wick_mesh", wick)
	root.set_meta("item_mode", "lantern")
	# OmniLight attachment center (inside the globe)
	root.set_meta("light_offset", Vector3(0.0, globe_y, 0.0))
	return root


## Updates the physical lens/mantle appearance: dark grey or black when turned off, glowing emissive when turned on.
static func set_item_light_state(item_root: Node3D, is_active: bool, mode: String = "") -> void:
	if not item_root or not is_instance_valid(item_root):
		return

	var item_mode: String = mode.to_lower()
	if item_mode.is_empty() and item_root.has_meta("item_mode"):
		item_mode = str(item_root.get_meta("item_mode"))

	if item_mode == "lantern":
		var globe: MeshInstance3D = item_root.get_meta("globe_mesh", null) if item_root.has_meta("globe_mesh") else null
		var wick: MeshInstance3D = item_root.get_meta("wick_mesh", null) if item_root.has_meta("wick_mesh") else null

		if globe and is_instance_valid(globe):
			var mat_g := StandardMaterial3D.new()
			mat_g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if is_active:
				mat_g.albedo_color = Color(1.0, 0.92, 0.65, 0.45) # Warm glowing glass
				mat_g.roughness = 0.15
			else:
				mat_g.albedo_color = Color(0.18, 0.18, 0.20, 0.35) # Dark grey tinted unlit glass
				mat_g.roughness = 0.25
			mat_g.cull_mode = BaseMaterial3D.CULL_BACK
			globe.material_override = mat_g

		if wick and is_instance_valid(wick):
			var mat_w := StandardMaterial3D.new()
			if is_active:
				mat_w.albedo_color = Color(1.0, 0.85, 0.45)
				mat_w.emission_enabled = true
				mat_w.emission = Color(1.0, 0.82, 0.45) * 2.2
				mat_w.roughness = 0.1
			else:
				mat_w.albedo_color = Color(0.10, 0.10, 0.10) # Dark charcoal black extinguished wick
				mat_w.emission_enabled = false
				mat_w.roughness = 0.9
			mat_w.cull_mode = BaseMaterial3D.CULL_BACK
			wick.material_override = mat_w
		return

	# Flashlights (normal, crank, uv, battery):
	var lens: MeshInstance3D = item_root.get_meta("lens_mesh", null) if item_root.has_meta("lens_mesh") else null
	if not lens or not is_instance_valid(lens):
		lens = item_root.find_child("Lens", true, false) as MeshInstance3D
	if not lens or not is_instance_valid(lens):
		return

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	if not is_active:
		# Dark grey or black when turned off from all of the light source tools
		mat.albedo_color = Color(0.11, 0.11, 0.13) # Dark charcoal black unlit glass lens
		mat.roughness = 0.25
		mat.metallic = 0.15
		mat.emission_enabled = false
	else:
		match item_mode:
			"uv":
				mat.albedo_color = Color(0.42, 0.12, 0.75)
				mat.roughness = 0.1
				mat.metallic = 0.1
				mat.emission_enabled = true
				mat.emission = Color(0.68, 0.25, 0.98) * 1.8
			"crank":
				mat.albedo_color = Color(0.95, 0.98, 1.0)
				mat.roughness = 0.1
				mat.metallic = 0.05
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.96, 0.88) * 1.5
			_:
				# "normal", "battery", and default
				mat.albedo_color = Color(1.0, 0.98, 0.90)
				mat.roughness = 0.1
				mat.metallic = 0.1
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.96, 0.85) * 1.5
	lens.material_override = mat


static func build_fp_arm(skin_col: Color, sleeve_col: Color, is_left: bool = false) -> Node3D:
	var arm_root := Node3D.new()
	arm_root.name = "LeftArm" if is_left else "RightArm"
	var sx: float = -1.0 if is_left else 1.0

	var mat_skin := _make_mat(skin_col, 0.85, 0.05)
	var mat_sleeve := _make_mat(sleeve_col, 0.88, 0.05)

	# Forearm sleeve (angled forward/inward into the screen)
	var forearm := _create_box(Vector3(0.070, 0.070, 0.22), mat_sleeve)
	forearm.position = Vector3(sx * 0.04, -0.02, 0.10)
	forearm.rotation_degrees = Vector3(14.0, sx * -16.0, sx * 12.0)
	arm_root.add_child(forearm)

	# Wrist cuff / transition
	var wrist := _create_box(Vector3(0.064, 0.060, 0.04), mat_skin)
	wrist.position = Vector3(0.0, 0.0, -0.01)
	arm_root.add_child(wrist)

	# Hand palm & fingers in grip pose
	var palm := _create_box(Vector3(0.058, 0.068, 0.075), mat_skin)
	palm.position = Vector3(0.0, 0.0, -0.045)
	arm_root.add_child(palm)

	# Curled fingers wrapped around handle
	var fingers := _create_box(Vector3(0.062, 0.052, 0.048), mat_skin)
	fingers.position = Vector3(sx * -0.012, -0.015, -0.052)
	arm_root.add_child(fingers)

	# Thumb resting on top / side
	var thumb := _create_box(Vector3(0.022, 0.022, 0.042), mat_skin)
	thumb.position = Vector3(sx * 0.026, 0.024, -0.038)
	thumb.rotation_degrees = Vector3(18.0, sx * 22.0, 0.0)
	arm_root.add_child(thumb)

	return arm_root


# --- Internal Mesh Helpers ---
static func _make_mat(col: Color, roughness: float = 0.8, metallic: float = 0.0, emission_col: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_col != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission_col
	return mat


static func _create_box(box_size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _create_cylinder(r_top: float, r_bot: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = h
	cyl.radial_segments = 14
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
