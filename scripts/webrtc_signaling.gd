class_name WebRTCSignalingClient
extends Node

# --- Signals ---
signal connected_to_server()
signal connection_error(error_msg: String)
signal room_created(code: String)
signal room_joined(code: String, my_id: int)
signal peer_joined(peer_id: int, peer_name: String)
signal peer_left(peer_id: int)
signal offer_received(from_id: int, sdp: String)
signal answer_received(from_id: int, sdp: String)
signal candidate_received(from_id: int, media: String, index: int, name: String)
signal room_closed(reason: String)

var ws_peer: WebSocketPeer = null
var current_url: String = ""
var is_connected_to_ws: bool = false
var pending_action: Dictionary = {}


func _process(_delta: float) -> void:
	if not ws_peer:
		return

	ws_peer.poll()
	var state := ws_peer.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_ws:
			is_connected_to_ws = true
			connected_to_server.emit()
			if not pending_action.is_empty():
				_send_json(pending_action)
				pending_action.clear()

		while ws_peer.get_available_packet_count() > 0:
			var packet := ws_peer.get_packet()
			var text := packet.get_string_from_utf8()
			var json := JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				_handle_signaling_message(json.data as Dictionary)

	elif state == WebSocketPeer.STATE_CLOSED:
		var code := ws_peer.get_close_code()
		var reason := ws_peer.get_close_reason()
		if is_connected_to_ws:
			is_connected_to_ws = false
			room_closed.emit("Signaling connection closed (%d: %s)" % [code, reason])
		else:
			connection_error.emit("Failed to connect to signaling server at %s" % current_url)
		ws_peer = null


func connect_to_server(url: String) -> Error:
	disconnect_from_server()
	current_url = url
	ws_peer = WebSocketPeer.new()
	var err := ws_peer.connect_to_url(url)
	if err != OK:
		connection_error.emit("Failed to connect to signaling server at %s" % url)
		ws_peer = null
	return err


func disconnect_from_server() -> void:
	is_connected_to_ws = false
	pending_action.clear()
	if ws_peer:
		if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws_peer.close(1000, "Normal Closure")
		ws_peer = null


func create_room(desired_code: String = "", host_name: String = "Host") -> void:
	var msg := {
		"type": "create_room",
		"code": desired_code,
		"name": host_name
	}
	if is_connected_to_ws:
		_send_json(msg)
	else:
		pending_action = msg


func join_room(room_code: String, player_name: String = "Guest") -> void:
	var msg := {
		"type": "join_room",
		"code": room_code,
		"name": player_name
	}
	if is_connected_to_ws:
		_send_json(msg)
	else:
		pending_action = msg


func send_offer(target_id: int, sdp: String) -> void:
	_send_json({
		"type": "offer",
		"target": target_id,
		"sdp": sdp
	})


func send_answer(target_id: int, sdp: String) -> void:
	_send_json({
		"type": "answer",
		"target": target_id,
		"sdp": sdp
	})


func send_candidate(target_id: int, media: String, index: int, name: String) -> void:
	_send_json({
		"type": "candidate",
		"target": target_id,
		"media": media,
		"index": index,
		"name": name
	})


func _send_json(dict: Dictionary) -> void:
	if ws_peer and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var txt := JSON.stringify(dict)
		ws_peer.send_text(txt)


func _handle_signaling_message(msg: Dictionary) -> void:
	var type_str: String = str(msg.get("type", ""))

	match type_str:
		"room_created":
			var code: String = str(msg.get("code", ""))
			room_created.emit(code)

		"room_joined":
			var code: String = str(msg.get("code", ""))
			var my_id: int = int(msg.get("peer_id", 2))
			room_joined.emit(code, my_id)

		"peer_joined":
			var p_id: int = int(msg.get("peer_id", 0))
			var p_name: String = str(msg.get("name", "Player"))
			peer_joined.emit(p_id, p_name)

		"peer_left":
			var p_id: int = int(msg.get("peer_id", 0))
			peer_left.emit(p_id)

		"offer":
			var from_id: int = int(msg.get("from", 1))
			var sdp: String = str(msg.get("sdp", ""))
			offer_received.emit(from_id, sdp)

		"answer":
			var from_id: int = int(msg.get("from", 2))
			var sdp: String = str(msg.get("sdp", ""))
			answer_received.emit(from_id, sdp)

		"candidate":
			var from_id: int = int(msg.get("from", 1))
			var media: String = str(msg.get("media", ""))
			var index: int = int(msg.get("index", 0))
			var c_name: String = str(msg.get("name", ""))
			candidate_received.emit(from_id, media, index, c_name)

		"room_closed":
			var reason: String = str(msg.get("message", "Room closed by host."))
			room_closed.emit(reason)

		"error":
			var err_msg: String = str(msg.get("message", "Signaling error"))
			connection_error.emit(err_msg)
