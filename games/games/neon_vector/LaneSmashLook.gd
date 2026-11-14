class_name LaneSmashLook
extends RefCounted
## Shared art direction for the 3D ride: gameplay colours keep one meaning everywhere, and each
## track palette is lifted into a saturated, bloom-friendly accent pair without touching the
## saved course data.

## Gameplay meaning colours. Never reuse one for scenery.
const GOLD := Color("ffc640")      ## collect bars
const MINT := Color("4dffc3")      ## cadence arrows
const VIOLET := Color("b78bff")    ## power sections
const DANGER := Color("ff3355")    ## road mines and penalties
const PLASMA := Color("ff6a2b")    ## hostile energy: attackers, shots, blast zones
const HOT := Color("fff1dc")       ## the white-hot core of any flash

## The palette's accent as a vivid emissive colour (grey palettes stay silvery).
static func vivid(accent: Color, value := 1.0) -> Color:
	return Color.from_hsv(accent.h, clampf(accent.s * 2.4, 0.4, 0.85), value)


## The companion hue used for rim light, fresnel sheen and the second sky colour.
static func companion(accent: Color, value := 1.0) -> Color:
	return Color.from_hsv(fposmod(accent.h + 0.11, 1.0), clampf(accent.s * 2.2, 0.45, 0.8), value)


## A near-black body tone carrying a little of the palette, for hulls and decks.
static func hull(accent: Color, lift := 0.0) -> Color:
	return Color.from_hsv(accent.h, 0.45, 0.07 + lift)


## The jukebox autoload (music playback and its live analysis), or null where it is not loaded.
## Safe to call from a node that is not in the tree yet.
static func jukebox() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Jukebox") if tree != null else null


## An emissive, optionally additive, vertex-coloured material for pooled effects. Values above
## one in the instance colour bloom through the environment glow.
static func emissive(additive := false, energy := 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://games/neon_vector/fx_emissive.gdshader") if not additive else preload("res://games/neon_vector/fx_additive.gdshader")
	material.set_shader_parameter("energy", energy)
	return material
