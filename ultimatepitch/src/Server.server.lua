-- UltimatePitch v0.4 · Server (baut die Welt beim Start selbst)
local VERSION = "0.4"
local GY = 1

local RS = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- Alte Reste (v0.3-Installer) entfernen
for _, pair in ipairs({
	{ workspace, "UltimatePitch" }, { RS, "UltimatePitch" },
	{ Teams, "Lobby" }, { Teams, "Rot" }, { Teams, "Blau" },
}) do
	local obj = pair[1]:FindFirstChild(pair[2])
	if obj then obj:Destroy() end
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") then d.Enabled = false end
end
local oldServer = game:GetService("ServerScriptService"):FindFirstChild("UltimatePitchServer")
if oldServer and oldServer ~= script then oldServer:Destroy() end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function part(props, parent)
	local p = new("Part", { Anchored = true, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, nil)
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

do
------------------------------------------------------------------ Workspace
local root = new("Folder", { Name = "UltimatePitch" }, workspace)
root:SetAttribute("Version", VERSION)
local field = new("Folder", { Name = "Field" }, root)
local goals = new("Folder", { Name = "Goals" }, root)
local walls = new("Folder", { Name = "Walls" }, root)
local lobby = new("Folder", { Name = "Lobby" }, root)
new("Folder", { Name = "Bots" }, root)

local GRASS = Color3.fromRGB(58, 135, 58)
local GRASS2 = Color3.fromRGB(70, 152, 68)
local WHITE = Color3.fromRGB(245, 245, 245)

-- Rasen
part({ Name = "Ground", Size = Vector3.new(200, 1, 140), Position = Vector3.new(0, GY - 0.5, 0), Material = Enum.Material.Grass, Color = GRASS }, field)
for i = 0, 9 do
	if i % 2 == 0 then
		part({ Name = "Stripe", Size = Vector3.new(16, 0.04, 100), Position = Vector3.new(-80 + 8 + i * 16, GY + 0.02, 0),
			Material = Enum.Material.Grass, Color = GRASS2, CanCollide = false, CanQuery = false, CanTouch = false }, field)
	end
end

-- Linien
local function line(a, b)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	part({ Name = "Line", Size = Vector3.new(0.6, 0.04, len + 0.6), CFrame = CFrame.lookAt(mid, b),
		Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false }, field)
end
local y = GY + 0.05
local function v(x, z) return Vector3.new(x, y, z) end
line(v(-80, -50), v(80, -50)); line(v(-80, 50), v(80, 50))
line(v(-80, -50), v(-80, 50)); line(v(80, -50), v(80, 50))
line(v(0, -50), v(0, 50))
for _, s in ipairs({ -1, 1 }) do
	local x0, x1 = s * 80, s * 62
	line(v(x0, -22), v(x1, -22)); line(v(x0, 22), v(x1, 22)); line(v(x1, -22), v(x1, 22))
	local x2 = s * 74
	line(v(x0, -14), v(x2, -14)); line(v(x0, 14), v(x2, 14)); line(v(x2, -14), v(x2, 14))
end
local SEG = 36
for i = 0, SEG - 1 do
	local a1, a2 = i / SEG * math.pi * 2, (i + 1) / SEG * math.pi * 2
	line(v(math.cos(a1) * 10, math.sin(a1) * 10), v(math.cos(a2) * 10, math.sin(a2) * 10))
end

-- Tore (Rot greift +X an, Blau greift -X an)
for _, s in ipairs({ -1, 1 }) do
	local g = new("Model", { Name = s > 0 and "GoalBlau" or "GoalRot" }, goals)
	local net = { Color = WHITE, Material = Enum.Material.Fabric, Transparency = 0.45 }
	local function netPart(props)
		for k, val in pairs(net) do props[k] = props[k] or val end
		return part(props, g)
	end
	netPart({ Name = "Back", Size = Vector3.new(1, 11, 26), Position = Vector3.new(s * 86.5, GY + 5.5, 0) })
	netPart({ Name = "SideL", Size = Vector3.new(7, 11, 1), Position = Vector3.new(s * 83.5, GY + 5.5, -12.5) })
	netPart({ Name = "SideR", Size = Vector3.new(7, 11, 1), Position = Vector3.new(s * 83.5, GY + 5.5, 12.5) })
	netPart({ Name = "Roof", Size = Vector3.new(7, 1, 26), Position = Vector3.new(s * 83.5, GY + 10.5, 0) })
	part({ Name = "PostL", Size = Vector3.new(1, 10, 1), Position = Vector3.new(s * 80.5, GY + 5, -12.5), Color = WHITE, Material = Enum.Material.Metal }, g)
	part({ Name = "PostR", Size = Vector3.new(1, 10, 1), Position = Vector3.new(s * 80.5, GY + 5, 12.5), Color = WHITE, Material = Enum.Material.Metal }, g)
	part({ Name = "Bar", Size = Vector3.new(1, 1, 26), Position = Vector3.new(s * 80.5, GY + 10.5, 0), Color = WHITE, Material = Enum.Material.Metal }, g)
end

-- Banden (Glas, Lücke für Tore)
-- SmoothPlastic statt Glass: Glass blendet dahinterliegende SurfaceGuis (LED-Banden) aus
-- Transparenz 0.96: unter Nachtlicht würde eine sichtbarere Bande als heller Schleier über dem Feld liegen
local glass = { Material = Enum.Material.SmoothPlastic, Transparency = 0.96, Color = Color3.fromRGB(200, 230, 255) }
local function wall(size, pos)
	local p = part({ Name = "Wall", Size = size, Position = pos }, walls)
	for k, val in pairs(glass) do p[k] = val end
	return p
end
wall(Vector3.new(164, 20, 2), Vector3.new(0, GY + 10, -51))
wall(Vector3.new(164, 20, 2), Vector3.new(0, GY + 10, 51))
for _, s in ipairs({ -1, 1 }) do
	wall(Vector3.new(2, 20, 38), Vector3.new(s * 81, GY + 10, -31))
	wall(Vector3.new(2, 20, 38), Vector3.new(s * 81, GY + 10, 31))
	wall(Vector3.new(2, 10, 24), Vector3.new(s * 81, GY + 15, 0))
end
-- Deckel hält den Ball im Feld; unsichtbar, damit das offene Stadiondach sichtbar bleibt
wall(Vector3.new(164, 2, 104), Vector3.new(0, GY + 21, 0)).Transparency = 1

-- Ball
local ball = part({
	Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Anchored = false,
	Position = Vector3.new(0, GY + 3, 0), Color = WHITE, Material = Enum.Material.SmoothPlastic,
	CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.4, 0.5, 1, 1),
}, root)
local a0 = new("Attachment", { Position = Vector3.new(0, 0.4, 0) }, ball)
local a1 = new("Attachment", { Position = Vector3.new(0, -0.4, 0) }, ball)
new("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.25, Transparency = NumberSequence.new(0.4, 1) }, ball)

-- Lobby (schwebt über der Seitenlinie, Blick aufs Feld)
local LC = Vector3.new(0, 70, -240) -- hinter der Außenwand des SPECTRA DOME: vom Spielfeld aus nicht sichtbar
part({ Name = "Floor", Size = Vector3.new(50, 2, 40), Position = LC, Material = Enum.Material.Slate, Color = Color3.fromRGB(40, 44, 52) }, lobby)
for _, w in ipairs({
	{ Vector3.new(50, 8, 1), Vector3.new(0, 5, -20.5) },
	{ Vector3.new(50, 8, 1), Vector3.new(0, 5, 20.5) },
	{ Vector3.new(1, 8, 40), Vector3.new(-25.5, 5, 0) },
	{ Vector3.new(1, 8, 40), Vector3.new(25.5, 5, 0) },
}) do
	part({ Name = "Rail", Size = w[1], Position = LC + w[2], Material = Enum.Material.Glass, Transparency = 0.6, Color = Color3.fromRGB(180, 220, 255) }, lobby)
end
new("SpawnLocation", {
	Name = "LobbySpawn", Anchored = true, Neutral = true, Duration = 0, Size = Vector3.new(12, 1, 12),
	Position = LC + Vector3.new(0, 1.5, -8), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon,
	TopSurface = Enum.SurfaceType.Smooth,
}, lobby)
local sign = part({ Name = "Sign", Size = Vector3.new(30, 7, 1), Position = LC + Vector3.new(0, 6, -21.5), Color = Color3.fromRGB(20, 22, 28) }, lobby)
local sg = new("SurfaceGui", { Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40 }, sign)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "ULTIMATEPITCH v" .. VERSION,
	Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(255, 200, 40),
}, sg)

