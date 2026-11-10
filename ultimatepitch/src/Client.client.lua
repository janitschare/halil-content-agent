-- UltimatePitch v0.5 · Client (HUD, Eingaben, Effekte, Sound, Grafikprofile).
-- Sendet nur Absichten; Ladung, Ausdauer, Tore entscheidet der Server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local SHARED = RS:WaitForChild("UltimatePitch")
local State = SHARED:WaitForChild("State")
local Kick = SHARED:WaitForChild("Kick")
local Effect = SHARED:WaitForChild("Effect")
local AuroraFX = require(script:WaitForChild("AuroraFX"))

local RED = Color3.fromRGB(200, 30, 45)
local BLUE = Color3.fromRGB(30, 80, 220)
local PANEL = Color3.fromRGB(10, 14, 24)
local ACCENT = Color3.fromRGB(40, 210, 255)
local AURORA = Color3.fromRGB(70, 255, 150)

local gui = Instance.new("ScreenGui")
gui.Name = "UltimatePitchHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		o.BackgroundTransparency = 1
		o.Font = Enum.Font.GothamBold
		o.TextColor3 = Color3.new(1, 1, 1)
	end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent or gui
	return o
end
local function corner(o, r) make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) return o end

---------------------------------------------------------------- Anzeigetafel (oben links, Broadcast-Stil)
local touchOnly = UIS.TouchEnabled and not UIS.KeyboardEnabled
local bug = make("Frame", { Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(318, 38), BackgroundTransparency = 1 })
local function cell(x, w, color, text, font)
	local f = corner(make("Frame", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 38), BackgroundColor3 = color }, bug), 4)
	local l = make("TextLabel", { Size = UDim2.fromScale(1, 1), Text = text, TextSize = 18, Font = font or Enum.Font.GothamBlack }, f)
	return f, l
end
local badge = cell(0, 38, ACCENT, "UP")
badge:FindFirstChildOfClass("TextLabel").TextColor3 = PANEL
cell(40, 60, RED, "ROT")
local _, scoreLabel = cell(102, 72, PANEL, "0 – 0")
scoreLabel.TextSize = 22
cell(176, 60, BLUE, "BLAU")
local clockCell, clockLabel = cell(238, 80, Color3.fromRGB(24, 30, 44), "0:00", Enum.Font.GothamBold)
clockLabel.TextColor3 = Color3.fromRGB(255, 230, 140)
local phasePill = corner(make("Frame", { Position = UDim2.fromOffset(40, 41), Size = UDim2.fromOffset(278, 20),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.25 }, bug), 4)
local phaseLabel = make("TextLabel", { Size = UDim2.fromScale(1, 1), TextSize = 12, Text = "LOBBY",
	TextColor3 = Color3.fromRGB(190, 205, 230) }, phasePill)

-- Mitte: Meldungen des Servers
local big = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 60),
	TextSize = 40, Font = Enum.Font.GothamBlack, TextTransparency = 1, TextStrokeTransparency = 1 })
local fade
local function showMsg(text)
	if fade then fade:Cancel() end
	big.Text = text or ""
	big.TextTransparency, big.TextStrokeTransparency = 0, 0.4
	fade = TweenService:Create(big, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.2),
		{ TextTransparency = 1, TextStrokeTransparency = 1 })
	fade:Play()
end

