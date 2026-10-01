class_name PlatformBackend
extends RefCounted
## A store/platform the game runs on (Milestone 13). The base class is the
## "local" platform: no overlay, no cloud - achievements and stats are kept
## by the Platform autoload in the player profile only. SteamBackend talks to
## Steam through the GodotSteam extension when it is installed.


func id() -> String:
	return "local"


## Starts the platform. false = not available (the game falls back to local).
func init() -> bool:
	return true


## Called every frame (Steam needs its callbacks pumped).
func poll() -> void:
	pass


func unlock(_achievement: StringName) -> void:
	pass


func set_stat(_stat: StringName, _value: int) -> void:
	pass


## Pushes unlocked achievements/stats to the platform's servers.
func store() -> void:
	pass


## "Playing ..." text shown to friends.
func set_presence(_text: String) -> void:
	pass


func user_name() -> String:
	var n := OS.get_environment("USERNAME")
	if n == "":
		n = OS.get_environment("USER")
	return n if n != "" else "Player"


func overlay_active() -> bool:
	return false


func shutdown() -> void:
	pass
