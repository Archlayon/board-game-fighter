extends Node
class_name FightNetworkSession
## ENet lobby and unreliable-ordered input exchange for rollback-driven matches.

signal session_started(is_server: bool)
signal session_ended
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_status_changed(status: String)
signal remote_input_received(peer_id: int, frame: int, buttons: int, axis_x: int, axis_y: int)

const DEFAULT_PORT: int = 27015
const MAX_PLAYERS: int = 2

var is_server: bool = false
var _last_frame_by_peer: Dictionary = {}


func host(port: int = DEFAULT_PORT, max_clients: int = MAX_PLAYERS - 1) -> Error:
	close_session()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, clampi(max_clients, 1, 8))
	if result != OK:
		connection_status_changed.emit("Server creation failed: %s" % error_string(result))
		return result
	multiplayer.multiplayer_peer = peer
	is_server = true
	_connect_multiplayer_signals()
	session_started.emit(true)
	connection_status_changed.emit("Hosting on port %d" % port)
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	close_session()
	if address.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), port)
	if result != OK:
		connection_status_changed.emit("Could not connect: %s" % error_string(result))
		return result
	multiplayer.multiplayer_peer = peer
	is_server = false
	_connect_multiplayer_signals()
	connection_status_changed.emit("Connecting to %s:%d" % [address, port])
	return OK


func close_session() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if is_server or not _last_frame_by_peer.is_empty():
		session_ended.emit()
	is_server = false
	_last_frame_by_peer.clear()


func send_local_input(frame: int, buttons: int, axis: Vector2) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var qx := clampi(roundi(axis.x * 127.0), -127, 127)
	var qy := clampi(roundi(axis.y * 127.0), -127, 127)
	if is_server:
		remote_input_received.emit(multiplayer.get_unique_id(), frame, buttons, qx, qy)
		_submit_input_rpc.rpc(frame, buttons, qx, qy)
	else:
		_submit_input_rpc.rpc_id(1, frame, buttons, qx, qy)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input_rpc(frame: int, buttons: int, axis_x: int, axis_y: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0 or (is_server and sender == multiplayer.get_unique_id()):
		return
	var previous := int(_last_frame_by_peer.get(sender, -1))
	if frame <= previous or frame > Engine.get_physics_frames() + 120:
		return
	_last_frame_by_peer[sender] = frame
	remote_input_received.emit(sender, frame, buttons, clampi(axis_x, -127, 127), clampi(axis_y, -127, 127))
	if is_server:
		_broadcast_input_rpc.rpc(sender, frame, buttons, clampi(axis_x, -127, 127), clampi(axis_y, -127, 127))


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _broadcast_input_rpc(peer_id: int, frame: int, buttons: int, axis_x: int, axis_y: int) -> void:
	remote_input_received.emit(peer_id, frame, buttons, axis_x, axis_y)


func _connect_multiplayer_signals() -> void:
	var callbacks := {
		"peer_connected": Callable(self, "_on_peer_connected"),
		"peer_disconnected": Callable(self, "_on_peer_disconnected"),
		"connected_to_server": Callable(self, "_on_connected_to_server"),
		"connection_failed": Callable(self, "_on_connection_failed"),
		"server_disconnected": Callable(self, "_on_server_disconnected"),
	}
	for signal_name in callbacks:
		var callback: Callable = callbacks[signal_name]
		if multiplayer.has_signal(signal_name) and not multiplayer.is_connected(signal_name, callback):
			multiplayer.connect(signal_name, callback)


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_last_frame_by_peer.erase(peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	connection_status_changed.emit("Connected to host")
	session_started.emit(false)


func _on_connection_failed() -> void:
	connection_status_changed.emit("Connection failed")
	close_session()


func _on_server_disconnected() -> void:
	connection_status_changed.emit("Host disconnected")
	close_session()