local function fmt(t) return string.format("%d:%02d", t // 60, t % 60) end
local PHASE_TEXT = { Lobby = "LOBBY · WARTE AUF SPIELER", Playing = "LIVE · SPECTRA DOME", GoldenGoal = "GOLDEN GOAL",
	Goal = "TOR", End = "ABPFIFF" }
local function refresh()
	local r, b = State:GetAttribute("RedScore") or 0, State:GetAttribute("BlueScore") or 0
	scoreLabel.Text = string.format("%d – %d", r, b)
	local ph = State:GetAttribute("Phase") or "Lobby"
	local t = State:GetAttribute("TimeLeft") or 0
	if ph == "Intermission" then
		phaseLabel.Text = "ANPFIFF IN " .. t .. " S"
		clockLabel.Text = "–:––"
	else
		phaseLabel.Text = PHASE_TEXT[ph] or string.upper(ph)
		clockLabel.Text = (ph == "GoldenGoal") and "GG" or fmt(t)
	end
	phaseLabel.TextColor3 = (ph == "Playing" or ph == "GoldenGoal") and Color3.fromRGB(120, 255, 170) or Color3.fromRGB(190, 205, 230)
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

---------------------------------------------------------------- Untere Leiste: Ausdauer, Schuss, AURORA-Kachel
local dock = corner(make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(330, 62),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.25 }), 8)
local function meter(y, title, color)
	make("TextLabel", { Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(80, 14), Text = title, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(170, 185, 210) }, dock)
	local back = corner(make("Frame", { Position = UDim2.fromOffset(92, y + 2), Size = UDim2.fromOffset(150, 10),
		BackgroundColor3 = Color3.fromRGB(30, 36, 52) }, dock), 5)
	local fill = corner(make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, back), 5)
	return back, fill
end
local _, staminaFill = meter(14, "AUSDAUER", Color3.fromRGB(80, 220, 120))
local chargeBack, chargeFill = meter(36, "SCHUSS", Color3.fromRGB(255, 170, 40))
chargeFill.Size = UDim2.fromScale(0, 1)

local skillTile = corner(make("Frame", { Position = UDim2.fromOffset(254, 6), Size = UDim2.fromOffset(68, 50),
	BackgroundColor3 = Color3.fromRGB(18, 40, 32), ClipsDescendants = true }, dock), 6)
local skillFill = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = AURORA, BackgroundTransparency = 0.55 }, skillTile)
local skillKey = make("TextLabel", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 2), Text = touchOnly and "★" or "R",
	TextSize = 20, Font = Enum.Font.GothamBlack }, skillTile)
local skillText = make("TextLabel", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 28), Text = "AURORA", TextSize = 11,
	Font = Enum.Font.GothamBlack, TextColor3 = AURORA }, skillTile)

-- Hinweise und Grafikprofil (unten links)
local hint = make("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -10), Size = UDim2.new(0.5, -200, 0, 16),
	TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.3, TextTruncate = Enum.TextTruncate.AtEnd,
	Text = touchOnly and "Schuss halten = aufladen · Pass · Sprint · AURORA · FX/GFX oben rechts"
		or "F/Klick halten Schuss · E Pass · Shift Sprint · R AURORA · M Effekte · G Grafik" })
local gfxLabel = make("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -28), Size = UDim2.fromOffset(240, 14),
	TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.45, Text = "" })

---------------------------------------------------------------- Markierung über der eigenen Figur
local function markOwn(char)
	local head = char:WaitForChild("Head", 10)
	if not head then return end
	local bb = make("BillboardGui", { Name = "UP_YouMarker", Adornee = head, Size = UDim2.fromOffset(26, 20), StudsOffset = Vector3.new(0, 4.1, 0),
		AlwaysOnTop = true, LightInfluence = 0 }, head)
	make("TextLabel", { Size = UDim2.fromScale(1, 1), Text = "▼", TextScaled = true, Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 220, 90), TextStrokeTransparency = 0.4 }, bb)
end
player.CharacterAdded:Connect(markOwn)
if player.Character then task.spawn(markOwn, player.Character) end

-- R15-Bewegungsebene (Sprint, Ballkontakte, Annahme, Torjubel) – nur Darstellung
AuroraFX.startMotion(State)

