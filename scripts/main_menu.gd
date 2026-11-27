extends Control

# --- Node References ---
@onready var main_subtitle: Label = get_node_or_null("CenterContainer/VBoxContainer/TitleBox/Subtitle")
@onready var main_buttons_container: VBoxContainer = $CenterContainer/VBoxContainer/MainButtons
@onready var play_alone_button: Button = $CenterContainer/VBoxContainer/MainButtons/PlayAloneButton

# Campaign Nodes
@onready var campaign_panel: VBoxContainer = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel")
@onready var campaign_card: PanelContainer = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignCard")
@onready var save_status_tag: Label = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignCard/CardVBox/StatusRow/SaveStatusTag")
@onready var save_slot_label: Label = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignCard/CardVBox/StatusRow/SaveSlotLabel")
@onready var chapter_title_label: Label = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignCard/CardVBox/ChapterTitleLabel")
@onready var checkpoint_location_label: Label = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignCard/CardVBox/CheckpointLocationLabel")
@onready var campaign_actions: VBoxContainer = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignActions")
@onready var continue_game_button: Button = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignActions/ContinueGameButton")
@onready var new_game_button: Button = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignActions/NewGameButton")
@onready var back_from_campaign_button: Button = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/CampaignActions/BackFromCampaignButton")
@onready var new_game_confirm_box: VBoxContainer = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/NewGameConfirmBox")
@onready var confirm_new_game_button: Button = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/NewGameConfirmBox/ConfirmButtonsRow/ConfirmNewGameButton")
@onready var cancel_new_game_button: Button = get_node_or_null("CenterContainer/VBoxContainer/CampaignPanel/NewGameConfirmBox/ConfirmButtonsRow/CancelNewGameButton")

@onready var multiplayer_panel: VBoxContainer = $CenterContainer/VBoxContainer/MultiplayerPanel
@onready var host_setup_panel: VBoxContainer = $CenterContainer/VBoxContainer/HostSetupPanel
@onready var join_methods_panel: VBoxContainer = $CenterContainer/VBoxContainer/JoinMethodsPanel
@onready var join_room_code_panel: VBoxContainer = $CenterContainer/VBoxContainer/JoinRoomCodePanel
@onready var join_lan_panel: VBoxContainer = $CenterContainer/VBoxContainer/JoinLanPanel
@onready var lobby_panel: VBoxContainer = $CenterContainer/VBoxContainer/LobbyPanel
@onready var options_panel: VBoxContainer = $CenterContainer/VBoxContainer/OptionsPanel

# Player & Host Setup Nodes
@onready var player_name_box: HBoxContainer = $CenterContainer/VBoxContainer/PlayerNameBox
@onready var player_name_sep: HSeparator = $CenterContainer/VBoxContainer/HSeparator
@onready var player_name_input: LineEdit = $CenterContainer/VBoxContainer/PlayerNameBox/PlayerNameInput
@onready var host_setup_title: Label = $CenterContainer/VBoxContainer/HostSetupPanel/HostSetupTitle
@onready var host_setup_desc: Label = $CenterContainer/VBoxContainer/HostSetupPanel/HostSetupDesc
@onready var game_mode_option: OptionButton = get_node_or_null("CenterContainer/VBoxContainer/HostSetupPanel/GameModeBox/GameModeOption")
@onready var lobby_name_input: LineEdit = $CenterContainer/VBoxContainer/HostSetupPanel/LobbyNameBox/LobbyNameInput
@onready var max_players_option: OptionButton = $CenterContainer/VBoxContainer/HostSetupPanel/MaxPlayersBox/MaxPlayersOption
@onready var host_info_label: Label = $CenterContainer/VBoxContainer/HostSetupPanel/HostInfoLabel
@onready var start_host_button: Button = $CenterContainer/VBoxContainer/HostSetupPanel/StartHostButton

# Join Nodes
@onready var room_code_input: LineEdit = $CenterContainer/VBoxContainer/JoinRoomCodePanel/RoomCodeRow/RoomCodeInput
@onready var paste_code_button: Button = $CenterContainer/VBoxContainer/JoinRoomCodePanel/RoomCodeRow/PasteCodeButton
@onready var join_room_code_button: Button = $CenterContainer/VBoxContainer/JoinRoomCodePanel/JoinRoomCodeButton
@onready var room_code_status_label: Label = $CenterContainer/VBoxContainer/JoinRoomCodePanel/RoomCodeStatusLabel

@onready var searching_label: Label = $CenterContainer/VBoxContainer/JoinLanPanel/SearchingLabel
@onready var lobby_list: VBoxContainer = $CenterContainer/VBoxContainer/JoinLanPanel/LobbyList
@onready var refresh_lan_button: Button = $CenterContainer/VBoxContainer/JoinLanPanel/RefreshLanButton

# Options UI nodes
@onready var voice_mode_option: OptionButton = $CenterContainer/VBoxContainer/OptionsPanel/VoiceBox/VoiceModeOption
@onready var crosshair_check: CheckBox = $CenterContainer/VBoxContainer/OptionsPanel/CrosshairBox/CrosshairCheck
@onready var touch_size_option: OptionButton = get_node_or_null("CenterContainer/VBoxContainer/OptionsPanel/TouchSizeBox/TouchSizeOption")

# Lobby UI nodes
@onready var lobby_title: Label = $CenterContainer/VBoxContainer/LobbyPanel/LobbyHeader/LobbyTitle
@onready var lobby_settings_label: Label = $CenterContainer/VBoxContainer/LobbyPanel/LobbyHeader/LobbySettingsLabel
@onready var room_code_card: PanelContainer = $CenterContainer/VBoxContainer/LobbyPanel/RoomCodeCard
@onready var lobby_code_row: Control = $CenterContainer/VBoxContainer/LobbyPanel/RoomCodeCard
@onready var lobby_code_label: Label = $CenterContainer/VBoxContainer/LobbyPanel/RoomCodeCard/LobbyCodeRow/LobbyCodeLabel
@onready var copy_code_button: Button = $CenterContainer/VBoxContainer/LobbyPanel/RoomCodeCard/LobbyCodeRow/CopyCodeButton
@onready var lobby_online_label: Label = $CenterContainer/VBoxContainer/LobbyPanel/LobbyOnlineLabel
@onready var lobby_ip_row: HBoxContainer = $CenterContainer/VBoxContainer/LobbyPanel/LobbyIpRow
@onready var lobby_ip_label: Label = $CenterContainer/VBoxContainer/LobbyPanel/LobbyIpRow/LobbyIpLabel
@onready var copy_ip_button: Button = $CenterContainer/VBoxContainer/LobbyPanel/LobbyIpRow/CopyIpButton
@onready var player_count_label: Label = $CenterContainer/VBoxContainer/LobbyPanel/RosterCard/RosterVBox/RosterHeader/PlayerCountLabel
@onready var player_list_container: VBoxContainer = $CenterContainer/VBoxContainer/LobbyPanel/RosterCard/RosterVBox/PlayerListContainer
@onready var role_brief_card: PanelContainer = get_node_or_null("CenterContainer/VBoxContainer/LobbyPanel/RoleBriefCard")
@onready var role_desc_label: Label = $CenterContainer/VBoxContainer/LobbyPanel/RoleBriefCard/RoleDescLabel
@onready var lobby_status_label: Label = $CenterContainer/VBoxContainer/LobbyPanel/LobbyStatusLabel
@onready var ready_button: Button = $CenterContainer/VBoxContainer/LobbyPanel/LobbyButtonsBox/ReadyButton
@onready var start_game_button: Button = $CenterContainer/VBoxContainer/LobbyPanel/LobbyButtonsBox/StartGameButton
@onready var match_settings_button: Button = get_node_or_null("CenterContainer/VBoxContainer/LobbyPanel/LobbyButtonsBox/MatchSettingsButton")
@onready var leave_lobby_button: Button = $CenterContainer/VBoxContainer/LobbyPanel/LobbyButtonsBox/LeaveLobbyButton