------------------------------------------------------------------ Teams
new("Team", { Name = "Lobby", TeamColor = BrickColor.new("White"), AutoAssignable = true }, Teams)
new("Team", { Name = "Rot", TeamColor = BrickColor.new("Really red"), AutoAssignable = false }, Teams)
new("Team", { Name = "Blau", TeamColor = BrickColor.new("Really blue"), AutoAssignable = false }, Teams)

------------------------------------------------------------------ Shared
local shared = new("Folder", { Name = "UltimatePitch" }, RS)
local state = new("Folder", { Name = "State" }, shared)
for k, val in pairs({ Phase = "Lobby", RedScore = 0, BlueScore = 0, TimeLeft = 0, Message = "", MessageId = 0, Version = VERSION,
	GoalSeq = 0, LastGoalTeam = "", LastGoalAurora = false }) do
	state:SetAttribute(k, val)
end
new("RemoteEvent", { Name = "Kick" }, shared)
new("RemoteEvent", { Name = "Effect" }, shared) -- nur Darstellung: Server meldet Skill-Phasen an alle Clients

-- Stadion SPECTRA DOME (Tribünenkessel, Dach, LED, Flutlicht, Anzeigetafel) als eigenes Modul
local stands = new("Folder", { Name = "Stands" }, root)
require(script:WaitForChild("Dome")).build(root, GY, state)

-- Sounds (IDs bei Bedarf in Eigenschaften austauschen)
local sounds = new("Folder", { Name = "Sounds" }, shared)
new("Sound", { Name = "Kick", SoundId = "rbxasset://sounds/swordlunge.wav", Volume = 0.8, PlaybackSpeed = 0.7 }, ball)
new("Sound", { Name = "Whistle", SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, PlaybackSpeed = 1.4 }, sounds)
new("Sound", { Name = "Goal", SoundId = "rbxasset://sounds/victory.wav", Volume = 1 }, sounds)
new("Sound", { Name = "Save", SoundId = "rbxasset://sounds/button.wav", Volume = 1 }, sounds)

-- Punkte und Eckfahnen
local function spot(x)
	part({ Name = "Spot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 1.2, 1.2), CFrame = CFrame.new(x, GY + 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false }, field)
end
spot(0); spot(68); spot(-68)
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local base = Vector3.new(sx * 79.6, GY, sz * 49.6)
		part({ Name = "FlagPole", Size = Vector3.new(0.25, 5, 0.25), Position = base + Vector3.new(0, 2.5, 0),
			Color = WHITE, Material = Enum.Material.Metal, CanCollide = false }, field)
		part({ Name = "Flag", Size = Vector3.new(0.05, 1.2, 1.6), Position = base + Vector3.new(0, 4.4, -sz * 0.8),
			Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false, CanTouch = false }, field)
	end
end

-- LED-Banden hinter den Seitenlinien
local ADS = { "ULTIMATEPITCH", "5 v 5", "GOLDEN GOAL", "ULTIMATEPITCH", "FAIR PLAY" }
for _, side in ipairs({ -1, 1 }) do
	for i, text in ipairs(ADS) do
		local x = -64 + (i - 1) * 32
		local board = part({ Name = "AdBoard", Size = Vector3.new(30, 2.6, 0.6), Position = Vector3.new(x, GY + 1.3, side * 54),
			Color = Color3.fromRGB(14, 16, 22), Material = Enum.Material.SmoothPlastic }, stands)
		local gui = new("SurfaceGui", { Face = side > 0 and Enum.NormalId.Front or Enum.NormalId.Back,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30,
			LightInfluence = 0, Brightness = 1.6 }, board)
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(20, 60, 160) or Color3.fromRGB(150, 20, 30),
			Text = text, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(255, 255, 255),
		}, gui)
	end
end

-- Atmosphaere: Nachtspiel in der Halle – dunkler, blauer Himmel, LED-Bänder leuchten über Bloom,
-- das Feld bleibt über das Umgebungslicht satt grün lesbar
local Lighting = game:GetService("Lighting")
for _, n in ipairs({ "UP_Atmosphere", "UP_Bloom", "UP_Color" }) do
	local o = Lighting:FindFirstChild(n)
	if o then o:Destroy() end
end
pcall(function()
	Lighting.ClockTime = 20.3
	Lighting.Brightness = 1.5
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 140, 185)
	Lighting.Ambient = Color3.fromRGB(60, 72, 120)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
end)
new("Atmosphere", { Name = "UP_Atmosphere", Density = 0.26, Offset = 0.1, Color = Color3.fromRGB(40, 70, 170),
	Decay = Color3.fromRGB(20, 30, 90), Glare = 0.4, Haze = 1.4 }, Lighting)
new("BloomEffect", { Name = "UP_Bloom", Intensity = 0.9, Size = 30, Threshold = 1.05 }, Lighting)
new("ColorCorrectionEffect", { Name = "UP_Color", Brightness = 0.05, Contrast = 0.16, Saturation = 0.3, TintColor = Color3.fromRGB(228, 236, 255) }, Lighting)

end

-- ===== Spiellogik =====
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ROOT = workspace:WaitForChild("UltimatePitch")
local SHARED = RS:WaitForChild("UltimatePitch")
local State = SHARED:WaitForChild("State")
local KickEvent = SHARED:WaitForChild("Kick")
local Ball = ROOT:WaitForChild("Ball")
local BotsFolder = ROOT:WaitForChild("Bots")
local LobbySpawn = ROOT:WaitForChild("Lobby"):WaitForChild("LobbySpawn")
local LobbyTeam = Teams:WaitForChild("Lobby")
local Sounds = SHARED:WaitForChild("Sounds")
local function sfx(name)
	local snd = Sounds:FindFirstChild(name)
	if snd then snd:Play() end
end

local CFG = {
	MatchTime = 180, Intermission = 12, GoalPause = 3, EndPause = 6, MinPlayers = 1,
	HalfLength = 80, HalfWidth = 50, GoalHalfWidth = 12, GoalHeight = 10, GroundY = 1,
	KickRange = 5, ShotRange = 7.5, ShotPower = 95, ShotMin = 45, ShotMax = 115, SprintFactor = 1.45, PassPower = 60, PlayerSpeed = 18, BotSpeed = 17, KeeperSpeed = 19,
	BallDrag = 0.55,
	-- Server-Autorität (eigene Testwerte): Schussladung wird serverseitig gemessen, Ausdauer serverseitig geführt
	ChargeTime = 1, ChargeMaxHold = 4,
	StaminaMax = 100, SprintDrain = 25, StaminaRegen = 16, SprintMinStamina = 5,
	MoveBurst = 12, -- Streckenbudget (Studs) für Netzwerk-Schübe, siehe Bewegungsprüfung
	-- AURORA BREAK (Elite-Abschluss, eigene Testwerte)
	AuroraRange = 6, AuroraCooldown = 12, AuroraStamina = 30, AuroraWindup = 0.3,
	AuroraSpeed = 128, AuroraLift = 9, AuroraGoalWindow = 2,
}

local TEAM = {
	Rot = { name = "Rot", team = Teams:WaitForChild("Rot"), sign = 1, score = "RedScore",
		color = Color3.fromRGB(215, 40, 40), keeper = Color3.fromRGB(255, 150, 20) },
	Blau = { name = "Blau", team = Teams:WaitForChild("Blau"), sign = -1, score = "BlueScore",
		color = Color3.fromRGB(40, 90, 230), keeper = Color3.fromRGB(30, 200, 170) },
}
-- Slot 1 = Torwart, 2-5 Feldspieler (d = Abstand vom eigenen Tor)
local SLOTS = { { d = 4, z = 0 }, { d = 28, z = -18 }, { d = 28, z = 18 }, { d = 62, z = -14 }, { d = 62, z = 14 } }