---------------------------------------------------------------- Ballbesitz: Leuchtring unter dem Spieler am Ball
-- Rein optisch; den Besitz bestimmt der Server (State@BallOwner = UserId, 0 = frei)
local RING_SEGMENTS, RING_RADIUS = 16, 2.5
local ringFolder = Instance.new("Folder")
ringFolder.Name = "UP_PossessionRing"
ringFolder.Parent = workspace
local ringParts = {}
for i = 1, RING_SEGMENTS do
	local seg = Instance.new("Part")
	seg.Size = Vector3.new(0.25, 0.06, 2 * math.pi * RING_RADIUS / RING_SEGMENTS * 0.8)
	seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
	seg.Material = Enum.Material.Neon
	seg.Transparency = 1
	seg.Parent = ringFolder
	ringParts[i] = seg
end
local ringVisible = false
RunService.RenderStepped:Connect(function()
	-- Ballführer = Mensch oder Bot (State.BallCarrier); Teamfarbe über Spielerteam bzw. Bot-Attribut
	local carrierValue = State:FindFirstChild("BallCarrier")
	local carrier = carrierValue and carrierValue.Value
	local root = carrier and carrier.Parent and carrier:FindFirstChild("HumanoidRootPart")
	local hum = carrier and carrier:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		if ringVisible then
			for _, seg in ipairs(ringParts) do seg.Transparency = 1 end
			ringVisible = false
		end
		return
	end
	local feet = Vector3.new(root.Position.X, root.Position.Y - hum.HipHeight - root.Size.Y / 2 + 0.06, root.Position.Z)
	local cPlr = Players:GetPlayerFromCharacter(carrier)
	local cTeam = cPlr and cPlr.Team and cPlr.Team.Name or carrier:GetAttribute("Team")
	local color = cTeam == "Rot" and RED or BLUE
	local spin = AuroraFX.reducedMotion and 0 or os.clock() * 1.5 -- bei reduzierter Bewegung steht der Ring
	for i, seg in ipairs(ringParts) do
		local a = spin + (i / RING_SEGMENTS) * math.pi * 2
		local pos = feet + Vector3.new(math.cos(a), 0, math.sin(a)) * RING_RADIUS
		seg.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
		seg.Color = color
		seg.Transparency = 0.1
	end
	ringVisible = true
end)

---------------------------------------------------------------- Reduzierte Bewegung
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

---------------------------------------------------------------- Sound: Stadionatmosphäre und Torjubel (lokal)
-- Freie Soundeffekte von „ProSoundEffects“ (Roblox Creator Store), kein eigener Upload
local ambience = make("Sound", { Name = "UP_Ambience", SoundId = "rbxassetid://9119562234", Looped = true, Volume = 0.25 }, SoundService) -- Stadium Crowd 1
local roar = make("Sound", { Name = "UP_GoalRoar", SoundId = "rbxassetid://9120974125", Volume = 0 }, SoundService) -- Wrestling Crowd 1 (Surges)
ambience:Play()
local function ambienceLevel()
	local ph = State:GetAttribute("Phase") or "Lobby"
	local target = (ph == "Playing" or ph == "GoldenGoal" or ph == "Goal") and 0.45 or 0.2
	TweenService:Create(ambience, TweenInfo.new(1.5), { Volume = target }):Play()
end
State:GetAttributeChangedSignal("Phase"):Connect(ambienceLevel)
ambienceLevel()
local roarToken = 0
local function goalRoar(aurora)
	roarToken += 1
	local my = roarToken
	roar.TimePosition = 0
	roar.Volume = aurora and 1.1 or 0.9
	roar:Play()
	task.delay(5, function()
		if my ~= roarToken then return end
		local tw = TweenService:Create(roar, TweenInfo.new(2), { Volume = 0 })
		tw.Completed:Connect(function() if my == roarToken then roar:Stop() end end)
		tw:Play()
	end)
end

