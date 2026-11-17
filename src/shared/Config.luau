-- Brainrot Bay: shared tuning constants for the whole game.
-- One place for every number the server and the client both need:
-- map layout, conveyor, economy, steal rules and event timings.

local Config = {}

-- The island is 256 studs across, centred on the origin. The ocean
-- plane in default.project.json is 900 studs across, so the island
-- reads as a green square floating in blue water.
Config.MAP_HALF = 128

-- The conveyor runs east-west along the north edge of the island.
-- Brainrots walk from StartX to EndX, then fall off the belt.
Config.CONVEYOR = {
	StartX = -60,
	EndX = 60,
	Z = -100,
	WalkY = 3,
	Speed = 6,
	SpawnEvery = 4,
	MaxOnBelt = 8,
}

-- Where a fresh player spawns, in the middle of the island.
Config.SPAWN = Vector3.new(0, 3, 30)

-- Eight player bases around the island. Each plot is a 22x22 pad with
-- low walls; the pad positions here must match default.project.json.
Config.PLOTS = {
	{ Name = "Plot 1", Position = Vector3.new(-100, 0, -60), Color = Color3.fromRGB(255, 107, 107) },
	{ Name = "Plot 2", Position = Vector3.new(100, 0, -60), Color = Color3.fromRGB(78, 205, 196) },
	{ Name = "Plot 3", Position = Vector3.new(-100, 0, 60), Color = Color3.fromRGB(255, 209, 102) },
	{ Name = "Plot 4", Position = Vector3.new(100, 0, 60), Color = Color3.fromRGB(155, 89, 182) },
	{ Name = "Plot 5", Position = Vector3.new(-100, 0, 0), Color = Color3.fromRGB(46, 204, 113) },
	{ Name = "Plot 6", Position = Vector3.new(100, 0, 0), Color = Color3.fromRGB(52, 152, 219) },
	{ Name = "Plot 7", Position = Vector3.new(-60, 0, 100), Color = Color3.fromRGB(230, 126, 34) },
	{ Name = "Plot 8", Position = Vector3.new(60, 0, 100), Color = Color3.fromRGB(236, 112, 99) },
}

-- A base starts with 4 slots; upgrades add more, up to this cap.
Config.BASE_START_SLOTS = 4
Config.BASE_MAX_SLOTS = 10
Config.SLOT_UPGRADE_COST = 1500

-- Economy.
Config.START_CASH = 100
Config.TICK_INTERVAL = 1 -- seconds between income ticks
Config.SELL_REFUND = 0.5 -- selling returns half the buy price

-- Stealing: grab a brainrot off another player's base and carry it
-- home. A locked base cannot be stolen from, and a steal has a
-- cooldown so one player cannot be farmed.
Config.STEAL_COOLDOWN = 20 -- seconds per player
Config.LOCK_DURATION = 30 -- seconds a lock lasts
Config.LOCK_COST = 250
Config.CARRY_SPEED = 14 -- studs/second while carrying (slower than walking)

-- Rebirth: hand back every brainrot and most of the cash for a
-- permanent income multiplier and a crown.
Config.REBIRTH_BASE_COST = 50000
Config.REBIRTH_COST_GROWTH = 2.5
Config.REBIRTH_MULTIPLIER_PER = 0.5 -- +50% income per rebirth
Config.REBIRTH_KEEP_CASH = 0.1 -- keep 10% of the cash

-- Events. The tsunami is the big one: a wall of water sweeps the
-- island north to south. Anyone caught off their base drops what
-- they are carrying and gets knocked back to spawn.
Config.TSUNAMI_FIRST_AT = 90 -- seconds after the server starts
Config.TSUNAMI_INTERVAL = 120 -- seconds between waves
Config.TSUNAMI_WARNING = 10 -- seconds of warning before the wave
Config.TSUNAMI_SWEEP_TIME = 8 -- seconds the wall takes to cross the island
Config.GOLDEN_HOUR_EVERY = 180 -- seconds between golden hours
Config.GOLDEN_HOUR_DURATION = 60 -- seconds of double income
Config.GOLDEN_HOUR_MULTIPLIER = 2
Config.MUTATION_SURGE_EVERY = 240 -- seconds between surges
Config.MUTATION_SURGE_DURATION = 45 -- seconds of boosted mutation odds

return Config
