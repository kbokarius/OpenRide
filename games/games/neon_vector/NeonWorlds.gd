class_name NeonWorlds
extends RefCounted
## Cosmetics are earned by completed, non-tutorial rides. No score or difficulty advantage.

const WORLDS := [
	{"id": "city", "title": "Midnight Circuit", "rides": 0, "accent": "67d8ff", "second": "a481ff", "sky": "090e23", "haze": "273357"},
	{"id": "orbit", "title": "Orbital Drift", "rides": 3, "accent": "baa0ff", "second": "66dcff", "sky": "130d2c", "haze": "49345f"},
	{"id": "abyss", "title": "Deep Signal", "rides": 7, "accent": "79e8dd", "second": "639bff", "sky": "061923", "haze": "174752"},
	{"id": "canyon", "title": "Solar Frontier", "rides": 12, "accent": "ffb785", "second": "f28cbe", "sky": "241223", "haze": "71384e"},
]
const TRAILS := [
	{"id": "ion", "title": "Ion", "rides": 0},
	{"id": "prism", "title": "Prism", "rides": 5},
	{"id": "comet", "title": "Comet", "rides": 10},
]


static func world(id: String) -> Dictionary:
	for value in WORLDS:
		if value.id == id:
			return value
	return WORLDS[0]


static func unlocked(id: String, completions: int, trail: bool = false) -> bool:
	for value in TRAILS if trail else WORLDS:
		if value.id == id:
			return completions >= int(value.rides)
	return false
