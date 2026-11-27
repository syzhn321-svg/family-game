class_name StoryCar
extends CharacterBody3D

# --- Sibling & Identity ---
@export var sibling_id: int = 1
@export var sibling_name: String = "Player"
@export var character_name: String = ""
@export var is_host: bool = false
@export var trunk_open: bool = false
@export var is_ai: bool = false
@export var car_layer_index: int = 1
@export var paint_color: Color = Color(0.12, 0.12, 0.14)

# --- Multiplayer & Network Replication ---
var network_tick_timer: float = 0.0
const NETWORK_TICK_RATE: float = 0.033 # 30 updates per second

var remote_target_pos: Vector3 = Vector3.ZERO
var remote_target_rot_y: float = 0.0
var remote_target_speed: float = 0.0
var remote_target_steer: float = 0.0
var remote_is_braking: bool = false
var remote_is_boosting: bool = false
var remote_is_scraping: bool = false
var remote_scrape_side: float = -1.0
var remote_scrape_z: float = -0.8
var has_received_network_sync: bool = false

# --- Driving Physics Tuning (Heavy, Grounded Highway Cruise Model) ---
@export var max_speed: float = 27.78        # ~100 km/h top cruising speed cap
@export var crawl_accel_low: float = 1.65   # Gentle initial crawling pickup (~6 km/h per sec)
@export var crawl_accel_high: float = 0.45  # Gradual top-end taper (takes sustained time to reach 100 km/h)
@export var braking: float = 18.0           # Firm, progressive braking
@export var steer_speed: float = 1.30       # Heavy, weighted steering response (no twitchy snap)
@export var max_steer_angle: float = 0.20   # ~11.5° maximum steer lock at crawl
@export var drift_grip: float = 14.0        # Planted tire grip along road (no arcade drift slide)
@export var friction: float = 2.4           # Natural aerodynamic coasting drag
@export var gravity: float = 25.0           # Downward holding road adhesion

# --- Hold-to-Boost System (Surges Acceleration Up to 140 km/h) ---
@export var auto_throttle: bool = true      # Always maintains cruise speed unless braking
@export var boost_speed: float = 38.89      # ~140 km/h top passing speed during boost
@export var boost_accel: float = 4.8        # Surges crawl rate to pull powerfully to 140 km/h

var is_boosting: bool = false
var touch_boost: bool = false
var is_boost_key_held: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_authority():
		return
	if event is InputEventKey:
		if event.keycode in [KEY_SPACE, KEY_SHIFT, KEY_W]:
			is_boost_key_held = event.pressed

# --- Live Driving State ---
var current_speed: float = 0.0              # Forward/backward velocity magnitude
var current_steer_angle: float = 0.0        # Current front wheel steer angle
var input_gas: float = 0.0                  # 0.0 to 1.0
var input_brake: float = 0.0                # 0.0 to 1.0
var input_steer: float = 0.0                # -1.0 (left) to 1.0 (right)
var input_handbrake: bool = false
var is_active_driving: bool = false         # False during cutscene, true when players take the wheel
var is_parked_at_destination: bool = false  # True once car crosses final checkpoint & must brake to a halt
var crash_spin_timer: float = 0.0           # Active 360-degree visual spinout timer on NPC impact
var crash_spin_dir: float = 1.0
var stuck_check_timer: float = 0.0          # Tracks immovable duration while trying to drive
var stuck_anchor_pos: Vector3 = Vector3.ZERO

# Mobile touch input hooks
var touch_gas: float = 0.0
var touch_brake: float = 0.0
var touch_steer: float = 0.0

# --- Visual Nodes (Separated Mount vs Spin for True Wheel Rotation) ---
var chassis_pivot: Node3D = null
var wheel_fl_mount: Node3D = null
var wheel_fr_mount: Node3D = null
var wheel_rl_mount: Node3D = null
var wheel_rr_mount: Node3D = null
var wheel_spins: Array[Node3D] = []
var wheel_roll_angle: float = 0.0
var steering_wheel_pivot: Node3D = null
var brake_glows: Array[Node] = []
var headlights: Array[SpotLight3D] = []
var name_tag: Label3D = null

# --- Boost, Tyre & Divider Collision Visual FX Nodes ---
var boost_flame_l: MeshInstance3D = null
var boost_flame_r: MeshInstance3D = null
var boost_underglow: Light3D = null
var tyre_spray_l: CPUParticles3D = null
var tyre_spray_r: CPUParticles3D = null
var divider_sparks: CPUParticles3D = null
var divider_dust: CPUParticles3D = null
var divider_spark_flash: OmniLight3D = null
var divider_fx_timer: float = 0.0
var divider_scrape_intensity: float = 0.0
var divider_scrape_local_pos: Vector3 = Vector3(-0.96, 0.52, -0.8)
var divider_scrape_side: float = -1.0
var divider_scrape_type: String = "metal"
var car_layer_mask: int = 2
var collision_cooldown_timer: float = 0.0

# --- Car-to-Car Physical Interaction & Visual FX ---
var car_contact_sparks: CPUParticles3D = null
var car_contact_flash: OmniLight3D = null
var car_contact_dust: CPUParticles3D = null
var bump_impulse_x: float = 0.0
var bump_impulse_z: float = 0.0
var car_bump_cooldown_timer: float = 0.0

# --- Impact Slowdown & Bobblehead Reaction State ---
signal car_crashed(car: StoryCar)

var impact_jolt_timer: float = 0.0
var driver_torso: MeshInstance3D = null
var driver_head: MeshInstance3D = null
var torso_rest_rot: Vector3 = Vector3(0.1745, 0.0, 0.0) # 10 deg rest
var head_rest_rot: Vector3 = Vector3.ZERO

# --- Audio ---
var engine_audio: AudioStreamPlayer3D = null
var audio_playback: AudioStreamGeneratorPlayback = null
var audio_phase: float = 0.0

# --- Sibling AI State ---
var ai_target_lane_x: float = -2.1
var ai_lane_switch_timer: float = 0.0
var ai_lead_distance: float = 0.0
var ai_personality_speed_bias: float = 1.0


func is_local_authority() -> bool:
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()


func is_multiplayer_active() -> bool:
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	return multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func apply_character_visuals(char_name: String, p_color: Color = Color.BLACK, s_name: String = "", broadcast: bool = true) -> void:
	if char_name.is_empty() or char_name == "random":
		char_name = "Syazril"
	character_name = char_name
	if p_color != Color.BLACK:
		paint_color = p_color
	if not s_name.is_empty():
		sibling_name = s_name

	if is_instance_valid(name_tag):
		var ai_badge := " [AI]" if is_ai else ""
		name_tag.text = "%s%s" % [sibling_name, ai_badge]

	_build_car_model(character_name)

	if broadcast and is_local_authority() and is_multiplayer_active():
		rpc_sync_car_visuals.rpc(character_name, paint_color, sibling_name)


@rpc("any_peer", "call_local", "reliable")
func rpc_sync_car_visuals(char_name: String, p_color: Color, s_name: String) -> void:
	apply_character_visuals(char_name, p_color, s_name, false)


func _ready() -> void:
	_setup_collision()
	_setup_visuals()
	_setup_audio()

	# AI personality variance
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sibling_name) + sibling_id
	ai_personality_speed_bias = rng.randf_range(0.92, 1.06)
	ai_lead_distance = rng.randf_range(-8.0, 8.0)

	if is_local_authority() and is_multiplayer_active() and not character_name.is_empty():
		rpc_sync_car_visuals.rpc(character_name, paint_color, sibling_name)


