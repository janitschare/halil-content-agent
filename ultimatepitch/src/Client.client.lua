-- UltimatePitch v0.4 · Client (HUD, Eingaben, Effekte). Sendet nur Absichten; Ladung, Ausdauer, Tore entscheidet der Server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local SHARED = RS:WaitForChild("UltimatePitch")
local State = SHARED:WaitForChild("State")
local Kick = SHARED:WaitForChild("Kick")
local Effect = SHARED:WaitForChild("Effect")
local AuroraFX = require(script:WaitForChild("AuroraFX"))

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
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local touchOnly = UIS.TouchEnabled and not UIS.KeyboardEnabled
label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 20),
	TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.25, TextTruncate = Enum.TextTruncate.AtEnd,
	Text = touchOnly and "Schuss halten = aufladen  ·  Pass  ·  Sprint halten  ·  AURORA  ·  FX = Effekte reduzieren"
		or "F / Klick halten = Schuss  ·  E = Pass  ·  Shift = Sprint  ·  R = AURORA BREAK  ·  M = Effekte reduzieren" })

-- Reduzierte Bewegung: Systemeinstellung des Spielers als Vorgabe übernehmen (M bzw. FX-Knopf schaltet um)
local function systemReducedMotion()
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end
AuroraFX.reducedMotion = systemReducedMotion()
pcall(function()
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		AuroraFX.reducedMotion = systemReducedMotion()
	end)
end)

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

local REJECTS = { TooFar = "Zu weit vom Ball!", NoCharge = "Schuss nicht aufgeladen", Cooldown = "AURORA BREAK lädt noch", NoStamina = "Zu wenig Ausdauer" }
Kick.OnClientEvent:Connect(function(what)
	if REJECTS[what] then showMsg(REJECTS[what]) end
end)

-- Skill-Effekte: Server meldet Anlauf, Kick-Marker-Schuss und Abbruch
Effect.OnClientEvent:Connect(function(kind, userId, arg)
	if type(userId) ~= "number" then return end
	if kind == "AuroraWindup" then AuroraFX.windup(userId, tonumber(arg) or 0.3)
	elseif kind == "AuroraKick" then AuroraFX.kick(userId, workspace:FindFirstChild("UltimatePitch") and workspace.UltimatePitch:FindFirstChild("Ball"))
	elseif kind == "AuroraCancel" then AuroraFX.cancel(userId) end
end)

-- GOAL-Cinematic nur auf das serverbestätigte Tor-Ereignis
local lastGoalSeq = State:GetAttribute("GoalSeq") or 0
State:GetAttributeChangedSignal("GoalSeq"):Connect(function()
	local seq = State:GetAttribute("GoalSeq") or 0
	if seq > lastGoalSeq then
		AuroraFX.goal(gui, State:GetAttribute("LastGoalTeam") or "", State:GetAttribute("LastGoalAurora") == true)
	end
	lastGoalSeq = seq
end)

-- Grafikprofil: bei niedriger Qualitätsstufe Zuschauer und Sitzreihen lokal ausblenden (Kollisionen unverändert)
local function applyProfile()
	local ok, level = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	local low = ok and level > 0 and level <= 3
	for _, p in ipairs(CollectionService:GetTagged("UP_Crowd")) do
		p.LocalTransparencyModifier = low and 1 or 0
	end
end
task.delay(3, applyProfile)

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

-- Skill-Anzeige: AURORA BREAK bereit / Restsekunden (Cooldown-Ende kommt als Server-Zeitstempel)
local skill = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -72), Size = UDim2.fromOffset(260, 22),
	TextSize = 15, TextColor3 = Color3.fromRGB(70, 255, 150), Text = "R  AURORA BREAK  bereit" })

local charging, chargeStart = false, 0
local CHARGE_TIME = 1 -- nur Anzeige; die gültige Ladung misst der Server

local function chargeLevel()
	return math.clamp((os.clock() - chargeStart) / CHARGE_TIME, 0, 1)
