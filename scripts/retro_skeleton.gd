class_name RetroSkeleton
extends Node3D

## Fears to Fathom Retro Low-Poly Character Skeleton Generator
## Forward orientation: -Z (Standard Godot forward axis)
##
## Visual design:
## - Faces use clean, front-aligned, background-removed portraits from charefs/
##   mapped onto a sculpted low-poly PS1/Fears-to-Fathom head (seamless skin match).
## - All body garments, hair, tudung (hijab), and accessories are built using
##   clean simple-colored low-poly geometry matching each character's reference photo.

@export var character_name: String = "Syazril"
@export var is_male: bool = true
@export var is_dad: bool = false

const PATH_ALEYSA_FACE   := "res://assets/characters/aleysa_face.png"
const PATH_AMELYA_FACE   := "res://assets/characters/amelya_face.png"
const PATH_SYAZRIL_FACE  := "res://assets/characters/syazril_face.png"
const PATH_SYAHIRUL_FACE := "res://assets/characters/syahirul_face.png"
const PATH_DAD_FACE      := "res://assets/characters/dad_face.png"
const ITEM_MODELS_SCRIPT  := preload("res://scripts/item_models.gd")

static var _texture_cache: Dictionary = {}

static func _get_tex(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	# Prefer direct PNG load from disk in workspace so freshly processed textures
	# take effect immediately without stale .ctex cache; fall back to ResourceLoader in exports.
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img:
			tex = ImageTexture.create_from_image(img)
	if not tex and ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res
	_texture_cache[path] = tex
	return tex

var pelvis_node: Node3D = null
var chest_node: Node3D = null
var neck_node: Node3D = null
var head_node: Node3D = null

var left_shoulder: Node3D = null
var left_upper_arm: Node3D = null
var left_elbow: Node3D = null
var left_forearm: Node3D = null
var left_hand: Node3D = null

var right_shoulder: Node3D = null
var right_upper_arm: Node3D = null
var right_elbow: Node3D = null
var right_forearm: Node3D = null
var right_hand: Node3D = null
var held_item_mount: Node3D = null
var held_item_model: Node3D = null
var current_held_mode: String = ""
var crank_arm_ref: Node3D = null

var left_hip: Node3D = null
var left_thigh: Node3D = null
var left_knee: Node3D = null
var left_shin: Node3D = null
var left_foot: Node3D = null

var right_hip: Node3D = null
var right_thigh: Node3D = null
var right_knee: Node3D = null
var right_shin: Node3D = null
var right_foot: Node3D = null

var anim_timer: float = 0.0
var walk_cycle: float = 0.0
var base_pelvis_y: float = 0.88


static func create_character(p_name: String) -> RetroSkeleton:
	var skel := RetroSkeleton.new()
	skel.character_name = p_name
	var norm_name := p_name.to_lower()
	if "dad" in norm_name or "ayah" in norm_name:
		skel.is_male = true
		skel.is_dad = true
	elif "syazril" in norm_name or "syahirul" in norm_name:
		skel.is_male = true
		skel.is_dad = false
	elif "amelya" in norm_name or "aleysa" in norm_name:
		skel.is_male = false
		skel.is_dad = false
	else:
		skel.is_male = true
		skel.is_dad = false
	skel._build_skeleton()
	return skel


func _build_skeleton() -> void:
	for child in get_children():
		child.queue_free()

	var norm := character_name.to_lower()
	var is_aleysa   := ("aleysa" in norm)
	var is_amelya   := ("amelya" in norm)
	var is_syazril  := ("syazril" in norm)
	var is_syahirul := ("syahirul" in norm)
	var is_female   := is_aleysa or is_amelya

	# Proportions: Male (~1.82m, Dad ~1.85m), Female (~1.66m)
	var height_mult: float = 1.05 if is_male else 0.92
	if is_dad:
		height_mult = 1.07

	var shoulder_hw: float = 0.22 if is_male else 0.17
	var hip_hw: float = 0.11 if is_male else 0.072
	var chest_w: float = 0.38 if is_male else 0.295
	var chest_h: float = 0.44 * height_mult
	var chest_d: float = 0.21 if is_male else 0.17
	var limb_thickness: float = 1.08 if is_male else 0.89
	if is_dad:
		chest_w *= 1.05
		chest_d *= 1.08

	base_pelvis_y = 0.86 * height_mult

	# Select face texture (only face uses photo texture; everything else is simple solid color)
	var face_tex: Texture2D = null
	if is_aleysa:
		face_tex = _get_tex(PATH_ALEYSA_FACE)
	elif is_amelya:
		face_tex = _get_tex(PATH_AMELYA_FACE)
	elif is_syazril:
		face_tex = _get_tex(PATH_SYAZRIL_FACE)
	elif is_syahirul:
		face_tex = _get_tex(PATH_SYAHIRUL_FACE)
	else:
		face_tex = _get_tex(PATH_DAD_FACE)

	var p := _get_palette()
	var skin_mat   := _make_mat(p.skin)
	var shirt_mat  := _make_mat(p.shirt)
	var pants_mat  := _make_mat(p.pants)
	var shoes_mat  := _make_mat(p.shoes)
	var hair_mat   := _make_mat(p.hair)
	var tudung_mat := _make_mat(p.get("tudung", p.hair))

	# === ROOT / PELVIS ===
	pelvis_node = Node3D.new()
	pelvis_node.name = "Pelvis"
	pelvis_node.position.y = base_pelvis_y
	add_child(pelvis_node)

	var pelvis_mat := shirt_mat if is_female else pants_mat
	var pelvis_mesh := _create_box(
		Vector3(chest_w * 0.92, 0.16 * height_mult, chest_d * 0.94),
		pelvis_mat,
		Vector3(0.0, 0.0, 0.0)
	)
	pelvis_node.add_child(pelvis_mesh)

	if is_female:
		# Baju Kurung long tunic hem falling gracefully over hips/upper thighs
		var tunic_hem := _create_box(
			Vector3(chest_w * 1.00, 0.24 * height_mult, chest_d * 1.02),
			shirt_mat,
			Vector3(0.0, -0.10 * height_mult, 0.0)
		)
		pelvis_node.add_child(tunic_hem)
	else:
		# Male belt & subtle buckle (front -Z)
		var belt_mesh := _create_box(
			Vector3(chest_w * 0.94, 0.036, chest_d * 0.96),
			_make_mat(Color(0.11, 0.09, 0.08)),
			Vector3(0.0, 0.07 * height_mult, 0.0)
		)
		pelvis_node.add_child(belt_mesh)

		var belt_buckle := _create_box(
			Vector3(0.052, 0.038, 0.012),
			_make_mat(Color(0.80, 0.66, 0.28)),
			Vector3(0.0, 0.07 * height_mult, -chest_d * 0.485)
		)
		pelvis_node.add_child(belt_buckle)

	# === CHEST / TORSO ===
	chest_node = Node3D.new()
	chest_node.name = "Chest"
	chest_node.position.y = 0.08 * height_mult
	pelvis_node.add_child(chest_node)

	var torso_mesh := _create_box(
		Vector3(chest_w, chest_h, chest_d),
		shirt_mat,
		Vector3(0.0, chest_h * 0.5, 0.0)
	)
	chest_node.add_child(torso_mesh)

	# Simple-colored Character Chest & Attire Details
	if is_aleysa:
		# Dusty mauve-pink hijab chest wrap + pointed front drape + black/white nametag badge
		var drape_main := _create_box(
			Vector3(chest_w * 0.86, 0.16 * height_mult, 0.026),
			tudung_mat,
			Vector3(0.0, chest_h * 0.84, -chest_d * 0.5 - 0.013)
		)
		chest_node.add_child(drape_main)

		var drape_tip := _create_box(
			Vector3(chest_w * 0.56, 0.11 * height_mult, 0.022),
			_make_mat(p.tudung.darkened(0.08)),
			Vector3(0.0, chest_h * 0.63, -chest_d * 0.5 - 0.011)
		)
		chest_node.add_child(drape_tip)

		# Name tag badge flush on left chest (-X in Godot space -> viewer's right, matching photo)
		var badge_bg := _create_box(
			Vector3(0.056, 0.018, 0.004),
			_make_mat(Color(0.10, 0.10, 0.12)),
			Vector3(-0.072, chest_h * 0.68, -chest_d * 0.5 - 0.025)
		)
		var badge_tag := _create_box(
			Vector3(0.018, 0.013, 0.005),
			_make_mat(Color(0.92, 0.92, 0.92)),
			Vector3(-0.090, chest_h * 0.68, -chest_d * 0.5 - 0.026)
		)
		chest_node.add_child(badge_bg)
		chest_node.add_child(badge_tag)

	elif is_amelya:
		# Sage green tudung long draped shawl across chest
		var drape_top := _create_box(
			Vector3(chest_w * 0.86, 0.19 * height_mult, 0.026),
			tudung_mat,
			Vector3(0.0, chest_h * 0.80, -chest_d * 0.5 - 0.013)
		)
		chest_node.add_child(drape_top)

		var drape_long := _create_box(
			Vector3(chest_w * 0.52, 0.24 * height_mult, 0.020),
			_make_mat(p.tudung.darkened(0.08)),
			Vector3(-0.012, chest_h * 0.44, -chest_d * 0.5 - 0.012)
		)
		chest_node.add_child(drape_long)

		# Delicate white lace shoulder embroidery (matching Amelya.png)
		var lace_mat := _make_mat(Color(0.96, 0.95, 0.93))
		var lace_shoulder := _create_box(
			Vector3(0.088, 0.045, 0.092),
			lace_mat,
			Vector3(-chest_w * 0.40, chest_h * 0.88, 0.0)
		)
		chest_node.add_child(lace_shoulder)

	elif is_syazril:
		# Flush white Adidas shoulder stripes across top of shoulders & white Trefoil badge
		var white_mat := _make_mat(Color(0.93, 0.93, 0.93))
		for s in range(3):
			var z_off: float = -0.036 + s * 0.036
			var sh_str_l := _create_box(Vector3(0.105, 0.005, 0.016), white_mat, Vector3(-chest_w * 0.37, chest_h + 0.001, z_off))
			var sh_str_r := _create_box(Vector3(0.105, 0.005, 0.016), white_mat, Vector3(chest_w * 0.37, chest_h + 0.001, z_off))
			chest_node.add_child(sh_str_l)
			chest_node.add_child(sh_str_r)

		# White minimalist geometric Adidas trefoil emblem on right chest (+X / viewer's left, matching photo)
		var logo_x := 0.095
		var logo_y := chest_h * 0.69
		var logo_z := -chest_d * 0.5 - 0.004
		var petal_c := _create_box(Vector3(0.014, 0.032, 0.006), white_mat, Vector3(logo_x, logo_y + 0.006, logo_z))
		var petal_l := _create_box(Vector3(0.012, 0.026, 0.006), white_mat, Vector3(logo_x - 0.015, logo_y + 0.001, logo_z))
		petal_l.rotation_degrees.z = 32.0
		var petal_r := _create_box(Vector3(0.012, 0.026, 0.006), white_mat, Vector3(logo_x + 0.015, logo_y + 0.001, logo_z))
		petal_r.rotation_degrees.z = -32.0
		var logo_bar := _create_box(Vector3(0.044, 0.008, 0.006), white_mat, Vector3(logo_x, logo_y - 0.016, logo_z))
		chest_node.add_child(petal_c)
		chest_node.add_child(petal_l)
		chest_node.add_child(petal_r)
		chest_node.add_child(logo_bar)

		# Navy crewneck rim
		var collar_rim := _create_box(Vector3(0.16, 0.018, 0.14), _make_mat(Color(0.06, 0.10, 0.21)), Vector3(0.0, chest_h + 0.005, -0.015))
		chest_node.add_child(collar_rim)

	elif is_syahirul:
		# Subtle darker red crewneck collar ribbing (matching red crewneck tee)
		var collar_rim := _create_box(Vector3(0.16, 0.020, 0.14), _make_mat(Color(0.56, 0.07, 0.14)), Vector3(0.0, chest_h + 0.005, -0.015))
		chest_node.add_child(collar_rim)

	elif is_dad:
		# Dad Polo Shirt Collar flaps & buttons (front is -Z)
		var collar_mat := _make_mat(Color(0.58, 0.52, 0.38))
		var collar_l := _create_box(Vector3(0.065, 0.042, 0.015), collar_mat, Vector3(-0.055, chest_h - 0.01, -chest_d * 0.5 - 0.008))
		collar_l.rotation_degrees.z = -18.0
		var collar_r := _create_box(Vector3(0.065, 0.042, 0.015), collar_mat, Vector3(0.055, chest_h - 0.01, -chest_d * 0.5 - 0.008))
		collar_r.rotation_degrees.z = 18.0
		var button_strip := _create_box(Vector3(0.028, 0.13, 0.012), _make_mat(Color(0.42, 0.36, 0.25)), Vector3(0.0, chest_h - 0.08, -chest_d * 0.5 - 0.006))
		chest_node.add_child(collar_l)
		chest_node.add_child(collar_r)
		chest_node.add_child(button_strip)

	# === NECK ===
	neck_node = Node3D.new()
	neck_node.name = "Neck"
	neck_node.position.y = chest_h
	chest_node.add_child(neck_node)

	var neck_mat := tudung_mat if is_female else skin_mat
	var neck_mesh := _create_cylinder(0.064 * limb_thickness, 0.074 * limb_thickness, 0.095 * height_mult, neck_mat, Vector3(0.0, 0.036 * height_mult, 0.0))
	neck_node.add_child(neck_mesh)

	# === HEAD (Sculpted Retro Low-Poly Head with Planar-Projected Photo Face) ===
	head_node = Node3D.new()
	head_node.name = "Head"
	head_node.position.y = 0.055 * height_mult
	neck_node.add_child(head_node)

	var head_scale := 1.0 if is_male else 0.93
	var head_mesh := _create_sculpted_head(head_scale, face_tex, skin_mat)
	head_node.add_child(head_mesh)

	# Ears for male characters (female ears are concealed under the tudung)
	if not is_female:
		var ear_l := _create_box(Vector3(0.022, 0.052, 0.036) * head_scale, skin_mat, Vector3(-0.095 * head_scale, 0.122 * head_scale, 0.004 * head_scale))
		var ear_r := _create_box(Vector3(0.022, 0.052, 0.036) * head_scale, skin_mat, Vector3(0.095 * head_scale, 0.122 * head_scale, 0.004 * head_scale))
		head_node.add_child(ear_l)
		head_node.add_child(ear_r)

	# === HEADWEAR: SIMPLE-COLORED HIJAB (TUDUNG) OR HAIR + SUNGLASSES ===
	if is_female:
		# Contoured tudung hood hugging the sculpted head & jaw cleanly without boxy blinders or chin gaps
		var tudung_top := _create_box(
			Vector3(0.184, 0.056, 0.194) * head_scale,
			tudung_mat,
			Vector3(0.0, 0.213 * head_scale, 0.008 * head_scale)
		)
		head_node.add_child(tudung_top)

		# Soft curved awning halves gently framing forehead right above brows (authentic Malay tudung curve)
		var arch_l := _create_box(
			Vector3(0.092, 0.032, 0.052) * head_scale,
			tudung_mat,
			Vector3(-0.043 * head_scale, 0.188 * head_scale, -0.072 * head_scale)
		)
		arch_l.rotation_degrees.z = 14.0
		var arch_r := _create_box(
			Vector3(0.092, 0.032, 0.052) * head_scale,
			tudung_mat,
			Vector3(0.043 * head_scale, 0.188 * head_scale, -0.072 * head_scale)
		)
		arch_r.rotation_degrees.z = -14.0
		head_node.add_child(arch_l)
		head_node.add_child(arch_r)

		# Back drapery enclosing back skull & neck cleanly
		var tudung_back := _create_box(
			Vector3(0.184, 0.236, 0.064) * head_scale,
			tudung_mat,
			Vector3(0.0, 0.096 * head_scale, 0.084 * head_scale)
		)
		head_node.add_child(tudung_back)

		# Cheek-to-jaw drapes tapering subtly inward toward chin while staying flush with crown width
		var tudung_side_l := _create_box(
			Vector3(0.030, 0.190, 0.176) * head_scale,
			tudung_mat,
			Vector3(-0.074 * head_scale, 0.094 * head_scale, 0.006 * head_scale)
		)
		tudung_side_l.rotation_degrees = Vector3(0.0, -7.0, 5.0)
		var tudung_side_r := _create_box(
			Vector3(0.030, 0.190, 0.176) * head_scale,
			tudung_mat,
			Vector3(0.074 * head_scale, 0.094 * head_scale, 0.006 * head_scale)
		)
		tudung_side_r.rotation_degrees = Vector3(0.0, 7.0, -5.0)
		head_node.add_child(tudung_side_l)
		head_node.add_child(tudung_side_r)

		# Full solid wrap-around chin & collar base sealing under jawline into neck
		var tudung_chin := _create_box(
			Vector3(0.168, 0.056, 0.174) * head_scale,
			tudung_mat,
			Vector3(0.0, -0.004 * head_scale, 0.002 * head_scale)
		)
		tudung_chin.rotation_degrees.x = 6.0
		head_node.add_child(tudung_chin)

	else:
		# --- Male Hair & Accessories ---
		# Main hair crown hugging cranium cleanly above forehead
		var hair_top := _create_box(
			Vector3(0.184, 0.050, 0.192) * head_scale,
			hair_mat,
			Vector3(0.0, 0.218 * head_scale, 0.010 * head_scale)
		)
		head_node.add_child(hair_top)

		# Hair back panel
		var hair_back := _create_box(
			Vector3(0.180, 0.155, 0.046) * head_scale,
			hair_mat,
			Vector3(0.0, 0.130 * head_scale, 0.084 * head_scale)
		)
		head_node.add_child(hair_back)

		# Side temples & sideburns (cleanly behind face front at z > -0.045)
		var temple_l := _create_box(Vector3(0.022, 0.105, 0.092) * head_scale, hair_mat, Vector3(-0.084 * head_scale, 0.165 * head_scale, 0.022 * head_scale))
		var temple_r := _create_box(Vector3(0.022, 0.105, 0.092) * head_scale, hair_mat, Vector3(0.084 * head_scale, 0.165 * head_scale, 0.022 * head_scale))
		head_node.add_child(temple_l)
		head_node.add_child(temple_r)

		if is_syazril:
			# Voluminous stylish wavy dark hair & textured bangs framing upper forehead
			var hair_vol := _create_box(Vector3(0.172, 0.038, 0.145), hair_mat, Vector3(0.0, 0.246, -0.010))
			var fringe_l := _create_box(Vector3(0.090, 0.034, 0.044), hair_mat, Vector3(-0.042, 0.190, -0.080))
			fringe_l.rotation_degrees.z = 7.0
			var fringe_r := _create_box(Vector3(0.094, 0.038, 0.046), hair_mat, Vector3(0.038, 0.185, -0.082))
			fringe_r.rotation_degrees.z = -8.0
			head_node.add_child(hair_vol)
			head_node.add_child(fringe_l)
			head_node.add_child(fringe_r)

		elif is_syahirul:
			# Tidy short dark hairline (leaves forehead clearly open) + 3D BLACK SUNGLASSES perched on top!
			var hairline := _create_box(Vector3(0.168, 0.028, 0.040), hair_mat, Vector3(0.0, 0.200, -0.072))
			head_node.add_child(hairline)

			# Perched Black Sunglasses sitting clearly ON TOP of hair_top front edge (y=0.252, z=-0.065..-0.098)
			var sg_frame_mat := _make_mat(Color(0.09, 0.09, 0.11))
			var sg_lens_mat := _make_mat(Color(0.03, 0.03, 0.04))
			sg_lens_mat.roughness = 0.22
			sg_lens_mat.metallic = 0.25

			var sg_bridge := _create_box(Vector3(0.168, 0.018, 0.022), sg_frame_mat, Vector3(0.0, 0.258, -0.082))
			var sg_lens_l := _create_box(Vector3(0.062, 0.036, 0.016), sg_lens_mat, Vector3(-0.045, 0.250, -0.088))
			sg_lens_l.rotation_degrees.x = 18.0
			var sg_lens_r := _create_box(Vector3(0.062, 0.036, 0.016), sg_lens_mat, Vector3(0.045, 0.250, -0.088))
			sg_lens_r.rotation_degrees.x = 18.0
			# Sunglass temple arms sweeping back over hair sides
			var sg_arm_l := _create_box(Vector3(0.010, 0.012, 0.115), sg_frame_mat, Vector3(-0.092, 0.242, -0.025))
			sg_arm_l.rotation_degrees.x = -12.0
			var sg_arm_r := _create_box(Vector3(0.010, 0.012, 0.115), sg_frame_mat, Vector3(0.092, 0.242, -0.025))
			sg_arm_r.rotation_degrees.x = -12.0
			head_node.add_child(sg_bridge)
			head_node.add_child(sg_lens_l)
			head_node.add_child(sg_lens_r)
			head_node.add_child(sg_arm_l)
			head_node.add_child(sg_arm_r)

		elif is_dad:
			# Mature swept hair with grey temple flecks flush to skull
			var hairline := _create_box(Vector3(0.162, 0.028, 0.038), hair_mat, Vector3(0.0, 0.196, -0.072))
			var grey_mat := _make_mat(Color(0.52, 0.50, 0.49))
			var grey_l := _create_box(Vector3(0.024, 0.045, 0.044), grey_mat, Vector3(-0.085, 0.150, 0.010))
			var grey_r := _create_box(Vector3(0.024, 0.045, 0.044), grey_mat, Vector3(0.085, 0.150, 0.010))
			head_node.add_child(hairline)
			head_node.add_child(grey_l)
			head_node.add_child(grey_r)

	# === SHOULDERS & ARMS (Simple Colored) ===
	var arm_len := 0.26 * height_mult
	var forearm_len := 0.24 * height_mult

	# Left Arm (-X)
	left_shoulder = Node3D.new()
	left_shoulder.name = "LeftShoulder"
	left_shoulder.position = Vector3(-shoulder_hw, chest_h * 0.90, 0.0)
	left_shoulder.rotation_degrees.z = -7.0
	chest_node.add_child(left_shoulder)

	left_upper_arm = Node3D.new()
	left_upper_arm.name = "LeftUpperArm"
	left_shoulder.add_child(left_upper_arm)

	if is_female:
		var l_sleeve := _create_box(Vector3(0.092 * limb_thickness, arm_len * 1.03, 0.092 * limb_thickness), shirt_mat, Vector3(0.0, -arm_len * 0.50, 0.0))
		left_upper_arm.add_child(l_sleeve)
	else:
		var l_sleeve := _create_box(Vector3(0.096 * limb_thickness, arm_len * 0.55, 0.096 * limb_thickness), shirt_mat, Vector3(0.0, -arm_len * 0.27, 0.0))
		var l_uarm_skin := _create_box(Vector3(0.084 * limb_thickness, arm_len * 0.52, 0.084 * limb_thickness), skin_mat, Vector3(0.0, -arm_len * 0.76, 0.0))
		left_upper_arm.add_child(l_sleeve)
		left_upper_arm.add_child(l_uarm_skin)
		if is_syazril:
			# 3 white Adidas stripes running down outer sleeve
			var white_mat := _make_mat(Color(0.93, 0.93, 0.93))
			for s in range(3):
				var str_l := _create_box(Vector3(0.008 * limb_thickness, arm_len * 0.50, 0.015 * limb_thickness), white_mat, Vector3(-0.050 * limb_thickness, -arm_len * 0.27, (-0.026 + s * 0.026) * limb_thickness))
				left_upper_arm.add_child(str_l)

	left_elbow = Node3D.new()
	left_elbow.name = "LeftElbow"
	left_elbow.position.y = -arm_len
	left_upper_arm.add_child(left_elbow)

	left_forearm = Node3D.new()
	left_forearm.name = "LeftForearm"
	left_elbow.add_child(left_forearm)

	if is_aleysa:
		var l_farm_mesh := _create_box(Vector3(0.084 * limb_thickness, forearm_len * 1.06, 0.084 * limb_thickness), shirt_mat, Vector3(0.0, -forearm_len * 0.48, 0.0))
		left_forearm.add_child(l_farm_mesh)
	elif is_amelya:
		var l_farm_mesh := _create_box(Vector3(0.084 * limb_thickness, forearm_len * 1.06, 0.084 * limb_thickness), shirt_mat, Vector3(0.0, -forearm_len * 0.48, 0.0))
		var lace_cuff := _create_box(Vector3(0.092 * limb_thickness, 0.056, 0.092 * limb_thickness), _make_mat(Color(0.91, 0.89, 0.88)), Vector3(0.0, -forearm_len * 0.80, 0.0))
		left_forearm.add_child(l_farm_mesh)
		left_forearm.add_child(lace_cuff)
	else:
		var l_farm_mesh := _create_box(Vector3(0.075 * limb_thickness, forearm_len * 1.06, 0.075 * limb_thickness), skin_mat, Vector3(0.0, -forearm_len * 0.48, 0.0))
		left_forearm.add_child(l_farm_mesh)

	# Syazril G-Shock Watch on Left Wrist / Dad Gold Watch on Left Wrist
	if is_syazril:
		var watch_mesh := _create_box(Vector3(0.088, 0.032, 0.088), _make_mat(Color(0.11, 0.11, 0.13)), Vector3(0.0, -forearm_len * 0.85, 0.0))
		var watch_dial := _create_box(Vector3(0.038, 0.034, 0.015), _make_mat(Color(0.62, 0.66, 0.68)), Vector3(0.0, -forearm_len * 0.85, -0.046))
		left_forearm.add_child(watch_mesh)
		left_forearm.add_child(watch_dial)
	elif is_dad:
		var watch_mesh := _create_box(Vector3(0.084, 0.025, 0.084), _make_mat(Color(0.20, 0.18, 0.15)), Vector3(0.0, -forearm_len * 0.88, 0.0))
		var watch_face := _create_box(Vector3(0.034, 0.028, 0.014), _make_mat(Color(0.85, 0.70, 0.30)), Vector3(0.0, -forearm_len * 0.88, -0.044))
		left_forearm.add_child(watch_mesh)
		left_forearm.add_child(watch_face)

	left_hand = Node3D.new()
	left_hand.name = "LeftHand"
	left_hand.position.y = -forearm_len
	left_forearm.add_child(left_hand)
	left_hand.add_child(_create_box(Vector3(0.065 * limb_thickness, 0.085, 0.045 * limb_thickness), skin_mat, Vector3(0.0, -0.042, 0.0)))

	# Right Arm (+X)
	right_shoulder = Node3D.new()
	right_shoulder.name = "RightShoulder"
	right_shoulder.position = Vector3(shoulder_hw, chest_h * 0.90, 0.0)
	right_shoulder.rotation_degrees.z = 7.0
	chest_node.add_child(right_shoulder)

	right_upper_arm = Node3D.new()
	right_upper_arm.name = "RightUpperArm"
	right_shoulder.add_child(right_upper_arm)

	if is_female:
		var r_sleeve := _create_box(Vector3(0.092 * limb_thickness, arm_len * 1.03, 0.092 * limb_thickness), shirt_mat, Vector3(0.0, -arm_len * 0.50, 0.0))
		right_upper_arm.add_child(r_sleeve)
	else:
		var r_sleeve := _create_box(Vector3(0.096 * limb_thickness, arm_len * 0.55, 0.096 * limb_thickness), shirt_mat, Vector3(0.0, -arm_len * 0.27, 0.0))
		var r_uarm_skin := _create_box(Vector3(0.084 * limb_thickness, arm_len * 0.52, 0.084 * limb_thickness), skin_mat, Vector3(0.0, -arm_len * 0.76, 0.0))
		right_upper_arm.add_child(r_sleeve)
		right_upper_arm.add_child(r_uarm_skin)
		if is_syazril:
			var white_mat := _make_mat(Color(0.93, 0.93, 0.93))
			for s in range(3):
				var str_r := _create_box(Vector3(0.008 * limb_thickness, arm_len * 0.50, 0.015 * limb_thickness), white_mat, Vector3(0.050 * limb_thickness, -arm_len * 0.27, (-0.026 + s * 0.026) * limb_thickness))
				right_upper_arm.add_child(str_r)

	right_elbow = Node3D.new()
	right_elbow.name = "RightElbow"
	right_elbow.position.y = -arm_len
	right_upper_arm.add_child(right_elbow)

	right_forearm = Node3D.new()
	right_forearm.name = "RightForearm"
	right_elbow.add_child(right_forearm)

	if is_aleysa:
		var r_farm_mesh := _create_box(Vector3(0.084 * limb_thickness, forearm_len * 1.06, 0.084 * limb_thickness), shirt_mat, Vector3(0.0, -forearm_len * 0.48, 0.0))
		right_forearm.add_child(r_farm_mesh)
		# Subtle gold bracelet on right wrist matching Aleysa.png
		var bracelet := _create_box(Vector3(0.088 * limb_thickness, 0.016, 0.088 * limb_thickness), _make_mat(Color(0.86, 0.70, 0.28)), Vector3(0.0, -forearm_len * 0.92, 0.0))
		right_forearm.add_child(bracelet)
	elif is_amelya:
		var r_farm_mesh := _create_box(Vector3(0.084 * limb_thickness, forearm_len * 1.06, 0.084 * limb_thickness), shirt_mat, Vector3(0.0, -forearm_len * 0.48, 0.0))
		var lace_cuff := _create_box(Vector3(0.092 * limb_thickness, 0.056, 0.092 * limb_thickness), _make_mat(Color(0.91, 0.89, 0.88)), Vector3(0.0, -forearm_len * 0.80, 0.0))
		right_forearm.add_child(r_farm_mesh)
		right_forearm.add_child(lace_cuff)
	else:
		var r_farm_mesh := _create_box(Vector3(0.075 * limb_thickness, forearm_len * 1.06, 0.075 * limb_thickness), skin_mat, Vector3(0.0, -forearm_len * 0.48, 0.0))
		right_forearm.add_child(r_farm_mesh)

	right_hand = Node3D.new()
	right_hand.name = "RightHand"
	right_hand.position.y = -forearm_len
	right_forearm.add_child(right_hand)
	right_hand.add_child(_create_box(Vector3(0.065 * limb_thickness, 0.085, 0.045 * limb_thickness), skin_mat, Vector3(0.0, -0.042, 0.0)))

	# Mount point for held 3D light sources / items in right hand
	held_item_mount = Node3D.new()
	held_item_mount.name = "HeldItemMount"
	held_item_mount.position = Vector3(0.0, -0.045, -0.035)
	right_hand.add_child(held_item_mount)

	# === HIPS & LEGS (Simple Colored) ===
	var thigh_len := 0.40 * height_mult
	var shin_len := 0.38 * height_mult

	# Left Leg (-X)
	left_hip = Node3D.new()
	left_hip.name = "LeftHip"
	left_hip.position = Vector3(-hip_hw, -0.06, 0.0)
	pelvis_node.add_child(left_hip)

	left_thigh = Node3D.new()
	left_thigh.name = "LeftThigh"
	left_hip.add_child(left_thigh)
	left_thigh.add_child(_create_box(Vector3((0.145 if is_female else 0.128) * limb_thickness, thigh_len * 1.06, (0.148 if is_female else 0.135) * limb_thickness), pants_mat, Vector3(0.0, -thigh_len * 0.50, 0.0)))

	left_knee = Node3D.new()
	left_knee.name = "LeftKnee"
	left_knee.position.y = -thigh_len
	left_thigh.add_child(left_knee)

	left_shin = Node3D.new()
	left_shin.name = "LeftShin"
	left_knee.add_child(left_shin)
	left_shin.add_child(_create_box(Vector3((0.138 if is_female else 0.108) * limb_thickness, shin_len * 1.08, (0.140 if is_female else 0.115) * limb_thickness), pants_mat, Vector3(0.0, -shin_len * 0.48, 0.0)))

	left_foot = Node3D.new()
	left_foot.name = "LeftFoot"
	left_foot.position.y = -shin_len
	left_shin.add_child(left_foot)
	var sole_col := Color(0.12, 0.08, 0.06) if (is_dad or is_amelya) else Color(0.84, 0.84, 0.84)
	left_foot.add_child(_create_box(Vector3(0.11 * limb_thickness, 0.085, 0.22 * limb_thickness), shoes_mat, Vector3(0.0, -0.042, -0.04)))
	left_foot.add_child(_create_box(Vector3(0.115 * limb_thickness, 0.025, 0.23 * limb_thickness), _make_mat(sole_col), Vector3(0.0, -0.085, -0.04)))

	# Right Leg (+X)
	right_hip = Node3D.new()
	right_hip.name = "RightHip"
	right_hip.position = Vector3(hip_hw, -0.06, 0.0)
	pelvis_node.add_child(right_hip)

	right_thigh = Node3D.new()
	right_thigh.name = "RightThigh"
	right_hip.add_child(right_thigh)
	right_thigh.add_child(_create_box(Vector3((0.145 if is_female else 0.128) * limb_thickness, thigh_len * 1.06, (0.148 if is_female else 0.135) * limb_thickness), pants_mat, Vector3(0.0, -thigh_len * 0.50, 0.0)))

	right_knee = Node3D.new()
	right_knee.name = "RightKnee"
	right_knee.position.y = -thigh_len
	right_thigh.add_child(right_knee)

	right_shin = Node3D.new()
	right_shin.name = "RightShin"
	right_knee.add_child(right_shin)
	right_shin.add_child(_create_box(Vector3((0.138 if is_female else 0.108) * limb_thickness, shin_len * 1.08, (0.140 if is_female else 0.115) * limb_thickness), pants_mat, Vector3(0.0, -shin_len * 0.48, 0.0)))

	right_foot = Node3D.new()
	right_foot.name = "RightFoot"
	right_foot.position.y = -shin_len
	right_shin.add_child(right_foot)
	right_foot.add_child(_create_box(Vector3(0.11 * limb_thickness, 0.085, 0.22 * limb_thickness), shoes_mat, Vector3(0.0, -0.042, -0.04)))
	right_foot.add_child(_create_box(Vector3(0.115 * limb_thickness, 0.025, 0.23 * limb_thickness), _make_mat(sole_col), Vector3(0.0, -0.085, -0.04)))


func _create_sculpted_head(head_scale: float, face_tex: Texture2D, fallback_skin_mat: Material) -> MeshInstance3D:
	## Sculpted retro Fears-to-Fathom low-poly head mesh.
	## Front facial facet is UV-mapped directly onto face_tex using canonical anatomical scaling
	## (eye separation ~6.6cm, full face fill) while temples, jaw, sides, and back skull sample skin corner.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Rings: wider front facial plane (w_f up to 0.074 = 14.8cm wide!) so cheeks, eyes, brows,
	# and mouth sit completely across the front face without pinching or wrapping sideways onto temples!
	# [y, w_f, w_m, w_b, z_f, z_fc, z_sf, z_sb, z_b]
	var ring_defs := [
		[0.020, 0.050, 0.068, 0.048, -0.084, -0.078, -0.020, 0.052, 0.078], # 0: Chin / Jawline
		[0.072, 0.068, 0.084, 0.058, -0.094, -0.088, -0.022, 0.060, 0.086], # 1: Cheeks / Mouth
		[0.133, 0.074, 0.088, 0.060, -0.096, -0.090, -0.020, 0.064, 0.092], # 2: Eyes / Brow ridge
		[0.192, 0.066, 0.080, 0.054, -0.088, -0.082, -0.014, 0.058, 0.086], # 3: Forehead crown
		[0.218, 0.036, 0.048, 0.034, -0.058, -0.054, -0.008, 0.040, 0.062], # 4: Upper cranium
	]

	var rings: Array = []
	for def in ring_defs:
		var y: float = def[0] * head_scale
		var wf: float = def[1] * head_scale
		var wm: float = def[2] * head_scale
		var wb: float = def[3] * head_scale
		var zf: float = def[4] * head_scale
		var zfc: float = def[5] * head_scale
		var zsf: float = def[6] * head_scale
		var zsb: float = def[7] * head_scale
		var zb: float = def[8] * head_scale
		rings.append([
			Vector3(0.0, y, zf),   # 0 Front center
			Vector3(-wf, y, zfc),  # 1 Front left
			Vector3(-wm, y, zsf),  # 2 Side-front left
			Vector3(-wm * 0.92, y, zsb), # 3 Side-back left
			Vector3(-wb, y, zb),   # 4 Back left
			Vector3(wb, y, zb),    # 5 Back right
			Vector3(wm * 0.92, y, zsb),  # 6 Side-back right
			Vector3(wm, y, zsf),   # 7 Side-front right
			Vector3(wf, y, zfc),   # 8 Front right
		])

	var bot_pole := Vector3(0.0, 0.006 * head_scale, -0.010 * head_scale)
	var top_pole := Vector3(0.0, 0.226 * head_scale, 0.004 * head_scale)
	var skin_uv := Vector2(0.03, 0.03)

	var front_uv := func(vtx: Vector3, is_front_face: bool) -> Vector2:
		if not is_front_face:
			return skin_uv
		var nx := vtx.x / head_scale
		var ny := vtx.y / head_scale
		# Scale 0.240 x 0.226 aligns canonical eye span (~0.274 U) to 6.6cm anatomical eye spacing
		# and keeps the full face oval spanning cleanly cheek-to-cheek and chin-to-forehead
		var u := clampf(0.5 - nx / 0.224, 0.02, 0.98)
		var v := clampf(0.398 + (0.122 - ny) / 0.234, 0.02, 0.98)
		return Vector2(u, v)

	var add_tri_outward := func(a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, ref_center: Vector3) -> void:
		var tri_center := (a + b + c) / 3.0
		var desired := (tri_center - ref_center).normalized()
		# Godot/Vulkan front-face normal for vertices added in order (a, b, c)
		var n_ab_ac := (b - a).cross(c - a)
		var n_ac_ab := (c - a).cross(b - a)
		# Note: SurfaceTool.generate_normals() uses (c - a).cross(b - a) in Godot (clockwise front face).
		if n_ac_ab.dot(desired) >= 0.0:
			st.set_uv(uva); st.add_vertex(a)
			st.set_uv(uvb); st.add_vertex(b)
			st.set_uv(uvc); st.add_vertex(c)
		else:
			st.set_uv(uva); st.add_vertex(a)
			st.set_uv(uvc); st.add_vertex(c)
			st.set_uv(uvb); st.add_vertex(b)

	var head_center := Vector3(0.0, 0.115 * head_scale, 0.0)
	var n_pts := 9

	# Side bands between rings 0..4
	for r_idx in range(rings.size() - 1):
		var r0: Array = rings[r_idx]
		var r1: Array = rings[r_idx + 1]
		for i in range(n_pts):
			var j := (i + 1) % n_pts
			# Front facial UVs strictly on rings 0..3 front-facing wedges (slots 7-8, 8-0, 0-1, 1-2)
			var is_front := (r_idx <= 2) and (i == 7 or i == 8 or i == 0 or i == 1)
			var v00: Vector3 = r0[i]
			var v01: Vector3 = r0[j]
			var v10: Vector3 = r1[i]
			var v11: Vector3 = r1[j]
			var uv00: Vector2 = front_uv.call(v00, is_front)
			var uv01: Vector2 = front_uv.call(v01, is_front)
			var uv10: Vector2 = front_uv.call(v10, is_front)
			var uv11: Vector2 = front_uv.call(v11, is_front)
			add_tri_outward.call(v00, v01, v11, uv00, uv01, uv11, head_center)
			add_tri_outward.call(v00, v11, v10, uv00, uv11, uv10, head_center)

	# Bottom cap (ring 0 -> bot_pole)
	var r_bot: Array = rings[0]
	for i in range(n_pts):
		var j := (i + 1) % n_pts
		add_tri_outward.call(r_bot[i], bot_pole, r_bot[j], skin_uv, skin_uv, skin_uv, head_center)

	# Top cap (ring 4 -> top_pole)
	var r_top: Array = rings[rings.size() - 1]
	for i in range(n_pts):
		var j := (i + 1) % n_pts
		add_tri_outward.call(r_top[i], r_top[j], top_pole, skin_uv, skin_uv, skin_uv, head_center)

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if face_tex:
		mi.material_override = _make_textured_mat(face_tex, Color.WHITE, false)
	else:
		mi.material_override = fallback_skin_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func update_held_item(mode: String, is_light_on: bool = false) -> void:
	if mode == current_held_mode and is_instance_valid(held_item_model):
		return
	current_held_mode = mode

	if is_instance_valid(held_item_model):
		held_item_model.queue_free()
		held_item_model = null
		crank_arm_ref = null

	if mode.is_empty() or mode == "disabled" or held_item_mount == null:
		return

	held_item_model = ITEM_MODELS_SCRIPT.create_item(mode, false, is_light_on)
	if held_item_model:
		held_item_mount.add_child(held_item_model)
		if mode == "lantern":
			# Lantern held hanging under fist with base vertical compensation
			held_item_model.position = Vector3(0.0, -0.055, -0.015)
			held_item_model.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
		else:
			# Flashlights (normal, crank, uv) point forward horizontally in the gripped hand
			held_item_model.position = Vector3(0.0, -0.025, -0.015)
			held_item_model.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		crank_arm_ref = held_item_model.get_meta("crank_arm") if held_item_model.has_meta("crank_arm") else null


func update_pose(speed: float, is_moving: bool, is_crouching: bool, delta: float, is_sprinting: bool = false, held_mode: String = "", is_cranking: bool = false, head_pitch: float = 0.0, is_light_on: bool = false, crank_reach_blend: float = 0.0) -> void:
	anim_timer += delta

	var has_item: bool = not (held_mode.is_empty() or held_mode == "disabled")
	var is_lantern: bool = (held_mode == "lantern")
	var is_crank_item: bool = (held_mode == "crank")

	# Check and synchronize held item in 3rd person
	if held_mode != current_held_mode or (has_item and (held_item_model == null or not is_instance_valid(held_item_model))):
		update_held_item(held_mode, is_light_on)
	elif held_item_model and is_instance_valid(held_item_model):
		ITEM_MODELS_SCRIPT.set_item_light_state(held_item_model, is_light_on, held_mode)

	# Rotate mechanical crank arm on dynamo model when cranking
	if is_cranking and crank_arm_ref and is_instance_valid(crank_arm_ref):
		crank_arm_ref.rotation.x += delta * 24.0

	# === BIOMECHANICAL AIM KINEMATICS (Hips, Spine, Neck, Head) ===
	# Natural multi-joint distribution of player aim pitch across the full skeletal chain:
	# Pelvis (10%) + Torso/Chest (22%) + Neck (18%) + Head (44%) = 94% aim line-of-sight tracking.
	var pitch_clamped := clampf(head_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))
	var pelvis_pitch: float = pitch_clamped * 0.10
	var hip_balance_z: float = -pitch_clamped * 0.045
	var chest_pitch: float = pitch_clamped * 0.22
	var neck_pitch: float = pitch_clamped * 0.18
	var head_sub_pitch: float = pitch_clamped * 0.44

	# Head and Neck actively follow player aim pitch
	if neck_node:
		neck_node.rotation.x = lerpf(neck_node.rotation.x, neck_pitch, delta * 12.0)
	if head_node:
		head_node.rotation.x = lerpf(head_node.rotation.x, head_sub_pitch, delta * 12.0)

	# === CROUCHING / STANDING KINEMATICS ===
	if is_crouching:
		# Pelvis drops down and shifts back to balance center of gravity over feet
		pelvis_node.position.y = lerpf(pelvis_node.position.y, base_pelvis_y - 0.28, delta * 9.0)
		pelvis_node.position.z = lerpf(pelvis_node.position.z, 0.05 + hip_balance_z, delta * 9.0)
		pelvis_node.rotation.x = lerpf(pelvis_node.rotation.x, deg_to_rad(-4.0) + pelvis_pitch, delta * 8.0)
		pelvis_node.rotation.z = lerpf(pelvis_node.rotation.z, 0.0, delta * 8.0)
		if chest_node:
			chest_node.rotation.x = lerpf(chest_node.rotation.x, deg_to_rad(-16.0) + chest_pitch, delta * 8.0)
			chest_node.rotation.y = lerpf(chest_node.rotation.y, 0.0, delta * 8.0)

		# Anatomical crouch: thighs angle FORWARD (+X), knees bend BACKWARD (-X), feet level (+X)
		# Counter-rotate hip angle by pelvis_pitch so feet remain firmly planted on the ground
		var crouch_hip_angle := deg_to_rad(45.0) - pelvis_pitch
		var crouch_knee_angle := deg_to_rad(-80.0)
		var crouch_foot_angle := deg_to_rad(35.0)

		if is_moving and speed > 0.1:
			# Low, stealthy crouch-walk / creep gait
			walk_cycle += delta * (speed * 2.8)
			var creep_step := sin(walk_cycle) * 0.18
			if left_hip: left_hip.rotation.x = crouch_hip_angle - creep_step
			if right_hip: right_hip.rotation.x = crouch_hip_angle + creep_step
			if left_knee: left_knee.rotation.x = crouch_knee_angle - maxf(0.0, -creep_step) * 0.25
			if right_knee: right_knee.rotation.x = crouch_knee_angle - maxf(0.0, creep_step) * 0.25
			if left_foot: left_foot.rotation.x = crouch_foot_angle - creep_step * 0.3
			if right_foot: right_foot.rotation.x = crouch_foot_angle + creep_step * 0.3
		else:
			# Idle crouch pose
			if left_hip: left_hip.rotation.x = lerpf(left_hip.rotation.x, crouch_hip_angle, delta * 8.0)
			if right_hip: right_hip.rotation.x = lerpf(right_hip.rotation.x, crouch_hip_angle, delta * 8.0)
			if left_knee: left_knee.rotation.x = lerpf(left_knee.rotation.x, crouch_knee_angle, delta * 8.0)
			if right_knee: right_knee.rotation.x = lerpf(right_knee.rotation.x, crouch_knee_angle, delta * 8.0)
			if left_foot: left_foot.rotation.x = lerpf(left_foot.rotation.x, crouch_foot_angle, delta * 8.0)
			if right_foot: right_foot.rotation.x = lerpf(right_foot.rotation.x, crouch_foot_angle, delta * 8.0)

	else:
		# Standing posture (Walking, Sprinting, or Idle)
		pelvis_node.position.z = lerpf(pelvis_node.position.z, hip_balance_z, delta * 8.0)

		if is_moving and speed > 0.1:
			var cadence := 3.4 if is_sprinting else 2.8
			walk_cycle += delta * (speed * cadence)
			var stride := 0.45 if is_sprinting else 0.32
			var leg_sin := sin(walk_cycle)

			# Pelvis vertical bounce (double-frequency) & subtle lateral hip sway
			var bounce_amp := 0.024 if is_sprinting else 0.014
			var bounce := sin(walk_cycle * 2.0) * bounce_amp
			pelvis_node.position.y = lerpf(pelvis_node.position.y, base_pelvis_y + bounce, delta * 12.0)
			pelvis_node.rotation.z = sin(walk_cycle) * (0.026 if is_sprinting else 0.016)

			# Torso: forward lean when sprinting, natural counter-rotation around Y + aim chest pitch
			var lean_x := deg_to_rad(-8.5) if is_sprinting else deg_to_rad(-1.5)
			pelvis_node.rotation.x = lerpf(pelvis_node.rotation.x, (deg_to_rad(-4.0) if is_sprinting else 0.0) + pelvis_pitch, delta * 8.0)
			if chest_node:
				chest_node.rotation.x = lerpf(chest_node.rotation.x, lean_x + chest_pitch, delta * 8.0)
				chest_node.rotation.y = -sin(walk_cycle) * (0.048 if is_sprinting else 0.032)

			# Leg swing & knee flexion (counter-compensating pelvis_pitch so feet stay grounded):
			var knee_flex := 0.70 if is_sprinting else 0.48
			if left_hip: left_hip.rotation.x = -leg_sin * stride - pelvis_pitch
			if right_hip: right_hip.rotation.x = leg_sin * stride - pelvis_pitch

			if left_knee: left_knee.rotation.x = -maxf(0.0, -leg_sin) * knee_flex
			if right_knee: right_knee.rotation.x = -maxf(0.0, leg_sin) * knee_flex

			# Ankle flexion
			if left_foot: left_foot.rotation.x = maxf(0.0, -leg_sin) * 0.15
			if right_foot: right_foot.rotation.x = maxf(0.0, leg_sin) * 0.15

		else:
			# Idle standing with whole-body aim pitch responsiveness
			pelvis_node.position.y = lerpf(pelvis_node.position.y, base_pelvis_y, delta * 8.0)
			pelvis_node.rotation.x = lerpf(pelvis_node.rotation.x, pelvis_pitch, delta * 8.0)
			pelvis_node.rotation.z = lerpf(pelvis_node.rotation.z, 0.0, delta * 8.0)

			var breath := sin(anim_timer * 1.6) * 0.012
			if chest_node:
				chest_node.rotation.x = lerpf(chest_node.rotation.x, chest_pitch, delta * 8.0)
				chest_node.rotation.y = lerpf(chest_node.rotation.y, 0.0, delta * 8.0)
				chest_node.scale = Vector3(1.0 + breath, 1.0 + breath * 0.5, 1.0 + breath)

			if left_hip: left_hip.rotation.x = lerpf(left_hip.rotation.x, -pelvis_pitch, delta * 8.0)
			if right_hip: right_hip.rotation.x = lerpf(right_hip.rotation.x, -pelvis_pitch, delta * 8.0)
			if left_knee: left_knee.rotation.x = lerpf(left_knee.rotation.x, 0.0, delta * 8.0)
			if right_knee: right_knee.rotation.x = lerpf(right_knee.rotation.x, 0.0, delta * 8.0)
			if left_foot: left_foot.rotation.x = lerpf(left_foot.rotation.x, 0.0, delta * 8.0)
			if right_foot: right_foot.rotation.x = lerpf(right_foot.rotation.x, 0.0, delta * 8.0)

	# === ARM ANIMATIONS & ITEM HOLDING ===
	if has_item:
		# RIGHT ARM: Holds the active light source
		if is_lantern:
			# Natural exploratory lantern holding pose with relaxed elbow (54°) and dynamic pendulum sway
			var sway_period: float = walk_cycle if is_moving else (anim_timer * 1.5)
			var sway_amp: float = 0.05 if is_sprinting else (0.03 if is_moving else 0.012)
			var arm_bob: float = sin(sway_period) * sway_amp
			var lantern_pendulum: float = cos(sway_period) * (0.14 if is_sprinting else (0.07 if is_moving else 0.022))
			var lateral_sway: float = sin(sway_period * 0.5) * (0.05 if is_sprinting else (0.025 if is_moving else 0.012))

			if right_shoulder:
				right_shoulder.rotation.x = lerpf(right_shoulder.rotation.x, deg_to_rad(14.0) + pitch_clamped * 0.14 + arm_bob, delta * 10.0)
				right_shoulder.rotation.y = lerpf(right_shoulder.rotation.y, deg_to_rad(-8.0), delta * 8.0)
				right_shoulder.rotation.z = lerpf(right_shoulder.rotation.z, deg_to_rad(-3.0), delta * 8.0)
			if right_elbow:
				right_elbow.rotation.x = lerpf(right_elbow.rotation.x, deg_to_rad(54.0) + pitch_clamped * 0.10, delta * 10.0)
				right_elbow.rotation.y = lerpf(right_elbow.rotation.y, deg_to_rad(-8.0), delta * 8.0)
			if right_hand:
				right_hand.rotation.x = lerpf(right_hand.rotation.x, deg_to_rad(-8.0), delta * 10.0)
				right_hand.rotation.y = lerpf(right_hand.rotation.y, deg_to_rad(-6.0), delta * 8.0)

			# Dynamic Lantern Pendulum Gravity Swing:
			# Lantern always hangs straight down under gravity (-Y) from the hand grip,
			# naturally compensating for full-body kinematic pitch (pelvis + chest + arm) plus swinging with stride inertia!
			if held_item_model and is_instance_valid(held_item_model):
				held_item_model.position = Vector3(0.0, -0.055, -0.015)
				var total_body_pitch: float = (pelvis_node.rotation.x if pelvis_node else 0.0) \
					+ (chest_node.rotation.x if chest_node else 0.0) \
					+ (right_shoulder.rotation.x if right_shoulder else 0.0) \
					+ (right_elbow.rotation.x if right_elbow else 0.0) \
					+ (right_hand.rotation.x if right_hand else 0.0)
				var target_rot_x: float = -total_body_pitch + lantern_pendulum
				var target_rot_z: float = lateral_sway
				held_item_model.rotation.x = lerpf(held_item_model.rotation.x, target_rot_x, delta * 12.0)
				held_item_model.rotation.z = lerpf(held_item_model.rotation.z, target_rot_z, delta * 10.0)
				held_item_model.rotation.y = lerpf(held_item_model.rotation.y, 0.0, delta * 8.0)
		else:
			# Flashlight, Hand-Crank Dynamo, or UV Blacklight aimed forward (tracks head pitch seamlessly with torso)
			var hold_bob := sin(walk_cycle if is_moving else (anim_timer * 1.6)) * (0.025 if is_moving else 0.01)
			var crank_blend_amt: float = 1.0 if is_cranking else clampf(crank_reach_blend, 0.0, 1.0)
			if (is_cranking or crank_blend_amt > 0.01) and is_crank_item:
				# Bring right arm towards chest center so the right-side crank is accessible to the left hand
				var tgt_rs_x: float = deg_to_rad(30.0) + pitch_clamped * 0.25
				var tgt_rs_y: float = deg_to_rad(14.0)
				var tgt_rs_z: float = deg_to_rad(-2.0)
				var tgt_re_x: float = deg_to_rad(80.0)
				var tgt_re_y: float = deg_to_rad(12.0)
				var tgt_rh_x: float = deg_to_rad(2.0)
				var tgt_rh_y: float = deg_to_rad(10.0)

				var base_rs_x: float = deg_to_rad(36.0) + pitch_clamped * 0.44 + hold_bob
				var base_re_x: float = deg_to_rad(68.0) + pitch_clamped * 0.24

				if right_shoulder:
					right_shoulder.rotation.x = lerpf(right_shoulder.rotation.x, lerpf(base_rs_x, tgt_rs_x, crank_blend_amt), delta * 12.0)
					right_shoulder.rotation.y = lerpf(right_shoulder.rotation.y, lerpf(0.0, tgt_rs_y, crank_blend_amt), delta * 12.0)
					right_shoulder.rotation.z = lerpf(right_shoulder.rotation.z, lerpf(0.0, tgt_rs_z, crank_blend_amt), delta * 12.0)
				if right_elbow:
					right_elbow.rotation.x = lerpf(right_elbow.rotation.x, lerpf(base_re_x, tgt_re_x, crank_blend_amt), delta * 12.0)
					right_elbow.rotation.y = lerpf(right_elbow.rotation.y, lerpf(0.0, tgt_re_y, crank_blend_amt), delta * 12.0)
				if right_hand:
					right_hand.rotation.x = lerpf(right_hand.rotation.x, lerpf(0.0, tgt_rh_x, crank_blend_amt), delta * 12.0)
					right_hand.rotation.y = lerpf(right_hand.rotation.y, lerpf(0.0, tgt_rh_y, crank_blend_amt), delta * 12.0)
			else:
				if right_shoulder:
					right_shoulder.rotation.x = lerpf(right_shoulder.rotation.x, deg_to_rad(36.0) + pitch_clamped * 0.44 + hold_bob, delta * 10.0)
					right_shoulder.rotation.y = lerpf(right_shoulder.rotation.y, 0.0, delta * 8.0)
					right_shoulder.rotation.z = lerpf(right_shoulder.rotation.z, 0.0, delta * 8.0)
				if right_elbow:
					right_elbow.rotation.x = lerpf(right_elbow.rotation.x, deg_to_rad(68.0) + pitch_clamped * 0.24, delta * 10.0)
					right_elbow.rotation.y = lerpf(right_elbow.rotation.y, 0.0, delta * 8.0)
				if right_hand:
					right_hand.rotation.x = lerpf(right_hand.rotation.x, 0.0, delta * 10.0)
					right_hand.rotation.y = lerpf(right_hand.rotation.y, 0.0, delta * 8.0)

		# LEFT ARM:
		var left_crank_blend: float = 1.0 if is_cranking else clampf(crank_reach_blend, 0.0, 1.0)
		if (is_cranking or left_crank_blend > 0.01) and is_crank_item:
			# Left arm reaches across chest to right side where the crank handle physically sits on the flashlight!
			var crank_phase := fmod(anim_timer * 24.0, TAU)
			var rot_wobble_x := (sin(crank_phase) * 0.18) if is_cranking else 0.0
			var rot_wobble_y := (cos(crank_phase) * 0.18) if is_cranking else 0.0

			var arm_swing_base := sin(walk_cycle) * (0.48 if is_sprinting else 0.32) if (is_moving and speed > 0.1) else (sin(anim_timer * 1.2) * 0.04)
			var base_ls_x: float = arm_swing_base
			var base_ls_y: float = 0.0
			var base_ls_z: float = deg_to_rad(-7.0) if (is_moving and speed > 0.1) else deg_to_rad(-8.0)
			var base_le_x: float = maxf(0.0, arm_swing_base) * 0.35 if (is_moving and speed > 0.1) else deg_to_rad(12.0)
			var base_le_y: float = 0.0
			var base_lh_x: float = 0.0
			var base_lh_y: float = 0.0
			var base_lh_z: float = 0.0

			var tgt_ls_x := deg_to_rad(30.0)
			var tgt_ls_y := deg_to_rad(-50.0)
			var tgt_ls_z := deg_to_rad(-16.0)
			var tgt_le_x := deg_to_rad(88.0)
			var tgt_le_y := deg_to_rad(14.0)
			var tgt_lh_x := deg_to_rad(-10.0) + rot_wobble_x
			var tgt_lh_y := deg_to_rad(16.0) + rot_wobble_y
			var tgt_lh_z := deg_to_rad(10.0)

			if left_shoulder:
				left_shoulder.rotation.x = lerpf(left_shoulder.rotation.x, lerpf(base_ls_x, tgt_ls_x, left_crank_blend), delta * 14.0)
				left_shoulder.rotation.y = lerpf(left_shoulder.rotation.y, lerpf(base_ls_y, tgt_ls_y, left_crank_blend), delta * 14.0)
				left_shoulder.rotation.z = lerpf(left_shoulder.rotation.z, lerpf(base_ls_z, tgt_ls_z, left_crank_blend), delta * 14.0)
			if left_elbow:
				left_elbow.rotation.x = lerpf(left_elbow.rotation.x, lerpf(base_le_x, tgt_le_x, left_crank_blend), delta * 14.0)
				left_elbow.rotation.y = lerpf(left_elbow.rotation.y, lerpf(base_le_y, tgt_le_y, left_crank_blend), delta * 14.0)
			if left_hand:
				left_hand.rotation.x = lerpf(left_hand.rotation.x, lerpf(base_lh_x, tgt_lh_x, left_crank_blend), delta * 14.0)
				left_hand.rotation.y = lerpf(left_hand.rotation.y, lerpf(base_lh_y, tgt_lh_y, left_crank_blend), delta * 14.0)
				left_hand.rotation.z = lerpf(left_hand.rotation.z, lerpf(base_lh_z, tgt_lh_z, left_crank_blend), delta * 14.0)
		else:
			# Free left arm: swings naturally during walking/running
			if is_moving and speed > 0.1:
				var arm_swing := sin(walk_cycle) * (0.48 if is_sprinting else 0.32)
				if left_shoulder:
					left_shoulder.rotation.x = lerpf(left_shoulder.rotation.x, arm_swing, delta * 10.0)
					left_shoulder.rotation.y = lerpf(left_shoulder.rotation.y, 0.0, delta * 8.0)
					left_shoulder.rotation.z = lerpf(left_shoulder.rotation.z, deg_to_rad(-7.0), delta * 8.0)
				if left_elbow:
					left_elbow.rotation.x = lerpf(left_elbow.rotation.x, maxf(0.0, arm_swing) * 0.35, delta * 8.0)
				if left_hand:
					left_hand.rotation.x = lerpf(left_hand.rotation.x, 0.0, delta * 8.0)
					left_hand.rotation.y = lerpf(left_hand.rotation.y, 0.0, delta * 8.0)
			else:
				if left_shoulder:
					left_shoulder.rotation.x = lerpf(left_shoulder.rotation.x, sin(anim_timer * 1.2) * 0.04, delta * 8.0)
					left_shoulder.rotation.y = lerpf(left_shoulder.rotation.y, 0.0, delta * 8.0)
					left_shoulder.rotation.z = lerpf(left_shoulder.rotation.z, deg_to_rad(-7.0), delta * 8.0)
				if left_elbow:
					left_elbow.rotation.x = lerpf(left_elbow.rotation.x, 0.0, delta * 8.0)
				if left_hand:
					left_hand.rotation.x = lerpf(left_hand.rotation.x, 0.0, delta * 8.0)
					left_hand.rotation.y = lerpf(left_hand.rotation.y, 0.0, delta * 8.0)

	else:
		# NO ITEM HELD: Both arms swing symmetrically
		if is_moving and speed > 0.1:
			var swing_amp := 0.50 if is_sprinting else 0.32
			var arm_sin := sin(walk_cycle) * swing_amp
			if left_shoulder:
				left_shoulder.rotation.x = lerpf(left_shoulder.rotation.x, arm_sin, delta * 10.0)
				left_shoulder.rotation.y = lerpf(left_shoulder.rotation.y, 0.0, delta * 8.0)
				left_shoulder.rotation.z = lerpf(left_shoulder.rotation.z, deg_to_rad(-7.0), delta * 8.0)
			if right_shoulder:
				right_shoulder.rotation.x = lerpf(right_shoulder.rotation.x, -arm_sin, delta * 10.0)
				right_shoulder.rotation.y = lerpf(right_shoulder.rotation.y, 0.0, delta * 8.0)
				right_shoulder.rotation.z = lerpf(right_shoulder.rotation.z, deg_to_rad(7.0), delta * 8.0)
			if left_elbow:
				left_elbow.rotation.x = lerpf(left_elbow.rotation.x, maxf(0.0, arm_sin) * 0.35, delta * 8.0)
			if right_elbow:
				right_elbow.rotation.x = lerpf(right_elbow.rotation.x, maxf(0.0, -arm_sin) * 0.35, delta * 8.0)
			if left_hand:
				left_hand.rotation.x = lerpf(left_hand.rotation.x, 0.0, delta * 8.0)
				left_hand.rotation.y = lerpf(left_hand.rotation.y, 0.0, delta * 8.0)
			if right_hand:
				right_hand.rotation.x = lerpf(right_hand.rotation.x, 0.0, delta * 8.0)
				right_hand.rotation.y = lerpf(right_hand.rotation.y, 0.0, delta * 8.0)
		else:
			# Idle arms
			var idle_sway := sin(anim_timer * 1.2) * 0.04
			if left_shoulder:
				left_shoulder.rotation.x = lerpf(left_shoulder.rotation.x, idle_sway, delta * 8.0)
				left_shoulder.rotation.y = lerpf(left_shoulder.rotation.y, 0.0, delta * 8.0)
				left_shoulder.rotation.z = lerpf(left_shoulder.rotation.z, deg_to_rad(-7.0), delta * 8.0)
			if right_shoulder:
				right_shoulder.rotation.x = lerpf(right_shoulder.rotation.x, -idle_sway, delta * 8.0)
				right_shoulder.rotation.y = lerpf(right_shoulder.rotation.y, 0.0, delta * 8.0)
				right_shoulder.rotation.z = lerpf(right_shoulder.rotation.z, deg_to_rad(7.0), delta * 8.0)
			if left_elbow:
				left_elbow.rotation.x = lerpf(left_elbow.rotation.x, 0.0, delta * 8.0)
			if right_elbow:
				right_elbow.rotation.x = lerpf(right_elbow.rotation.x, 0.0, delta * 8.0)
			if left_hand:
				left_hand.rotation.x = lerpf(left_hand.rotation.x, 0.0, delta * 8.0)
			if right_hand:
				right_hand.rotation.x = lerpf(right_hand.rotation.x, 0.0, delta * 8.0)


