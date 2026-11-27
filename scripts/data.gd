# Static game data: fish species, upgrades, tuning.
extends RefCounted

# Seconds for a fish to go from full (0) to starving (1). Starving fish stop dropping coins.
const HUNGER_TIME := 120.0
# How much hunger one food pellet removes.
const FOOD_VALUE := 0.5
const MAX_LEVEL := 5
const START_MONEY := 15.0
const OFFLINE_CAP_SECONDS := 12 * 3600

# Dirty water. Levels are the average grime on the glass (0..1).
const DIRTY_AT := 0.3            # food sinks into grime, snails skip buried coins
const SICK_AT := 0.6             # fish get sick
const FILTHY_AT := 0.85          # sick fish lose levels
const FULL_AT := 0.95            # fully covered: the death timer runs
const OFFLINE_DIRT_CAP := 0.85   # grime stops growing here while the game is closed
const DEATH_AFTER := 600.0       # seconds fully covered before the first death
const DEATH_EVERY := 180.0       # then one more death this often
const LEVEL_DRAIN := 150.0       # filthy water: a sick fish drops a level this often
const REVIVE_WINDOW := 300.0     # seconds (while the game runs) to revive a dead fish
const REVIVE_WEAK := 60.0        # a revived fish drops no coins for this long
const SPARKLE_TIME := 180.0      # spotless bonus lasts this long
const SPARKLE_BONUS := 1.25
const FLUSH_REFUND := 0.25       # share of the sell price you get back for flushing
# Coin multiplier by dirt level (points are joined with straight lines).
const DIRT_PENALTY := [[0.0, 1.0], [0.3, 0.9], [0.6, 0.7], [0.85, 0.4], [1.0, 0.1]]

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
		"food": "flakes",
		"color": Color("7fdbff"), "accent": Color("ff7ad9"),
		"frames": [
			["><'>"],
			["}<'>"],
		],
		"mask": ["aae"],
	},
	{
		# Doesn't eat at all: it wants pats (stroke it with the mouse).
		"name": "Dawa", "icon": "())==D", "cost": 75, "value": 5, "interval": 7.0, "speed": 3.5,
		"food": "pat",
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
		# A lonely Dawa droops: its head curves down, more the lonelier it is.
		"moods": {
			"sad": {
				"frames": [["())=-.", "     D"], ["{))=-.", "     D"]],
				"left": [[".-=(()", "C"], [".-=((}", "C"]],
				"mask": ["a  aa"],
			},
			"sadder": {
				"frames": [["())-.", "    \\", "     D"], ["{))-.", "    \\", "     D"]],
				"left": [[" .-(()", " /", "C"], [" .-((}", " /", "C"]],
				"mask": ["a  a"],
			},
		},
	},
	{
		"name": "Classic", "icon": "><((((o>", "cost": 400, "value": 22, "interval": 8.0, "speed": 3.0,
		"food": "pellets",
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
		"food": "pellets",
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
		"food": "shrimp",
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
		# Sharks don't eat pellets: a hungry shark hunts guppies (not named ones).
		"name": "Shark", "icon": ">=|||  o`-.", "cost": 60000, "value": 2200, "interval": 12.0, "speed": 4.5,
		"prey": 0,
		"food": "guppies",
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
	# Not part of the unlock chain: in the shop whenever dirt is on.
	# Grazes grime off the glass wherever it goes, and the grime feeds it.
	{
		"name": "Algae eater", "icon": "=<(##)o", "cost": 400, "value": 3, "interval": 8.0, "speed": 2.0,
		"color": Color("b08a5a"), "accent": Color("6b5a2a"),
		"cleaner": true,
		"food": "algae",
		"frames": [
			[
				"   _/\\_    ",
				"=<(####)o ",
			],
			[
				"   _/\\_    ",
				"-<(####)o ",
			],
		],
		"mask": [
			"   aaaa",
			"aa dddd e",
		],
	},
	# Doesn't swim, it pulses: a quick squeeze up, then a slow sink.
	# It drifts toward food instead of chasing it.
	{
		"name": "Jellyfish", "icon": "(o.o)", "cost": 350000, "value": 10000, "interval": 14.0, "speed": 1.0,
		"color": Color("e7a6ff"), "accent": Color("b07ad9"),
		"drifter": true,
		"food": "plankton",
		"frames": [
			[
				" .-. ",
				"(o.o)",
				" )|( ",
			],
			[
				" .-. ",
				"(o.o)",
				" (|) ",
			],
		],
		"mask": [
			" ddd",
			"le el",
			" aaa",
		],
	},
]

