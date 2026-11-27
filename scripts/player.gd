extends CharacterBody3D

# --- Player Nodes ---
@onready var nek: Node3D = $nek
@onready var head: Node3D = $nek/head
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var camera_3d: Camera3D = $nek/head/eyes/Camera3D
@onready var eyes: Node3D = $nek/head/eyes
@onready var animation_player: AnimationPlayer = $nek/head/eyes/AnimationPlayer
@onready var visuals: Node3D = $visuals
@onready var body_mesh: MeshInstance3D = $visuals/body_mesh
@onready var head_mesh: MeshInstance3D = $visuals/head_mesh
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var flashlight: SpotLight3D = $nek/head/eyes/Camera3D/Flashlight
@onready var torch_body: MeshInstance3D = $nek/head/eyes/Camera3D/TorchBody
@onready var lantern_light: OmniLight3D = $nek/head/eyes/Camera3D/LanternLight
@onready var lantern_body: Node3D = $nek/head/eyes/Camera3D/LanternBody
@onready var beam_ray_cast: RayCast3D = $nek/head/eyes/Camera3D/Flashlight/BeamRayCast
@onready var lens_glow: MeshInstance3D = $nek/head/eyes/Camera3D/Flashlight/LensGlow
@onready var beam_mesh: MeshInstance3D = $nek/head/eyes/Camera3D/Flashlight/BeamMesh
@onready var name_tag: Label3D = $NameTag
const RETRO_SKELETON_SCRIPT := preload("res://scripts/retro_skeleton.gd")
const ITEM_MODELS_SCRIPT := preload("res://scripts/item_models.gd")
var retro_skeleton: Node3D = null

# --- First-Person Item Viewmodel Rig ---
var fp_rig: Node3D = null
var fp_item_container: Node3D = null
var fp_item_model: Node3D = null
var fp_right_arm: Node3D = null
var fp_left_arm: Node3D = null
var fp_crank_arm: Node3D = null
var fp_sway_timer: float = 0.0
var fp_bob_timer: float = 0.0

# --- Proximity Voice Chat & Audio Nodes ---
const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx_click_switch.wav")
const SFX_CROUCH: AudioStream = preload("res://assets/audio/sfx_crouch.wav")
const SFX_CRANK: AudioStream = preload("res://assets/audio/sfx_crank_tick.wav")
const SFX_STEP_1: AudioStream = preload("res://assets/audio/sfx_footstep_wood_1.wav")
const SFX_STEP_2: AudioStream = preload("res://assets/audio/sfx_footstep_wood_2.wav")

@onready var voice_player_3d: AudioStreamPlayer3D = $nek/head/VoicePlayer3D
@onready var voice_capture_player: AudioStreamPlayer = $VoiceCapturePlayer
@onready var voice_indicator: Label3D = $VoiceIndicator
@onready var voice_hud: CanvasLayer = $VoiceHUD
@onready var voice_mic_icon: Label = get_node_or_null("VoiceHUD/VoiceRoot/MarginContainer/VoicePanel/VoiceRow/MicIcon") if has_node("VoiceHUD/VoiceRoot/MarginContainer/VoicePanel/VoiceRow/MicIcon") else (get_node_or_null("VoiceHUD/MarginContainer/VoicePanel/VoiceRow/MicIcon") if has_node("VoiceHUD/MarginContainer/VoicePanel/VoiceRow/MicIcon") else get_node_or_null("VoiceHUD/MarginContainer/VoicePanel/VBoxContainer/VoiceRow/MicIcon"))
@onready var voice_label: Label = get_node_or_null("VoiceHUD/VoiceRoot/MarginContainer/VoicePanel/VoiceRow/VoiceLabel") if has_node("VoiceHUD/VoiceRoot/MarginContainer/VoicePanel/VoiceRow/VoiceLabel") else (get_node_or_null("VoiceHUD/MarginContainer/VoicePanel/VoiceRow/VoiceLabel") if has_node("VoiceHUD/MarginContainer/VoicePanel/VoiceRow/VoiceLabel") else get_node_or_null("VoiceHUD/MarginContainer/VoicePanel/VBoxContainer/VoiceRow/VoiceLabel"))
@onready var noise_meter_panel: PanelContainer = get_node_or_null("VoiceHUD/VoiceRoot/NoiseMeter") if has_node("VoiceHUD/VoiceRoot/NoiseMeter") else get_node_or_null("VoiceHUD/NoiseMeter")
@onready var noise_bar: ProgressBar = get_node_or_null("VoiceHUD/VoiceRoot/NoiseMeter/VBoxContainer/NoiseBar") if has_node("VoiceHUD/VoiceRoot/NoiseMeter/VBoxContainer/NoiseBar") else (get_node_or_null("VoiceHUD/NoiseMeter/VBoxContainer/NoiseBar") if has_node("VoiceHUD/NoiseMeter/VBoxContainer/NoiseBar") else get_node_or_null("VoiceHUD/MarginContainer/VoicePanel/VBoxContainer/NoiseRow/NoiseBar"))
@onready var noise_status_label: Label = get_node_or_null("VoiceHUD/VoiceRoot/NoiseMeter/VBoxContainer/NoiseStatusLabel") if has_node("VoiceHUD/VoiceRoot/NoiseMeter/VBoxContainer/NoiseStatusLabel") else (get_node_or_null("VoiceHUD/NoiseMeter/VBoxContainer/NoiseStatusLabel") if has_node("VoiceHUD/NoiseMeter/VBoxContainer/NoiseStatusLabel") else get_node_or_null("VoiceHUD/MarginContainer/VoicePanel/VBoxContainer/NoiseRow/NoiseStatusLabel"))
@onready var noise_icon: Label = get_node_or_null("VoiceHUD/VoiceRoot/NoiseMeter/VBoxContainer/NoiseIcon") if has_node("VoiceHUD/VoiceRoot/NoiseMeter/VBoxContainer/NoiseIcon") else get_node_or_null("VoiceHUD/NoiseMeter/VBoxContainer/NoiseIcon")
@onready var crosshair_layer: CanvasLayer = $CrosshairLayer
@onready var crosshair_ring: TextureRect = $CrosshairLayer/CenterContainer/CrosshairRing if has_node("CrosshairLayer/CenterContainer/CrosshairRing") else null
@onready var mobile_controls: CanvasLayer = $MobileControls

var click_player_3d: AudioStreamPlayer3D = null
var crouch_player_3d: AudioStreamPlayer3D = null
var crank_player_3d: AudioStreamPlayer3D = null
var footstep_player_3d: AudioStreamPlayer3D = null
var step_distance: float = 0.0
var step_counter: int = 0
var noise_impulse: float = 0.0
var base_nametag_y: float = 1.84
var _prev_flashlight_on: bool = false
var _was_crouching: bool = false

# --- Flashlight HUD Nodes ---
@onready var flashlight_hud: CanvasLayer = $FlashlightHUD
@onready var flashlight_hud_margin: MarginContainer = $FlashlightHUD/MarginContainer
@onready var flashlight_icon: Label = $FlashlightHUD/MarginContainer/FlashlightPanel/VBoxContainer/HeaderRow/FlashlightIcon
@onready var flashlight_mode_label: Label = $FlashlightHUD/MarginContainer/FlashlightPanel/VBoxContainer/HeaderRow/FlashlightModeLabel
@onready var flashlight_status_label: Label = $FlashlightHUD/MarginContainer/FlashlightPanel/VBoxContainer/HeaderRow/FlashlightStatusLabel
@onready var flashlight_battery_bar: ProgressBar = $FlashlightHUD/MarginContainer/FlashlightPanel/VBoxContainer/BatteryRow/FlashlightBatteryBar
@onready var flashlight_battery_label: Label = $FlashlightHUD/MarginContainer/FlashlightPanel/VBoxContainer/BatteryRow/FlashlightBatteryLabel
@onready var flashlight_prompt_label: Label = $FlashlightHUD/MarginContainer/FlashlightPanel/VBoxContainer/FlashlightPromptLabel

enum VoiceMode { PUSH_TO_TALK, OPEN_MIC, ALWAYS_ON }
var voice_mode: VoiceMode = VoiceMode.OPEN_MIC
var is_mic_muted: bool = false
var voice_capture_effect: AudioEffectCapture = null
var voice_generator_playback: AudioStreamGeneratorPlayback = null

# --- Mobile Touch Input State ---
var touch_move_vector: Vector2 = Vector2.ZERO
var touch_crouch_active: bool = false
var touch_crank_held: bool = false
var is_in_cutscene: bool = false
var external_interact_available: bool = false
var external_interact_text: String = "USE"
var external_drop_available: bool = false
var interact_ray_cast: RayCast3D = null

