-- Brainrot Bay: the client HUD. A ScreenGui over the 3D world: a
-- top bar with cash and income, a shop panel for the conveyor belt,
-- a base panel with sell buttons, a rivals panel with steal buttons,
-- and action buttons for lock, upgrade and rebirth. The client only
-- asks: every button calls a RemoteFunction and the server decides.
-- The HUD text stays clear of the top-left corner, where Roblox's
-- own menu buttons sit over the play view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))

local buyFn = remotes:WaitForChild("BuyBrainrot")
local sellFn = remotes:WaitForChild("SellBrainrot")
local rebirthFn = remotes:WaitForChild("Rebirth")
local upgradeFn = remotes:WaitForChild("UpgradeSlots")
local lockFn = remotes:WaitForChild("LockBase")
local stealFn = remotes:WaitForChild("StealBrainrot")
local snapshotFn = remotes:WaitForChild("GetSnapshot")
local rivalsFn = remotes:WaitForChild("GetRivals")

local beltEvent = remotes:WaitForChild("BeltUpdate")
local eventAlert = remotes:WaitForChild("EventAlert")
local stealAlert = remotes:WaitForChild("StealAlert")
local baseChanged = remotes:WaitForChild("BaseChanged")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotBayGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, name, text, size, position, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, size, position, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local function makePanel(parent, name, size, position, color)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = color
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	return panel
end

-- Top bar, centred: cash, income, rebirths, lock timer. Centred so
-- the top-left corner stays clear for Roblox's menu buttons.
local topBar = makePanel(gui, "TopBar", UDim2.fromOffset(560, 52), UDim2.new(0.5, -280, 0, 12), Color3.fromRGB(20, 20, 30))
local cashLabel = makeLabel(topBar, "CashLabel", "$100", UDim2.fromOffset(180, 52), UDim2.fromOffset(8, 0), 22, Color3.fromRGB(120, 255, 120))
local incomeLabel = makeLabel(topBar, "IncomeLabel", "+$0/s", UDim2.fromOffset(150, 52), UDim2.fromOffset(190, 0), 20, Color3.fromRGB(255, 215, 0))
local rebirthLabel = makeLabel(topBar, "RebirthLabel", "Rebirths: 0  (x1.0)", UDim2.fromOffset(210, 52), UDim2.fromOffset(342, 0), 18, Color3.fromRGB(200, 160, 255))

-- Event banner, under the top bar: tsunami warnings, golden hour.
local banner = makeLabel(gui, "EventBanner", "", UDim2.fromOffset(700, 44), UDim2.new(0.5, -350, 0, 72), 24, Color3.fromRGB(255, 255, 255))
banner.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
banner.BackgroundTransparency = 0.2
banner.Visible = false

-- Feedback line: "Bought X!", errors, steal results.
local messageLabel = makeLabel(gui, "MessageLabel", "", UDim2.fromOffset(700, 32), UDim2.new(0.5, -350, 0, 122), 18, Color3.fromRGB(255, 255, 255))
messageLabel.Visible = false

local function showMessage(text, color)
	messageLabel.Text = text
	messageLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	messageLabel.Visible = true
	task.delay(4, function()
		messageLabel.Visible = false
	end)
end

local function showBanner(text, color)
	banner.Text = text
	banner.BackgroundColor3 = color or Color3.fromRGB(200, 40, 40)
	banner.Visible = true
	task.delay(6, function()
		banner.Visible = false
	end)
end

-- Shop panel, right side: the conveyor belt as a list. Each row
-- shows the brainrot's name, rarity, $/s and price, with a Buy
-- button. The belt updates live as brainrots roll on and off.
local shopPanel = makePanel(gui, "ShopPanel", UDim2.fromOffset(300, 420), UDim2.new(1, -316, 0, 80), Color3.fromRGB(20, 30, 50))
makeLabel(shopPanel, "ShopTitle", "🛒 CONVEYOR BELT - click to buy!", UDim2.fromOffset(300, 30), UDim2.fromOffset(0, 6), 17, Color3.fromRGB(255, 215, 0))
local shopList = Instance.new("Frame")
shopList.Name = "ShopList"
shopList.Size = UDim2.fromOffset(284, 374)
shopList.Position = UDim2.fromOffset(8, 40)
shopList.BackgroundTransparency = 1
shopList.Parent = shopPanel
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 6)
shopLayout.Parent = shopList

