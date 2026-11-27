extends Node

# --- Signals ---
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_failed()
signal connection_succeeded()
signal server_found(ip: String, port: int, server_name: String, room_code: String)
signal lobby_updated()
signal game_started()
signal upnp_completed(success: bool, external_ip: String, message: String)
signal room_code_ready(code: String)
signal signaling_status_changed(message: String)

# --- Network Constants & Config ---
const DEFAULT_PORT: int = 8910
const BROADCAST_PORT: int = 8912
const MAX_PLAYERS: int = 4
const STORY_CHARACTERS: Array[String] = ["Syazril", "Aleysa", "Syahirul", "Amelya"]

# --- Direct Room Code (Base36 IP Encoding) ---
const BASE36_CHARS: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
var current_room_code: String = ""

# --- Host Settings ---
var host_settings: Dictionary = {
	"lobby_name": "Family House",
	"player_name": "Player",
	"show_name_tags": true,
	"flashlight_mode": "normal",  # "normal", "crank", "battery", "disabled"
	"flashlight_enabled": true,
	"atmosphere": "Midnight",
	"max_players": 4
}

# --- State ---
var peer: ENetMultiplayerPeer = null
var webrtc_mp: WebRTCMultiplayerPeer = null
var signaling_client: WebRTCSignalingClient = null
var peer_connections: Dictionary = {}  # peer_id -> WebRTCPeerConnection
var is_webrtc_mode: bool = false
var pending_join_code: String = ""
var players: Dictionary = {}  # peer_id -> Dictionary { "name": String, "ready": bool }
var local_player_name: String = "Player"
var is_singleplayer: bool = false

# --- UPnP Auto-Port Forwarding State ---
var upnp_thread: Thread = null
var active_upnp: UPNP = null
var upnp_external_ip: String = ""
var upnp_status_message: String = ""

# --- Client Local Settings (Options) ---
var local_settings: Dictionary = {
	"voice_mode": "open_mic",       # "open_mic" (Voice Detection), "always_on", "ptt"
	"crosshair_enabled": true,      # true / false
	"touch_controls": "auto",       # "auto" (Mobile/Touch only), "on" (Always), "off"
	"touch_size": "Smallest",       # "Smallest", "Medium", "Large"
	"signaling_url": "wss://family-server-srkg.onrender.com",
	"mic_threshold": 0.025,         # VAD activation threshold (0.005 to 0.10)
	"mic_sensitivity": 1.0,         # Speech volume boost factor (0.5 to 2.5)
	"mic_calibrated": false,        # First-launch calibration flag
	"skip_startup_mic_calib": false # Option to never show startup calibration slide again
}
const SETTINGS_FILE_PATH: String = "user://settings.cfg"


func save_local_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("gameplay", "voice_mode", local_settings.get("voice_mode", "open_mic"))
	cfg.set_value("gameplay", "crosshair_enabled", local_settings.get("crosshair_enabled", true))
	cfg.set_value("gameplay", "touch_controls", local_settings.get("touch_controls", "auto"))
	cfg.set_value("gameplay", "touch_size", local_settings.get("touch_size", "Smallest"))
	cfg.set_value("gameplay", "mic_threshold", float(local_settings.get("mic_threshold", 0.025)))
	cfg.set_value("gameplay", "mic_sensitivity", float(local_settings.get("mic_sensitivity", 1.0)))
	cfg.set_value("gameplay", "mic_calibrated", bool(local_settings.get("mic_calibrated", false)))
	cfg.set_value("gameplay", "skip_startup_mic_calib", bool(local_settings.get("skip_startup_mic_calib", false)))
	cfg.set_value("network", "signaling_url", local_settings.get("signaling_url", ""))
	cfg.save(SETTINGS_FILE_PATH)


func load_local_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) == OK:
		local_settings["voice_mode"] = str(cfg.get_value("gameplay", "voice_mode", "open_mic"))
		local_settings["crosshair_enabled"] = bool(cfg.get_value("gameplay", "crosshair_enabled", true))
		local_settings["touch_controls"] = str(cfg.get_value("gameplay", "touch_controls", "auto"))
		local_settings["touch_size"] = str(cfg.get_value("gameplay", "touch_size", "Smallest"))
		local_settings["mic_threshold"] = float(cfg.get_value("gameplay", "mic_threshold", 0.025))
		local_settings["mic_sensitivity"] = float(cfg.get_value("gameplay", "mic_sensitivity", 1.0))
		local_settings["mic_calibrated"] = bool(cfg.get_value("gameplay", "mic_calibrated", false))
		local_settings["skip_startup_mic_calib"] = bool(cfg.get_value("gameplay", "skip_startup_mic_calib", false))
		local_settings["signaling_url"] = str(cfg.get_value("network", "signaling_url", ""))