end

RunService.RenderStepped:Connect(function()
	local stamina = (player:GetAttribute("Stamina") or 100) / 100
	staminaFill.Size = UDim2.fromScale(stamina, 1)
	staminaFill.BackgroundColor3 = stamina < 0.25 and Color3.fromRGB(230, 70, 60) or Color3.fromRGB(80, 220, 120)
	if charging then chargeFill.Size = UDim2.fromScale(chargeLevel(), 1) end
	local left = (player:GetAttribute("AuroraReady") or 0) - workspace:GetServerTimeNow()
	skill.Text = left > 0 and string.format("R  AURORA BREAK  %ds", math.ceil(left)) or "R  AURORA BREAK  bereit"
	skill.TextColor3 = left > 0 and Color3.fromRGB(150, 160, 175) or Color3.fromRGB(70, 255, 150)
end)

local function shot(_, st)
	if st == Enum.UserInputState.Begin then
		charging, chargeStart = true, os.clock()
		chargeBack.Visible = true
		Kick:FireServer("ChargeStart")
	elseif st == Enum.UserInputState.End and charging then
		charging = false
		chargeBack.Visible = false
		Kick:FireServer("Shot")
	end
	return Enum.ContextActionResult.Pass
end
CAS:BindAction("UP_Shot", shot, true, Enum.KeyCode.F, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
CAS:SetTitle("UP_Shot", "Schuss")

CAS:BindAction("UP_Sprint", function(_, st)
	if st == Enum.UserInputState.Begin then Kick:FireServer("Sprint", true)
	elseif st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then Kick:FireServer("Sprint", false) end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
CAS:SetTitle("UP_Sprint", "Sprint")

CAS:BindAction("UP_Aurora", function(_, st)
	if st == Enum.UserInputState.Begin then Kick:FireServer("Aurora") end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
CAS:SetTitle("UP_Aurora", "AURORA")

local function toggleReducedMotion()
	AuroraFX.reducedMotion = not AuroraFX.reducedMotion
	showMsg(AuroraFX.reducedMotion and "Effekte reduziert" or "Effekte voll")
end
CAS:BindAction("UP_ReducedMotion", function(_, st)
	if st == Enum.UserInputState.Begin then toggleReducedMotion() end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.M)

-- Touch-Geräte haben keine M-Taste: kleiner FX-Schalter oben rechts
if UIS.TouchEnabled then
	local fx = Instance.new("TextButton")
	fx.Name = "UP_FXToggle"
	fx.AnchorPoint = Vector2.new(1, 0)
	fx.Position = UDim2.new(1, -10, 0, 8)
	fx.Size = UDim2.fromOffset(56, 36)
	fx.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	fx.BackgroundTransparency = 0.2
	fx.Font = Enum.Font.GothamBold
	fx.TextSize = 15
	fx.TextColor3 = Color3.new(1, 1, 1)
	fx.Text = "FX"
	Instance.new("UICorner", fx).CornerRadius = UDim.new(0, 10)
	fx.Parent = gui
	fx.Activated:Connect(function()
		toggleReducedMotion()
		fx.Text = AuroraFX.reducedMotion and "FX–" or "FX"
	end)
	fx.Text = AuroraFX.reducedMotion and "FX–" or "FX"
end

CAS:BindAction("UP_Pass", function(_, st)
	if st == Enum.UserInputState.Begin then Kick:FireServer("Pass") end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
CAS:SetTitle("UP_Pass", "Pass")

CAS:SetPosition("UP_Shot", UDim2.new(0.15, 0, 0.05, 0))
CAS:SetPosition("UP_Pass", UDim2.new(-0.25, 0, 0.45, 0))
CAS:SetPosition("UP_Sprint", UDim2.new(-0.25, 0, 0.0, 0))
CAS:SetPosition("UP_Aurora", UDim2.new(0.15, 0, 0.5, 0))