# Match Settings Modal nodes
@onready var match_settings_modal: Control = get_node_or_null("MatchSettingsModal")
@onready var modal_subtitle: Label = get_node_or_null("MatchSettingsModal/ModalCenter/ModalCard/ModalVBox/ModalSubtitle")
@onready var modal_atmosphere_box: HBoxContainer = get_node_or_null("MatchSettingsModal/ModalCenter/ModalCard/ModalVBox/ModalAtmosphereBox")
@onready var modal_atmosphere_option: OptionButton = get_node_or_null("MatchSettingsModal/ModalCenter/ModalCard/ModalVBox/ModalAtmosphereBox/ModalAtmosphereOption")
@onready var modal_flashlight_box: HBoxContainer = get_node_or_null("MatchSettingsModal/ModalCenter/ModalCard/ModalVBox/ModalFlashlightBox")
@onready var modal_flashlight_option: OptionButton = get_node_or_null("MatchSettingsModal/ModalCenter/ModalCard/ModalVBox/ModalFlashlightBox/ModalFlashlightOption")
@onready var modal_name_tags_check: CheckBox = get_node_or_null("MatchSettingsModal/ModalCenter/ModalCard/ModalVBox/ModalNameTagsBox/ModalNameTagsCheck")
@onready var modal_done_button: Button = get_node_or_null("MatchSettingsModal/ModalCenter/ModalCard/ModalVBox/ModalDoneButton")

# Mic Calibration Fullscreen Slide nodes
@onready var mic_calib_screen: Control = get_node_or_null("MicCalibrationScreen")
@onready var calib_meter_status: Label = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/LiveMeterVBox/MeterRow/MeterStatus")
@onready var calib_progress_bar: ProgressBar = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/LiveMeterVBox/CalibProgressBar")
@onready var manual_adjust_button: Button = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/ManualAdjustButton")
@onready var sliders_vbox: VBoxContainer = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/SlidersVBox")
@onready var calib_threshold_slider: HSlider = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/SlidersVBox/GateBox/ThresholdSlider")
@onready var calib_threshold_val: Label = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/SlidersVBox/GateBox/GateRow/ThresholdValLabel")
@onready var calib_sens_slider: HSlider = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/SlidersVBox/SensBox/SensitivitySlider")
@onready var calib_sens_val: Label = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/SlidersVBox/SensBox/SensRow/SensitivityValLabel")
@onready var calib_auto_button: Button = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/AutoCalibVBox/AutoCalibButton")
@onready var calib_auto_status: Label = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/AutoCalibVBox/AutoCalibStatus")
@onready var calib_dont_show_check: CheckBox = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/DontShowRow/CalibDontShowCheck")
@onready var save_calib_button: Button = get_node_or_null("MicCalibrationScreen/CenterContainer/MainCard/VBox/ProceedButton")
@onready var proceed_button: Button = save_calib_button
@onready var skip_calib_button: Button = null

# Backward compatibility alias
@onready var mic_calib_modal: Control = mic_calib_screen

var calib_audio_player: AudioStreamPlayer = null
var calib_capture_effect: AudioEffectCapture = null
var is_auto_calibrating: bool = false
var auto_calib_timer: float = 0.0
var auto_calib_samples: Array[float] = []
var is_calib_opened_from_options: bool = false

var discovered_servers: Dictionary = {}
var is_local_ready: bool = false


func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_default_values()
	
	var net := get_node_or_null("/root/NetworkManager")
	var skip_startup: bool = false
	if net:
		net.connection_succeeded.connect(_on_connection_succeeded)
		net.connection_failed.connect(_on_connection_failed)
		net.server_disconnected.connect(_on_server_disconnected)
		net.server_found.connect(_on_server_found)
		net.lobby_updated.connect(_update_lobby_ui)
		net.upnp_completed.connect(_on_upnp_completed)
		net.room_code_ready.connect(_on_room_code_ready)
		net.signaling_status_changed.connect(_on_signaling_status_changed)
		if net.get("local_settings") != null:
			skip_startup = bool(net.local_settings.get("skip_startup_mic_calib", false))

	if copy_code_button and not copy_code_button.pressed.is_connected(_on_copy_code_pressed):
		copy_code_button.pressed.connect(_on_copy_code_pressed)
	if copy_ip_button and not copy_ip_button.pressed.is_connected(_on_copy_ip_pressed):
		copy_ip_button.pressed.connect(_on_copy_ip_pressed)

	if not skip_startup:
		_open_mic_calibration_screen(true)
	else:
		_show_main_buttons()