var mic_threshold: float = 0.025
var mic_sensitivity: float = 1.0
const VAD_HOLD_TIME: float = 0.35
var vad_timer: float = 0.0
var voice_timer: float = 0.0
const VOICE_CHUNK_INTERVAL: float = 0.04
var remote_talking_timer: float = 0.0

# --- Identity & Host Sync ---
var crosshair_enabled: bool = true
@export var player_name: String = "Player":
	set(val):
		player_name = val
		if name_tag:
			name_tag.text = val

@export var character_name: String = "Syazril":
	set(val):
		character_name = val
		if is_inside_tree() and (retro_skeleton == null or not is_instance_valid(retro_skeleton) or retro_skeleton.character_name != val):
			setup_character_model(val)

@export var flashlight_is_on: bool = false:
	set(val):
		flashlight_is_on = val
		_update_light_visibility()

@export var flashlight_energy: float = 2.0:
	set(val):
		flashlight_energy = val
		_apply_flashlight_energy(val)

# --- Flashlight & Crank Battery System ---
@export var flashlight_mode: String = "normal":
	set(val):
		flashlight_mode = val
		_apply_role_profile()
		_update_light_visibility()
		_update_fp_item_model()
		if is_inside_tree() and is_multiplayer_authority():
			_update_flashlight_hud(0.0)

@export var flashlight_enabled_by_host: bool = true
var flashlight_battery: float = 100.0
const battery_drain_speed: float = 0.5        # ~3.3 minutes continuous use (Standard battery)
const crank_battery_drain_speed: float = 0.75  # ~2.2 minutes continuous use (Reduced longevity by 1/3)

# --- Hand-Crank Holding State (3-Phase Progression) ---
@export var is_cranking: bool = false
@export var crank_reach_blend: float = 0.0
var prev_remote_position: Vector3 = Vector3.ZERO
var crank_hold_timer: float = 0.0
var crank_tick_timer: float = 0.0
const CRANK_PHASE_1_DURATION: float = 0.35  # Phase 1: Movement slows down immediately
const CRANK_PHASE_2_DURATION: float = 0.55  # Phase 2: Second hand slowly reaches for crank
const CRANK_START_DELAY: float = 0.90       # Phase 3: Actual cranking & charging begins at 0.90s
const CRANK_TICK_INTERVAL: float = 0.34     # Nerfed: slower tick frequency
const CRANK_CHARGE_PER_TICK: float = 1.8    # Nerfed: down from 6.0! (takes ~19 ticks to full charge)
const CRANK_SLOWDOWN_FACTOR: float = 0.35   # Noticeable movement deceleration while cranking

# --- Movement Speeds (Horror Pacing) ---
const walking_speed: float = 2.45
const crouching_speed: float = 1.2
var current_speed: float = walking_speed

# --- Stealth & Noise (For Monster AI Detection) ---
var noise_level: float = 0.0  # 0.0 = silent/crouch, 1.0 = normal walk

# --- States ---
var walking: bool = false
var sprinting: bool = false  # Kept as false for any remote player/packet compatibility
var crouching: bool = false
var free_looking: bool = false

# --- Head Bobbing (Grounded Cadence) ---
const head_bobbing_walking_speed: float = 10.0
const head_bobbing_crouching_speed: float = 6.0

const head_bobbing_walking_intensity: float = 0.05
const head_bobbing_crouching_intensity: float = 0.02

var head_bobbing_vector: Vector2 = Vector2.ZERO
var head_bobbing_index: float = 0.0
var head_bobbing_current_intensity: float = 0.0

# --- Camera & Movement Vars ---
var crouching_depth: float = -0.5
var lerp_speed: float = 10.0
var free_look_tilt_amount: float = 5.0
var mouse_sens: float = 0.25
var direction: Vector3 = Vector3.ZERO


func _enter_tree() -> void:
	var id := name.to_int()
	if id != 0:
		set_multiplayer_authority(id)
	else:
		set_multiplayer_authority(1)


func _ready() -> void:
	if synchronizer:
		synchronizer.set_multiplayer_authority(get_multiplayer_authority())

	# Duplicate beam and glow materials so individual player flicker/crank doesn't leak
	if beam_mesh and beam_mesh.mesh and beam_mesh.mesh.material:
		beam_mesh.material_override = beam_mesh.mesh.material.duplicate()
	if lens_glow and lens_glow.mesh and lens_glow.mesh.material:
		lens_glow.material_override = lens_glow.mesh.material.duplicate()
	if beam_ray_cast:
		beam_ray_cast.add_exception(self)

	# Positional Audio Players for Flashlight Click, Crouch Rustle, Cranking Ratchet, and Footsteps
	click_player_3d = AudioStreamPlayer3D.new()
	click_player_3d.name = "ClickPlayer3D"
	click_player_3d.stream = SFX_CLICK
	click_player_3d.unit_size = 5.0
	click_player_3d.max_distance = 18.0
	click_player_3d.volume_db = +2.0
	add_child(click_player_3d)

	crouch_player_3d = AudioStreamPlayer3D.new()
	crouch_player_3d.name = "CrouchPlayer3D"
	crouch_player_3d.stream = SFX_CROUCH
	crouch_player_3d.unit_size = 4.5
	crouch_player_3d.max_distance = 16.0
	crouch_player_3d.volume_db = +4.0
	add_child(crouch_player_3d)

	crank_player_3d = AudioStreamPlayer3D.new()
	crank_player_3d.name = "CrankPlayer3D"
	crank_player_3d.stream = SFX_CRANK
	crank_player_3d.unit_size = 6.0
	crank_player_3d.max_distance = 22.0
	crank_player_3d.volume_db = +5.0
	add_child(crank_player_3d)

	footstep_player_3d = AudioStreamPlayer3D.new()
	footstep_player_3d.name = "FootstepPlayer3D"
	footstep_player_3d.unit_size = 5.0
	footstep_player_3d.max_distance = 20.0
	footstep_player_3d.volume_db = +3.0
	add_child(footstep_player_3d)

	var net := get_node_or_null("/root/NetworkManager")
	var crosshair_enabled: bool = true
	var v_mode_str: String = "ptt"
	if net:
		var settings: Dictionary = net.host_settings
		var my_id := get_multiplayer_authority()
		if net.players.has(my_id) and not str(net.players[my_id].get("role", "")).is_empty() and str(net.players[my_id].get("role", "")) != "random":
			flashlight_mode = str(net.players[my_id].get("role"))
		else:
			flashlight_mode = settings.get("flashlight_mode", "normal")
		flashlight_enabled_by_host = (flashlight_mode != "disabled") and settings.get("flashlight_enabled", true)
		_apply_role_profile()
		var show_tags: bool = settings.get("show_name_tags", true)
		if not is_multiplayer_authority():
			name_tag.visible = show_tags
		else:
			name_tag.visible = false

		if net.get("local_settings") != null:
			crosshair_enabled = bool(net.local_settings.get("crosshair_enabled", true))
			v_mode_str = str(net.local_settings.get("voice_mode", "open_mic"))
			mic_threshold = float(net.local_settings.get("mic_threshold", 0.025))
			mic_sensitivity = float(net.local_settings.get("mic_sensitivity", 1.0))

	if not flashlight_enabled_by_host:
		if torch_body:
			torch_body.visible = false
		if lantern_body:
			lantern_body.visible = false
		if flashlight:
			flashlight.visible = false
		if lantern_light:
			lantern_light.visible = false

	if is_multiplayer_authority():
		if not is_in_cutscene:
			camera_3d.current = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			camera_3d.current = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		name_tag.visible = false
		if body_mesh:
			body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if head_mesh:
			head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if voice_hud:
			voice_hud.visible = true
		if crosshair_layer:
			crosshair_layer.visible = crosshair_enabled
		if voice_indicator:
			voice_indicator.visible = false

		if v_mode_str == "always_on":
			voice_mode = VoiceMode.ALWAYS_ON
		elif v_mode_str == "open_mic":
			voice_mode = VoiceMode.OPEN_MIC
		else:
			voice_mode = VoiceMode.PUSH_TO_TALK

		_update_voice_hud_status(false, 0.0)
		_setup_voice_capture()

		if mobile_controls:
			mobile_controls.setup(self)
			mobile_controls.move_vector_changed.connect(func(v: Vector2) -> void: touch_move_vector = v)
			mobile_controls.look_dragged.connect(apply_touch_look)
			mobile_controls.crouch_toggled.connect(func(active: bool) -> void: touch_crouch_active = active)
			mobile_controls.flashlight_pressed.connect(_toggle_flashlight)
			mobile_controls.crank_held.connect(func(active: bool) -> void: touch_crank_held = active)
			mobile_controls.interact_pressed.connect(_trigger_interact)
			mobile_controls.drop_pressed.connect(_trigger_drop)
			if mobile_controls.has_signal("mic_mute_toggled"):
				mobile_controls.mic_mute_toggled.connect(toggle_mic_mute)

		if camera_3d and not interact_ray_cast:
			interact_ray_cast = RayCast3D.new()
			interact_ray_cast.name = "InteractRayCast"
			interact_ray_cast.target_position = Vector3(0.0, 0.0, -2.8)
			interact_ray_cast.collision_mask = 1 | 2 | 4 | 8
			interact_ray_cast.enabled = true
			camera_3d.add_child(interact_ray_cast)

		if flashlight_hud:
			flashlight_hud.visible = flashlight_enabled_by_host and (flashlight_mode != "disabled")
		if mobile_controls and mobile_controls.visible and flashlight_hud_margin:
			# On mobile, anchor Flashlight HUD at the top-right below the mic button
			flashlight_hud_margin.anchor_top = 0.0
			flashlight_hud_margin.anchor_bottom = 0.0
			flashlight_hud_margin.offset_top = 64.0
			flashlight_hud_margin.offset_bottom = 140.0
	else:
		if flashlight_hud:
			flashlight_hud.visible = false
		camera_3d.current = false
		if body_mesh:
			body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if head_mesh:
			head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if voice_hud:
			voice_hud.visible = false
		if crosshair_layer:
			crosshair_layer.visible = false
		if mobile_controls:
			mobile_controls.queue_free()
		_setup_voice_playback()

	_update_light_visibility()
	_apply_flashlight_energy(flashlight_energy)

	# Initialize Fears to Fathom retro character skeleton
	var char_to_use := character_name
	if has_meta("character_name"):
		char_to_use = str(get_meta("character_name"))
	elif net and net.players.has(get_multiplayer_authority()):
		char_to_use = str(net.players[get_multiplayer_authority()].get("character", character_name))
	if char_to_use.is_empty() or char_to_use == "random":
		char_to_use = "Syazril"
	prev_remote_position = global_position
	character_name = char_to_use
	setup_character_model(char_to_use)