local phase = "Lobby"
local roster = { Rot = {}, Blau = {} }
local scores = { Rot = 0, Blau = 0 }
local pendingGoal = nil
local pendingGoalAurora = false
local botCd, lastKick = {}, {}
-- Serverseitiger Spielerzustand: Schussladung, Sprint-Wunsch, Ausdauer, Bewegungs-Stichprobe, Skill-Cooldown
local chargeStart, sprintWanted, stamina, motion, auroraReady = {}, {}, {}, {}, {}
local auroraHold = nil      -- { player, releaseAt } während des Anlaufs: Ball wird vor dem Spieler gehalten
-- Schuss-Token des letzten AURORA-Kicks: { id, player, team, expires }. Jede andere Ballaktion
-- (Pass, Schuss, Bot-Kick, Parade, Ball-Reset, Berührung durch eine andere Figur) löscht es.
-- Ein Tor zählt nur als AURORA-Tor, wenn das Token noch gilt und das Tor für das Team des Schützen fällt.
local auroraShot = nil
local auroraShotSeq = 0
local EffectEvent = SHARED:WaitForChild("Effect")

-- Gewollter Server-Teleport: Bezugspunkt der Bewegungsprüfung mitziehen, sonst würde sie zurücksetzen
local function teleport(plr, cf)
	local char = plr.Character
	if not char then return end
	char:PivotTo(cf)
	motion[plr] = { pos = cf.Position, budget = CFG.MoveBurst }
end

local function flat(vec) return Vector3.new(vec.X, 0, vec.Z) end
local function unit(vec, fallback)
	if vec.Magnitude < 1e-3 then return fallback end
	return vec.Unit
end
local function setPhase(p) phase = p; State:SetAttribute("Phase", p) end
local function msg(t)
	State:SetAttribute("Message", t)
	State:SetAttribute("MessageId", (State:GetAttribute("MessageId") or 0) + 1)
end
local function inMatch() return phase == "Playing" or phase == "GoldenGoal" end

local function slotPos(td, slot)
	local s = SLOTS[slot]
	return Vector3.new(-td.sign * CFG.HalfLength + td.sign * s.d, CFG.GroundY + 3, s.z)
end
local function slotCF(td, slot)
	local p = slotPos(td, slot)
	return CFrame.lookAt(p, p + Vector3.new(td.sign, 0, 0))
end

---------------------------------------------------------------- Ball
local function resetBall()
	auroraShot = nil
	Ball.AssemblyLinearVelocity = Vector3.zero
	Ball.AssemblyAngularVelocity = Vector3.zero
	Ball.CFrame = CFrame.new(0, CFG.GroundY + 3, 0)
	pcall(function() Ball:SetNetworkOwner(nil) end)
end
local function kickBall(vel)
	auroraShot = nil -- jede neue Ballaktion beendet die Zuordnung zum letzten AURORA-Schuss
	local k = Ball:FindFirstChild("Kick")
	if k then k:Play() end
	pcall(function() Ball:SetNetworkOwner(nil) end)
	Ball.AssemblyLinearVelocity = vel
end
-- Berührt eine andere Figur (Spieler oder Bot) den Ball, gehört ein späteres Tor nicht mehr zum AURORA-Schuss
Ball.Touched:Connect(function(part)
	local shot = auroraShot
	if not shot then return end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") and model ~= shot.player.Character then
		auroraShot = nil
	end
end)

---------------------------------------------------------------- Bots
local function simpleRig(color)
	local m = Instance.new("Model")
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"; hrp.Size = Vector3.new(2, 2, 1); hrp.Color = color; hrp.Parent = m
	local head = Instance.new("Part")
	head.Name = "Head"; head.Size = Vector3.new(1.2, 1.2, 1.2); head.Color = Color3.fromRGB(234, 184, 146)
	head.CFrame = hrp.CFrame * CFrame.new(0, 1.6, 0); head.Parent = m
	local w = Instance.new("WeldConstraint"); w.Part0 = hrp; w.Part1 = head; w.Parent = hrp
	local h = Instance.new("Humanoid"); h.RigType = Enum.HumanoidRigType.R15; h.HipHeight = 2; h.Parent = m
	m.PrimaryPart = hrp
	return m
end

local function makeBot(td, slot)
	local shirt = slot == 1 and td.keeper or td.color
	local model
	local ok = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = Color3.fromRGB(234, 184, 146)
		d.TorsoColor, d.LeftArmColor, d.RightArmColor = shirt, shirt, shirt
		d.LeftLegColor, d.RightLegColor = Color3.fromRGB(30, 30, 30), Color3.fromRGB(30, 30, 30)
		model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then model = simpleRig(shirt) end
	local name = (slot == 1 and "TW " or "Bot ") .. td.name .. " " .. slot
	model.Name = name
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = name
	hum.WalkSpeed = slot == 1 and CFG.KeeperSpeed or CFG.BotSpeed
	hum.BreakJointsOnDeath = false
	model:SetAttribute("Team", td.name)
	model:SetAttribute("Slot", slot)
	model:PivotTo(slotCF(td, slot))
	model.Parent = BotsFolder
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then pcall(function() hrp:SetNetworkOwner(nil) end) end
	return model