func _setup_default_values() -> void:
	var sys_user := OS.get_environment("USERNAME")
	if sys_user.is_empty():
		sys_user = OS.get_environment("USER")
	if sys_user.is_empty():
		sys_user = "Player"
	
	player_name_input.text = sys_user
	lobby_name_input.text = "%s's Session" % sys_user
	
	# Game Mode options (Story Mode locked for now)
	if game_mode_option:
		game_mode_option.clear()
		game_mode_option.add_item("Story Mode (Coming Soon)", 0)
		game_mode_option.set_item_disabled(0, true)
		game_mode_option.add_item("Escape Mode", 1)
		game_mode_option.select(1)
		if not game_mode_option.item_selected.is_connected(_on_game_mode_option_selected):
			game_mode_option.item_selected.connect(_on_game_mode_option_selected)

	# Setup Modal Controls
	if modal_atmosphere_option:
		modal_atmosphere_option.clear()
		modal_atmosphere_option.add_item("Midnight (Pitch Black)", 0)
		modal_atmosphere_option.add_item("Dusk (Dim Twilight)", 1)
		modal_atmosphere_option.select(0)
		if not modal_atmosphere_option.item_selected.is_connected(_on_modal_atmosphere_selected):
			modal_atmosphere_option.item_selected.connect(_on_modal_atmosphere_selected)

	if modal_flashlight_option:
		modal_flashlight_option.clear()
		modal_flashlight_option.add_item("Squad Roles (Player Choice)", 0)
		modal_flashlight_option.add_item("Mystery Roulette (Random)", 1)
		modal_flashlight_option.add_item("All Hand-Crank (Uniform Panic)", 2)
		modal_flashlight_option.add_item("All Battery (Uniform Scavenger)", 3)
		modal_flashlight_option.add_item("All Classic Normal (Infinite)", 4)
		modal_flashlight_option.add_item("All Disabled (Pitch Black)", 5)
		modal_flashlight_option.select(0)
		if not modal_flashlight_option.item_selected.is_connected(_on_modal_flashlight_selected):
			modal_flashlight_option.item_selected.connect(_on_modal_flashlight_selected)

	if modal_name_tags_check:
		modal_name_tags_check.button_pressed = true
		if not modal_name_tags_check.toggled.is_connected(_on_modal_name_tags_toggled):
			modal_name_tags_check.toggled.connect(_on_modal_name_tags_toggled)

	if match_settings_button and not match_settings_button.pressed.is_connected(_on_match_settings_button_pressed):
		match_settings_button.pressed.connect(_on_match_settings_button_pressed)

	if modal_done_button and not modal_done_button.pressed.is_connected(_on_modal_done_pressed):
		modal_done_button.pressed.connect(_on_modal_done_pressed)

	# Max players options
	max_players_option.clear()
	max_players_option.add_item("2 Players", 2)
	max_players_option.add_item("3 Players", 3)
	max_players_option.add_item("4 Players", 4)
	max_players_option.select(2)  # Default 4 players

	# Platform-tailored Voice Mode options
	var is_mobile := OS.get_name() in ["Android", "iOS"] or OS.has_feature("android") or OS.has_feature("ios")
	voice_mode_option.clear()
	voice_mode_option.add_item("Voice Detection (Auto-detect)", 0)
	voice_mode_option.add_item("Always On (Continuous)", 1)
	if not is_mobile:
		voice_mode_option.add_item("Push-to-Talk (Hold [V])", 2)

	var net := get_node_or_null("/root/NetworkManager")
	if net:
		var v_mode: String = str(net.local_settings.get("voice_mode", "open_mic"))
		if v_mode == "always_on":
			voice_mode_option.select(1)
		elif v_mode == "ptt" and not is_mobile:
			voice_mode_option.select(2)
		else:
			voice_mode_option.select(0)

		crosshair_check.button_pressed = bool(net.local_settings.get("crosshair_enabled", true))

		if touch_size_option:
			touch_size_option.clear()
			touch_size_option.add_item("Smallest", 0)
			touch_size_option.add_item("Medium", 1)
			touch_size_option.add_item("Large", 2)
			var current_size: String = str(net.local_settings.get("touch_size", "Smallest"))
			match current_size:
				"Medium": touch_size_option.select(1)
				"Large": touch_size_option.select(2)
				_: touch_size_option.select(0)


# --- Navigation Helpers ---
func _hide_all_panels() -> void:
	main_buttons_container.visible = false
	if campaign_panel: campaign_panel.visible = false
	if multiplayer_panel: multiplayer_panel.visible = false
	if host_setup_panel: host_setup_panel.visible = false
	if join_methods_panel: join_methods_panel.visible = false
	if join_room_code_panel: join_room_code_panel.visible = false
	if join_lan_panel: join_lan_panel.visible = false
	lobby_panel.visible = false
	options_panel.visible = false
	if match_settings_modal: match_settings_modal.visible = false
	if mic_calib_screen: mic_calib_screen.visible = false
	if mic_calib_modal and mic_calib_modal != mic_calib_screen: mic_calib_modal.visible = false
	if player_name_box: player_name_box.visible = false
	if player_name_sep: player_name_sep.visible = false


func _show_main_buttons() -> void:
	_hide_all_panels()
	main_buttons_container.visible = true
	if main_subtitle:
		main_subtitle.text = "CO-OP ESCAPE"
	if player_name_box:
		player_name_box.visible = true
	if player_name_sep:
		player_name_sep.visible = true
	if play_alone_button:
		play_alone_button.disabled = true
		play_alone_button.text = "CAMPAIGN (COMING SOON)"
		play_alone_button.tooltip_text = "Campaign mode is currently in development."

	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.stop_listening()


func _show_campaign_panel() -> void:
	_hide_all_panels()
	if main_subtitle:
		main_subtitle.text = "CO-OP ESCAPE"
	if campaign_panel:
		campaign_panel.visible = true
	if campaign_actions:
		campaign_actions.visible = true
	if new_game_confirm_box:
		new_game_confirm_box.visible = false

	var save_mgr := get_node_or_null("/root/SaveManager")
	var has_save: bool = save_mgr and save_mgr.has_campaign_save()
	if has_save:
		var summary: Dictionary = save_mgr.get_campaign_save_summary()
		var ch_title: String = str(summary.get("chapter_title", "Chapter 1: The Midnight Return"))
		var cp_disp: String = str(summary.get("checkpoint_display", "Checkpoint"))
		if save_status_tag:
			save_status_tag.text = "ACTIVE CHECKPOINT"
			save_status_tag.add_theme_color_override("font_color", Color(0.92, 0.76, 0.35, 1.0))
		if chapter_title_label:
			chapter_title_label.text = ch_title
		if checkpoint_location_label:
			checkpoint_location_label.text = "Checkpoint: %s" % cp_disp
		if continue_game_button:
			continue_game_button.visible = true
			continue_game_button.text = "CONTINUE"
		if new_game_button:
			new_game_button.text = "NEW GAME"
	else:
		if save_status_tag:
			save_status_tag.text = "NO SAVE FILE"
			save_status_tag.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
		if chapter_title_label:
			chapter_title_label.text = "Fresh Journey"
		if checkpoint_location_label:
			checkpoint_location_label.text = "Laluan 189 • Drive home into the dark alone."
		if continue_game_button:
			continue_game_button.visible = false
		if new_game_button:
			new_game_button.text = "START NEW GAME"


func _show_multiplayer_panel() -> void:
	_hide_all_panels()
	if main_subtitle:
		main_subtitle.text = "CO-OP ESCAPE"
	if player_name_box:
		player_name_box.visible = true
	if player_name_sep:
		player_name_sep.visible = true
	multiplayer_panel.visible = true


func _show_host_setup_panel() -> void:
	_hide_all_panels()
	if main_subtitle:
		main_subtitle.text = "CO-OP ESCAPE"
	# player_name_box and player_name_sep are not shown when creating lobby
	host_setup_panel.visible = true
	
	var p_name := _get_player_name()
	if lobby_name_input.text.is_empty() or lobby_name_input.text.ends_with("'s House") or lobby_name_input.text.ends_with("'s Convoy") or lobby_name_input.text.ends_with("'s Session"):
		lobby_name_input.text = "%s's Session" % p_name
	
	var net := get_node_or_null("/root/NetworkManager")
	var local_ip: String = net._get_local_ip() if net else "127.0.0.1"
	var default_port: int = net.DEFAULT_PORT if net else 8910
	
	host_setup_title.text = "CREATE LOBBY"
	host_setup_desc.text = "Session Settings"
	host_info_label.text = "Local IP: %s (Port %d)" % [local_ip, default_port]
	start_host_button.text = "START LOBBY"