func setup_character_model(char_name: String) -> void:
	if char_name.is_empty() or char_name == "random":
		char_name = "Syazril"
	if body_mesh:
		body_mesh.visible = false
	if head_mesh:
		head_mesh.visible = false

	if retro_skeleton and is_instance_valid(retro_skeleton):
		retro_skeleton.queue_free()

	retro_skeleton = RETRO_SKELETON_SCRIPT.create_character(char_name)
	if visuals:
		visuals.add_child(retro_skeleton)

	# Male characters are taller than female characters (Fears to Fathom art style)
	# Syazril & Syahirul are male, Amelya & Aleysa are female
	var is_male_char: bool = not (char_name.to_lower() in ["amelya", "aleysa"])
	if nek:
		nek.position.y = 1.72 if is_male_char else 1.54
	if standing_collision_shape:
		standing_collision_shape.position.y = 1.08 if is_male_char else 0.96
	base_nametag_y = 1.84 if is_male_char else 1.72
	if name_tag:
		name_tag.position.y = base_nametag_y

	if is_multiplayer_authority() and not is_in_cutscene:
		retro_skeleton.set_first_person(true)
	else:
		retro_skeleton.set_first_person(false)

	# Ensure player body is perfectly upright with 0 pitch or roll lean
	rotation.x = 0.0
	rotation.z = 0.0

	_setup_fp_rig()


func _setup_fp_rig() -> void:
	if not is_multiplayer_authority() or is_in_cutscene:
		if fp_rig and is_instance_valid(fp_rig):
			fp_rig.visible = false
		return

	if fp_rig == null or not is_instance_valid(fp_rig):
		fp_rig = Node3D.new()
		fp_rig.name = "FPRig"
		camera_3d.add_child(fp_rig)

		fp_item_container = Node3D.new()
		fp_item_container.name = "FPItemContainer"
		fp_rig.add_child(fp_item_container)

	fp_rig.visible = true
	_update_fp_arm_models()
	_update_fp_item_model()


func _update_fp_arm_models() -> void:
	if not fp_rig or not is_instance_valid(fp_rig):
		return

	if fp_right_arm and is_instance_valid(fp_right_arm):
		fp_right_arm.queue_free()
		fp_right_arm = null
	if fp_left_arm and is_instance_valid(fp_left_arm):
		fp_left_arm.queue_free()
		fp_left_arm = null

	var palette: Dictionary = RETRO_SKELETON_SCRIPT.get_character_palette(character_name)
	var skin_col: Color = palette.get("skin", Color(0.80, 0.62, 0.48))
	var sleeve_col: Color = palette.get("shirt", Color(0.25, 0.25, 0.30))

	fp_right_arm = ITEM_MODELS_SCRIPT.build_fp_arm(skin_col, sleeve_col, false)
	fp_rig.add_child(fp_right_arm)

	fp_left_arm = ITEM_MODELS_SCRIPT.build_fp_arm(skin_col, sleeve_col, true)
	fp_left_arm.visible = false
	fp_rig.add_child(fp_left_arm)


func _update_fp_item_model() -> void:
	if not fp_rig or not is_instance_valid(fp_rig):
		return

	if fp_item_model and is_instance_valid(fp_item_model):
		fp_item_model.queue_free()
		fp_item_model = null
		fp_crank_arm = null

	if torch_body:
		torch_body.visible = false
	if lantern_body:
		lantern_body.visible = false

	if not flashlight_enabled_by_host or flashlight_mode == "disabled":
		if fp_right_arm:
			fp_right_arm.visible = false
		if fp_left_arm:
			fp_left_arm.visible = false
		return

	if fp_right_arm:
		fp_right_arm.visible = true

	fp_item_model = ITEM_MODELS_SCRIPT.create_item(flashlight_mode, true, flashlight_is_on and flashlight_enabled_by_host and (flashlight_energy > 0.05))
	if fp_item_model:
		fp_item_container.add_child(fp_item_model)
		fp_crank_arm = fp_item_model.get_meta("crank_arm") if fp_item_model.has_meta("crank_arm") else null
		ITEM_MODELS_SCRIPT.set_item_light_state(fp_item_model, flashlight_is_on and flashlight_enabled_by_host and (flashlight_energy > 0.05), flashlight_mode)

		# Position item container and arms in camera screen view
		if flashlight_mode == "lantern":
			fp_item_container.position = Vector3(0.24, -0.11, -0.38)
			fp_item_container.rotation_degrees = Vector3(4.0, -8.0, 0.0)
			if fp_right_arm:
				fp_right_arm.position = Vector3(0.24, -0.11, -0.38)
				fp_right_arm.rotation_degrees = Vector3(12.0, -12.0, 4.0)
		elif flashlight_mode == "crank":
			fp_item_container.position = Vector3(0.20, -0.20, -0.38)
			fp_item_container.rotation_degrees = Vector3(3.0, -5.0, 0.0)
			if fp_right_arm:
				fp_right_arm.position = Vector3(0.20, -0.20, -0.38)
				fp_right_arm.rotation_degrees = Vector3(8.0, -8.0, 2.0)
		else:
			# Normal flashlight, UV flashlight, Battery
			fp_item_container.position = Vector3(0.20, -0.20, -0.38)
			fp_item_container.rotation_degrees = Vector3(3.0, -5.0, 0.0)
			if fp_right_arm:
				fp_right_arm.position = Vector3(0.20, -0.20, -0.38)
				fp_right_arm.rotation_degrees = Vector3(8.0, -8.0, 2.0)

		# Align dynamic light sources to match lens or lantern mantle
		var offset: Vector3 = fp_item_model.get_meta("light_offset") if fp_item_model.has_meta("light_offset") else Vector3(0, 0, -0.1)
		var world_light_pos: Vector3 = fp_item_container.position + fp_item_container.transform.basis * offset
		if flashlight:
			flashlight.position = world_light_pos
		if lantern_light:
			lantern_light.position = world_light_pos


