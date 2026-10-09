"""Final biome palette + which texture each biome surface uses.

Colours are sRGB hex. "old" keeps the v0.25 values for the side-by-side preview.
Surfaces follow terrain_generator.gd: top (grass), shore (h <= 1), underwater
(h < 0), rock (h >= rock_height), peak (h >= peak_height); side = wall below the
top band.
"""

BIOMES = {
    "verdant_meadow": {
        "top": "#5A9A34", "top_alt": "#7AAE3E", "side": "#8A5A36", "shore": "#F2D58A", "underwater": "#BC9E66",
        "old": {"top": "#447C30", "top_alt": "#66993A", "side": "#7F5433", "shore": "#F7D684", "underwater": "#BC9E66"},
        "tex": {"top": "grass_meadow", "side": "dirt_side", "shore": "sand", "underwater": "sand", "rock": "stone"},
        "why": "Home biome: brighter, fresher yellow-green so it feels sunny and inviting; warmer dirt.",
    },
    "whispering_forest": {
        "top": "#3C7A34", "top_alt": "#4E8C3A", "side": "#6E4A2E", "shore": "#E8CF8C", "underwater": "#A6936A",
        "old": {"top": "#336B2D", "top_alt": "#498235", "side": "#724C2D", "shore": "#EFD184", "underwater": "#A6936A"},
        "tex": {"top": "grass_forest", "side": "dirt_side", "shore": "sand", "underwater": "sand", "rock": "stone"},
        "why": "Darker and a bit bluer than the meadow so the border between them is clear; old one was too dark.",
    },
    "emerald_jungle": {
        "top": "#22813C", "top_alt": "#33964A", "side": "#6A4226", "shore": "#E6C980", "underwater": "#807048",
        "old": {"top": "#216B28", "top_alt": "#388730", "side": "#6B4428", "shore": "#EACC84", "underwater": "#807048"},
        "tex": {"top": "grass_jungle", "side": "dirt_side", "shore": "sand", "underwater": "sand", "rock": "stone"},
        "why": "Pushed toward emerald (blue-green, very saturated) so it is not just 'another forest'.",
    },
    "frostpine_taiga": {
        "top": "#3E7562", "top_alt": "#4F8770", "side": "#66503C", "shore": "#C9C6AA", "underwater": "#807E70",
        "old": {"top": "#3F7551", "top_alt": "#54895E", "side": "#6B5138", "shore": "#CCC6A5", "underwater": "#807E70"},
        "tex": {"top": "grass_taiga", "side": "dirt_side", "shore": "gravel", "underwater": "gravel", "rock": "stone"},
        "why": "Cool teal-green: reads 'cold' next to the warm forest. Gravel shores instead of sand.",
    },
    "murk_swamp": {
        "top": "#5B6B34", "top_alt": "#6C7A3C", "side": "#4F4330", "shore": "#6B6440", "underwater": "#4A4C34",
        "old": {"top": "#496633", "top_alt": "#5E7538", "side": "#594C33", "shore": "#66603F", "underwater": "#4A4C34"},
        "tex": {"top": "grass_swamp", "side": "mud_side", "shore": "swamp_mud", "underwater": "swamp_mud", "rock": "stone"},
        "why": "Olive and low saturation: the only 'dirty' green. Mud texture carries the wet look.",
    },
    "sandy_beach": {
        "top": "#F2D48E", "top_alt": "#F8E0A6", "side": "#D9B077", "shore": "#F2D48E", "underwater": "#D0B27A",
        "old": {"top": "#F4D389", "top_alt": "#FCE2A0", "side": "#E0B572", "shore": "#F4D389", "underwater": "#D0B27A"},
        "tex": {"top": "sand", "side": "sand_side", "shore": "sand", "underwater": "sand", "rock": "stone"},
        "why": "Almost unchanged; a touch less yellow so it differs from desert orange.",
    },
    "sunscorch_desert": {
        "top": "#EDB66C", "top_alt": "#F5C780", "side": "#CF8A55", "shore": "#F0CB88", "underwater": "#CCAD74",
        "rock": "#C47A4E", "rock_height": 40,
        "old": {"top": "#F4BF70", "top_alt": "#FCD184", "side": "#DB995E", "shore": "#F2CC84", "underwater": "#CCAD74", "rock": "#D68C59"},
        "tex": {"top": "desert_sand", "side": "sandstone", "shore": "sand", "underwater": "sand", "rock": "sandstone"},
        "why": "More orange than the beach; deeper red-orange mesas so cliffs stand out against the sand.",
    },
    "snowy_tundra": {
        "top": "#EEF3FA", "top_alt": "#E2EBF6", "side": "#7E6E68", "shore": "#D6DFEA", "underwater": "#9A9EA8",
        "ice": "#A9D6EE", "frozen_water": True,
        "old": {"top": "#EDF2F9", "top_alt": "#E0EAF7", "side": "#8E7A70", "shore": "#D8E0EA", "underwater": "#9A9EA8", "ice": "#BFE5FF"},
        "tex": {"top": "snow", "side": "dirt_side", "shore": "snow", "underwater": "gravel", "rock": "stone"},
        "why": "Snow stays near white but cool; darker frozen dirt so snow caps read as a bright lip.",
    },
    "stonecrown_mountains": {
        "top": "#6E8A4E", "top_alt": "#829659", "side": "#6E6660", "shore": "#9A948C", "underwater": "#7E7A74",
        "rock": "#8E867D", "peak": "#F2F5FA", "rock_height": 40, "peak_height": 78,
        "old": {"top": "#607A47", "top_alt": "#758454", "side": "#726B66", "shore": "#99938C", "underwater": "#7E7A74", "rock": "#8C847C", "peak": "#F4F7FF"},
        "tex": {"top": "grass_alpine", "side": "stone", "shore": "gravel", "underwater": "gravel", "rock": "mountain_rock", "peak": "snow"},
        "why": "Sage alpine grass (lighter, greyer); warm grey rock so cliffs are not cold blue-grey.",
    },
    "crystal_glade": {
        "top": "#8069C6", "top_alt": "#6B7ED0", "side": "#54466E", "shore": "#CFC2EA", "underwater": "#7E72A6",
        "old": {"top": "#7F6BB7", "top_alt": "#707AC1", "side": "#594C72", "shore": "#CCBFE5", "underwater": "#7E72A6"},
        "tex": {"top": "crystal_ground", "side": "crystal_side", "shore": "sand", "underwater": "sand", "rock": "stone"},
        "why": "A bit more saturated violet/blue so the magic biome pops; it is the rare 'wow' place.",
    },
    "deep_ocean": {
        "top": "#4E6A8E", "top_alt": "#557395", "side": "#47597A", "shore": "#D8CC99", "underwater": "#5A7290",
        "old": {"top": "#4C668C", "top_alt": "#516D93", "side": "#47597A", "shore": "#D8CC99", "underwater": "#5A7290"},
        "tex": {"top": "gravel", "side": "stone", "shore": "sand", "underwater": "sand", "rock": "stone"},
        "why": "Kept; seen through water. Small lift so the sea floor is not black on the web renderer.",
    },
    "the_deeps": {
        "top": "#5E5864", "top_alt": "#69616C", "side": "#4A4550", "shore": "#666666", "underwater": "#4C4C4C",
        "rock": "#3A3640", "rock_height": -9999, "cave": True,
        "old": {"top": "#5B5660", "top_alt": "#665E66", "side": "#4C4751", "shore": "#666666", "underwater": "#4C4C4C", "rock": "#333038"},
        "tex": {"top": "cave_stone", "side": "cave_stone", "shore": "gravel", "underwater": "gravel", "rock": "cave_stone"},
        "why": "Slightly lighter, purple-tinted grey: without ambient occlusion (web) the old cave rock was nearly black.",
    },
}

