class_name NetSession
extends Node
## One multiplayer session: hosting or joining a shared room. Lives under the
## Game autoload so it survives scene changes.
##
## Two ways to connect, same game on top (Godot's high-level multiplayer):
##   Direct : host on a port, or join by IP address and port (ENet). Works on a
##            LAN, or over the internet if the host forwards the port.
##   Steam  : the host opens a friends-only Steam lobby and invites friends
##            from the Steam overlay; accepting the invite (or "Join game" in
##            the friends list, or launching with +connect_lobby) joins it.
##            With GodotSteam's SteamMultiplayerPeer installed, traffic goes
##            through Steam's relay (no port forwarding). Without it, the
##            lobby passes the host's address and players connect directly.
##
## Up to MAX_PLAYERS in a room, host included.

signal connected            ## we're in a room (hosting, or joined)
signal failed(reason: String)
signal ended(reason: String)  ## the session closed (we left, or the host did)
signal status_changed(text: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
const LOBBY_FRIENDS_ONLY := 1       ## Steam.LobbyType: friends only
const RESULT_OK := 1                ## Steam.Result.RESULT_OK
const ENTER_SUCCESS := 1            ## Steam.ChatRoomEnterResponse: success

enum Mode { NONE, DIRECT, STEAM }

var mode := Mode.NONE
var is_host := false
var lobby_id := 0
## What to tell friends to connect: addresses for direct, or "Steam lobby".
var address_text := ""
var status := ""

var _steam: Object = null


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(func() -> void: _fail("Couldn't reach the host."))
	multiplayer.server_disconnected.connect(func() -> void: _end("The host left the room."))


## Hooks up Steam lobbies once Steam is running.
func use_steam(steam: Object) -> void:
	_steam = steam
	if _steam == null:
		return
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("join_requested", _on_join_requested)


func steam_available() -> bool:
	return _steam != null


## True when Steam's relay is installed (GodotSteam's MultiplayerPeer).
static func steam_relay_available() -> bool:
	return ClassDB.class_exists("SteamMultiplayerPeer")


func in_room() -> bool:
	return mode != Mode.NONE


# --------------------------------------------------------------------------
# Direct (ENet)
# --------------------------------------------------------------------------

func host_direct(port := DEFAULT_PORT) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		_fail("Couldn't open port %d (error %d). Is another game using it?" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.DIRECT
	is_host = true
	address_text = ", ".join(local_addresses().map(func(a: String) -> String: return "%s:%d" % [a, port]))
	_set_status("Hosting. Friends join at %s" % address_text)
	print("[net] Hosting a room on port %d (%s)." % [port, address_text])
	connected.emit()


## `address` is "ip" or "ip:port".
func join_direct(address: String) -> void:
	leave()
	var host := address.strip_edges()
	var port := DEFAULT_PORT
	if host.count(":") == 1:
		port = int(host.get_slice(":", 1))
		host = host.get_slice(":", 0)
	if host == "":
		_fail("Type the host's address first.")
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		_fail("Couldn't start connecting (error %d)." % err)
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.DIRECT
	is_host = false
	address_text = "%s:%d" % [host, port]
	_set_status("Connecting to %s..." % address_text)
	print("[net] Joining %s." % address_text)


## This machine's IPv4 addresses (not loopback), for telling friends where to join.
static func local_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	if out.is_empty():
		out.append("127.0.0.1")
	return out


# --------------------------------------------------------------------------
# Steam lobbies
# --------------------------------------------------------------------------

## Opens a friends-only lobby; once it's up, the Steam invite overlay opens.
func host_steam() -> void:
	if _steam == null:
		_fail("Steam isn't running.")
		return
	leave()
	_set_status("Opening a Steam lobby...")
	_steam.call("createLobby", LOBBY_FRIENDS_ONLY, MAX_PLAYERS)


func invite_friends() -> void:
	if _steam != null and lobby_id != 0:
		_steam.call("activateGameOverlayInviteDialog", lobby_id)


func join_steam_lobby(id: int) -> void:
	if _steam == null:
		_fail("Steam isn't running.")
		return
	leave()
	_set_status("Joining your friend's room...")
	_steam.call("joinLobby", id)


func _on_lobby_created(result: int, id: int) -> void:
	if result != RESULT_OK:
		_fail("Steam couldn't open a lobby (result %d)." % result)
		return
	lobby_id = id
	_steam.call("setLobbyData", id, "game", "bighead")
	is_host = true
	mode = Mode.STEAM
	if steam_relay_available():
		var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
		peer.call("create_host", 0)
		peer.set("server_relay", true)
		multiplayer.multiplayer_peer = peer
		_steam.call("setLobbyData", id, "transport", "relay")
	else:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS - 1)
		if err != OK:
			_fail("Couldn't open port %d (error %d)." % [DEFAULT_PORT, err])
			return
		multiplayer.multiplayer_peer = peer
		_steam.call("setLobbyData", id, "transport", "direct")
		_steam.call("setLobbyData", id, "address", "%s:%d" % [local_addresses()[0], DEFAULT_PORT])
	address_text = "Steam lobby"
	_set_status("Room open. Invite friends from the Steam overlay.")
	print("[net] Steam lobby %d open (%s)." % [id, "relay" if steam_relay_available() else "direct"])
	connected.emit()
	invite_friends()


func _on_join_requested(id: int, friend_id: int) -> void:
	print("[net] Invited by %s: joining lobby %d." % [str(_steam.call("getFriendPersonaName", friend_id)), id])
	join_steam_lobby(id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_SUCCESS:
		_fail("Couldn't join that room (it may be full or closed).")
		return
	var owner := int(_steam.call("getLobbyOwner", id))
	if owner == int(_steam.call("getSteamID")):
		return  # our own lobby: we're already hosting
	lobby_id = id
	mode = Mode.STEAM
	is_host = false
	if str(_steam.call("getLobbyData", id, "transport")) == "relay" and steam_relay_available():
		var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
		peer.call("create_client", owner, 0)
		peer.set("server_relay", true)
		multiplayer.multiplayer_peer = peer
		_set_status("Connecting through Steam...")
	else:
		var address := str(_steam.call("getLobbyData", id, "address"))
		join_direct(address)
		mode = Mode.STEAM
		lobby_id = id


# --------------------------------------------------------------------------
# Leaving
# --------------------------------------------------------------------------

func leave() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	mode = Mode.NONE
	is_host = false
	address_text = ""


func _on_connected_to_server() -> void:
	_set_status("Connected.")
	print("[net] Connected to the room as player %d." % multiplayer.get_unique_id())
	connected.emit()


func _fail(reason: String) -> void:
	print("[net] %s" % reason)
	leave()
	_set_status(reason)
	failed.emit(reason)


func _end(reason: String) -> void:
	print("[net] %s" % reason)
	leave()
	ended.emit(reason)


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)