---------------------------------------------------------------- Server-Ereignisse
Effect.OnClientEvent:Connect(function(kind, userId, arg)
	if type(userId) ~= "number" then return end
	local ball = workspace:FindFirstChild("UltimatePitch") and workspace.UltimatePitch:FindFirstChild("Ball")
	if kind == "AuroraWindup" then AuroraFX.windup(userId, tonumber(arg) or 0.3)
	elseif kind == "AuroraKick" then AuroraFX.kick(userId, ball)
	elseif kind == "AuroraCancel" then AuroraFX.cancel(userId)
	elseif kind == "KickAnim" and typeof(arg) == "Instance" and arg:IsA("Model") then AuroraFX.quickKick(arg, ball) end
end)

-- GOAL-Cinematic und Jubel nur auf das serverbestätigte Tor-Ereignis
local lastGoalSeq = State:GetAttribute("GoalSeq") or 0
State:GetAttributeChangedSignal("GoalSeq"):Connect(function()
	local seq = State:GetAttribute("GoalSeq") or 0
	if seq > lastGoalSeq then
		local aurora = State:GetAttribute("LastGoalAurora") == true
		AuroraFX.goal(gui, State:GetAttribute("LastGoalTeam") or "", aurora)
		goalRoar(aurora)
	end
	lastGoalSeq = seq
end)

---------------------------------------------------------------- Grafikprofile (nur lokale Darstellung)
-- Hoch: alles, Flutlicht-Schatten an. Mittel: ohne Einzelfiguren im Publikum, ohne Schatten.
-- Niedrig: ohne Publikum, ohne Bloom, dünnere Atmosphäre, halbe Effektmenge. Kollisionen bleiben unverändert.
local PROFILES = { "Hoch", "Mittel", "Niedrig" }
local profile
local function autoProfile()
	local ok, level = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	level = ok and level or 0
	if level == 0 then return UIS.TouchEnabled and "Mittel" or "Hoch" end
	if level <= 3 then return "Niedrig" elseif level <= 6 then return "Mittel" end
	return "Hoch"
end
local function styleCrowd(p)
	local hide = profile == "Niedrig" or (profile == "Mittel" and CollectionService:HasTag(p, "UP_CrowdDetail"))
	p.LocalTransparencyModifier = hide and 1 or 0
end
local function styleLight(l)
	l.Shadows = profile == "Hoch"
end
local function applyProfile(name)
	profile = name
	for _, p in ipairs(CollectionService:GetTagged("UP_Crowd")) do styleCrowd(p) end
	for _, l in ipairs(CollectionService:GetTagged("UP_FieldLight")) do styleLight(l) end
	local bloom = Lighting:FindFirstChild("UP_Bloom")
	if bloom then bloom.Enabled = name ~= "Niedrig" end
	local atmo = Lighting:FindFirstChild("UP_Atmosphere")
	if atmo then atmo.Density = name == "Niedrig" and 0.12 or 0.26 end
	AuroraFX.fxScale = name == "Niedrig" and 0.5 or 1
	gfxLabel.Text = "GRAFIK: " .. string.upper(name) .. (touchOnly and "" or "  (G)")