func _physics_process(delta: float) -> void:
	if not is_active_driving or not is_inside_tree():
		return

	if is_local_authority():
		# --- Local Player Driving Physics ---
		# 1. Gather Inputs (Human, Parked at Destination, or Sibling AI)
		if is_parked_at_destination:
			input_gas = 0.0
			input_brake = 1.0
			input_steer = 0.0
			input_handbrake = true
			is_boosting = false
		elif is_ai:
			_process_ai_input(delta)
		else:
			_process_player_input()

		# 2. Heavy, Speed-Damped Steering Angle (Cornering)
		# At high speeds, reduce steer lock so handling feels heavy, stable, and planted
		var speed_ratio := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
		var speed_steer_damp := lerpf(1.0, 0.26, speed_ratio)
		var target_steer := input_steer * max_steer_angle * speed_steer_damp
		var centering_rate := steer_speed * 1.5 if absf(input_steer) < 0.05 else steer_speed
		current_steer_angle = move_toward(current_steer_angle, target_steer, centering_rate * delta)

		# 3. Slow Crawl Auto-Throttle & Hold-to-Boost Acceleration
		if input_brake > 0.01:
			current_speed = move_toward(current_speed, 0.0, braking * delta * input_brake)
		elif auto_throttle or input_gas > 0.01:
			if is_boosting:
				# HOLD BOOST: surges acceleration pulling toward 140 km/h (does not snap instantly)
				current_speed = move_toward(current_speed, boost_speed, boost_accel * delta)
			else:
				if current_speed > max_speed:
					# Smoothly coast down from boost to 100 km/h cruising cap
					current_speed = move_toward(current_speed, max_speed, friction * 1.6 * delta)
				else:
					# Slow crawl: gentle progressive acceleration that takes sustained time to reach 100 km/h
					var crawl_accel := lerpf(crawl_accel_low, crawl_accel_high, speed_ratio)
					current_speed = move_toward(current_speed, max_speed, crawl_accel * delta)
		else:
			current_speed = move_toward(current_speed, 0.0, friction * delta)

		if input_handbrake:
			current_speed = move_toward(current_speed, 0.0, braking * 1.5 * delta)
		current_speed = clampf(current_speed, 0.0, boost_speed)

		# 4. Turn Vehicle Orientation & Align with Road Center / Incline
		var current_road_cx := 0.0
		var current_road_cy := 0.0
		var road_slope_pitch := 0.0
		var road_yaw := 0.0
		var cur_scene := get_tree().current_scene
		if cur_scene and cur_scene.has_method("_get_road_center_x") and cur_scene.has_method("_get_road_elevation"):
			current_road_cx = float(cur_scene.call("_get_road_center_x", global_position.z))
			current_road_cy = float(cur_scene.call("_get_road_elevation", global_position.z))
			var ahead_cx := float(cur_scene.call("_get_road_center_x", global_position.z - 6.0))
			var front_cy := float(cur_scene.call("_get_road_elevation", global_position.z - 2.0))
			var rear_cy := float(cur_scene.call("_get_road_elevation", global_position.z + 2.0))
			road_yaw = -atan2(ahead_cx - current_road_cx, 6.0)
			road_slope_pitch = atan2(front_cy - rear_cy, 4.0)

		if absf(current_speed) > 0.2:
			var forward_dir := 1.0 if current_speed >= 0.0 else -1.0
			var turn_rate := current_steer_angle * clampf(current_speed * 0.12, 0.5, 2.4) * forward_dir
			rotation.y -= turn_rate * delta

			if absf(global_position.x - current_road_cx) > 5.2:
				rotation.y = lerp_angle(rotation.y, road_yaw, delta * 4.5)

		# Safe forward heading lock: prevent car from ever turning backward down the highway
		const MAX_YAW_OFFSET: float = 0.58 # ~33 deg max off road heading
		var rel_yaw := wrapf(rotation.y - road_yaw, -PI, PI)
		if absf(rel_yaw) > MAX_YAW_OFFSET:
			rotation.y = lerp_angle(rotation.y, road_yaw + clampf(rel_yaw, -MAX_YAW_OFFSET, MAX_YAW_OFFSET), clampf(delta * 18.0, 0.0, 1.0))

		# Pitch car smoothly to follow road slopes and bridge crests naturally
		rotation.x = lerp_angle(rotation.x, road_slope_pitch, delta * 8.0)

		# 360-degree visual spinout on oncoming NPC collision (camera & physics heading stay safe)
		if is_instance_valid(chassis_pivot):
			if crash_spin_timer > 0.0:
				crash_spin_timer = maxf(0.0, crash_spin_timer - delta)
				var spin_p: float = 1.0 - (crash_spin_timer / 0.85)
				var eased_p: float = 1.0 - pow(1.0 - spin_p, 2.0)
				chassis_pivot.rotation.y = crash_spin_dir * TAU * eased_p
			else:
				chassis_pivot.rotation.y = 0.0

		# 5. Compute Velocity Vector with Strong Lateral Grip & Slope Pitch
		var forward_vec := -global_transform.basis.z.normalized()
		forward_vec.y = sin(road_slope_pitch)
		forward_vec = forward_vec.normalized()

		var right_vec := global_transform.basis.x.normalized()
		# Compute pure lateral sliding velocity separated from transient collision impulse
		var pure_lateral_vel := (velocity - right_vec * bump_impulse_x).dot(right_vec) * right_vec
		var grip := drift_grip * (0.35 if input_handbrake else 1.0)
		var new_lateral := pure_lateral_vel.move_toward(Vector3.ZERO, grip * delta * 15.0)

		# Smoothly decay bump impulses over time (suspension spring damping)
		bump_impulse_x = move_toward(bump_impulse_x, 0.0, delta * 9.5)
		bump_impulse_z = move_toward(bump_impulse_z, 0.0, delta * 8.0)
		if car_bump_cooldown_timer > 0.0:
			car_bump_cooldown_timer = maxf(0.0, car_bump_cooldown_timer - delta)

		var target_forward_vel := forward_vec * current_speed
		velocity.x = target_forward_vel.x + new_lateral.x + bump_impulse_x
		velocity.z = target_forward_vel.z + new_lateral.z + (forward_vec.z * bump_impulse_z)

		# Vertical slope velocity & gravity snapping
		if is_on_floor():
			# Follow road slope rate plus firm downward floor snap
			velocity.y = target_forward_vel.y - 1.8
		else:
			velocity.y -= gravity * delta

		move_and_slide()

		# Physical Ground Clamping Safeguard: only clamp if genuinely sinking below road (>4cm)
		if global_position.y < current_road_cy - 0.04:
			global_position.y = current_road_cy
			if velocity.y < 0.0:
				velocity.y = 0.0

		# 6. Physical Collision Response & Elastic Momentum Transfer
		_process_car_collisions(delta)
		_check_and_recover_stuck(delta, current_road_cx, current_road_cy, road_yaw, road_slope_pitch)

		# 7. Wheel Animation & Visual Body Suspension Roll
		_update_wheel_and_chassis_animations(delta)

		# 8. Boost Exhaust Flames, Underglow, Brake Tyre Smoke & Divider Collision FX
		var is_braking := (input_brake > 0.05) or input_handbrake
		_update_boost_and_tyre_fx(delta, is_braking)
		_update_divider_fx(delta)
		_update_bobblehead(delta)
		if is_instance_valid(car_contact_flash) and car_contact_flash.light_energy > 0.01:
			car_contact_flash.light_energy = move_toward(car_contact_flash.light_energy, 0.0, delta * 32.0)

		# 9. Taillight / Brake light flare
		_update_brake_lights(is_braking)

		# 10. Audio synthesis
		_update_engine_audio(delta)

		# 11. Broadcast network transform at 30Hz
		if multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			network_tick_timer += delta
			if network_tick_timer >= NETWORK_TICK_RATE:
				network_tick_timer = 0.0
				sync_car_state.rpc(global_position, rotation.y, current_speed, current_steer_angle, is_braking, is_boosting, divider_fx_timer > 0.0, divider_scrape_side, divider_scrape_local_pos.z)
	else:
		# --- Remote Peer Car: Smooth Interpolation ---
		_process_remote_interpolation(delta)