# Food you drop in the water. Every fish eats only its own kind (the
# species' "food"); the others aren't dropped: "pat" (the Dawa), "algae"
# (the algae eater grazes grime) and "guppies" (the shark hunts).
# price is per piece, before it scales with your coin multiplier, and is
# about a fifth of what the fish earns between two meals.
const FOODS := {
	"flakes": {"name": "Flakes", "glyph": "*", "color": Color("d98c4a"), "price": 0.0, "pack": 0, "sink": 1.6},
	"pellets": {"name": "Pellets", "glyph": "\u2022", "color": Color("d6b27a"), "price": 30.0, "pack": 20, "sink": 1.8},
	"shrimp": {"name": "Shrimp", "glyph": "c", "color": Color("ff8f7a"), "price": 500.0, "pack": 10, "sink": 1.4},
	"plankton": {"name": "Plankton", "glyph": "\u00b0", "color": Color("9ff0d0"), "price": 8000.0, "pack": 10, "sink": 0.5},
}
const PAID_FOODS := ["pellets", "shrimp", "plankton"]
const FOOD_CAP := [100, 250, 500, 1000]   # pieces of each food you can store, by Food hopper level
const MEAL_SECONDS := 60.0                # a fed fish eats about this often
# Patting the Dawa: stroke this many cells over it for one pat.
const PAT_STROKE := 2.5
const PAT_VALUE := 0.15                   # happiness per pat (a meal is 0.5)
const PATS_PER_XP := 3
# Happiness overload: keep patting a fully happy Dawa and it bursts with joy.
const OVERLOAD_PATS := 120                # extra pats in a row, when already full (~20 s of stroking)
const SUPER_TIME := 60.0                  # super happy: coins twice as often
const SUPER_COOLDOWN := 300.0             # after super happy ends, before it can overload again
# Treats, bought and used at once. Priced from your income.
const GOURMET_TIME := 600.0               # double XP from food and pats
const GOLDEN_TIME := 300.0                # coins are worth more
const GOLDEN_BONUS := 1.5
const TREAT_PRICE_SECONDS := 120.0        # a treat costs this many seconds of income


static func food_of(species: int) -> String:
	return SPECIES[species].get("food", "flakes")


# Species indexes are saved, so new species go at the end of the list.
const ALGAE_EATER := 6
const JELLYFISH := 7
# The order species unlock in: each one shows up once you buy the one before.
# The algae eater isn't in it (it's in the shop whenever dirt is on).
const CHAIN := [0, 1, 2, 3, 4, 5, 7]
# The order of the fish buttons in the shop (and keys 1-8).
const SHOP_ORDER := [0, 1, 2, 3, 4, 5, 7, 6]

# key -> data. Cost = base * growth ^ current_level.
const UPGRADES := {
	"snail": {
		"short": "Snail", "name": "Snail _@'", "base": 120, "growth": 4.0, "max": 4,
		"desc": "A snail crawls the sand and collects coins for you.",
	},
	"feeder": {
		"short": "Feeder", "name": "Auto-feeder", "base": 200, "growth": 2.5, "max": 5,
		"desc": "Drops food when fish get hungry. Each level feeds more often.",
	},
	"minerals": {
		"short": "Minerals", "name": "Minerals", "base": 300, "growth": 2.2, "max": 10,
		"desc": "Coins are worth x1.25 per level.",
	},
	"tank": {
		"short": "Tank+", "name": "Bigger tank", "base": 150, "growth": 2.0, "max": 8,
		"desc": "Room for 2 more fish.",
	},
	"weed": {
		"short": "Weed", "name": "Seaweed )(", "base": 50, "growth": 1.6, "max": 8,
		"desc": "Fish are happier: +5% coin value each.",
	},
	"castle": {
		"short": "Castle", "name": "Castle [~]", "base": 5000, "growth": 1.0, "max": 1,
		"desc": "A tiny castle. +25% coin value.",
	},
	"sponge": {
		"short": "Sponge", "name": "Big sponge", "base": 150, "growth": 4.0, "max": 3,
		"desc": "A bigger, tougher sponge: wider strokes, scrubs harder, holds more grime before it needs a rinse.",
	},
	"hopper": {
		"short": "Hopper", "name": "Food hopper", "base": 500, "growth": 3.0, "max": 3,
		"desc": "Stores more food: 100 -> 250 -> 500 -> 1000 of each kind.",
	},
	"filter": {
		"short": "Filter", "name": "Filter [=]", "base": 250, "growth": 2.5, "max": 3,
		"desc": "The tank gets dirty 12% slower per level.",
	},
	"uv": {
		"short": "UV", "name": "UV lamp", "base": 25000, "growth": 1.0, "max": 1,
		"desc": "The tank gets dirty 20% slower.",
	},
}

# Big sponge, per level: reach, scrubbing strength, how much grime it holds.
const SPONGE_REACH_PER_LV := 0.2
const SPONGE_POWER_PER_LV := 0.1
const SPONGE_HOLD_PER_LV := 0.5

const FEEDER_INTERVAL := [0.0, 30.0, 22.0, 15.0, 10.0, 6.0]


static func upgrade_cost(key: String, level: int) -> float:
	var u: Dictionary = UPGRADES[key]
	return floor(float(u.base) * pow(float(u.growth), level))


# How much slower the tank gets dirty (0..0.5) with these upgrades.
static func dirt_slowdown(ups: Dictionary) -> float:
	return minf(0.5, 0.12 * int(ups.get("filter", 0)) + 0.2 * int(ups.get("uv", 0)))


static func dirt_penalty(level: float) -> float:
	for i in range(1, DIRT_PENALTY.size()):
		var a: Array = DIRT_PENALTY[i - 1]
		var b: Array = DIRT_PENALTY[i]
		if level <= b[0]:
			return lerpf(a[1], b[1], (level - a[0]) / (b[0] - a[0]))
	return DIRT_PENALTY[-1][1]


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
