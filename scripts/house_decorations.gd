@tool
class_name HouseDecorations
extends Node3D

## Procedural Builder for Real-Life Escape House Decorations & Furnishings:
## Accurately reflects user's real-life house layout (Lot 184, Kg. Sungai Bakau):
## 1: Master Bedroom (King-sized bed right of front door)
## 2: Bathroom & Toilet (Bi-fold accordion door to Living Room 6, cloth curtain to Master Bedroom 1)
## 3: Bedroom (Queen-sized mattress directly on floor, no bed frame)
## 4: Bathroom (Toilet & shower fixtures)
## 5 & 11: Bedroom Suite (Queen-sized bed beside side windows, adjoining wardrobe/study)
## 6: Living Room (Inside front door, TV console, sofa, shoe rack)
## 7: Guest Living Room (2-seater cushioned sofa facing Rooms 8 & 9)
## 8: Guest Living Room (1-seater & 2-seater wooden sofas facing Room 7, exterior door to garage)
## 9: Guest Living Room (3-seater wooden sofa leaning towards 8, facing away from front window)
## 10: Dining Room (Tabletop along center structure wall, circular dark brown wood dining table & chairs near right windows)
## 12: Bedroom (Wardrobe, study desk, nightstand)
## 13: Bedroom continuation (Queen-sized bed filled snugly in wall gap)
## 14: Small Toilet (Compact toilet, wash fixtures)
## 15: Bedroom (King-sized bed, wardrobe, bedside tables)
## 16: Kitchen (Double stainless steel sinks on right wall towards outside, actual back door)
## Front Yard / Car Porch: Roofed Garage beside Rooms 8 & 9 connected via Room 8 door
## Back Yard / Compound: Traditional Stone Well on lower-left, Tall Farm Animal Barn on right side

# Materials
var mat_wood_dark: StandardMaterial3D
var mat_wood_medium: StandardMaterial3D
var mat_wood_rustic: StandardMaterial3D
var mat_fabric_cushion: StandardMaterial3D
var mat_fabric_sofa_wood: StandardMaterial3D
var mat_bed_white: StandardMaterial3D
var mat_bed_blue: StandardMaterial3D
var mat_bed_green: StandardMaterial3D
var mat_mattress: StandardMaterial3D
var mat_curtain: StandardMaterial3D
var mat_accordion_door: StandardMaterial3D
var mat_porcelain: StandardMaterial3D
var mat_chrome: StandardMaterial3D
var mat_counter: StandardMaterial3D
var mat_stone_well: StandardMaterial3D
var mat_water: StandardMaterial3D
var mat_corrugated_roof: StandardMaterial3D
var mat_straw: StandardMaterial3D
var mat_metal_dark: StandardMaterial3D
var mat_lamp_warm: StandardMaterial3D
var mat_concrete: StandardMaterial3D

const FLOOR_Y: float = 0.64
const GROUND_Y: float = 0.0


func _init() -> void:
	name = "HouseDecorations"
	_init_materials()


func build(main_node: Node3D, home_node: Node3D) -> void:
	var dec_root := Node3D.new()
	dec_root.name = "DecorationsRoot"
	main_node.add_child(dec_root)

	# --- Interior Furnishings (Floor height Y = 0.64m) ---
	_build_room_1_master_bedroom(dec_root)
	_build_room_2_bathroom(dec_root)
	_build_room_3_floor_mattress_bedroom(dec_root)
	_build_room_4_bathroom(dec_root)
	_build_room_5_and_11_bedroom_suite(dec_root)
	_build_room_6_living_room(dec_root)
	_build_room_7_guest_living_room(dec_root)
	_build_room_8_guest_living_room(dec_root)
	_build_room_9_guest_living_room(dec_root)
	_build_room_10_dining_room(dec_root)
	_build_room_12_bedroom(dec_root)
	_build_room_13_gap_bed(dec_root)
	_build_room_14_small_toilet(dec_root)
	_build_room_15_bedroom(dec_root)
	_build_room_16_kitchen(dec_root)

	# --- Exterior Structures (Ground height Y = 0.0m) ---
	_build_roofed_garage(dec_root)
	_build_traditional_stone_well(dec_root)
	_build_tall_animal_barn(dec_root)

	# In Godot Editor, assign ownership to edited_scene_root so every room and furniture
	# is selectable and movable with 3D gizmos in the viewport and visible in Scene Tree dock
	if Engine.is_editor_hint():
		var scene_root: Node = main_node.get_tree().edited_scene_root if main_node.get_tree() else main_node
		if scene_root:
			_assign_ownership(dec_root, scene_root)


func _assign_ownership(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_assign_ownership(child, scene_root)


func _init_materials() -> void:
	# Dark brown wooden texture for Room 10 circular dining table and wooden sofas
	mat_wood_dark = StandardMaterial3D.new()
	mat_wood_dark.albedo_color = Color(0.22, 0.13, 0.07)
	mat_wood_dark.roughness = 0.45

	mat_wood_medium = StandardMaterial3D.new()
	mat_wood_medium.albedo_color = Color(0.48, 0.32, 0.18)
	mat_wood_medium.roughness = 0.65

	mat_wood_rustic = StandardMaterial3D.new()
	mat_wood_rustic.albedo_color = Color(0.36, 0.28, 0.20)
	mat_wood_rustic.roughness = 0.90

	mat_fabric_cushion = StandardMaterial3D.new()
	mat_fabric_cushion.albedo_color = Color(0.72, 0.68, 0.60)
	mat_fabric_cushion.roughness = 0.85

	mat_fabric_sofa_wood = StandardMaterial3D.new()
	mat_fabric_sofa_wood.albedo_color = Color(0.55, 0.25, 0.18)
	mat_fabric_sofa_wood.roughness = 0.80

	mat_bed_white = StandardMaterial3D.new()
	mat_bed_white.albedo_color = Color(0.92, 0.91, 0.88)
	mat_bed_white.roughness = 0.75

	mat_bed_blue = StandardMaterial3D.new()
	mat_bed_blue.albedo_color = Color(0.24, 0.38, 0.52)
	mat_bed_blue.roughness = 0.80

	mat_bed_green = StandardMaterial3D.new()
	mat_bed_green.albedo_color = Color(0.28, 0.44, 0.32)
	mat_bed_green.roughness = 0.80

	mat_mattress = StandardMaterial3D.new()
	mat_mattress.albedo_color = Color(0.85, 0.84, 0.80)
	mat_mattress.roughness = 0.85

	# Hanging cloth curtain (soft maroon/burgundy drape)
	mat_curtain = StandardMaterial3D.new()
	mat_curtain.albedo_color = Color(0.45, 0.16, 0.20)
	mat_curtain.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_curtain.roughness = 0.90

	# Bi-fold accordion door (cream PVC slats with vertical ribs)
	mat_accordion_door = StandardMaterial3D.new()
	mat_accordion_door.albedo_color = Color(0.82, 0.78, 0.72)
	mat_accordion_door.roughness = 0.50

	mat_porcelain = StandardMaterial3D.new()
	mat_porcelain.albedo_color = Color(0.95, 0.96, 0.98)
	mat_porcelain.roughness = 0.20

	mat_chrome = StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.88, 0.90, 0.92)
	mat_chrome.metallic = 0.90
	mat_chrome.roughness = 0.25

	mat_counter = StandardMaterial3D.new()
	mat_counter.albedo_color = Color(0.28, 0.29, 0.30)
	mat_counter.roughness = 0.35

	mat_stone_well = StandardMaterial3D.new()
	mat_stone_well.albedo_color = Color(0.42, 0.40, 0.38)
	mat_stone_well.roughness = 0.95

	mat_water = StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.08, 0.18, 0.22, 0.88)
	mat_water.roughness = 0.10

	mat_corrugated_roof = StandardMaterial3D.new()
	mat_corrugated_roof.albedo_color = Color(0.38, 0.39, 0.41)
	mat_corrugated_roof.metallic = 0.40
	mat_corrugated_roof.roughness = 0.65

	mat_straw = StandardMaterial3D.new()
	mat_straw.albedo_color = Color(0.68, 0.58, 0.32)
	mat_straw.roughness = 0.98

	mat_metal_dark = StandardMaterial3D.new()
	mat_metal_dark.albedo_color = Color(0.14, 0.15, 0.16)
	mat_metal_dark.metallic = 0.70
	mat_metal_dark.roughness = 0.40

	mat_lamp_warm = StandardMaterial3D.new()
	mat_lamp_warm.albedo_color = Color(1.0, 0.90, 0.70)
	mat_lamp_warm.emission_enabled = true
	mat_lamp_warm.emission = Color(1.0, 0.90, 0.70)
	mat_lamp_warm.emission_energy_multiplier = 2.0

	mat_concrete = StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.65, 0.64, 0.61)
	mat_concrete.roughness = 0.92


