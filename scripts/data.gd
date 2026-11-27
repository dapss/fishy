# Static game data: fish species, upgrades, tuning.
extends RefCounted

# Seconds for a fish to go from full (0) to starving (1). Starving fish stop dropping coins.
const HUNGER_TIME := 120.0
# How much hunger one food pellet removes.
const FOOD_VALUE := 0.5
const MAX_LEVEL := 5
const START_MONEY := 15.0
const OFFLINE_CAP_SECONDS := 12 * 3600

# Sprites face RIGHT and are mirrored automatically for swimming left,
# unless "left" frames are given.
#   frames: animation frames (tail wag). Every frame is a list of rows.
#   mask:   colors per character, same layout as the frames:
#           " " body   "a" accent (fins/tail)   "d" darker body
#           "l" lighter body   "e" eye (blinks)
#           Rows may be shorter than the sprite; the rest is body color.
const SPECIES := [
	{
		"name": "Guppy", "icon": "><'>", "cost": 10, "value": 1, "interval": 5.0, "speed": 4.0,
		"color": Color("7fdbff"), "accent": Color("ff7ad9"),
		"frames": [
			["><'>"],
			["}<'>"],
		],
		"mask": ["aae"],
	},
	{
		"name": "Dawa", "icon": "())==D", "cost": 75, "value": 5, "interval": 7.0, "speed": 3.5,
		"color": Color("ffb347"), "accent": Color("ff6b4a"),
		"frames": [
			["())==D"],
			["{))==D"],
		],
		"left": [
			["C==(()"],
			["C==((}"],
		],
		"mask": ["a  aa"],
	},
	{
		"name": "Classic", "icon": "><((((o>", "cost": 400, "value": 22, "interval": 8.0, "speed": 3.0,
		"color": Color("ff8c42"), "accent": Color("ffd166"),
		"frames": [
			[
				"    _/,  ",
				"><((((o> ",
				"    `\\   ",
			],
			[
				"    _/,  ",
				"}-((((o> ",
				"    `\\   ",
			],
		],
		"mask": [
			"    aaa",
			"aa d de",
			"    aa",
		],
	},
	{
		"name": "Angel", "icon": "><(::o>", "cost": 2000, "value": 90, "interval": 9.0, "speed": 2.5,
		"color": Color("eef0f8"), "accent": Color("b79ce0"),
		"frames": [
			[
				"   /|   ",
				"  / |   ",
				"><(::o> ",
				"  \\ |   ",
				"   \\|   ",
			],
			[
				"   /|   ",
				"  / |   ",
				"}-(::o> ",
				"  \\ |   ",
				"   \\|   ",
			],
		],
		"mask": [
			"   aa",
			"  a a",
			"aa dde",
			"  a a",
			"   aa",
		],
	},
	{
		"name": "Puffer", "icon": "><( :: o)", "cost": 10000, "value": 400, "interval": 10.0, "speed": 2.0,
		"color": Color("f9e264"), "accent": Color("e0913a"),
		"frames": [
			[
				"  ,^^^^,  ",
				"><( :: o) ",
				"  `^vv^'  ",
			],
			[
				"  .^^^^.  ",
				"}-( :: o) ",
				"  '^vv^`  ",
			],
		],
		"mask": [
			"  dddddd",
			"aa  ll e",
			"  dllllld",
		],
	},
	{
		"name": "Shark", "icon": ">=|||  o`-.", "cost": 60000, "value": 2200, "interval": 12.0, "speed": 4.5,
		"color": Color("8fa3b8"), "accent": Color("5f7389"),
		"frames": [
			[
				"          /|          ",
				"\\ _______/ |_____     ",
				" >     |||     o `-.  ",
				"/ `-.________.-vvv='  ",
			],
			[
				"          /|          ",
				"  _______/ |_____     ",
				"=>     |||     o `-.  ",
				"  `-.________.-vvv='  ",
			],
		],
		"mask": [
			"          dd",
			"a        d d",
			"aa     ddd     e",
			"a llllllllllllllllll",
		],
	},
]

# key -> data. Cost = base * growth ^ current_level.
const UPGRADES := {
	"snail": {
		"name": "Snail _@'", "base": 120, "growth": 4.0, "max": 4,
		"desc": "A snail crawls the sand and collects coins for you.",
	},
	"feeder": {
		"name": "Auto-feeder", "base": 200, "growth": 2.5, "max": 5,
		"desc": "Drops food when fish get hungry. Each level feeds more often.",
	},
	"minerals": {
		"name": "Minerals", "base": 300, "growth": 2.2, "max": 10,
		"desc": "Coins are worth x1.25 per level.",
	},
	"tank": {
		"name": "Bigger tank", "base": 150, "growth": 2.0, "max": 8,
		"desc": "Room for 2 more fish.",
	},
	"weed": {
		"name": "Seaweed )(", "base": 50, "growth": 1.6, "max": 8,
		"desc": "Fish are happier: +5% coin value each.",
	},
	"castle": {
		"name": "Castle [~]", "base": 5000, "growth": 1.0, "max": 1,
		"desc": "A tiny castle. +25% coin value.",
	},
}

const FEEDER_INTERVAL := [0.0, 30.0, 22.0, 15.0, 10.0, 6.0]


static func upgrade_cost(key: String, level: int) -> float:
	var u: Dictionary = UPGRADES[key]
	return floor(float(u.base) * pow(float(u.growth), level))


static func xp_needed(level: int) -> int:
	return 3 + level * 2


static func fmt(n: float) -> String:
	if n < 10000.0:
		return str(int(floor(n)))
	var units := ["K", "M", "B", "T", "Qa", "Qi"]
	var i := -1
	while n >= 1000.0 and i < units.size() - 1:
		n /= 1000.0
		i += 1
	return "%.2f%s" % [n, units[i]]


static func fmt_time(secs: float) -> String:
	var s := int(secs)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %ds" % [s / 60, s % 60]
	return "%dh %dm" % [s / 3600, (s % 3600) / 60]
