-- UltimatePitch v0.4 · Client (HUD, Sprint, Schusskraft)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local SHARED = RS:WaitForChild("UltimatePitch")
local State = SHARED:WaitForChild("State")
local Kick = SHARED:WaitForChild("Kick")

local gui = Instance.new("ScreenGui")
gui.Name = "UltimatePitchHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do l[k] = v end
	l.Parent = props.Parent or gui
	return l
end

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 8)
bar.Size = UDim2.fromOffset(320, 66)
bar.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
bar.BackgroundTransparency = 0.2
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)

local score = label({ Parent = bar, Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 4),
	RichText = true, TextSize = 26, Font = Enum.Font.GothamBlack })
local info = label({ Parent = bar, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 40),
	TextSize = 16, TextColor3 = Color3.fromRGB(255, 210, 60) })
local big = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(700, 70),
	TextSize = 44, Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.3, TextTransparency = 1 })
big.TextStrokeTransparency = 1
label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(420, 20),
	TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.25,
	Text = "F / Klick halten = Schuss   ·   E = Pass   ·   Shift = Sprint" })

local function fmt(t) return string.format("%d:%02d", t // 60, t % 60) end

local function refresh()
	local r, b = State:GetAttribute("RedScore") or 0, State:GetAttribute("BlueScore") or 0
	score.Text = string.format('<font color="#ff5a5a">ROT</font>  %d : %d  <font color="#6f9bff">BLAU</font>', r, b)
	local ph = State:GetAttribute("Phase") or "Lobby"
	local t = State:GetAttribute("TimeLeft") or 0
	if ph == "Lobby" then info.Text = "Lobby · warte auf Spieler"
	elseif ph == "Intermission" then info.Text = "Anpfiff in " .. t .. "s"
	elseif ph == "Playing" then info.Text = fmt(t)
	elseif ph == "GoldenGoal" then info.Text = "⚡ GOLDEN GOAL"
	elseif ph == "Goal" then info.Text = "TOR!"
	else info.Text = "Abpfiff" end
end

local fade
local function showMsg(text)
	if fade then fade:Cancel() end
	big.Text = text or ""
	big.TextTransparency, big.TextStrokeTransparency = 0, 0.3
	fade = TweenService:Create(big, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.2),
		{ TextTransparency = 1, TextStrokeTransparency = 1 })
	fade:Play()
end

State.AttributeChanged:Connect(function(name)
	refresh()
	if name == "MessageId" then showMsg(State:GetAttribute("Message")) end
end)
refresh()

local RunService = game:GetService("RunService")

-- Leisten (Ausdauer + Schusskraft)
local function meter(y, color)
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, y)
	back.Size = UDim2.fromOffset(220, 10)
	back.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	back.BackgroundTransparency = 0.3
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	return back, fill
end
local _, staminaFill = meter(-40, Color3.fromRGB(80, 220, 120))
local chargeBack, chargeFill = meter(-56, Color3.fromRGB(255, 170, 40))
chargeBack.Visible = false

local stamina, sprinting = 1, false
local charging, chargeStart = false, 0
local CHARGE_TIME = 1

local function chargeLevel()
	return math.clamp((os.clock() - chargeStart) / CHARGE_TIME, 0, 1)
end

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local base = char:GetAttribute("BaseSpeed") or 16
		local moving = hum.MoveDirection.Magnitude > 0.1
		local active = sprinting and moving and stamina > 0
		if active then stamina = math.max(0, stamina - dt / 4) else stamina = math.min(1, stamina + dt / 6) end
		hum.WalkSpeed = active and base * 1.45 or base
	end
	staminaFill.Size = UDim2.fromScale(stamina, 1)
	staminaFill.BackgroundColor3 = stamina < 0.25 and Color3.fromRGB(230, 70, 60) or Color3.fromRGB(80, 220, 120)
	if charging then chargeFill.Size = UDim2.fromScale(chargeLevel(), 1) end
end)

local function shot(_, st)
	if st == Enum.UserInputState.Begin then
		charging, chargeStart = true, os.clock()
		chargeBack.Visible = true
	elseif st == Enum.UserInputState.End and charging then
		charging = false
		chargeBack.Visible = false
		Kick:FireServer("Shot", chargeLevel())
	end
	return Enum.ContextActionResult.Pass
end
CAS:BindAction("UP_Shot", shot, true, Enum.KeyCode.F, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
CAS:SetTitle("UP_Shot", "Schuss")

CAS:BindAction("UP_Sprint", function(_, st)
	if st == Enum.UserInputState.Begin then sprinting = true
	elseif st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then sprinting = false end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
CAS:SetTitle("UP_Sprint", "Sprint")

CAS:BindAction("UP_Pass", function(_, st)
	if st == Enum.UserInputState.Begin then Kick:FireServer("Pass") end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
CAS:SetTitle("UP_Pass", "Pass")

CAS:SetPosition("UP_Shot", UDim2.new(0.15, 0, 0.05, 0))
CAS:SetPosition("UP_Pass", UDim2.new(-0.25, 0, 0.45, 0))
CAS:SetPosition("UP_Sprint", UDim2.new(-0.25, 0, 0.0, 0))
