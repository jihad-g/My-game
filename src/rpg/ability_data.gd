class_name AbilityData
extends Resource
## Data for one active ability. Behaviour is implemented in PlayerAbilities by
## `effect` (a method name suffix); all tuning numbers live here.

enum CostType { NONE, MANA, STAMINA, RAGE }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## PlayerAbilities method: _ability_<effect>()
@export var effect: StringName
@export var unlock_level: int = 1
@export var cost_type: CostType = CostType.MANA
@export var cost: float = 10.0
@export var cooldown: float = 5.0
@export var damage: float = 0.0
@export var damage_type: StringName = &"physical"
@export var radius: float = 3.0
@export var range: float = 10.0
@export var duration: float = 0.0
## Generic extra tuning value (meaning documented per effect).
@export var power: float = 0.0
## Advanced spells (Milestone 7): Mana Control skill needed to cast it.
@export var required_mana_control: int = 0
@export var icon_color: Color = Color.WHITE
@export var icon_glyph: String = "?"


func cost_name() -> String:
	return ["", "mana", "stamina", "rage"][cost_type]