end
-- Matchday-Atmosphäre: Anstoß-Intro und Torjubel im Stadion (rein optisch, siehe Matchday.lua)
local Matchday = require(script:WaitForChild("Matchday"))
Matchday.start(State, gui, {
	reducedMotion = function() return AuroraFX.reducedMotion end,
	fxScale = function() return AuroraFX.fxScale end,
	profile = function() return profile end,
})
CollectionService:GetInstanceAddedSignal("UP_Crowd"):Connect(function(p) if profile then styleCrowd(p) end end)
CollectionService:GetInstanceAddedSignal("UP_FieldLight"):Connect(function(l) if profile then styleLight(l) end end)
applyProfile(autoProfile())
task.delay(3, function() applyProfile(profile) end) -- Lighting-Effekte entstehen serverseitig evtl. später
local function cycleProfile()
	local i = table.find(PROFILES, profile) or 1
	applyProfile(PROFILES[i % #PROFILES + 1])
	showMsg("Grafik: " .. profile)
end

---------------------------------------------------------------- Laufende Anzeige
local charging, chargeStart = false, 0
local CHARGE_TIME = 1 -- nur Anzeige; die gültige Ladung misst der Server
local COOLDOWN = 12   -- nur Anzeige der Kachelfüllung; das Ende kommt als Server-Zeitstempel

RunService.RenderStepped:Connect(function()
	local stamina = (player:GetAttribute("Stamina") or 100) / 100
	staminaFill.Size = UDim2.fromScale(stamina, 1)
	staminaFill.BackgroundColor3 = stamina < 0.25 and Color3.fromRGB(230, 70, 60) or Color3.fromRGB(80, 220, 120)
	chargeFill.Size = UDim2.fromScale(charging and math.clamp((os.clock() - chargeStart) / CHARGE_TIME, 0, 1) or 0, 1)
	chargeBack.BackgroundTransparency = charging and 0 or 0.5
	local left = (player:GetAttribute("AuroraReady") or 0) - workspace:GetServerTimeNow()
	if left > 0 then
		skillFill.Size = UDim2.fromScale(1, 1 - math.clamp(left / COOLDOWN, 0, 1))
		skillFill.BackgroundTransparency = 0.75
		skillText.Text = string.format("%ds", math.ceil(left))
		skillText.TextColor3 = Color3.fromRGB(150, 160, 175)
	else
		skillFill.Size = UDim2.fromScale(1, 1)
		skillFill.BackgroundTransparency = 0.45 + 0.15 * math.sin(os.clock() * 4)
		skillText.Text = "AURORA"
		skillText.TextColor3 = AURORA
	end
end)

---------------------------------------------------------------- Eingaben
local function shot(_, st)
	if st == Enum.UserInputState.Begin then
		charging, chargeStart = true, os.clock()
		Kick:FireServer("ChargeStart")
	elseif st == Enum.UserInputState.End and charging then
		charging = false
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

CAS:BindAction("UP_Pass", function(_, st)
	if st == Enum.UserInputState.Begin then Kick:FireServer("Pass") end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
CAS:SetTitle("UP_Pass", "Pass")

local function toggleReducedMotion()
	AuroraFX.reducedMotion = not AuroraFX.reducedMotion
	showMsg(AuroraFX.reducedMotion and "Effekte reduziert" or "Effekte voll")
end
CAS:BindAction("UP_ReducedMotion", function(_, st)
	if st == Enum.UserInputState.Begin then toggleReducedMotion() end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.M)
CAS:BindAction("UP_Graphics", function(_, st)
	if st == Enum.UserInputState.Begin then cycleProfile() end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.G)

-- Touch-Geräte haben keine M-/G-Taste: kleine Schalter oben rechts
if UIS.TouchEnabled then
	local function topButton(name, x, text, onClick)
		local b = corner(make("TextButton", { Name = name, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, 8),
			Size = UDim2.fromOffset(56, 36), BackgroundColor3 = PANEL, BackgroundTransparency = 0.2, TextSize = 15, Text = text }), 10)
		b.Activated:Connect(function() onClick(b) end)
		return b
	end
	local fx = topButton("UP_FXToggle", -10, AuroraFX.reducedMotion and "FX–" or "FX", function(b)
		toggleReducedMotion()
		b.Text = AuroraFX.reducedMotion and "FX–" or "FX"
	end)
	fx.Text = AuroraFX.reducedMotion and "FX–" or "FX"
	topButton("UP_GFXToggle", -72, "GFX", function() cycleProfile() end)
end

CAS:SetPosition("UP_Shot", UDim2.new(0.15, 0, 0.05, 0))
CAS:SetPosition("UP_Pass", UDim2.new(-0.25, 0, 0.45, 0))
CAS:SetPosition("UP_Sprint", UDim2.new(-0.25, 0, 0.0, 0))
CAS:SetPosition("UP_Aurora", UDim2.new(0.15, 0, 0.5, 0))
