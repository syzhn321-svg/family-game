@tool
class_name HouseEnvironment
extends Node3D

## Procedural Builder for Escape Mode:
## - House Structure Fixes (Ceilings, hipped roof, parquet/tile floors, plaster walls, back door, room lights)
## - Surrounding 1.5m Brick Wall (10m setback on all sides) with Front Main Gate and Back Main Gate
## - 100-Meter Path leading from the Main Road into the Front Gate
## - Main Road (asphalt highway at Z = -126m) with road markings, guardrails, and streetlights
## - Ground plane and tropical roadside foliage

const TEXTURE_DIR := "res://assets/textures/house/"
const HOUSE_DECORATIONS_SCRIPT := preload("res://scripts/house_decorations.gd")

# Preloaded Textures
var tex_brick: Texture2D
var tex_road: Texture2D
var tex_gravel: Texture2D
var tex_wood: Texture2D
var tex_tiles: Texture2D
var tex_wall: Texture2D
var tex_roof: Texture2D
var tex_grass: Texture2D

# Materials
var mat_brick: StandardMaterial3D
var mat_brick_coping: StandardMaterial3D
var mat_road: StandardMaterial3D
var mat_gravel: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_tiles: StandardMaterial3D
var mat_wall: StandardMaterial3D
var mat_roof: StandardMaterial3D
var mat_grass: StandardMaterial3D
var mat_metal_dark: StandardMaterial3D
var mat_wood_trim: StandardMaterial3D
var mat_concrete: StandardMaterial3D
var mat_lamp_glow: StandardMaterial3D

# Compound Boundary Coordinates (Calculated with 10m setback from house)
# House AABB: X [-7.98, 40.11], Z [-15.72, 23.55], Center (16.07, 3.91)
const WALL_FRONT_Z: float = -26.0
const WALL_BACK_Z: float  =  34.0
const WALL_LEFT_X: float  = -18.0
const WALL_RIGHT_X: float =  50.0
const WALL_HEIGHT: float  =   1.5
const WALL_THICK: float   =   0.30

# Road & Path Coordinates
# 100 meters path from Road to Front Gate
const ROAD_Z: float = -126.0   # WALL_FRONT_Z (-26.0) - 100.0m = -126.0m
const ROAD_WIDTH: float = 8.0
const PATH_WIDTH: float = 5.6
const GATE_CENTER_X: float = 16.0
const FRONT_GATE_WIDTH: float = 6.0
const BACK_GATE_WIDTH: float = 5.0


func _init() -> void:
	name = "HouseEnvironment"
	_load_textures_and_materials()


func build(main_node: Node3D) -> void:
	var home_node: Node3D = main_node if main_node.name == "home" else main_node.get_node_or_null("home")
	if home_node:
		_fix_house_structure(home_node)
	_build_ground(main_node)
	_build_perimeter_brick_walls(main_node)
	_build_path_and_road(main_node)
	_build_foliage(main_node)
	_setup_mood_lighting(main_node)
	# Build interior decorations and exterior structures if not already instanced in scene
	if main_node.get_node_or_null("HouseFurniture") == null and main_node.get_node_or_null("DecorationsRoot") == null:
		var dec = HOUSE_DECORATIONS_SCRIPT.new()
		dec.build(main_node, home_node)


func _load_textures_and_materials() -> void:
	tex_brick  = _get_texture("brick_wall.png")
	tex_road   = _get_texture("asphalt_road.png")
	tex_gravel = _get_texture("path_gravel.png")
	tex_wood   = _get_texture("floor_wood.png")
	tex_tiles  = _get_texture("floor_tiles.png")
	tex_wall   = _get_texture("wall_plaster.png")
	tex_roof   = _get_texture("roof_tiles.png")
	tex_grass  = _get_texture("grass_ground.png")

	mat_brick = StandardMaterial3D.new()
	mat_brick.albedo_texture = tex_brick
	mat_brick.uv1_scale = Vector3(3.5, 1.2, 3.5)
	mat_brick.roughness = 0.92

	mat_brick_coping = StandardMaterial3D.new()
	mat_brick_coping.albedo_color = Color(0.82, 0.80, 0.76)
	mat_brick_coping.roughness = 0.85

	mat_road = StandardMaterial3D.new()
	mat_road.albedo_texture = tex_road
	mat_road.uv1_scale = Vector3(25.0, 1.0, 1.0)
	mat_road.roughness = 0.88

	mat_gravel = StandardMaterial3D.new()
	mat_gravel.albedo_texture = tex_gravel
	mat_gravel.uv1_scale = Vector3(2.0, 10.0, 2.0)
	mat_gravel.roughness = 0.95

	mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_texture = tex_wood
	mat_wood.uv1_scale = Vector3(2.5, 2.5, 2.5)
	mat_wood.roughness = 0.82

	mat_tiles = StandardMaterial3D.new()
	mat_tiles.albedo_texture = tex_tiles
	mat_tiles.uv1_scale = Vector3(2.0, 2.0, 2.0)
	mat_tiles.roughness = 0.65

	mat_wall = StandardMaterial3D.new()
	mat_wall.albedo_texture = tex_wall
	mat_wall.uv1_scale = Vector3(3.0, 3.0, 3.0)
	mat_wall.roughness = 0.88

	mat_roof = StandardMaterial3D.new()
	mat_roof.albedo_texture = tex_roof
	mat_roof.uv1_scale = Vector3(4.0, 4.0, 4.0)
	mat_roof.roughness = 0.90

	mat_grass = StandardMaterial3D.new()
	mat_grass.albedo_texture = tex_grass
	mat_grass.uv1_scale = Vector3(18.0, 18.0, 18.0)
	mat_grass.roughness = 0.96

	mat_metal_dark = StandardMaterial3D.new()
	mat_metal_dark.albedo_color = Color(0.12, 0.13, 0.14)
	mat_metal_dark.metallic = 0.6
	mat_metal_dark.roughness = 0.45

	mat_wood_trim = StandardMaterial3D.new()
	mat_wood_trim.albedo_color = Color(0.24, 0.16, 0.10)
	mat_wood_trim.roughness = 0.75

	mat_concrete = StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.68, 0.66, 0.62)
	mat_concrete.roughness = 0.90

	mat_lamp_glow = StandardMaterial3D.new()
	mat_lamp_glow.albedo_color = Color(1.0, 0.92, 0.75)
	mat_lamp_glow.emission_enabled = true
	mat_lamp_glow.emission = Color(1.0, 0.92, 0.75)
	mat_lamp_glow.emission_energy_multiplier = 2.5


