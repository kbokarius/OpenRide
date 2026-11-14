class_name LaneSmashEnvironment
extends Node
## One bounded sky pass. Stable IDs preserve the identity of existing seeded courses.
##
## Three things drive it, each for one job. The rider's real distance moves the field forward
## (and nothing else does). Resistance shifts its colours. The music that is playing shapes
## it: bass breathes the walls and thickens the filaments, mids bend the cross-section, treble
## adds sparkle, kicks send soft rings of light down the tunnel, and the track's energy slowly
## turns the whole field. Every response is eased (see `Jukebox.calm_*`): the picture swells
## and settles with the music rather than flickering with it. With the music off the field is
## the calm one it always was.
const TITLES := {"orbital": "Prismatic flow", "citadel": "Kaleidoscope", "asteroid": "Liquid aurora", "reactor": "Vortex"}
## How much of the music reaches the picture in Reduced motion (no beat flashes at all).
const REDUCED_RESPONSE := 0.3
var material: ShaderMaterial
var resistance_mix := 0.0
var music := Vector4.ZERO  ## the eased bass, mids, treble and beat last sent to the shader
var swirl := 0.0

func configure(environment: Environment) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://games/neon_vector/psychedelic_sky.gdshader")
	material.set_shader_parameter("star_noise", MeshKit3D.noise_texture(4127))
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

func update_environment(id: String, accent: Color, distance_m: float, resistance_fraction: float, delta: float, reduced: bool) -> void:
	var blend := 1.0 - exp(-delta * 3.0) if delta > 0 else 1.0
	resistance_mix = lerpf(resistance_mix, clampf(resistance_fraction, 0, 1), blend)
	_follow_music(delta, reduced)
	var colors := palette(accent, resistance_mix, music.x, music.y, music.z)
	# Use the rules' actual distance, including its speed cap and stopped state.
	# No render-frame integration or free-running time can move the sky independently.
	material.set_shader_parameter("travel_m", distance_m)
	material.set_shader_parameter("detail", 0.0 if reduced else 1.0)
	material.set_shader_parameter("intensity", 0.45 if reduced else 1.0)
	material.set_shader_parameter("style", maxi(0, TITLES.keys().find(id)))
	material.set_shader_parameter("primary", colors[0])
	material.set_shader_parameter("secondary", colors[1])
	material.set_shader_parameter("music", music)
	material.set_shader_parameter("swirl", swirl)

## Reads the jukebox's calm analysis: values that swell over about half a second and
## settle over about a second, with each kick as a soft pulse. The whole sky moves with them,
## so nothing here may jump from one frame to the next.
func _follow_music(_delta: float, reduced: bool) -> void:
	var jukebox := LaneSmashLook.jukebox()
	var response := REDUCED_RESPONSE if reduced else 1.0
	if jukebox == null:
		music = Vector4.ZERO
		return
	music = Vector4(float(jukebox.calm_bass), float(jukebox.calm_mid), float(jukebox.calm_treble), 0.0 if reduced else float(jukebox.pulse)) * response
	swirl = float(jukebox.flow) * response

static func palette(accent: Color, resistance_fraction: float = 0.0, bass := 0.0, mids := 0.0, treble := 0.0) -> Array[Color]:
	# Resistance sets the hue; the music turns it a little further and brightens it (mids move
	# the first colour, treble the second, bass deepens both) without changing its identity.
	var primary := Color.from_hsv(fposmod(accent.h + resistance_fraction * 0.08 + mids * 0.05, 1.0), 0.65 + bass * 0.14, 0.9 + bass * 0.1)
	var secondary := Color.from_hsv(fposmod(primary.h + 0.13 + resistance_fraction * 0.08 + mids * 0.04 + treble * 0.07, 1.0), 0.72 + bass * 0.1, 0.85 + bass * 0.12)
	return [primary, secondary]
