class_name LaneSmashCelebration
extends RefCounted
## The burst of light and the big number when a power burst is finished: a ring and rays
## that fly outward, shards of light, and the points the burst earned, in and out in a little
## over a second. Drawn by the view that owns the HUD (`paint`); it never changes a score.
const LIFE := 1.3
const RAYS := 18
const SHARDS := 24
const VIOLET := LaneSmashLook.VIOLET
const HOT := LaneSmashLook.HOT

var age := LIFE
var points := 0
var title := "POWER BURST"
var _seed := 0


## Starts the celebration for a burst that earned `points`. `charge` is those points against
## what the reference rider would have earned, which picks the word above the number.
func start(earned: int, charge: float) -> void:
	age = 0.0
	points = earned
	title = rank(charge)
	_seed += 1


static func rank(charge: float) -> String:
	return "OVERCHARGED" if charge >= 2.0 else ("SUPERCHARGED" if charge >= 1.4 else ("FULL POWER" if charge >= 1.0 else "POWER BURST"))


func update(delta: float) -> void:
	age = minf(LIFE, age + delta)


func active() -> bool:
	return age < LIFE


## How opaque the whole thing is: in within a tenth of a second, out over the last 0.45 s.
static func opacity(at: float) -> float:
	return smoothstep(0.0, 0.08, at) * (1.0 - smoothstep(LIFE - 0.45, LIFE, at))


## The number's scale: it punches in past full size and settles.
static func scale(at: float) -> float:
	var t := clampf(at / 0.3, 0.0, 1.0)
	return 0.5 + 0.5 * t + 0.45 * sin(t * PI)


func paint(canvas: CanvasItem, centre: Vector2, caps: Font, digits: Font, reduced := false) -> void:
	if not active(): return
	var alpha := opacity(age)
	var spread := 1.0 - pow(1.0 - clampf(age / 0.7, 0.0, 1.0), 3.0)  # fast out, easing to a stop
	if not reduced:
		# A flash at the centre that is gone within a fifth of a second.
		var flash := (1.0 - clampf(age / 0.2, 0.0, 1.0)) * alpha
		if flash > 0.01:
			for layer in 3:
				canvas.draw_circle(centre, (90.0 + 260.0 * age / 0.2) * (1.0 - layer * 0.28), Color(HOT.lerp(VIOLET, layer * 0.35), flash * 0.22))
		# A ring and a second, thinner one behind it.
		for ring in 2:
			var radius := 70.0 + (430.0 - ring * 120.0) * spread
			var fade := (1.0 - clampf(age / (0.75 - ring * 0.15), 0.0, 1.0)) * alpha
			if fade > 0.01: canvas.draw_arc(centre, radius, 0.0, TAU, 72, Color(VIOLET.lerp(Color.WHITE, 0.3 + 0.3 * ring), fade * 0.9), maxf(2.0, 14.0 * (1.0 - spread)), true)
		# Rays leaving the centre, alternating long and short.
		for i in RAYS:
			var angle := TAU * (i + 0.5 * (_seed % 2)) / RAYS
			var direction := Vector2(cos(angle), sin(angle))
			var reach := 150.0 + (340.0 if i % 2 == 0 else 250.0) * spread
			var length := (150.0 if i % 2 == 0 else 90.0) * (1.0 - spread * 0.55)
			var fade := (1.0 - clampf(age / 0.8, 0.0, 1.0)) * alpha
			if fade > 0.01:
				canvas.draw_line(centre + direction * reach, centre + direction * (reach + length), Color(VIOLET.lerp(Color.WHITE, 0.45), fade), 12.0 if i % 2 == 0 else 6.0, true)
				canvas.draw_line(centre + direction * reach, centre + direction * (reach + length * 0.6), Color(1, 1, 1, fade * 0.8), 4.0 if i % 2 == 0 else 2.0, true)
		# Shards tumbling outward and falling a little.
		for i in SHARDS:
			var seed_a := fposmod(sin((i + _seed * 7) * 12.9898) * 43758.5453, 1.0)
			var seed_b := fposmod(sin((i + _seed * 7) * 78.233) * 24634.6345, 1.0)
			var angle := TAU * seed_a
			var travel := (180.0 + 420.0 * seed_b) * spread
			var at := centre + Vector2(cos(angle), sin(angle) * 0.75) * travel + Vector2(0, 160.0 * age * age)
			var fade := (1.0 - clampf(age / 1.0, 0.0, 1.0)) * alpha
			var half := 10.0 + 14.0 * seed_b
			var spin := angle + age * (6.0 + 8.0 * seed_a)
			var axis := Vector2(cos(spin), sin(spin)) * half
			var side := Vector2(-axis.y, axis.x) * 0.4
			canvas.draw_colored_polygon(PackedVector2Array([at + axis, at + side, at - axis, at - side]), Color((HOT if i % 3 == 0 else VIOLET).lerp(Color.WHITE, 0.2), fade))
	# The word and the number, scaled about the centre.
	var size := scale(age) if not reduced else 1.0
	canvas.draw_set_transform(centre, 0.0, Vector2(size, size))
	var title_width := caps.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	canvas.draw_string_outline(caps, Vector2(-title_width * 0.5, -86), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 10, Color(0.01, 0.02, 0.045, alpha * 0.9))
	canvas.draw_string(caps, Vector2(-title_width * 0.5, -86), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(VIOLET.lerp(Color.WHITE, 0.35), alpha))
	var text := "+%s" % HudTheme.grouped(points)
	var width := digits.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 148).x
	# A soft violet halo, a dark outline, then the number itself.
	canvas.draw_string_outline(digits, Vector2(-width * 0.5, 62), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 148, 34, Color(VIOLET, alpha * 0.22))
	canvas.draw_string_outline(digits, Vector2(-width * 0.5, 62), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 148, 14, Color(0.02, 0.01, 0.06, alpha * 0.92))
	canvas.draw_string(digits, Vector2(-width * 0.5, 62), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 148, Color(HOT.lerp(Color.WHITE, 0.4), alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