func _get_texture(filename: String) -> Texture2D:
	var path := TEXTURE_DIR + filename
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path)
	return null


# ==============================================================================
# 1. FIX HOUSE STRUCTURE (Ceilings, Roof, Materials, Back Door, Room Lighting)
# ==============================================================================
func _fix_house_structure(home_node: Node3D) -> void:
	var wf := home_node.get_node_or_null("walls and floors")
	if wf:
		for child in wf.get_children():
			if not (child is MeshInstance3D):
				continue
			var mi: MeshInstance3D = child
			if "Plane" in mi.name:
				# Apply tile floor to kitchen/bathrooms/backrooms, wood parquet to living/bedrooms
				if mi.name in ["Plane_005", "Plane_006", "Plane_010", "Plane_011", "Plane_016", "Plane_017"]:
					mi.material_override = mat_tiles
				else:
					mi.material_override = mat_wood
			elif "Cube" in mi.name:
				# Apply plastered wall material
				mi.material_override = mat_wall

	# Add Back Door at rear kitchen exit doorway (Room 16)
	var door_scene := preload("res://scenes/door.tscn")
	var back_door := door_scene.instantiate()
	back_door.name = "back_door"
	# At home local coordinates (Room 16 rear wall): 34.425 / 0.45 = 76.5, 0.96 / 0.45 = 2.13, 22.8 / 0.45 = 50.67
	back_door.position = Vector3(76.5, 2.13, 50.67)
	back_door.rotation_degrees.y = 180.0
	home_node.add_child(back_door)

	# --- Construct Ceilings and Complete Roof Structure ---
	# The house top of walls in main global space is Y = 5.55m.
	# In home local space (scaled by 0.45), Y = 5.55 / 0.45 = 12.33m.
	# We construct an interior ceiling slab + exterior hipped roof with overhangs.
	var roof_node := Node3D.new()
	roof_node.name = "RoofStructure"
	home_node.add_child(roof_node)

	# Interior Ceiling Slab (covers all rooms at local Y = 12.18m, underside is warm off-white ceiling)
	var ceiling_mesh := BoxMesh.new()
	ceiling_mesh.size = Vector3(126.0, 0.8, 106.0)
	var mat_ceiling := StandardMaterial3D.new()
	mat_ceiling.albedo_color = Color(0.88, 0.86, 0.82)
	mat_ceiling.roughness = 0.90
	ceiling_mesh.material = mat_ceiling
	var ceiling_mi := MeshInstance3D.new()
	ceiling_mi.mesh = ceiling_mesh
	ceiling_mi.position = Vector3(35.7, 12.18, 8.7)
	roof_node.add_child(ceiling_mi)

	# Front Car Porch Support Pillars (supports roof overhang over front driveway)
	# In local space (divided by 0.45): X = 12.0/0.45 = 26.67, 24.0/0.45 = 53.33, Z = -15.5/0.45 = -34.44
	var porch_pillar_l := _create_box(Vector3(1.2, 12.0, 1.2), mat_concrete, Vector3(26.0, 6.0, -32.0))
	var porch_pillar_r := _create_box(Vector3(1.2, 12.0, 1.2), mat_concrete, Vector3(48.0, 6.0, -32.0))
	roof_node.add_child(porch_pillar_l)
	roof_node.add_child(porch_pillar_r)

	# Exterior Roof Fascia / Eaves Trim (dark timber overhang framing the entire roof perimeter)
	var fascia_mesh := BoxMesh.new()
	fascia_mesh.size = Vector3(115.0, 0.8, 95.0)
	fascia_mesh.material = mat_wood_trim
	var fascia_mi := MeshInstance3D.new()
	fascia_mi.mesh = fascia_mesh
	fascia_mi.position = Vector3(35.7, 12.55, 8.7)
	roof_node.add_child(fascia_mi)

	# Exterior Hipped Clay Shingle Roof Structure
	# Main roof base tier
	var r_tier1 := MeshInstance3D.new()
	var b_tier1 := BoxMesh.new()
	b_tier1.size = Vector3(110.0, 1.4, 90.0)
	b_tier1.material = mat_roof
	r_tier1.mesh = b_tier1
	r_tier1.position = Vector3(35.7, 13.5, 8.7)
	roof_node.add_child(r_tier1)

	# Mid hipped roof tier
	var r_tier2 := MeshInstance3D.new()
	var b_tier2 := BoxMesh.new()
	b_tier2.size = Vector3(92.0, 1.8, 72.0)
	b_tier2.material = mat_roof
	r_tier2.mesh = b_tier2
	r_tier2.position = Vector3(35.7, 14.9, 8.7)
	roof_node.add_child(r_tier2)

	# Roof ridge crown
	var r_ridge := MeshInstance3D.new()
	var b_ridge := BoxMesh.new()
	b_ridge.size = Vector3(70.0, 1.6, 50.0)
	b_ridge.material = mat_roof
	r_ridge.mesh = b_ridge
	r_ridge.position = Vector3(35.7, 16.4, 8.7)
	roof_node.add_child(r_ridge)

	# Ridge cap peak
	var r_peak := MeshInstance3D.new()
	var b_peak := BoxMesh.new()
	b_peak.size = Vector3(48.0, 0.9, 28.0)
	b_peak.material = mat_roof
	r_peak.mesh = b_peak
	r_peak.position = Vector3(35.7, 17.5, 8.7)
	roof_node.add_child(r_peak)

	# --- Interior Room Lighting ---
	# In world coordinates (scale 0.45 applied)
	var lights_group := Node3D.new()
	lights_group.name = "HouseLights"
	home_node.add_child(lights_group)

	var room_lights := [
		# Living Room Hall (Plane_014)
		{"pos": Vector3(23.08, 10.5, -2.35), "col": Color(1.0, 0.88, 0.70), "energy": 1.4, "range": 22.0},
		# Right Family Hall (Plane_019)
		{"pos": Vector3(62.47, 10.5, 13.58), "col": Color(1.0, 0.85, 0.65), "energy": 1.3, "range": 24.0},
		# Left Front Bedroom (Plane_002)
		{"pos": Vector3(-3.51, 10.5, -12.70), "col": Color(0.95, 0.82, 0.68), "energy": 1.1, "range": 16.0},
		# Left Mid Bedroom (Plane_003)
		{"pos": Vector3(-3.51, 10.5, 3.80), "col": Color(0.95, 0.82, 0.68), "energy": 1.1, "range": 16.0},
		# Back Kitchen / Dining (Plane_006)
		{"pos": Vector3(29.84, 10.5, 42.55), "col": Color(1.0, 0.92, 0.80), "energy": 1.3, "range": 18.0},
		# Back Right Bedroom (Plane_020)
		{"pos": Vector3(79.09, 10.5, 43.34), "col": Color(0.95, 0.80, 0.65), "energy": 1.1, "range": 16.0},
		# Front Porch Light (above front door)
		{"pos": Vector3(9.02, 6.2, -8.5), "col": Color(1.0, 0.82, 0.55), "energy": 1.5, "range": 14.0},
		# Back Porch Light (above Room 16 kitchen back door)
		{"pos": Vector3(76.5, 6.2, 53.5), "col": Color(1.0, 0.82, 0.55), "energy": 1.5, "range": 14.0},
	]

	for ld in room_lights:
		var lt := OmniLight3D.new()
		lt.position = ld["pos"]
		lt.light_color = ld["col"]
		lt.light_energy = ld["energy"]
		lt.omni_range = ld["range"]
		lt.omni_attenuation = 1.35
		lt.shadow_enabled = true
		lights_group.add_child(lt)

		# Visual ceiling light fixture bulb
		var bulb := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.35
		s_mesh.height = 0.55
		s_mesh.material = mat_lamp_glow
		bulb.mesh = s_mesh
		bulb.position = ld["pos"] + Vector3(0.0, 0.8, 0.0)
		lights_group.add_child(bulb)


