-- Brainrot Bay: the cast. Every character is original to this game:
-- an absurd, meme-born creature with a rarity, a money-per-second rate
-- and a buy price. The rarity ladder is what the player climbs:
-- Common -> Rare -> Epic -> Legendary -> Mythic -> Secret.
-- Mutations multiply the rate: Golden x2, Diamond x5, Rainbow x10,
-- Cosmic x25. The same table drives the server spawns, the shop UI
-- and the screenshot renderer, so all three always agree.

local BrainrotData = {}

BrainrotData.RARITIES = {
	Common = { Weight = 40, Color = Color3.fromRGB(149, 165, 166), Order = 1 },
	Rare = { Weight = 28, Color = Color3.fromRGB(52, 152, 219), Order = 2 },
	Epic = { Weight = 16, Color = Color3.fromRGB(155, 89, 182), Order = 3 },
	Legendary = { Weight = 9, Color = Color3.fromRGB(243, 156, 18), Order = 4 },
	Mythic = { Weight = 5, Color = Color3.fromRGB(231, 76, 60), Order = 5 },
	Secret = { Weight = 2, Color = Color3.fromRGB(20, 20, 20), Order = 6 },
}

BrainrotData.MUTATIONS = {
	{ Name = "None", Multiplier = 1, Chance = 0.70, Color = Color3.fromRGB(255, 255, 255) },
	{ Name = "Golden", Multiplier = 2, Chance = 0.16, Color = Color3.fromRGB(255, 215, 0) },
	{ Name = "Diamond", Multiplier = 5, Chance = 0.08, Color = Color3.fromRGB(127, 219, 255) },
	{ Name = "Rainbow", Multiplier = 10, Chance = 0.045, Color = Color3.fromRGB(255, 105, 180) },
	{ Name = "Cosmic", Multiplier = 25, Chance = 0.015, Color = Color3.fromRGB(138, 43, 226) },
}

-- Id, display name, rarity, $/second, buy price, body colour,
-- head colour, accent colour, height in studs, and one joke line.
-- Prices climb with the rate so the next tier is always a stretch.
BrainrotData.CAST = {
	{ Id = "pisang_panik", Name = "Pisang Panik", Rarity = "Common", Rate = 4, Cost = 50,
		Body = Color3.fromRGB(255, 221, 51), Head = Color3.fromRGB(255, 236, 120), Accent = Color3.fromRGB(120, 72, 20),
		Height = 3, Joke = "A banana that saw the wifi password change." },
	{ Id = "kopi_kucing", Name = "Kopi Kucing", Rarity = "Common", Rate = 9, Cost = 120,
		Body = Color3.fromRGB(139, 90, 43), Head = Color3.fromRGB(205, 170, 125), Accent = Color3.fromRGB(60, 35, 15),
		Height = 3, Joke = "Meows in espresso. Purrs in decaf." },
	{ Id = "ayam_angkasa", Name = "Ayam Angkasa", Rarity = "Rare", Rate = 25, Cost = 350,
		Body = Color3.fromRGB(240, 240, 240), Head = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(255, 87, 51),
		Height = 4, Joke = "First chicken on the moon. Still clucking." },
	{ Id = "hiu_hologram", Name = "Hiu Hologram", Rarity = "Rare", Rate = 45, Cost = 700,
		Body = Color3.fromRGB(0, 180, 216), Head = Color3.fromRGB(144, 224, 239), Accent = Color3.fromRGB(255, 255, 255),
		Height = 4, Joke = "A shark made of light. Bites in 4K." },
	{ Id = "gajah_gitar", Name = "Gajah Gitar", Rarity = "Epic", Rate = 90, Cost = 1600,
		Body = Color3.fromRGB(150, 150, 160), Head = Color3.fromRGB(180, 180, 190), Accent = Color3.fromRGB(255, 159, 28),
		Height = 5, Joke = "Plays one chord. The crowd goes wild." },
	{ Id = "naga_nasi", Name = "Naga Nasi", Rarity = "Epic", Rate = 160, Cost = 3200,
		Body = Color3.fromRGB(200, 40, 40), Head = Color3.fromRGB(255, 200, 60), Accent = Color3.fromRGB(255, 240, 200),
		Height = 5, Joke = "Breathes fire. Smells like fried rice." },
	{ Id = "robot_roti", Name = "Robot Roti", Rarity = "Legendary", Rate = 320, Cost = 7500,
		Body = Color3.fromRGB(180, 190, 200), Head = Color3.fromRGB(220, 230, 240), Accent = Color3.fromRGB(255, 195, 0),
		Height = 5, Joke = "Toasted itself. Zero regrets." },
	{ Id = "raja_rujak", Name = "Raja Rujak", Rarity = "Mythic", Rate = 700, Cost = 18000,
		Body = Color3.fromRGB(128, 0, 128), Head = Color3.fromRGB(255, 215, 0), Accent = Color3.fromRGB(255, 0, 110),
		Height = 6, Joke = "King of the fruit salad. Bow down." },
	{ Id = "dewa_durian", Name = "Dewa Durian", Rarity = "Mythic", Rate = 1500, Cost = 40000,
		Body = Color3.fromRGB(60, 140, 40), Head = Color3.fromRGB(120, 200, 60), Accent = Color3.fromRGB(255, 230, 0),
		Height = 6, Joke = "Smells like victory. And durian." },
	{ Id = "bayangan_bakso", Name = "Bayangan Bakso", Rarity = "Secret", Rate = 4000, Cost = 120000,
		Body = Color3.fromRGB(30, 30, 40), Head = Color3.fromRGB(60, 60, 80), Accent = Color3.fromRGB(170, 0, 255),
		Height = 6, Joke = "The meatball that was never served." },
}

