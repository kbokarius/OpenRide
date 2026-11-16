class_name LaneSmashBikeGaugeAnchor
extends RefCounted
## Shared, bounded placement for cadence and bomb gauges. Presentation only.
var centre := Vector2(-1, -1)
var _side := 0.0
var _inward := false

func follow(delta: float, bike: Vector2, bounds: Rect2, size: Vector2, bike_gap: float) -> Vector2:
	# Beside the bike, on the side away from the middle of the road, so it never covers the
	# lane ahead. It changes side only once the bike is clearly across the middle.
	var middle := bounds.get_center().x
	if _side == 0.0 or absf(bike.x - middle) > 90.0: _side = -1.0 if bike.x < middle else 1.0
	# A wider road can put an outside-lane bike too near the viewport edge for an outward
	# panel. Place it inward there, with hysteresis so it cannot chatter at the threshold.
	var room := size.x + bike_gap
	var edge_room := minf(bike.x - bounds.position.x, bounds.end.x - bike.x)
	if edge_room < room: _inward = true
	elif edge_room > room + 32.0: _inward = false
	if _inward: _side = 1.0 if bike.x < middle else -1.0
	var wanted := Vector2(bike.x + _side * (size.x * 0.5 + bike_gap), bike.y - 90.0)
	wanted.x = clampf(wanted.x, bounds.position.x + size.x * 0.5, bounds.end.x - size.x * 0.5)
	wanted.y = clampf(wanted.y, bounds.position.y + size.y * 0.5, bounds.end.y - size.y * 0.5)
	centre = wanted if centre.x < 0.0 or delta <= 0.0 else centre.lerp(wanted, 1.0 - exp(-delta * 7.0))
	return centre