# ==============================================================================
# 2. PERIMETER BRICK WALL & GATES (1.5m tall, 10m setback, Front & Back Gates)
# ==============================================================================
func _build_perimeter_brick_walls(parent: Node3D) -> void:
	var wall_root := StaticBody3D.new()
	wall_root.name = "PerimeterBrickWall"
	parent.add_child(wall_root)

	var y_wall_center := WALL_HEIGHT * 0.5  # 0.75m

	# --- LEFT WALL (X = WALL_LEFT_X = -18.0, Z from -26.0 to +34.0, length = 60.0m) ---
	_add_wall_segment(wall_root,
		Vector3(WALL_LEFT_X, y_wall_center, (WALL_FRONT_Z + WALL_BACK_Z) * 0.5),
		Vector3(WALL_THICK, WALL_HEIGHT, (WALL_BACK_Z - WALL_FRONT_Z) + WALL_THICK)
	)

	# --- RIGHT WALL (X = WALL_RIGHT_X = 50.0, Z from -26.0 to +34.0, length = 60.0m) ---
	_add_wall_segment(wall_root,
		Vector3(WALL_RIGHT_X, y_wall_center, (WALL_FRONT_Z + WALL_BACK_Z) * 0.5),
		Vector3(WALL_THICK, WALL_HEIGHT, (WALL_BACK_Z - WALL_FRONT_Z) + WALL_THICK)
	)

	# --- FRONT WALL (Z = WALL_FRONT_Z = -26.0) with FRONT MAIN GATE ---
	# Gate opening is from (GATE_CENTER_X - FRONT_GATE_WIDTH/2) to (GATE_CENTER_X + FRONT_GATE_WIDTH/2)
	# i.e. X = 13.0m to X = 19.0m
	var f_gate_left_x  := GATE_CENTER_X - FRONT_GATE_WIDTH * 0.5  # 13.0m
	var f_gate_right_x := GATE_CENTER_X + FRONT_GATE_WIDTH * 0.5  # 19.0m

	# Front Wall Left Segment (from WALL_LEFT_X to f_gate_left_x: -18.0 to 13.0, len = 31.0m)
	var f_left_len := f_gate_left_x - WALL_LEFT_X
	_add_wall_segment(wall_root,
		Vector3(WALL_LEFT_X + f_left_len * 0.5, y_wall_center, WALL_FRONT_Z),
		Vector3(f_left_len, WALL_HEIGHT, WALL_THICK)
	)

	# Front Wall Right Segment (from f_gate_right_x to WALL_RIGHT_X: 19.0 to 50.0, len = 31.0m)
	var f_right_len := WALL_RIGHT_X - f_gate_right_x
	_add_wall_segment(wall_root,
		Vector3(f_gate_right_x + f_right_len * 0.5, y_wall_center, WALL_FRONT_Z),
		Vector3(f_right_len, WALL_HEIGHT, WALL_THICK)
	)

	# Front Main Gate Structure (Pillars, Caps, Lanterns, Iron Gate panels)
	_build_main_gate(parent, WALL_FRONT_Z, f_gate_left_x, f_gate_right_x, "FrontMainGate", true)

	# --- BACK WALL (Z = WALL_BACK_Z = 34.0) with BACK MAIN GATE ---
	var b_gate_left_x  := GATE_CENTER_X - BACK_GATE_WIDTH * 0.5  # 13.5m
	var b_gate_right_x := GATE_CENTER_X + BACK_GATE_WIDTH * 0.5  # 18.5m

	# Back Wall Left Segment (from WALL_LEFT_X to b_gate_left_x: -18.0 to 13.5, len = 31.5m)
	var b_left_len := b_gate_left_x - WALL_LEFT_X
	_add_wall_segment(wall_root,
		Vector3(WALL_LEFT_X + b_left_len * 0.5, y_wall_center, WALL_BACK_Z),
		Vector3(b_left_len, WALL_HEIGHT, WALL_THICK)
	)

	# Back Wall Right Segment (from b_gate_right_x to WALL_RIGHT_X: 18.5 to 50.0, len = 31.5m)
	var b_right_len := WALL_RIGHT_X - b_gate_right_x
	_add_wall_segment(wall_root,
		Vector3(b_gate_right_x + b_right_len * 0.5, y_wall_center, WALL_BACK_Z),
		Vector3(b_right_len, WALL_HEIGHT, WALL_THICK)
	)

	# Back Main Gate Structure
	_build_main_gate(parent, WALL_BACK_Z, b_gate_left_x, b_gate_right_x, "BackMainGate", false)