func _on_game_mode_option_selected(_idx: int) -> void:
	pass


func _show_join_methods_panel() -> void:
	_hide_all_panels()
	join_methods_panel.visible = true


func _show_join_room_code_panel() -> void:
	_hide_all_panels()
	join_room_code_panel.visible = true
	room_code_status_label.text = ""


func _show_join_lan_panel() -> void:
	_hide_all_panels()
	join_lan_panel.visible = true
	_refresh_lan_search()


func _show_lobby_panel() -> void:
	_hide_all_panels()
	if player_name_box: player_name_box.visible = false
	if player_name_sep: player_name_sep.visible = false
	lobby_panel.visible = true
	var is_host := multiplayer.is_server()
	is_local_ready = is_host
	_update_lobby_ui()


func _show_options_panel() -> void:
	_hide_all_panels()
	if main_subtitle:
		main_subtitle.text = "CO-OP ESCAPE"
	options_panel.visible = true


func _get_player_name() -> String:
	var raw := player_name_input.text.strip_edges()
	return raw if not raw.is_empty() else "Player"


# --- Auto LAN Discovery Callback ---
func _on_server_found(ip: String, port: int, server_name: String, room_code: String = "") -> void:
	if discovered_servers.has(ip):
		return
	
	discovered_servers[ip] = { "name": server_name, "port": port, "room_code": room_code }
	searching_label.visible = false
	
	var btn := Button.new()
	btn.text = "%s - Join" % server_name
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(func() -> void:
		for child in lobby_list.get_children():
			if child is Button:
				child.disabled = true
		btn.text = "CONNECTING..."
		if searching_label:
			searching_label.visible = true
			searching_label.text = "Connecting to %s..." % server_name
			searching_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
		_join_target(ip, port, room_code)
	)
	lobby_list.add_child(btn)


# --- Connection Logic ---
func _join_target(ip: String, port: int, room_code: String = "") -> void:
	var p_name := _get_player_name()
	if searching_label and join_lan_panel.visible:
		searching_label.visible = true
		searching_label.text = "Connecting to %s..." % ip
		searching_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	if room_code_status_label and join_room_code_panel.visible:
		room_code_status_label.text = "Connecting to %s:%d as '%s'..." % [ip, port, p_name]
	
	var net := get_node_or_null("/root/NetworkManager")
	if not net:
		return
	net.is_singleplayer = false
	
	var err: int = OK
	if not room_code.is_empty():
		err = net.join_online_room(room_code, p_name)
		if err != OK:
			err = net.join_game(ip, port, p_name)
	else:
		err = net.join_game(ip, port, p_name)
	
	if err != OK:
		if searching_label and join_lan_panel.visible:
			searching_label.text = "Failed to connect to %s" % ip
			searching_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		if room_code_status_label and join_room_code_panel.visible:
			room_code_status_label.text = "Failed to connect to %s" % ip
		for child in lobby_list.get_children():
			if child is Button:
				child.disabled = false
				child.text = "%s - Join" % ip


func _refresh_lan_search() -> void:
	discovered_servers.clear()
	for child in lobby_list.get_children():
		child.queue_free()
	searching_label.visible = true
	searching_label.text = "Searching local network..."
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.start_listening()


# --- Button Signal Handlers ---
func _on_campaign_pressed() -> void:
	# Campaign mode is locked (Coming Soon)
	return


func _on_load_game_pressed() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_campaign_save():
		save_mgr.load_campaign_save()
	_start_solo_campaign()


func _on_new_game_pressed() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	var has_save: bool = save_mgr and save_mgr.has_campaign_save()
	if has_save:
		if campaign_actions:
			campaign_actions.visible = false
		if new_game_confirm_box:
			new_game_confirm_box.visible = true
	else:
		_start_solo_campaign()


func _on_confirm_new_game_pressed() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.delete_campaign_save()
	_start_solo_campaign()


func _on_cancel_new_game_pressed() -> void:
	if campaign_actions:
		campaign_actions.visible = true
	if new_game_confirm_box:
		new_game_confirm_box.visible = false


func _on_back_from_campaign_pressed() -> void:
	_show_main_buttons()


func _start_solo_campaign() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.is_singleplayer = true
		var settings := {
			"player_name": _get_player_name(),
			"lobby_name": "Solo Session",
			"game_mode": "story",
			"show_name_tags": false,
			"flashlight_mode": "normal",
			"flashlight_enabled": true,
			"atmosphere": "Midnight",
			"max_players": 1
		}
		net.host_game(8910, settings)
	get_tree().change_scene_to_file("res://scenes/story_drive.tscn")


func _on_multiplayer_pressed() -> void:
	_show_multiplayer_panel()


func _on_host_pressed() -> void:
	_show_host_setup_panel()


func _on_join_pressed() -> void:
	_show_join_methods_panel()


func _on_back_to_multiplayer_pressed() -> void:
	_show_multiplayer_panel()


func _on_back_to_join_methods_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.stop_listening()
	_show_join_methods_panel()


func _on_start_host_session_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if not net:
		return
	net.is_singleplayer = false

	# Multiplayer Story mode is locked for now; enforce escape mode
	var g_mode := "escape"

	var default_lobby_name := "Convoy Road Trip" if g_mode == "story" else "Escape Squad"
	var final_lobby_name := lobby_name_input.text.strip_edges()
	if final_lobby_name.is_empty():
		final_lobby_name = default_lobby_name

	var settings := {
		"player_name": _get_player_name(),
		"lobby_name": final_lobby_name,
		"game_mode": g_mode,
		"atmosphere": "Midnight",
		"flashlight_mode": "roles",
		"flashlight_enabled": true,
		"show_name_tags": true,
		"max_players": max_players_option.get_item_id(max_players_option.selected)
	}

	var err: int = net.host_online_room("", settings)
	if err == OK:
		_show_lobby_panel()
	else:
		host_info_label.text = "Error starting server (Port %d busy?)" % net.DEFAULT_PORT


func _on_join_method_online_pressed() -> void:
	_show_join_room_code_panel()


func _on_join_method_lan_pressed() -> void:
	_show_join_lan_panel()


func _on_refresh_lan_pressed() -> void:
	_refresh_lan_search()


func _on_options_pressed() -> void:
	_show_options_panel()


func _on_voice_mode_selected(index: int) -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		var mode_str := "open_mic"
		if index == 1:
			mode_str = "always_on"
		elif index == 2:
			mode_str = "ptt"
		net.local_settings["voice_mode"] = mode_str
		net.save_local_settings()


func _on_crosshair_toggled(button_pressed: bool) -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.local_settings["crosshair_enabled"] = button_pressed
		net.save_local_settings()


func _on_touch_size_selected(index: int) -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		var size_str := "Smallest"
		match index:
			1: size_str = "Medium"
			2: size_str = "Large"
			_: size_str = "Smallest"
		net.local_settings["touch_size"] = size_str
		net.save_local_settings()


func _on_paste_code_pressed() -> void:
	var clip_text := DisplayServer.clipboard_get().strip_edges()
	if not clip_text.is_empty():
		room_code_input.text = clip_text
		room_code_status_label.text = "Pasted: %s" % clip_text
		room_code_status_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55))


func _on_join_room_code_pressed() -> void:
	var code := room_code_input.text.strip_edges()
	if code.is_empty():
		room_code_status_label.text = "Please enter a Room Code (e.g. 1E0UVS0-1HGE10B) or Host IP."
		room_code_status_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.45))
		return

	var p_name := _get_player_name()
	room_code_status_label.text = "Connecting to '%s' as '%s'..." % [code, p_name]
	room_code_status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))

	var net := get_node_or_null("/root/NetworkManager")
	if net:
		var err: int = net.join_online_room(code, p_name)
		if err != OK:
			room_code_status_label.text = "Invalid room code or IP format."
			room_code_status_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.45))


func _on_copy_ip_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	var ip_to_copy := "127.0.0.1"
	if net and not net.upnp_external_ip.is_empty() and net.upnp_external_ip != "Online":
		ip_to_copy = net.upnp_external_ip
	elif net:
		ip_to_copy = net._get_best_host_ip()
	DisplayServer.clipboard_set(ip_to_copy)
	copy_ip_button.text = "COPIED!"
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(copy_ip_button):
			copy_ip_button.text = "COPY IP"
	)


func _on_copy_code_pressed() -> void:
	var code_to_copy := ""
	var net := get_node_or_null("/root/NetworkManager")
	if net and not net.current_room_code.is_empty():
		code_to_copy = net.current_room_code
	elif lobby_code_label and not lobby_code_label.text.is_empty() and lobby_code_label.text != "CONNECTING...":
		code_to_copy = lobby_code_label.text

	if not code_to_copy.is_empty():
		DisplayServer.clipboard_set(code_to_copy)
		copy_code_button.text = "COPIED!"
		var timer := get_tree().create_timer(1.8)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(copy_code_button):
				copy_code_button.text = "COPY"
		)


func _on_room_code_ready(code: String) -> void:
	if lobby_code_label:
		lobby_code_label.text = code
	if copy_code_button:
		copy_code_button.visible = true


func _on_signaling_status_changed(message: String) -> void:
	if join_room_code_panel and join_room_code_panel.visible and room_code_status_label:
		room_code_status_label.text = message
	if join_lan_panel and join_lan_panel.visible and searching_label:
		searching_label.visible = true
		searching_label.text = message
		searching_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))


func _on_upnp_completed(success: bool, ext_ip: String, msg: String) -> void:
	if not lobby_online_label:
		return
	if success and not ext_ip.is_empty() and ext_ip != "Online":
		lobby_online_label.text = "Online Public IP: %s (Port 8910 Open)" % ext_ip
		lobby_online_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55))
	else:
		lobby_online_label.text = msg
		lobby_online_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))


func _on_back_pressed() -> void:
	_show_main_buttons()


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Lobby UI & Callbacks ---
func _on_lobby_game_mode_option_selected(idx: int) -> void:
	var net := get_node_or_null("/root/NetworkManager")
# --- Match Settings Modal Callbacks ---
func _on_match_settings_button_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if not net or not match_settings_modal:
		return

	var g_mode: String = str(net.host_settings.get("game_mode", "story"))
	var is_story := (g_mode == "story")
	var atmos: String = str(net.host_settings.get("atmosphere", "Midnight"))
	var raw_f_mode: String = str(net.host_settings.get("flashlight_mode", "roles"))
	var show_tags: bool = bool(net.host_settings.get("show_name_tags", true))

	if modal_subtitle:
		modal_subtitle.text = "Story Mode Convoy Rules" if is_story else "Escape Survival Rules"

	if modal_atmosphere_box:
		modal_atmosphere_box.visible = not is_story
	if modal_flashlight_box:
		modal_flashlight_box.visible = not is_story

	if modal_atmosphere_option:
		modal_atmosphere_option.select(0 if atmos == "Midnight" else 1)

	if modal_flashlight_option:
		var f_idx := 0
		match raw_f_mode:
			"roles": f_idx = 0
			"roulette": f_idx = 1
			"crank": f_idx = 2
			"battery": f_idx = 3
			"normal": f_idx = 4
			"disabled": f_idx = 5
		modal_flashlight_option.select(f_idx)

	if modal_name_tags_check:
		modal_name_tags_check.button_pressed = show_tags

	match_settings_modal.visible = true


func _on_modal_done_pressed() -> void:
	if match_settings_modal:
		match_settings_modal.visible = false


func _on_modal_atmosphere_selected(idx: int) -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if not net or not multiplayer.is_server():
		return
	net.update_host_match_settings({
		"atmosphere": "Midnight" if idx == 0 else "Dusk"
	})


func _on_modal_flashlight_selected(idx: int) -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if not net or not multiplayer.is_server():
		return
	var new_mode := "roles"
	match idx:
		0: new_mode = "roles"
		1: new_mode = "roulette"
		2: new_mode = "crank"
		3: new_mode = "battery"
		4: new_mode = "normal"
		5: new_mode = "disabled"
	net.update_host_match_settings({
		"flashlight_mode": new_mode,
		"flashlight_enabled": (new_mode != "disabled")
	})


func _on_modal_name_tags_toggled(button_pressed: bool) -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if not net or not multiplayer.is_server():
		return
	net.update_host_match_settings({
		"show_name_tags": button_pressed
	})


func _get_role_display_name(role_key: String) -> String:
	match role_key:
		"battery": return "Battery Torch"
		"crank": return "Hand-Crank"
		"lantern": return "Lantern"
		"uv": return "UV Blacklight"
		_: return "Random Role"


func _get_role_desc(role_key: String) -> String:
	match role_key:
		"battery": return "Long-range beam (18m). Uses batteries found in the house."
		"crank": return "Hold [C] to recharge infinite power. Makes cranking noise."
		"lantern": return "Wide 360° light. Illuminates the room, but draws attention."
		"uv": return "Purple beam. Reveals secret keypad codes and monster tracks."
		_: return "Mystery pick. Assigned an unpicked role when match begins."


