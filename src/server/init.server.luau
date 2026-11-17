-- Brainrot Bay: the server bootstrap. One script wires everything:
-- it builds the world, creates the remotes, hands players their
-- plots, and starts the three loops (income, conveyor, events).
-- The client never touches money or ownership directly: every
-- RemoteFunction here checks the state and answers ok/message, and
-- every broadcast keeps the HUD honest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Conveyor = require(script.Parent:WaitForChild("Conveyor"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))
local EventSystem = require(script.Parent:WaitForChild("EventSystem"))

-- The remotes live in ReplicatedStorage so both sides can find them.
local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
remotes.Parent = ReplicatedStorage

local function addRemoteEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end

local function addRemoteFunction(name)
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remotes
	return fn
end

addRemoteEvent("BeltUpdate") -- belt list for the shop UI
addRemoteEvent("IncomeTick") -- "+$X" floaters on the client
addRemoteEvent("EventAlert") -- tsunami, golden hour, surge banners
addRemoteEvent("StealAlert") -- personal warnings (steal, drop, wave)
addRemoteEvent("BaseChanged") -- rebuild the base panel on the client
local buyFn = addRemoteFunction("BuyBrainrot")
local sellFn = addRemoteFunction("SellBrainrot")
local rebirthFn = addRemoteFunction("Rebirth")
local upgradeFn = addRemoteFunction("UpgradeSlots")
local lockFn = addRemoteFunction("LockBase")
local stealFn = addRemoteFunction("StealBrainrot")
local deliverFn = addRemoteFunction("DeliverCarried")
local snapshotFn = addRemoteFunction("GetSnapshot")
local rivalsFn = addRemoteFunction("GetRivals")

-- Slot offsets on a plot, in studs from the plot centre: two rows
-- of four, then two spares in the middle for the last upgrades.
local SLOT_OFFSETS = {
	Vector3.new(-6, 0, -4), Vector3.new(6, 0, -4),
	Vector3.new(-6, 0, 4), Vector3.new(6, 0, 4),
	Vector3.new(0, 0, -7), Vector3.new(0, 0, 7),
	Vector3.new(-6, 0, 0), Vector3.new(6, 0, 0),
	Vector3.new(0, 0, -4), Vector3.new(0, 0, 4),
}

local plotSigns = {} -- plot index -> TextLabel

