class_name SteamIdentity
extends IdentityPort
## IdentityPort backed by GodotSteam (GDExtension, 4.14 or newer).
##
## The Steam singleton is looked up at runtime instead of referenced by name,
## so the project still opens and runs when GodotSteam is not installed:
## initialize() just returns false and the game uses the Head Builder fallback.

const STEAM_INIT_OK := 0
const AVATAR_LARGE := 3   ## Steam.AVATAR_LARGE (184 px)

var init_message := ""

var _steam: Object = null
var _available := false


func initialize(app_id: int) -> bool:
	if not Engine.has_singleton("Steam"):
		init_message = "GodotSteam is not installed (no Steam singleton)."
		return false
	_steam = Engine.get_singleton("Steam")
	# GodotSteam 4.14+: steamInitEx(app_id, embed_callbacks). Callbacks run in _process below.
	var result: Variant = _steam.call("steamInitEx", app_id, false)
	if result is Dictionary:
		init_message = str(result)
		_available = int((result as Dictionary).get("status", 1)) == STEAM_INIT_OK
	else:
		init_message = "Unexpected steamInitEx result: %s" % [result]
		_available = false
	if _available:
		_steam.connect("avatar_loaded", _on_avatar_loaded)
	return _available


func steam() -> Object:
	return _steam


func is_available() -> bool:
	return _available


func local_name() -> String:
	return str(_steam.call("getPersonaName")) if _available else ""


func local_id() -> int:
	return int(_steam.call("getSteamID")) if _available else 0


func request_local_avatar() -> void:
	if _available:
		_steam.call("getPlayerAvatar", AVATAR_LARGE, local_id())


func _process(_delta: float) -> void:
	if _available:
		_steam.call("run_callbacks")


func _on_avatar_loaded(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	if user_id != local_id():
		return
	var image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	local_avatar_ready.emit(ImageTexture.create_from_image(image))