func _update_lobby_ui() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if not net or not lobby_panel.visible:
		return
	
	var is_host := multiplayer.is_server()
	var my_id := multiplayer.get_unique_id()
	
	# Settings overview
	var l_name: String = str(net.host_settings.get("lobby_name", "Family House"))
	var atmos: String = str(net.host_settings.get("atmosphere", "Midnight"))
	var raw_f_mode: String = str(net.host_settings.get("flashlight_mode", "roles"))
	var max_p: int = int(net.host_settings.get("max_players", 4))
	var g_mode: String = str(net.host_settings.get("game_mode", "story"))
	var is_story := (g_mode == "story")
	var mode_title := "Story Mode" if is_story else "Escape"
	
	lobby_title.text = "[ %s ] %s" % [mode_title.to_upper(), l_name.to_upper()]
	player_count_label.text = "%d / %d" % [net.players.size(), max_p]

	# Clean Unified Rules Label
	if lobby_settings_label:
		lobby_settings_label.visible = true
		var show_tags: bool = bool(net.host_settings.get("show_name_tags", true))
		var tags_str := "3D Names: ON" if show_tags else "3D Names: OFF"
		if is_story:
			lobby_settings_label.text = "%s" % tags_str
		else:
			var rule_title := "Squad Roles"
			match raw_f_mode:
				"roles": rule_title = "Squad Roles"
				"roulette": rule_title = "Mystery Roulette"
				"crank": rule_title = "All Hand-Crank"
				"battery": rule_title = "All Battery"
				"normal": rule_title = "All Classic"
				"disabled": rule_title = "Pitch Black"
			lobby_settings_label.text = "Atmosphere: %s  •  Flashlights: %s  •  %s" % [atmos, rule_title, tags_str]

	if match_settings_button:
		match_settings_button.visible = is_host

	# Host Room Code or IP display
	var has_room_code: bool = not str(net.current_room_code).is_empty()
	if has_room_code:
		lobby_code_row.visible = true
		lobby_code_label.text = str(net.current_room_code)
		lobby_ip_row.visible = false
		lobby_online_label.visible = true
		if net.is_webrtc_mode:
			lobby_online_label.text = "● Online (Ready for squad)"
			lobby_online_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.6))
		elif not net.upnp_external_ip.is_empty() and net.upnp_external_ip != "Online":
			lobby_online_label.text = "● Online & LAN Ready (Port %d)" % net.DEFAULT_PORT
			lobby_online_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.6))
		elif not net.upnp_status_message.is_empty():
			lobby_online_label.text = "● %s" % net.upnp_status_message
			lobby_online_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
		else:
			lobby_online_label.text = "● Ready (Port %d)" % net.DEFAULT_PORT
			lobby_online_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.6))
	else:
		if net.is_webrtc_mode:
			lobby_code_row.visible = true
			lobby_code_label.text = "CONNECTING..."
			lobby_ip_row.visible = false
			lobby_online_label.visible = true
			lobby_online_label.text = "● Connecting..."
			lobby_online_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45))
		else:
			lobby_code_row.visible = false
			lobby_ip_row.visible = true
			var best_ip: String = net._get_best_host_ip() if is_host else "Host"
			lobby_ip_label.text = "LAN Host: %s:%d" % [best_ip, net.DEFAULT_PORT]
			lobby_online_label.visible = false

	# Clear and rebuild player rows
	for child in player_list_container.get_children():
		child.queue_free()

	var taken_story_chars: Dictionary = {}
	if is_story:
		for l_pid in net.players:
			var l_info: Dictionary = net.players[l_pid]
			var l_char: String = str(l_info.get("character", "random"))
			if l_char in net.STORY_CHARACTERS:
				taken_story_chars[l_char] = int(l_pid)

	var all_ready: bool = true
	for peer_id in net.players:
		var p_info: Dictionary = net.players[peer_id]
		var p_name: String = str(p_info.get("name", "Player %d" % peer_id))
		var is_peer_ready: bool = bool(p_info.get("ready", peer_id == 1))
		var is_peer_host: bool = (peer_id == 1)
		var p_role: String = str(p_info.get("role", "random"))
		var p_char: String = str(p_info.get("character", "random"))
		
		if not is_peer_ready:
			all_ready = false

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 32)
		row.add_theme_constant_override("separation", 10)

		# 1. Player Name
		var name_lbl := Label.new()
		var role_icon := "[HOST] " if is_peer_host else ""
		var you_tag := " (You)" if peer_id == my_id else ""
		name_lbl.text = "%s%s%s" % [role_icon, p_name, you_tag]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98) if is_peer_ready else Color(0.75, 0.78, 0.85))
		name_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(name_lbl)

		# 2. Character Selector (Both Story and Escape modes)
		# In Story mode: unique character per player (claimed characters disabled)
		# In Escape mode: any player can pick any character (duplicates allowed!)
		if peer_id == my_id:
			var char_picker := OptionButton.new()
			char_picker.custom_minimum_size = Vector2(120, 28)
			var char_keys: Array[String] = ["random", "Syazril", "Aleysa", "Syahirul", "Amelya"]
			char_picker.add_item("Random", 0)
			for c_i in range(1, char_keys.size()):
				var c_name := char_keys[c_i]
				var is_taken := is_story and taken_story_chars.has(c_name) and int(taken_story_chars[c_name]) != int(peer_id)
				var suffix := " (Taken)" if is_taken else ""
				char_picker.add_item("%s%s" % [c_name, suffix], c_i)
				if is_taken:
					char_picker.set_item_disabled(c_i, true)

			var sel_idx := char_keys.find(p_char)
			char_picker.select(sel_idx if sel_idx >= 0 else 0)
			char_picker.disabled = is_peer_ready if is_story else (is_peer_ready and not is_peer_host)

			var target_pid: int = int(peer_id)
			char_picker.item_selected.connect(func(idx: int) -> void:
				net.request_set_story_character(target_pid, char_keys[idx])
			)
			row.add_child(char_picker)
		else:
			var char_badge := Label.new()
			char_badge.custom_minimum_size = Vector2(100, 0)
			var disp_char := "Random" if p_char == "random" or p_char.is_empty() else p_char
			char_badge.text = disp_char
			char_badge.add_theme_color_override("font_color", Color(0.65, 0.9, 0.75) if is_peer_ready else Color(0.8, 0.85, 0.92))
			char_badge.add_theme_font_size_override("font_size", 12)
			row.add_child(char_badge)

		# 3. Flashlight Role (Escape mode only)
		if not is_story:
			if raw_f_mode == "roles":
				if peer_id == my_id or is_host:
					var role_picker := OptionButton.new()
					role_picker.custom_minimum_size = Vector2(115, 28)
					role_picker.add_item("Battery Torch", 0)
					role_picker.add_item("Hand-Crank", 1)
					role_picker.add_item("Lantern", 2)
					role_picker.add_item("UV Blacklight", 3)
					role_picker.add_item("Random", 4)
					
					match p_role:
						"battery": role_picker.select(0)
						"crank": role_picker.select(1)
						"lantern": role_picker.select(2)
						"uv": role_picker.select(3)
						_: role_picker.select(4)
					
					role_picker.disabled = is_peer_ready and not is_peer_host
					var target_pid: int = int(peer_id)
					role_picker.item_selected.connect(func(idx: int) -> void:
						var r_keys: Array[String] = ["battery", "crank", "lantern", "uv", "random"]
						var chosen_r: String = r_keys[idx]
						net.request_set_role(target_pid, chosen_r)
					)
					row.add_child(role_picker)
				else:
					var role_badge := Label.new()
					role_badge.custom_minimum_size = Vector2(100, 0)
					role_badge.text = _get_role_display_name(p_role)
					role_badge.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
					role_badge.add_theme_font_size_override("font_size", 12)
					row.add_child(role_badge)
			elif raw_f_mode == "roulette":
				var secret_badge := Label.new()
				secret_badge.custom_minimum_size = Vector2(100, 0)
				secret_badge.text = "Mystery Role"
				secret_badge.add_theme_color_override("font_color", Color(0.85, 0.65, 0.95))
				secret_badge.add_theme_font_size_override("font_size", 12)
				row.add_child(secret_badge)
			else:
				var uniform_badge := Label.new()
				uniform_badge.custom_minimum_size = Vector2(100, 0)
				match raw_f_mode:
					"crank": uniform_badge.text = "Hand-Crank"
					"battery": uniform_badge.text = "Battery Torch"
					"normal": uniform_badge.text = "Standard Torch"
					"disabled": uniform_badge.text = "Pitch Black"
				uniform_badge.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
				uniform_badge.add_theme_font_size_override("font_size", 12)
				row.add_child(uniform_badge)

		# 4. Status Badge
		var status_badge := Label.new()
		status_badge.custom_minimum_size = Vector2(75, 0)
		status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if is_peer_ready:
			status_badge.text = "[ READY ]"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
		else:
			status_badge.text = "[ WAITING ]"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
		status_badge.add_theme_font_size_override("font_size", 11)
		row.add_child(status_badge)

		player_list_container.add_child(row)

	# Update Role / Character Description at bottom of Lobby
	if role_brief_card:
		role_brief_card.visible = true
	if role_desc_label:
		var my_info: Dictionary = net.players.get(my_id, {})
		var my_char := str(my_info.get("character", "random"))
		var my_char_disp := "Random" if my_char == "random" or my_char.is_empty() else my_char
		if is_story:
			var my_ready := bool(my_info.get("ready", false))
			if my_char == "random" or my_char.is_empty():
				role_desc_label.text = "Character: Random — Press READY to lock in, or pick Syazril, Aleysa, Syahirul, or Amelya."
			elif my_ready:
				role_desc_label.text = "Character Locked: %s — Press UNREADY if you want to swap character." % my_char
			else:
				role_desc_label.text = "Selected: %s — Press READY to lock this character for yourself." % my_char
		else:
			var my_role := str(my_info.get("role", "random"))
			var role_part := ""
			if raw_f_mode == "roles":
				role_part = "  •  %s: %s" % [_get_role_display_name(my_role), _get_role_desc(my_role)]
			elif raw_f_mode == "roulette":
				role_part = "  •  Mystery Roulette: Flashlight role assigned upon start."
			else:
				role_part = "  •  Flashlight: %s" % raw_f_mode.capitalize()
			role_desc_label.text = "Character: %s (Duplicates allowed)%s" % [my_char_disp, role_part]

	# Ready button styling & state (Story Co-op allows Host & Clients to Ready/Unready to lock/swap character)
	var my_info: Dictionary = net.players.get(my_id, {})
	is_local_ready = bool(my_info.get("ready", false))
	if is_host:
		ready_button.visible = is_story
		if is_story:
			ready_button.text = "UNREADY" if is_local_ready else "READY"
		start_game_button.visible = true
		
		var can_start := all_ready
		start_game_button.disabled = not can_start
		if can_start:
			if net.players.size() > 1:
				lobby_status_label.text = "All players ready! Ready to start."
			else:
				lobby_status_label.text = "Ready to start solo or wait for others."
			lobby_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			lobby_status_label.text = "Pick your character and press READY to lock in." if is_story else "Waiting for squad members to ready up..."
			lobby_status_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	else:
		start_game_button.visible = false
		ready_button.visible = true
		ready_button.text = "UNREADY" if is_local_ready else "READY"
		
		if all_ready:
			lobby_status_label.text = "Squad is ready! Waiting for host to start..."
			lobby_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			lobby_status_label.text = "Pick a character and press READY to lock in." if is_story else "Click READY when you are ready."
			lobby_status_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))


