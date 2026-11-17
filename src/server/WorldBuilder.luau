-- Brainrot Bay: WorldBuilder builds the 3D world the static map in
-- default.project.json does not: trees, lamps, rocks, clouds, the
-- shop sign, the tsunami wall, and every brainrot character model.
-- A brainrot is a blocky creature built from parts, so it reads as a
-- Roblox character at a glance: body, head, eyes, and one accessory
-- that says what it is (ears, fin, crown, antenna, spikes).

local BrainrotData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotData"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local WorldBuilder = {}

local function makePart(name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Trees, lamps, rocks and clouds scattered around the island so the
-- map reads as a place, not a flat board.
function WorldBuilder.buildDecorations()
	local world = workspace:FindFirstChild("WorldDecor")
	if not world then
		world = Instance.new("Folder")
		world.Name = "WorldDecor"
		world.Parent = workspace
	end

	local treeSpots = {
		Vector3.new(-120, 0, -20), Vector3.new(-120, 0, 20), Vector3.new(120, 0, -20),
		Vector3.new(120, 0, 20), Vector3.new(-40, 0, -60), Vector3.new(40, 0, -60),
		Vector3.new(-40, 0, 90), Vector3.new(40, 0, 90),
	}
	for i, spot in ipairs(treeSpots) do
		local trunk = makePart("TreeTrunk" .. i, Vector3.new(2, 6, 2), spot + Vector3.new(0, 3, 0), Color3.fromRGB(120, 72, 20), Enum.Material.Wood)
		trunk.Parent = world
		local leaves = makePart("TreeLeaves" .. i, Vector3.new(7, 6, 7), spot + Vector3.new(0, 8, 0), Color3.fromRGB(40, 160, 60), Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
		leaves.Parent = world
	end

	local lampSpots = {
		Vector3.new(-12, 0, 10), Vector3.new(12, 0, 10),
		Vector3.new(-12, 0, 50), Vector3.new(12, 0, 50),
	}
	for i, spot in ipairs(lampSpots) do
		local pole = makePart("LampPole" .. i, Vector3.new(1, 7, 1), spot + Vector3.new(0, 3.5, 0), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
		pole.Parent = world
		local bulb = makePart("LampBulb" .. i, Vector3.new(2, 2, 2), spot + Vector3.new(0, 7.5, 0), Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		bulb.Parent = world
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 240, 150)
		light.Range = 18
		light.Brightness = 1
		light.Parent = bulb
	end

	local rockSpots = {
		Vector3.new(-70, 0, -30), Vector3.new(70, 0, -30),
		Vector3.new(-70, 0, 80), Vector3.new(70, 0, 80),
	}
	for i, spot in ipairs(rockSpots) do
		local rock = makePart("Rock" .. i, Vector3.new(5, 3, 4), spot + Vector3.new(0, 1.5, 0), Color3.fromRGB(130, 130, 130), Enum.Material.Slate)
		rock.Parent = world
	end

	-- A few slow clouds, so the sky has something in it.
	for i = 1, 5 do
		local cloud = makePart("Cloud" .. i, Vector3.new(24, 4, 12), Vector3.new(-100 + i * 45, 55 + (i % 2) * 8, -60 + (i % 3) * 40), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		cloud.CanCollide = false
		cloud.Parent = world
	end

	-- The shop sign over the kiosk, so new players find the shop.
	local sign = makePart("ShopSign", Vector3.new(14, 3, 1), Vector3.new(-20, 9, 55), Color3.fromRGB(255, 209, 102), Enum.Material.SmoothPlastic)
	sign.Parent = world
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Text = "SHOP - UPGRADE BASE"
	signText.TextScaled = true
	signText.Font = Enum.Font.GothamBold
	signText.TextColor3 = Color3.fromRGB(40, 40, 40)
	signText.Parent = signGui

	return world
end

-- The tsunami wall: a huge translucent wave that starts parked
-- beyond the north edge and sweeps south across the island.
function WorldBuilder.buildTsunamiWall()
	local wall = makePart("TsunamiWall", Vector3.new(300, 40, 6), Vector3.new(0, 20, -160), Color3.fromRGB(0, 120, 200), Enum.Material.Water)
	wall.Transparency = 0.35
	wall.CanCollide = false
	wall.Parent = workspace
	local crest = makePart("TsunamiCrest", Vector3.new(300, 4, 8), Vector3.new(0, 40, -160), Color3.fromRGB(220, 245, 255), Enum.Material.Neon)
	crest.Transparency = 0.2
	crest.CanCollide = false
	crest.Parent = workspace
	return wall, crest
end

-- One accessory per character, so the cast is told apart at a glance.
local function addAccessory(model, entry, height)
	local accent = entry.Accent
	if entry.Id == "kopi_kucing" then
		-- Cat ears.
		for _, side in ipairs({ -1, 1 }) do
			local ear = makePart("Ear", Vector3.new(1, 1.5, 1), Vector3.new(side * 1.2, height + 1.2, 0), accent, Enum.Material.SmoothPlastic)
			ear.Parent = model
		end
	elseif entry.Id == "ayam_angkasa" then
		-- Astronaut helmet dome.
		local dome = makePart("Helmet", Vector3.new(3.4, 3.4, 3.4), Vector3.new(0, height + 0.6, 0), Color3.fromRGB(200, 230, 255), Enum.Material.Glass)
		dome.Shape = Enum.PartType.Ball
		dome.Transparency = 0.3
		dome.Parent = model
	elseif entry.Id == "hiu_hologram" then
		-- Shark fin.
		local fin = makePart("Fin", Vector3.new(0.6, 2, 2.5), Vector3.new(0, height + 1.4, 0), accent, Enum.Material.SmoothPlastic)
		fin.Parent = model
	elseif entry.Id == "gajah_gitar" then
		-- A guitar slung across the body.
		local guitar = makePart("Guitar", Vector3.new(2.5, 3.5, 0.8), Vector3.new(1.8, height * 0.4, 0.8), accent, Enum.Material.Wood)
		guitar.Parent = model
	elseif entry.Id == "naga_nasi" then
		-- Dragon wings.
		for _, side in ipairs({ -1, 1 }) do
			local wing = makePart("Wing", Vector3.new(0.5, 3, 4), Vector3.new(side * 2.2, height * 0.6, -0.5), accent, Enum.Material.SmoothPlastic)
			wing.Parent = model
		end
	elseif entry.Id == "robot_roti" then
		-- Antenna with a glowing tip.
		local rod = makePart("Antenna", Vector3.new(0.4, 2, 0.4), Vector3.new(0, height + 1.6, 0), accent, Enum.Material.Metal)
		rod.Parent = model
		local tip = makePart("AntennaTip", Vector3.new(1, 1, 1), Vector3.new(0, height + 2.6, 0), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		tip.Shape = Enum.PartType.Ball
		tip.Parent = model
	elseif entry.Id == "raja_rujak" or entry.Id == "dewa_durian" then
		-- Crown for the king, spikes for the durian god.
		if entry.Id == "raja_rujak" then
			local crown = makePart("Crown", Vector3.new(2.6, 1.2, 2.6), Vector3.new(0, height + 1.2, 0), Color3.fromRGB(255, 215, 0), Enum.Material.Metal)
			crown.Parent = model
		else
			for i = 1, 5 do
				local spike = makePart("Spike" .. i, Vector3.new(0.7, 1.6, 0.7), Vector3.new(-1.6 + (i - 1) * 0.8, height + 1.2, 0), accent, Enum.Material.SmoothPlastic)
				spike.Parent = model
			end
		end
	elseif entry.Id == "bayangan_bakso" then
		-- A purple glow ring under the shadow.
		local ring = makePart("GlowRing", Vector3.new(5, 0.5, 5), Vector3.new(0, 0.3, 0), Color3.fromRGB(170, 0, 255), Enum.Material.Neon)
		ring.Parent = model
	elseif entry.Id == "pisang_panik" then
		-- A banana curve on top.
		local peel = makePart("Peel", Vector3.new(1, 2.5, 1), Vector3.new(0, height + 1.4, 0), accent, Enum.Material.SmoothPlastic)
		peel.Parent = model
	end
end

-- Build one brainrot character model at a spot. The model is a
-- blocky creature: a body, a head with two eyes, legs, one accessory
-- and a name tag that shows its name, rarity and $/second, so a
-- player can read the whole deal without opening any menu.
function WorldBuilder.buildBrainrotModel(entry, mutation, position)
	local height = entry.Height
	local model = Instance.new("Model")
	model.Name = BrainrotData.displayName(entry, mutation)

	local bodyHeight = height * 0.55
	local body = makePart("Body", Vector3.new(3, bodyHeight, 2), position + Vector3.new(0, bodyHeight / 2 + 1, 0), entry.Body, Enum.Material.SmoothPlastic)
	body.Parent = model

	local headSize = height * 0.45
	local head = makePart("Head", Vector3.new(headSize, headSize, headSize), position + Vector3.new(0, bodyHeight + headSize / 2 + 1, 0), entry.Head, Enum.Material.SmoothPlastic)
	head.Parent = model

	-- Two eyes, so it looks alive.
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Vector3.new(0.5, 0.7, 0.3), position + Vector3.new(side * 0.6, bodyHeight + headSize * 0.6 + 1, headSize / 2), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
		eye.Parent = model
	end

	-- Stubby legs.
	for _, side in ipairs({ -1, 1 }) do
		local leg = makePart("Leg", Vector3.new(1, 1, 1.2), position + Vector3.new(side * 0.8, 0.5, 0), entry.Accent, Enum.Material.SmoothPlastic)
		leg.Parent = model
	end

	addAccessory(model, entry, height)

	-- Mutation tint: a golden brainrot gleams, a cosmic one glows.
	if mutation.Name ~= "None" then
		local glow = Instance.new("PointLight")
		glow.Color = mutation.Color
		glow.Range = 8
		glow.Brightness = 1
		glow.Parent = body
		if mutation.Name == "Golden" or mutation.Name == "Diamond" then
			body.Material = Enum.Material.Metal
		end
	end

	-- The name tag: name, rarity and $/second, readable from afar.
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(140, 64)
	tag.StudsOffset = Vector3.new(0, height + 3.2, 0)
	tag.AlwaysOnTop = true
	tag.Parent = model
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = BrainrotData.displayName(entry, mutation)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = tag
	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Position = UDim2.fromScale(0, 0.5)
	rateLabel.Size = UDim2.fromScale(1, 0.5)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = entry.Rarity .. "  $" .. tostring(entry.Rate * mutation.Multiplier) .. "/s"
	rateLabel.TextColor3 = BrainrotData.RARITIES[entry.Rarity].Color
	rateLabel.TextStrokeTransparency = 0
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.Parent = tag

	-- Clicking a brainrot on the belt buys it; the client asks the
	-- server, which decides. ClickDetectors only work on the server
	-- side, so the click is wired by the Conveyor, not here.
	local click = Instance.new("ClickDetector")
	click.Name = "BuyClick"
	click.MaxActivationDistance = 32
	click.Parent = body

	model.PrimaryPart = body
	return model
end

-- A floating owner sign above a base plot: the owner's name and how
-- many brainrots live there. Updated by GameState when it changes.
function WorldBuilder.buildPlotSign(plot)
	local sign = Instance.new("BillboardGui")
	sign.Name = "PlotSign"
	sign.Size = UDim2.fromOffset(220, 60)
	sign.StudsOffset = Vector3.new(0, 10, 0)
	sign.AlwaysOnTop = true
	local anchor = makePart("SignAnchor", Vector3.new(1, 1, 1), plot.Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Parent = workspace
	sign.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = plot.Name .. " - empty"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = sign
	return label
end

return WorldBuilder
