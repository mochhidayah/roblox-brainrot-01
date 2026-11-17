-- Brainrot Bay: Conveyor runs the belt along the north edge. Every
-- few seconds a new brainrot rolls onto it with a rarity and a
-- mutation, walks from west to east, and falls off the end if nobody
-- buys it. The belt is the heart of the game: the shop the player
-- watches, the thing they run to, and the reason to save cash.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local Conveyor = {}

local belt = {} -- id -> { Id, EntryId, MutationName, Cost, Rate, Model, PositionX }
local nextId = 1
local rng = Random.new()
local remotes = nil
local luckBoost = 1

function Conveyor.setRemotes(folder)
	remotes = folder
end

function Conveyor.setLuckBoost(boost)
	luckBoost = boost
end

function Conveyor.getBelt()
	local list = {}
	for _, entry in pairs(belt) do
		table.insert(list, {
			Id = entry.Id,
			EntryId = entry.EntryId,
			MutationName = entry.MutationName,
			Cost = entry.Cost,
			Rate = entry.Rate,
			X = entry.PositionX,
		})
	end
	table.sort(list, function(a, b)
		return a.X < b.X
	end)
	return list
end

local function broadcastBelt()
	if not remotes then
		return
	end
	local event = remotes:FindFirstChild("BeltUpdate")
	if event then
		event:FireAllClients(Conveyor.getBelt())
	end
end

-- Spawn one brainrot at the west end of the belt.
function Conveyor.spawnOne()
	if #Conveyor.getBelt() >= Config.CONVEYOR.MaxOnBelt then
		return
	end
	local entry, mutation = BrainrotData.rollBrainrot(rng, luckBoost)
	local id = nextId
	nextId += 1
	local position = Vector3.new(Config.CONVEYOR.StartX, Config.CONVEYOR.WalkY, Config.CONVEYOR.Z)
	local model = WorldBuilder.buildBrainrotModel(entry, mutation, position)
	local beltFolder = workspace:FindFirstChild("BeltModels")
	if not beltFolder then
		beltFolder = Instance.new("Folder")
		beltFolder.Name = "BeltModels"
		beltFolder.Parent = workspace
	end
	model.Parent = beltFolder
	local body = model:FindFirstChild("Body")
	local click = body and body:FindFirstChild("BuyClick")
	if click then
		click.MouseClick:Connect(function(player)
			if buyHandler then
				buyHandler(player, id)
			end
		end)
	end
	belt[id] = {
		Id = id,
		EntryId = entry.Id,
		MutationName = mutation.Name,
		Cost = entry.Cost,
		Rate = entry.Rate * mutation.Multiplier,
		Model = model,
		PositionX = Config.CONVEYOR.StartX,
	}
	broadcastBelt()
end

-- Take a brainrot off the belt by id. Returns the belt entry, or nil
-- when it is already gone (bought, or walked off the end).
function Conveyor.takeOffBelt(id)
	local entry = belt[id]
	if not entry then
		return nil
	end
	belt[id] = nil
	if entry.Model then
		entry.Model:Destroy()
	end
	broadcastBelt()
	return entry
end

-- The belt walk: every heartbeat each brainrot steps east. One that
-- reaches the end falls off and is gone for good.
function Conveyor.startLoop()
	local folder = Instance.new("Folder")
	folder.Name = "BeltModels"
	folder.Parent = workspace

	local spawnTimer = 0
	local lastStep = os.clock()
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - lastStep
		lastStep = now
		spawnTimer += dt
		if spawnTimer >= Config.CONVEYOR.SpawnEvery then
			spawnTimer = 0
			Conveyor.spawnOne()
		end
		local toRemove = {}
		for id, entry in pairs(belt) do
			entry.PositionX += Config.CONVEYOR.Speed * dt
			if entry.PositionX >= Config.CONVEYOR.EndX then
				table.insert(toRemove, id)
			elseif entry.Model and entry.Model.PrimaryPart then
				entry.Model:PivotTo(CFrame.new(entry.PositionX, Config.CONVEYOR.WalkY, Config.CONVEYOR.Z))
			end
		end
		for _, id in ipairs(toRemove) do
			Conveyor.takeOffBelt(id)
		end
	end)
end

-- The buy handler is set by init.server.luau: it runs the sale
-- through the Economy and only takes the brainrot off the belt when
-- the sale goes through. Clicks fire on the server, so the click is
-- wired here, where the model is born.
local buyHandler = nil

function Conveyor.setBuyHandler(handler)
	buyHandler = handler
end

return Conveyor