# --- LAN Discovery State ---
var broadcaster: PacketPeerUDP = null
var listener: PacketPeerUDP = null
var is_broadcasting: bool = false
var is_listening: bool = false
var broadcast_timer: float = 0.0
var server_broadcast_name: String = "Family House"


func _ready() -> void:
	load_local_settings()
	if OS.get_name() == "Android":
		OS.request_permissions()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	# Broadcast beacon every 1 second when hosting
	if is_broadcasting and broadcaster:
		broadcast_timer += delta
		if broadcast_timer >= 1.0:
			broadcast_timer = 0.0
			_send_broadcast_packet()
	
	# Listen for incoming broadcast beacons
	if is_listening and listener:
		while listener.get_available_packet_count() > 0:
			var packet := listener.get_packet()
			var sender_ip := listener.get_packet_ip()
			var text := packet.get_string_from_utf8()
			var json := JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				var dict: Dictionary = json.data
				if dict.get("game") == "FAMILY_ESCAPE":
					var s_name: String = str(dict.get("name", "Host"))
					var s_port: int = int(dict.get("port", DEFAULT_PORT))
					var s_code: String = str(dict.get("room_code", ""))
					server_found.emit(sender_ip, s_port, s_name, s_code)

	# Poll active WebRTC peer connections
	if is_webrtc_mode:
		for pid in peer_connections:
			var pc: WebRTCPeerConnection = peer_connections[pid]
			if pc:
				pc.poll()


# --- Host Game (Direct / LAN) ---
func host_game(port: int = DEFAULT_PORT, settings: Dictionary = {}) -> Error:
	disconnect_game()
	
	if not settings.is_empty():
		for key in settings:
			host_settings[key] = settings[key]
	
	local_player_name = host_settings.get("player_name", "Host")
	var max_p: int = int(host_settings.get("max_players", MAX_PLAYERS))
	var l_name: String = str(host_settings.get("lobby_name", "Family House"))
	
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_p)
	if err != OK:
		push_error("NetworkManager: Failed to start server on port %d (Error: %s)" % [port, err])
		peer = null
		return err
	
	if multiplayer:
		multiplayer.multiplayer_peer = peer
	var host_ready := not (str(host_settings.get("game_mode", "arcade")) == "story" and not is_singleplayer)
	players[1] = { "name": local_player_name, "ready": host_ready, "role": "random", "character": "random" }
	player_connected.emit(1, players[1])
	lobby_updated.emit()
	print("NetworkManager: Server started on port %d as '%s'" % [port, local_player_name])
	
	start_broadcasting(l_name)
	start_upnp(port)
	return OK


# --- Join Game (Direct IP) ---
func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT, player_name: String = "Guest") -> Error:
	disconnect_game()
	local_player_name = player_name
	
	if address.strip_edges().is_empty():
		address = "127.0.0.1"
	
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: Failed to connect to %s:%d (Error: %s)" % [address, port, err])
		peer = null
		return err
	
	if multiplayer:
		multiplayer.multiplayer_peer = peer
	print("NetworkManager: Connecting to %s:%d as '%s'..." % [address, port, local_player_name])
	return OK


# --- Online Room Methods (WebRTC P2P via Render + ENet LAN Fallback) ---
func host_online_room(desired_code: String = "", settings: Dictionary = {}) -> Error:
	disconnect_game()

	if not settings.is_empty():
		for key in settings:
			host_settings[key] = settings[key]

	local_player_name = host_settings.get("player_name", "Host")
	var l_name: String = str(host_settings.get("lobby_name", "Family House"))

	_setup_signaling_client()

	webrtc_mp = WebRTCMultiplayerPeer.new()
	var err := webrtc_mp.create_server()
	if err != OK:
		push_error("NetworkManager: Failed to initialize WebRTCMultiplayerPeer server (Error: %s)" % err)
		webrtc_mp = null
		return err

	is_webrtc_mode = true
	multiplayer.multiplayer_peer = webrtc_mp

	var host_ready := not (str(host_settings.get("game_mode", "arcade")) == "story" and not is_singleplayer)
	players[1] = { "name": local_player_name, "ready": host_ready, "role": "random", "character": "random" }
	player_connected.emit(1, players[1])
	lobby_updated.emit()

	# Start local broadcast beacon once cloud room code is acquired
	server_broadcast_name = l_name

	# Connect to Render cloud server for 4-letter WebRTC room code
	var sig_url: String = str(local_settings.get("signaling_url", "wss://family-server-srkg.onrender.com"))
	if sig_url.is_empty():
		sig_url = "wss://family-server-srkg.onrender.com"

	signaling_status_changed.emit("Connecting to cloud server...")
	print("NetworkManager: Connecting to signaling server at %s..." % sig_url)
	signaling_client.connect_to_server(sig_url)
	return OK