func _on_ready_button_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		is_local_ready = not is_local_ready
		if multiplayer.is_server():
			net.set_player_ready(is_local_ready)
		else:
			net.set_player_ready.rpc_id(1, is_local_ready)


func _on_start_game_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net and multiplayer.is_server():
		if net.has_method("host_start_game"):
			net.host_start_game()
		else:
			net.start_game.rpc()


func _on_leave_lobby_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.disconnect_game()
	_show_main_buttons()


# --- Network Callbacks ---
func _on_connection_succeeded() -> void:
	_show_lobby_panel()


func _on_connection_failed() -> void:
	if searching_label and join_lan_panel.visible:
		searching_label.visible = true
		searching_label.text = "Connection timed out. Check that host is active."
		searching_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		for child in lobby_list.get_children():
			if child is Button:
				child.disabled = false
				child.text = "Retry Join"
	if room_code_status_label and join_room_code_panel.visible:
		room_code_status_label.text = "Connection timed out.\nEnsure Host is running and both devices are connected."
		room_code_status_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))


func _on_server_disconnected() -> void:
	_show_main_buttons()
	if room_code_status_label:
		room_code_status_label.text = "Host closed the lobby or game ended."


# --- Microphone Calibration Fullscreen Slide ---

func _open_mic_calibration_screen(is_startup: bool = false) -> void:
	is_calib_opened_from_options = not is_startup
	_hide_all_panels()
	
	var net := get_node_or_null("/root/NetworkManager")
	var curr_thresh: float = 0.025
	var curr_sens: float = 1.0
	var skip_startup: bool = false
	if net and net.get("local_settings") != null:
		curr_thresh = float(net.local_settings.get("mic_threshold", 0.025))
		curr_sens = float(net.local_settings.get("mic_sensitivity", 1.0))
		skip_startup = bool(net.local_settings.get("skip_startup_mic_calib", false))

	if calib_threshold_slider:
		calib_threshold_slider.value = curr_thresh
	_update_threshold_label(curr_thresh)
	
	if calib_sens_slider:
		calib_sens_slider.value = curr_sens
	_update_sensitivity_label(curr_sens)

	if calib_dont_show_check:
		calib_dont_show_check.button_pressed = skip_startup

	if sliders_vbox:
		sliders_vbox.visible = false
	if manual_adjust_button:
		manual_adjust_button.text = "⚙️ Manual Adjustments ▾"

	if is_startup:
		if save_calib_button:
			save_calib_button.text = "PROCEED ➔"
	else:
		if save_calib_button:
			save_calib_button.text = "PROCEED"

	_setup_calib_microphone()
	is_auto_calibrating = false
	if calib_auto_status:
		calib_auto_status.text = "Stay quiet and click to sample & filter ambient fans/room noise."
		calib_auto_status.add_theme_color_override("font_color", Color(0.6, 0.66, 0.76))
	if calib_auto_button:
		calib_auto_button.disabled = false
		calib_auto_button.text = "🎙️ Auto-Detect Background Noise"

	if mic_calib_screen:
		mic_calib_screen.visible = true


func _open_mic_calibration_modal() -> void:
	_open_mic_calibration_screen(false)


