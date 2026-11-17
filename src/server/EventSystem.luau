-- Brainrot Bay: EventSystem runs the hazards and the good times.
-- Three events on three clocks:
--   * Tsunami: a wall of water sweeps the island north to south.
--     Anyone off their base drops what they carry and is knocked
--     back to spawn. The warning gives ten seconds to dash home.
--   * Golden Hour: double income for a minute.
--   * Mutation Surge: rare mutations roll far more often.
-- The current event multiplier is one number the Economy reads, so
-- income and the HUD never disagree about it.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))

local EventSystem = {}

local remotes = nil
local wall = nil
local crest = nil
local dropCarried = nil -- init hooks StealSystem.dropCarried up
local eventMultiplier = 1
local goldenUntil = 0
local surgeUntil = 0
local tsunamiActive = false

function EventSystem.setRemotes(folder)
	remotes = folder
end

function EventSystem.setWall(wallPart, crestPart)
	wall = wallPart
	crest = crestPart
end

function EventSystem.setDropCarried(handler)
	dropCarried = handler
end

function EventSystem.getEventMultiplier()
	return eventMultiplier
end

function EventSystem.isSurgeActive()
	return os.clock() < surgeUntil
end

local function broadcast(name, text)
	if not remotes then
		return
	end
	local event = remotes:FindFirstChild("EventAlert")
	if event then
		event:FireAllClients(name, text)
	end
end

local function isOnOwnBase(player)
	local state = GameState.getState(player)
	if not state or not state.PlotIndex then
		return false
	end
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return (root.Position - Config.PLOTS[state.PlotIndex].Position).Magnitude <= 16
end

-- The wave itself: the wall crosses the island over eight seconds.
-- Anyone it passes who is not standing on their own base is knocked
-- back to spawn and drops what they carry.
local function runTsunami()
	tsunamiActive = true
	broadcast("Tsunami", "🌊 TSUNAMI! Run to your base NOW!")
	local startZ = -160
	local endZ = 160
	local steps = 40
	for i = 1, steps do
		local t = i / steps
		local z = startZ + (endZ - startZ) * t
		if wall then
			wall.Position = Vector3.new(0, 20, z)
		end
		if crest then
			crest.Position = Vector3.new(0, 40, z)
		end
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			local character = player.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and math.abs(root.Position.Z - z) < 8 and not isOnOwnBase(player) then
					if dropCarried then
						dropCarried(player, "The wave took what you were carrying!")
					end
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:TakeDamage(20)
					end
					root.CFrame = CFrame.new(Config.SPAWN)
					if remotes then
						local alert = remotes:FindFirstChild("StealAlert")
						if alert then
							alert:FireClient(player, "The tsunami swept you back to spawn!")
						end
					end
				end
			end
		end
		task.wait(Config.TSUNAMI_SWEEP_TIME / steps)
	end
	if wall then
		wall.Position = Vector3.new(0, 20, startZ)
	end
	if crest then
		crest.Position = Vector3.new(0, 40, startZ)
	end
	tsunamiActive = false
	broadcast("Safe", "The wave is gone. The belt is open again!")
end

local function runGoldenHour()
	goldenUntil = os.clock() + Config.GOLDEN_HOUR_DURATION
	eventMultiplier = Config.GOLDEN_HOUR_MULTIPLIER
	broadcast("GoldenHour", "✨ GOLDEN HOUR! Double income for 60 seconds!")
	task.wait(Config.GOLDEN_HOUR_DURATION)
	eventMultiplier = 1
	broadcast("GoldenHourEnd", "Golden Hour is over. Back to normal rates.")
end

local function runMutationSurge()
	surgeUntil = os.clock() + Config.MUTATION_SURGE_DURATION
	broadcast("MutationSurge", "🌈 MUTATION SURGE! Rare mutations are far more likely!")
	task.wait(Config.MUTATION_SURGE_DURATION)
	surgeUntil = 0
	broadcast("MutationSurgeEnd", "The surge is over. Mutations are back to normal odds.")
end

-- Three clocks, one loop. The tsunami warns ten seconds before the
-- wall moves, so a player mid-steal has a real choice to make.
function EventSystem.startLoop()
	task.spawn(function()
		task.wait(Config.TSUNAMI_FIRST_AT)
		local lastTsunami = os.clock()
		local lastGolden = os.clock()
		local lastSurge = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			if now - lastGolden >= Config.GOLDEN_HOUR_EVERY then
				lastGolden = now
				task.spawn(runGoldenHour)
			end
			if now - lastSurge >= Config.MUTATION_SURGE_EVERY then
				lastSurge = now
				task.spawn(runMutationSurge)
			end
			if now - lastTsunami >= Config.TSUNAMI_INTERVAL then
				lastTsunami = now
				broadcast("TsunamiWarning", "⚠️ TSUNAMI IN 10 SECONDS! Get to your base!")
				task.wait(Config.TSUNAMI_WARNING)
				runTsunami()
			end
		end
	end)
end

return EventSystem