func join_online_room(code: String, player_name: String = "Guest") -> Error:
	var clean_code := code.strip_edges().to_upper()
	if clean_code.is_empty():
		return ERR_INVALID_PARAMETER

	local_player_name = player_name

	# Direct IP or legacy dual-part IP code -> use direct ENet
	if clean_code.contains(".") or clean_code.contains("-"):
		return _join_enet_room(clean_code, player_name)

	# WebRTC 4-letter room code (e.g. K8SZ) via Render
	disconnect_game()
	_setup_signaling_client()

	pending_join_code = clean_code
	var sig_url: String = str(local_settings.get("signaling_url", "wss://family-server-srkg.onrender.com"))
	if sig_url.is_empty():
		sig_url = "wss://family-server-srkg.onrender.com"

	signaling_status_changed.emit("Connecting to cloud server...")
	print("NetworkManager: Connecting to signaling server at %s to join [%s]..." % [sig_url, clean_code])
	signaling_client.connect_to_server(sig_url)
	return OK


func _join_enet_room(clean_code: String, player_name: String) -> Error:
	# If the code contains dots, it is a direct IP address
	if clean_code.contains("."):
		var target_ip := clean_code
		var target_port := DEFAULT_PORT
		if clean_code.contains(":"):
			var parts := clean_code.split(":")
			target_ip = parts[0]
			if parts.size() > 1 and parts[1].is_valid_int():
				target_port = int(parts[1])
		print("NetworkManager: Joining direct IP: %s:%d" % [target_ip, target_port])
		signaling_status_changed.emit("Connecting to IP %s..." % target_ip)
		return join_game(target_ip, target_port, player_name)

	var my_ips := IP.get_local_addresses()

	# Dual-part Room Code: [PUBLIC]-[LOCAL] (e.g. 1E0UVS0-1HGE10B)
	if clean_code.contains("-"):
		var parts := clean_code.split("-")
		var pub_ip := code_to_ip(parts[0])
		var loc_ip := code_to_ip(parts[1])

		# 1. Exact same PC (for playtesting two instances on one PC)
		if my_ips.has(loc_ip) or loc_ip.begins_with("127."):
			print("NetworkManager: Same PC detected (%s). Connecting via 127.0.0.1..." % loc_ip)
			signaling_status_changed.emit("Connecting to local PC...")
			return join_game("127.0.0.1", DEFAULT_PORT, player_name)

		# 2. Same local Wi-Fi / Hotspot subnet
		var loc_prefix := _get_subnet_prefix(loc_ip)
		var on_same_subnet := false
		for ip in my_ips:
			if not ip.contains(":") and not ip.begins_with("127."):
				if _get_subnet_prefix(ip) == loc_prefix:
					on_same_subnet = true
					break

		if on_same_subnet:
			print("NetworkManager: Local Wi-Fi host detected (%s). Connecting directly..." % loc_ip)
			signaling_status_changed.emit("Connecting via local Wi-Fi...")
			return join_game(loc_ip, DEFAULT_PORT, player_name)

		# 3. Remote Internet player -> connect to Public IP
		print("NetworkManager: Internet connection to host %s..." % pub_ip)
		signaling_status_changed.emit("Connecting via Internet (%s)..." % pub_ip)
		return join_game(pub_ip, DEFAULT_PORT, player_name)

	# Single-part Room Code
	var target_ip := code_to_ip(clean_code)
	if target_ip.is_empty():
		push_error("NetworkManager: Invalid Room Code %s" % clean_code)
		signaling_status_changed.emit("Invalid room code format.")
		connection_failed.emit()
		return ERR_INVALID_PARAMETER

	if my_ips.has(target_ip):
		target_ip = "127.0.0.1"

	print("NetworkManager: Single Room Code [%s] -> Connecting to %s" % [clean_code, target_ip])
	signaling_status_changed.emit("Connecting to %s..." % target_ip)
	return join_game(target_ip, DEFAULT_PORT, player_name)