func _close_mic_calibration_screen() -> void:
	if mic_calib_screen:
		mic_calib_screen.visible = false
	if mic_calib_modal and mic_calib_modal != mic_calib_screen:
		mic_calib_modal.visible = false
	is_auto_calibrating = false
	if is_instance_valid(calib_audio_player):
		calib_audio_player.stop()
		calib_audio_player.queue_free()
		calib_audio_player = null
	calib_capture_effect = null


func _close_mic_calibration_modal() -> void:
	_close_mic_calibration_screen()


func _setup_calib_microphone() -> void:
	if not is_instance_valid(calib_audio_player):
		calib_audio_player = AudioStreamPlayer.new()
		calib_audio_player.name = "CalibMicrophonePlayer"
		var mic_stream := AudioStreamMicrophone.new()
		calib_audio_player.stream = mic_stream
		calib_audio_player.bus = &"Record"
		add_child(calib_audio_player)
		calib_audio_player.play()

	var record_idx := AudioServer.get_bus_index("Record")
	if record_idx >= 0:
		for i in range(AudioServer.get_bus_effect_count(record_idx)):
			var eff := AudioServer.get_bus_effect(record_idx, i)
			if eff is AudioEffectCapture:
				calib_capture_effect = eff
				calib_capture_effect.clear_buffer()
				break


func _process(delta: float) -> void:
	if mic_calib_screen and mic_calib_screen.visible:
		_process_mic_calibration(delta)


func _process_mic_calibration(delta: float) -> void:
	if not calib_capture_effect:
		return

	var frames_avail := calib_capture_effect.get_frames_available()
	var rms := 0.0
	if frames_avail > 0:
		var buf := calib_capture_effect.get_buffer(frames_avail)
		var sum := 0.0
		for sample in buf:
			var s := (sample.x + sample.y) * 0.5
			sum += s * s
		rms = sqrt(sum / float(frames_avail))

	var thresh: float = calib_threshold_slider.value if calib_threshold_slider else 0.025
	var sens: float = calib_sens_slider.value if calib_sens_slider else 1.0

	# Auto-calibration sampling
	if is_auto_calibrating:
		auto_calib_timer += delta
		auto_calib_samples.append(rms)
		var remaining: float = maxf(0.0, 1.8 - auto_calib_timer)
		if calib_auto_status:
			calib_auto_status.text = "Measuring room noise... keep quiet (%.1fs)" % remaining
			calib_auto_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		if auto_calib_timer >= 1.8:
			is_auto_calibrating = false
			if calib_auto_button:
				calib_auto_button.disabled = false
				calib_auto_button.text = "🎙️ Re-Detect Background Noise"
			var avg_room := 0.0
			for s in auto_calib_samples:
				avg_room += s
			if auto_calib_samples.size() > 0:
				avg_room /= float(auto_calib_samples.size())
			var recommended_thresh := clampf(avg_room * 1.5 + 0.015, 0.005, 0.08)
			if calib_threshold_slider:
				calib_threshold_slider.value = recommended_thresh
			_update_threshold_label(recommended_thresh)
			if calib_auto_status:
				calib_auto_status.text = "Calibrated! Noise gate set to %.1f%%" % [recommended_thresh * 1000.0]
				calib_auto_status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))

	# Live progress bar calculation
	var pct: float = clampf(rms * 25.0 * sens * 100.0, 0.0, 100.0)
	if calib_progress_bar:
		calib_progress_bar.value = lerpf(calib_progress_bar.value, pct, delta * 15.0)

	if calib_meter_status:
		if rms < (thresh * 0.5):
			calib_meter_status.text = "🟢 SAFE (Silent)"
			calib_meter_status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
		elif rms < thresh:
			calib_meter_status.text = "🟢 SAFE (Room Noise Filtered)"
			calib_meter_status.add_theme_color_override("font_color", Color(0.5, 0.85, 0.7))
		elif pct > 75.0:
			calib_meter_status.text = "🔴 LOUD! (Alerting Entities!)"
			calib_meter_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		else:
			calib_meter_status.text = "🟡 TALKING (Voice Active)"
			calib_meter_status.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))


func _update_threshold_label(val: float) -> void:
	if not calib_threshold_val:
		return
	if val < 0.015:
		calib_threshold_val.text = "Low / Sensitive (%d%%)" % int(round(val * 1000.0))
		calib_threshold_val.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	elif val > 0.035:
		calib_threshold_val.text = "High / Heavy Filter (%d%%)" % int(round(val * 1000.0))
		calib_threshold_val.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
	else:
		calib_threshold_val.text = "Medium / Recommended (%d%%)" % int(round(val * 1000.0))
		calib_threshold_val.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))


func _update_sensitivity_label(val: float) -> void:
	if not calib_sens_val:
		return
	if val < 0.85:
		calib_sens_val.text = "Quiet (%.1fx)" % val
		calib_sens_val.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	elif val > 1.25:
		calib_sens_val.text = "Boosted (%.1fx)" % val
		calib_sens_val.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	else:
		calib_sens_val.text = "Normal (%.1fx)" % val
		calib_sens_val.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))


func _on_calibrate_mic_button_pressed() -> void:
	_open_mic_calibration_screen(false)


func _on_manual_adjust_button_pressed() -> void:
	if not sliders_vbox:
		return
	sliders_vbox.visible = not sliders_vbox.visible
	if manual_adjust_button:
		if sliders_vbox.visible:
			manual_adjust_button.text = "⚙️ Manual Adjustments ▴"
		else:
			manual_adjust_button.text = "⚙️ Manual Adjustments ▾"


func _on_calib_threshold_changed(val: float) -> void:
	_update_threshold_label(val)


func _on_calib_sensitivity_changed(val: float) -> void:
	_update_sensitivity_label(val)


func _on_auto_calib_button_pressed() -> void:
	is_auto_calibrating = true
	auto_calib_timer = 0.0
	auto_calib_samples.clear()
	if calib_auto_button:
		calib_auto_button.disabled = true


func _on_skip_calib_button_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net and net.get("local_settings") != null:
		var skip_again: bool = calib_dont_show_check.button_pressed if calib_dont_show_check else false
		net.local_settings["mic_calibrated"] = true
		net.local_settings["skip_startup_mic_calib"] = skip_again
		net.save_local_settings()
	_close_mic_calibration_screen()
	if is_calib_opened_from_options:
		_on_options_pressed()
	else:
		_show_main_buttons()


func _on_save_calib_button_pressed() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net and net.get("local_settings") != null:
		var th: float = calib_threshold_slider.value if calib_threshold_slider else 0.025
		var sens: float = calib_sens_slider.value if calib_sens_slider else 1.0
		var skip_again: bool = calib_dont_show_check.button_pressed if calib_dont_show_check else false
		net.local_settings["mic_threshold"] = th
		net.local_settings["mic_sensitivity"] = sens
		net.local_settings["mic_calibrated"] = true
		net.local_settings["skip_startup_mic_calib"] = skip_again
		net.save_local_settings()
	_close_mic_calibration_screen()
	if is_calib_opened_from_options:
		_on_options_pressed()
	else:
		_show_main_buttons()