func set_first_person(first_person: bool) -> void:
	# Completely remove player's own 3rd-person body in 1st person view (zero camera clipping, zero visual clutter)
	visible = not first_person


func _get_palette() -> Dictionary:
	return get_character_palette(character_name)


static func get_character_palette(p_name: String) -> Dictionary:
	var norm := p_name.to_lower()
	if "dad" in norm or "ayah" in norm:
		return {
			"skin":  Color(0.741, 0.584, 0.533), # Exact dad_face.png cheek-matched skin
			"shirt": Color(0.47, 0.41, 0.28),    # Olive/tan vintage polo
			"pants": Color(0.36, 0.32, 0.24),    # Khaki slacks
			"shoes": Color(0.20, 0.13, 0.08),    # Dark brown loafers
			"hair":  Color(0.20, 0.18, 0.17),    # Dark hair with grey temples
		}
	elif "syazril" in norm:
		return {
			"skin":  Color(0.678, 0.490, 0.369), # Exact syazril_face.png cheek-matched skin
			"shirt": Color(0.085, 0.135, 0.270), # Dark navy blue Adidas tee
			"pants": Color(0.11, 0.15, 0.24),    # Dark wash denim jeans
			"shoes": Color(0.91, 0.91, 0.89),    # White sneakers
			"hair":  Color(0.11, 0.11, 0.13),    # Textured black hair
		}
	elif "syahirul" in norm:
		return {
			"skin":  Color(0.804, 0.596, 0.549), # Exact syahirul_face.png edge skin
			"shirt": Color(0.74, 0.10, 0.19),    # Vivid crimson red crewneck tee
			"pants": Color(0.66, 0.58, 0.46),    # Khaki/beige chinos
			"shoes": Color(0.15, 0.13, 0.12),    # Dark casual shoes
			"hair":  Color(0.12, 0.11, 0.12),    # Dark hair
		}
	elif "amelya" in norm:
		return {
			"skin":   Color(0.698, 0.557, 0.502), # Exact amelya_face.png cheek-matched skin
			"shirt":  Color(0.24, 0.44, 0.34),    # Rich emerald/sage green baju kurung moden
			"tudung": Color(0.44, 0.62, 0.52),    # Soft sage green tudung
			"pants":  Color(0.20, 0.38, 0.29),    # Deep forest emerald silk skirt
			"shoes":  Color(0.18, 0.16, 0.15),    # Modest dark espresso shoes
			"hair":   Color(0.44, 0.62, 0.52),
		}
	elif "aleysa" in norm:
		return {
			"skin":   Color(0.843, 0.643, 0.510), # Exact aleysa_face.png cheek-matched skin
			"shirt":  Color(0.78, 0.46, 0.56),    # Pastel blossom rose baju kurung
			"tudung": Color(0.84, 0.56, 0.65),    # Soft pastel rose blush tudung
			"pants":  Color(0.72, 0.40, 0.50),    # Matching blossom rose skirt
			"shoes":  Color(0.92, 0.90, 0.88),    # Light off-white/cream flats
			"hair":   Color(0.84, 0.56, 0.65),
		}
	return {
		"skin":  Color(0.80, 0.62, 0.48),
		"shirt": Color(0.30, 0.34, 0.40),
		"pants": Color(0.18, 0.20, 0.24),
		"shoes": Color(0.80, 0.80, 0.80),
		"hair":  Color(0.12, 0.10, 0.09),
	}


func _make_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.88
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat


func _make_textured_mat(tex: Texture2D, tint: Color = Color.WHITE, flip_h: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.roughness = 0.88
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if flip_h:
		mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
		mat.uv1_offset = Vector3(1.0, 0.0, 0.0)
	return mat


func _create_box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func _create_cylinder(r_top: float, r_bot: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = height
	cyl.radial_segments = 8
	cyl.material = mat
	mi.mesh = cyl
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi
