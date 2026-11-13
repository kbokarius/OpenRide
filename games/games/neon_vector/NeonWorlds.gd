class_name NeonWorlds
extends RefCounted
## Track-assigned palettes. All eight are available immediately; no cosmetic progression.

const WORLDS := [
	{"id": "arctic", "title": "Arctic", "rides": 0, "accent": "8db9c9", "second": "5d7e96", "sky": "080e14", "haze": "5d7e96"},
	{"id": "cobalt", "title": "Cobalt", "rides": 0, "accent": "639ad1", "second": "526782", "sky": "080c15", "haze": "526782"},
	{"id": "copper", "title": "Copper", "rides": 0, "accent": "bf9872", "second": "84725e", "sky": "110e0c", "haze": "84725e"},
	{"id": "titanium", "title": "Titanium", "rides": 0, "accent": "b5c3cd", "second": "667d8b", "sky": "0b1014", "haze": "667d8b"},
	{"id": "petrol", "title": "Petrol", "rides": 0, "accent": "68aaa6", "second": "467576", "sky": "071011", "haze": "467576"},
	{"id": "amber", "title": "Amber", "rides": 0, "accent": "c1ae76", "second": "827453", "sky": "110f08", "haze": "827453"},
	{"id": "ember", "title": "Ember", "rides": 0, "accent": "c78676", "second": "8a635c", "sky": "130c0b", "haze": "8a635c"},
	{"id": "glacier", "title": "Glacier", "rides": 0, "accent": "83b5aa", "second": "5e858e", "sky": "09100f", "haze": "5e858e"},
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