func _add_wall_segment(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	# Brick wall body
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat_brick
	mi.mesh = bm
	mi.position = center
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	body.add_child(cs)

	# Decorative concrete coping slab on top of the 1.5m brick wall
	var coping_mi := MeshInstance3D.new()
	var coping_mesh := BoxMesh.new()
	# Coping extends 4cm wider on sides
	var cop_size := Vector3(
		size.x + (0.08 if size.z > size.x else 0.0),
		0.08,
		size.z + (0.08 if size.x > size.z else 0.0)
	)
	coping_mesh.size = cop_size
	coping_mesh.material = mat_brick_coping
	coping_mi.mesh = coping_mesh
	coping_mi.position = center + Vector3(0.0, size.y * 0.5 + 0.04, 0.0)
	body.add_child(coping_mi)


func _build_main_gate(parent: Node3D, z_pos: float, left_x: float, right_x: float, gate_name: String, has_lights: bool) -> void:
	var gate_root := Node3D.new()
	gate_root.name = gate_name
	parent.add_child(gate_root)

	var pillar_w := 0.70
	var pillar_h := 1.90
	var pillar_d := 0.70

	# Left Pillar
	_create_gate_pillar(gate_root, Vector3(left_x, pillar_h * 0.5, z_pos), Vector3(pillar_w, pillar_h, pillar_d), has_lights)
	# Right Pillar
	_create_gate_pillar(gate_root, Vector3(right_x, pillar_h * 0.5, z_pos), Vector3(pillar_w, pillar_h, pillar_d), has_lights)

	# Wrought Iron Gates (left and right leaf, slightly swung open inward into compound)
	var leaf_w := (right_x - left_x) * 0.48
	var leaf_h := 1.55
	var leaf_thick := 0.06

	# Left Gate leaf hinged at left pillar, rotated inward -25 degrees
	var gate_l := _create_iron_gate_leaf(leaf_w, leaf_h, leaf_thick)
	gate_l.position = Vector3(left_x + 0.25, 0.05, z_pos)
	gate_l.rotation_degrees.y = 25.0 if z_pos < 0.0 else -25.0
	gate_root.add_child(gate_l)

	# Right Gate leaf hinged at right pillar, rotated inward +25 degrees
	var gate_r := _create_iron_gate_leaf(leaf_w, leaf_h, leaf_thick)
	gate_r.position = Vector3(right_x - 0.25, 0.05, z_pos)
	gate_r.rotation_degrees.y = -25.0 if z_pos < 0.0 else 25.0
	gate_root.add_child(gate_r)


func _create_gate_pillar(parent: Node3D, pos: Vector3, size: Vector3, with_light: bool) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)

	# Sturdy brick pillar
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat_brick
	mi.mesh = bm
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)

	# Pyramid / tiered concrete pier cap
	var cap1 := MeshInstance3D.new()
	var c1_mesh := BoxMesh.new()
	c1_mesh.size = Vector3(size.x + 0.14, 0.12, size.z + 0.14)
	c1_mesh.material = mat_brick_coping
	cap1.mesh = c1_mesh
	cap1.position = Vector3(0.0, size.y * 0.5 + 0.06, 0.0)
	body.add_child(cap1)

	var cap2 := MeshInstance3D.new()
	var c2_mesh := BoxMesh.new()
	c2_mesh.size = Vector3(size.x * 0.65, 0.10, size.z * 0.65)
	c2_mesh.material = mat_brick_coping
	cap2.mesh = c2_mesh
	cap2.position = Vector3(0.0, size.y * 0.5 + 0.17, 0.0)
	body.add_child(cap2)

	# Cast iron gate lantern perched on the pier cap
	if with_light:
		var lantern_base := MeshInstance3D.new()
		var l_mesh := BoxMesh.new()
		l_mesh.size = Vector3(0.24, 0.32, 0.24)
		l_mesh.material = mat_lamp_glow
		lantern_base.mesh = l_mesh
		lantern_base.position = Vector3(0.0, size.y * 0.5 + 0.38, 0.0)
		body.add_child(lantern_base)

		var l_cap := MeshInstance3D.new()
		var lc_mesh := BoxMesh.new()
		lc_mesh.size = Vector3(0.30, 0.08, 0.30)
		lc_mesh.material = mat_metal_dark
		l_cap.mesh = lc_mesh
		l_cap.position = Vector3(0.0, size.y * 0.5 + 0.58, 0.0)
		body.add_child(l_cap)

		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0, 0.88, 0.65)
		omni.light_energy = 1.35
		omni.omni_range = 10.0
		omni.omni_attenuation = 1.2
		omni.shadow_enabled = true
		omni.position = Vector3(0.0, size.y * 0.5 + 0.42, 0.0)
		body.add_child(omni)