func _update_fp_rig(delta: float) -> void:
	if not is_multiplayer_authority() or is_in_cutscene or not fp_rig or not is_instance_valid(fp_rig):
		return

	fp_sway_timer += delta
	# Subtle natural breathing sway in first person
	var sway_x := cos(fp_sway_timer * 1.4) * 0.003
	var sway_y := sin(fp_sway_timer * 2.8) * 0.003

	# Movement bobbing in first person
	var bob_x: float = 0.0
	var bob_y: float = 0.0
	if is_on_floor() and walking and velocity.length() > 0.1:
		var bob_cadence := 9.0
		var bob_amp := 0.008
		fp_bob_timer += delta * bob_cadence
		bob_y = sin(fp_bob_timer) * bob_amp
		bob_x = cos(fp_bob_timer * 0.5) * (bob_amp * 0.6)
	else:
		fp_bob_timer = 0.0

	var crouch_off_y := -0.04 if crouching else 0.0

	fp_rig.position = fp_rig.position.lerp(
		Vector3(sway_x + bob_x, sway_y + bob_y + crouch_off_y, 0.0),
		delta * 12.0
	)

	# Cranking animation in first person (3-stage visual progression)
	if flashlight_mode == "crank" and (is_cranking or crank_reach_blend > 0.01):
		if fp_left_arm:
			fp_left_arm.visible = true
			var knob_node: Node3D = fp_crank_arm.get_node_or_null("Knob") as Node3D if (fp_crank_arm and is_instance_valid(fp_crank_arm)) else null
			var crank_target_pos: Vector3
			if knob_node and is_instance_valid(knob_node):
				# Lock hand directly to the 3D position of the crank knob on the right side of the flashlight!
				var target_pos: Vector3 = fp_rig.to_local(knob_node.global_position)
				crank_target_pos = target_pos + Vector3(0.012, 0.0, 0.038)
			else:
				var crank_rot: float = fp_crank_arm.rotation.x if (fp_crank_arm and is_instance_valid(fp_crank_arm)) else 0.0
				var knob_y: float = -0.20 + cos(crank_rot) * 0.045
				var knob_z: float = -0.36 + sin(crank_rot) * 0.045
				crank_target_pos = Vector3(0.252, knob_y, knob_z)

			# Resting / start pose off to the bottom-left of screen
			var rest_pos := Vector3(-0.06, -0.40, -0.36)
			var rest_rot := Vector3(12.0, 20.0, -8.0)
			var crank_rot_deg := Vector3(18.0, 38.0, -14.0)

			var blend_val := 1.0 if is_cranking else clampf(crank_reach_blend, 0.0, 1.0)
			fp_left_arm.position = rest_pos.lerp(crank_target_pos, blend_val)
			fp_left_arm.rotation_degrees = rest_rot.lerp(crank_rot_deg, blend_val)

		# Phase 3: Only rotate crank arm when actually cranking
		if is_cranking and fp_crank_arm and is_instance_valid(fp_crank_arm):
			fp_crank_arm.rotation.x += delta * 24.0
	else:
		if fp_left_arm and fp_left_arm.visible:
			fp_left_arm.visible = false


func _process(delta: float) -> void:
	if is_in_cutscene:
		if retro_skeleton and is_instance_valid(retro_skeleton):
			retro_skeleton.update_pose(0.0, false, false, delta, false, "", false, 0.0)
		return

	var active_held_mode: String = flashlight_mode if (flashlight_enabled_by_host and flashlight_mode != "disabled") else ""
	var head_pitch: float = head.rotation.x if head else 0.0
	var is_light_active: bool = flashlight_is_on and flashlight_enabled_by_host and (flashlight_energy > 0.05)

	if is_multiplayer_authority():
		_update_fp_rig(delta)
		_sync_light_positions()

		if retro_skeleton and is_instance_valid(retro_skeleton):
			retro_skeleton.update_pose(
				current_speed,
				walking and is_on_floor(),
				crouching,
				delta,
				false,
				active_held_mode,
				is_cranking,
				head_pitch,
				is_light_active,
				crank_reach_blend
			)
	else:
		if prev_remote_position == Vector3.ZERO:
			prev_remote_position = global_position
		var moved_dist := (global_position - prev_remote_position).length()
		prev_remote_position = global_position
		var remote_speed: float = moved_dist / maxf(delta, 0.001)
		var remote_moving: bool = remote_speed > 0.15

		# Remote peer footsteps in 3D positional audio
		if remote_moving and not crouching:
			step_distance += remote_speed * delta
			if step_distance >= 1.40:
				step_distance -= 1.40
				_play_footstep_sfx()
		else:
			step_distance = 0.0

		if flashlight_is_on != _prev_flashlight_on:
			_prev_flashlight_on = flashlight_is_on
			_play_click_sfx()

		if retro_skeleton and is_instance_valid(retro_skeleton):
			retro_skeleton.update_pose(
				remote_speed,
				remote_moving,
				crouching,
				delta,
				false,
				active_held_mode,
				is_cranking,
				head_pitch,
				is_light_active,
				crank_reach_blend
			)

		_sync_light_positions()

	# Nametag & Voice Indicator follow player hitbox when crouching
	if name_tag:
		var target_tag_y: float = (base_nametag_y - 0.45) if crouching else base_nametag_y
		name_tag.position.y = lerpf(name_tag.position.y, target_tag_y, delta * 12.0)
		if voice_indicator:
			voice_indicator.position.y = name_tag.position.y + 0.18
		# Proximity and distance culling:
		# Closer than 2.0m: hide completely so it NEVER obstructs camera or touch HUD controls
		# 2.0m to 3.0m: smoothly fade in
		# 3.0m to 14.0m: fully visible with natural 3D perspective scaling
		# 14.0m to 18.0m: fade into darkness
		# Beyond 18.0m: hidden
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam and not is_multiplayer_authority():
			var dist := cam.global_position.distance_to(name_tag.global_position)
			var net := get_node_or_null("/root/NetworkManager")
			var show_tags: bool = true
			if net:
				show_tags = bool(net.host_settings.get("show_name_tags", true))
			if not show_tags or dist < 2.0 or dist > 18.0:
				name_tag.visible = false
			else:
				name_tag.visible = true
				var alpha: float = 0.85
				if dist < 3.0:
					alpha = clampf((dist - 2.0) / 1.0, 0.0, 1.0) * 0.85
				elif dist > 14.0:
					alpha = clampf((18.0 - dist) / 4.0, 0.0, 1.0) * 0.85
				name_tag.modulate.a = alpha
				name_tag.outline_modulate.a = alpha * 0.90


func _get_aim_target(origin: Vector3, fwd: Vector3) -> Vector3:
	var space_state := get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null
	if space_state:
		# Start 0.35m ahead of origin to never intersect own body/colliders
		var ray_start: Vector3 = origin + fwd * 0.35
		var ray_end: Vector3 = origin + fwd * 25.0
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [get_rid()]
		query.collision_mask = 1 | 2 | 4 | 8
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_pos: Vector3 = result.get("position", ray_end)
			# Minimum distance of 0.8m prevents extreme light angling when hugging walls
			if origin.distance_to(hit_pos) >= 0.8:
				return hit_pos
	return origin + fwd * 20.0


func _sync_light_positions() -> void:
	if not flashlight and not lantern_light:
		return

	if is_multiplayer_authority():
		# Local First-Person: Lights emanate from first-person viewmodel in camera
		if fp_item_model and is_instance_valid(fp_item_model) and fp_item_container:
			var offset: Vector3 = fp_item_model.get_meta("light_offset") if fp_item_model.has_meta("light_offset") else Vector3(0, 0, -0.1)
			var world_light_pos: Vector3 = fp_item_container.position + fp_item_container.transform.basis * offset
			if flashlight:
				flashlight.position = world_light_pos
				# Dynamic surface convergence: hits the exact same spot on walls/doors
				var cam_node: Camera3D = camera_3d if camera_3d else (head.get_node_or_null("eyes/Camera3D") as Camera3D)
				if cam_node:
					var cam_fwd: Vector3 = -cam_node.global_transform.basis.z
					var aim_target_world: Vector3 = _get_aim_target(cam_node.global_position, cam_fwd)
					flashlight.look_at(aim_target_world, cam_node.global_transform.basis.y)
				else:
					flashlight.rotation = Vector3.ZERO
			if lantern_light:
				lantern_light.position = world_light_pos
	else:
		# Remote Third-Person: Lights, lens flare orb and volumetric beam emanate directly from 3D item in character's hand
		if retro_skeleton and is_instance_valid(retro_skeleton) and retro_skeleton.held_item_mount:
			var mount: Node3D = retro_skeleton.held_item_mount
			var item_mdl: Node3D = retro_skeleton.held_item_model
			var target_node: Node3D = item_mdl if (item_mdl and is_instance_valid(item_mdl)) else mount
			var offset: Vector3 = target_node.get_meta("light_offset") if target_node.has_meta("light_offset") else Vector3(0.0, 0.0, -0.09)

			var emit_pos: Vector3 = target_node.global_position + target_node.global_transform.basis * offset
			if flashlight:
				flashlight.global_position = emit_pos
				if flashlight_mode == "lantern":
					flashlight.global_rotation = target_node.global_rotation
				else:
					var aim_fwd: Vector3 = -head.global_transform.basis.z if head else -global_transform.basis.z
					var aim_up: Vector3 = head.global_transform.basis.y if head else Vector3.UP
					var head_pos: Vector3 = head.global_position if head else (global_position + Vector3(0.0, 1.8, 0.0))
					# Dynamic surface convergence: matches 1st person aim target on walls/doors perfectly!
					var aim_target: Vector3 = _get_aim_target(head_pos, aim_fwd)
					flashlight.look_at(aim_target, aim_up)
					if item_mdl and is_instance_valid(item_mdl) and not is_cranking:
						item_mdl.global_rotation = flashlight.global_rotation
			if lantern_light:
				lantern_light.global_position = emit_pos