PROPS = {   # current prop colours from prop_library.gd (unchanged)
    "trunk": "#734D2E", "leaf_oak": "#317530", "leaf_oak_light": "#4D9136",
    "needle": "#2E8054", "needle_light": "#3D9961", "leaf_jungle": "#1F7030",
    "boulder": "#807A73", "ore_stone": "#80808A",
}

TEXTURE_GROUPS = {   # group -> (top textures, side texture, edge texture)
    "grass_meadow": (["grass_meadow_top_0", "grass_meadow_top_1", "grass_meadow_top_2"], "dirt_side", "grass_meadow_edge"),
    "grass_forest": (["grass_forest_top_0", "grass_forest_top_1", "grass_forest_top_2"], "dirt_side", "grass_forest_edge"),
    "grass_jungle": (["grass_jungle_top_0", "grass_jungle_top_1", "grass_jungle_top_2"], "dirt_side", "grass_jungle_edge"),
    "grass_taiga": (["grass_taiga_top_0", "grass_taiga_top_1", "grass_taiga_top_2"], "dirt_side", "grass_taiga_edge"),
    "grass_swamp": (["grass_swamp_top_0", "grass_swamp_top_1", "grass_swamp_top_2"], "mud_side", "grass_swamp_edge"),
    "grass_alpine": (["grass_alpine_top_0", "grass_alpine_top_1", "grass_alpine_top_2"], "dirt_side", "grass_alpine_edge"),
    "crystal_ground": (["crystal_ground_top_0", "crystal_ground_top_1", "crystal_ground_top_2"], "crystal_side", "crystal_ground_edge"),
    "dirt": (["dirt_top"], "dirt_side", "dirt_side"),
    "sand": (["sand_top_0", "sand_top_1", "sand_top_2"], "sand_side", "sand_side"),
    "desert_sand": (["desert_sand_top_0", "desert_sand_top_1", "desert_sand_top_2"], "desert_sand_side", "desert_sand_side"),
    "sandstone": (["sandstone_top"], "sandstone_side", "sandstone_side"),
    "stone": (["stone_top_0", "stone_top_1", "stone_top_2"], "stone_side_0", "stone_side_0"),
    "mountain_rock": (["mountain_rock_top_0", "mountain_rock_top_1"], "mountain_rock_side", "mountain_rock_side"),
    "snow": (["snow_top_0", "snow_top_1"], "snow_side", "snow_edge"),
    "ice": (["ice_top"], "ice_side", "ice_side"),
    "swamp_mud": (["swamp_mud_top_0", "swamp_mud_top_1"], "mud_side", "mud_side"),
    "cave_stone": (["cave_stone_top_0", "cave_stone_top_1"], "cave_stone_side", "cave_stone_side"),
    "gravel": (["gravel_top_0", "gravel_top_1"], "gravel_side", "gravel_side"),
}
# the "side" entry in a biome's tex map can be a group name (use its side texture) or a texture name
