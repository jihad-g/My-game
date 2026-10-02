class_name CharacterLook
extends RefCounted
## The player's body (Milestone 14): every class shares the same body; the
## player picks skin tone, hair colour, hair style and beard. Everything else
## the character looks like comes from the armour and clothes they wear.
##
## Saved as a small dictionary {skin, hair, style, beard} (palette indices).

const SKINS := [
	Color(0.98, 0.85, 0.72), Color(0.96, 0.78, 0.62), Color(0.85, 0.64, 0.48),
	Color(0.66, 0.46, 0.32), Color(0.52, 0.36, 0.24), Color(0.38, 0.26, 0.18),
]
const SKIN_NAMES := ["Fair", "Light", "Tan", "Bronze", "Brown", "Dark"]
const HAIRS := [
	Color(0.15, 0.12, 0.1), Color(0.42, 0.26, 0.14), Color(0.72, 0.35, 0.12), Color(0.85, 0.7, 0.35),
	Color(0.85, 0.85, 0.88), Color(0.3, 0.3, 0.32), Color(0.55, 0.15, 0.12), Color(0.3, 0.4, 0.7),
]
const HAIR_NAMES := ["Black", "Brown", "Auburn", "Blond", "White", "Grey", "Crimson", "Blue"]
const STYLES := [&"short", &"long", &"topknot", &"bald"]
const STYLE_NAMES := ["Short", "Long", "Topknot", "Bald"]

## Suggested look for each class (the player can change it in the class picker).
const CLASS_DEFAULTS := {
	&"knight": {"skin": 1, "hair": 1, "style": 0, "beard": false},
	&"barbarian": {"skin": 2, "hair": 2, "style": 1, "beard": true},
	&"assassin": {"skin": 3, "hair": 0, "style": 2, "beard": false},
	&"wizard": {"skin": 0, "hair": 4, "style": 1, "beard": true},
}


static func default_for(class_id: StringName) -> Dictionary:
	return (CLASS_DEFAULTS.get(class_id, CLASS_DEFAULTS[&"knight"]) as Dictionary).duplicate()


## Cleans a saved/received look: indices in range, missing keys filled in.
static func sanitize(look: Dictionary, class_id: StringName = &"knight") -> Dictionary:
	var d := default_for(class_id)
	return {
		"skin": clampi(int(look.get("skin", d.skin)), 0, SKINS.size() - 1),
		"hair": clampi(int(look.get("hair", d.hair)), 0, HAIRS.size() - 1),
		"style": clampi(int(look.get("style", d.style)), 0, STYLES.size() - 1),
		"beard": bool(look.get("beard", d.beard)),
	}


static func skin_color(look: Dictionary) -> Color:
	return SKINS[clampi(int(look.get("skin", 1)), 0, SKINS.size() - 1)]


static func hair_color(look: Dictionary) -> Color:
	return HAIRS[clampi(int(look.get("hair", 1)), 0, HAIRS.size() - 1)]


static func hair_style(look: Dictionary) -> StringName:
	return STYLES[clampi(int(look.get("style", 0)), 0, STYLES.size() - 1)]


static func describe(look: Dictionary) -> String:
	var l := sanitize(look)
	return "%s skin · %s %s hair%s" % [SKIN_NAMES[l.skin], HAIR_NAMES[l.hair], STYLE_NAMES[l.style].to_lower(),
		" · beard" if l.beard else ""]