func _create_iron_gate_leaf(width: float, height: float, thick: float) -> Node3D:
	var leaf := Node3D.new()

	# Outer rectangular steel frame
	var top_bar := _create_box(Vector3(width, 0.05, thick), mat_metal_dark, Vector3(width * 0.5, height - 0.025, 0.0))
	var bot_bar := _create_box(Vector3(width, 0.06, thick), mat_metal_dark, Vector3(width * 0.5, 0.03, 0.0))
	var mid_bar := _create_box(Vector3(width, 0.04, thick), mat_metal_dark, Vector3(width * 0.5, height * 0.52, 0.0))
	var post_l  := _create_box(Vector3(0.06, height, thick), mat_metal_dark, Vector3(0.03, height * 0.5, 0.0))
	var post_r  := _create_box(Vector3(0.06, height, thick), mat_metal_dark, Vector3(width - 0.03, height * 0.5, 0.0))

	leaf.add_child(top_bar)
	leaf.add_child(bot_bar)
	leaf.add_child(mid_bar)
	leaf.add_child(post_l)
	leaf.add_child(post_r)

	# Vertical decorative pickets
	var n_pickets := int(width / 0.18)
	for i in range(1, n_pickets):
		var px := i * (width / float(n_pickets))
		var picket := _create_box(Vector3(0.022, height * 0.96, thick * 0.8), mat_metal_dark, Vector3(px, height * 0.50, 0.0))
		leaf.add_child(picket)
		# Spear spearhead point
		var tip := _create_box(Vector3(0.034, 0.06, thick * 0.9), mat_metal_dark, Vector3(px, height + 0.03, 0.0))
		leaf.add_child(tip)

	return leaf


