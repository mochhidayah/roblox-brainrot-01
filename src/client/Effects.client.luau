-- Brainrot Bay: client effects. No gameplay logic lives here, only
-- feedback: the screen shakes when the tsunami comes, a gold flash
-- marks Golden Hour, and every income tick floats a "+$X" up the
-- screen. Small things, but they are what make a buy feel good.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local incomeTick = remotes:WaitForChild("IncomeTick")
local eventAlert = remotes:WaitForChild("EventAlert")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotBayEffects"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

-- A full-screen flash frame: red for the wave, gold for Golden Hour.
local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local function flashScreen(color, peak)
	flash.BackgroundColor3 = color
	local tweenIn = TweenService:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 - peak })
	tweenIn:Play()
	tweenIn.Completed:Wait()
	local tweenOut = TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
	tweenOut:Play()
end

-- Shake the camera for a second: the wave is coming.
local function shakeCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local start = camera.CFrame
	for _ = 1, 20 do
		local offset = Vector3.new(math.random(-2, 2) * 0.3, math.random(-2, 2) * 0.3, 0)
		camera.CFrame = start * CFrame.new(offset)
		task.wait(0.05)
	end
	camera.CFrame = start
end

eventAlert.OnClientEvent:Connect(function(name, _text)
	if name == "TsunamiWarning" then
		task.spawn(function()
			flashScreen(Color3.fromRGB(255, 0, 0), 0.25)
			shakeCamera()
		end)
	elseif name == "Tsunami" then
		task.spawn(function()
			flashScreen(Color3.fromRGB(0, 120, 200), 0.35)
			shakeCamera()
		end)
	elseif name == "GoldenHour" then
		task.spawn(function()
			flashScreen(Color3.fromRGB(255, 215, 0), 0.3)
		end)
	elseif name == "MutationSurge" then
		task.spawn(function()
			flashScreen(Color3.fromRGB(155, 89, 182), 0.25)
		end)
	end
end)

-- A "+$X" that floats up from the bottom centre on every income tick.
incomeTick.OnClientEvent:Connect(function(amount)
	if amount <= 0 then
		return
	end
	local floater = Instance.new("TextLabel")
	floater.Name = "IncomeFloater"
	floater.Text = "+$" .. tostring(amount)
	floater.Size = UDim2.fromOffset(120, 30)
	floater.Position = UDim2.new(0.5, -60 + math.random(-40, 40), 1, -160)
	floater.TextSize = 20
	floater.Font = Enum.Font.GothamBold
	floater.TextColor3 = Color3.fromRGB(120, 255, 120)
	floater.BackgroundTransparency = 1
	floater.TextStrokeTransparency = 0.5
	floater.Parent = gui
	local tween = TweenService:Create(floater, TweenInfo.new(1.2), {
		Position = floater.Position + UDim2.fromOffset(0, -70),
		TextTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		floater:Destroy()
	end)
end)

print("Brainrot Bay effects are live.")
