-- Brainrot Bay: Economy runs the money. One tick a second pays every
-- player their base's income; buying, selling, upgrading and
-- rebirthing all go through here, on the server, so the client can
-- ask but never decide. A brainrot on the belt is bought by id, and
-- the sale price is checked against the cast table, never the
-- client's word for it.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))
local GameState = require(script.Parent:WaitForChild("GameState"))

local Economy = {}

local remotes = nil

function Economy.setRemotes(folder)
	remotes = folder
end

-- The income tick: every second, every player earns their base's
-- $/second, and the client hears about it to float the "+$X" text.
function Economy.startIncomeLoop(getEventMultiplier)
	task.spawn(function()
		while true do
			task.wait(Config.TICK_INTERVAL)
			local multiplier = getEventMultiplier()
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local income = GameState.incomePerSecond(player, multiplier)
				if income > 0 then
					GameState.addCash(player, income * Config.TICK_INTERVAL)
					if remotes then
						local tickEvent = remotes:FindFirstChild("IncomeTick")
						if tickEvent then
							tickEvent:FireClient(player, math.floor(income * Config.TICK_INTERVAL))
						end
					end
				end
			end
		end
	end)
end

-- Buy a brainrot off the conveyor belt. The belt entry is looked up
-- by the Conveyor, which owns the belt; this only moves the money
-- and the ownership, and only when the base has a free slot.
-- Returns ok, message.
function Economy.buyFromBelt(player, beltEntry, takeOffBelt)
	local state = GameState.getState(player)
	if not state then
		return false, "No state yet, wait a second and try again."
	end
	if not beltEntry then
		return false, "That brainrot already left the belt."
	end
	if not GameState.hasFreeSlot(player) then
		return false, "Your base is full! Upgrade slots or sell one first."
	end
	local entry = BrainrotData.getById(beltEntry.EntryId)
	if not entry then
		return false, "Unknown brainrot."
	end
	if entry.Cost ~= beltEntry.Cost then
		return false, "Price mismatch, try again."
	end
	if not GameState.spendCash(player, entry.Cost) then
		return false, "Not enough cash! You need $" .. tostring(entry.Cost) .. "."
	end
	if not takeOffBelt(beltEntry.Id) then
		-- Someone else bought it a blink earlier: refund in full.
		GameState.addCash(player, entry.Cost)
		return false, "Someone just bought it!"
	end
	GameState.addBrainrot(player, beltEntry.EntryId, beltEntry.MutationName)
	return true, "Bought " .. BrainrotData.displayName(entry, { Name = beltEntry.MutationName }) .. "!"
end

-- Sell a brainrot from a base slot for half its buy price.
function Economy.sellFromBase(player, slotIndex)
	local state = GameState.getState(player)
	if not state then
		return false, "No state yet."
	end
	local owned = state.Owned[slotIndex]
	if not owned then
		return false, "Nothing in that slot."
	end
	local entry = BrainrotData.getById(owned.EntryId)
	if not entry then
		return false, "Unknown brainrot."
	end
	GameState.removeBrainrot(player, slotIndex)
	local refund = math.floor(entry.Cost * Config.SELL_REFUND)
	GameState.addCash(player, refund)
	return true, "Sold " .. entry.Name .. " for $" .. tostring(refund) .. "."
end

-- Buy one more base slot, up to the cap.
function Economy.upgradeSlots(player)
	local state = GameState.getState(player)
	if not state then
		return false, "No state yet."
	end
	if state.Slots >= Config.BASE_MAX_SLOTS then
		return false, "Your base is already maxed out at " .. tostring(Config.BASE_MAX_SLOTS) .. " slots!"
	end
	if not GameState.spendCash(player, Config.SLOT_UPGRADE_COST) then
		return false, "Not enough cash! A slot costs $" .. tostring(Config.SLOT_UPGRADE_COST) .. "."
	end
	state.Slots += 1
	return true, "Base upgraded! You now have " .. tostring(state.Slots) .. " slots."
end

-- Rebirth: pay the price, lose the brainrots and most of the cash,
-- keep +50% income forever. The base visuals are rebuilt by the
-- caller through the BaseChanged event.
function Economy.rebirth(player)
	local state = GameState.getState(player)
	if not state then
		return false, "No state yet."
	end
	local cost = GameState.rebirthCost(player)
	if state.Cash < cost then
		return false, "Rebirth costs $" .. tostring(cost) .. ". Keep earning!"
	end
	if GameState.rebirth(player) then
		return true, "REBIRTH! Income is now x" .. tostring(GameState.rebirthMultiplier(player)) .. " forever."
	end
	return false, "Rebirth failed."
end

return Economy