func setup_role(role_name: String) -> void:
	flashlight_mode = role_name
	flashlight_enabled_by_host = (flashlight_mode != "disabled")
	_apply_role_profile()
	_update_light_visibility()
	_update_fp_item_model()
	if flashlight_hud:
		flashlight_hud.visible = is_multiplayer_authority() and flashlight_enabled_by_host and not is_in_cutscene
	_update_flashlight_hud(0.0)


func set_cutscene_mode(active: bool) -> void:
	is_in_cutscene = active
	if retro_skeleton and is_instance_valid(retro_skeleton):
		retro_skeleton.set_first_person(not active and is_multiplayer_authority())
	if fp_rig and is_instance_valid(fp_rig):
		fp_rig.visible = not active and is_multiplayer_authority()
	if active:
		if is_multiplayer_authority():
			camera_3d.current = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if voice_hud: voice_hud.visible = false
			if crosshair_layer: crosshair_layer.visible = false
			if flashlight_hud: flashlight_hud.visible = false
			if mobile_controls: mobile_controls.visible = false
	else:
		if is_multiplayer_authority():
			camera_3d.current = true
			var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
			if not is_mobile:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if voice_hud: voice_hud.visible = true
			if crosshair_layer: crosshair_layer.visible = crosshair_enabled
			if flashlight_hud: flashlight_hud.visible = flashlight_enabled_by_host and (flashlight_mode != "disabled")
			if mobile_controls: mobile_controls._check_platform_visibility()


func _update_light_visibility() -> void:
	if not is_inside_tree():
		return
	var active: bool = flashlight_is_on and flashlight_enabled_by_host
	var is_lantern: bool = (flashlight_mode == "lantern")
	var is_local: bool = is_multiplayer_authority()

	# Spotlight is used by flashlights/torches, disabled for lanterns
	if flashlight:
		flashlight.visible = active and not is_lantern

	# OmniLight3D provides true 360-degree illumination for lanterns
	if lantern_light:
		lantern_light.visible = active and is_lantern

	# Physical item body meshes (handled cleanly by ItemModels and FP rig)
	if torch_body:
		torch_body.visible = false

	if lantern_body:
		lantern_body.visible = false

	# Flare / Glare & Volumetric Cone:
	# - Lanterns NEVER have lens flare glare or focused conical beams
	# - Directional torches hide flare/beam locally (to not blind 1st person), visible to other peers
	if lens_glow:
		lens_glow.visible = active and (not is_lantern) and (not is_local)

	if beam_mesh:
		beam_mesh.visible = active and (not is_lantern) and (not is_local)

	# Physical lens/mantle appearance (dark grey/black when off, glowing emissive when on)
	var is_lit := active and (flashlight_energy > 0.05)
	if fp_item_model and is_instance_valid(fp_item_model):
		ITEM_MODELS_SCRIPT.set_item_light_state(fp_item_model, is_lit, flashlight_mode)
	if retro_skeleton and is_instance_valid(retro_skeleton) and retro_skeleton.held_item_model:
		ITEM_MODELS_SCRIPT.set_item_light_state(retro_skeleton.held_item_model, is_lit, flashlight_mode)

	if mobile_controls and mobile_controls.has_method("update_flashlight_ui"):
		mobile_controls.update_flashlight_ui(active)


func _apply_role_profile() -> void:
	if not flashlight:
		return
	match flashlight_mode:
		"uv":
			flashlight.light_color = Color(0.68, 0.28, 0.98)
			flashlight.spot_range = 10.0
			flashlight.spot_angle = 32.0
		"lantern":
			if lantern_light:
				lantern_light.light_color = Color(1.0, 0.82, 0.52)
				lantern_light.omni_range = 9.0
				lantern_light.omni_attenuation = 1.25
		"battery":
			flashlight.light_color = Color(0.95, 0.98, 1.0)
			flashlight.spot_range = 18.0
			flashlight.spot_angle = 38.0
		"crank":
			flashlight.light_color = Color(1.0, 0.95, 0.82)
			flashlight.spot_range = 12.0
			flashlight.spot_angle = 42.0
		_:
			flashlight.light_color = Color(1.0, 0.96, 0.88)
			flashlight.spot_range = 14.0
			flashlight.spot_angle = 45.0

	if beam_mesh and beam_mesh.material_override:
		var mat := beam_mesh.material_override as ShaderMaterial
		if mat:
			if flashlight_mode == "uv":
				mat.set_shader_parameter("beam_color", Color(0.68, 0.28, 0.98, 0.08))
			else:
				mat.set_shader_parameter("beam_color", Color(1.0, 0.96, 0.88, 0.05))

	if lens_glow and lens_glow.material_override:
		var mat := lens_glow.material_override as StandardMaterial3D
		if mat:
			if flashlight_mode == "uv":
				mat.albedo_color = Color(0.7, 0.3, 1.0, 0.85)
			else:
				mat.albedo_color = Color(1.0, 0.95, 0.85, 0.75)


