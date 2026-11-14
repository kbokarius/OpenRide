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
## The tunnel's material. It is drawn once a frame into `pass_view`, a small off-screen image,
## and `backdrop` (the sky itself) only stretches that image behind the scene.
var material: ShaderMaterial
var backdrop: ShaderMaterial
var pass_view: SubViewport
var portal_basis := Basis.IDENTITY  ## the tunnel's frame in the world: its mouth follows the road's end
var resistance_mix := 0.0
var music := Vector4.ZERO  ## the eased bass, mids, treble and beat last sent to the shader
var swirl := 0.0
var _star_key := ""
var _inv_view := Vector2.ZERO

func configure(environment: Environment) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://games/neon_vector/psychedelic_sky_pass.gdshader")
	# The off-screen sky is a child of this node, inside the 3D view, so the engine draws it
	# before the view that shows it: the sky is never a frame behind the camera.
	pass_view = SubViewport.new()
	pass_view.name = "SkyPass"
	pass_view.disable_3d = true
	pass_view.transparent_bg = false
	pass_view.gui_disable_input = true
	pass_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pass_view.size = Vector2i(640, 360)
	add_child(pass_view)
	var field := ColorRect.new()
	field.name = "Field"
	field.material = material
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pass_view.add_child(field)
	backdrop = ShaderMaterial.new()
	backdrop.shader = load("res://games/neon_vector/psychedelic_sky.gdshader")
	backdrop.set_shader_parameter("sky_pass", pass_view.get_texture())
	backdrop.set_shader_parameter("star_noise", MeshKit3D.noise_texture(4127))
	var sky := Sky.new()
	sky.sky_material = backdrop
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	# Nothing in the backdrop material changes per frame, so its radiance is made once.
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY


## The size of the off-screen sky: the 3D view's size times `scale` (0.5 is a quarter of the
## pixels).
func set_view_size(view_size: Vector2i, scale: float) -> void:
	if pass_view == null: return
	var wanted := Vector2i((Vector2(view_size) * scale).round()).max(Vector2i(64, 36))
	if pass_view.size != wanted: pass_view.size = wanted
	# The backdrop finds its place in the sky image from the pixel it is drawing. (Only
	# written when the size changes: see `configure`.)
	var inverse := Vector2.ONE / Vector2(view_size)
	if not inverse.is_equal_approx(_inv_view):
		_inv_view = inverse
		backdrop.set_shader_parameter("inv_view", inverse)


## How bright the star field is (0 switches it off for the lightest tier).
func set_stars(amount: float) -> void:
	if backdrop != null: backdrop.set_shader_parameter("stars", amount)


## Points the off-screen sky the way the camera looks. `portal` is the tunnel's frame in the
## world (its mouth follows the end of the visible road); `fov` is the camera's vertical field
## of view in degrees.
func set_view(camera_basis: Basis, portal: Basis, fov: float, aspect: float) -> void:
	portal_basis = portal
	if material == null: return
	material.set_shader_parameter("view_to_tunnel", portal.inverse() * camera_basis)
	var half := tan(deg_to_rad(fov) * 0.5)
	material.set_shader_parameter("half_extent", Vector2(half * aspect, half))

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
	# The stars take the palette's colour. Only written when the palette itself changes: a
	# sky material that changes makes the engine re-filter the sky.
	if id + accent.to_html() != _star_key and backdrop != null:
		_star_key = id + accent.to_html()
		backdrop.set_shader_parameter("star_tint", LaneSmashLook.vivid(accent).lerp(Color.WHITE, 0.7))
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