# --- WebRTC Helper & Signaling Methods ---
func _setup_signaling_client() -> void:
	if signaling_client:
		return
	signaling_client = WebRTCSignalingClient.new()
	signaling_client.name = "WebRTCSignalingClient"
	add_child(signaling_client)
	signaling_client.connected_to_server.connect(_on_signaling_connected)
	signaling_client.connection_error.connect(_on_signaling_error)
	signaling_client.room_created.connect(_on_signaling_room_created)
	signaling_client.room_joined.connect(_on_signaling_room_joined)
	signaling_client.peer_joined.connect(_on_signaling_peer_joined)
	signaling_client.peer_left.connect(_on_signaling_peer_left)
	signaling_client.offer_received.connect(_on_signaling_offer_received)
	signaling_client.answer_received.connect(_on_signaling_answer_received)
	signaling_client.candidate_received.connect(_on_signaling_candidate_received)
	signaling_client.room_closed.connect(_on_signaling_room_closed)


func _create_peer_connection(target_id: int) -> WebRTCPeerConnection:
	var pc := WebRTCPeerConnection.new()
	pc.initialize({
		"iceServers": [
			{ "urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302", "stun:stun2.l.google.com:19302"] },
			{
				"urls": ["turn:openrelay.metered.ca:80", "turn:openrelay.metered.ca:443"],
				"username": "openrelayproject",
				"credential": "openrelayproject"
			}
		]
	})
	pc.session_description_created.connect(func(type: String, sdp: String) -> void:
		pc.set_local_description(type, sdp)
		if type == "offer":
			signaling_client.send_offer(target_id, sdp)
		elif type == "answer":
			signaling_client.send_answer(target_id, sdp)
	)
	pc.ice_candidate_created.connect(func(media: String, index: int, c_name: String) -> void:
		signaling_client.send_candidate(target_id, media, index, c_name)
	)
	return pc


func _on_signaling_connected() -> void:
	if multiplayer.is_server() and is_webrtc_mode:
		signaling_status_changed.emit("Online Cloud Connected. Creating Room...")
		signaling_client.create_room("", local_player_name)
	elif not multiplayer.is_server() and not pending_join_code.is_empty():
		signaling_status_changed.emit("Joining Room %s..." % pending_join_code)
		signaling_client.join_room(pending_join_code, local_player_name)
		pending_join_code = ""


func _on_signaling_error(err_msg: String) -> void:
	print("NetworkManager Signaling Error: %s" % err_msg)
	signaling_status_changed.emit("Cloud: %s" % err_msg)
	if not multiplayer.is_server():
		connection_failed.emit()


func _on_signaling_room_created(code: String) -> void:
	current_room_code = code
	room_code_ready.emit(current_room_code)
	start_broadcasting(server_broadcast_name)
	lobby_updated.emit()
	print("NetworkManager: WebRTC Online Room Code active: [%s]" % current_room_code)


func _on_signaling_room_joined(code: String, my_id: int) -> void:
	current_room_code = code
	webrtc_mp = WebRTCMultiplayerPeer.new()
	var err := webrtc_mp.create_client(my_id)
	if err != OK:
		push_error("NetworkManager: Failed to initialize WebRTCMultiplayerPeer client (Error: %s)" % err)
		webrtc_mp = null
		signaling_status_changed.emit("Failed to create WebRTC client peer.")
		connection_failed.emit()
		return

	is_webrtc_mode = true
	multiplayer.multiplayer_peer = webrtc_mp

	print("NetworkManager: Joined room [%s] as peer #%d. Connecting to Host (1)..." % [code, my_id])
	signaling_status_changed.emit("Connecting P2P to Host...")
	var pc := _create_peer_connection(1)
	peer_connections[1] = pc
	webrtc_mp.add_peer(pc, 1)


func _on_signaling_peer_joined(peer_id: int, peer_name: String) -> void:
	if not multiplayer.is_server() or not is_webrtc_mode or webrtc_mp == null:
		return
	print("NetworkManager: Guest #%d ('%s') entered room. Initiating WebRTC peer connection..." % [peer_id, peer_name])
	var pc := _create_peer_connection(peer_id)
	peer_connections[peer_id] = pc
	webrtc_mp.add_peer(pc, peer_id)
	pc.create_offer()


