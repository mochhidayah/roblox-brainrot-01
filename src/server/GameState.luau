-- Brainrot Bay: GameState keeps every player's state in one place.
-- Cash, owned brainrots, rebirth count, base slot count, lock timer,
-- steal cooldown and what they are carrying. The server is the only
-- writer: the client asks through RemoteFunctions and the server
-- decides, so a tampered client cannot mint cash or brainrots.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))

local GameState = {}

local states = {}
local plotOwners = {} -- plot index -> player
local freePlots = {}

for i = 1, #Config.PLOTS do
	table.insert(freePlots, i)
end

function GameState.getState(player)
	return states[player]
end

function GameState.getPlotOf(player)
	local state = states[player]
	if state then
		return state.PlotIndex
	end
	return nil
end

function GameState.getOwnerOfPlot(plotIndex)
	return plotOwners[plotIndex]
end

-- A fresh player gets starting cash, an empty base and the first
-- free plot. Plots are handed out in order, so the first eight
-- players each own one.
function GameState.newPlayer(player)
	local plotIndex = table.remove(freePlots, 1)
	local state = {
		Player = player,
		Cash = Config.START_CASH,
		Owned = {}, -- { EntryId, MutationName, BoughtAt } per slot
		Rebirths = 0,
		Slots = Config.BASE_START_SLOTS,
		PlotIndex = plotIndex,
		LockedUntil = 0,
		StealReadyAt = 0,
		Carrying = nil, -- { Owner, SlotIndex, EntryId, MutationName } or nil
	}
	states[player] = state
	if plotIndex then
		plotOwners[plotIndex] = player
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = state.Cash
	cashValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats
	state.CashValue = cashValue
	state.RebirthValue = rebirthValue
	return state
end

function GameState.removePlayer(player)
	local state = states[player]
	if state then
		if state.PlotIndex then
			plotOwners[state.PlotIndex] = nil
			table.insert(freePlots, state.PlotIndex)
		end
		states[player] = nil
	end
end

function GameState.addCash(player, amount)
	local state = states[player]
	if not state then
		return
	end
	state.Cash += amount
	state.CashValue.Value = math.floor(state.Cash)
end

-- Returns true when the player could afford it; the cash is only
-- taken when it returns true.
function GameState.spendCash(player, amount)
	local state = states[player]
	if not state or state.Cash < amount then
		return false
	end
	state.Cash -= amount
	state.CashValue.Value = math.floor(state.Cash)
	return true
end

-- The permanent income multiplier from rebirths: +50% each.
function GameState.rebirthMultiplier(player)
	local state = states[player]
	if not state then
		return 1
	end
	return 1 + state.Rebirths * Config.REBIRTH_MULTIPLIER_PER
end

-- Total $/second across the base, before the event multiplier.
function GameState.incomePerSecond(player, eventMultiplier)
	local state = states[player]
	if not state then
		return 0
	end
	local total = 0
	for _, owned in ipairs(state.Owned) do
		local entry = BrainrotData.getById(owned.EntryId)
		local mutation = nil
		for _, m in ipairs(BrainrotData.MUTATIONS) do
			if m.Name == owned.MutationName then
				mutation = m
				break
			end
		end
		if entry and mutation then
			total += BrainrotData.effectiveRate(entry, mutation, GameState.rebirthMultiplier(player), eventMultiplier)
		end
	end
	return total
end

function GameState.hasFreeSlot(player)
	local state = states[player]
	return state ~= nil and #state.Owned < state.Slots
end

function GameState.addBrainrot(player, entryId, mutationName)
	local state = states[player]
	if not state or #state.Owned >= state.Slots then
		return false
	end
	table.insert(state.Owned, { EntryId = entryId, MutationName = mutationName })
	return true
end

-- Removes the brainrot at a 1-based slot and returns it, or nil.
function GameState.removeBrainrot(player, slotIndex)
	local state = states[player]
	if not state then
		return nil
	end
	local owned = state.Owned[slotIndex]
	if not owned then
		return nil
	end
	table.remove(state.Owned, slotIndex)
	return owned
end

function GameState.isLocked(player)
	local state = states[player]
	if not state then
		return false
	end
	return os.clock() < state.LockedUntil
end

function GameState.lockBase(player)
	local state = states[player]
	if not state then
		return false
	end
	if not GameState.spendCash(player, Config.LOCK_COST) then
		return false
	end
	state.LockedUntil = os.clock() + Config.LOCK_DURATION
	return true
end

function GameState.canSteal(player)
	local state = states[player]
	if not state then
		return false
	end
	return os.clock() >= state.StealReadyAt and state.Carrying == nil
end

function GameState.markStealUsed(player)
	local state = states[player]
	if state then
		state.StealReadyAt = os.clock() + Config.STEAL_COOLDOWN
	end
end

-- The rebirth price climbs with each rebirth, so the ladder never
-- ends: 50k, then 125k, then 312k, and so on.
function GameState.rebirthCost(player)
	local state = states[player]
	if not state then
		return Config.REBIRTH_BASE_COST
	end
	return math.floor(Config.REBIRTH_BASE_COST * (Config.REBIRTH_COST_GROWTH ^ state.Rebirths))
end

-- Hand back every brainrot and most of the cash for +50% income
-- forever and a crown. Returns true on success.
function GameState.rebirth(player)
	local state = states[player]
	if not state then
		return false
	end
	local cost = GameState.rebirthCost(player)
	if state.Cash < cost then
		return false
	end
	state.Cash = math.floor(state.Cash * Config.REBIRTH_KEEP_CASH)
	state.CashValue.Value = state.Cash
	state.Owned = {}
	state.Rebirths += 1
	state.RebirthValue.Value = state.Rebirths
	return true
end

-- A small snapshot for the client HUD: cash, income, slots used,
-- rebirths, lock time left and what the player is carrying.
function GameState.snapshot(player, eventMultiplier)
	local state = states[player]
	if not state then
		return nil
	end
	return {
		Cash = math.floor(state.Cash),
		IncomePerSecond = math.floor(GameState.incomePerSecond(player, eventMultiplier)),
		OwnedCount = #state.Owned,
		Slots = state.Slots,
		Rebirths = state.Rebirths,
		RebirthCost = GameState.rebirthCost(player),
		Multiplier = GameState.rebirthMultiplier(player),
		LockSecondsLeft = math.max(0, math.floor(state.LockedUntil - os.clock())),
		Carrying = state.Carrying ~= nil,
		PlotIndex = state.PlotIndex,
	}
end

return GameState