end

local function clearBots()
	for _, b in ipairs(BotsFolder:GetChildren()) do b:Destroy() end
	botCd = {}
end

---------------------------------------------------------------- Spieler
local function highlight(char, td)
	local h = char:FindFirstChild("TeamHighlight")
	if not td then if h then h:Destroy() end return end
	h = h or Instance.new("Highlight")
	h.Name = "TeamHighlight"; h.FillColor = td.color; h.OutlineColor = td.color
	h.FillTransparency = 0.75; h.OutlineTransparency = 0.3; h.Parent = char
end

local function findPlayerSlot(plr)
	for teamName, slots in pairs(roster) do
		for slot, e in pairs(slots) do
			if e.kind == "player" and e.player == plr then return teamName, slot end
		end
	end
end

local function placePlayer(plr, teamName, slot)
	local char = plr.Character
	if not char then return end
	teleport(plr, slotCF(TEAM[teamName], slot))
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = CFG.PlayerSpeed end
	char:SetAttribute("BaseSpeed", CFG.PlayerSpeed)
	highlight(char, TEAM[teamName])
end

local function members(teamName)
	local list = {}
	for slot, e in pairs(roster[teamName]) do
		local char = e.kind == "bot" and e.model or (e.player and e.player.Character)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			table.insert(list, { slot = slot, e = e, hum = hum, root = root, model = char })
		end
	end
	return list
end

local function humanCount()
	local n = 0
	for _, slots in pairs(roster) do
		for _, e in pairs(slots) do
			if e.kind == "player" and e.player.Parent then n += 1 end
		end
	end
	return n
end

---------------------------------------------------------------- KI
local function clampField(p)
	return Vector3.new(math.clamp(p.X, -78, 78), CFG.GroundY, math.clamp(p.Z, -48, 48))
end

local function botKick(td, m, list)
	local now = os.clock()
	if (botCd[m.model] or 0) > now then return end
	botCd[m.model] = now + 0.6
	local s = td.sign
	local bp = Ball.Position
	local goal = Vector3.new(s * CFG.HalfLength, 0, 0)
	local toGoal = flat(goal - bp)
	-- Schuss
	if toGoal.Magnitude < 50 then
		local aim = Vector3.new(s * (CFG.HalfLength + 4), 0, (math.random() * 2 - 1) * (CFG.GoalHalfWidth - 2))
		local dir = unit(flat(aim - bp), Vector3.new(s, 0, 0))
		kickBall(dir * CFG.ShotPower * (0.8 + math.random() * 0.25) + Vector3.new(0, 4 + math.random() * 14, 0))
		return
	end
	-- Pass nach vorn
	local best, bestScore = nil, -math.huge
	for _, o in ipairs(list) do
		if o ~= m and o.slot ~= 1 then
			local op = o.root.Position
			local ahead = (op.X - bp.X) * s
			local dist = flat(op - bp).Magnitude
			if ahead > 4 and dist < 60 then
				local score = ahead - dist * 0.3 + math.random() * 10
				if score > bestScore then best, bestScore = o, score end
			end
		end
	end
	if best and math.random() < 0.7 then
		local target = best.root.Position + Vector3.new(s * 5, 0, 0)
		local d = flat(target - bp)
		kickBall(unit(d, Vector3.new(s, 0, 0)) * math.clamp(d.Magnitude * 1.4, 35, 75) + Vector3.new(0, 3, 0))
		return
	end
	-- Dribbeln
	local dir = unit(toGoal, Vector3.new(s, 0, 0))
	dir = (CFrame.Angles(0, (math.random() - 0.5) * 0.8, 0) * dir)
	kickBall(dir * 30 + Vector3.new(0, 1, 0))
end

local function keeper(td, m, bp)
	local s = td.sign
	local gx = -s * CFG.HalfLength
	local inBox = math.abs(bp.X - gx) < 20 and math.abs(bp.Z) < 22
	local target
	if inBox then
		target = Vector3.new(bp.X, 0, bp.Z)
	else
		target = Vector3.new(gx + s * 3, 0, math.clamp(bp.Z * 0.35, -CFG.GoalHalfWidth + 2, CFG.GoalHalfWidth - 2))
	end
	local minX, maxX = math.min(gx + s * 1.5, gx + s * 20), math.max(gx + s * 1.5, gx + s * 20)
	target = Vector3.new(math.clamp(target.X, minX, maxX), CFG.GroundY, math.clamp(target.Z, -22, 22))
	m.hum:MoveTo(target)

	local rel = bp - m.root.Position
	local now = os.clock()
	if flat(rel).Magnitude < 6.5 and rel.Y < 7 and (botCd[m.model] or 0) < now then
		botCd[m.model] = now + 0.8
		local speed = Ball.AssemblyLinearVelocity.Magnitude
		local chance = speed > 70 and 0.6 or (speed > 40 and 0.8 or 0.97)
		if rel.Y > 1.5 then m.hum.Jump = true end
		if math.random() < chance then
			kickBall(Vector3.new(s * 75, 30, (math.random() * 2 - 1) * 35))
			if speed > 40 then msg("Parade! TW " .. td.name); sfx("Save") end
		end
	end
end

