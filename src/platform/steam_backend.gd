class_name SteamBackend
extends PlatformBackend
## Steam through GodotSteam (https://godotsteam.com), Milestone 13.
##
## The Steamworks SDK is not part of this repository (its licence doesn't
## allow redistributing it here): install the GodotSteam GDExtension into
## addons/godotsteam/ and set the app id (Project Settings →
## shardlands/platform/steam_app_id, or a steam_appid.txt next to the game for
## development). Without it, Platform uses the local backend and nothing here
## runs. See docs/RELEASE.md.
##
## Every call is guarded with has_method(), so a different GodotSteam version
## degrades to "not available" instead of crashing.

signal overlay_changed(active: bool)

var steam: Object
var app_id := 0
var _overlay := false
var _ok := false


func _init(p_steam: Object, p_app_id: int) -> void:
	steam = p_steam
	app_id = p_app_id


func id() -> String:
	return "steam"


func init() -> bool:
	if steam == null:
		return false
	var status := -1
	if steam.has_method("steamInitEx"):
		var r = steam.call("steamInitEx", true, app_id)
		status = int((r as Dictionary).get("status", -1)) if r is Dictionary else (0 if r == true else -1)
	elif steam.has_method("steamInit"):
		var r = steam.call("steamInit", true, app_id)
		status = int((r as Dictionary).get("status", -1)) if r is Dictionary else (0 if r == true else -1)
	if status != 0:
		push_warning("Steam: not initialised (status %d) - is Steam running and the app id set?" % status)
		return false
	if steam.has_signal("overlay_toggled"):
		steam.connect("overlay_toggled", _on_overlay)
	if steam.has_method("requestCurrentStats"):
		steam.call("requestCurrentStats")
	_ok = true
	return true


func poll() -> void:
	if _ok and steam.has_method("run_callbacks"):
		steam.call("run_callbacks")


func unlock(achievement: StringName) -> void:
	if _ok and steam.has_method("setAchievement"):
		steam.call("setAchievement", String(achievement))


func set_stat(stat: StringName, value: int) -> void:
	if _ok and steam.has_method("setStatInt"):
		steam.call("setStatInt", String(stat), value)


func store() -> void:
	if _ok and steam.has_method("storeStats"):
		steam.call("storeStats")


func set_presence(text: String) -> void:
	if _ok and steam.has_method("setRichPresence"):
		steam.call("setRichPresence", "status", text)
		steam.call("setRichPresence", "steam_display", "#Status")


func user_name() -> String:
	if _ok and steam.has_method("getPersonaName"):
		var n := String(steam.call("getPersonaName"))
		if n != "":
			return n
	return super.user_name()


func overlay_active() -> bool:
	return _overlay


func _on_overlay(active: bool, _user_initiated: bool = true, _app: int = 0) -> void:
	_overlay = active
	overlay_changed.emit(active)


func shutdown() -> void:
	if _ok and steam.has_method("steamShutdown"):
		steam.call("steamShutdown")
	_ok = false
