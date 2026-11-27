# What changed in each version, newest first. Shown once after an update
# ("What's new") and any time from the help card. Keep lines short: they
# have to read well in a Tiny window too.
extends RefCounted

const ENTRIES := [
	{
		"version": "0.4.1",
		"notes": [
			"A lonely Dawa droops: its head curves down, more the lonelier it gets. A pat perks it up.",
			"Happiness overload: keep patting a fully happy Dawa and it bursts with joy. Super happy Dawas drop coins twice as often for a minute.",
			"Algae eaters graze properly: they crawl along a patch of grime eating it, instead of swimming past it and starving. With dirt turned off they never go hungry.",
		],
	},
	{
		"version": "0.4.0",
		"notes": [
			"Food! Each fish eats only its own: flakes are free, pellets, shrimp and plankton come from the shop. The auto-feeder uses your stock, even while you're away.",
			"The Dawa doesn't eat anymore: pat it (move the mouse back and forth over it) when it's lonely.",
			"Treats: Gourmet (double XP) and Golden flakes (x1.5 coins). New upgrade: Food hopper stores more food.",
			"New fish: the Jellyfish, after the Shark. It pulses up and drifts down instead of swimming.",
			"Algae eaters are fish now (key 8): they eat only grime, grazing it off the glass. Your old ones moved in.",
			"Sharks don't eat pellets anymore: they hunt guppies. Name a guppy to keep it safe.",
			"New upgrade: Big sponge. Wider strokes, scrubs harder, needs rinsing less often.",
			"Dirty tanks no longer slow the game down.",
			"The sponge outline keeps up with the mouse.",
		],
	},
	{
		"version": "0.3.0",
		"notes": [
			"Dirty tanks! Grime slowly builds up on the glass.",
			"Press W (or [ clean ]) and scrub with the left button held. Slow strokes clean best; right-click rinses the sponge.",
			"Dirty water earns less, makes fish sick ( ~ ) and costs them levels. Left fully covered, fish start to die.",
			"Fish Medicine (shop) revives a dead fish within 5 minutes, or cures a sick one. Or flush it.",
			"New upgrades: Algae eater, Filter and UV lamp slow the grime down.",
			"Scrub the tank spotless for +25% coins for 3 minutes.",
			"Smaller, tidier shop in small windows.",
			"Don't want grime? Turn it (or fish deaths) off in settings.",
		],
	},
	{
		"version": "0.2.0",
		"notes": [
			"fishy updates itself: it tells you when a new version is out and asks first.",
			"Installer with a Start menu entry.",
			"Fish list (L), Shift-click to buy as many as you can afford, F feeds every hungry fish.",
			"Start with Windows, save backups, export / import, and a stats screen.",
		],
	},
]


# "0.10.0" > "0.9.3": compare number by number.
static func newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false


# Notes for every version after `since` (all of them if since is "").
static func text_since(since: String, limit := 3) -> String:
	var parts := []
	for e in ENTRIES:
		if since != "" and not newer(e.version, since):
			break
		var lines := ["v%s" % e.version]
		for n in e.notes:
			lines.append("- " + n)
		parts.append("\n".join(lines))
		if parts.size() >= limit:
			break
	return "\n\n".join(parts)