func _apply_flashlight_energy(energy: float) -> void:
	if flashlight:
		flashlight.light_energy = energy
	if lantern_light:
		lantern_light.light_energy = energy
	if beam_mesh and beam_mesh.material_override:
		var mat := beam_mesh.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("beam_energy", energy / 2.0)
	if lens_glow and lens_glow.material_override:
		var mat := lens_glow.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = clamp(0.75 * (energy / 2.0), 0.0, 1.0)

	var is_lit := flashlight_is_on and flashlight_enabled_by_host and (energy > 0.05)
	if fp_item_model and is_instance_valid(fp_item_model):
		ITEM_MODELS_SCRIPT.set_item_light_state(fp_item_model, is_lit, flashlight_mode)
	if retro_skeleton and is_instance_valid(retro_skeleton) and retro_skeleton.held_item_model:
		ITEM_MODELS_SCRIPT.set_item_light_state(retro_skeleton.held_item_model, is_lit, flashlight_mode)


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_in_cutscene:
		return

	# Toggle mouse cursor capture (Escape key)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Mouse look logic (only active when cursor is captured)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if free_looking:
			nek.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			nek.rotation.y = clamp(nek.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Flashlight / Lantern Toggle (F)
	if event.is_action_pressed("flashlight") and flashlight_enabled_by_host:
		_toggle_flashlight()

	# Offline / Solo quick role switch testing (1: Battery, 2: Crank, 3: Lantern, 4: UV)
	var net := get_node_or_null("/root/NetworkManager")
	var is_offline: bool = (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		or (net == null) \
		or (net.get("peer") == null and net.get("webrtc_mp") == null)
	if is_offline and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			setup_role("battery")
		elif event.keycode == KEY_2:
			setup_role("crank")
		elif event.keycode == KEY_3:
			setup_role("lantern")
		elif event.keycode == KEY_4:
			setup_role("uv")

	# Hand-Crank / Shake Flashlight (Feedback for non-crank modes)
	if event.is_action_pressed("crank_flashlight") and flashlight_enabled_by_host:
		if flashlight_mode in ["normal", "uv", "lantern"]:
			print("Flashlight: %s has infinite power (no cranking needed)." % flashlight_mode.capitalize())
		elif flashlight_mode == "battery":
			print("Flashlight: Standard battery flashlight cannot be hand-cranked.")


func _toggle_flashlight() -> void:
	if not flashlight_enabled_by_host:
		return
	flashlight_is_on = not flashlight_is_on
	_prev_flashlight_on = flashlight_is_on
	_update_light_visibility()
	_update_flashlight_hud(0.0)
	_play_click_sfx()
	# Mechanical switch click feeds transient impulse into the loud meter (audible even while walking)
	noise_impulse = clampf(noise_impulse + 0.38, 0.0, 1.0)
	noise_level = clampf(noise_level + 0.38, 0.0, 1.0)
	print("Flashlight: toggled %s (Noise impulse added: +0.38, total: %.2f)" % ["ON" if flashlight_is_on else "OFF", noise_level])


func _trigger_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	if interact_ray_cast and interact_ray_cast.is_colliding():
		var col = interact_ray_cast.get_collider()
		if col and col.has_method("interact"):
			col.interact(self)


func _trigger_drop() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	var cur_scene := get_tree().current_scene
	if cur_scene and cur_scene.has_method("_handle_drop_item"):
		cur_scene._handle_drop_item(self)


func set_interact_available(available: bool, prompt_text: String = "USE") -> void:
	external_interact_available = available
	external_interact_text = prompt_text
	if mobile_controls and mobile_controls.has_method("set_interact_visible"):
		mobile_controls.set_interact_visible(available, prompt_text)


func set_drop_available(available: bool) -> void:
	external_drop_available = available
	if mobile_controls and mobile_controls.has_method("set_drop_visible"):
		mobile_controls.set_drop_visible(available)


func apply_touch_look(relative: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	rotate_y(deg_to_rad(-relative.x * mouse_sens))
	head.rotate_x(deg_to_rad(-relative.y * mouse_sens))
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))


func toggle_mic_mute() -> void:
	is_mic_muted = not is_mic_muted
	if mobile_controls:
		mobile_controls.update_mic_ui(is_mic_muted)
	_update_voice_hud_status(false, 0.0)


func _execute_crank_tick() -> void:
	if flashlight_battery < 100.0:
		flashlight_battery = min(100.0, flashlight_battery + CRANK_CHARGE_PER_TICK)
	# Cranking makes loud mechanical ratchet noise that alerts enemies!
	noise_impulse = maxf(noise_impulse, 0.90)
	noise_level = clampf(noise_level + 0.90, 0.0, 1.0)
	_play_crank_sfx()
	if flashlight_is_on:
		flashlight_energy = min(2.4, flashlight_energy + 0.15)  # momentary bright pulse on crank turn
		_apply_flashlight_energy(flashlight_energy)
	_update_flashlight_hud(0.0)
	print("Flashlight: Crank tick! Battery at %.0f%% (Noise emitted: %.1f)" % [flashlight_battery, noise_level])


func _update_flashlight_hud(delta: float) -> void:
	if not is_multiplayer_authority() or not flashlight_hud:
		return

	if not flashlight_enabled_by_host or flashlight_mode == "disabled":
		flashlight_hud.visible = false
		return

	flashlight_hud.visible = true

	# Update ON / OFF status label
	if flashlight_status_label:
		if flashlight_is_on:
			flashlight_status_label.text = "ON"
			flashlight_status_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
		else:
			flashlight_status_label.text = "OFF"
			flashlight_status_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))

	var is_touch: bool = (mobile_controls and mobile_controls.visible)

	match flashlight_mode:
		"normal":
			if flashlight_icon:
				flashlight_icon.text = ""
			if flashlight_mode_label:
				flashlight_mode_label.text = "STANDARD TORCH"
			if flashlight_battery_bar:
				flashlight_battery_bar.value = 100.0
				flashlight_battery_bar.modulate = Color(0.45, 0.85, 0.95)
			if flashlight_battery_label:
				flashlight_battery_label.text = "∞"
				flashlight_battery_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			if flashlight_prompt_label:
				flashlight_prompt_label.text = "Tap Light" if is_touch else "[F] Toggle Light"
				flashlight_prompt_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))

		"crank":
			if flashlight_icon:
				flashlight_icon.text = ""
			if flashlight_mode_label:
				flashlight_mode_label.text = "HAND-CRANK DYNAMO"
			if flashlight_battery_bar:
				flashlight_battery_bar.value = flashlight_battery
				_apply_battery_bar_color(flashlight_battery)
			if flashlight_battery_label:
				flashlight_battery_label.text = "%d%%" % int(flashlight_battery)

			if flashlight_prompt_label:
				if is_cranking:
					if flashlight_battery >= 99.5:
						flashlight_prompt_label.text = "BATTERY FULL (Release)"
						flashlight_prompt_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.6))
					else:
						var pulse: float = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
						flashlight_prompt_label.text = "CRANKING... (Keep holding)" if not is_touch else "CRANKING... (Hold)"
						flashlight_prompt_label.add_theme_color_override("font_color", lerp(Color(0.95, 0.85, 0.45), Color(1.0, 1.0, 0.7), pulse))
				elif crank_hold_timer > 0.0:
					if crank_hold_timer < CRANK_PHASE_1_DURATION:
						flashlight_prompt_label.text = "Slowdown... (Hold)" if is_touch else "Decelerating... (Hold [C])"
						flashlight_prompt_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
					else:
						flashlight_prompt_label.text = "Reaching crank... (Hold)" if is_touch else "Reaching crank... (Hold [C])"
						flashlight_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
				elif flashlight_battery < 25.0:
					var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
					flashlight_prompt_label.text = "HOLD CRANK!" if is_touch else "HOLD [C] TO CRANK!"
					flashlight_prompt_label.add_theme_color_override("font_color", lerp(Color(0.95, 0.3, 0.3), Color(1.0, 0.8, 0.4), pulse))
				elif not flashlight_is_on and flashlight_battery < 60.0:
					flashlight_prompt_label.text = "Hold Crank to charge" if is_touch else "Hold [C] to Crank"
					flashlight_prompt_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
				else:
					flashlight_prompt_label.text = "Light / Hold Crank" if is_touch else "[F] Light  |  [C] Hold Crank"
					flashlight_prompt_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))

		"battery":
			if flashlight_icon:
				flashlight_icon.text = ""
			if flashlight_mode_label:
				flashlight_mode_label.text = "BATTERY FLASHLIGHT"
			if flashlight_battery_bar:
				flashlight_battery_bar.value = flashlight_battery
				_apply_battery_bar_color(flashlight_battery)
			if flashlight_battery_label:
				flashlight_battery_label.text = "%d%%" % int(flashlight_battery)

			if flashlight_prompt_label:
				if flashlight_battery <= 0.0:
					flashlight_prompt_label.text = "BATTERY DEAD (Emergency Glow)"
					flashlight_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
				elif flashlight_battery < 20.0:
					var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
					flashlight_prompt_label.text = "LOW BATTERY (Flickering)"
					flashlight_prompt_label.add_theme_color_override("font_color", lerp(Color(0.95, 0.35, 0.35), Color(0.95, 0.7, 0.3), pulse))
				else:
					flashlight_prompt_label.text = "Tap Light" if is_touch else "[F] Toggle Light"
					flashlight_prompt_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))

		"uv":
			if flashlight_icon:
				flashlight_icon.text = ""
			if flashlight_mode_label:
				flashlight_mode_label.text = "UV BLACKLIGHT"
			if flashlight_battery_bar:
				flashlight_battery_bar.value = 100.0
				flashlight_battery_bar.modulate = Color(0.72, 0.35, 0.95)
			if flashlight_battery_label:
				flashlight_battery_label.text = "∞"
				flashlight_battery_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.95))
			if flashlight_prompt_label:
				flashlight_prompt_label.text = "Tap Light (Reveals Clues)" if is_touch else "[F] UV Light (Reveals Clues)"
				flashlight_prompt_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.9))

		"lantern":
			if flashlight_icon:
				flashlight_icon.text = ""
			if flashlight_mode_label:
				flashlight_mode_label.text = "KEROSENE LANTERN"
			if flashlight_battery_bar:
				flashlight_battery_bar.value = 100.0
				flashlight_battery_bar.modulate = Color(1.0, 0.8, 0.45)
			if flashlight_battery_label:
				flashlight_battery_label.text = "∞"
				flashlight_battery_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
			if flashlight_prompt_label:
				flashlight_prompt_label.text = "Tap Light (360° Light)" if is_touch else "[F] Toggle Lantern (360° Light)"
				flashlight_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.55))


func _apply_battery_bar_color(val: float) -> void:
	if not flashlight_battery_bar:
		return
	var col: Color = Color(0.45, 0.85, 0.6)  # Green/Cyan (>50%)
	if val <= 20.0:
		col = Color(0.95, 0.35, 0.35)  # Critical Red
	elif val <= 50.0:
		col = Color(0.95, 0.75, 0.35)  # Amber Warning
	
	flashlight_battery_bar.modulate = col
	if flashlight_battery_label:
		flashlight_battery_label.add_theme_color_override("font_color", col)