local function refreshShop(belt)
	for _, child in ipairs(shopList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if #belt == 0 then
		makeLabel(shopList, "EmptyLabel", "The belt is empty... wait for it!", UDim2.fromOffset(284, 30), UDim2.fromOffset(0, 0), 15, Color3.fromRGB(200, 200, 200))
		return
	end
	for _, item in ipairs(belt) do
		local entry = BrainrotData.getById(item.EntryId)
		if entry then
			local row = makePanel(shopList, "Row" .. tostring(item.Id), UDim2.fromOffset(284, 40), UDim2.fromOffset(0, 0), Color3.fromRGB(40, 50, 80))
			local rarity = BrainrotData.RARITIES[entry.Rarity]
			local nameText = entry.Name
			if item.MutationName ~= "None" then
				nameText = item.MutationName .. " " .. nameText
			end
			makeLabel(row, "NameLabel", nameText, UDim2.fromOffset(150, 20), UDim2.fromOffset(8, 2), 15, rarity.Color)
			makeLabel(row, "RateLabel", entry.Rarity .. "  $" .. tostring(item.Rate) .. "/s", UDim2.fromOffset(150, 18), UDim2.fromOffset(8, 20), 13, Color3.fromRGB(200, 200, 200))
			local buyButton = makeButton(row, "BuyButton", "$" .. tostring(item.Cost), UDim2.fromOffset(80, 30), UDim2.fromOffset(196, 5), Color3.fromRGB(46, 204, 113))
			buyButton.MouseButton1Click:Connect(function()
				local ok, message = buyFn:InvokeServer(item.Id)
				if ok then
					showMessage(message, Color3.fromRGB(120, 255, 120))
				else
					showMessage(message, Color3.fromRGB(255, 120, 120))
				end
			end)
		end
	end
end

-- Base panel, left side: the brainrots on your base, each with a
-- Sell button. The server pushes a BaseChanged event after every
-- buy, sell, steal or rebirth, and the snapshot fills the rows.
local basePanel = makePanel(gui, "BasePanel", UDim2.fromOffset(300, 300), UDim2.new(0, 16, 0, 80), Color3.fromRGB(20, 30, 50))
makeLabel(basePanel, "BaseTitle", "🏠 MY BASE", UDim2.fromOffset(300, 30), UDim2.fromOffset(0, 6), 17, Color3.fromRGB(255, 215, 0))
local baseList = Instance.new("Frame")
baseList.Name = "BaseList"
baseList.Size = UDim2.fromOffset(284, 254)
baseList.Position = UDim2.fromOffset(8, 40)
baseList.BackgroundTransparency = 1
baseList.Parent = basePanel
local baseLayout = Instance.new("UIListLayout")
baseLayout.Padding = UDim.new(0, 6)
baseLayout.Parent = baseList

local function refreshBase(snapshot)
	for _, child in ipairs(baseList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if snapshot.OwnedCount == 0 then
		makeLabel(baseList, "EmptyLabel", "No brainrots yet! Buy one off the belt.", UDim2.fromOffset(284, 30), UDim2.fromOffset(0, 0), 15, Color3.fromRGB(200, 200, 200))
		return
	end
	-- The snapshot carries counts, not names: the base models in the
	-- world show the names. Rows here are slots with sell buttons.
	for slot = 1, snapshot.OwnedCount do
		local row = makePanel(baseList, "Slot" .. tostring(slot), UDim2.fromOffset(284, 34), UDim2.fromOffset(0, 0), Color3.fromRGB(40, 50, 80))
		makeLabel(row, "SlotLabel", "Slot " .. tostring(slot) .. " - brainrot", UDim2.fromOffset(180, 34), UDim2.fromOffset(8, 0), 15, Color3.fromRGB(255, 255, 255))
		local sellButton = makeButton(row, "SellButton", "Sell", UDim2.fromOffset(80, 26), UDim2.fromOffset(196, 4), Color3.fromRGB(231, 76, 60))
		sellButton.MouseButton1Click:Connect(function()
			local ok, message = sellFn:InvokeServer(slot)
			if ok then
				showMessage(message, Color3.fromRGB(120, 255, 120))
			else
				showMessage(message, Color3.fromRGB(255, 120, 120))
			end
		end)
	end
end

-- Rivals panel, left side under the base: every other player's base
-- and a Steal button per brainrot. The server still checks distance,
-- lock and cooldown, so a button here is only ever a request.
local rivalsPanel = makePanel(gui, "RivalsPanel", UDim2.fromOffset(300, 220), UDim2.new(0, 16, 0, 396), Color3.fromRGB(50, 20, 30))
makeLabel(rivalsPanel, "RivalsTitle", "😈 RIVALS - steal their brainrots!", UDim2.fromOffset(300, 30), UDim2.fromOffset(0, 6), 17, Color3.fromRGB(255, 120, 120))
local rivalsList = Instance.new("Frame")
rivalsList.Name = "RivalsList"
rivalsList.Size = UDim2.fromOffset(284, 174)
rivalsList.Position = UDim2.fromOffset(8, 40)
rivalsList.BackgroundTransparency = 1
rivalsList.Parent = rivalsPanel
local rivalsLayout = Instance.new("UIListLayout")
rivalsLayout.Padding = UDim.new(0, 6)
rivalsLayout.Parent = rivalsList

local function refreshRivals(rivals)
	for _, child in ipairs(rivalsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if #rivals == 0 then
		makeLabel(rivalsList, "EmptyLabel", "No rivals yet. Invite your friends!", UDim2.fromOffset(284, 30), UDim2.fromOffset(0, 0), 15, Color3.fromRGB(200, 200, 200))
		return
	end
	for _, rival in ipairs(rivals) do
		local title = rival.DisplayName
		if rival.Locked then
			title ..= " 🔒 LOCKED"
		end
		title ..= " (" .. tostring(#rival.Owned) .. ")"
		local row = makePanel(rivalsList, "Rival" .. tostring(rival.UserId), UDim2.fromOffset(284, 34), UDim2.fromOffset(0, 0), Color3.fromRGB(70, 30, 40))
		makeLabel(row, "RivalLabel", title, UDim2.fromOffset(180, 34), UDim2.fromOffset(8, 0), 14, Color3.fromRGB(255, 255, 255))
		if #rival.Owned > 0 and not rival.Locked then
			local stealButton = makeButton(row, "StealButton", "STEAL", UDim2.fromOffset(80, 26), UDim2.fromOffset(196, 4), Color3.fromRGB(155, 89, 182))
			stealButton.MouseButton1Click:Connect(function()
				local ok, message = stealFn:InvokeServer(rival.UserId, 1)
				if ok then
					showMessage(message, Color3.fromRGB(200, 160, 255))
				else
					showMessage(message, Color3.fromRGB(255, 120, 120))
				end
			end)
		end
	end
end

-- Action buttons, bottom centre: lock, upgrade, rebirth.
local actionsPanel = makePanel(gui, "ActionsPanel", UDim2.fromOffset(460, 56), UDim2.new(0.5, -230, 1, -72), Color3.fromRGB(20, 20, 30))
local lockButton = makeButton(actionsPanel, "LockButton", "🔒 Lock Base ($250)", UDim2.fromOffset(140, 40), UDim2.fromOffset(8, 8), Color3.fromRGB(52, 152, 219))
lockButton.MouseButton1Click:Connect(function()
	local ok, message = lockFn:InvokeServer()
	showMessage(message, ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120))
end)
local upgradeButton = makeButton(actionsPanel, "UpgradeButton", "⬆️ +1 Slot ($1500)", UDim2.fromOffset(140, 40), UDim2.fromOffset(160, 8), Color3.fromRGB(46, 204, 113))
upgradeButton.MouseButton1Click:Connect(function()
	local ok, message = upgradeFn:InvokeServer()
	showMessage(message, ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120))
end)
local rebirthButton = makeButton(actionsPanel, "RebirthButton", "👑 Rebirth", UDim2.fromOffset(140, 40), UDim2.fromOffset(312, 8), Color3.fromRGB(155, 89, 182))
rebirthButton.MouseButton1Click:Connect(function()
	local ok, message = rebirthFn:InvokeServer()
	showMessage(message, ok and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 120, 120))
end)

-- Controls hint, bottom right.
makeLabel(gui, "HintLabel", "WASD move  •  Click a brainrot on the belt to buy  •  E steal nearest", UDim2.fromOffset(560, 24), UDim2.new(1, -576, 1, -28), 14, Color3.fromRGB(220, 220, 220))

-- E steals from the nearest rival base: the client finds the target,
-- the server still decides.
local function stealNearest(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	local ok, rivals = pcall(function()
		return rivalsFn:InvokeServer()
	end)
	if not ok or not rivals or #rivals == 0 then
		showMessage("No rivals to steal from!", Color3.fromRGB(255, 120, 120))
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local best = nil
	local bestDistance = math.huge
	for _, rival in ipairs(rivals) do
		if #rival.Owned > 0 and not rival.Locked and rival.PlotPosition then
			local distance = (root.Position - rival.PlotPosition).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = rival
			end
		end
	end
	if not best then
		showMessage("No unlocked rival base nearby!", Color3.fromRGB(255, 120, 120))
		return
	end
	local okSteal, message = stealFn:InvokeServer(best.UserId, 1)
	showMessage(message, okSteal and Color3.fromRGB(200, 160, 255) or Color3.fromRGB(255, 120, 120))
end
ContextActionService:BindAction("StealNearest", stealNearest, false, Enum.KeyCode.E)

-- Refresh the top bar and the base panel from a snapshot.
local function applySnapshot(snapshot)
	if not snapshot then
		return
	end
	cashLabel.Text = "$" .. tostring(snapshot.Cash)
	incomeLabel.Text = "+$" .. tostring(snapshot.IncomePerSecond) .. "/s"
	rebirthLabel.Text = "Rebirths: " .. tostring(snapshot.Rebirths) .. "  (x" .. string.format("%.1f", snapshot.Multiplier) .. ")"
	if snapshot.LockSecondsLeft > 0 then
		rebirthLabel.Text ..= "  🔒 " .. tostring(snapshot.LockSecondsLeft) .. "s"
	end
	rebirthButton.Text = "👑 Rebirth ($" .. tostring(snapshot.RebirthCost) .. ")"
	refreshBase(snapshot)
end

beltEvent.OnClientEvent:Connect(refreshShop)
baseChanged.OnClientEvent:Connect(applySnapshot)
eventAlert.OnClientEvent:Connect(function(name, text)
	if name == "Tsunami" or name == "TsunamiWarning" then
		showBanner(text, Color3.fromRGB(200, 40, 40))
	elseif name == "GoldenHour" then
		showBanner(text, Color3.fromRGB(243, 156, 18))
	elseif name == "MutationSurge" then
		showBanner(text, Color3.fromRGB(155, 89, 182))
	else
		showBanner(text, Color3.fromRGB(52, 152, 219))
	end
end)
stealAlert.OnClientEvent:Connect(function(text)
	showMessage(text, Color3.fromRGB(255, 180, 180))
end)

-- Poll the snapshot and the rivals list every few seconds: cheap,
-- and it keeps the HUD right after a steal or a rebirth.
task.spawn(function()
	while true do
		local ok, snapshot = pcall(function()
			return snapshotFn:InvokeServer()
		end)
		if ok and snapshot then
			applySnapshot(snapshot)
		end
		local okRivals, rivals = pcall(function()
			return rivalsFn:InvokeServer()
		end)
		if okRivals and rivals then
			refreshRivals(rivals)
		end
		task.wait(3)
	end
end)

print("Brainrot Bay HUD is live.")