# ==============================================================================
# ROOM 1: MASTER BEDROOM (King sized bed on right side at front door)
# ==============================================================================
func _build_room_1_master_bedroom(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room1_MasterBedroom"
	parent.add_child(r)

	# King-Sized Bed ($2.0m x 2.2m) on the right side of the entrance
	var bed := _create_bed(r, Vector3(-0.6, FLOOR_Y, -6.6), 2.0, 2.2, 0.65, mat_wood_dark, mat_bed_white, mat_bed_blue, 0.0)
	bed.name = "MasterBed_King"

	# Bedside nightstands flanking bed
	var ns_l := _create_furniture_prop(r, "Nightstand_Left", Vector3(-1.95, FLOOR_Y, -7.5), Vector3(0.5, 0.55, 0.45), mat_wood_dark)
	var ns_r := _create_furniture_prop(r, "Nightstand_Right", Vector3(0.75, FLOOR_Y, -7.5), Vector3(0.5, 0.55, 0.45), mat_wood_dark)
	_create_table_lamp(ns_l, Vector3(0.0, 0.55, 0.0))
	_create_table_lamp(ns_r, Vector3(0.0, 0.55, 0.0))

	# Large wooden wardrobe along west wall
	_create_furniture_prop(r, "Wardrobe", Vector3(-3.8, FLOOR_Y, -5.5), Vector3(0.65, 2.2, 1.8), mat_wood_medium)

	# Vanity dressing table with mirror on south wall
	_create_vanity_table(r, Vector3(-2.2, FLOOR_Y, -3.4), 0.0)


# ==============================================================================
# ROOM 2: BATHROOM & TOILET (Foldable door to Living Room 6, Curtain to Master Bedroom 1)
# ==============================================================================
func _build_room_2_bathroom(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room2_Bathroom"
	parent.add_child(r)

	# 1. Foldable / Bi-Fold Accordion Door to Living Room 6 (at X ≈ 1.2m, Z ≈ 1.7m)
	_create_accordion_bifold_door(r, Vector3(1.18, FLOOR_Y, 1.7), 0.95, 2.05, 90.0)

	# 2. Doorway from Master Bedroom 1 with Hanging Cloth Curtain (at X ≈ -1.5m, Z ≈ -0.5m)
	_create_curtain_doorway(r, Vector3(-1.5, FLOOR_Y, -0.6), 1.0, 2.1, 0.0)

	# Toilet Bowl with water tank
	_create_toilet(r, Vector3(-3.8, FLOOR_Y, 2.5), 90.0)

	# Ceramic wash basin with mirror
	_create_wash_basin(r, Vector3(-3.8, FLOOR_Y, 0.9), 90.0)

	# Traditional Malaysian water tap & large bathing pail (timba mandi)
	_create_bath_pail(r, Vector3(-1.2, FLOOR_Y, 2.6))


# ==============================================================================
# ROOM 3: BEDROOM (Queen sized bed - mattress on floor only, no bed frame)
# ==============================================================================
func _build_room_3_floor_mattress_bedroom(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room3_FloorMattressBedroom"
	parent.add_child(r)

	# Queen-Sized Mattress on Floor ONLY ($1.55m x 2.0m x 0.24m)
	_create_floor_mattress(r, Vector3(-1.6, FLOOR_Y, 8.5), 1.55, 2.0, 0.0)

	# Standing floor fan and floor wardrobe
	_create_furniture_prop(r, "FloorFanStand", Vector3(-3.5, FLOOR_Y, 7.2), Vector3(0.4, 0.45, 0.4), mat_wood_medium)
	_create_furniture_prop(r, "Wardrobe", Vector3(-3.6, FLOOR_Y, 9.6), Vector3(0.5, 1.8, 1.2), mat_wood_medium)


# ==============================================================================
# ROOM 4: BATHROOM
# ==============================================================================
func _build_room_4_bathroom(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room4_Bathroom"
	parent.add_child(r)

	_create_toilet(r, Vector3(-5.2, FLOOR_Y, 14.5), 0.0)
	_create_wash_basin(r, Vector3(-5.2, FLOOR_Y, 16.0), 0.0)
	_create_shower_head(r, Vector3(-3.9, FLOOR_Y, 16.2), 180.0)


# ==============================================================================
# ROOM 5 & 11: BEDROOM SUITE (Queen bed beside side windows + Room 11 continuation)
# ==============================================================================
func _build_room_5_and_11_bedroom_suite(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room5_11_BedroomSuite"
	parent.add_child(r)

	# Queen-Sized Bed right beside the side windows along west wall
	var bed := _create_bed(r, Vector3(-4.6, FLOOR_Y, 20.7), 1.55, 2.05, 0.58, mat_wood_medium, mat_bed_white, mat_bed_blue, 90.0)
	bed.name = "Bed_Queen_WindowSide"

	# Room 11 (continuation): Wardrobe and study desk
	_create_furniture_prop(r, "SuiteWardrobe", Vector3(0.2, FLOOR_Y, 15.5), Vector3(0.6, 2.1, 1.6), mat_wood_medium)
	_create_study_desk(r, Vector3(1.8, FLOOR_Y, 17.5), 180.0)


# ==============================================================================
# ROOM 6: LIVING ROOM (Inside front door)
# ==============================================================================
func _build_room_6_living_room(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room6_LivingRoom"
	parent.add_child(r)

	# Shoe rack beside front entrance (door at X: 4.06, Z: -3.02)
	_create_furniture_prop(r, "ShoeRack", Vector3(5.2, FLOOR_Y, -2.2), Vector3(0.4, 0.85, 1.2), mat_wood_dark)

	# Living room carpet rug
	_create_furniture_prop(r, "LivingRoomRug", Vector3(10.5, FLOOR_Y, -1.0), Vector3(4.2, 0.02, 3.2), mat_fabric_cushion, 0.0, false)

	# CRT Television Console credenza
	_create_tv_console(r, Vector3(10.5, FLOOR_Y, -4.2), 0.0)

	# Coffee table in center of living room
	_create_furniture_prop(r, "LivingRoomCoffeeTable", Vector3(10.5, FLOOR_Y, -1.0), Vector3(1.4, 0.45, 0.8), mat_wood_dark)


# ==============================================================================
# ROOM 7: GUEST LIVING ROOM (2-seater cushioned sofa facing Rooms 8 & 9)
# ==============================================================================
func _build_room_7_guest_living_room(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room7_GuestLivingRoom"
	parent.add_child(r)

	# 2-seater cushioned sofa on west side facing +X (towards Rooms 8 & 9)
	_create_cushioned_sofa_2_seater(r, Vector3(20.0, FLOOR_Y, -7.15), 90.0)

	# Coffee table in front of sofa
	_create_furniture_prop(r, "GuestCoffeeTable_7", Vector3(21.4, FLOOR_Y, -7.15), Vector3(0.7, 0.42, 1.2), mat_wood_dark)


# ==============================================================================
# ROOM 8: GUEST LIVING ROOM (Wooden sofas on right facing Room 7 + Door to Garage)
# ==============================================================================
func _build_room_8_guest_living_room(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room8_GuestLivingRoom"
	parent.add_child(r)

	# 1. Single-seater wooden sofa on right side facing west (-X towards Room 7)
	_create_wooden_sofa(r, Vector3(35.5, FLOOR_Y, -8.6), 1, -90.0)

	# 2. Two-seater wooden sofa on right side facing west (-X towards Room 7)
	_create_wooden_sofa(r, Vector3(35.5, FLOOR_Y, -6.5), 2, -90.0)

	# Coffee table between sofas
	_create_furniture_prop(r, "GuestCoffeeTable_8", Vector3(33.8, FLOOR_Y, -7.5), Vector3(0.65, 0.45, 1.0), mat_wood_dark)

	# Exterior door leading into the roofed garage on east wall (X ≈ 36.5m, Z ≈ -7.0m)
	_create_interior_door_frame(r, Vector3(36.5, FLOOR_Y, -7.1), 1.0, 2.1, 90.0)


# ==============================================================================
# ROOM 9: GUEST LIVING ROOM (3-seater wooden sofa leaning towards 8, facing away from front window)
# ==============================================================================
func _build_room_9_guest_living_room(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room9_GuestLivingRoom"
	parent.add_child(r)

	# 3-seater wooden sofa backing against front window (Z ≈ -14.4m), facing +Z (towards Room 8)
	_create_wooden_sofa(r, Vector3(33.3, FLOOR_Y, -13.6), 3, 0.0)

	# Side table next to sofa
	_create_furniture_prop(r, "SofaSideTable_9", Vector3(35.2, FLOOR_Y, -13.6), Vector3(0.5, 0.55, 0.5), mat_wood_dark)


# ==============================================================================
# ROOM 10: DINING ROOM (Tabletop along center wall + Circular dark brown wood table & chairs)
# ==============================================================================
func _build_room_10_dining_room(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room10_DiningRoom"
	parent.add_child(r)

	# 1. Long tabletop sideboard counter along middle structure wall (X ≈ 23.2m, Z: 3.5m to 8.5m)
	_create_furniture_prop(r, "CenterWallTabletop", Vector3(23.2, FLOOR_Y, 6.0), Vector3(0.65, 0.90, 4.5), mat_wood_dark)

	# 2. Large Circular Dining Table closer to right windows (dark brown wooden texture)
	var table_pos := Vector3(30.2, FLOOR_Y, 6.0)
	_create_circular_dining_table(r, table_pos, 1.8, 0.78, mat_wood_dark)

	# 5 dark brown wooden chairs surrounding the circular table
	for i in range(5):
		var ang := i * (PI * 2.0 / 5.0)
		var chair_pos := table_pos + Vector3(cos(ang) * 1.35, 0.0, sin(ang) * 1.35)
		var ch := _create_dining_chair(r, chair_pos, -rad_to_deg(ang) + 90.0, mat_wood_dark)
		ch.name = "DiningChair_" + str(i + 1)


# ==============================================================================
# ROOM 12: BEDROOM
# ==============================================================================
func _build_room_12_bedroom(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room12_Bedroom"
	parent.add_child(r)

	# Wardrobe closet
	_create_furniture_prop(r, "Wardrobe_12", Vector3(15.0, FLOOR_Y, 18.5), Vector3(0.6, 2.1, 1.5), mat_wood_medium)
	# Study desk and chair
	_create_study_desk(r, Vector3(13.5, FLOOR_Y, 20.4), 180.0)


# ==============================================================================
# ROOM 13: BEDROOM CONTINUATION (Queen sized bed filled snugly in wall gap)
# ==============================================================================
func _build_room_13_gap_bed(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room13_GapBed"
	parent.add_child(r)

	# Queen bed fitted snugly into the wall gap between X: 5.5m and 7.8m
	var bed := _create_bed(r, Vector3(6.7, FLOOR_Y, 19.8), 1.6, 2.1, 0.58, mat_wood_medium, mat_bed_white, mat_bed_green, 0.0)
	bed.name = "QueenBed_GapFill"


# ==============================================================================
# ROOM 14: SMALL TOILET
# ==============================================================================
func _build_room_14_small_toilet(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room14_SmallToilet"
	parent.add_child(r)

	_create_toilet(r, Vector3(19.2, FLOOR_Y, 18.8), 180.0)
	_create_wash_basin(r, Vector3(19.2, FLOOR_Y, 17.5), 0.0)


# ==============================================================================
# ROOM 15: BEDROOM (King sized bed)
# ==============================================================================
func _build_room_15_bedroom(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room15_Bedroom"
	parent.add_child(r)

	# King-Sized Bed ($2.0m x 2.2m)
	var bed := _create_bed(r, Vector3(26.5, FLOOR_Y, 19.4), 2.0, 2.2, 0.65, mat_wood_dark, mat_bed_white, mat_bed_blue, 0.0)
	bed.name = "KingBed_15"

	# Flanking nightstands
	_create_furniture_prop(r, "Nightstand_15_Left", Vector3(25.1, FLOOR_Y, 18.5), Vector3(0.48, 0.55, 0.45), mat_wood_dark)
	_create_furniture_prop(r, "Nightstand_15_Right", Vector3(27.9, FLOOR_Y, 18.5), Vector3(0.48, 0.55, 0.45), mat_wood_dark)

	# Wardrobe along side wall
	_create_furniture_prop(r, "Wardrobe_15", Vector3(28.8, FLOOR_Y, 20.2), Vector3(0.65, 2.2, 1.6), mat_wood_medium)


# ==============================================================================
# ROOM 16: KITCHEN (Double stainless steel sinks on right wall towards outside + Back Door)
# ==============================================================================
func _build_room_16_kitchen(parent: Node3D) -> void:
	var r := Node3D.new()
	r.name = "Room16_Kitchen"
	parent.add_child(r)

	# Main kitchen counter along the right wall (X ≈ 38.3m, Z: 17.0m to 22.0m)
	var counter_len := 5.0
	var counter_x := 38.3
	_create_furniture_prop(r, "KitchenCounter_Main", Vector3(counter_x, FLOOR_Y, 19.5), Vector3(0.80, 0.90, counter_len), mat_counter)

	# Overhead kitchen cupboards
	_create_furniture_prop(r, "KitchenCupboards", Vector3(counter_x, FLOOR_Y + 1.5, 19.5), Vector3(0.50, 0.70, counter_len), mat_wood_medium, 0.0, false)

	# Double Stainless Steel Sinks on right side counter towards the outside house (at Z ≈ 18.5m)
	_create_double_kitchen_sink(r, Vector3(counter_x, FLOOR_Y + 0.90, 18.5))

	# Gas cooking stove with twin burners (at Z ≈ 21.0m)
	_create_gas_stove(r, Vector3(counter_x, FLOOR_Y + 0.90, 21.0))

	# Refrigerator on left side wall
	_create_furniture_prop(r, "Refrigerator", Vector3(32.8, FLOOR_Y, 16.5), Vector3(0.85, 1.85, 0.85), mat_porcelain)


# ==============================================================================
# EXTERIOR 1: ROOFED GARAGE (Beside Rooms 8 & 9 connected via Room 8 door)
# ==============================================================================
func _build_roofed_garage(parent: Node3D) -> void:
	var g := Node3D.new()
	g.name = "Exterior_RoofedGarage"
	g.set_meta("_edit_group_", true)
	parent.add_child(g)

	# Dimensions: X from 37.0m to 46.5m (width 9.5m), Z from -16.0m to -3.5m (length 12.5m)
	var mid_x := (37.0 + 46.5) * 0.5   # 41.75m
	var mid_z := (-16.0 + -3.5) * 0.5  # -9.75m
	var w := 46.5 - 37.0               # 9.5m
	var d := -3.5 - -16.0              # 12.5m

	# 1. Smooth concrete garage floor slab
	_create_box(g, Vector3(w, 0.12, d), mat_concrete, Vector3(mid_x, 0.06, mid_z), true)

	# 2. Outer structural steel/concrete support pillars (at X = 46.2m)
	var pillar_zs := [-15.5, -9.75, -4.0]
	for pz in pillar_zs:
		_create_box(g, Vector3(0.35, 3.2, 0.35), mat_concrete, Vector3(46.2, 1.6, pz), true)

	# 3. Slanted Garage Awning Roof Structure
	# Slopes from house connection (Y ≈ 3.4m) down to outer pillars (Y ≈ 2.8m)
	var roof_mesh := _create_box(g, Vector3(w + 0.6, 0.14, d + 0.6), mat_corrugated_roof, Vector3(mid_x, 3.15, mid_z), false)
	roof_mesh.rotation_degrees.z = 3.6  # Slanted slope toward east

	# 4. Garage accessories (workbench, tyre stacks, shelving)
	_create_furniture_prop(g, "GarageWorkbench", Vector3(45.5, 0.0, -14.5), Vector3(0.7, 0.9, 2.2), mat_wood_rustic)
	_create_furniture_prop(g, "GarageStorageShelves", Vector3(45.6, 0.0, -6.5), Vector3(0.5, 1.8, 1.8), mat_metal_dark)


# ==============================================================================
# EXTERIOR 2: TRADITIONAL STONE WELL (Back Yard lower-left side)
# ==============================================================================
func _build_traditional_stone_well(parent: Node3D) -> void:
	var w := Node3D.new()
	w.name = "Exterior_TraditionalStoneWell"
	w.set_meta("_edit_group_", true)
	parent.add_child(w)

	var center := Vector3(-8.0, 0.0, 28.5)

	# 1. Cobblestone base platform
	_create_box(w, Vector3(3.2, 0.10, 3.2), mat_concrete, center + Vector3(0.0, 0.05, 0.0), true)

	# 2. Cylindrical stone masonry well wall
	var well_ring := StaticBody3D.new()
	well_ring.position = center
	w.add_child(well_ring)

	var ring_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.95
	cyl.bottom_radius = 1.05
	cyl.height = 0.85
	cyl.material = mat_stone_well
	ring_mesh.mesh = cyl
	ring_mesh.position = Vector3(0.0, 0.425, 0.0)
	well_ring.add_child(ring_mesh)

	var col_shape := CollisionShape3D.new()
	var c_shape := CylinderShape3D.new()
	c_shape.radius = 1.0
	c_shape.height = 0.85
	col_shape.shape = c_shape
	col_shape.position = Vector3(0.0, 0.425, 0.0)
	well_ring.add_child(col_shape)

	# Dark reflective water surface inside the well
	var water_mi := MeshInstance3D.new()
	var w_cyl := CylinderMesh.new()
	w_cyl.top_radius = 0.78
	w_cyl.bottom_radius = 0.78
	w_cyl.height = 0.02
	w_cyl.material = mat_water
	water_mi.mesh = w_cyl
	water_mi.position = center + Vector3(0.0, 0.15, 0.0)
	w.add_child(water_mi)

	# 3. Two sturdy timber upright support posts
	_create_box(w, Vector3(0.16, 2.4, 0.16), mat_wood_rustic, center + Vector3(-0.95, 1.2, 0.0), true)
	_create_box(w, Vector3(0.16, 2.4, 0.16), mat_wood_rustic, center + Vector3(0.95, 1.2, 0.0), true)

	# Wooden crossbeam axle & winch drum
	_create_box(w, Vector3(2.1, 0.14, 0.14), mat_wood_rustic, center + Vector3(0.0, 2.25, 0.0))
	_create_box(w, Vector3(0.6, 0.22, 0.22), mat_wood_rustic, center + Vector3(0.0, 1.85, 0.0))

	# Metal hand crank handle on side
	_create_box(w, Vector3(0.04, 0.35, 0.04), mat_metal_dark, center + Vector3(1.1, 1.85, 0.15))

	# Pitched timber shingle gable roof
	var roof_l := _create_box(w, Vector3(2.3, 0.08, 1.15), mat_wood_rustic, center + Vector3(0.0, 2.58, -0.42))
	roof_l.rotation_degrees.x = 32.0
	var roof_r := _create_box(w, Vector3(2.3, 0.08, 1.15), mat_wood_rustic, center + Vector3(0.0, 2.58, 0.42))
	roof_r.rotation_degrees.x = -32.0

	# Weathered wooden bucket dangling on rope
	_create_box(w, Vector3(0.32, 0.35, 0.32), mat_wood_rustic, center + Vector3(0.2, 0.75, 0.0))
	_create_box(w, Vector3(0.03, 1.05, 0.03), mat_straw, center + Vector3(0.2, 1.35, 0.0))


# ==============================================================================
# EXTERIOR 3: TALL FARM ANIMAL BARN (Back Yard right side)
# ==============================================================================
func _build_tall_animal_barn(parent: Node3D) -> void:
	var b := Node3D.new()
	b.name = "Exterior_TallAnimalBarn"
	b.set_meta("_edit_group_", true)
	parent.add_child(b)

	# Dimensions: 13.0m wide (X: 31.0m to 44.0m), 6.5m deep (Z: 26.0m to 32.5m), 4.8m tall
	var mid_x := (31.0 + 44.0) * 0.5   # 37.5m
	var mid_z := (26.0 + 32.5) * 0.5   # 29.25m
	var bw := 44.0 - 31.0              # 13.0m
	var bd := 32.5 - 26.0              # 6.5m
	var bh := 4.8                      # 4.8m tall barn!

	# Dirt / packed gravel barn floor
	_create_box(b, Vector3(bw + 1.0, 0.08, bd + 1.0), mat_concrete, Vector3(mid_x, 0.04, mid_z), true)

	# Heavy timber corner and intermediate posts
	var post_coords := [
		Vector3(31.2, 0.0, 26.2), Vector3(37.5, 0.0, 26.2), Vector3(43.8, 0.0, 26.2),
		Vector3(31.2, 0.0, 32.3), Vector3(37.5, 0.0, 32.3), Vector3(43.8, 0.0, 32.3),
	]
	for ppos in post_coords:
		_create_box(b, Vector3(0.32, bh, 0.32), mat_wood_rustic, ppos + Vector3(0.0, bh * 0.5, 0.0), true)

	# Upper horizontal perimeter timber tie-beams
	_create_box(b, Vector3(bw, 0.22, 0.22), mat_wood_rustic, Vector3(mid_x, bh - 0.11, 26.2))
	_create_box(b, Vector3(bw, 0.22, 0.22), mat_wood_rustic, Vector3(mid_x, bh - 0.11, 32.3))
	_create_box(b, Vector3(0.22, 0.22, bd), mat_wood_rustic, Vector3(31.2, bh - 0.11, mid_z))
	_create_box(b, Vector3(0.22, 0.22, bd), mat_wood_rustic, Vector3(43.8, bh - 0.11, mid_z))

	# Pitched Corrugated Barn Roof (peaking at Y = 5.6m)
	var roof_l := _create_box(b, Vector3(bw + 1.2, 0.10, bd * 0.58), mat_corrugated_roof, Vector3(mid_x, bh + 0.45, mid_z - bd * 0.24))
	roof_l.rotation_degrees.x = 18.0
	var roof_r := _create_box(b, Vector3(bw + 1.2, 0.10, bd * 0.58), mat_corrugated_roof, Vector3(mid_x, bh + 0.45, mid_z + bd * 0.24))
	roof_r.rotation_degrees.x = -18.0

	# Enclosed back wall (Z = 32.3m) with wooden planks
	_create_box(b, Vector3(bw - 0.6, bh * 0.8, 0.08), mat_wood_rustic, Vector3(mid_x, bh * 0.4, 32.2), true)

	# 3 Divided Farm Animal Stalls / Pens with wooden railing fences
	var stall_dividers := [35.3, 39.5]
	for sx in stall_dividers:
		_create_box(b, Vector3(0.12, 1.3, bd * 0.85), mat_wood_rustic, Vector3(sx, 0.65, mid_z + 0.3), true)

	# Front pen railings with swinging gates
	_create_box(b, Vector3(3.8, 1.2, 0.10), mat_wood_rustic, Vector3(33.2, 0.6, 27.2), true)
	_create_box(b, Vector3(3.8, 1.2, 0.10), mat_wood_rustic, Vector3(37.4, 0.6, 27.2), true)
	_create_box(b, Vector3(3.8, 1.2, 0.10), mat_wood_rustic, Vector3(41.6, 0.6, 27.2), true)

	# Long wooden animal feeding troughs filled with hay/straw
	var tr1 := _create_feeding_trough(b, Vector3(33.2, 0.0, 31.0))
	tr1.name = "FeedingTrough_1"
	var tr2 := _create_feeding_trough(b, Vector3(37.4, 0.0, 31.0))
	tr2.name = "FeedingTrough_2"
	var tr3 := _create_feeding_trough(b, Vector3(41.6, 0.0, 31.0))
	tr3.name = "FeedingTrough_3"

	# Stacked hay bales
	_create_furniture_prop(b, "HayBales", Vector3(42.5, 0.0, 28.5), Vector3(0.9, 1.1, 1.4), mat_straw)

	# Rustic hanging barn lantern casting warm light
	_create_hanging_lantern(b, Vector3(mid_x, bh - 0.6, mid_z))


# ==============================================================================
# REUSABLE FURNITURE & PROP BUILDERS
# ==============================================================================

## Generic furniture prop container with pivot on the floor and _edit_group_ enabled
func _create_furniture_prop(parent: Node3D, prop_name: String, pos: Vector3, size: Vector3, mat: Material, rot_y: float = 0.0, with_collision: bool = true) -> Node3D:
	var prop := StaticBody3D.new() if with_collision else Node3D.new()
	prop.name = prop_name
	prop.position = pos
	prop.rotation_degrees.y = rot_y
	prop.set_meta("_edit_group_", true)
	parent.add_child(prop)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = Vector3(0.0, size.y * 0.5, 0.0)
	prop.add_child(mi)

	if with_collision:
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = Vector3(0.0, size.y * 0.5, 0.0)
		prop.add_child(cs)

	return prop


func _create_bed(parent: Node3D, pos: Vector3, width: float, length: float, height: float, frame_mat: Material, sheet_mat: Material, duvet_mat: Material, rot_y: float) -> Node3D:
	var bed := Node3D.new()
	bed.name = "Bed"
	bed.position = pos
	bed.rotation_degrees.y = rot_y
	bed.set_meta("_edit_group_", true)
	parent.add_child(bed)

	# Wooden bed frame
	_create_box(bed, Vector3(width, 0.28, length), frame_mat, Vector3(0.0, 0.14, 0.0), true)

	# Headboard
	_create_box(bed, Vector3(width, height * 1.4, 0.10), frame_mat, Vector3(0.0, height * 0.7, -length * 0.5 + 0.05), true)

	# Mattress
	var mat_h := 0.26
	_create_box(bed, Vector3(width * 0.96, mat_h, length * 0.95), sheet_mat, Vector3(0.0, 0.28 + mat_h * 0.5, 0.05))

	# Duvet / Comforter folded on lower half
	_create_box(bed, Vector3(width * 0.94, 0.06, length * 0.60), duvet_mat, Vector3(0.0, 0.28 + mat_h + 0.03, length * 0.18))

	# Two Pillows
	var pw := width * 0.40
	_create_box(bed, Vector3(pw, 0.12, 0.42), sheet_mat, Vector3(-width * 0.24, 0.28 + mat_h + 0.06, -length * 0.32))
	_create_box(bed, Vector3(pw, 0.12, 0.42), sheet_mat, Vector3(width * 0.24, 0.28 + mat_h + 0.06, -length * 0.32))

	return bed


func _create_floor_mattress(parent: Node3D, pos: Vector3, width: float, length: float, rot_y: float) -> Node3D:
	var mattress := Node3D.new()
	mattress.name = "FloorMattress_Queen"
	mattress.position = pos
	mattress.rotation_degrees.y = rot_y
	mattress.set_meta("_edit_group_", true)
	parent.add_child(mattress)

	var mat_h := 0.24
	_create_box(mattress, Vector3(width, mat_h, length), mat_mattress, Vector3(0.0, mat_h * 0.5, 0.0), true)

	# Fitted bedsheet / blanket on mattress
	_create_box(mattress, Vector3(width * 0.98, 0.05, length * 0.65), mat_bed_green, Vector3(0.0, mat_h + 0.025, length * 0.15))

	# Two soft pillows
	var pw := width * 0.40
	_create_box(mattress, Vector3(pw, 0.10, 0.40), mat_bed_white, Vector3(-width * 0.25, mat_h + 0.05, -length * 0.32))
	_create_box(mattress, Vector3(pw, 0.10, 0.40), mat_bed_white, Vector3(width * 0.25, mat_h + 0.05, -length * 0.32))

	return mattress


func _create_accordion_bifold_door(parent: Node3D, pos: Vector3, width: float, height: float, rot_y: float) -> Node3D:
	var door := Node3D.new()
	door.name = "AccordionBiFoldDoor"
	door.position = pos
	door.rotation_degrees.y = rot_y
	door.set_meta("_edit_group_", true)
	parent.add_child(door)

	# Top track rail
	_create_box(door, Vector3(width, 0.06, 0.08), mat_metal_dark, Vector3(width * 0.5, height - 0.03, 0.0))

	# Accordion folding slats (zigzag folding pattern)
	var n_slats := 6
	var slat_w := (width * 0.75) / float(n_slats)
	for i in range(n_slats):
		var sx := i * slat_w + slat_w * 0.5
		var angle := 22.0 if (i % 2 == 0) else -22.0
		var slat := _create_box(door, Vector3(slat_w * 1.05, height - 0.08, 0.025), mat_accordion_door, Vector3(sx, (height - 0.08) * 0.5, 0.0))
		slat.rotation_degrees.y = angle

	# Door handle
	_create_box(door, Vector3(0.04, 0.18, 0.06), mat_chrome, Vector3(width * 0.72, 0.95, 0.04))

	return door


func _create_curtain_doorway(parent: Node3D, pos: Vector3, width: float, height: float, rot_y: float) -> Node3D:
	var doorway := Node3D.new()
	doorway.name = "ClothCurtainDoorway"
	doorway.position = pos
	doorway.rotation_degrees.y = rot_y
	doorway.set_meta("_edit_group_", true)
	parent.add_child(doorway)

	# Wooden / brass curtain rod across top
	_create_box(doorway, Vector3(width + 0.2, 0.04, 0.04), mat_wood_dark, Vector3(width * 0.5, height - 0.02, 0.0))

	# Hanging pleated fabric curtain (two halves drawn slightly open)
	var cur_w := width * 0.44
	var cur_h := height - 0.06
	# Left drape
	_create_box(doorway, Vector3(cur_w, cur_h, 0.04), mat_curtain, Vector3(cur_w * 0.5 + 0.02, cur_h * 0.5, 0.0))
	# Right drape
	_create_box(doorway, Vector3(cur_w, cur_h, 0.04), mat_curtain, Vector3(width - cur_w * 0.5 - 0.02, cur_h * 0.5, 0.0))

	return doorway


func _create_cushioned_sofa_2_seater(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var sofa := Node3D.new()
	sofa.name = "CushionedSofa_2Seater"
	sofa.position = pos
	sofa.rotation_degrees.y = rot_y
	sofa.set_meta("_edit_group_", true)
	parent.add_child(sofa)

	var sw := 1.75
	var sd := 0.88
	# Base frame
	_create_box(sofa, Vector3(sw, 0.25, sd), mat_wood_dark, Vector3(0.0, 0.125, 0.0), true)
	# Cushioned seat
	_create_box(sofa, Vector3(sw * 0.88, 0.20, sd * 0.80), mat_fabric_cushion, Vector3(0.0, 0.35, 0.02))
	# Cushioned backrest
	_create_box(sofa, Vector3(sw * 0.88, 0.48, 0.22), mat_fabric_cushion, Vector3(0.0, 0.58, -sd * 0.38))
	# Armrests
	_create_box(sofa, Vector3(0.18, 0.35, sd * 0.95), mat_fabric_cushion, Vector3(-sw * 0.44, 0.425, 0.0))
	_create_box(sofa, Vector3(0.18, 0.35, sd * 0.95), mat_fabric_cushion, Vector3(sw * 0.44, 0.425, 0.0))

	return sofa


func _create_wooden_sofa(parent: Node3D, pos: Vector3, seats: int, rot_y: float) -> Node3D:
	var sofa := Node3D.new()
	sofa.name = "WoodenSofa_" + str(seats) + "Seater"
	sofa.position = pos
	sofa.rotation_degrees.y = rot_y
	sofa.set_meta("_edit_group_", true)
	parent.add_child(sofa)

	var sw := 0.75 * seats + 0.15
	var sd := 0.80
	# Slatted wooden seat frame
	_create_box(sofa, Vector3(sw, 0.08, sd), mat_wood_dark, Vector3(0.0, 0.38, 0.0), true)
	# Wooden legs
	_create_box(sofa, Vector3(0.08, 0.38, 0.08), mat_wood_dark, Vector3(-sw * 0.45, 0.19, -sd * 0.42), true)
	_create_box(sofa, Vector3(0.08, 0.38, 0.08), mat_wood_dark, Vector3(sw * 0.45, 0.19, -sd * 0.42), true)
	_create_box(sofa, Vector3(0.08, 0.38, 0.08), mat_wood_dark, Vector3(-sw * 0.45, 0.19, sd * 0.42), true)
	_create_box(sofa, Vector3(0.08, 0.38, 0.08), mat_wood_dark, Vector3(sw * 0.45, 0.19, sd * 0.42), true)

	# Carved wooden backrest
	_create_box(sofa, Vector3(sw, 0.52, 0.06), mat_wood_dark, Vector3(0.0, 0.64, -sd * 0.44), true)

	# Wooden armrests
	_create_box(sofa, Vector3(0.08, 0.22, sd * 0.92), mat_wood_dark, Vector3(-sw * 0.45, 0.52, 0.0))
	_create_box(sofa, Vector3(0.08, 0.22, sd * 0.92), mat_wood_dark, Vector3(sw * 0.45, 0.52, 0.0))

	# Thin seat cushions (traditional Malay wooden sofa cushions)
	for s in range(seats):
		var cx := (s - (seats - 1) * 0.5) * 0.72
		_create_box(sofa, Vector3(0.66, 0.08, 0.68), mat_fabric_sofa_wood, Vector3(cx, 0.44, 0.04))

	return sofa


func _create_circular_dining_table(parent: Node3D, pos: Vector3, diameter: float, height: float, mat: Material) -> Node3D:
	var table := StaticBody3D.new()
	table.name = "CircularDiningTable"
	table.position = pos
	table.set_meta("_edit_group_", true)
	parent.add_child(table)

	# Circular tabletop
	var top_mi := MeshInstance3D.new()
	top_mi.name = "TabletopMesh"
	var top_cyl := CylinderMesh.new()
	top_cyl.top_radius = diameter * 0.5
	top_cyl.bottom_radius = diameter * 0.5
	top_cyl.height = 0.06
	top_cyl.material = mat
	top_mi.mesh = top_cyl
	top_mi.position = Vector3(0.0, height - 0.03, 0.0)
	table.add_child(top_mi)

	var top_col := CollisionShape3D.new()
	top_col.name = "TabletopCollision"
	var top_shape := CylinderShape3D.new()
	top_shape.radius = diameter * 0.5
	top_shape.height = 0.06
	top_col.shape = top_shape
	top_col.position = Vector3(0.0, height - 0.03, 0.0)
	table.add_child(top_col)

	# Sturdy central wooden pedestal & radial four-legged base
	_create_box(table, Vector3(0.24, height - 0.06, 0.24), mat, Vector3(0.0, (height - 0.06) * 0.5, 0.0))
	_create_box(table, Vector3(diameter * 0.75, 0.08, 0.14), mat, Vector3(0.0, 0.04, 0.0))
	_create_box(table, Vector3(0.14, 0.08, diameter * 0.75), mat, Vector3(0.0, 0.04, 0.0))

	return table


func _create_dining_chair(parent: Node3D, pos: Vector3, rot_y: float, mat: Material) -> Node3D:
	var chair := Node3D.new()
	chair.name = "DiningChair"
	chair.position = pos
	chair.rotation_degrees.y = rot_y
	chair.set_meta("_edit_group_", true)
	parent.add_child(chair)

	# Seat
	_create_box(chair, Vector3(0.44, 0.05, 0.44), mat, Vector3(0.0, 0.44, 0.0), true)
	# 4 Legs
	_create_box(chair, Vector3(0.05, 0.44, 0.05), mat, Vector3(-0.18, 0.22, -0.18), true)
	_create_box(chair, Vector3(0.05, 0.44, 0.05), mat, Vector3(0.18, 0.22, -0.18), true)
	_create_box(chair, Vector3(0.05, 0.44, 0.05), mat, Vector3(-0.18, 0.22, 0.18), true)
	_create_box(chair, Vector3(0.05, 0.44, 0.05), mat, Vector3(0.18, 0.22, 0.18), true)
	# Slatted backrest
	_create_box(chair, Vector3(0.44, 0.48, 0.04), mat, Vector3(0.0, 0.68, -0.20), true)

	return chair


func _create_double_kitchen_sink(parent: Node3D, pos: Vector3) -> Node3D:
	var sink := Node3D.new()
	sink.name = "DoubleKitchenSink"
	sink.position = pos
	sink.set_meta("_edit_group_", true)
	parent.add_child(sink)

	# Stainless steel rim frame
	_create_box(sink, Vector3(0.65, 0.04, 1.25), mat_chrome, Vector3(0.0, 0.02, 0.0))

	# Left sink bowl depression
	_create_box(sink, Vector3(0.50, 0.02, 0.48), mat_metal_dark, Vector3(0.0, 0.025, -0.28))
	# Right sink bowl depression
	_create_box(sink, Vector3(0.50, 0.02, 0.48), mat_metal_dark, Vector3(0.0, 0.025, 0.28))

	# Center Gooseneck Chrome Faucet
	_create_box(sink, Vector3(0.05, 0.28, 0.05), mat_chrome, Vector3(-0.25, 0.16, 0.0))
	_create_box(sink, Vector3(0.18, 0.04, 0.04), mat_chrome, Vector3(-0.16, 0.30, 0.0))

	return sink


func _create_gas_stove(parent: Node3D, pos: Vector3) -> Node3D:
	var stove := Node3D.new()
	stove.name = "GasStove"
	stove.position = pos
	stove.set_meta("_edit_group_", true)
	parent.add_child(stove)

	# Stainless steel cooktop base
	_create_box(stove, Vector3(0.60, 0.05, 0.85), mat_chrome, Vector3(0.0, 0.025, 0.0))

	# Twin burners
	_create_box(stove, Vector3(0.24, 0.03, 0.24), mat_metal_dark, Vector3(0.0, 0.06, -0.22))
	_create_box(stove, Vector3(0.24, 0.03, 0.24), mat_metal_dark, Vector3(0.0, 0.06, 0.22))

	return stove


func _create_toilet(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var toilet := StaticBody3D.new()
	toilet.name = "Toilet"
	toilet.position = pos
	toilet.rotation_degrees.y = rot_y
	toilet.set_meta("_edit_group_", true)
	parent.add_child(toilet)

	# Bowl pedestal
	_create_box(toilet, Vector3(0.42, 0.42, 0.58), mat_porcelain, Vector3(0.0, 0.21, 0.0), true)
	# Water tank
	_create_box(toilet, Vector3(0.44, 0.46, 0.24), mat_porcelain, Vector3(0.0, 0.55, -0.22), true)

	return toilet


func _create_wash_basin(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var basin := StaticBody3D.new()
	basin.name = "WashBasin"
	basin.position = pos
	basin.rotation_degrees.y = rot_y
	basin.set_meta("_edit_group_", true)
	parent.add_child(basin)

	# Pedestal
	_create_box(basin, Vector3(0.22, 0.72, 0.22), mat_porcelain, Vector3(0.0, 0.36, 0.0), true)
	# Basin sink bowl
	_create_box(basin, Vector3(0.58, 0.18, 0.48), mat_porcelain, Vector3(0.0, 0.81, 0.0), true)
	# Faucet
	_create_box(basin, Vector3(0.04, 0.12, 0.08), mat_chrome, Vector3(0.0, 0.94, -0.16))
	# Mirror on wall
	_create_box(basin, Vector3(0.52, 0.75, 0.03), mat_chrome, Vector3(0.0, 1.45, -0.24))

	return basin


func _create_bath_pail(parent: Node3D, pos: Vector3) -> Node3D:
	var pail := StaticBody3D.new()
	pail.name = "BathPail"
	pail.position = pos
	pail.set_meta("_edit_group_", true)
	parent.add_child(pail)

	# Plastic water drum / pail
	var p_mesh := MeshInstance3D.new()
	p_mesh.name = "PailMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.30
	cyl.height = 0.55
	var mat_p := StandardMaterial3D.new()
	mat_p.albedo_color = Color(0.18, 0.45, 0.65)
	p_mesh.mesh = cyl
	p_mesh.position = Vector3(0.0, 0.275, 0.0)
	pail.add_child(p_mesh)

	var p_col := CollisionShape3D.new()
	p_col.name = "PailCollision"
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = 0.34
	col_cyl.height = 0.55
	p_col.shape = col_cyl
	p_col.position = Vector3(0.0, 0.275, 0.0)
	pail.add_child(p_col)

	# Water scoop (gayung mandi)
	_create_box(pail, Vector3(0.16, 0.12, 0.26), mat_fabric_sofa_wood, Vector3(0.0, 0.58, 0.0))

	return pail


func _create_shower_head(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var sh := Node3D.new()
	sh.name = "ShowerHead"
	sh.position = pos
	sh.rotation_degrees.y = rot_y
	sh.set_meta("_edit_group_", true)
	parent.add_child(sh)

	_create_box(sh, Vector3(0.04, 0.4, 0.22), mat_chrome, Vector3(0.0, 1.8, -0.1))
	_create_box(sh, Vector3(0.14, 0.04, 0.14), mat_chrome, Vector3(0.0, 1.95, 0.02))

	return sh


func _create_vanity_table(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var vanity := Node3D.new()
	vanity.name = "VanityTable"
	vanity.position = pos
	vanity.rotation_degrees.y = rot_y
	vanity.set_meta("_edit_group_", true)
	parent.add_child(vanity)

	# Table surface & drawers
	_create_box(vanity, Vector3(1.1, 0.72, 0.48), mat_wood_medium, Vector3(0.0, 0.36, 0.0), true)
	# Vanity mirror
	_create_box(vanity, Vector3(0.70, 0.65, 0.04), mat_chrome, Vector3(0.0, 1.05, -0.20))
	# Vanity stool
	_create_box(vanity, Vector3(0.36, 0.42, 0.36), mat_fabric_cushion, Vector3(0.0, 0.21, 0.35), true)

	return vanity


func _create_tv_console(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var tv_node := Node3D.new()
	tv_node.name = "TVConsole"
	tv_node.position = pos
	tv_node.rotation_degrees.y = rot_y
	tv_node.set_meta("_edit_group_", true)
	parent.add_child(tv_node)

	# Low credenza cabinet
	_create_box(tv_node, Vector3(1.8, 0.50, 0.55), mat_wood_dark, Vector3(0.0, 0.25, 0.0), true)

	# Vintage CRT Television
	_create_box(tv_node, Vector3(0.75, 0.55, 0.48), mat_metal_dark, Vector3(0.0, 0.775, 0.0))
	# TV glass screen
	_create_box(tv_node, Vector3(0.58, 0.44, 0.02), mat_counter, Vector3(0.0, 0.775, 0.25))

	return tv_node


func _create_study_desk(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var desk := Node3D.new()
	desk.name = "StudyDesk"
	desk.position = pos
	desk.rotation_degrees.y = rot_y
	desk.set_meta("_edit_group_", true)
	parent.add_child(desk)

	_create_box(desk, Vector3(1.3, 0.75, 0.65), mat_wood_medium, Vector3(0.0, 0.375, 0.0), true)
	var ch := _create_dining_chair(desk, Vector3(0.0, 0.0, 0.55), 180.0, mat_wood_dark)
	ch.name = "DeskChair"

	return desk


func _create_table_lamp(parent: Node3D, pos: Vector3) -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "TableLamp"
	lamp.position = pos
	lamp.set_meta("_edit_group_", true)
	parent.add_child(lamp)

	_create_box(lamp, Vector3(0.14, 0.28, 0.14), mat_wood_dark, Vector3(0.0, 0.14, 0.0))
	_create_box(lamp, Vector3(0.24, 0.20, 0.24), mat_lamp_warm, Vector3(0.0, 0.32, 0.0))

	var omni := OmniLight3D.new()
	omni.name = "LampLight"
	omni.light_color = Color(1.0, 0.88, 0.65)
	omni.light_energy = 0.65
	omni.omni_range = 4.5
	omni.position = Vector3(0.0, 0.35, 0.0)
	lamp.add_child(omni)

	return lamp


func _create_hanging_lantern(parent: Node3D, pos: Vector3) -> Node3D:
	var l := Node3D.new()
	l.name = "HangingLantern"
	l.position = pos
	l.set_meta("_edit_group_", true)
	parent.add_child(l)

	_create_box(l, Vector3(0.24, 0.34, 0.24), mat_metal_dark, Vector3(0.0, 0.0, 0.0))
	_create_box(l, Vector3(0.18, 0.22, 0.18), mat_lamp_warm, Vector3(0.0, 0.0, 0.0))

	var lt := OmniLight3D.new()
	lt.name = "LanternLight"
	lt.light_color = Color(1.0, 0.82, 0.55)
	lt.light_energy = 1.6
	lt.omni_range = 14.0
	lt.shadow_enabled = true
	l.add_child(lt)

	return l


func _create_feeding_trough(parent: Node3D, pos: Vector3) -> Node3D:
	var trough := Node3D.new()
	trough.name = "FeedingTrough"
	trough.position = pos
	trough.set_meta("_edit_group_", true)
	parent.add_child(trough)

	# Long wooden box trough
	_create_box(trough, Vector3(3.2, 0.45, 0.65), mat_wood_rustic, Vector3(0.0, 0.225, 0.0), true)
	# Manger hay fill
	_create_box(trough, Vector3(3.0, 0.12, 0.55), mat_straw, Vector3(0.0, 0.40, 0.0))

	return trough


func _create_interior_door_frame(parent: Node3D, pos: Vector3, width: float, height: float, rot_y: float) -> Node3D:
	var frame := Node3D.new()
	frame.name = "DoorFrame"
	frame.position = pos
	frame.rotation_degrees.y = rot_y
	frame.set_meta("_edit_group_", true)
	parent.add_child(frame)

	var thick := 0.12
	# Side posts
	_create_box(frame, Vector3(thick, height, thick), mat_wood_dark, Vector3(-width * 0.5, height * 0.5, 0.0), true)
	_create_box(frame, Vector3(thick, height, thick), mat_wood_dark, Vector3(width * 0.5, height * 0.5, 0.0), true)
	# Top lintel
	_create_box(frame, Vector3(width + thick * 2.0, thick, thick), mat_wood_dark, Vector3(0.0, height + thick * 0.5, 0.0))

	return frame


func _create_box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, with_collision: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)

	if with_collision:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		if parent is CollisionObject3D:
			parent.add_child(cs)
		else:
			var sb := StaticBody3D.new()
			parent.add_child(sb)
			sb.add_child(cs)

	return mi