func _physics_process(delta: float) -> void:
	if is_in_cutscene:
		return

	# Flashlight remote sync & battery processing
	if flashlight_is_on:
		if is_multiplayer_authority():
			if flashlight_mode in ["normal", "uv", "lantern"]:
				flashlight_battery = 100.0
				if flashlight_mode == "uv":
					flashlight_energy = 1.3
				elif flashlight_mode == "lantern":
					flashlight_energy = 2.0
				else:
					flashlight_energy = 2.0
				_apply_flashlight_energy(flashlight_energy)
			elif flashlight_mode in ["crank", "battery"]:
				var drain_speed := crank_battery_drain_speed if flashlight_mode == "crank" else battery_drain_speed
				flashlight_battery = max(0.0, flashlight_battery - drain_speed * delta)
				
				if flashlight_battery > 20.0:
					flashlight_energy = 2.0
				elif flashlight_battery > 0.0:
					# Dims and flickers slightly when battery is low
					var ratio := flashlight_battery / 20.0
					flashlight_energy = lerp(0.4, 1.8, ratio) * randf_range(0.85, 1.0)
				else:
					# Emergency glow: never completely blind!
					flashlight_energy = 0.15
				
				_apply_flashlight_energy(flashlight_energy)

		# Raycast to stop volumetric beam at walls and obstacles
		if beam_mesh and beam_mesh.visible:
			var target_dist: float = 8.0
			if beam_ray_cast and beam_ray_cast.is_colliding():
				var col = beam_ray_cast.get_collider()
				# Do not cut off volumetric beam on other player heads or bodies
				if not (col is CharacterBody3D):
					var hit_pt: Vector3 = beam_ray_cast.get_collision_point()
					target_dist = clamp(flashlight.global_position.distance_to(hit_pt), 0.5, 8.0)
			
			if beam_mesh.material_override:
				var mat := beam_mesh.material_override as ShaderMaterial
				if mat:
					var cur_max: float = mat.get_shader_parameter("max_beam_dist") if mat.get_shader_parameter("max_beam_dist") != null else 8.0
					mat.set_shader_parameter("max_beam_dist", lerpf(cur_max, target_dist, delta * 12.0))
	
	# Hand-crank flashlight 3-stage progression logic (controlling authority only)
	var wants_to_crank: bool = false
	if is_multiplayer_authority():
		wants_to_crank = (Input.is_action_pressed("crank_flashlight") or touch_crank_held) \
			and flashlight_enabled_by_host \
			and flashlight_mode == "crank"

		if wants_to_crank:
			crank_hold_timer += delta
			if crank_hold_timer < CRANK_PHASE_1_DURATION:
				# Phase 1: Movement slows down immediately, hands preparing
				is_cranking = false
				crank_reach_blend = 0.0
			elif crank_hold_timer < CRANK_START_DELAY:
				# Phase 2: Second hand slowly reaches for the flashlight crank
				is_cranking = false
				var reach_ratio := (crank_hold_timer - CRANK_PHASE_1_DURATION) / CRANK_PHASE_2_DURATION
				crank_reach_blend = clampf(reach_ratio, 0.0, 1.0)
			else:
				# Phase 3: Actual cranking & charging begins
				is_cranking = true
				crank_reach_blend = 1.0
				crank_tick_timer += delta
				if crank_tick_timer >= CRANK_TICK_INTERVAL:
					crank_tick_timer = 0.0
					_execute_crank_tick()
		else:
			crank_hold_timer = 0.0
			crank_tick_timer = 0.0
			is_cranking = false
			crank_reach_blend = move_toward(crank_reach_blend, 0.0, delta * 4.0)

	_process_voice_chat(delta)
	_update_flashlight_hud(delta)
	_update_noise_hud(delta)

	# Only the controlling peer computes input and character physics
	if not is_multiplayer_authority():
		return

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	if touch_move_vector != Vector2.ZERO:
		input_dir = touch_move_vector

	# Movement slowdown calculation across all 3 cranking phases
	var is_crank_active := wants_to_crank or is_cranking or (crank_reach_blend > 0.05)
	var current_crank_slowdown := 1.0
	if is_crank_active:
		var decel_progress := clampf(crank_hold_timer / CRANK_PHASE_1_DURATION, 0.0, 1.0)
		current_crank_slowdown = lerpf(1.0, CRANK_SLOWDOWN_FACTOR, decel_progress)

	# --- Crouch & Movement Logic ---
	var is_crouching_input := Input.is_action_pressed("crouch") or touch_crouch_active
	if is_crouching_input:
		if not _was_crouching:
			_play_crouch_sfx()
		crouching = true
		_was_crouching = true
		walking = false
		var target_crouch_speed := crouching_speed * current_crank_slowdown
		current_speed = lerp(current_speed, target_crouch_speed, delta * lerp_speed)
		head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	elif !ray_cast_3d.is_colliding():
		crouching = false
		_was_crouching = false
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		walking = (input_dir != Vector2.ZERO)
		var target_walk_speed := walking_speed * current_crank_slowdown
		current_speed = lerp(current_speed, target_walk_speed, delta * lerp_speed)

	# --- Free-Look Handling ---
	if Input.is_action_pressed("free_look"):
		free_looking = true
		eyes.rotation.z = -deg_to_rad(nek.rotation.y * free_look_tilt_amount)
	else:
		free_looking = false
		nek.rotation.y = lerp(nek.rotation.y, 0.0, delta * lerp_speed)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed)

	# --- Head Bobbing ---
	if is_on_floor() and input_dir != Vector2.ZERO:
		if crouching:
			head_bobbing_current_intensity = head_bobbing_crouching_intensity
			head_bobbing_index += head_bobbing_crouching_speed * delta
		else:
			head_bobbing_current_intensity = head_bobbing_walking_intensity
			head_bobbing_index += head_bobbing_walking_speed * delta
		
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index * 0.5) + 0.5
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity * 0.5), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_current_intensity, delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)

	# --- Footstep Audio & Locomotion Cadence ---
	if is_on_floor() and not crouching and velocity.length() > 0.15:
		step_distance += velocity.length() * delta
		if step_distance >= 1.40:
			step_distance -= 1.40
			_play_footstep_sfx()
	else:
		step_distance = 0.0

	# --- Noise Level Calculation ---
	# Crouching makes movement completely silent (stealth)
	var movement_noise: float = 0.0
	if not crouching and is_on_floor() and input_dir != Vector2.ZERO:
		movement_noise = clampf((velocity.length() / walking_speed) * 0.48, 0.0, 0.55)

	# Transient noise impulses (speech, clicks, cranking) decay smoothly toward 0.0
	if noise_impulse > 0.0:
		noise_impulse = move_toward(noise_impulse, 0.0, delta * 1.6)

	noise_level = clampf(movement_noise + noise_impulse, 0.0, 1.0)

	# --- Gravity & Movement ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * 3.0)

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	# Safeguard player body to stay strictly upright on the horizontal plane
	rotation.x = 0.0
	rotation.z = 0.0
	move_and_slide()

	# --- Mobile Touch HUD Synchronizations ---
	var can_interact_now := external_interact_available
	if not can_interact_now and interact_ray_cast and interact_ray_cast.is_colliding():
		var col = interact_ray_cast.get_collider()
		if col:
			var c_name: String = str(col.name).to_lower()
			var p_name: String = str(col.get_parent().name).to_lower() if col.get_parent() else ""
			if col.is_in_group("interactable") or col.has_method("interact") or col.has_meta("interactable") \
				or "door" in c_name or "door" in p_name \
				or "bag" in c_name or "bag" in p_name \
				or "item" in c_name or "item" in p_name \
				or "vase" in c_name or "vase" in p_name \
				or "trunk" in c_name or "trunk" in p_name \
				or "switch" in c_name or "puzzle" in c_name \
				or "drawer" in c_name or "cabinet" in c_name or "key" in c_name:
				can_interact_now = true

	if mobile_controls and mobile_controls.visible:
		mobile_controls.update_crouch_ui(crouching)
		mobile_controls.set_drop_visible(external_drop_available)
		mobile_controls.set_interact_visible(can_interact_now)

	if crosshair_ring and is_multiplayer_authority():
		var show_ring := false
		if not is_in_cutscene and crosshair_enabled:
			show_ring = can_interact_now
		crosshair_ring.visible = show_ring


# --- Proximity Voice Chat System ---
func _setup_voice_capture() -> void:
	if not is_multiplayer_authority():
		return
	if voice_capture_player:
		voice_capture_player.bus = &"Record"
	var record_bus_idx := AudioServer.get_bus_index("Record")
	if record_bus_idx != -1:
		for i in range(AudioServer.get_bus_effect_count(record_bus_idx)):
			var effect := AudioServer.get_bus_effect(record_bus_idx, i)
			if effect is AudioEffectCapture:
				voice_capture_effect = effect
				voice_capture_effect.clear_buffer()
				break
	
	if voice_capture_effect and voice_capture_player:
		voice_capture_player.play()
		_update_voice_hud_status(false, 0.0)
		print("VoiceChat: Microphone capture initialized on 'Record' bus.")
	else:
		push_warning("VoiceChat: Could not find AudioEffectCapture on 'Record' bus.")