# ==============================================================================
# 3. 100-METER PATH & MAIN ROAD (Beside the road, 100m path to house)
# ==============================================================================
func _build_path_and_road(parent: Node3D) -> void:
	var path_root := StaticBody3D.new()
	path_root.name = "PathAndRoad"
	parent.add_child(path_root)

	# --- 100-METER PATH (Driveway) ---
	# Starts at the road (ROAD_Z = -126.0m) and ends at the Front Gate (WALL_FRONT_Z = -26.0m)
	# Length = 100.0 meters!
	var path_len := WALL_FRONT_Z - ROAD_Z  # 100.0m
	var path_mid_z := (WALL_FRONT_Z + ROAD_Z) * 0.5 # -76.0m

	var path_mesh := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(PATH_WIDTH, 0.12, path_len)
	p_box.material = mat_gravel
	path_mesh.mesh = p_box
	path_mesh.position = Vector3(GATE_CENTER_X, 0.06, path_mid_z)
	path_root.add_child(path_mesh)

	var p_col := CollisionShape3D.new()
	var pc_box := BoxShape3D.new()
	pc_box.size = Vector3(PATH_WIDTH, 0.12, path_len)
	p_col.shape = pc_box
	p_col.position = Vector3(GATE_CENTER_X, 0.06, path_mid_z)
	path_root.add_child(p_col)

	# Stone/grass verges lining both sides of the 100-meter path
	var verge_l := _create_box(Vector3(0.35, 0.16, path_len), mat_concrete, Vector3(GATE_CENTER_X - PATH_WIDTH * 0.5 - 0.175, 0.08, path_mid_z))
	var verge_r := _create_box(Vector3(0.35, 0.16, path_len), mat_concrete, Vector3(GATE_CENTER_X + PATH_WIDTH * 0.5 + 0.175, 0.08, path_mid_z))
	path_root.add_child(verge_l)
	path_root.add_child(verge_r)

	# --- Streetlight Utility Poles along the 100-meter path ---
	# Spaced every 25m: at Z = -110m, -85m, -60m, -35m
	var pole_zs := [-110.0, -85.0, -60.0, -35.0]
	for pz in pole_zs:
		_create_roadside_streetlight(parent, Vector3(GATE_CENTER_X - PATH_WIDTH * 0.5 - 1.2, 0.0, pz), true)

	# --- MAIN ROAD (Tarmac Highway at ROAD_Z = -126.0m) ---
	# Runs perpendicular (along X) from X = -80.0m to X = +120.0m (length = 200m)
	var road_len := 200.0
	var road_mid_x := 20.0

	var road_mesh := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(road_len, 0.14, ROAD_WIDTH)
	r_box.material = mat_road
	road_mesh.mesh = r_box
	road_mesh.position = Vector3(road_mid_x, 0.07, ROAD_Z)
	path_root.add_child(road_mesh)

	var road_col := CollisionShape3D.new()
	var rc_box := BoxShape3D.new()
	rc_box.size = Vector3(road_len, 0.14, ROAD_WIDTH)
	road_col.shape = rc_box
	road_col.position = Vector3(road_mid_x, 0.07, ROAD_Z)
	path_root.add_child(road_col)

	# Roadside Guardrails along the road edges (with gap for the driveway entrance)
	_build_road_guardrails(path_root, road_len, road_mid_x, ROAD_Z)

	# Rural Entrance Signboard at the junction of Road and 100m path
	_create_entrance_signboard(parent, Vector3(GATE_CENTER_X + PATH_WIDTH * 0.5 + 1.8, 0.0, ROAD_Z + 4.5))


func _create_roadside_streetlight(parent: Node3D, pos: Vector3, cast_light: bool) -> void:
	var pole_root := Node3D.new()
	pole_root.position = pos
	parent.add_child(pole_root)

	var pole_h := 6.5
	var pole := _create_box(Vector3(0.24, pole_h, 0.24), mat_wood_trim, Vector3(0.0, pole_h * 0.5, 0.0))
	pole_root.add_child(pole)

	# Curved metal arm reaching out toward the path
	var arm := _create_box(Vector3(1.8, 0.08, 0.08), mat_metal_dark, Vector3(0.9, pole_h - 0.2, 0.0))
	pole_root.add_child(arm)

	# Cobra-head lamp fixture
	var lamp := _create_box(Vector3(0.55, 0.18, 0.30), mat_metal_dark, Vector3(1.7, pole_h - 0.3, 0.0))
	pole_root.add_child(lamp)

	var bulb := _create_box(Vector3(0.38, 0.06, 0.20), mat_lamp_glow, Vector3(1.7, pole_h - 0.40, 0.0))
	pole_root.add_child(bulb)

	if cast_light:
		var spot := SpotLight3D.new()
		spot.position = Vector3(1.7, pole_h - 0.45, 0.0)
		spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		spot.light_color = Color(1.0, 0.88, 0.65)
		spot.light_energy = 2.2
		spot.spot_range = 14.0
		spot.spot_angle = 54.0
		spot.shadow_enabled = true
		pole_root.add_child(spot)