local byId = {}
for _, entry in ipairs(BrainrotData.CAST) do
	byId[entry.Id] = entry
end

function BrainrotData.getById(id)
	return byId[id]
end

-- Pick a rarity by weight, so Commons flood the belt and Secrets
-- are a genuine event when one shows up.
function BrainrotData.rollRarity(rng)
	local total = 0
	for _, rarity in pairs(BrainrotData.RARITIES) do
		total += rarity.Weight
	end
	local roll = rng:NextNumber(0, total)
	for name, rarity in pairs(BrainrotData.RARITIES) do
		roll -= rarity.Weight
		if roll <= 0 then
			return name
		end
	end
	return "Common"
end

-- Pick a mutation. A surge event passes a luck boost that shifts
-- the odds toward the rare end of the table.
function BrainrotData.rollMutation(rng, luckBoost)
	local luckBoost = luckBoost or 1
	local roll = rng:NextNumber(0, 1)
	local cursor = 0
	for _, mutation in ipairs(BrainrotData.MUTATIONS) do
		local chance = mutation.Chance
		if mutation.Name ~= "None" then
			chance = chance * luckBoost
		end
		cursor += chance
		if roll <= cursor then
			return mutation
		end
	end
	return BrainrotData.MUTATIONS[1]
end

-- Roll one full brainrot: rarity first, then a random member of it.
function BrainrotData.rollBrainrot(rng, luckBoost)
	local rarity = BrainrotData.rollRarity(rng)
	local pool = {}
	for _, entry in ipairs(BrainrotData.CAST) do
		if entry.Rarity == rarity then
			table.insert(pool, entry)
		end
	end
	if #pool == 0 then
		return BrainrotData.CAST[1], BrainrotData.MUTATIONS[1]
	end
	local entry = pool[rng:NextInteger(1, #pool)]
	return entry, BrainrotData.rollMutation(rng, luckBoost)
end

-- The money a brainrot earns per second, after mutation, rebirth
-- multiplier and any live event multiplier.
function BrainrotData.effectiveRate(entry, mutation, rebirthMultiplier, eventMultiplier)
	return entry.Rate * mutation.Multiplier * rebirthMultiplier * eventMultiplier
end

-- The label a brainrot shows above its head on its name tag.
function BrainrotData.displayName(entry, mutation)
	if mutation.Name == "None" then
		return entry.Name
	end
	return mutation.Name .. " " .. entry.Name
end

return BrainrotData