func _on_signaling_peer_left(peer_id: int) -> void:
	print("NetworkManager: WebRTC peer #%d left." % peer_id)
	if peer_connections.has(peer_id):
		peer_connections[peer_id].close()
		peer_connections.erase(peer_id)
	if webrtc_mp and webrtc_mp.has_peer(peer_id):
		webrtc_mp.remove_peer(peer_id)


func _on_signaling_offer_received(from_id: int, sdp: String) -> void:
	print("NetworkManager: Received WebRTC offer from #%d" % from_id)
	if peer_connections.has(from_id):
		peer_connections[from_id].set_remote_description("offer", sdp)


func _on_signaling_answer_received(from_id: int, sdp: String) -> void:
	print("NetworkManager: Received WebRTC answer from #%d" % from_id)
	if peer_connections.has(from_id):
		peer_connections[from_id].set_remote_description("answer", sdp)


func _on_signaling_candidate_received(from_id: int, media: String, index: int, c_name: String) -> void:
	if peer_connections.has(from_id):
		peer_connections[from_id].add_ice_candidate(media, index, c_name)


func _on_signaling_room_closed(reason: String) -> void:
	print("NetworkManager: Signaling room closed: %s" % reason)
	signaling_status_changed.emit(reason)
	if not multiplayer.is_server():
		disconnect_game()
		server_disconnected.emit()


# --- Disconnect / Reset ---
func disconnect_game() -> void:
	stop_broadcasting()
	stop_listening()
	if active_upnp:
		active_upnp.delete_port_mapping(DEFAULT_PORT, "UDP")
		active_upnp = null
	if upnp_thread and upnp_thread.is_alive():
		upnp_thread.wait_to_finish()
	upnp_external_ip = ""
	upnp_status_message = ""
	current_room_code = ""
	pending_join_code = ""

	if signaling_client:
		signaling_client.disconnect_from_server()
	for pid in peer_connections:
		var pc: WebRTCPeerConnection = peer_connections[pid]
		if pc:
			pc.close()
	peer_connections.clear()

	if multiplayer and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	peer = null
	webrtc_mp = null
	is_webrtc_mode = false
	players.clear()


# --- Direct Room Code (IP Encoding) Helpers ---
func ip_to_code(ip_str: String) -> String:
	var parts := ip_str.split(".")
	if parts.size() != 4:
		return ""
	var num: int = (int(parts[0]) * 16777216) + (int(parts[1]) * 65536) + (int(parts[2]) * 256) + int(parts[3])
	return _int_to_base36(num)


func code_to_ip(code_str: String) -> String:
	var clean := code_str.strip_edges().to_upper()
	if clean.is_empty():
		return ""
	var num := _base36_to_int(clean)
	if num <= 0:
		return ""
	var a: int = (num >> 24) & 255
	var b: int = (num >> 16) & 255
	var c: int = (num >> 8) & 255
	var d: int = num & 255
	return "%d.%d.%d.%d" % [a, b, c, d]


func _int_to_base36(val: int) -> String:
	if val <= 0:
		return "0"
	var res := ""
	var cur: int = val
	while cur > 0:
		var rem: int = cur % 36
		res = BASE36_CHARS[rem] + res
		cur = cur / 36
	return res


func _base36_to_int(str_val: String) -> int:
	var res: int = 0
	for i in range(str_val.length()):
		var ch := str_val[i]
		var idx := BASE36_CHARS.find(ch)
		if idx == -1:
			return -1
		res = res * 36 + idx
	return res