local function thinkTeam(teamName)
	local td = TEAM[teamName]
	local s = td.sign
	local bp = Ball.Position
	local list = members(teamName)
	local chaser, cd = nil, math.huge
	for _, m in ipairs(list) do
		if m.slot ~= 1 then
			local d = flat(m.root.Position - bp).Magnitude
			if d < cd then chaser, cd = m, d end
		end
	end
	for _, m in ipairs(list) do
		if m.e.kind == "bot" then
			if m.slot == 1 then
				keeper(td, m, bp)
			else
				local target
				if m == chaser then
					target = bp - Vector3.new(s, 0, 0) * 1.2
				else
					local home = slotPos(td, m.slot)
					target = Vector3.new(home.X + bp.X * 0.5, 0, home.Z * 0.8 + bp.Z * 0.3)
				end
				m.hum:MoveTo(clampField(target))
				local rel = bp - m.root.Position
				if flat(rel).Magnitude < 4.5 and bp.Y < CFG.GroundY + 5 then
					botKick(td, m, list)
				end
			end
		end
	end
end

---------------------------------------------------------------- Spielablauf
local function updateScore()
	State:SetAttribute("RedScore", scores.Rot)
	State:SetAttribute("BlueScore", scores.Blau)
end

local function kickoff()
	resetBall()
	for teamName, slots in pairs(roster) do
		for slot, e in pairs(slots) do
			if e.kind == "bot" then
				if e.model.Parent then e.model:PivotTo(slotCF(TEAM[teamName], slot)) end
			else
				placePlayer(e.player, teamName, slot)
			end
		end
	end
end

local function setupTeams()
	clearBots()
	roster = { Rot = {}, Blau = {} }
	local list = Players:GetPlayers()
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	for idx, plr in ipairs(list) do
		if idx <= 8 then
			local teamName = (idx % 2 == 1) and "Rot" or "Blau"
			local slot = 2 + math.floor((idx - 1) / 2)
			plr.Team = TEAM[teamName].team
			roster[teamName][slot] = { kind = "player", player = plr }
		else
			plr.Team = LobbyTeam
		end
	end
	for teamName, td in pairs(TEAM) do
		for slot = 1, #SLOTS do
			if not roster[teamName][slot] then
				roster[teamName][slot] = { kind = "bot", model = makeBot(td, slot) }
			end
		end
	end
end

local function cleanup()
	clearBots()
	roster = { Rot = {}, Blau = {} }
	for _, plr in ipairs(Players:GetPlayers()) do
		plr.Team = LobbyTeam
		local char = plr.Character
		if char then
			highlight(char, nil)
			teleport(plr, LobbySpawn.CFrame + Vector3.new(0, 4, 0))
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
			char:SetAttribute("BaseSpeed", 16)
		end
	end
	resetBall()
end

local function runMatch()
	setupTeams()
	scores = { Rot = 0, Blau = 0 }
	updateScore()
	pendingGoal = nil
	local timeLeft = CFG.MatchTime
	local golden = false
	local winner = nil
	State:SetAttribute("TimeLeft", timeLeft)
	kickoff()
	setPhase("Playing")
	msg("Anpfiff! Rot ▶  ◀ Blau")
	sfx("Whistle")
	while true do
		local dt = task.wait(0.1)
		if humanCount() == 0 then break end
		if pendingGoal then
			local t = pendingGoal
			scores[t] += 1
			updateScore()
			-- Serverbestätigtes Tor-Ereignis für das GOAL-Cinematic der Clients
			State:SetAttribute("LastGoalTeam", t)
			State:SetAttribute("LastGoalAurora", pendingGoalAurora)
			State:SetAttribute("GoalSeq", (State:GetAttribute("GoalSeq") or 0) + 1)
			pendingGoalAurora = false
			setPhase("Goal")
			if golden then
				winner = t
				msg("GOLDEN GOAL! " .. t .. " trifft!")
				sfx("Goal")
				break
			end
			msg("TOR für " .. t .. "!")
			sfx("Goal")
			task.wait(CFG.GoalPause)
			kickoff()
			pendingGoal = nil
			setPhase("Playing")
			sfx("Whistle")
		elseif not golden then
			timeLeft -= dt
			State:SetAttribute("TimeLeft", math.max(0, math.ceil(timeLeft)))
			if timeLeft <= 0 then
				if scores.Rot == scores.Blau then
					golden = true
					setPhase("Goal")
					msg("Unentschieden – GOLDEN GOAL!")
					task.wait(CFG.GoalPause)
					kickoff()
					setPhase("GoldenGoal")
				else
					winner = scores.Rot > scores.Blau and "Rot" or "Blau"
					break
				end
			end
		end
	end
	setPhase("End")
	sfx("Whistle")
	task.wait(golden and winner and 2 or 0)
	msg(winner and ("Team " .. winner .. " gewinnt " .. scores.Rot .. ":" .. scores.Blau .. "!") or "Spiel abgebrochen")
	task.wait(CFG.EndPause)
	cleanup()
end

