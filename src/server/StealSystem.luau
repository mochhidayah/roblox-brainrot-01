-- Brainrot Bay: StealSystem is the threat that makes the game tense.
-- Walk up to another player's base, grab one of their brainrots and
-- carry it home. A locked base cannot be touched, stealing has a
-- cooldown, and carrying slows you down -- so the dash home is the
-- riskiest walk in the game. Get caught by the tsunami while
-- carrying and you drop it where you stand.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))

local StealSystem = {}

local remotes = nil
local carryingModels = {} -- player -> Model
local onBaseChanged = nil -- init hooks this up to rebuild base visuals

function StealSystem.setRemotes(folder)
	remotes = folder
end

function StealSystem.setBaseChangedHandler(handler)
	onBaseChanged = handler
end

local function distanceTo(player, position)
	local character = player.Character
	if not character then
		return math.huge
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

-- Start a steal: the thief must be near the victim's base, the base
-- must be unlocked, the thief must not be on cooldown or already
-- carrying, and the victim must actually own something in that slot.
-- Returns ok, message.
function StealSystem.trySteal(player, victim, slotIndex)
	local thiefState = GameState.getState(player)
	local victimState = GameState.getState(victim)
	if not thiefState or not victimState then
		return false, "Wait a second and try again."
	end
	if player == victim then
		return false, "That is your own base!"
	end
	if not GameState.canSteal(player) then
		return false, "Stealing is on cooldown. Wait a bit!"
	end
	if GameState.isLocked(victim) then
		return false, victim.DisplayName .. "'s base is LOCKED. Come back later!"
	end
	local plotIndex = victimState.PlotIndex
	if not plotIndex then
		return false, "That player has no base."
	end
	local plot = Config.PLOTS[plotIndex]
	if distanceTo(player, plot.Position) > 30 then
		return false, "Get closer to their base first!"
	end
	local owned = victimState.Owned[slotIndex]
	if not owned then
		return false, "Nothing in that slot."
	end
	-- Take it off the victim's base and into the thief's arms.
	GameState.removeBrainrot(victim, slotIndex)
	thiefState.Carrying = { Owner = victim, SlotIndex = slotIndex, EntryId = owned.EntryId, MutationName = owned.MutationName }
	GameState.markStealUsed(player)
	if onBaseChanged then
		onBaseChanged(victim)
	end
	if remotes then
		local alert = remotes:FindFirstChild("StealAlert")
		if alert then
			alert:FireClient(victim, player.DisplayName .. " is stealing your brainrot! RUN!")
			alert:FireClient(player, "You grabbed it! RUN HOME before the wave or their lock!")
		end
	end
	return true, "You grabbed it! Get it to YOUR base!"
end

-- The thief reached their own base with the catch: it becomes theirs.
function StealSystem.tryDeliver(player)
	local state = GameState.getState(player)
	if not state or not state.Carrying then
		return false
	end
	local plotIndex = state.PlotIndex
	if not plotIndex then
		return false
	end
	if distanceTo(player, Config.PLOTS[plotIndex].Position) > 16 then
		return false
	end
	if not GameState.hasFreeSlot(player) then
		return false, "Your base is full! Sell something first."
	end
	local carried = state.Carrying
	state.Carrying = nil
	GameState.addBrainrot(player, carried.EntryId, carried.MutationName)
	local model = carryingModels[player]
	if model then
		model:Destroy()
		carryingModels[player] = nil
	end
	if onBaseChanged then
		onBaseChanged(player)
	end
	return true, "Stolen fair and square! It is yours now."
end

-- Drop what is being carried where the thief stands: the tsunami's
-- punishment, or a thief who left the game mid-carry. The brainrot
-- goes back on the belt's end as a free pickup is too kind -- it
-- simply vanishes, so a failed steal costs the victim nothing extra
-- and the thief everything.
function StealSystem.dropCarried(player, reason)
	local state = GameState.getState(player)
	if not state or not state.Carrying then
		return
	end
	state.Carrying = nil
	local model = carryingModels[player]
	if model then
		model:Destroy()
		carryingModels[player] = nil
	end
	if remotes then
		local alert = remotes:FindFirstChild("StealAlert")
		if alert then
			alert:FireClient(player, reason or "You dropped what you were carrying!")
		end
	end
end

-- While carrying, the brainrot model rides above the thief's head,
-- and the thief walks slower. Checked every heartbeat by init.
function StealSystem.updateCarrying(player, model)
	local state = GameState.getState(player)
	if not state or not state.Carrying then
		local old = carryingModels[player]
		if old then
			old:Destroy()
			carryingModels[player] = nil
		end
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if not carryingModels[player] then
		local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))
		local entry = BrainrotData.getById(state.Carrying.EntryId)
		if not entry then
			return
		end
		local mutation = { Name = state.Carrying.MutationName, Multiplier = 1 }
		for _, m in ipairs(BrainrotData.MUTATIONS) do
			if m.Name == state.Carrying.MutationName then
				mutation = m
				break
			end
		end
		local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
		local carriedModel = WorldBuilder.buildBrainrotModel(entry, mutation, root.Position + Vector3.new(0, 5, 0))
		carriedModel.Parent = workspace
		carryingModels[player] = carriedModel
	end
	local carriedModel = carryingModels[player]
	if carriedModel and carriedModel.PrimaryPart then
		carriedModel:PivotTo(CFrame.new(root.Position + Vector3.new(0, 5.5, 0)))
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.CARRY_SPEED
	end
end

-- Leaving the game mid-carry drops the brainrot, so it cannot be
-- smuggled out of existence.
function StealSystem.playerLeft(player)
	StealSystem.dropCarried(player, "You left the game, so the brainrot slipped away!")
end

return StealSystem