func _process_remote_interpolation(delta: float) -> void:
	if not has_received_network_sync:
		return

	var dist := global_position.distance_to(remote_target_pos)
	if dist > 8.0:
		global_position = remote_target_pos
		rotation.y = remote_target_rot_y
	else:
		global_position = global_position.lerp(remote_target_pos, clampf(delta * 18.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, remote_target_rot_y, clampf(delta * 18.0, 0.0, 1.0))

	# Remote peer anti-sink safeguard & pitch alignment
	var cur_scene := get_tree().current_scene
	if cur_scene and cur_scene.has_method("_get_road_elevation"):
		var road_elev := float(cur_scene.call("_get_road_elevation", global_position.z))
		if global_position.y < road_elev:
			global_position.y = road_elev
		var front_elev := float(cur_scene.call("_get_road_elevation", global_position.z - 2.0))
		var rear_elev := float(cur_scene.call("_get_road_elevation", global_position.z + 2.0))
		var road_pitch := atan2(front_elev - rear_elev, 4.0)
		rotation.x = lerp_angle(rotation.x, road_pitch, delta * 8.0)

	if is_instance_valid(chassis_pivot):
		if crash_spin_timer > 0.0:
			crash_spin_timer = maxf(0.0, crash_spin_timer - delta)
			var spin_p: float = 1.0 - (crash_spin_timer / 0.85)
			var eased_p: float = 1.0 - pow(1.0 - spin_p, 2.0)
			chassis_pivot.rotation.y = crash_spin_dir * TAU * eased_p
		else:
			chassis_pivot.rotation.y = 0.0

	current_speed = lerpf(current_speed, remote_target_speed, clampf(delta * 16.0, 0.0, 1.0))
	current_steer_angle = lerpf(current_steer_angle, remote_target_steer, clampf(delta * 18.0, 0.0, 1.0))
	is_boosting = remote_is_boosting

	_update_wheel_and_chassis_animations(delta)
	_update_boost_and_tyre_fx(delta, remote_is_braking)
	_update_divider_fx(delta)
	_update_bobblehead(delta)
	if is_instance_valid(car_contact_flash) and car_contact_flash.light_energy > 0.01:
		car_contact_flash.light_energy = move_toward(car_contact_flash.light_energy, 0.0, delta * 32.0)
	_update_brake_lights(remote_is_braking)
	_update_engine_audio(delta)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func sync_car_state(pos: Vector3, rot_y: float, spd: float, steer: float, is_brake: bool, is_boost: bool, is_scraping: bool = false, scrape_side: float = -1.0, scrape_z: float = -0.8) -> void:
	if is_local_authority():
		return
	remote_target_pos = pos
	remote_target_rot_y = rot_y
	remote_target_speed = spd
	remote_target_steer = steer
	remote_is_braking = is_brake
	remote_is_boosting = is_boost
	remote_is_scraping = is_scraping
	remote_scrape_side = scrape_side
	remote_scrape_z = scrape_z

	if not has_received_network_sync:
		has_received_network_sync = true
		global_position = pos
		rotation.y = rot_y
		current_speed = spd
		current_steer_angle = steer


# --- Input Handling (Hold-to-Boost & Heavy Steering) ---
func _process_player_input() -> void:
	# Cornering (Left / Right)
	var key_left := Input.get_action_strength("ui_left") + (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	var key_right := Input.get_action_strength("ui_right") + (1.0 if Input.is_key_pressed(KEY_D) else 0.0)
	input_steer = clampf((key_right - key_left) + touch_steer, -1.0, 1.0)

	# Braking
	var key_brake := Input.get_action_strength("ui_down") + (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
	input_brake = clampf(maxf(key_brake, touch_brake), 0.0, 1.0)

	# Auto-Throttle: Throttle is held automatically unless braking
	input_gas = 0.0 if input_brake > 0.05 else 1.0
	input_handbrake = false

	# HOLD TO BOOST: Holding Space / Shift / W or touch button increases acceleration rate up to 140 km/h
	var key_boost := is_boost_key_held or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_accept")
	is_boosting = (key_boost or touch_boost) and is_active_driving


func _process_ai_input(delta: float) -> void:
	# Sibling AI: Playfully races alongside the human player
	var player_car: StoryCar = null
	var parent_node := get_parent()
	if parent_node:
		for sibling in parent_node.get_children():
			if sibling is StoryCar and not sibling.is_ai:
				player_car = sibling
				break

	# 1. Target Speed: Match player speed + personality bias
	var target_speed := 18.0
	if player_car:
		var p_speed := absf(player_car.current_speed)
		target_speed = clampf(p_speed * ai_personality_speed_bias, 14.0, max_speed * 0.96)
		if is_boosting:
			target_speed = boost_speed * 0.92

		# Catch-up / Slow-down logic based on Z distance
		var z_diff := global_position.z - (player_car.global_position.z + ai_lead_distance)
		if z_diff > 16.0:
			# AI is falling behind -> hold boost to surge acceleration
			is_boosting = true
			target_speed = boost_speed
		elif z_diff < -15.0:
			# AI is too far ahead -> ease off
			is_boosting = false
			target_speed = maxf(12.0, p_speed * 0.85)
		else:
			is_boosting = false

	if current_speed < target_speed:
		input_gas = 1.0
		input_brake = 0.0
	else:
		input_gas = 0.1
		input_brake = 0.2 if (current_speed > target_speed + 4.0) else 0.0

	# 2. Lane Keeping & Gentle Overtaking along Road Center
	var road_cx := 0.0
	var scene := get_tree().current_scene
	if scene and scene.has_method("_get_road_center_x"):
		road_cx = float(scene.call("_get_road_center_x", global_position.z))

	ai_lane_switch_timer += delta
	if ai_lane_switch_timer > 8.0:
		ai_lane_switch_timer = 0.0
		var rand_choice := randf()
		if rand_choice < 0.45:
			ai_target_lane_x = -2.2 + randf_range(-0.4, 0.4)
		else:
			ai_target_lane_x = 2.2 + randf_range(-0.4, 0.4)

	# Steer towards target lane position relative to road center
	var target_x := road_cx + ai_target_lane_x
	var x_error := target_x - global_position.x
	var desired_steer := clampf(x_error * 0.45, -0.65, 0.65)

	# Align rotation with road heading
	var next_cx := road_cx
	if scene and scene.has_method("_get_road_center_x"):
		next_cx = float(scene.call("_get_road_center_x", global_position.z - 8.0))
	var road_yaw := atan2(next_cx - road_cx, -8.0)
	var current_heading := wrapf(rotation.y - road_yaw, -PI, PI)
	var heading_correction := -current_heading * 0.85

	input_steer = clampf(desired_steer + heading_correction, -1.0, 1.0)
	input_handbrake = false


# --- Visual Animations (Mount Y-Steer vs Spin X-Roll Separation) ---
func _update_wheel_and_chassis_animations(delta: float) -> void:
	# 1. Roll wheels along their local axle (X) - 0 crosstalk with steering
	var wheel_radius: float = 0.34
	var roll_step: float = -(current_speed * delta / wheel_radius)
	wheel_roll_angle = wrapf(wheel_roll_angle + roll_step, -PI, PI)

	for sp in wheel_spins:
		if is_instance_valid(sp):
			sp.rotation.x = wheel_roll_angle

	# 2. Steer ONLY front wheel mounts around vertical Y axis
	if is_instance_valid(wheel_fl_mount):
		wheel_fl_mount.rotation.y = current_steer_angle
	if is_instance_valid(wheel_fr_mount):
		wheel_fr_mount.rotation.y = current_steer_angle

	# 3. Dynamic Suspension Body Roll & Pitch
	if is_instance_valid(chassis_pivot):
		var target_roll := -current_steer_angle * (current_speed / max_speed) * 0.14
		chassis_pivot.rotation.z = lerpf(chassis_pivot.rotation.z, target_roll, delta * 4.5)

		var target_pitch := 0.0
		if is_boosting:
			target_pitch = 0.04
		elif input_gas > 0.1:
			target_pitch = 0.025
		elif input_brake > 0.1:
			target_pitch = -0.055
		chassis_pivot.rotation.x = lerpf(chassis_pivot.rotation.x, target_pitch, delta * 4.5)

	# 4. Turn Right-Hand Drive steering wheel in driver's hands
	if is_instance_valid(steering_wheel_pivot):
		steering_wheel_pivot.rotation.z = -current_steer_angle * 2.8


# --- Car-to-Car Physical Collision & Elastic Deflection ---
func _process_car_collisions(delta: float) -> void:
	if collision_cooldown_timer > 0.0:
		collision_cooldown_timer = maxf(0.0, collision_cooldown_timer - delta)

	var col_count := get_slide_collision_count()
	if col_count == 0:
		return

	var handled_car_collision := false
	var handled_divider_collision := false

	for i in range(col_count):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null or collider == self:
			continue

		# Ignore road surfaces, shoulders, gas station ground
		if collider.is_in_group("road") or collider.name.begins_with("Road") or collider.name.begins_with("Highway") or collider.name.begins_with("Station"):
			continue

		var normal := col.get_normal()

		# Ignore pure vertical road collision
		if normal.y > 0.7:
			continue

		# 0. High-Speed Collision with Oncoming Traffic (NPC explodes & vanishes; player car slows down significantly)
		if collider.is_in_group("traffic_cars"):
			var push_dir: float = signf(normal.x) if absf(normal.x) > 0.1 else -1.0
			var cur_scene := get_tree().current_scene
			if cur_scene and cur_scene.has_method("trigger_npc_explosion"):
				cur_scene.call("trigger_npc_explosion", collider)
			trigger_crash(push_dir)
			return

		# 0b. Seamless Curved Invisible Funnel Walls on unintended junction branches
		if collider.is_in_group("invisible_walls"):
			var guide_yaw := 0.0
			var cur_scene := get_tree().current_scene
			if cur_scene and cur_scene.has_method("_get_road_center_x"):
				var r_cx := float(cur_scene.call("_get_road_center_x", global_position.z))
				var r_next_cx := float(cur_scene.call("_get_road_center_x", global_position.z - 8.0))
				guide_yaw = -atan2(r_next_cx - r_cx, 8.0)
			# Smoothly lean vehicle & front wheels into the right-hand branch curve along the wall
			rotation.y = lerp_angle(rotation.y, guide_yaw, clampf(delta * 16.0, 0.0, 0.72))
			current_steer_angle = lerpf(current_steer_angle, 0.34, clampf(delta * 16.0, 0.0, 0.7))
			current_speed = maxf(current_speed, 10.0)
			continue

		# 0c. Side Divider / Guardrail Scrape & Impact FX
		if collider.is_in_group("side_dividers"):
			if not handled_divider_collision:
				handled_divider_collision = true
				_handle_divider_collision(col, delta)
			continue

		var is_car: bool = collider is StoryCar or collider.is_in_group("story_cars")

		# 1. Car-to-Car Physical Collision & Elastic Momentum Interaction
		if is_car:
			if not handled_car_collision:
				handled_car_collision = true
				_handle_car_to_car_collision(col, collider, delta)
			continue


func _handle_car_to_car_collision(col: KinematicCollision3D, other_car: Node, delta: float) -> void:
	var normal := col.get_normal()
	# Constrain normal strictly to horizontal plane to eliminate vertical airborne launching
	normal.y = 0.0
	if normal.length_squared() < 0.001:
		normal = Vector3(1.0, 0.0, 0.0)
	normal = normal.normalized()

	var contact_pos := col.get_position()
	var depth := col.get_depth()
	var other_speed: float = float(other_car.get("current_speed")) if "current_speed" in other_car else 0.0
	var speed_diff: float = absf(current_speed - other_speed)
	var intensity: float = clampf(maxf(speed_diff * 0.12, depth * 8.0 + 0.5), 0.6, 1.8)

	# 1. Sideswipe / Lateral Fender Rub (normal.x dominant)
	if absf(normal.x) > 0.35:
		var push_dir: float = signf(normal.x)
		var lat_push: float = push_dir * clampf(3.2 + depth * 8.0, 2.5, 5.0)
		if push_dir > 0.0:
			bump_impulse_x = maxf(bump_impulse_x, lat_push)
		else:
			bump_impulse_x = minf(bump_impulse_x, lat_push)

		# Retain forward momentum with slight racing rub scrub
		current_speed = maxf(current_speed * 0.985, 7.0)

		# Visual chassis roll away from impact
		if is_instance_valid(chassis_pivot):
			chassis_pivot.rotation.z = clampf(chassis_pivot.rotation.z + push_dir * 0.05, -0.15, 0.15)

		# Trigger visual FX, contact flash, audio thump, and camera jolt
		if car_bump_cooldown_timer <= 0.0:
			car_bump_cooldown_timer = 0.18
			trigger_car_bump_fx(contact_pos, normal, intensity)
			if is_multiplayer_active():
				rpc_trigger_car_bump_fx.rpc(contact_pos, normal, intensity)
				if other_car.has_method("rpc_receive_bump"):
					other_car.rpc("rpc_receive_bump", 0.0, -push_dir * 3.2)
			else:
				if other_car.has_method("receive_bump"):
					other_car.call("receive_bump", 0.0, -push_dir * 3.2)

	# 2. Rear-End Bumper Shunt (We hit the car ahead of us, normal.z > 0.25)
	elif normal.z > 0.25:
		var rel_speed: float = maxf(0.0, current_speed - other_speed)
		var transfer_impulse: float = clampf(rel_speed * 0.55 + 2.0, 2.2, 7.5)

		# Rear car cushions and slows down smoothly
		current_speed = maxf(current_speed - transfer_impulse * 0.45, 6.0)

		if is_instance_valid(chassis_pivot):
			chassis_pivot.rotation.x = clampf(chassis_pivot.rotation.x - 0.05, -0.12, 0.12)

		if car_bump_cooldown_timer <= 0.0:
			car_bump_cooldown_timer = 0.20
			trigger_car_bump_fx(contact_pos, normal, intensity)
			if is_multiplayer_active():
				rpc_trigger_car_bump_fx.rpc(contact_pos, normal, intensity)
				if other_car.has_method("rpc_receive_bump"):
					other_car.rpc("rpc_receive_bump", transfer_impulse, 0.0)
			else:
				if other_car.has_method("receive_bump"):
					other_car.call("receive_bump", transfer_impulse, 0.0)

	# 3. Head-On / Angled Front Contact (normal.z < -0.25)
	elif normal.z < -0.25:
		current_speed = maxf(current_speed * 0.70, 4.0)
		if is_instance_valid(chassis_pivot):
			chassis_pivot.rotation.x = clampf(chassis_pivot.rotation.x + 0.05, -0.12, 0.12)

		if car_bump_cooldown_timer <= 0.0:
			car_bump_cooldown_timer = 0.22
			trigger_car_bump_fx(contact_pos, normal, intensity)
			if is_multiplayer_active():
				rpc_trigger_car_bump_fx.rpc(contact_pos, normal, intensity)


func trigger_car_bump_fx(global_pos: Vector3, normal: Vector3, intensity: float = 1.0) -> void:
	var local_pos := to_local(global_pos)
	local_pos.x = clampf(local_pos.x, -1.05, 1.05)
	local_pos.y = clampf(local_pos.y, 0.35, 1.1)
	local_pos.z = clampf(local_pos.z, -2.1, 2.1)

	var local_norm := (to_local(global_position + normal) - local_pos).normalized()
	var spray_dir := Vector3(local_norm.x * 0.7, 0.35, local_norm.z * 0.5 + 0.35).normalized()

	if is_instance_valid(car_contact_sparks):
		car_contact_sparks.position = local_pos
		car_contact_sparks.direction = spray_dir
		car_contact_sparks.restart()
		car_contact_sparks.emitting = true

	if is_instance_valid(car_contact_dust):
		car_contact_dust.position = local_pos
		car_contact_dust.direction = spray_dir
		car_contact_dust.restart()
		car_contact_dust.emitting = true

	if is_instance_valid(car_contact_flash):
		car_contact_flash.position = local_pos + local_norm * 0.15
		car_contact_flash.light_energy = 5.2 * clampf(intensity, 0.6, 1.6)

	_play_bump_sound(intensity)

	var cur_scene := get_tree().current_scene
	if cur_scene and cur_scene.has_method("trigger_car_bump_camera_shake"):
		cur_scene.call("trigger_car_bump_camera_shake", 0.26 * clampf(intensity, 0.6, 1.5))


@rpc("any_peer", "call_local", "unreliable")
func rpc_trigger_car_bump_fx(global_pos: Vector3, normal: Vector3, intensity: float) -> void:
	trigger_car_bump_fx(global_pos, normal, intensity)


func _play_bump_sound(intensity: float = 1.0) -> void:
	if not audio_playback:
		return
	var frames := audio_playback.get_frames_available()
	if frames == 0:
		return
	var burst_frames := mini(frames, int(22050.0 * 0.16))
	for f in range(burst_frames):
		var env := exp(-float(f) / (burst_frames * 0.26))
		var thud := sin(float(f) * 0.026) * 0.38
		var crunch := randf_range(-0.45, 0.45) * 0.42
		var sample := (thud + crunch) * env * clampf(intensity, 0.5, 1.4)
		audio_playback.push_frame(Vector2(sample, sample))


@rpc("any_peer", "call_local", "unreliable")
func rpc_receive_bump(impulse_z: float, impulse_x: float) -> void:
	receive_bump(impulse_z, impulse_x)


func receive_bump(impulse_z: float, impulse_x: float) -> void:
	if impulse_z > 0.0:
		# Front car gets jolted forward by rear impact (drafting bump / push)
		current_speed = minf(current_speed + impulse_z * 0.75, boost_speed)
		bump_impulse_z = clampf(bump_impulse_z + impulse_z * 0.35, 0.0, 4.5)
		if is_instance_valid(chassis_pivot):
			chassis_pivot.rotation.x = clampf(chassis_pivot.rotation.x + 0.045, -0.12, 0.12)
		var cur_scene := get_tree().current_scene
		if cur_scene and cur_scene.has_method("trigger_car_bump_camera_shake"):
			cur_scene.call("trigger_car_bump_camera_shake", 0.24)
	if absf(impulse_x) > 0.01:
		if impulse_x > 0.0:
			bump_impulse_x = maxf(bump_impulse_x, impulse_x)
		else:
			bump_impulse_x = minf(bump_impulse_x, impulse_x)
		if is_instance_valid(chassis_pivot):
			chassis_pivot.rotation.z = clampf(chassis_pivot.rotation.z + signf(impulse_x) * 0.04, -0.15, 0.15)
		var cur_scene := get_tree().current_scene
		if cur_scene and cur_scene.has_method("trigger_car_bump_camera_shake"):
			cur_scene.call("trigger_car_bump_camera_shake", 0.20)


# --- Boost Exhaust Flames, Underglow & Brake Tyre Smoke Visual FX ---
func _check_and_recover_stuck(delta: float, road_cx: float, road_cy: float, road_yaw: float, road_pitch: float) -> void:
	if is_parked_at_destination or input_brake > 0.1 or input_handbrake:
		stuck_check_timer = 0.0
		stuck_anchor_pos = global_position
		return

	if stuck_anchor_pos == Vector3.ZERO:
		stuck_anchor_pos = global_position
		return

	if global_position.distance_to(stuck_anchor_pos) > 1.8:
		stuck_check_timer = 0.0
		stuck_anchor_pos = global_position
		return

	stuck_check_timer += delta
	if stuck_check_timer >= 2.2:
		stuck_check_timer = 0.0
		global_position = Vector3(road_cx, road_cy + 0.12, global_position.z)
		rotation.y = road_yaw
		rotation.x = -road_pitch
		rotation.z = 0.0
		velocity = Vector3.ZERO
		current_steer_angle = 0.0
		current_speed = maxf(current_speed, 10.0)
		stuck_anchor_pos = global_position
		print("StoryCar: Unstuck recovery repositioned %s to road center (x=%.2f, z=%.2f)" % [name, road_cx, global_position.z])


func _update_boost_and_tyre_fx(delta: float, is_braking: bool = false) -> void:
	# 1. Boost Exhaust Flames & Underglow (Active on hold-to-boost for both perspectives)
	if is_instance_valid(boost_flame_l) and is_instance_valid(boost_flame_r):
		boost_flame_l.visible = is_boosting
		boost_flame_r.visible = is_boosting
		var in_l = boost_flame_l.get_meta("inner", null) as Node3D
		var in_r = boost_flame_r.get_meta("inner", null) as Node3D
		if in_l: in_l.visible = is_boosting
		if in_r: in_r.visible = is_boosting

		if is_boosting:
			var jitter := randf_range(0.85, 1.25)
			var jet_scale := Vector3(randf_range(0.9, 1.1), randf_range(0.9, 1.1), jitter)
			boost_flame_l.scale = jet_scale
			boost_flame_r.scale = jet_scale

	if is_instance_valid(boost_underglow):
		var target_energy: float = 4.2 if is_boosting else 0.0
		boost_underglow.light_energy = lerpf(boost_underglow.light_energy, target_energy, delta * 14.0)

	# 2. Rear Tyre Brake Smoke (Emits ONLY while actively braking at speed)
	var show_brake_smoke := is_braking and absf(current_speed) > 2.8
	if is_instance_valid(tyre_spray_l) and is_instance_valid(tyre_spray_r):
		tyre_spray_l.emitting = show_brake_smoke
		tyre_spray_r.emitting = show_brake_smoke
		if show_brake_smoke:
			var spd_ratio := clampf(absf(current_speed) / boost_speed, 0.0, 1.0)
			var vel_val := lerpf(2.2, 6.5, spd_ratio)
			tyre_spray_l.initial_velocity_min = vel_val * 0.7
			tyre_spray_l.initial_velocity_max = vel_val
			tyre_spray_r.initial_velocity_min = vel_val * 0.7
			tyre_spray_r.initial_velocity_max = vel_val


func _update_brake_lights(is_braking: bool) -> void:
	for glow in brake_glows:
		if glow is Light3D:
			glow.light_energy = 2.6 if is_braking else 0.9
		elif glow is MeshInstance3D and glow.material_override:
			var mat: StandardMaterial3D = glow.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 4.0 if is_braking else 1.8


func _handle_divider_collision(col: KinematicCollision3D, delta: float) -> void:
	var collider := col.get_collider()
	var normal := col.get_normal()
	var push_dir: float = signf(normal.x)
	var cur_scene := get_tree().current_scene
	var road_cx := 0.0
	var road_yaw := 0.0
	if cur_scene and cur_scene.has_method("_get_road_center_x"):
		road_cx = float(cur_scene.call("_get_road_center_x", global_position.z))
		var ahead_cx := float(cur_scene.call("_get_road_center_x", global_position.z - 6.0))
		road_yaw = -atan2(ahead_cx - road_cx, 6.0)
	if absf(normal.x) < 0.15:
		push_dir = signf(road_cx - global_position.x)
		if absf(push_dir) < 0.1:
			push_dir = 1.0

	var local_hit := to_local(col.get_position())
	if absf(local_hit.x) >= 0.15:
		divider_scrape_side = -1.0 if local_hit.x < 0.0 else 1.0
	else:
		var local_normal_x := to_local(global_position + normal).x
		divider_scrape_side = 1.0 if local_normal_x < 0.0 else -1.0

	divider_scrape_local_pos = Vector3(
		divider_scrape_side * 0.96,
		clampf(local_hit.y, 0.35, 0.74),
		clampf(local_hit.z, -1.95, 1.85)
	)
	divider_scrape_type = str(collider.get_meta("divider_type", "metal")) if collider else "metal"

	var spd_mag := absf(current_speed)
	if spd_mag > 1.2 or absf(velocity.x) > 1.5:
		divider_fx_timer = 0.22
		divider_scrape_intensity = clampf(maxf(spd_mag, absf(velocity.x) * 2.0) / 18.0, 0.35, 1.25)

	# Apply clean deflection impulse without directly modifying velocity.x
	var target_impulse := push_dir * clampf(3.2 + col.get_depth() * 8.0, 2.5, 5.0)
	if push_dir > 0.0:
		bump_impulse_x = maxf(bump_impulse_x, target_impulse)
	else:
		bump_impulse_x = minf(bump_impulse_x, target_impulse)

	rotation.y = lerp_angle(rotation.y, road_yaw, clampf(delta * 10.0, 0.0, 0.5))
	current_speed = maxf(current_speed * 0.96, 5.5)
	if is_instance_valid(chassis_pivot):
		chassis_pivot.rotation.z = clampf(chassis_pivot.rotation.z + push_dir * 0.05, -0.15, 0.15)


func _update_divider_fx(delta: float) -> void:
	var active_scrape := false
	var fx_pos := divider_scrape_local_pos
	var fx_side := divider_scrape_side

	if is_local_authority():
		if divider_fx_timer > 0.0:
			divider_fx_timer = maxf(0.0, divider_fx_timer - delta)
			active_scrape = true
		else:
			divider_scrape_intensity = move_toward(divider_scrape_intensity, 0.0, delta * 6.0)
	elif remote_is_scraping:
		active_scrape = true
		fx_side = remote_scrape_side
		fx_pos = Vector3(fx_side * 0.96, 0.52, remote_scrape_z)
		divider_scrape_intensity = clampf(absf(current_speed) / 18.0, 0.35, 1.0)

	if is_instance_valid(divider_sparks) and is_instance_valid(divider_dust):
		divider_sparks.position = fx_pos
		divider_dust.position = fx_pos
		var back_z := 1.0 if current_speed >= -0.5 else -1.0
		divider_sparks.direction = Vector3(fx_side * 0.35, 0.45, back_z)
		divider_dust.direction = Vector3(fx_side * 0.25, 0.35, back_z)

		var dust_tint := Color(0.75, 0.72, 0.68, 0.28)
		if divider_scrape_type == "wood":
			dust_tint = Color(0.66, 0.54, 0.40, 0.34)
		elif divider_scrape_type == "bridge":
			dust_tint = Color(0.84, 0.86, 0.88, 0.32)
		divider_dust.color = dust_tint

		divider_sparks.emitting = active_scrape
		divider_dust.emitting = active_scrape

	if is_instance_valid(divider_spark_flash):
		divider_spark_flash.position = fx_pos + Vector3(fx_side * 0.18, 0.0, 0.0)
		if active_scrape:
			divider_spark_flash.light_energy = randf_range(2.6, 5.8) * clampf(divider_scrape_intensity, 0.5, 1.3)
		else:
			divider_spark_flash.light_energy = move_toward(divider_spark_flash.light_energy, 0.0, delta * 28.0)


# --- Setup Visual 3D Meshes & Materials ---
func _setup_collision() -> void:
	# 1. Floor Ground Capsule: Rounded cylindrical keel with hemispherical ends
	# Glides over road segment seams, bridge crests, and slopes with 0 catching
	var floor_col := CollisionShape3D.new()
	floor_col.name = "FloorCol"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 3.0
	floor_col.shape = cap
	floor_col.rotation_degrees.x = 90.0
	floor_col.position.y = 0.32
	add_child(floor_col)

	# 2. Unified Car Body Box (Front bumper, cabin, sides, and rear bumper in one clean hull)
	# Elevated 0.46m above road level so it NEVER touches asphalt or road segment seams.
	# Exactly one contact manifold when colliding with other cars or dividers, eliminating solver chatter.
	var body_col := CollisionShape3D.new()
	body_col.name = "BodyCol"
	var box := BoxShape3D.new()
	box.size = Vector3(1.76, 0.52, 4.10)
	body_col.shape = box
	body_col.position = Vector3(0.0, 0.72, 0.0)
	add_child(body_col)

	add_to_group("story_cars")

	# Smooth road adhesion on slopes without sticking or bouncing
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(65.0)
	floor_stop_on_slope = false
	floor_constant_speed = true


func _setup_visuals() -> void:
	if not is_instance_valid(chassis_pivot):
		chassis_pivot = Node3D.new()
		chassis_pivot.name = "ChassisPivot"
		add_child(chassis_pivot)

	car_layer_mask = 1 << clampi(car_layer_index, 1, 10)
	var other_lights_mask: int = 0xFFFFF & ~car_layer_mask

	_setup_collision_particles(other_lights_mask)
	_build_car_model(character_name)


func _setup_collision_particles(other_lights_mask: int) -> void:
	if is_instance_valid(divider_sparks):
		return

	# Side Divider Collision FX (Velocity-Aligned Spark Streaks, Dust & Flickering Contact Flash)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.vertex_color_use_as_albedo = true

	var spk_streak := BoxMesh.new()
	spk_streak.size = Vector3(0.042, 0.48, 0.042)
	spk_streak.material = spark_mat

	var spark_ramp := Gradient.new()
	spark_ramp.colors = PackedColorArray([Color(1.0, 0.98, 0.75, 1.0), Color(1.0, 0.62, 0.12, 0.95), Color(0.95, 0.25, 0.02, 0.0)])
	spark_ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])

	divider_sparks = CPUParticles3D.new()
	divider_sparks.mesh = spk_streak
	divider_sparks.amount = 64
	divider_sparks.lifetime = 0.45
	divider_sparks.particle_flag_align_y = true
	divider_sparks.direction = Vector3(-0.35, 0.55, 1.0)
	divider_sparks.spread = 36.0
	divider_sparks.gravity = Vector3(0.0, -18.0, 0.0)
	divider_sparks.initial_velocity_min = 7.0
	divider_sparks.initial_velocity_max = 17.5
	divider_sparks.scale_amount_min = 0.5
	divider_sparks.scale_amount_max = 1.35
	divider_sparks.color_ramp = spark_ramp
	divider_sparks.emitting = false
	add_child(divider_sparks)

	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.vertex_color_use_as_albedo = true
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust_mat.albedo_texture = _create_radial_particle_tex(
		PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.0)]),
		PackedFloat32Array([0.0, 0.45, 1.0])
	)

	var dust_quad := QuadMesh.new()
	dust_quad.size = Vector2(0.28, 0.28)
	dust_quad.material = dust_mat

	divider_dust = CPUParticles3D.new()
	divider_dust.mesh = dust_quad
	divider_dust.amount = 18
	divider_dust.lifetime = 0.42
	divider_dust.direction = Vector3(-0.25, 0.35, 1.0)
	divider_dust.spread = 26.0
	divider_dust.gravity = Vector3(0.0, -1.5, 0.0)
	divider_dust.initial_velocity_min = 2.0
	divider_dust.initial_velocity_max = 5.5
	divider_dust.scale_amount_min = 0.45
	divider_dust.scale_amount_max = 1.05
	divider_dust.color = Color(0.75, 0.72, 0.68, 0.28)
	divider_dust.emitting = false
	add_child(divider_dust)

	divider_spark_flash = OmniLight3D.new()
	divider_spark_flash.light_color = Color(1.0, 0.60, 0.14)
	divider_spark_flash.light_energy = 0.0
	divider_spark_flash.omni_range = 4.5
	divider_spark_flash.light_cull_mask = other_lights_mask
	add_child(divider_spark_flash)

	# Car-to-Car Physical Impact FX
	var car_spk_mat := StandardMaterial3D.new()
	car_spk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	car_spk_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	car_spk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	car_spk_mat.vertex_color_use_as_albedo = true

	var car_spk_mesh := BoxMesh.new()
	car_spk_mesh.size = Vector3(0.045, 0.40, 0.045)
	car_spk_mesh.material = car_spk_mat

	var car_spk_ramp := Gradient.new()
	car_spk_ramp.colors = PackedColorArray([Color(1.0, 0.98, 0.75, 1.0), Color(1.0, 0.60, 0.12, 0.95), Color(0.92, 0.20, 0.02, 0.0)])
	car_spk_ramp.offsets = PackedFloat32Array([0.0, 0.40, 1.0])

	car_contact_sparks = CPUParticles3D.new()
	car_contact_sparks.name = "CarContactSparks"
	car_contact_sparks.mesh = car_spk_mesh
	car_contact_sparks.amount = 45
	car_contact_sparks.lifetime = 0.42
	car_contact_sparks.one_shot = true
	car_contact_sparks.explosiveness = 0.92
	car_contact_sparks.particle_flag_align_y = true
	car_contact_sparks.direction = Vector3(0.0, 0.5, 1.0)
	car_contact_sparks.spread = 60.0
	car_contact_sparks.gravity = Vector3(0.0, -17.0, 0.0)
	car_contact_sparks.initial_velocity_min = 8.5
	car_contact_sparks.initial_velocity_max = 19.0
	car_contact_sparks.scale_amount_min = 0.55
	car_contact_sparks.scale_amount_max = 1.35
	car_contact_sparks.color_ramp = car_spk_ramp
	car_contact_sparks.emitting = false
	add_child(car_contact_sparks)

	car_contact_flash = OmniLight3D.new()
	car_contact_flash.name = "CarContactFlash"
	car_contact_flash.light_color = Color(1.0, 0.72, 0.22)
	car_contact_flash.light_energy = 0.0
	car_contact_flash.omni_range = 5.5
	car_contact_flash.light_cull_mask = other_lights_mask
	add_child(car_contact_flash)

	car_contact_dust = CPUParticles3D.new()
	car_contact_dust.name = "CarContactDust"
	car_contact_dust.mesh = dust_quad
	car_contact_dust.amount = 16
	car_contact_dust.lifetime = 0.36
	car_contact_dust.one_shot = true
	car_contact_dust.explosiveness = 0.88
	car_contact_dust.direction = Vector3(0.0, 0.4, 1.0)
	car_contact_dust.spread = 45.0
	car_contact_dust.gravity = Vector3(0.0, -1.8, 0.0)
	car_contact_dust.initial_velocity_min = 2.2
	car_contact_dust.initial_velocity_max = 5.2
	car_contact_dust.scale_amount_min = 0.5
	car_contact_dust.scale_amount_max = 1.15
	car_contact_dust.color = Color(0.80, 0.78, 0.75, 0.32)
	car_contact_dust.emitting = false
	add_child(car_contact_dust)


func _create_license_plate(plate_no: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var plate_root := Node3D.new()
	plate_root.name = "LicensePlate"
	plate_root.position = pos
	plate_root.rotation_degrees = rot_deg

	# Malaysian black license plate plate
	var plate_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.48, 0.15, 0.02)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.08, 0.08, 0.09)
	plate_mat.roughness = 0.75
	plate_mesh.mesh = box
	plate_mesh.material_override = plate_mat
	plate_root.add_child(plate_mesh)

	# Embossed white registration characters
	var lbl := Label3D.new()
	lbl.text = plate_no
	lbl.font_size = 28
	lbl.outline_size = 3
	lbl.modulate = Color(0.96, 0.96, 0.96)
	lbl.outline_modulate = Color(0.05, 0.05, 0.05)
	lbl.position = Vector3(0.0, 0.0, 0.012)
	plate_root.add_child(lbl)

	return plate_root


func _build_car_model(char_name: String) -> void:
	if not is_instance_valid(chassis_pivot):
		chassis_pivot = Node3D.new()
		chassis_pivot.name = "ChassisPivot"
		add_child(chassis_pivot)

	# Clean previous visual meshes from chassis pivot
	for child in chassis_pivot.get_children():
		child.queue_free()

	wheel_spins.clear()
	headlights.clear()
	brake_glows.clear()
	wheel_fl_mount = null
	wheel_fr_mount = null
	wheel_rl_mount = null
	wheel_rr_mount = null
	steering_wheel_pivot = null
	driver_torso = null
	driver_head = null
	boost_flame_l = null
	boost_flame_r = null
	boost_underglow = null
	tyre_spray_l = null
	tyre_spray_r = null
	name_tag = null

	var other_lights_mask: int = 0xFFFFF & ~car_layer_mask
	var resolved_char := char_name
	if resolved_char.is_empty() or resolved_char == "random":
		resolved_char = "Syazril"

	# Shared Base Materials
	var paint_mat := StandardMaterial3D.new()
	var rim_mat := StandardMaterial3D.new()
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.08, 0.08, 0.09)
	trim_mat.roughness = 0.70

	var chrome_mat := StandardMaterial3D.new()
	chrome_mat.albedo_color = Color(0.90, 0.92, 0.94)
	chrome_mat.metallic = 0.95
	chrome_mat.roughness = 0.15

	var gloss_black_mat := StandardMaterial3D.new()
	gloss_black_mat.albedo_color = Color(0.04, 0.04, 0.05)
	gloss_black_mat.metallic = 0.20
	gloss_black_mat.roughness = 0.10

	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.06, 0.09, 0.13, 0.75)
	glass_mat.metallic = 0.0
	glass_mat.roughness = 0.45
	glass_mat.metallic_specular = 0.12

	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.05, 0.05, 0.05)
	tire_mat.roughness = 0.90

	# Authentic Malaysian Vehicle Specifications per Character
	var body_size := Vector3(1.74, 0.54, 3.90)
	var cabin_size := Vector3(1.46, 0.52, 2.05)
	var cabin_pos := Vector3(0.0, 1.08, 0.25)
	var ws_pos := Vector3(0.0, 1.02, -0.78)
	var ws_rot_x := -26.0
	var rg_pos := Vector3(0.0, 1.04, 1.28)
	var rg_rot_x := 26.0
	var sw_len := 1.75
	var track_x := 0.82
	var front_z := -1.18
	var rear_z := 1.25

	var driver_shirt_col := Color(0.10, 0.18, 0.32)
	var license_plate_no := "WYY 8832"

	# Exhaust Placement: Vector3(x, y, z)
	var exhaust_positions: Array[Vector3] = [Vector3(-0.06, 0.28, 1.95), Vector3(0.06, 0.28, 1.95)]

	match resolved_char:
		"Syazril":
			# Proton Satria Neo (Gunmetal Metallic Dark Grey, 3-door sport hatchback)
			paint_mat.albedo_color = Color(0.22, 0.23, 0.25)
			paint_mat.metallic = 0.45
			paint_mat.roughness = 0.42
			rim_mat.albedo_color = Color(0.48, 0.48, 0.46)
			rim_mat.metallic = 0.65
			rim_mat.roughness = 0.35
			driver_shirt_col = Color(0.10, 0.18, 0.32) # Syazril navy tee
			license_plate_no = "WYY 8832"
			body_size = Vector3(1.74, 0.54, 3.90)
			cabin_size = Vector3(1.46, 0.52, 2.05)
			cabin_pos = Vector3(0.0, 1.08, 0.25)
			ws_pos = Vector3(0.0, 1.02, -0.78)
			ws_rot_x = -26.0
			rg_pos = Vector3(0.0, 1.04, 1.28)
			rg_rot_x = 26.0
			sw_len = 1.72
			track_x = 0.82
			front_z = -1.18
			rear_z = 1.25
			# Center-mounted exhaust
			exhaust_positions = [Vector3(-0.05, 0.28, body_size.z * 0.5), Vector3(0.05, 0.28, body_size.z * 0.5)]

		"Syahirul":
			# Proton Inspira 2.0 (Solid White, 4-door sports sedan)
			paint_mat.albedo_color = Color(0.92, 0.93, 0.94)
			paint_mat.metallic = 0.15
			paint_mat.roughness = 0.38
			rim_mat.albedo_color = Color(0.78, 0.80, 0.82)
			rim_mat.metallic = 0.75
			rim_mat.roughness = 0.30
			driver_shirt_col = Color(0.45, 0.10, 0.10) # Syahirul crimson shirt
			license_plate_no = "KDK 4821"
			body_size = Vector3(1.78, 0.58, 4.56)
			cabin_size = Vector3(1.50, 0.54, 2.15)
			cabin_pos = Vector3(0.0, 1.12, 0.05)
			ws_pos = Vector3(0.0, 1.06, -1.04)
			ws_rot_x = -24.0
			rg_pos = Vector3(0.0, 1.06, 1.14)
			rg_rot_x = 24.0
			sw_len = 1.88
			track_x = 0.85
			front_z = -1.35
			rear_z = 1.30
			# Right-side sports exhaust
			exhaust_positions = [Vector3(0.46, 0.30, body_size.z * 0.5), Vector3(0.54, 0.30, body_size.z * 0.5)]

		"Aleysa":
			# Perodua Axia Rahmah (Midnight Black, compact 5-door city hatchback)
			paint_mat.albedo_color = Color(0.06, 0.06, 0.07)
			paint_mat.metallic = 0.12
			paint_mat.roughness = 0.48
			rim_mat.albedo_color = Color(0.55, 0.56, 0.58)
			rim_mat.metallic = 0.30
			rim_mat.roughness = 0.55
			driver_shirt_col = Color(0.55, 0.48, 0.72) # Aleysa lavender top
			license_plate_no = "VBG 1904"
			body_size = Vector3(1.62, 0.58, 3.64)
			cabin_size = Vector3(1.40, 0.62, 2.15)
			cabin_pos = Vector3(0.0, 1.18, 0.18)
			ws_pos = Vector3(0.0, 1.12, -0.90)
			ws_rot_x = -20.0
			rg_pos = Vector3(0.0, 1.12, 1.25)
			rg_rot_x = 8.0 # Near-vertical flat rear hatch
			sw_len = 1.82
			track_x = 0.73 # Narrow track - wheels tucked neatly under body!
			front_z = -1.10
			rear_z = 1.15
			# Left-side discreet exhaust
			exhaust_positions = [Vector3(-0.48, 0.24, body_size.z * 0.5 - 0.04), Vector3(-0.44, 0.24, body_size.z * 0.5 - 0.04)]

		"Amelya":
			# Honda City Hatchback (Taffeta White, sleek aerodynamic hatchback)
			paint_mat.albedo_color = Color(0.95, 0.95, 0.96)
			paint_mat.metallic = 0.18
			paint_mat.roughness = 0.36
			rim_mat.albedo_color = Color(0.72, 0.74, 0.76)
			rim_mat.metallic = 0.70
			rim_mat.roughness = 0.32
			driver_shirt_col = Color(0.28, 0.42, 0.32) # Amelya sage blouse
			license_plate_no = "DCS 7712"
			body_size = Vector3(1.75, 0.56, 4.34)
			cabin_size = Vector3(1.48, 0.54, 2.30)
			cabin_pos = Vector3(0.0, 1.12, 0.22)
			ws_pos = Vector3(0.0, 1.06, -0.96)
			ws_rot_x = -28.0
			rg_pos = Vector3(0.0, 1.06, 1.38)
			rg_rot_x = 30.0
			sw_len = 1.98
			track_x = 0.83
			front_z = -1.28
			rear_z = 1.28
			# Right-side sports oval exhaust
			exhaust_positions = [Vector3(0.44, 0.28, body_size.z * 0.5), Vector3(0.52, 0.28, body_size.z * 0.5)]

	# 1. Main Car Lower Chassis Body
	var body_mesh := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = body_size
	b_box.material = paint_mat
	body_mesh.mesh = b_box
	body_mesh.position.y = 0.56
	chassis_pivot.add_child(body_mesh)

	# 2. Cabin Structure
	var cabin := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = cabin_size
	c_box.material = paint_mat
	cabin.mesh = c_box
	cabin.position = cabin_pos
	chassis_pivot.add_child(cabin)

	# 3. Model-Specific Authentic Exterior Features
	match resolved_char:
		"Syazril":
			# Satria Neo: Flared sports wheel arches
			for arch_side in [-track_x - 0.03, track_x + 0.03]:
				for arch_z in [front_z, rear_z]:
					var arch := MeshInstance3D.new()
					var a_box := BoxMesh.new()
					a_box.size = Vector3(0.07, 0.24, 0.62)
					a_box.material = paint_mat
					arch.mesh = a_box
					arch.position = Vector3(arch_side, 0.44, arch_z)
					chassis_pivot.add_child(arch)

			# Front Lotus air dam / lower bumper splitter
			var splitter := MeshInstance3D.new()
			var sp_box := BoxMesh.new()
			sp_box.size = Vector3(body_size.x * 0.98, 0.12, 0.36)
			sp_box.material = trim_mat
			splitter.mesh = sp_box
			splitter.position = Vector3(0.0, 0.24, -body_size.z * 0.5 + 0.12)
			chassis_pivot.add_child(splitter)

			# Aerodynamic Tailgate Roof Spoiler
			var spoiler := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(cabin_size.x * 0.94, 0.08, 0.28)
			s_box.material = paint_mat
			spoiler.mesh = s_box
			spoiler.position = Vector3(0.0, cabin_pos.y + cabin_size.y * 0.5 + 0.03, cabin_pos.z + cabin_size.z * 0.5 - 0.06)
			chassis_pivot.add_child(spoiler)

		"Syahirul":
			# Inspira Sedan: Protruding stepped rear boot / trunk deck
			var trunk_deck := MeshInstance3D.new()
			var td_box := BoxMesh.new()
			td_box.size = Vector3(body_size.x * 0.94, 0.26, 0.88)
			td_box.material = paint_mat
			trunk_deck.mesh = td_box
			trunk_deck.position = Vector3(0.0, 0.74, cabin_pos.z + cabin_size.z * 0.5 + 0.44)
			chassis_pivot.add_child(trunk_deck)

			# Integrated aerodynamic trunk ducktail lip spoiler
			var lip := MeshInstance3D.new()
			var l_box := BoxMesh.new()
			l_box.size = Vector3(body_size.x * 0.88, 0.06, 0.14)
			l_box.material = paint_mat
			lip.mesh = l_box
			lip.position = Vector3(0.0, 0.89, body_size.z * 0.5 - 0.04)
			chassis_pivot.add_child(lip)

			# Shark-nose inverted front grille with chrome frame
			var grille := MeshInstance3D.new()
			var g_box := BoxMesh.new()
			g_box.size = Vector3(1.18, 0.28, 0.08)
			g_box.material = trim_mat
			grille.mesh = g_box
			grille.position = Vector3(0.0, 0.50, -body_size.z * 0.5 - 0.02)
			grille.rotation_degrees.x = -8.0
			chassis_pivot.add_child(grille)

			var frame := MeshInstance3D.new()
			var fr_box := BoxMesh.new()
			fr_box.size = Vector3(1.22, 0.30, 0.03)
			fr_box.material = chrome_mat
			frame.mesh = fr_box
			frame.position = Vector3(0.0, 0.50, -body_size.z * 0.5 - 0.01)
			frame.rotation_degrees.x = -8.0
			chassis_pivot.add_child(frame)

		"Aleysa":
			# Axia City Car: Front Chrome smile grille bar
			var smile := MeshInstance3D.new()
			var sm_box := BoxMesh.new()
			sm_box.size = Vector3(0.85, 0.06, 0.04)
			sm_box.material = chrome_mat
			smile.mesh = sm_box
			smile.position = Vector3(0.0, 0.64, -body_size.z * 0.5 - 0.01)
			chassis_pivot.add_child(smile)

			var lower_intake := MeshInstance3D.new()
			var li_box := BoxMesh.new()
			li_box.size = Vector3(1.05, 0.18, 0.06)
			li_box.material = trim_mat
			lower_intake.mesh = li_box
			lower_intake.position = Vector3(0.0, 0.38, -body_size.z * 0.5 - 0.01)
			chassis_pivot.add_child(lower_intake)

		"Amelya":
			# Honda City Hatchback: Honda Solid Wing Face (Gloss-Black Bar + Chrome 'H')
			var wing := MeshInstance3D.new()
			var w_box := BoxMesh.new()
			w_box.size = Vector3(1.25, 0.12, 0.06)
			wing.material_override = gloss_black_mat
			wing.mesh = w_box
			wing.position = Vector3(0.0, 0.65, -body_size.z * 0.5 - 0.01)
			chassis_pivot.add_child(wing)

			var emblem := MeshInstance3D.new()
			var e_box := BoxMesh.new()
			e_box.size = Vector3(0.12, 0.10, 0.02)
			emblem.material_override = chrome_mat
			emblem.mesh = e_box
			emblem.position = Vector3(0.0, 0.65, -body_size.z * 0.5 - 0.04)
			chassis_pivot.add_child(emblem)

			# Sweeping roof spoiler
			var roof_sp := MeshInstance3D.new()
			var rsp_box := BoxMesh.new()
			rsp_box.size = Vector3(cabin_size.x * 0.94, 0.08, 0.32)
			roof_sp.material_override = gloss_black_mat
			roof_sp.mesh = rsp_box
			roof_sp.position = Vector3(0.0, cabin_pos.y + cabin_size.y * 0.5 + 0.04, cabin_pos.z + cabin_size.z * 0.5 - 0.04)
			chassis_pivot.add_child(roof_sp)

			# Roof-mounted Shark-Fin Antenna
			var fin := MeshInstance3D.new()
			var fin_box := BoxMesh.new()
			fin_box.size = Vector3(0.06, 0.10, 0.20)
			fin.material_override = gloss_black_mat
			fin.mesh = fin_box
			fin.position = Vector3(0.0, cabin_pos.y + cabin_size.y * 0.5 + 0.05, cabin_pos.z + 0.35)
			chassis_pivot.add_child(fin)

	# 4. Open Rear Trunk Lid + Boot Interior Light (Resort Chalet Luggage Interaction)
	if trunk_open:
		var trunk_hinge := Node3D.new()
		trunk_hinge.name = "TrunkHinge"
		var is_sedan := (resolved_char == "Syahirul")
		var hinge_y := 0.88 if is_sedan else (cabin_pos.y + cabin_size.y * 0.45)
		var hinge_z := (cabin_pos.z + cabin_size.z * 0.5 + 0.06) if is_sedan else (cabin_pos.z + cabin_size.z * 0.42)
		trunk_hinge.position = Vector3(0.0, hinge_y, hinge_z)
		trunk_hinge.rotation_degrees.x = 62.0 if is_sedan else 58.0
		chassis_pivot.add_child(trunk_hinge)

		var lid := MeshInstance3D.new()
		var lid_box := BoxMesh.new()
		var lid_len := (body_size.z * 0.5 - hinge_z) + 0.06
		lid_box.size = Vector3(cabin_size.x * 0.92, 0.08, maxf(0.65, lid_len))
		lid_box.material = paint_mat
		lid.mesh = lid_box
		lid.position = Vector3(0.0, 0.0, maxf(0.65, lid_len) * 0.5)
		trunk_hinge.add_child(lid)

		var boot_floor := MeshInstance3D.new()
		var bf_box := BoxMesh.new()
		bf_box.size = Vector3(1.28, 0.06, 0.82)
		bf_box.material = trim_mat
		boot_floor.mesh = bf_box
		boot_floor.position = Vector3(0.0, 0.62, body_size.z * 0.5 - 0.42)
		chassis_pivot.add_child(boot_floor)

		var boot_light := OmniLight3D.new()
		boot_light.light_color = Color(1.0, 0.9, 0.65)
		boot_light.light_energy = 1.6
		boot_light.omni_range = 3.2
		boot_light.light_cull_mask = other_lights_mask
		boot_light.position = Vector3(0.0, 1.05, body_size.z * 0.5 - 0.15)
		chassis_pivot.add_child(boot_light)

	# 5. Windshield & Windows
	var windshield := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(cabin_size.x - 0.04, 0.48, 0.08)
	w_box.material = glass_mat
	windshield.mesh = w_box
	windshield.position = ws_pos
	windshield.rotation_degrees.x = ws_rot_x
	chassis_pivot.add_child(windshield)

	var rear_glass := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(cabin_size.x - 0.04, 0.45, 0.08)
	r_box.material = glass_mat
	rear_glass.mesh = r_box
	rear_glass.position = rg_pos
	rear_glass.rotation_degrees.x = rg_rot_x
	chassis_pivot.add_child(rear_glass)

	# Side Windows
	for s_side in [-cabin_size.x * 0.5 + 0.01, cabin_size.x * 0.5 - 0.01]:
		var side_win := MeshInstance3D.new()
		var sw_box := BoxMesh.new()
		sw_box.size = Vector3(0.04, 0.44, sw_len)
		sw_box.material = glass_mat
		side_win.mesh = sw_box
		side_win.position = Vector3(s_side, cabin_pos.y - 0.04, cabin_pos.z)
		chassis_pivot.add_child(side_win)

	# 6. Right-Hand Drive (RHD) Malaysian Cockpit
	var dash := MeshInstance3D.new()
	var d_box := BoxMesh.new()
	d_box.size = Vector3(1.42, 0.24, 0.42)
	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.08, 0.08, 0.1)
	dash_mat.roughness = 0.85
	dash.mesh = d_box
	dash.material_override = dash_mat
	dash.position = Vector3(0.0, 0.88, -0.42)
	chassis_pivot.add_child(dash)

	# RHD Glowing Instrument Cluster (+X = 0.38)
	var cluster := MeshInstance3D.new()
	var cl_box := BoxMesh.new()
	cl_box.size = Vector3(0.36, 0.16, 0.04)
	var cluster_mat := StandardMaterial3D.new()
	cluster_mat.albedo_color = Color(0.05, 0.12, 0.18)
	cluster_mat.emission_enabled = true
	cluster_mat.emission = Color(0.14, 0.55, 0.72)
	cluster_mat.emission_energy_multiplier = 0.65
	cluster.mesh = cl_box
	cluster.material_override = cluster_mat
	cluster.position = Vector3(0.38, 0.90, -0.40)
	cluster.rotation_degrees.x = -18.0
	chassis_pivot.add_child(cluster)

	# RHD Steering Column & Steering Wheel (+X = 0.38)
	var steering_column := Node3D.new()
	steering_column.position = Vector3(0.38, 0.94, -0.30)
	steering_column.rotation_degrees.x = 22.0
	chassis_pivot.add_child(steering_column)

	steering_wheel_pivot = Node3D.new()
	steering_column.add_child(steering_wheel_pivot)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.18
	var wheel_rim := MeshInstance3D.new()
	wheel_rim.mesh = torus
	wheel_rim.material_override = dash_mat
	wheel_rim.rotation_degrees.x = 90.0
	steering_wheel_pivot.add_child(wheel_rim)

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.05
	cap_mesh.bottom_radius = 0.05
	cap_mesh.height = 0.04
	var center_cap := MeshInstance3D.new()
	center_cap.mesh = cap_mesh
	center_cap.material_override = dash_mat
	center_cap.rotation_degrees.x = 90.0
	steering_wheel_pivot.add_child(center_cap)

	# Seats Material
	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = Color(0.12, 0.13, 0.15)
	seat_mat.roughness = 0.85

	var sb_mesh := BoxMesh.new()
	sb_mesh.size = Vector3(0.46, 0.16, 0.48)
	var sback_mesh := BoxMesh.new()
	sback_mesh.size = Vector3(0.44, 0.52, 0.12)
	var hr_mesh := BoxMesh.new()
	hr_mesh.size = Vector3(0.22, 0.15, 0.08)

	# Driver Seat (+X = 0.38)
	var driver_seat := Node3D.new()
	driver_seat.position = Vector3(0.38, 0.58, 0.04)
	chassis_pivot.add_child(driver_seat)

	var d_base := MeshInstance3D.new()
	d_base.mesh = sb_mesh
	d_base.material_override = seat_mat
	d_base.position.y = 0.08
	driver_seat.add_child(d_base)

	var d_back := MeshInstance3D.new()
	d_back.mesh = sback_mesh
	d_back.material_override = seat_mat
	d_back.position = Vector3(0.0, 0.38, 0.2)
	d_back.rotation_degrees.x = 8.0
	driver_seat.add_child(d_back)

	var d_hr := MeshInstance3D.new()
	d_hr.mesh = hr_mesh
	d_hr.material_override = seat_mat
	d_hr.position = Vector3(0.0, 0.68, 0.24)
	driver_seat.add_child(d_hr)

	# Driver Model (Torso & Head with Character-Specific Shirt Color)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = driver_shirt_col
	var torso := MeshInstance3D.new()
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(0.36, 0.42, 0.2)
	torso.mesh = t_mesh
	torso.material_override = body_mat
	torso.position = Vector3(0.0, 0.38, 0.08)
	driver_seat.add_child(torso)
	driver_torso = torso
	torso_rest_rot = Vector3.ZERO

	var head := MeshInstance3D.new()
	var h_mesh := SphereMesh.new()
	h_mesh.radius = 0.11
	h_mesh.height = 0.22
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.65, 0.52, 0.42)
	head.mesh = h_mesh
	head.material_override = head_mat
	head.position = Vector3(0.0, 0.68, 0.1)
	driver_seat.add_child(head)
	driver_head = head
	head_rest_rot = head.rotation

	# Passenger Seat (-X = -0.38)
	var pass_seat := Node3D.new()
	pass_seat.position = Vector3(-0.38, 0.58, 0.04)
	chassis_pivot.add_child(pass_seat)

	var p_base := MeshInstance3D.new()
	p_base.mesh = sb_mesh
	p_base.material_override = seat_mat
	p_base.position.y = 0.08
	pass_seat.add_child(p_base)

	var p_back := MeshInstance3D.new()
	p_back.mesh = sback_mesh
	p_back.material_override = seat_mat
	p_back.position = Vector3(0.0, 0.38, 0.2)
	p_back.rotation_degrees.x = 8.0
	pass_seat.add_child(p_back)

	var p_hr := MeshInstance3D.new()
	p_hr.mesh = hr_mesh
	p_hr.material_override = seat_mat
	p_hr.position = Vector3(0.0, 0.68, 0.24)
	pass_seat.add_child(p_hr)

	# 7. Wheels & Suspension Mounts (Flush with Wheel Track per Model)
	wheel_fl_mount = _create_wheel_node(Vector3(-track_x, 0.34, front_z), tire_mat, rim_mat, true)
	wheel_fr_mount = _create_wheel_node(Vector3(track_x, 0.34, front_z), tire_mat, rim_mat, false)
	wheel_rl_mount = _create_wheel_node(Vector3(-track_x, 0.34, rear_z), tire_mat, rim_mat, true)
	wheel_rr_mount = _create_wheel_node(Vector3(track_x, 0.34, rear_z), tire_mat, rim_mat, false)

	chassis_pivot.add_child(wheel_fl_mount)
	chassis_pivot.add_child(wheel_fr_mount)
	chassis_pivot.add_child(wheel_rl_mount)
	chassis_pivot.add_child(wheel_rr_mount)

	wheel_spins.clear()
	for m in [wheel_fl_mount, wheel_fr_mount, wheel_rl_mount, wheel_rr_mount]:
		var sp := m.get_node_or_null("WheelSpin") as Node3D
		if sp:
			wheel_spins.append(sp)

	# 8. Front Headlights (SpotLights)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.98, 0.9)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.98, 0.9)
	bulb_mat.emission_energy_multiplier = 4.0

	var hl_spread_x := track_x - 0.16
	for h_side in [-hl_spread_x, hl_spread_x]:
		var bulb := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.12
		s_mesh.height = 0.24
		bulb.mesh = s_mesh
		bulb.material_override = bulb_mat
		bulb.position = Vector3(h_side, 0.62, -body_size.z * 0.5 - 0.01)
		chassis_pivot.add_child(bulb)

		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.96, 0.88)
		spot.light_energy = 8.5
		spot.spot_range = 75.0
		spot.spot_angle = 38.0
		spot.spot_attenuation = 0.7
		spot.shadow_enabled = true
		spot.position = Vector3(h_side, 0.62, -body_size.z * 0.5 - 0.03)
		spot.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		chassis_pivot.add_child(spot)
		headlights.append(spot)

	# Ground bounce light
	var bounce := OmniLight3D.new()
	bounce.light_color = Color(0.95, 0.92, 0.85)
	bounce.light_energy = 4.2
	bounce.omni_range = 14.0
	bounce.light_cull_mask = other_lights_mask
	bounce.position = Vector3(0.0, 0.42, -body_size.z * 0.5 - 2.2)
	chassis_pivot.add_child(bounce)

	# 9. Rear Taillights (Specific Styling per Vehicle)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.95, 0.08, 0.08)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(0.95, 0.08, 0.08)
	tail_mat.emission_energy_multiplier = 2.0

	if resolved_char == "Syazril":
		# Satria Neo circular twin-pod taillight clusters
		for t_side in [-0.58, 0.58]:
			for pod_dx in [-0.07, 0.07]:
				var pod_mesh := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.05
				cyl.bottom_radius = 0.05
				cyl.height = 0.03
				pod_mesh.mesh = cyl
				pod_mesh.material_override = tail_mat.duplicate()
				pod_mesh.rotation_degrees.x = 90.0
				pod_mesh.position = Vector3(t_side + pod_dx, 0.65, body_size.z * 0.5 + 0.01)
				chassis_pivot.add_child(pod_mesh)
				brake_glows.append(pod_mesh)

			var red_glow := OmniLight3D.new()
			red_glow.light_color = Color(0.95, 0.08, 0.08)
			red_glow.light_energy = 0.9
			red_glow.omni_range = 4.2
			red_glow.light_cull_mask = other_lights_mask
			red_glow.position = Vector3(t_side, 0.60, body_size.z * 0.5 + 0.22)
			chassis_pivot.add_child(red_glow)
			brake_glows.append(red_glow)

	elif resolved_char == "Aleysa":
		# Perodua Axia high-mounted vertical pillar taillights
		for t_side in [-track_x + 0.08, track_x - 0.08]:
			var pillar_light := MeshInstance3D.new()
			var p_box := BoxMesh.new()
			p_box.size = Vector3(0.07, 0.44, 0.04)
			pillar_light.mesh = p_box
			pillar_light.material_override = tail_mat.duplicate()
			pillar_light.position = Vector3(t_side, 1.02, body_size.z * 0.5 - 0.04)
			chassis_pivot.add_child(pillar_light)
			brake_glows.append(pillar_light)

			var red_glow := OmniLight3D.new()
			red_glow.light_color = Color(0.95, 0.08, 0.08)
			red_glow.light_energy = 0.9
			red_glow.omni_range = 4.2
			red_glow.light_cull_mask = other_lights_mask
			red_glow.position = Vector3(t_side, 0.85, body_size.z * 0.5 + 0.20)
			chassis_pivot.add_child(red_glow)
			brake_glows.append(red_glow)

	else:
		# Syahirul (Inspira) & Amelya (City Hatchback) Horizontal Taillights
		for t_side in [-track_x + 0.15, track_x - 0.15]:
			var tail_mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.28, 0.12, 0.04)
			tail_mesh.mesh = box
			tail_mesh.material_override = tail_mat.duplicate()
			tail_mesh.position = Vector3(t_side, 0.68, body_size.z * 0.5 + 0.01)
			chassis_pivot.add_child(tail_mesh)
			brake_glows.append(tail_mesh)

			var red_glow := OmniLight3D.new()
			red_glow.light_color = Color(0.95, 0.08, 0.08)
			red_glow.light_energy = 0.9
			red_glow.omni_range = 4.2
			red_glow.light_cull_mask = other_lights_mask
			red_glow.position = Vector3(t_side, 0.58, body_size.z * 0.5 + 0.22)
			chassis_pivot.add_child(red_glow)
			brake_glows.append(red_glow)

	# 10. Authentic Malaysian Registration Plates (Front Bumper & Rear Bumper)
	var front_plate := _create_license_plate(license_plate_no, Vector3(0.0, 0.40, -body_size.z * 0.5 - 0.02), Vector3(0.0, 180.0, 0.0))
	chassis_pivot.add_child(front_plate)

	var rear_plate := _create_license_plate(license_plate_no, Vector3(0.0, 0.48, body_size.z * 0.5 + 0.02), Vector3.ZERO)
	chassis_pivot.add_child(rear_plate)

	# 11. Exhaust Tips & Turbo Boost Flame Jets (Properly Aligned with Model Exhaust Outlets)
	var exhaust_mat := StandardMaterial3D.new()
	exhaust_mat.albedo_color = Color(0.2, 0.2, 0.22)
	exhaust_mat.metallic = 0.95
	exhaust_mat.roughness = 0.25

	var flame_outer_mat := StandardMaterial3D.new()
	flame_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_outer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_outer_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.85)

	var flame_inner_mat := StandardMaterial3D.new()
	flame_inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_inner_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_inner_mat.albedo_color = Color(1.0, 0.95, 0.65, 0.95)

	var flame_targets: Array[MeshInstance3D] = []
	for ex_pos in exhaust_positions:
		var tip := MeshInstance3D.new()
		var tip_cyl := CylinderMesh.new()
		tip_cyl.top_radius = 0.052
		tip_cyl.bottom_radius = 0.052
		tip_cyl.height = 0.12
		tip.mesh = tip_cyl
		tip.material_override = exhaust_mat
		tip.rotation_degrees.x = 90.0
		tip.position = ex_pos
		chassis_pivot.add_child(tip)

		var flame := MeshInstance3D.new()
		var f_cyl := CylinderMesh.new()
		f_cyl.top_radius = 0.012
		f_cyl.bottom_radius = 0.070
		f_cyl.height = 0.72
		flame.mesh = f_cyl
		flame.material_override = flame_outer_mat
		flame.rotation_degrees.x = 90.0
		flame.position = ex_pos + Vector3(0.0, 0.0, 0.38)
		flame.visible = false
		chassis_pivot.add_child(flame)

		var inner := MeshInstance3D.new()
		var in_cyl := CylinderMesh.new()
		in_cyl.top_radius = 0.006
		in_cyl.bottom_radius = 0.040
		in_cyl.height = 0.44
		inner.mesh = in_cyl
		inner.material_override = flame_inner_mat
		inner.rotation_degrees.x = 90.0
		inner.position = ex_pos + Vector3(0.0, 0.0, 0.24)
		inner.visible = false
		chassis_pivot.add_child(inner)

		flame.set_meta("inner", inner)
		flame_targets.append(flame)

	if flame_targets.size() >= 2:
		boost_flame_l = flame_targets[0]
		boost_flame_r = flame_targets[1]
	elif flame_targets.size() == 1:
		boost_flame_l = flame_targets[0]
		boost_flame_r = flame_targets[0]

	# Underbody Boost Road Light
	var boost_spot := SpotLight3D.new()
	boost_spot.light_color = Color(0.2, 0.85, 1.0)
	boost_spot.light_energy = 0.0
	boost_spot.spot_range = 4.8
	boost_spot.spot_angle = 65.0
	boost_spot.spot_attenuation = 1.1
	boost_spot.light_cull_mask = other_lights_mask
	boost_spot.position = Vector3(0.0, 0.25, rear_z + 0.35)
	boost_spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	chassis_pivot.add_child(boost_spot)
	boost_underglow = boost_spot

	# 12. Rear Tyre Road Spray / Mist Particle Emitters
	var spray_mat := StandardMaterial3D.new()
	spray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spray_mat.vertex_color_use_as_albedo = true
	spray_mat.albedo_color = Color(0.85, 0.90, 0.95, 0.35)
	spray_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spray_mat.albedo_texture = _create_radial_particle_tex(
		PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.0)]),
		PackedFloat32Array([0.0, 0.45, 1.0])
	)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = spray_mat

	tyre_spray_l = CPUParticles3D.new()
	tyre_spray_l.mesh = quad
	tyre_spray_l.amount = 32
	tyre_spray_l.lifetime = 0.36
	tyre_spray_l.direction = Vector3(0.0, 0.35, 1.0)
	tyre_spray_l.spread = 24.0
	tyre_spray_l.gravity = Vector3(0.0, -1.8, 0.0)
	tyre_spray_l.initial_velocity_min = 2.0
	tyre_spray_l.initial_velocity_max = 5.0
	tyre_spray_l.scale_amount_min = 0.6
	tyre_spray_l.scale_amount_max = 2.2
	tyre_spray_l.color = Color(0.85, 0.90, 0.95, 0.28)
	tyre_spray_l.position = Vector3(-track_x, 0.14, rear_z + 0.15)
	tyre_spray_l.emitting = false
	chassis_pivot.add_child(tyre_spray_l)

	tyre_spray_r = tyre_spray_l.duplicate() as CPUParticles3D
	tyre_spray_r.position = Vector3(track_x, 0.14, rear_z + 0.15)
	chassis_pivot.add_child(tyre_spray_r)

	# 13. Sibling Name Tag
	name_tag = Label3D.new()
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = true
	name_tag.font_size = 24
	var ai_badge := " [AI]" if is_ai else ""
	name_tag.text = "%s%s" % [sibling_name, ai_badge]
	name_tag.modulate = Color(0.4, 0.95, 0.6) if is_host else Color(0.85, 0.9, 0.98)
	name_tag.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	name_tag.outline_size = 6
	name_tag.position = Vector3(0.0, 2.05, 0.0)

	var net := get_node_or_null("/root/NetworkManager")
	if net:
		var show_tags: bool = bool(net.host_settings.get("show_name_tags", true))
		name_tag.visible = show_tags

	chassis_pivot.add_child(name_tag)

	# Assign Car Layer Mask to exclude self-illumination glare
	_set_car_meshes_layer(chassis_pivot, car_layer_mask)


func _create_radial_particle_tex(colors: PackedColorArray, offsets: PackedFloat32Array, tex_size: int = 32) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = colors
	grad.offsets = offsets
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = tex_size
	tex.height = tex_size
	return tex


func _set_car_meshes_layer(root: Node, layer_mask: int) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).layers = layer_mask
	for child in root.get_children():
		_set_car_meshes_layer(child, layer_mask)


func _create_wheel_node(w_pos: Vector3, tire_mat: Material, rim_mat: Material, is_left: bool) -> Node3D:
	# Mount: handles position offset and Y steering (Euler X and Z remain strictly 0)
	var mount := Node3D.new()
	mount.position = w_pos

	# Spin child: handles ONLY axle rolling (Euler X rotation) - eliminates sideways rotation
	var spin := Node3D.new()
	spin.name = "WheelSpin"
	mount.add_child(spin)

	# Rubber tire
	var tire := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.34
	cyl.height = 0.22
	cyl.material = tire_mat
	tire.mesh = cyl
	tire.rotation_degrees.z = 90.0
	spin.add_child(tire)

	# Silver rim hubcap
	var rim := MeshInstance3D.new()
	var rim_cyl := CylinderMesh.new()
	rim_cyl.top_radius = 0.22
	rim_cyl.bottom_radius = 0.22
	rim_cyl.height = 0.224
	rim_cyl.material = rim_mat
	rim.mesh = rim_cyl
	rim.rotation_degrees.z = 90.0
	spin.add_child(rim)

	# Spokes on the outward face
	var face_x: float = -0.113 if is_left else 0.113
	for s_deg in [0.0, 60.0, 120.0]:
		var spoke := MeshInstance3D.new()
		var sp_box := BoxMesh.new()
		sp_box.size = Vector3(0.012, 0.38, 0.04)
		sp_box.material = rim_mat
		spoke.mesh = sp_box
		spoke.position.x = face_x
		spoke.rotation_degrees.x = s_deg
		spin.add_child(spoke)

	return mount


# --- Procedural Engine Sound Synthesis ---
func _setup_audio() -> void:
	engine_audio = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	engine_audio.stream = gen
	engine_audio.volume_db = -2.0
	engine_audio.unit_size = 12.0
	engine_audio.max_distance = 65.0
	add_child(engine_audio)
	engine_audio.play()
	audio_playback = engine_audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _update_engine_audio(delta: float) -> void:
	if not audio_playback:
		return

	var frames_needed := audio_playback.get_frames_available()
	if frames_needed == 0:
		return

	var sample_rate := 22050.0

	# Normal engine sound + metallic divider scrape chatter
	var speed_ratio := clampf(absf(current_speed) / boost_speed, 0.0, 1.0)
	var max_rpm := 235.0 if is_boosting else 170.0
	var rpm_freq := lerpf(46.0, max_rpm, speed_ratio)
	var scrape_amt := clampf(divider_scrape_intensity, 0.0, 1.0) * 0.24 if divider_fx_timer > 0.0 else 0.0

	for f in range(frames_needed):
		var tone := sin(audio_phase * TAU) * 0.16 + sin(audio_phase * 2.0 * TAU) * 0.09
		if scrape_amt > 0.0:
			tone += randf_range(-scrape_amt, scrape_amt) + sin(audio_phase * 9.0 * TAU) * (scrape_amt * 0.45)
		audio_playback.push_frame(Vector2(tone, tone))
		audio_phase += rpm_freq / sample_rate
		if audio_phase >= 1.0:
			audio_phase -= 1.0


# --- Oncoming Impact Slowdown & Funny Bobblehead Jolt (No Engine Stall) ---

func trigger_crash(push_dir: float = 1.0) -> void:
	if impact_jolt_timer > 1.35:
		return
	if is_local_authority():
		rpc_sync_crash.rpc(push_dir)
	else:
		_apply_crash_state(push_dir)


@rpc("any_peer", "call_local", "reliable")
func rpc_sync_crash(push_dir: float) -> void:
	_apply_crash_state(push_dir)


func _apply_crash_state(push_dir: float) -> void:
	is_boosting = false
	impact_jolt_timer = 1.8
	crash_spin_timer = 0.85
	crash_spin_dir = 1.0 if push_dir >= 0.0 else -1.0

	# Heavy deceleration penalty + 360 spinout without stalling
	current_speed = clampf(current_speed * 0.28, 3.5, 6.5)
	velocity.x += push_dir * 4.5

	if is_instance_valid(chassis_pivot):
		chassis_pivot.rotation.x += 0.08
		chassis_pivot.rotation.z += push_dir * 0.09

	if is_instance_valid(boost_flame_l): boost_flame_l.visible = false
	if is_instance_valid(boost_flame_r): boost_flame_r.visible = false
	if is_instance_valid(boost_underglow): boost_underglow.light_energy = 0.0

	# Play heavy crash crunch burst into audio
	if audio_playback:
		var frames := audio_playback.get_frames_available()
		for f in range(frames):
			var crunch := randf_range(-0.6, 0.6) * exp(-float(f) / (frames * 0.35))
			audio_playback.push_frame(Vector2(crunch, crunch))

	car_crashed.emit(self)


func _update_bobblehead(delta: float) -> void:
	if not is_instance_valid(driver_torso) or not is_instance_valid(driver_head):
		return

	if impact_jolt_timer > 0.0:
		impact_jolt_timer = maxf(0.0, impact_jolt_timer - delta)
		var elapsed := 1.8 - impact_jolt_timer
		var decay := impact_jolt_timer / 1.8
		driver_torso.rotation.x = torso_rest_rot.x + sin(elapsed * 14.0) * decay * 0.32
		driver_head.rotation.x = sin(elapsed * 20.0) * decay * 0.52
		driver_head.rotation.z = cos(elapsed * 16.0) * decay * 0.42
	else:
		driver_torso.rotation.x = lerp_angle(driver_torso.rotation.x, torso_rest_rot.x, delta * 8.0)
		driver_head.rotation.x = lerp_angle(driver_head.rotation.x, head_rest_rot.x, delta * 8.0)
		driver_head.rotation.z = lerp_angle(driver_head.rotation.z, head_rest_rot.z, delta * 8.0)
