class_name LaneSmashEnvironment
extends Node
## One bounded sky pass. Stable IDs preserve the identity of existing seeded courses.
const TITLES := {"orbital": "Prismatic flow", "citadel": "Kaleidoscope", "asteroid": "Liquid aurora", "reactor": "Vortex"}
var material: ShaderMaterial
var flow_time := 0.0
var resistance_mix := 0.0
var motion_rate := 0.0

func configure(environment: Environment) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://games/neon_vector/psychedelic_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

func update_environment(id: String, accent: Color, rpm: float, resistance_fraction: float, delta: float, reduced: bool) -> void:
	var blend := 1.0 - exp(-delta * 3.0) if delta > 0 else 1.0
	resistance_mix = lerpf(resistance_mix, clampf(resistance_fraction, 0, 1), blend)
	motion_rate = lerpf(motion_rate, clampf(rpm / 140.0, 0, 1.4), blend)
	flow_time += delta * (0.12 + motion_rate * 1.8) * (0.22 if reduced else 1.0)
	var primary := Color.from_hsv(fposmod(accent.h + resistance_mix * 0.16, 1.0), 0.72, 0.9)
	var secondary := Color.from_hsv(fposmod(primary.h + 0.24 + resistance_mix * 0.12, 1.0), 0.8, 0.85)
	material.set_shader_parameter("flow_time", flow_time)
	material.set_shader_parameter("resistance", resistance_mix)
	material.set_shader_parameter("intensity", 0.45 if reduced else 1.0)
	material.set_shader_parameter("style", maxi(0, TITLES.keys().find(id)))
	material.set_shader_parameter("primary", primary)
	material.set_shader_parameter("secondary", secondary)
