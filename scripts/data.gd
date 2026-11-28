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
		"name": "Angel", "icon": "><(::o>", "cost": 3000, "value": 90, "interval": 9.0, "speed": 2.5, "growth": 1.17,
		"food": "pellets",
		"color": Color("eef0f8"), "accent": Color("b79ce0"),
		"frames": [
			[
				"  /|   ",
				"><(::o>",
				"  \\|   ",
			],
			[
				"  /|   ",
				"}-(::o>",
				"  \\|   ",
			],
		],
		"mask": [
			"  aa",
			"aa dde",
			"  aa",
		],
	},
	{
		"name": "Puffer", "icon": "><( :: o)", "cost": 1200000, "value": 1100, "interval": 10.0, "speed": 2.0, "growth": 1.21,
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
		# A guppy keeps it full for a while: it gets hungry 3x slower than other fish.
		"name": "Shark", "icon": ">=|||  o`-.", "cost": 12000000000, "value": 50000, "interval": 12.0, "speed": 4.5,
		"growth": 1.27, "hunger": 360.0,
		"prey": 0,
		"food": "guppies",
		"color": Color("8fa3b8"), "accent": Color("5f7389"),
		"frames": [
			[
				"\\  ___/|___     ",
				" >=   |||  o`-. ",
				"/  `-.____.-vv' ",
			],
			[
				"   ___/|___     ",
				"=>=   |||  o`-. ",
				"   `-.____.-vv' ",
			],
		],
		"mask": [
			"a  ddddddddd",
			"aaa   ddd  e",
			"a  lllllllllll",
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
		"name": "Jellyfish", "icon": "(o.o)", "cost": 500000000, "value": 13000, "interval": 14.0, "speed": 1.0, "growth": 1.25,
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
	# Long flowing fins and tail that ripple as it swims.
	{
		"name": "Betta", "icon": "{{(~~o>", "cost": 50000, "value": 300, "interval": 10.0, "speed": 2.8, "growth": 1.19,
		"food": "pellets",
		"color": Color("d6336c"), "accent": Color("5b8cff"),
		"frames": [
			[
				"  ,/|/,  ",
				"{{(~~~o> ",
				"  `\\|\\'  ",
			],
			[
				"  ,|/|,  ",
				"}}(~~~o> ",
				"  `|\\|'  ",
			],
		],
		"mask": [
			"  aaaaa",
			"aa ddde",
			"  aaaaa",
		],
	},
	# Flat and wide: glides low over the sand, slowly flapping its wings.
	{
		"name": "Stingray", "icon": "~<_o>", "cost": 25000000, "value": 3800, "interval": 11.0, "speed": 2.2, "growth": 1.23,
		"food": "shrimp",
		"bottom": true,
		"color": Color("9aa7c7"), "accent": Color("5d6b8a"),
		"frames": [
			[
				"    .-\"\"-.  ",
				"-~~<______o>",
			],
			[
				"    _.--._  ",
				"~-~<______o>",
			],
		],
		"mask": [
			"    aaaaaa",
			"aaa       e",
		],
	},
	# Prestige fish: only in the shop after moving to a new tank a few times.
	# Bobs along upright, swaying its curled tail.
	{
		"name": "Seahorse", "icon": "(o>=", "cost": 300000000000, "value": 180000, "interval": 12.0, "speed": 1.6, "growth": 1.27,
		"food": "krill", "needs_moves": 1, "upright": true,
		"color": Color("f2c94c"), "accent": Color("e0913a"),
		"frames": [
			[
				" (o>=",
				"  )\\",
				"  @/",
			],
			[
				" (o>=",
				"  )\\",
				"  @|",
			],
		],
		"mask": [
			" de a",
			"   a",
			"  aa",
		],
	},
	# Crawls over the sand and slowly shifts color.
	{
		"name": "Octopus", "icon": "(o  o)", "cost": 8000000000000, "value": 700000, "interval": 13.0, "speed": 1.8, "growth": 1.28,
		"food": "krill", "needs_moves": 3, "bottom": true, "shift": true,
		"color": Color("ff7f6e"), "accent": Color("e0565a"),
		"frames": [
			[
				" .--. ",
				"(o  o)",
				"/\\/\\/\\",
			],
			[
				" .--. ",
				"(o  o)",
				"\\/\\/\\/",
			],
		],
		"mask": [
			" dddd",
			" e  e",
			"aaaaaa",
		],
	},
	# Lives in the deep: the lure on its head glows and pulses.
	{
		"name": "Anglerfish", "icon": "><( O|vv", "cost": 200000000000000, "value": 2800000, "interval": 14.0, "speed": 2.0, "growth": 1.3,
		"food": "krill", "needs_moves": 6,
		"color": Color("5a6b8c"), "accent": Color("3a4866"), "glow": Color("fff27a"),
		"frames": [
			[
				"      _*",
				"><(  O |vv",
				"   `--'^^",
			],
			[
				"      _*",
				"}-(  O |vv",
				"   `--'^^",
			],
		],
		"mask": [
			"      dg",
			"aad  e  ll",
			"   ddddll",
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
	"krill": {"name": "Krill", "glyph": "~", "color": Color("ff9ec4"), "price": 150000.0, "pack": 10, "sink": 1.2},
}
const PAID_FOODS := ["pellets", "shrimp", "plankton", "krill"]
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
const GUPPY := 0
const SHARK := 5
const ALGAE_EATER := 6
const JELLYFISH := 7
const BETTA := 8
const STINGRAY := 9
const SEAHORSE := 10
const OCTOPUS := 11
const ANGLERFISH := 12
# The order species unlock in: each one shows up once you buy the one before.
# The algae eater isn't in it (it's in the shop whenever dirt is on).
# The last ones only show up after moving to a new tank (their "needs_moves").
const CHAIN := [0, 1, 2, 3, 8, 4, 9, 7, 5, 10, 11, 12]
# The unlock order saves from before v0.5.0 counted along ("unlocked" is a
# position in it).
const OLD_CHAIN := [0, 1, 2, 3, 4, 5, 7]
const CHAIN_VERSION := 2
# The order of the fish buttons in the shop (and keys 1-9, 0).
const SHOP_ORDER := [0, 1, 2, 3, 8, 4, 9, 7, 5, 6, 10, 11, 12]


# Moves to a new tank it takes before this fish is sold at all.
static func needs_moves(species: int) -> int:
	return int(SPECIES[species].get("needs_moves", 0))

# Each extra fish of a kind costs this much more than the one before.
static func cost_growth(species: int) -> float:
	return float(SPECIES[species].get("growth", 1.15))


# Seconds for this kind of fish to go from full to starving.
static func hunger_time(species: int) -> float:
	return float(SPECIES[species].get("hunger", HUNGER_TIME))

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
		"short": "Minerals", "name": "Minerals", "base": 300, "growth": 4.5, "max": 10,
		"desc": "Coins are worth x1.25 per level.",
	},
	"tank": {
		"short": "Tank+", "name": "Bigger tank", "base": 150, "growth": 4.0, "max": 8,
		"desc": "Room for 2 more fish.",
	},
	"weed": {
		"short": "Weed", "name": "Seaweed )(", "base": 50, "growth": 1.9, "max": 8,
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
	"hatchery": {
		"short": "Hatchery", "name": "Guppy hatchery", "base": 2000000000, "growth": 2.5, "max": 8,
		"desc": "Hatches little guppy fry for your sharks to hunt. Fry don't take up room or make coins. Each level hatches them faster.",
	},
	"reef": {
		"short": "Reef", "name": "Coral reef", "base": 1000000, "growth": 1.6, "max": 60,
		"desc": "Coral grows on the sand: +10% coin value per level. Keeps going long after the rest is maxed.",
	},
	"diver": {
		"short": "Diver", "name": "Pearl diver", "base": 100000000, "growth": 2.5, "max": 40,
		"desc": "+10% pearls when you move to a new tank, per level.",
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
# Guppy hatchery: one fry every this many seconds, divided by its level.
const HATCH_SECONDS := 120.0
const SHARK_MEAL_SECONDS := 180.0         # a shark eats a guppy about this often

# ---------------------------------------------------------------- prestige
# Moving to a new tank: you give up this tank (coins, fish, upgrades) for
# pearls, which buy perks that last forever.
# pearls = floor(sqrt(coins earned this run / PEARL_UNIT)) * (1 + 10% per Pearl diver)
const PEARL_UNIT := 1000000000.0
# Only small fish fit in the travel bag (keeps a new tank from starting
# with a shark in it).
const KEEPABLE := [0, 1, 2, 3]

# key -> data. "costs" lists the price of each level in pearls; with "step"
# instead, a level costs base + step * level and it goes up to "max".
const PERKS := {
	"lucky": {"name": "Lucky water", "base": 2, "step": 2, "max": 50,
		"desc": "+25% coin value per level, in every tank from now on."},
	"start": {"name": "Head start", "costs": [2, 5, 10, 20],
		"desc": "Start each new tank with more money."},
	"learn": {"name": "Quick learners", "costs": [3, 6, 9, 12],
		"desc": "Fish level up 25% faster per level."},
	"friends": {"name": "Old friends", "costs": [3, 6, 12, 24],
		"desc": "Bring one more named fish along when you move."},
	"room": {"name": "Roomy tank", "costs": [5, 10, 20, 40],
		"desc": "Room for 2 more fish, in every tank."},
	"habits": {"name": "Old habits", "costs": [3, 6, 12],
		"desc": "New tanks start with a Snail and the Auto-feeder at this level."},
	"pantry": {"name": "Pantry", "costs": [4],
		"desc": "Keep your food stock when you move."},
}
const PERK_ORDER := ["lucky", "start", "learn", "friends", "room", "habits", "pantry"]
const HEAD_START := [0.0, 500.0, 20000.0, 2000000.0, 200000000.0]


static func perk_max(key: String) -> int:
	var p: Dictionary = PERKS[key]
	return p.costs.size() if p.has("costs") else int(p.max)


static func perk_cost(key: String, level: int) -> int:
	var p: Dictionary = PERKS[key]
	if p.has("costs"):
		return int(p.costs[mini(level, p.costs.size() - 1)])
	return int(p.base) + int(p.step) * level


static func pearls_for(earned: float, diver: int) -> int:
	return int(floor(floor(sqrt(maxf(0.0, earned) / PEARL_UNIT)) * (1.0 + 0.1 * diver)))


# Coins needed this run for the next pearl (before Pearl diver).
static func next_pearl_at(earned: float) -> float:
	var n: float = floor(sqrt(maxf(0.0, earned) / PEARL_UNIT)) + 1.0
	return n * n * PEARL_UNIT


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