func _get_subnet_prefix(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() >= 3:
		return "%s.%s.%s." % [parts[0], parts[1], parts[2]]
	return ip


func _get_local_ip() -> String:
	var candidates: Array[String] = []
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			candidates.append(address)

	# 1. Prioritize active subnet matching user's active Wi-Fi router (192.168.0.x)
	for cand in candidates:
		if cand.begins_with("192.168.0."):
			return cand

	# 2. Any other 192.168.x.x except 192.168.1.1 (common disconnected virtual adapter)
	for cand in candidates:
		if cand.begins_with("192.168.") and cand != "192.168.1.1":
			return cand

	# 3. Any private network address except 192.168.1.1
	for cand in candidates:
		if cand != "192.168.1.1":
			return cand

	# 4. Fallback to any detected candidate
	if not candidates.is_empty():
		return candidates[0]

	return "127.0.0.1"


func _get_best_host_ip() -> String:
	return _get_local_ip()


# --- UPnP Auto-Port Forwarding Methods ---
func start_upnp(port: int = DEFAULT_PORT) -> void:
	if upnp_thread and upnp_thread.is_alive():
		return
	upnp_status_message = "Discovering router for online play..."
	upnp_thread = Thread.new()
	upnp_thread.start(_run_upnp_discovery.bind(port))


func _run_upnp_discovery(port: int) -> void:
	var upnp := UPNP.new()
	var err := upnp.discover(2000, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS:
		err = upnp.discover()

	if err != UPNP.UPNP_RESULT_SUCCESS:
		var err_msg := "UPnP unavailable (LAN / Hotspot active)."
		call_deferred("_on_upnp_finished", false, "", err_msg, null)
		return

	var gw := upnp.get_gateway()
	if not gw or not gw.is_valid_gateway():
		var err_msg := "No UPnP gateway found (LAN / Hotspot active)."
		call_deferred("_on_upnp_finished", false, "", err_msg, null)
		return

	var map_udp := upnp.add_port_mapping(port, port, "FamilyHorrorGame", "UDP")
	if map_udp != UPNP.UPNP_RESULT_SUCCESS:
		var err_msg := "Router rejected port mapping %d (LAN / Hotspot active)." % port
		call_deferred("_on_upnp_finished", false, "", err_msg, null)
		return

	var ext_ip: String = upnp.query_external_address()
	if ext_ip.is_empty():
		ext_ip = "Online"

	var ok_msg := "Online port forwarded! Public IP: %s (Port: %d)" % [ext_ip, port]
	call_deferred("_on_upnp_finished", true, ext_ip, ok_msg, upnp)


func _on_upnp_finished(success: bool, ext_ip: String, msg: String, upnp_obj: UPNP) -> void:
	if upnp_thread and upnp_thread.is_started():
		upnp_thread.wait_to_finish()
	active_upnp = upnp_obj
	upnp_external_ip = ext_ip
	upnp_status_message = msg
	upnp_completed.emit(success, ext_ip, msg)
	print("NetworkManager UPnP: %s" % msg)

	if multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server() and success and not ext_ip.is_empty() and ext_ip != "Online":
		var local_ip := _get_local_ip()
		var pub_code := ip_to_code(ext_ip)
		var loc_code := ip_to_code(local_ip)
		current_room_code = "%s-%s" % [pub_code, loc_code]
		room_code_ready.emit(current_room_code)
		lobby_updated.emit()
		print("NetworkManager: Dual Room Code active: [%s] (Public: %s, Local: %s)" % [current_room_code, ext_ip, local_ip])


# --- LAN Discovery Methods ---
func start_broadcasting(lobby_name: String = "Family House") -> void:
	stop_broadcasting()
	server_broadcast_name = lobby_name
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	is_broadcasting = true
	_send_broadcast_packet()
	print("NetworkManager: Auto-discovery broadcast active on port %d" % BROADCAST_PORT)


func stop_broadcasting() -> void:
	is_broadcasting = false
	if broadcaster:
		broadcaster.close()
		broadcaster = null


func _send_broadcast_packet() -> void:
	if broadcaster and is_broadcasting:
		var data := {
			"game": "FAMILY_ESCAPE",
			"name": server_broadcast_name,
			"port": DEFAULT_PORT,
			"room_code": current_room_code
		}
		var json_bytes := JSON.stringify(data).to_utf8_buffer()
		broadcaster.put_packet(json_bytes)


func start_listening() -> void:
	stop_listening()
	listener = PacketPeerUDP.new()
	var err := listener.bind(BROADCAST_PORT)
	if err != OK:
		push_warning("NetworkManager: Could not bind discovery listener on port %d (Error: %s)" % [BROADCAST_PORT, err])
		listener = null
		return
	is_listening = true
	print("NetworkManager: Listening for local games on port %d..." % BROADCAST_PORT)


func stop_listening() -> void:
	is_listening = false
	if listener:
		listener.close()
		listener = null


# --- Host Settings & Player Info Replication RPCs ---
@rpc("authority", "call_local", "reliable")
func sync_host_settings(settings: Dictionary) -> void:
	host_settings = settings
	var cur_scene := get_tree().current_scene
	if cur_scene and cur_scene.has_method("_apply_host_environment_settings"):
		cur_scene._apply_host_environment_settings()
	lobby_updated.emit()


func update_host_match_settings(new_settings: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	for key in new_settings:
		host_settings[key] = new_settings[key]
	sync_host_settings.rpc(host_settings)
	lobby_updated.emit()


@rpc("any_peer", "reliable")
func send_player_info(p_name: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if not players.has(sender_id):
		players[sender_id] = {}
	players[sender_id]["name"] = p_name
	if not players[sender_id].has("ready"):
		players[sender_id]["ready"] = false if str(host_settings.get("game_mode", "arcade")) == "story" else (sender_id == 1)
	if not players[sender_id].has("role"):
		players[sender_id]["role"] = "random"
	if not players[sender_id].has("character"):
		players[sender_id]["character"] = "random"
	sync_players.rpc(players)
	player_connected.emit(sender_id, players[sender_id])
	lobby_updated.emit()
	print("NetworkManager: Registered player %d as '%s'" % [sender_id, p_name])


@rpc("any_peer", "reliable")
func set_player_ready(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if players.has(sender_id):
		var g_mode: String = str(host_settings.get("game_mode", "arcade"))
		if is_ready and g_mode == "story":
			var chosen_char: String = str(players[sender_id].get("character", "random"))
			if chosen_char in STORY_CHARACTERS and _is_story_character_taken_by_other(chosen_char, sender_id):
				players[sender_id]["character"] = "random"
				players[sender_id]["ready"] = false
				sync_players.rpc(players)
				lobby_updated.emit()
				return
		players[sender_id]["ready"] = is_ready
		sync_players.rpc(players)
		lobby_updated.emit()
		print("NetworkManager: Player %d ready status set to %s" % [sender_id, is_ready])


func _is_story_character_taken_by_other(char_name: String, exclude_peer_id: int) -> bool:
	for pid in players:
		if int(pid) == exclude_peer_id:
			continue
		var p_info: Dictionary = players[pid]
		if str(p_info.get("character", "random")) == char_name:
			return true
	return false


func request_set_story_character(target_peer_id: int, char_name: String) -> void:
	if multiplayer.is_server():
		_apply_story_character(target_peer_id, char_name)
	else:
		_server_set_story_character.rpc_id(1, target_peer_id, char_name)


func request_set_character(target_peer_id: int, char_name: String) -> void:
	request_set_story_character(target_peer_id, char_name)


@rpc("any_peer", "reliable")
func _server_set_story_character(target_peer_id: int, char_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if sender_id == target_peer_id:
		_apply_story_character(target_peer_id, char_name)


func _apply_story_character(target_peer_id: int, char_name: String) -> void:
	if not players.has(target_peer_id):
		return
	var g_mode: String = str(host_settings.get("game_mode", "arcade"))
	var is_story := (g_mode == "story")

	# Locked once ready until player presses Unready
	# In story mode, locked when ready. In escape mode, host is ready by default but can freely change character.
	if is_story and bool(players[target_peer_id].get("ready", false)):
		return
	elif not is_story and target_peer_id != 1 and bool(players[target_peer_id].get("ready", false)):
		return

	if char_name != "random" and not (char_name in STORY_CHARACTERS):
		return
	# Enforce unique character ONLY in story mode! In escape mode, duplicate characters are allowed.
	if is_story and char_name in STORY_CHARACTERS and _is_story_character_taken_by_other(char_name, target_peer_id):
		return

	players[target_peer_id]["character"] = char_name
	sync_players.rpc(players)
	lobby_updated.emit()
	print("NetworkManager: Player %d character set to '%s' (mode: %s)" % [target_peer_id, char_name, g_mode])


func request_set_role(target_peer_id: int, role_name: String) -> void:
	if multiplayer.is_server():
		_apply_role(target_peer_id, role_name)
	else:
		_server_set_player_role.rpc_id(1, target_peer_id, role_name)


@rpc("any_peer", "reliable")
func _server_set_player_role(target_peer_id: int, role_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	# Only allow if sender is host (peer 1) OR sender is setting their own role
	if sender_id == 1 or sender_id == target_peer_id:
		_apply_role(target_peer_id, role_name)


func _apply_role(target_peer_id: int, role_name: String) -> void:
	if players.has(target_peer_id):
		players[target_peer_id]["role"] = role_name
		sync_players.rpc(players)
		lobby_updated.emit()
		print("NetworkManager: Player %d role set to '%s'" % [target_peer_id, role_name])


@rpc("authority", "call_local", "reliable")
func sync_players(all_players: Dictionary) -> void:
	players = all_players
	lobby_updated.emit()


func host_start_game() -> void:
	if not multiplayer.is_server():
		return
	_resolve_roles_before_start()
	start_game.rpc(players)


@rpc("authority", "call_local", "reliable")
func start_game(synced_players: Dictionary = {}) -> void:
	if not synced_players.is_empty():
		players = synced_players
	elif multiplayer.is_server():
		_resolve_roles_before_start()
	stop_broadcasting()
	game_started.emit()
	var g_mode: String = str(host_settings.get("game_mode", "arcade"))
	if g_mode == "story":
		get_tree().change_scene_to_file("res://scenes/story_drive.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _resolve_roles_before_start() -> void:
	var g_mode: String = str(host_settings.get("game_mode", "arcade"))
	if g_mode == "story":
		var claimed_chars: Array[String] = []
		for pid in players:
			var c_name: String = str(players[pid].get("character", "random"))
			if c_name in STORY_CHARACTERS and not (c_name in claimed_chars):
				claimed_chars.append(c_name)
		var char_pool: Array[String] = []
		for c_name in STORY_CHARACTERS:
			if not (c_name in claimed_chars):
				char_pool.append(c_name)
		char_pool.shuffle()
		if char_pool.is_empty():
			char_pool = STORY_CHARACTERS.duplicate()
			char_pool.shuffle()
		var c_idx: int = 0
		var assigned: Array[String] = []
		for pid in players:
			var c_name: String = str(players[pid].get("character", "random"))
			if c_name in STORY_CHARACTERS and not (c_name in assigned):
				assigned.append(c_name)
			else:
				var picked: String = char_pool[c_idx % char_pool.size()]
				players[pid]["character"] = picked
				assigned.append(picked)
				c_idx += 1
		return

	# In Escape mode, resolve any characters left as "random" or empty.
	# Duplicate characters ARE allowed in Escape mode, so each unselected player gets a random character!
	for pid in players:
		var c_name: String = str(players[pid].get("character", "random"))
		if not (c_name in STORY_CHARACTERS):
			players[pid]["character"] = STORY_CHARACTERS[randi() % STORY_CHARACTERS.size()]

	var flash_mode: String = str(host_settings.get("flashlight_mode", "roles"))
	var all_roles := ["battery", "crank", "lantern", "uv"]
	
	if flash_mode == "roulette":
		# Full random mystery roulette: deal 1 unique role to each player randomly
		var available := all_roles.duplicate()
		available.shuffle()
		var idx: int = 0
		for pid in players:
			players[pid]["role"] = available[idx % available.size()]
			idx += 1
	elif flash_mode == "roles":
		# Squad Roles: Resolve any players that picked "random"
		var claimed: Array[String] = []
		for pid in players:
			var r: String = str(players[pid].get("role", "random"))
			if r in all_roles:
				claimed.append(r)
		
		var pool: Array[String] = []
		for r in all_roles:
			if not r in claimed:
				pool.append(r)
		pool.shuffle()
		if pool.is_empty():
			pool = all_roles.duplicate()
			pool.shuffle()
		
		var pool_idx: int = 0
		for pid in players:
			var r: String = str(players[pid].get("role", "random"))
			if r == "random" or not (r in all_roles):
				players[pid]["role"] = pool[pool_idx % pool.size()]
				pool_idx += 1
	else:
		# Uniform modes ("crank", "battery", "normal", "disabled")
		for pid in players:
			players[pid]["role"] = flash_mode


func are_all_players_ready() -> bool:
	if players.is_empty():
		return false
	for pid in players:
		if not players[pid].get("ready", false):
			return false
	return true


# --- Internal Peer Callbacks ---
func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected with ID: %d" % id)
	if multiplayer.is_server():
		if not players.has(id):
			players[id] = { "name": "Player_%d" % id, "ready": false, "role": "random", "character": "random" }
		sync_players.rpc(players)
		sync_host_settings.rpc_id(id, host_settings)
		lobby_updated.emit()
	else:
		if id == 1:
			print("NetworkManager: Client connected to Host (peer 1).")
			stop_listening()
			connection_succeeded.emit()
			send_player_info.rpc_id(1, local_player_name)


func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected: %d" % id)
	if players.has(id):
		players.erase(id)
	if multiplayer.is_server():
		sync_players.rpc(players)
	player_disconnected.emit(id)
	lobby_updated.emit()


func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	print("NetworkManager: Connected to server successfully. My ID: %d" % my_id)
	stop_listening()
	connection_succeeded.emit()
	send_player_info.rpc_id(1, local_player_name)


func _on_connection_failed() -> void:
	print("NetworkManager: Failed to connect to server.")
	disconnect_game()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("NetworkManager: Server closed the connection.")
	disconnect_game()
	server_disconnected.emit()