---------------------------------------------------------------- Events
-- Client meldet nur Absichten: "ChargeStart", "Shot", "Pass", "Sprint" (true/false), "Aurora".
-- Schussstärke, Ausdauer, Reichweite, Cooldowns und Tore entscheidet ausschließlich der Server.
KickEvent.OnServerEvent:Connect(function(plr, kind, arg)
	if type(kind) ~= "string" then return end
	if kind == "Sprint" then
		sprintWanted[plr] = arg == true
		return
	end
	if kind == "ChargeStart" then
		chargeStart[plr] = os.clock()
		return
	end
	if kind ~= "Pass" and kind ~= "Shot" and kind ~= "Aurora" then return end
	if not inMatch() or pendingGoal or auroraHold then return end
	local teamName = plr.Team and plr.Team.Name
	local td = TEAM[teamName]
	if not td then return end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local now = os.clock()
	if (lastKick[plr] or 0) + 0.35 > now then return end
	local rel = Ball.Position - root.Position
	-- Schuss mit Toleranz: der Ball rollt beim Aufladen etwas weg
	local range = (kind == "Pass" and CFG.KickRange) or (kind == "Aurora" and CFG.AuroraRange) or CFG.ShotRange
	lastKick[plr] = now
	if flat(rel).Magnitude > range or math.abs(rel.Y) > 5 then
		chargeStart[plr] = nil
		KickEvent:FireClient(plr, "TooFar")
		return
	end
	local look = unit(flat(root.CFrame.LookVector), Vector3.new(td.sign, 0, 0))
	if kind == "Pass" then
		kickBall(look * CFG.PassPower + Vector3.new(0, 3, 0))
	elseif kind == "Shot" then
		-- Ladung = serverseitig gemessene Haltedauer seit "ChargeStart"; ein mitgeschickter Wert wird ignoriert
		local began = chargeStart[plr]
		chargeStart[plr] = nil
		if not began or now - began > CFG.ChargeMaxHold then
			KickEvent:FireClient(plr, "NoCharge")
			return
		end
		local pw = math.clamp((now - began) / CFG.ChargeTime, 0, 1)
		kickBall(look * (CFG.ShotMin + (CFG.ShotMax - CFG.ShotMin) * pw) + Vector3.new(0, 6 + 30 * pw, 0))
	else
		-- AURORA BREAK: Cooldown und Ausdauer serverseitig, dann Anlauf mit gehaltenem Ball bis zum Kick-Marker
		if now < (auroraReady[plr] or 0) then KickEvent:FireClient(plr, "Cooldown") return end
		if (stamina[plr] or 0) < CFG.AuroraStamina then KickEvent:FireClient(plr, "NoStamina") return end
		stamina[plr] -= CFG.AuroraStamina
		auroraReady[plr] = now + CFG.AuroraCooldown
		plr:SetAttribute("AuroraReady", workspace:GetServerTimeNow() + CFG.AuroraCooldown)
		auroraHold = { player = plr, releaseAt = now + CFG.AuroraWindup }
		EffectEvent:FireAllClients("AuroraWindup", plr.UserId, CFG.AuroraWindup)
	end
end)

-- Kick-Marker von AURORA BREAK: Server schießt selbst, sobald der Anlauf abgelaufen ist
local function releaseAurora()
	local hold = auroraHold
	auroraHold = nil
	local plr = hold.player
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or not inMatch() then
		EffectEvent:FireAllClients("AuroraCancel", plr.UserId)
		return
	end
	local td = TEAM[plr.Team and plr.Team.Name]
	local look = unit(flat(root.CFrame.LookVector), Vector3.new(td and td.sign or 1, 0, 0))
	kickBall(look * CFG.AuroraSpeed + Vector3.new(0, CFG.AuroraLift, 0))
	auroraShotSeq += 1
	auroraShot = { id = auroraShotSeq, player = plr, team = plr.Team and plr.Team.Name,
		expires = os.clock() + CFG.AuroraGoalWindow }
	State:SetAttribute("AuroraShotId", auroraShotSeq)
	EffectEvent:FireAllClients("AuroraKick", plr.UserId)
end

local function humansIn(teamName)
	local n = 0
	for _, e in pairs(roster[teamName]) do
		if e.kind == "player" then n += 1 end
	end
	return n
end

-- Spät beigetreten: Feldspieler-Bot des Teams mit weniger Menschen übernehmen
local function joinRunningMatch(plr)
	local first = humansIn("Rot") <= humansIn("Blau") and "Rot" or "Blau"
	for _, teamName in ipairs({ first, first == "Rot" and "Blau" or "Rot" }) do
		for slot = 2, #SLOTS do
			local e = roster[teamName][slot]
			if e and e.kind == "bot" then
				if e.model then e.model:Destroy() end
				roster[teamName][slot] = { kind = "player", player = plr }
				plr.Team = TEAM[teamName].team
				msg(plr.DisplayName .. " wechselt ein (" .. teamName .. ")")
				return teamName, slot
			end
		end
	end
end

local function onCharacter(plr)
	task.wait(0.2)
	local teamName, slot = findPlayerSlot(plr)
	if not teamName and (inMatch() or phase == "Goal") then
		teamName, slot = joinRunningMatch(plr)
	end
	if teamName and phase ~= "Lobby" and phase ~= "Intermission" and phase ~= "End" then
		placePlayer(plr, teamName, slot)
	elseif plr.Character then
		teleport(plr, LobbySpawn.CFrame + Vector3.new(0, 4, 0))
		plr.Character:SetAttribute("BaseSpeed", 16)
	end
end

local function onPlayer(plr)
	plr.CharacterAdded:Connect(function() onCharacter(plr) end)
	if plr.Character then task.spawn(onCharacter, plr) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