func _build_road_guardrails(body: StaticBody3D, road_len: float, road_x: float, road_z: float) -> void:
	var rail_mat := mat_metal_dark
	var hw := ROAD_WIDTH * 0.5

	# Far side guardrail (Z = road_z - hw - 0.3)
	var far_rail := _create_box(Vector3(road_len, 0.70, 0.15), rail_mat, Vector3(road_x, 0.45, road_z - hw - 0.25))
	body.add_child(far_rail)

	# Near side guardrail with gap for the 100m path driveway (X: 13.0 to 19.0)
	var gap_l := GATE_CENTER_X - PATH_WIDTH * 0.5 - 0.5 # 12.7
	var gap_r := GATE_CENTER_X + PATH_WIDTH * 0.5 + 0.5 # 19.3
	var left_len := gap_l - (road_x - road_len * 0.5)
	var right_len := (road_x + road_len * 0.5) - gap_r

	var near_rail_l := _create_box(Vector3(left_len, 0.70, 0.15), rail_mat, Vector3(gap_l - left_len * 0.5, 0.45, road_z + hw + 0.25))
	var near_rail_r := _create_box(Vector3(right_len, 0.70, 0.15), rail_mat, Vector3(gap_r + right_len * 0.5, 0.45, road_z + hw + 0.25))
	body.add_child(near_rail_l)
	body.add_child(near_rail_r)


func _create_entrance_signboard(parent: Node3D, pos: Vector3) -> void:
	var sign_root := Node3D.new()
	sign_root.position = pos
	parent.add_child(sign_root)

	# Timber posts
	var post_l := _create_box(Vector3(0.12, 2.0, 0.12), mat_wood_trim, Vector3(-0.85, 1.0, 0.0))
	var post_r := _create_box(Vector3(0.12, 2.0, 0.12), mat_wood_trim, Vector3(0.85, 1.0, 0.0))
	sign_root.add_child(post_l)
	sign_root.add_child(post_r)

	# Signboard plank
	var board := _create_box(Vector3(1.85, 0.85, 0.08), mat_wood_trim, Vector3(0.0, 1.45, 0.0))
	sign_root.add_child(board)

	var label := Label3D.new()
	label.position = Vector3(0.0, 1.45, -0.05)
	label.rotation_degrees.y = 180.0
	label.pixel_size = 0.0035
	label.text = "✦ LOT 184 • KG. SUNGAI BAKAU ✦\n[ PRIVATE PROPERTY • KELUARGA SHUHA ]\nKEEP OUT"
	label.font_size = 32
	label.modulate = Color(0.92, 0.88, 0.78)
	label.outline_modulate = Color(0.1, 0.08, 0.05)
	label.outline_size = 4
	sign_root.add_child(label)


# ==============================================================================
# 4. GROUND TERRAIN & TROPICAL FOLIAGE
# ==============================================================================
func _build_ground(parent: Node3D) -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundTerrain"
	parent.add_child(ground_body)

	# Massive ground plane (X: -120 to +160, Z: -170 to +80)
	var g_size := Vector3(280.0, 0.4, 250.0)
	var g_pos  := Vector3(20.0, -0.2, -45.0)

	var g_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g_size
	bm.material = mat_grass
	g_mesh.mesh = bm
	g_mesh.position = g_pos
	ground_body.add_child(g_mesh)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = g_size
	cs.shape = bs
	cs.position = g_pos
	ground_body.add_child(cs)

	# Paved compound walkway inside the front gate to the front porch
	var walk_front := _create_box(Vector3(3.2, 0.04, 12.0), mat_concrete, Vector3(9.0, 0.02, -18.0))
	walk_front.rotation_degrees.y = -22.0
	ground_body.add_child(walk_front)

	# Paved compound walkway from Room 16 kitchen back door out into backyard
	var walk_back_exit := _create_box(Vector3(3.0, 0.04, 6.5), mat_concrete, Vector3(34.4, 0.02, 26.0))
	ground_body.add_child(walk_back_exit)

	# Cross walkway connecting kitchen path to back gate
	var walk_back_cross := _create_box(Vector3(20.0, 0.04, 2.6), mat_concrete, Vector3(25.0, 0.02, 28.5))
	ground_body.add_child(walk_back_cross)

	# Paved compound walkway leading directly to back gate
	var walk_back_gate := _create_box(Vector3(4.0, 0.04, 6.5), mat_concrete, Vector3(16.0, 0.02, 31.5))
	ground_body.add_child(walk_back_gate)


