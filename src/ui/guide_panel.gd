class_name GuidePanel
extends PanelContainer
## In-game guide (Milestone 13, F1): every control with the current bindings,
## and short pages on how survival, combat, the character, crafting and
## building, the world and saving work.

var tabs := TabContainer.new()
var _controls := RichTextLabel.new()

const PAGES := [
	["Survival", """[b]Health[/b] regenerates a few seconds after you were last hurt. [b]Stamina[/b] pays for sprinting, dodging, heavy attacks and blocking.

[b]Hunger[/b] drains over time - faster while sprinting or cold. Eat from the hotbar or the bag; cooked food is better than raw. At zero hunger you slowly lose health.

[b]Temperature[/b] depends on the biome, the time of day, altitude, water, weather and shelter. Being cold makes you slower and hungrier; being hot drains stamina. [i]Temperature never kills you.[/i] Campfires, roofs and walls, warm clothes, hot or cooling food and your class's temperature shield all help.

[b]Water[/b]: you can swim anywhere (you never drown), but slowly when out of stamina.

[b]Collapsing[/b]: press Respawn to get back up at your bed (or where you started) with part of your health."""],
	["Combat", """[b]Light attacks[/b] chain into a combo; [b]heavy attacks[/b] hit harder and break poise. [b]Dodge-roll[/b] through attacks - you can't be hit while rolling.

[b]Block[/b] (hold) takes most of the damage for stamina. Tap block [i]just before[/i] a hit to [b]parry[/b]: no damage and the attacker is stunned. Attack right after a parry for a [b]riposte[/b] (x2.5, always a critical hit).

[b]Hold heavy[/b] to charge it (up to +75% damage). Attack while [b]sprinting[/b] for a long lunge, or while [b]falling[/b] for a plunging slam - the higher the fall, the harder it hits.

[b]Bows[/b]: hold attack to draw, release to shoot. A full draw hits hardest. Bows use the best arrows in your bag - make them at a workbench. [b]Bows, greatswords and war hammers[/b] need both hands. [b]Spears[/b] reach far; [b]war hammers[/b] stun. Wizards can hold a [b]wand or tome[/b] in the off hand for more spell power.

[b]Lock on[/b] to keep facing one enemy. Hitting enemies from behind deals extra damage; enemies flash red before big attacks.

Elemental damage applies [b]status effects[/b] (burning, poisoned, chilled, wet...). Wet things don't burn but freeze faster; fire melts ice.

[b]Elites[/b] carry special affixes (shielded, molten, vampiric...). [b]Bosses[/b] have phases - watch for new attacks when their health bar drops."""],
	["Character", """Four [b]classes[/b]: Barbarian (strength, rage), Knight (defence, shields), Wizard (spells, mana) and Assassin (speed, critical hits). A Wizard is never as strong physically as the fighters.

[b]Ability book (L)[/b]: every class learns a new ability every two levels. [b]Active[/b] abilities go on your bar - six slots on Z, X, C, T, V and U; [b]passive[/b] abilities are always on. New abilities fill empty slots by themselves; to change your bar, rest next to a [b]bed or a campfire[/b] and pick abilities in the book. Spells use Y and H, and N while you hold a tome.

Each level gives [b]skill points[/b] (2, plus 1 every 5 levels) for Strength, Defense, Dexterity, Mana Control and Crafting. Your class makes some skills grow faster. You can't max everything - choose.

[b]Abilities[/b] unlock at levels 1, 5 and 15. [b]Spells[/b] are learned from tomes found in towers and dungeons; equip them in the spellbook.

[b]Gear[/b] needs a level: Common 5, Uncommon 15, Rare 22, Very Rare 30, Magical 38, Legendary 48. Legendary gear is crafted from scrolls and S-rank materials."""],
	["Crafting & building", """[b]Crafting never fails.[/b] Higher Crafting skill uses fewer materials (bulk ingredients only - single items never cost more).

Recipes are made [b]by hand[/b] or at a [b]station[/b]: workbench, forge, tailoring table, arcane altar, campfire or alchemy table - stand near it. You learn recipes by picking up new materials, from recipe books in caves and ruins, and from shops.

[b]Tools[/b] in your bag are used automatically: hatchets for trees, pickaxes for rock and ore. Better tools mine harder ores.

[b]Building[/b]: place a Claim Totem first - it protects the area from monster spawns. Then floors, walls, doors, roofs, storage, stations and defences. Walls and a roof keep you warm. Repair damaged pieces after raids.

[b]Blueprints[/b] save whole buildings; place one as a construction site and build it piece by piece or let it auto-build from your bag and nearby chests."""],
	["World", """The world is huge and different every seed: meadows, forests, deserts, snowfields, swamps, jungles, mountains, caves underneath and an ocean at the edge.

[b]Villages and kingdoms[/b]: trade with merchants (prices depend on the region and your reputation), take requests from notice boards, and help defend them from raids.

[b]Points of interest[/b] (ruins, wizard towers, temples, hidden groves, dungeons) have a [b]rank[/b] from E to S. Ranks rise the further you travel from spawn - so does the danger of wild monsters - and so does the loot.

[b]Dungeons[/b] have several floors, traps, secret walls and a boss at the bottom. [b]Raids[/b] are announced before they hit your base or a town; an alarm bell gives you more warning.

Nights are darker and more dangerous; storms bring lightning, rain makes you wet, blizzards are cold."""],
	["Saving", """Your world [b]saves automatically[/b] (Settings → Gameplay → Autosave) and whenever you quit through the menu. Quick-save any time.

Every save keeps the previous one, and a few older [b]backups[/b] are kept per world. If a save is ever damaged, the game loads the newest good copy and tells you; you can also restore a backup from the world list (Recover).

If the game ever closes unexpectedly, it writes a [b]crash report[/b] (Main menu → the notice at the top) with the log, which helps us fix the problem."""],
]


func _ready() -> void:
	custom_minimum_size = Vector2(760, 560)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	var title := Label.new()
	title.text = "Guide"
	title.add_theme_font_size_override(&"font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	_controls.name = "Controls"
	_setup_text(_controls)
	tabs.add_child(_controls)
	for page in PAGES:
		var r := RichTextLabel.new()
		r.name = page[0]
		_setup_text(r)
		r.text = page[1]
		tabs.add_child(r)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: visible = false)
	v.add_child(close)
	InputSetup.bindings_changed.connect(refresh_controls)
	InputSetup.device_changed.connect(func(_p: bool) -> void: refresh_controls())
	refresh_controls()


func _setup_text(r: RichTextLabel) -> void:
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override(&"normal_font_size", 16)


## The controls page lists every rebindable action with its current keys.
func refresh_controls() -> void:
	var lines := PackedStringArray()
	lines.append("[i]Change any of these in Settings → Controls.[/i]\n")
	for group in InputSetup.REBINDABLE:
		lines.append("[color=#ffcc59][b]%s[/b][/color]" % group[0])
		for entry in group[1]:
			lines.append("    %s:  [b]%s[/b]   [color=#aaa](pad: %s)[/color]" % [entry[1], InputSetup.action_label(entry[0], false),
				InputSetup.action_label(entry[0], true)])
		lines.append("")
	lines.append("[color=#ffcc59][b]Mouse[/b][/color]\n    Wheel: zoom    Middle-drag: rotate camera    Right-click in build mode: remove")
	_controls.text = "\n".join(lines)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh_controls()
		Tutorial.notify(&"guide_opened")