Players.PlayerRemoving:Connect(function(plr)
	lastKick[plr] = nil
	chargeStart[plr], sprintWanted[plr], stamina[plr], motion[plr], auroraReady[plr] = nil, nil, nil, nil, nil
	if auroraHold and auroraHold.player == plr then auroraHold = nil end
	local teamName, slot = findPlayerSlot(plr)
	if teamName and phase ~= "Lobby" and phase ~= "Intermission" then
		roster[teamName][slot] = { kind = "bot", model = makeBot(TEAM[teamName], slot) }
	end
end)

local aiAcc = 0
RunService.Heartbeat:Connect(function(dt)
	if not inMatch() then
		if auroraHold then auroraHold = nil end
		return
	end
	-- AURORA BREAK Anlauf: Ball liegt vor dem Schützen, bis der Server am Kick-Marker schießt
	if auroraHold then
		local root = auroraHold.player.Character and auroraHold.player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local look = unit(flat(root.CFrame.LookVector), Vector3.new(1, 0, 0))
			Ball.AssemblyLinearVelocity = Vector3.zero
			Ball.AssemblyAngularVelocity = Vector3.zero
			Ball.CFrame = CFrame.new(Vector3.new(root.Position.X, CFG.GroundY + 1.1, root.Position.Z) + look * 2.6)
		end
		if os.clock() >= auroraHold.releaseAt then releaseAurora() end
	end
	local p = Ball.Position
	-- Tor?
	if not pendingGoal and math.abs(p.Z) < CFG.GoalHalfWidth and p.Y < CFG.GroundY + CFG.GoalHeight then
		if p.X > CFG.HalfLength + 1.2 then pendingGoal = "Rot"
		elseif p.X < -CFG.HalfLength - 1.2 then pendingGoal = "Blau" end
		if pendingGoal then
			local shot = auroraShot
			pendingGoalAurora = shot ~= nil and os.clock() < shot.expires and shot.team == pendingGoal
			auroraShot = nil
		end
	end
	-- Ball verloren?
	if p.Y < -20 or math.abs(p.X) > 100 or math.abs(p.Z) > 70 then resetBall() end
	-- Rollwiderstand
	if p.Y < CFG.GroundY + 1.5 then
		local vel = Ball.AssemblyLinearVelocity
		local f = math.max(0, 1 - CFG.BallDrag * dt)
		Ball.AssemblyLinearVelocity = Vector3.new(vel.X * f, vel.Y, vel.Z * f)
	end
	aiAcc += dt
	if aiAcc >= 0.1 then
		aiAcc = 0
		if not pendingGoal and not auroraHold then
			thinkTeam("Rot")
			thinkTeam("Blau")
		end
	end
end)

-- Ausdauer, Sprint und Bewegungsplausibilität serverseitig (läuft auch außerhalb des Matches)
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			local value = stamina[plr] or CFG.StaminaMax
			local base = char:GetAttribute("BaseSpeed") or 16
			local moving = hum.MoveDirection.Magnitude > 0.1
			local sprinting = sprintWanted[plr] and moving and value > 0
				and (value >= CFG.SprintMinStamina or hum.WalkSpeed > base)
			if sprinting then
				value = math.max(0, value - CFG.SprintDrain * dt)
			else
				value = math.min(CFG.StaminaMax, value + CFG.StaminaRegen * dt)
			end
			stamina[plr] = value
			local speed = (sprinting and value > 0) and base * CFG.SprintFactor or base
			if hum.WalkSpeed ~= speed then hum.WalkSpeed = speed end
			local rounded = math.floor(value + 0.5)
			if plr:GetAttribute("Stamina") ~= rounded then plr:SetAttribute("Stamina", rounded) end

			-- Bewegung: Streckenbudget. Es füllt sich mit dem gerade erlaubten Tempo (Gehen oder Sprint, +20 %)
			-- und ist auf MoveBurst gedeckelt (Netzwerk-Schübe, Sprint-Ende mit Verzögerung). Jede zurückgelegte
			-- horizontale Strecke wird abgezogen; fällt das Budget unter 0, setzt der Server auf die letzte
			-- akzeptierte Position zurück. So wird auch ein dauerhaft nur leicht erhöhtes Tempo erkannt.
			local m = motion[plr]
			if not m then
				motion[plr] = { pos = root.Position, budget = CFG.MoveBurst }
			else
				local delta = flat(root.Position - m.pos).Magnitude
				local rate = speed * 1.2
				m.budget = math.min(CFG.MoveBurst, m.budget + rate * dt) - delta
				if m.budget < 0 then
					char:PivotTo(CFrame.new(m.pos) * root.CFrame.Rotation)
					m.budget = 0
					plr:SetAttribute("MoveCorrections", (plr:GetAttribute("MoveCorrections") or 0) + 1)
				else
					m.pos = root.Position
				end
			end
		end
	end
end)

---------------------------------------------------------------- Hauptschleife
resetBall()
while true do
	setPhase("Lobby")
	State:SetAttribute("TimeLeft", 0)
	if #Players:GetPlayers() < CFG.MinPlayers then
		msg("Warte auf Spieler …")
		repeat task.wait(1) until #Players:GetPlayers() >= CFG.MinPlayers
	end
	setPhase("Intermission")
	for t = CFG.Intermission, 1, -1 do
		State:SetAttribute("TimeLeft", t)
		task.wait(1)
	end
	if #Players:GetPlayers() >= CFG.MinPlayers then
		local ok, err = pcall(runMatch)
		if not ok then
			warn("[UltimatePitch] " .. tostring(err))
			pcall(cleanup)
		end
	end
end
