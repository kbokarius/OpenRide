class_name LaneSmashEnvironment
extends Node
## One bounded sky pass. Stable IDs preserve the identity of existing seeded courses.
const TITLES := {"orbital": "Prismatic flow", "citadel": "Kaleidoscope", "asteroid": "Liquid aurora", "reactor": "Vortex"}
var material: ShaderMaterial
var resistance_mix := 0.0

func configure(environment: Environment) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://games/neon_vector/psychedelic_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

func update_environment(id: String, accent: Color, distance_m: float, resistance_fraction: float, delta: float, reduced: bool) -> void:
	var blend := 1.0 - exp(-delta * 3.0) if delta > 0 else 1.0
	resistance_mix = lerpf(resistance_mix, clampf(resistance_fraction, 0, 1), blend)
	var colors := palette(accent, resistance_mix)
	# Use the rules' actual distance, including its speed cap and stopped state.
	# No render-frame integration or free-running time can move the sky independently.
	material.set_shader_parameter("travel_m", distance_m)
	material.set_shader_parameter("detail", 0.0 if reduced else 1.0)
	material.set_shader_parameter("intensity", 0.45 if reduced else 1.0)
	material.set_shader_parameter("style", maxi(0, TITLES.keys().find(id)))
	material.set_shader_parameter("primary", colors[0])
	material.set_shader_parameter("secondary", colors[1])

static func palette(accent: Color, resistance_fraction: float = 0.0) -> Array[Color]:
	var primary := Color.from_hsv(fposmod(accent.h + resistance_fraction * 0.08, 1.0), 0.65, 0.9)
	var secondary := Color.from_hsv(fposmod(primary.h + 0.13 + resistance_fraction * 0.08, 1.0), 0.72, 0.85)
	return [primary, secondary]