func _build_foliage(parent: Node3D) -> void:
	var foliage_root := Node3D.new()
	foliage_root.name = "TropicalFoliage"
	parent.add_child(foliage_root)

	# Tree positions along the 100m path (flanking both left and right sides)
	var path_trees := [
		Vector3(GATE_CENTER_X - PATH_WIDTH * 0.5 - 3.8, 0.0, -38.0),
		Vector3(GATE_CENTER_X + PATH_WIDTH * 0.5 + 4.2, 0.0, -48.0),
		Vector3(GATE_CENTER_X - PATH_WIDTH * 0.5 - 4.5, 0.0, -68.0),
		Vector3(GATE_CENTER_X + PATH_WIDTH * 0.5 + 3.9, 0.0, -78.0),
		Vector3(GATE_CENTER_X - PATH_WIDTH * 0.5 - 4.2, 0.0, -98.0),
		Vector3(GATE_CENTER_X + PATH_WIDTH * 0.5 + 4.5, 0.0, -108.0),
		Vector3(GATE_CENTER_X - PATH_WIDTH * 0.5 - 5.0, 0.0, -118.0),
	]

	# Tree positions surrounding the exterior perimeter wall
	var perimeter_trees := [
		# Outside Left Wall (X = -23.0)
		Vector3(-23.0, 0.0, -20.0),
		Vector3(-24.5, 0.0, -5.0),
		Vector3(-23.8, 0.0, 10.0),
		Vector3(-24.0, 0.0, 25.0),
		# Outside Right Wall (X = +55.0)
		Vector3(55.0, 0.0, -18.0),
		Vector3(56.5, 0.0, -2.0),
		Vector3(55.8, 0.0, 14.0),
		Vector3(56.2, 0.0, 28.0),
		# Outside Back Wall (Z = +40.0)
		Vector3(-10.0, 0.0, 40.0),
		Vector3(4.0, 0.0, 42.0),
		Vector3(28.0, 0.0, 41.5),
		Vector3(42.0, 0.0, 40.8),
	]

	for pos in path_trees:
		_create_coconut_palm(foliage_root, pos)
		_create_banana_bush(foliage_root, pos + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5)))

	for pos in perimeter_trees:
		_create_coconut_palm(foliage_root, pos)


func _create_coconut_palm(parent: Node3D, pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = pos
	parent.add_child(tree)

	var trunk_mat := mat_wood_trim
	var frond_mat := StandardMaterial3D.new()
	frond_mat.albedo_color = Color(0.18, 0.32, 0.14)
	frond_mat.roughness = 0.85

	# Segmented leaning trunk
	var h := 8.5 + randf_range(-1.0, 1.5)
	var lean := randf_range(3.0, 8.0)
	var trunk := _create_box(Vector3(0.38, h, 0.38), trunk_mat, Vector3(0.0, h * 0.5, 0.0))
	trunk.rotation_degrees.z = lean
	tree.add_child(trunk)

	# Palm crown fronds
	var crown_y := h
	for i in range(8):
		var ang := i * 45.0 + randf_range(-8.0, 8.0)
		var frond := _create_box(Vector3(0.45, 0.08, 3.2), frond_mat, Vector3(0.0, crown_y, 1.5))
		frond.rotation_degrees.y = ang
		frond.rotation_degrees.x = -24.0 + randf_range(-4.0, 4.0)
		tree.add_child(frond)


func _create_banana_bush(parent: Node3D, pos: Vector3) -> void:
	var bush := Node3D.new()
	bush.position = pos
	parent.add_child(bush)

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.25, 0.44, 0.18)
	leaf_mat.roughness = 0.8

	for i in range(5):
		var ang := i * 72.0
		var leaf := _create_box(Vector3(0.40, 0.04, 1.6), leaf_mat, Vector3(0.0, 0.8, 0.7))
		leaf.rotation_degrees.y = ang
		leaf.rotation_degrees.x = -32.0
		bush.add_child(leaf)


# ==============================================================================
# 5. MOOD LIGHTING & ATMOSPHERE
# ==============================================================================
func _setup_mood_lighting(parent: Node3D) -> void:
	var we: WorldEnvironment = parent.get_node_or_null("WorldEnvironment")
	if we and we.environment:
		var env := we.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.012, 0.016, 0.024)
		env.fog_enabled = true
		env.fog_light_color = Color(0.03, 0.04, 0.07)
		env.fog_density = 0.009
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.12, 0.15, 0.22)
		env.ambient_light_energy = 0.55

	var moon: DirectionalLight3D = parent.get_node_or_null("DirectionalLight3D")
	if moon:
		moon.visible = true
		moon.light_color = Color(0.68, 0.78, 0.95)
		moon.light_energy = 0.45
		moon.shadow_enabled = true
		moon.rotation_degrees = Vector3(-45.0, 35.0, 0.0)

	if not Engine.is_editor_hint() and not parent.has_node("HouseAmbiencePlayer"):
		var amb_stream := load("res://assets/audio/ambience_house_wind.wav") as AudioStreamWAV
		if amb_stream:
			amb_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			var amb_player := AudioStreamPlayer.new()
			amb_player.name = "HouseAmbiencePlayer"
			amb_player.stream = amb_stream
			amb_player.volume_db = -19.0
			amb_player.autoplay = true
			parent.add_child(amb_player)
			amb_player.play()


# ==============================================================================
# HELPER: Primitive Box Creator
# ==============================================================================
func _create_box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi
