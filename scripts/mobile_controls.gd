class_name MobileControls
extends CanvasLayer

# --- Signals to Player ---
signal move_vector_changed(vec: Vector2)
signal look_dragged(relative: Vector2)
signal crouch_toggled(active: bool)
signal flashlight_pressed()
signal crank_pressed()
signal crank_held(active: bool)
signal interact_pressed()
signal drop_pressed()

# --- Config & Textures ---
@export var max_joystick_radius: float = 80.0
@export var deadzone: float = 0.08

const ICON_CREEP_STAND := preload("res://assets/ui/creep_stand_icon.png")
const ICON_CROUCH := preload("res://assets/ui/crouch_icon.png")

# --- UI Nodes ---
@onready var touch_root: Control = $TouchRoot
@onready var joystick_base: Panel = $TouchRoot/JoystickArea/Base
@onready var joystick_knob: Panel = $TouchRoot/JoystickArea/Base/Knob
@onready var joystick_area: Control = $TouchRoot/JoystickArea
@onready var look_area: Control = $TouchRoot/LookArea

@onready var crouch_button: Button = $TouchRoot/CrouchButton
@onready var settings_button: Button = $TouchRoot/SettingsButton
@onready var interact_button: Button = $TouchRoot/InteractButton
@onready var drop_button: Button = $TouchRoot/DropButton
@onready var flashlight_button: Button = $TouchRoot/FlashlightButton
@onready var crank_button: Button = $TouchRoot/CrankButton

# --- In-Game Options Modal ---
@onready var options_modal: Panel = $TouchRoot/OptionsModal
@onready var sens_vbox: VBoxContainer = $TouchRoot/OptionsModal/SensVBox
@onready var sens_slider: HSlider = $TouchRoot/OptionsModal/SensVBox/SensSlider
@onready var music_checkbox: CheckBox = $TouchRoot/OptionsModal/MusicVBox/MusicCheckBox
@onready var more_options_button: Button = $TouchRoot/OptionsModal/MoreOptionsButton
@onready var more_options_container: VBoxContainer = $TouchRoot/OptionsModal/MoreOptionsContainer
@onready var btn_size_smallest: Button = $TouchRoot/OptionsModal/MoreOptionsContainer/SizeHBox/BtnSmallest
@onready var btn_size_medium: Button = $TouchRoot/OptionsModal/MoreOptionsContainer/SizeHBox/BtnMedium
@onready var btn_size_large: Button = $TouchRoot/OptionsModal/MoreOptionsContainer/SizeHBox/BtnLarge
@onready var mic_thresh_val: Label = get_node_or_null("TouchRoot/OptionsModal/MoreOptionsContainer/MicVBox/MicThreshRow/MicThreshVal")
@onready var mic_thresh_slider: HSlider = get_node_or_null("TouchRoot/OptionsModal/MoreOptionsContainer/MicVBox/MicThreshSlider")
@onready var mic_sens_val: Label = get_node_or_null("TouchRoot/OptionsModal/MoreOptionsContainer/MicVBox/MicSensRow/MicSensVal")
@onready var mic_sens_slider: HSlider = get_node_or_null("TouchRoot/OptionsModal/MoreOptionsContainer/MicVBox/MicSensSlider")

# --- State ---
var player_ref: Node = null

var joystick_active: bool = false
var joystick_touch_id: int = -1
var joystick_center_pos: Vector2 = Vector2.ZERO
var move_vector: Vector2 = Vector2.ZERO

var look_active: bool = false
var look_touch_id: int = -1
var last_look_pos: Vector2 = Vector2.ZERO

var crouch_enabled: bool = false
var is_more_options_expanded: bool = false
var current_touch_size: String = "Smallest"


func _ready() -> void:
	_check_platform_visibility()
	_reset_joystick_visuals()
	update_crouch_ui(false)
	
	# Load Touch Size Preset from persistent settings
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net and net.get("local_settings") != null:
		current_touch_size = str(net.local_settings.get("touch_size", "Smallest"))
	apply_touch_size_preset(current_touch_size)

	if crank_button:
		crank_button.button_down.connect(_on_crank_button_down)
		crank_button.button_up.connect(_on_crank_button_up)


func _check_platform_visibility() -> void:
	var net: Node = get_node_or_null("/root/NetworkManager")
	var setting: String = "auto"
	if net and net.get("local_settings") != null:
		setting = str(net.local_settings.get("touch_controls", "auto"))

	if setting == "on":
		visible = true
	elif setting == "off":
		visible = false
	else:
		var is_mobile_os := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
		visible = is_mobile_os


func setup(player: Node) -> void:
	player_ref = player
	_check_platform_visibility()
	
	if crank_button and player:
		var f_mode := str(player.get("flashlight_mode"))
		crank_button.visible = (f_mode == "crank")


# --- Touch Size Presets ("Smallest", "Medium", "Large") ---

func apply_touch_size_preset(preset: String) -> void:
	current_touch_size = preset
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net and net.get("local_settings") != null:
		net.local_settings["touch_size"] = preset
		net.save_local_settings()
	
	match preset:
		"Medium":
			_apply_size_medium()
		"Large":
			_apply_size_large()
		_:
			_apply_size_smallest()
	
	_update_size_buttons_ui(preset)


func _apply_size_smallest() -> void:
	max_joystick_radius = 80.0
	_set_joystick_size(170.0, 72.0, 85, 36, 60.0, 60.0)
	_set_control_rect(crouch_button, Vector2(96, 136), 40.0, 26.0, 136.0, 162.0)
	_set_control_rect(settings_button, Vector2(64, 64), 155.0, 38.0, 219.0, 102.0)
	_set_control_rect(interact_button, Vector2(100, 100), -160.0, -50.0, -60.0, 50.0)
	if interact_button:
		interact_button.anchor_top = 0.30
		interact_button.anchor_bottom = 0.30
	_set_control_rect(drop_button, Vector2(160, 50), -80.0, -80.0, 80.0, -30.0)
	if drop_button:
		drop_button.add_theme_font_size_override("font_size", 28)
	_set_flashlight_size(96.0, 14, 48, -180.0, -180.0, -84.0, -84.0)
	_set_crank_size(96.0, 48, -260.0, -230.0, -164.0, -134.0)


func _apply_size_medium() -> void:
	max_joystick_radius = 105.0
	_set_joystick_size(220.0, 92.0, 110, 46, 50.0, 50.0)
	_set_control_rect(crouch_button, Vector2(120, 168), 38.0, 22.0, 158.0, 190.0)
	_set_control_rect(settings_button, Vector2(78, 78), 180.0, 38.0, 258.0, 116.0)
	_set_control_rect(interact_button, Vector2(128, 128), -190.0, -64.0, -62.0, 64.0)
	if interact_button:
		interact_button.anchor_top = 0.30
		interact_button.anchor_bottom = 0.30
	_set_control_rect(drop_button, Vector2(190, 60), -95.0, -95.0, 95.0, -35.0)
	if drop_button:
		drop_button.add_theme_font_size_override("font_size", 32)
	_set_flashlight_size(122.0, 17, 61, -215.0, -215.0, -93.0, -93.0)
	_set_crank_size(122.0, 61, -310.0, -275.0, -188.0, -153.0)


func _apply_size_large() -> void:
	max_joystick_radius = 130.0
	_set_joystick_size(270.0, 112.0, 135, 56, 40.0, 40.0)
	_set_control_rect(crouch_button, Vector2(144, 202), 35.0, 20.0, 179.0, 222.0)
	_set_control_rect(settings_button, Vector2(92, 92), 205.0, 36.0, 297.0, 128.0)
	_set_control_rect(interact_button, Vector2(156, 156), -225.0, -78.0, -69.0, 78.0)
	if interact_button:
		interact_button.anchor_top = 0.30
		interact_button.anchor_bottom = 0.30
	_set_control_rect(drop_button, Vector2(230, 72), -115.0, -112.0, 115.0, -40.0)
	if drop_button:
		drop_button.add_theme_font_size_override("font_size", 38)
	_set_flashlight_size(148.0, 20, 74, -250.0, -250.0, -102.0, -102.0)
	_set_crank_size(148.0, 74, -360.0, -320.0, -212.0, -172.0)


func _set_control_rect(ctrl: Control, min_sz: Vector2, l: float, t: float, r: float, b: float) -> void:
	if not ctrl:
		return
	ctrl.custom_minimum_size = min_sz
	ctrl.offset_left = l
	ctrl.offset_top = t
	ctrl.offset_right = r
	ctrl.offset_bottom = b


func _set_joystick_size(base_sz: float, knob_sz: float, base_radius: int, knob_radius: int, margin_x: float, margin_bottom: float) -> void:
	if joystick_base:
		joystick_base.custom_minimum_size = Vector2(base_sz, base_sz)
		joystick_base.layout_mode = 1
		joystick_base.anchors_preset = Control.PRESET_BOTTOM_LEFT
		joystick_base.anchor_left = 0.0
		joystick_base.anchor_top = 1.0
		joystick_base.anchor_right = 0.0
		joystick_base.anchor_bottom = 1.0
		joystick_base.offset_left = margin_x
		joystick_base.offset_right = margin_x + base_sz
		joystick_base.offset_bottom = -margin_bottom
		joystick_base.offset_top = -margin_bottom - base_sz
		var base_sb: StyleBoxFlat = joystick_base.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if base_sb:
			base_sb.set_corner_radius_all(base_radius)
			joystick_base.add_theme_stylebox_override("panel", base_sb)

	if joystick_knob:
		var half_k := knob_sz * 0.5
		joystick_knob.custom_minimum_size = Vector2(knob_sz, knob_sz)
		joystick_knob.layout_mode = 1
		joystick_knob.anchors_preset = Control.PRESET_CENTER
		joystick_knob.anchor_left = 0.5
		joystick_knob.anchor_top = 0.5
		joystick_knob.anchor_right = 0.5
		joystick_knob.anchor_bottom = 0.5
		joystick_knob.offset_left = -half_k
		joystick_knob.offset_top = -half_k
		joystick_knob.offset_right = half_k
		joystick_knob.offset_bottom = half_k
		var knob_sb: StyleBoxFlat = joystick_knob.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if knob_sb:
			knob_sb.set_corner_radius_all(knob_radius)
			joystick_knob.add_theme_stylebox_override("panel", knob_sb)
			joystick_knob.add_theme_stylebox_override("panel", knob_sb)


func _set_flashlight_size(sz: float, font_sz: int, radius: int, l: float, t: float, r: float, b: float) -> void:
	if not flashlight_button:
		return
	flashlight_button.custom_minimum_size = Vector2(sz, sz)
	flashlight_button.offset_left = l
	flashlight_button.offset_top = t
	flashlight_button.offset_right = r
	flashlight_button.offset_bottom = b
	flashlight_button.add_theme_font_size_override("font_size", font_sz)
	
	var sb: StyleBoxFlat = flashlight_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if sb:
		sb.set_corner_radius_all(radius)
		flashlight_button.add_theme_stylebox_override("normal", sb)
		flashlight_button.add_theme_stylebox_override("pressed", sb)
		flashlight_button.add_theme_stylebox_override("hover", sb)


func _set_crank_size(sz: float, radius: int, l: float, t: float, r: float, b: float) -> void:
	if not crank_button:
		return
	crank_button.custom_minimum_size = Vector2(sz, sz)
	crank_button.offset_left = l
	crank_button.offset_top = t
	crank_button.offset_right = r
	crank_button.offset_bottom = b
	var sb: StyleBoxFlat = crank_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if sb:
		sb.set_corner_radius_all(radius)
		crank_button.add_theme_stylebox_override("normal", sb)
		crank_button.add_theme_stylebox_override("pressed", sb)
		crank_button.add_theme_stylebox_override("hover", sb)


func _update_size_buttons_ui(active_preset: String) -> void:
	var btns := {
		"Smallest": btn_size_smallest,
		"Medium": btn_size_medium,
		"Large": btn_size_large
	}
	for k in btns.keys():
		var b: Button = btns[k]
		if b:
			if k == active_preset:
				b.modulate = Color(1.0, 0.95, 0.65, 1.0)
			else:
				b.modulate = Color(0.7, 0.72, 0.76, 0.7)


# --- Input Handling & Drag / Look ---

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if options_modal and options_modal.visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_down(event.index, event.position)
		else:
			_handle_touch_up(event.index)

	elif event is InputEventScreenDrag:
		_handle_touch_drag(event.index, event.position, event.relative)


func _handle_touch_down(id: int, pos: Vector2) -> void:
	if _is_touch_on_interactive_ui(pos):
		return

	var vp_size := get_viewport().get_visible_rect().size

	if pos.x < vp_size.x * 0.45:
		if not joystick_active:
			joystick_active = true
			joystick_touch_id = id
			joystick_center_pos = pos
			joystick_base.global_position = pos - (joystick_base.size * 0.5)
			joystick_base.visible = true
			_update_joystick(pos)
	else:
		if not look_active:
			look_active = true
			look_touch_id = id
			last_look_pos = pos


func _handle_touch_drag(id: int, pos: Vector2, rel: Vector2) -> void:
	if id == joystick_touch_id:
		_update_joystick(pos)
	elif id == look_touch_id:
		look_dragged.emit(rel)


func _handle_touch_up(id: int) -> void:
	if id == joystick_touch_id:
		joystick_active = false
		joystick_touch_id = -1
		move_vector = Vector2.ZERO
		move_vector_changed.emit(Vector2.ZERO)
		_reset_joystick_visuals()

	elif id == look_touch_id:
		look_active = false
		look_touch_id = -1


func _update_joystick(touch_pos: Vector2) -> void:
	var diff := touch_pos - joystick_center_pos
	var dist := diff.length()

	if dist > max_joystick_radius:
		diff = diff.normalized() * max_joystick_radius

	joystick_knob.position = (joystick_base.size * 0.5) + diff - (joystick_knob.size * 0.5)

	var norm_vec := diff / max_joystick_radius
	if norm_vec.length() < deadzone:
		norm_vec = Vector2.ZERO

	move_vector = Vector2(norm_vec.x, norm_vec.y)
	move_vector_changed.emit(move_vector)


func _reset_joystick_visuals() -> void:
	if joystick_knob and joystick_base:
		joystick_knob.position = (joystick_base.size * 0.5) - (joystick_knob.size * 0.5)
		joystick_base.visible = true


func _is_touch_on_interactive_ui(pos: Vector2) -> bool:
	var buttons: Array[Control] = [
		interact_button,
		drop_button,
		crouch_button,
		settings_button,
		flashlight_button,
		crank_button
	]
	for btn in buttons:
		if btn and btn.is_visible_in_tree() and btn.get_global_rect().has_point(pos):
			return true
	return false


# --- Context-Sensitive Granny USE & DROP Controls ---

func set_interact_visible(can_interact: bool, _unused: String = "") -> void:
	if interact_button:
		interact_button.visible = can_interact


func set_drop_visible(can_drop: bool) -> void:
	if drop_button:
		drop_button.visible = can_drop


# --- Crouch Toggle & Design Change ---

func _on_crouch_button_pressed() -> void:
	crouch_enabled = not crouch_enabled
	update_crouch_ui(crouch_enabled)
	crouch_toggled.emit(crouch_enabled)


func update_crouch_ui(active: bool) -> void:
	crouch_enabled = active
	if crouch_button:
		# Standing posture when standing, crouching posture when crouching
		crouch_button.icon = ICON_CROUCH if active else ICON_CREEP_STAND


# --- Settings / Options Modal Logic ---