-- Rebuild one player's base: the brainrots they own, standing on
-- their plot's slots, with the owner's sign above it.
local function rebuildBase(player)
	local state = GameState.getState(player)
	if not state or not state.PlotIndex then
		return
	end
	local folder = workspace:FindFirstChild("BaseModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BaseModels"
		folder.Parent = workspace
	end
	local old = folder:FindFirstChild("Base_" .. player.UserId)
	if old then
		old:Destroy()
	end
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base_" .. player.UserId
	baseFolder.Parent = folder
	local plot = Config.PLOTS[state.PlotIndex]
	for i, owned in ipairs(state.Owned) do
		local entry = BrainrotData.getById(owned.EntryId)
		if entry then
			local mutation = BrainrotData.MUTATIONS[1]
			for _, m in ipairs(BrainrotData.MUTATIONS) do
				if m.Name == owned.MutationName then
					mutation = m
					break
				end
			end
			local offset = SLOT_OFFSETS[i] or Vector3.new(0, 0, 0)
			local position = plot.Position + offset
			local model = WorldBuilder.buildBrainrotModel(entry, mutation, position)
			model.Parent = baseFolder
		end
	end
	-- The plot sign names the owner and the fill level.
	local sign = plotSigns[state.PlotIndex]
	if sign then
		sign.Text = player.DisplayName .. "  " .. tostring(#state.Owned) .. "/" .. tostring(state.Slots) .. " brainrots"
	end
	local event = remotes:FindFirstChild("BaseChanged")
	if event then
		event:FireClient(player, GameState.snapshot(player, EventSystem.getEventMultiplier()))
	end
end

StealSystem.setBaseChangedHandler(rebuildBase)

-- A gold crown for reborn players, welded to the head on spawn.
local function giveCrown(player)
	local state = GameState.getState(player)
	if not state or state.Rebirths < 1 then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	if character:FindFirstChild("RebirthCrown") then
		return
	end
	local crown = Instance.new("Part")
	crown.Name = "RebirthCrown"
	crown.Size = Vector3.new(2.4, 1, 2.4)
	crown.Color = Color3.fromRGB(255, 215, 0)
	crown.Material = Enum.Material.Metal
	crown.CanCollide = false
	crown.CFrame = head.CFrame * CFrame.new(0, 0.8, 0)
	crown.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = crown
	weld.Part1 = head
	weld.Parent = crown
end

local function onPlayerAdded(player)
	GameState.newPlayer(player)
	local state = GameState.getState(player)
	if state and state.PlotIndex then
		if not plotSigns[state.PlotIndex] then
			plotSigns[state.PlotIndex] = WorldBuilder.buildPlotSign(Config.PLOTS[state.PlotIndex])
		end
		local sign = plotSigns[state.PlotIndex]
		if sign then
			sign.Text = player.DisplayName .. "  0/" .. tostring(state.Slots) .. " brainrots"
		end
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(Config.SPAWN)
			end
		end
		giveCrown(player)
	end)
	-- Send the opening belt so the shop is never empty on join.
	task.wait(1)
	local beltEvent = remotes:FindFirstChild("BeltUpdate")
	if beltEvent then
		beltEvent:FireClient(player, Conveyor.getBelt())
	end
end

local function onPlayerRemoving(player)
	StealSystem.playerLeft(player)
	local state = GameState.getState(player)
	if state and state.PlotIndex then
		local folder = workspace:FindFirstChild("BaseModels")
		if folder then
			local old = folder:FindFirstChild("Base_" .. player.UserId)
			if old then
				old:Destroy()
			end
		end
		local sign = plotSigns[state.PlotIndex]
		if sign then
			sign.Text = Config.PLOTS[state.PlotIndex].Name .. " - empty"
		end
	end
	GameState.removePlayer(player)
end

-- Buying through the shop UI: same path as clicking the brainrot.
local function handleBuy(player, beltId)
	local beltEntry = nil
	for _, item in ipairs(Conveyor.getBelt()) do
		if item.Id == beltId then
			beltEntry = item
			break
		end
	end
	if not beltEntry then
		return false, "That brainrot already left the belt."
	end
	local ok, message = Economy.buyFromBelt(player, beltEntry, function(id)
		local taken = Conveyor.takeOffBelt(id)
		return taken ~= nil
	end)
	if ok then
		rebuildBase(player)
	end
	return ok, message
end

buyFn.OnServerInvoke = handleBuy
Conveyor.setBuyHandler(handleBuy)

sellFn.OnServerInvoke = function(player, slotIndex)
	local ok, message = Economy.sellFromBase(player, slotIndex)
	if ok then
		rebuildBase(player)
	end
	return ok, message
end

rebirthFn.OnServerInvoke = function(player)
	local ok, message = Economy.rebirth(player)
	if ok then
		rebuildBase(player)
		giveCrown(player)
	end
	return ok, message
end

upgradeFn.OnServerInvoke = function(player)
	local ok, message = Economy.upgradeSlots(player)
	if ok then
		rebuildBase(player)
	end
	return ok, message
end

lockFn.OnServerInvoke = function(player)
	if GameState.lockBase(player) then
		return true, "Base locked for " .. tostring(Config.LOCK_DURATION) .. " seconds. Nobody can steal from you!"
	end
	return false, "Not enough cash! A lock costs $" .. tostring(Config.LOCK_COST) .. "."
end

stealFn.OnServerInvoke = function(player, victimUserId, slotIndex)
	local victim = Players:GetPlayerByUserId(victimUserId)
	if not victim then
		return false, "That player left."
	end
	return StealSystem.trySteal(player, victim, slotIndex)
end

deliverFn.OnServerInvoke = function(player)
	return StealSystem.tryDeliver(player)
end

snapshotFn.OnServerInvoke = function(player)
	return GameState.snapshot(player, EventSystem.getEventMultiplier())
end

-- The rivals list for the steal panel: every other player's base,
-- whether it is locked, and what sits on it. Positions included so
-- the client's E key can pick the nearest one.
rivalsFn.OnServerInvoke = function(player)
	local rivals = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local state = GameState.getState(other)
			if state then
				local owned = {}
				for _, item in ipairs(state.Owned) do
					table.insert(owned, { EntryId = item.EntryId, MutationName = item.MutationName })
				end
				local plotPosition = nil
				if state.PlotIndex then
					plotPosition = Config.PLOTS[state.PlotIndex].Position
				end
				table.insert(rivals, {
					UserId = other.UserId,
					DisplayName = other.DisplayName,
					Locked = GameState.isLocked(other),
					Owned = owned,
					PlotPosition = plotPosition,
				})
			end
		end
	end
	return rivals
end

-- Every heartbeat: carry the stolen brainrot over the thief's head,
-- slow them down, and hand it over the moment they reach home.
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		StealSystem.updateCarrying(player)
		local state = GameState.getState(player)
		if state and state.Carrying then
			StealSystem.tryDeliver(player)
		elseif state then
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.WalkSpeed ~= 16 then
					humanoid.WalkSpeed = 16
				end
			end
		end
	end
	-- The mutation surge boosts the belt's luck while it lasts.
	if EventSystem.isSurgeActive() then
		Conveyor.setLuckBoost(3)
	else
		Conveyor.setLuckBoost(1)
	end
end)

-- Build the world, then start everything.
WorldBuilder.buildDecorations()
local wall, crest = WorldBuilder.buildTsunamiWall()
EventSystem.setRemotes(remotes)
EventSystem.setWall(wall, crest)
EventSystem.setDropCarried(function(player, reason)
	StealSystem.dropCarried(player, reason)
end)
Economy.setRemotes(remotes)
Conveyor.setRemotes(remotes)
StealSystem.setRemotes(remotes)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Economy.startIncomeLoop(function()
	return EventSystem.getEventMultiplier()
end)
Conveyor.startLoop()
EventSystem.startLoop()

print("Brainrot Bay is live: 8 plots, 10 brainrots, tsunami every " .. tostring(Config.TSUNAMI_INTERVAL) .. "s.")