func _setup_voice_playback() -> void:
	if voice_player_3d:
		if not voice_player_3d.playing:
			voice_player_3d.play()
		voice_generator_playback = voice_player_3d.get_stream_playback() as AudioStreamGeneratorPlayback


func _process_voice_chat(delta: float) -> void:
	if not is_multiplayer_authority():
		if remote_talking_timer > 0.0:
			remote_talking_timer -= delta
			if remote_talking_timer <= 0.0 and voice_indicator:
				voice_indicator.visible = false
		return

	var buffer: PackedVector2Array = PackedVector2Array()
	var rms: float = 0.0
	if voice_capture_effect:
		var frames_avail := voice_capture_effect.get_frames_available()
		if frames_avail > 0:
			buffer = voice_capture_effect.get_buffer(frames_avail)
			var sum_sq: float = 0.0
			for frame in buffer:
				var mono := (frame.x + frame.y) * 0.5
				sum_sq += mono * mono
			rms = sqrt(sum_sq / float(buffer.size())) if buffer.size() > 0 else 0.0

	# Check Voice Activity (PTT key held vs Voice Detection vs Always On vs Muted)
	var ptt_active := Input.is_action_pressed("push_to_talk")
	var should_transmit := false
	if is_mic_muted:
		should_transmit = false
	elif voice_mode == VoiceMode.ALWAYS_ON:
		should_transmit = true
	elif voice_mode == VoiceMode.OPEN_MIC:
		if rms > mic_threshold:
			vad_timer = VAD_HOLD_TIME
		else:
			vad_timer = max(0.0, vad_timer - delta)
		should_transmit = (vad_timer > 0.0)
	elif voice_mode == VoiceMode.PUSH_TO_TALK:
		should_transmit = ptt_active

	_update_voice_hud_status(should_transmit, rms)

	if should_transmit:
		# Calibrated speech volume above gate threshold:
		# Whisper (~threshold) registers ~0.15-0.30 (QUIET)
		# Normal speaking registers ~0.40-0.60 (NORMAL)
		# Shouting/screaming registers ~0.75-1.00 (LOUD!)
		var effective_volume: float = maxf(0.0, rms - (mic_threshold * 0.5))
		var speech_loudness: float = clampf(effective_volume * 10.0 * mic_sensitivity, 0.15, 1.0)
		noise_impulse = maxf(noise_impulse, speech_loudness)

		if not buffer.is_empty():
			voice_timer += delta
			if voice_timer >= VOICE_CHUNK_INTERVAL:
				voice_timer = 0.0
				_send_voice_buffer(buffer)
	else:
		voice_timer = 0.0


func _send_voice_buffer(buffer: PackedVector2Array) -> void:
	if buffer.is_empty():
		return

	# Downsample 44.1kHz stereo to 22.05kHz mono 16-bit PCM (take every 2nd frame)
	var raw_bytes := PackedByteArray()
	var half_size: int = buffer.size() / 2
	raw_bytes.resize(half_size * 2)

	for i in range(half_size):
		var src_idx := i * 2
		var mono := (buffer[src_idx].x + buffer[src_idx].y) * 0.5
		var int16 := clampi(int(mono * 32767.0), -32768, 32767)
		if int16 < 0:
			int16 += 65536
		var byte_pos := i * 2
		raw_bytes[byte_pos] = int16 & 0xFF
		raw_bytes[byte_pos + 1] = (int16 >> 8) & 0xFF

	var uncompressed_size := raw_bytes.size()
	var compressed := raw_bytes.compress(FileAccess.COMPRESSION_FASTLZ)
	
	receive_voice_chunk.rpc(compressed, uncompressed_size)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func receive_voice_chunk(compressed_chunk: PackedByteArray, uncompressed_size: int) -> void:
	if is_multiplayer_authority():
		return

	if not voice_generator_playback:
		_setup_voice_playback()
	if not voice_generator_playback:
		return

	# Display 3D talking indicator above player's head
	if voice_indicator:
		voice_indicator.visible = true
		remote_talking_timer = 0.25

	var raw_bytes := compressed_chunk.decompress(uncompressed_size, FileAccess.COMPRESSION_FASTLZ)
	if raw_bytes.is_empty():
		return

	var num_samples := raw_bytes.size() / 2
	var frames_avail := voice_generator_playback.get_frames_available()
	var to_push := mini(num_samples, frames_avail)

	for i in range(to_push):
		var byte_idx := i * 2
		var low := raw_bytes[byte_idx]
		var high := raw_bytes[byte_idx + 1]
		var int16 := low | (high << 8)
		if int16 >= 32768:
			int16 -= 65536
		var sample := float(int16) / 32767.0
		voice_generator_playback.push_frame(Vector2(sample, sample))


func _update_voice_hud_status(is_transmitting: bool, volume: float) -> void:
	if not voice_hud or not voice_hud.visible or not voice_label or not voice_mic_icon:
		return
	
	if is_mic_muted:
		voice_mic_icon.modulate = Color(0.8, 0.45, 0.45, 0.7)
		voice_label.text = "VOICE: MUTED"
		voice_label.add_theme_color_override("font_color", Color(0.8, 0.45, 0.45, 0.75))
		return

	var mode_text := "PTT"
	if voice_mode == VoiceMode.OPEN_MIC:
		mode_text = "AUTO"
	elif voice_mode == VoiceMode.ALWAYS_ON:
		mode_text = "OPEN"
	
	if is_transmitting:
		voice_mic_icon.modulate = Color(0.9, 0.88, 0.8, 0.85)
		var bars := ""
		if volume > 0.08:
			bars = " |||"
		elif volume > 0.04:
			bars = " ||"
		elif volume > 0.015:
			bars = " |"
		voice_label.text = "VOICE: ACTIVE%s" % bars
		voice_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82, 0.9))
	else:
		voice_mic_icon.modulate = Color(0.6, 0.62, 0.66, 0.45)
		voice_label.text = "VOICE: %s" % mode_text
		voice_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72, 0.55))


func _play_footstep_sfx() -> void:
	if footstep_player_3d:
		footstep_player_3d.stream = SFX_STEP_1 if (step_counter % 2 == 0) else SFX_STEP_2
		step_counter += 1
		footstep_player_3d.pitch_scale = randf_range(0.95, 1.05)
		footstep_player_3d.play()


func _play_click_sfx() -> void:
	if click_player_3d:
		click_player_3d.pitch_scale = randf_range(0.96, 1.04)
		click_player_3d.play()


func _play_crouch_sfx() -> void:
	if crouch_player_3d:
		crouch_player_3d.pitch_scale = randf_range(0.94, 1.06)
		crouch_player_3d.play()


func _play_crank_sfx() -> void:
	if crank_player_3d:
		crank_player_3d.pitch_scale = randf_range(0.95, 1.05)
		crank_player_3d.play()


func _update_noise_hud(delta: float) -> void:
	if not is_multiplayer_authority() or not is_inside_tree():
		if noise_meter_panel and is_instance_valid(noise_meter_panel):
			noise_meter_panel.visible = false
		return

	if not noise_bar or not is_instance_valid(noise_bar):
		return

	if noise_meter_panel and is_instance_valid(noise_meter_panel):
		noise_meter_panel.visible = true

	# Map noise_level (0.0 to 1.0) to 0-100% standing volume bar
	var target_pct := clampf(noise_level * 100.0, 0.0, 100.0)
	noise_bar.value = lerpf(noise_bar.value, target_pct, delta * 22.0)

	var col: Color = Color(0.35, 0.72, 0.65, 0.7)  # Silent teal
	var status_text := "SILENT"
	var icon_text := "MIC"
	var icon_col := Color(0.5, 0.6, 0.7, 0.6)

	if noise_bar.value >= 68.0:
		col = Color(1.0, 0.25, 0.2, 1.0)  # Alert Red / Danger
		status_text = "LOUD!"
		icon_text = "MIC"
		icon_col = Color(1.0, 0.35, 0.3, 1.0)
	elif noise_bar.value >= 32.0:
		col = Color(1.0, 0.82, 0.25, 0.95)  # Amber / Normal walking
		status_text = "NORMAL"
		icon_text = "MIC"
		icon_col = Color(0.95, 0.88, 0.45, 0.9)
	elif noise_bar.value >= 10.0:
		col = Color(0.55, 0.88, 0.45, 0.85)  # Soft Lime / Quiet
		status_text = "QUIET"
		icon_text = "MIC"
		icon_col = Color(0.65, 0.85, 0.6, 0.8)

	noise_bar.modulate = col
	if noise_status_label and is_instance_valid(noise_status_label):
		noise_status_label.text = status_text
		noise_status_label.add_theme_color_override("font_color", col)
	if noise_icon and is_instance_valid(noise_icon):
		noise_icon.text = icon_text
		noise_icon.modulate = icon_col