func _on_settings_button_pressed() -> void:
	if options_modal:
		options_modal.visible = not options_modal.visible
		if options_modal.visible:
			_set_more_options_expanded(false)
			if player_ref and player_ref.get("mouse_sens") != null:
				sens_slider.value = float(player_ref.get("mouse_sens"))
			if mic_thresh_slider:
				var th: float = player_ref.mic_threshold if player_ref and "mic_threshold" in player_ref else 0.025
				mic_thresh_slider.value = th
				if mic_thresh_val:
					mic_thresh_val.text = "%d%%" % int(round(th * 1000.0))
			if mic_sens_slider:
				var sens: float = player_ref.mic_sensitivity if player_ref and "mic_sensitivity" in player_ref else 1.0
				mic_sens_slider.value = sens
				if mic_sens_val:
					mic_sens_val.text = "%.1fx" % sens


func _on_resume_button_pressed() -> void:
	if options_modal:
		options_modal.visible = false


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_sens_slider_value_changed(value: float) -> void:
	if player_ref and player_ref.get("mouse_sens") != null:
		player_ref.set("mouse_sens", value)


func _on_music_check_box_toggled(pressed: bool) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, not pressed)
	else:
		var m_idx := AudioServer.get_bus_index("Master")
		if m_idx != -1:
			AudioServer.set_bus_mute(m_idx, not pressed)


func _on_more_options_button_pressed() -> void:
	_set_more_options_expanded(not is_more_options_expanded)


func _set_more_options_expanded(expanded: bool) -> void:
	is_more_options_expanded = expanded
	if more_options_container:
		more_options_container.visible = expanded
	if more_options_button:
		more_options_button.text = "Less Options ▴" if expanded else "More Options ▾"

	if options_modal:
		if expanded:
			options_modal.offset_top = -225.0
			options_modal.offset_bottom = 225.0
			if sens_vbox:
				sens_vbox.offset_top = -80.0
				sens_vbox.offset_bottom = -15.0
		else:
			options_modal.offset_top = -145.0
			options_modal.offset_bottom = 145.0
			if sens_vbox:
				sens_vbox.offset_top = -30.0
				sens_vbox.offset_bottom = 35.0


func _on_mic_thresh_slider_value_changed(val: float) -> void:
	if mic_thresh_val:
		mic_thresh_val.text = "%d%%" % int(round(val * 1000.0))
	if player_ref and "mic_threshold" in player_ref:
		player_ref.mic_threshold = val
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net and net.get("local_settings") != null:
		net.local_settings["mic_threshold"] = val
		net.save_local_settings()


func _on_mic_sens_slider_value_changed(val: float) -> void:
	if mic_sens_val:
		mic_sens_val.text = "%.1fx" % val
	if player_ref and "mic_sensitivity" in player_ref:
		player_ref.mic_sensitivity = val
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net and net.get("local_settings") != null:
		net.local_settings["mic_sensitivity"] = val
		net.save_local_settings()


func _on_btn_size_smallest_pressed() -> void:
	apply_touch_size_preset("Smallest")


func _on_btn_size_medium_pressed() -> void:
	apply_touch_size_preset("Medium")


func _on_btn_size_large_pressed() -> void:
	apply_touch_size_preset("Large")


# --- Action Signal Handlers ---

func _on_interact_button_pressed() -> void:
	interact_pressed.emit()


func _on_drop_button_pressed() -> void:
	drop_pressed.emit()


func _on_flashlight_button_pressed() -> void:
	flashlight_pressed.emit()


func update_flashlight_ui(is_on: bool) -> void:
	if flashlight_button:
		flashlight_button.modulate = Color(1.0, 0.95, 0.60, 1.0) if is_on else Color(0.85, 0.88, 0.95, 0.75)


func _on_crank_button_pressed() -> void:
	crank_pressed.emit()


func _on_crank_button_down() -> void:
	crank_held.emit(true)
	if crank_button:
		crank_button.modulate = Color(1.0, 0.92, 0.55, 0.95)


func _on_crank_button_up() -> void:
	crank_held.emit(false)
	if crank_button:
		crank_button.modulate = Color(0.75, 0.78, 0.82, 0.65)
