-- UltimatePitch v0.5 · Server (baut die Welt beim Start selbst)
local VERSION = "0.5"

-- Gemeinsamer Zustand aller Arenen (M1b): Spielerwerte (Ausdauer, Sprint, Bewegungsprüfung, Cooldown) gelten
-- serverweit; jedes Match läuft als eigene Instanz in seiner Arena (siehe createArena).
local G = {
	arenas = {},
	chargeStart = {}, sprintWanted = {}, stamina = {}, motion = {}, auroraReady = {},
	playerLoop = false,
}

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
-- Open-World-Regel (M1): Dieses Skript besitzt nur seine eigenen Objekte – workspace.UltimatePitch,
-- ReplicatedStorage.UltimatePitch, die Teams Lobby/Rot/Blau und die Lighting-Effekte UP_*. Alles andere in der
-- Place (z. B. ein handgebauter Stadtbezirk unter workspace.UltimateCity samt eigener SpawnLocations) wird
-- weder gelöscht noch deaktiviert oder umgefärbt. Fremde SpawnLocations bleiben deshalb aktiv.
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

-- Eine Arena = ein eigenständiges Match mit eigenem Ball, eigenen Maßen, eigenem Ursprung und eigenem Zustand.
-- A = { id, stadium, origin (Vector3), halfLength, halfWidth, goalHalfWidth, slots, matchTime, exitCFrame }
-- Das Stadion (stadium = true) entsteht zuerst und genau einmal. Es legt auch die gemeinsamen Objekte an (Teams,
-- RemoteEvents, Sounds, Grundlicht) und steht fest am Welt-Ursprung, weil der SPECTRA DOME dort gebaut ist.
-- Innerhalb der Logik sind alle Positionen Weltkoordinaten; OX/OZ ist die Feldmitte, CFG.GroundY die Rasenhöhe.
local function createArena(A)
assert(type(A.id) == "string" and not G.arenas[A.id], "Arena-Id fehlt oder ist vergeben")
local O = A.origin or Vector3.zero
local OX, OZ = O.X, O.Z
local root, ball, state
if A.stadium then
assert(O == Vector3.zero and A.halfLength == 80 and A.halfWidth == 50 and A.goalHalfWidth == 12,
	"Stadion: fester Ursprung und feste Maße")
local GY = 1
------------------------------------------------------------------ Workspace
root = new("Folder", { Name = "UltimatePitch" }, workspace)
root:SetAttribute("Version", VERSION)
local field = new("Folder", { Name = "Field" }, root)
local goals = new("Folder", { Name = "Goals" }, root)
local walls = new("Folder", { Name = "Walls" }, root)
local lobby = new("Folder", { Name = "Lobby" }, root)
new("Folder", { Name = "Bots" }, root)

local GRASS = Color3.fromRGB(58, 135, 58)
local GRASS2 = Color3.fromRGB(70, 152, 68)
local WHITE = Color3.fromRGB(245, 245, 245)

-- Rasen: dunklerer Außenbereich, darauf die Spielfläche mit Mähstreifen
part({ Name = "Ground", Size = Vector3.new(200, 1, 140), Position = Vector3.new(0, GY - 0.5, 0), Material = Enum.Material.Grass,
	Color = Color3.fromRGB(42, 104, 46) }, field)
part({ Name = "Pitch", Size = Vector3.new(166, 0.02, 106), Position = Vector3.new(0, GY + 0.01, 0), Material = Enum.Material.Grass, Color = GRASS,
	CanCollide = false, CanQuery = false, CanTouch = false }, field)
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
local glass = { Material = Enum.Material.SmoothPlastic, Transparency = 0.96, Color = Color3.fromRGB(200, 230, 255), CastShadow = false }
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
ball = part({
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
state = new("Folder", { Name = "State" }, shared)
for k, val in pairs({ Phase = "Lobby", RedScore = 0, BlueScore = 0, TimeLeft = 0, Message = "", MessageId = 0, Version = VERSION,
	GoalSeq = 0, LastGoalTeam = "", LastGoalAurora = false, BallOwner = 0 }) do
	state:SetAttribute(k, val)
end
new("ObjectValue", { Name = "BallCarrier" }, state) -- Figur am Ball (Mensch oder Bot), nur Anzeige
new("RemoteEvent", { Name = "Kick" }, shared)
new("RemoteEvent", { Name = "Effect" }, shared) -- nur Darstellung: Server meldet Skill-Phasen an alle Clients

-- Stadion SPECTRA DOME (Tribünenkessel, Dach, LED, Flutlicht, Anzeigetafel) als eigenes Modul
local stands = new("Folder", { Name = "Stands" }, root)
require(script:WaitForChild("Dome")).build(root, GY, state)

-- Sounds: freie Soundeffekte von „ProSoundEffects“ aus dem Roblox Creator Store (von Roblox lizenzierte
-- Bibliothek, kein eigener Upload). Stadionatmosphäre, Torjubel und AURORA-Knall spielt der Client.
local sounds = new("Folder", { Name = "Sounds" }, shared)
new("Sound", { Name = "Kick", SoundId = "rbxassetid://9119330229", Volume = 1, RollOffMaxDistance = 220 }, ball) -- Soccer Ball Kicks On Surfaces 41
new("Sound", { Name = "Whistle", SoundId = "rbxassetid://9118113825", Volume = 0.8 }, sounds) -- Referee Whistle 2
new("Sound", { Name = "Goal", SoundId = "rbxasset://sounds/victory.wav", Volume = 0.25 }, sounds)
new("Sound", { Name = "Save", SoundId = "rbxassetid://9119335569", Volume = 1 }, sounds) -- Soccer Goalie Deflection 201

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
	-- Grundlicht der Welt (später Nachmittag). Das Nachtspiel-Licht des SPECTRA DOME ist kein globaler
	-- Zustand mehr: jeder Client blendet es lokal ein, solange seine Kamera im Stadion ist (Client: Zonenlicht).
	Lighting.ClockTime = 16.6
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 142, 150)
	Lighting.Ambient = Color3.fromRGB(92, 96, 110)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
end)
new("Atmosphere", { Name = "UP_Atmosphere", Density = 0.28, Offset = 0.1, Color = Color3.fromRGB(190, 205, 230),
	Decay = Color3.fromRGB(120, 140, 170), Glare = 0.1, Haze = 1.2 }, Lighting)
new("BloomEffect", { Name = "UP_Bloom", Intensity = 0.4, Size = 24, Threshold = 1.2 }, Lighting)
new("ColorCorrectionEffect", { Name = "UP_Color", Brightness = 0, Contrast = 0.08, Saturation = 0.12, TintColor = Color3.new(1, 1, 1) }, Lighting)

else
	-- Einfache Arena (z. B. Bolzplatz): Boden, Linien, Tore, unsichtbare Banden und Ball – ohne Stadion und Lobby.
	-- Eigene Objekte liegen unter workspace.UltimatePitch.Arenas.<id> und ReplicatedStorage.UltimatePitch.Arenas.<id>.
	local GYa = O.Y + 1
	local HLa, HWa, GWa, GHa = A.halfLength, A.halfWidth, A.goalHalfWidth, 10
	local function P(x, y, z) return Vector3.new(OX + x, y, OZ + z) end
	local base = workspace:WaitForChild("UltimatePitch")
	local arenas = base:FindFirstChild("Arenas") or new("Folder", { Name = "Arenas" }, base)
	root = new("Folder", { Name = A.id }, arenas)
	local field = new("Folder", { Name = "Field" }, root)
	local goals = new("Folder", { Name = "Goals" }, root)
	local walls = new("Folder", { Name = "Walls" }, root)
	new("Folder", { Name = "Bots" }, root)
	local WHITE = Color3.fromRGB(245, 245, 245)
	part({ Name = "Ground", Size = Vector3.new(HLa * 2 + 16, 1, HWa * 2 + 16), Position = P(0, GYa - 0.5, 0),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(70, 74, 82) }, field)
	part({ Name = "Pitch", Size = Vector3.new(HLa * 2, 0.02, HWa * 2), Position = P(0, GYa + 0.01, 0),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(34, 110, 150), CanCollide = false, CanQuery = false, CanTouch = false }, field)
	local function line(x1, z1, x2, z2)
		local a, b = P(x1, GYa + 0.05, z1), P(x2, GYa + 0.05, z2)
		part({ Name = "Line", Size = Vector3.new(0.5, 0.04, (b - a).Magnitude + 0.5), CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false }, field)
	end
	line(-HLa, -HWa, HLa, -HWa); line(-HLa, HWa, HLa, HWa)
	line(-HLa, -HWa, -HLa, HWa); line(HLa, -HWa, HLa, HWa)
	line(0, -HWa, 0, HWa)
	local function wall(size, pos)
		part({ Name = "Wall", Size = size, Position = pos, Transparency = 1, CastShadow = false }, walls)
	end
	wall(Vector3.new(HLa * 2 + 4, 20, 2), P(0, GYa + 10, -(HWa + 1)))
	wall(Vector3.new(HLa * 2 + 4, 20, 2), P(0, GYa + 10, HWa + 1))
	wall(Vector3.new(HLa * 2 + 4, 2, HWa * 2 + 4), P(0, GYa + 21, 0))
	for _, s in ipairs({ -1, 1 }) do
		local g = new("Model", { Name = s > 0 and "GoalBlau" or "GoalRot" }, goals)
		local net = { Color = WHITE, Material = Enum.Material.Fabric, Transparency = 0.45 }
		local function netPart(props)
			for k, val in pairs(net) do props[k] = props[k] or val end
			return part(props, g)
		end
		netPart({ Name = "Back", Size = Vector3.new(1, GHa + 1, GWa * 2 + 2), Position = P(s * (HLa + 5.5), GYa + (GHa + 1) / 2, 0) })
		netPart({ Name = "SideL", Size = Vector3.new(5, GHa + 1, 1), Position = P(s * (HLa + 3), GYa + (GHa + 1) / 2, -(GWa + 0.5)) })
		netPart({ Name = "SideR", Size = Vector3.new(5, GHa + 1, 1), Position = P(s * (HLa + 3), GYa + (GHa + 1) / 2, GWa + 0.5) })
		netPart({ Name = "Roof", Size = Vector3.new(5, 1, GWa * 2 + 2), Position = P(s * (HLa + 3), GYa + GHa + 0.5, 0) })
		part({ Name = "PostL", Size = Vector3.new(1, GHa, 1), Position = P(s * (HLa + 0.5), GYa + GHa / 2, -(GWa + 0.5)), Color = WHITE, Material = Enum.Material.Metal }, g)
		part({ Name = "PostR", Size = Vector3.new(1, GHa, 1), Position = P(s * (HLa + 0.5), GYa + GHa / 2, GWa + 0.5), Color = WHITE, Material = Enum.Material.Metal }, g)
		part({ Name = "Bar", Size = Vector3.new(1, 1, GWa * 2 + 2), Position = P(s * (HLa + 0.5), GYa + GHa + 0.5, 0), Color = WHITE, Material = Enum.Material.Metal }, g)
		local seg = HWa - GWa
		wall(Vector3.new(2, 20, seg), P(s * (HLa + 1), GYa + 10, -(GWa + seg / 2)))
		wall(Vector3.new(2, 20, seg), P(s * (HLa + 1), GYa + 10, GWa + seg / 2))
		wall(Vector3.new(2, 20 - GHa, GWa * 2), P(s * (HLa + 1), GYa + GHa + (20 - GHa) / 2, 0))
	end
	ball = part({
		Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Anchored = false,
		Position = P(0, GYa + 3, 0), Color = WHITE, Material = Enum.Material.SmoothPlastic,
		CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.4, 0.5, 1, 1),
	}, root)
	local a0 = new("Attachment", { Position = Vector3.new(0, 0.4, 0) }, ball)
	local a1 = new("Attachment", { Position = Vector3.new(0, -0.4, 0) }, ball)
	new("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.25, Transparency = NumberSequence.new(0.4, 1) }, ball)
	new("Sound", { Name = "Kick", SoundId = "rbxassetid://9119330229", Volume = 1, RollOffMaxDistance = 220 }, ball)
	local sharedBase = RS:WaitForChild("UltimatePitch")
	local sharedArenas = sharedBase:FindFirstChild("Arenas") or new("Folder", { Name = "Arenas" }, sharedBase)
	state = new("Folder", { Name = "State" }, new("Folder", { Name = A.id }, sharedArenas))
	for k, val in pairs({ Phase = "Lobby", RedScore = 0, BlueScore = 0, TimeLeft = 0, Message = "", MessageId = 0, Version = VERSION,
		GoalSeq = 0, LastGoalTeam = "", LastGoalAurora = false, BallOwner = 0 }) do
		state:SetAttribute(k, val)
	end
	new("ObjectValue", { Name = "BallCarrier" }, state)
end
G.arenas[A.id] = true
for k, val in pairs({ ArenaId = A.id, Origin = O, HalfLength = A.halfLength, HalfWidth = A.halfWidth, GoalHalfWidth = A.goalHalfWidth }) do
	state:SetAttribute(k, val)
end

-- ===== Spiellogik =====
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SHARED = RS:WaitForChild("UltimatePitch")
local State = state
local KickEvent = SHARED:WaitForChild("Kick")
local Ball = ball
local BotsFolder = root:WaitForChild("Bots")
-- Wohin Teilnehmer nach dem Match bzw. bei Abmeldung kommen: Stadion-Lobby oder ein Punkt neben der Arena
local EXIT_CF = A.exitCFrame
if not EXIT_CF then
	if A.stadium then
		EXIT_CF = root:WaitForChild("Lobby"):WaitForChild("LobbySpawn").CFrame + Vector3.new(0, 4, 0)
	else
		EXIT_CF = CFrame.new(OX, O.Y + 5, OZ - A.halfWidth - 5) -- auf dem Bodenrand neben dem Feld (Boden reicht 8 Studs über die Linie)
	end
end
local LobbyTeam = Teams:WaitForChild("Lobby")
local Sounds = SHARED:WaitForChild("Sounds")
local function sfx(name)
	if not A.stadium then return end -- diese Sounds sind nicht räumlich: nur das Stadion spielt sie
	local snd = Sounds:FindFirstChild(name)
	if snd then snd:Play() end
end

local CFG = {
	MatchTime = A.matchTime or 180, Intermission = 12, GoalPause = 3, EndPause = 6, MinPlayers = 1,
	AutoQueue = true, -- jeden Spieler beim Beitritt fürs Match anmelden (false, sobald die Stadt einen eigenen Einstieg hat)
	HalfLength = A.halfLength, HalfWidth = A.halfWidth, GoalHalfWidth = A.goalHalfWidth, GoalHeight = 10, GroundY = O.Y + 1,
	KickRange = 5, ShotRange = 7.5, ShotPower = 95, ShotMin = 45, ShotMax = 115, SprintFactor = 1.45, PassPower = 60, PlayerSpeed = 18, BotSpeed = 17, KeeperSpeed = 19,
	BallDrag = 0.55,
	-- Server-Autorität (eigene Testwerte): Schussladung wird serverseitig gemessen, Ausdauer serverseitig geführt
	ChargeTime = 1, ChargeMaxHold = 4,
	StaminaMax = 100, SprintDrain = 25, StaminaRegen = 16, SprintMinStamina = 5,
	MoveBurst = 12, -- Streckenbudget (Studs) für Netzwerk-Schübe, siehe Bewegungsprüfung
	-- Ballgefühl: Dribbel-Reichweite, Abstand des Balls vor dem Fuß, Zugstärke, Sperrzeit nach Schuss/Pass
	DribbleRange = 3.6, DribbleDist = 2.4, DribbleGain = 6, KickGrace = 0.35, DribbleMaxBall = 45,
	TackleRange = 3, TackleChance = 0.35, TackleRetry = 0.8, -- Bot-Zweikampf gegen den gegnerischen Ballführer
	TrapMaxSpeed = 75, -- schnellere Bälle (harte Schüsse) lassen sich nicht einfach annehmen
	-- Bot-KI: Entscheidungstakt am Ball, Schussdistanz, Gegnerdruck (ab dann eher passen)
	BotDecision = 0.35, BotShootRange = 40, BotPressure = 7,
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
local SLOTS = A.slots or { { d = 4, z = 0 }, { d = 28, z = -18 }, { d = 28, z = 18 }, { d = 62, z = -14 }, { d = 62, z = 14 } }

local phase = "Lobby"
local roster = { Rot = {}, Blau = {} }
local scores = { Rot = 0, Blau = 0 }
local pendingGoal = nil
local pendingGoalAurora = false
local botCd, lastKick = {}, {}
-- Serverseitiger Spielerzustand: Schussladung, Sprint-Wunsch, Ausdauer, Bewegungs-Stichprobe, Skill-Cooldown
local chargeStart, sprintWanted, stamina, motion, auroraReady = G.chargeStart, G.sprintWanted, G.stamina, G.motion, G.auroraReady
local auroraHold = nil      -- { player, releaseAt } während des Anlaufs: Ball wird vor dem Spieler gehalten
-- Schuss-Token des letzten AURORA-Kicks: { id, player, team, expires }. Jede andere Ballaktion
-- (Pass, Schuss, Bot-Kick, Parade, Ball-Reset, Berührung durch eine andere Figur) löscht es.
-- Ein Tor zählt nur als AURORA-Tor, wenn das Token noch gilt und das Tor für das Team des Schützen fällt.
local auroraShot = nil
local auroraShotSeq = 0
local ballOwner = nil -- Spieler (Mensch), der den Ball gerade führt; siehe dribble()
local ballCarrier = nil -- Figur (Mensch oder Bot), die den Ball gerade führt
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

-- Teilnahme (M1): Ein Match erfasst nur Spieler, die für seine Arena angemeldet sind (Player-Attribut
-- UP_Arena = Arena-Id, ausschließlich serverseitig gesetzt; leer = nirgends angemeldet). Wer nicht angemeldet
-- ist, wird weder eingeteilt noch teleportiert. Solange es außer dem Stadion nichts gibt, meldet AutoQueue
-- jeden Spieler beim Beitritt automatisch im Stadion an.
local function queued(plr) return plr:GetAttribute("UP_Arena") == A.id end
local function queuedPlayers()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if queued(plr) then table.insert(list, plr) end
	end
	return list
end

local function slotPos(td, slot)
	local s = SLOTS[slot]
	return Vector3.new(OX - td.sign * CFG.HalfLength + td.sign * s.d, CFG.GroundY + 3, OZ + s.z)
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
	Ball.CFrame = CFrame.new(OX, CFG.GroundY + 3, OZ)
	pcall(function() Ball:SetNetworkOwner(nil) end)
end
-- kicker (optional): Figur, die den Ball spielt. Clients zeigen dazu nur eine Schussanimation ("KickAnim");
-- Ballrichtung und -tempo setzt allein der Server.
local lastBallKickAt = 0 -- Zeitpunkt der letzten Schuss-/Passaktion: kurz danach kein Dribbel-Fangen
local function kickBall(vel, kicker)
	lastBallKickAt = os.clock()
	auroraShot = nil -- jede neue Ballaktion beendet die Zuordnung zum letzten AURORA-Schuss
	local k = Ball:FindFirstChild("Kick")
	if k then
		k.PlaybackSpeed = 0.9 + math.min(vel.Magnitude, 120) / 400
		k:Play()
	end
	pcall(function() Ball:SetNetworkOwner(nil) end)
	Ball.AssemblyLinearVelocity = vel
	if kicker then EffectEvent:FireAllClients("KickAnim", 0, kicker) end
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

---------------------------------------------------------------- Trikots (eigene Kits, nur Teilefarben + Rückennummer)
-- Einheitliche Teamkleidung für Bots und Spieler: Trikot mit kurzen Ärmeln (Oberarm in Trikotfarbe),
-- Hose, Stutzen in Teamfarbe, dunkle Schuhe, Rückennummer und kleines Brustabzeichen als SurfaceGui.
-- Keine Kleidungs-Assets: eigene Spieler-Kleidung (Shirt/Pants/T-Shirt-Bild) wird im Match entfernt.
local KIT = {
	Rot = { shorts = Color3.fromRGB(245, 245, 245), socks = Color3.fromRGB(200, 30, 40), trim = Color3.fromRGB(255, 255, 255) },
	Blau = { shorts = Color3.fromRGB(20, 28, 60), socks = Color3.fromRGB(40, 90, 230), trim = Color3.fromRGB(255, 220, 90) },
}
local NUMBERS = { 1, 4, 5, 10, 9 }
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(141, 92, 62),
	Color3.fromRGB(96, 62, 44), Color3.fromRGB(245, 205, 170) }
local BOOTS = Color3.fromRGB(22, 22, 26)

local function kitLabel(parent, face, text, size, color, name)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	gui.Parent = parent
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.45)
	l.Size = UDim2.fromScale(size, size)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = gui
end

local function applyKit(char, td, slot)
	local kit = KIT[td.name]
	if not kit then return end
	local shirt = slot == 1 and td.keeper or td.color
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then d:Destroy() end
	end
	local skin = char:GetAttribute("SkinColor")
	if not skin then
		local head = char:FindFirstChild("Head")
		skin = head and head.Color or SKIN[1]
	end
	local paint = {
		UpperTorso = shirt, LowerTorso = shirt, LeftUpperArm = shirt, RightUpperArm = shirt,
		LeftLowerArm = skin, RightLowerArm = skin, LeftHand = slot == 1 and BOOTS or skin, RightHand = slot == 1 and BOOTS or skin,
		LeftUpperLeg = kit.shorts, RightUpperLeg = kit.shorts, LeftLowerLeg = kit.socks, RightLowerLeg = kit.socks,
		LeftFoot = BOOTS, RightFoot = BOOTS,
	}
	for partName, color in pairs(paint) do
		local p = char:FindFirstChild(partName)
		if p and p:IsA("BasePart") then
			p.Color = color
			for _, s in ipairs(p:GetChildren()) do
				if s:IsA("SurfaceAppearance") then s:Destroy() end
			end
			if p:IsA("MeshPart") then pcall(function() p.TextureID = "" end) end
		end
	end
	local torso = char:FindFirstChild("UpperTorso")
	if torso then
		kitLabel(torso, Enum.NormalId.Back, tostring(NUMBERS[slot] or slot), 0.8, kit.trim, "KitNumber")
		kitLabel(torso, Enum.NormalId.Front, "UP", 0.32, kit.trim, "KitBadge")
	end
	char:SetAttribute("KitTeam", td.name)
	-- Namensschild im Broadcast-Stil (Nummer in Trikotfarbe + Name) statt des Standard-Humanoid-Namens
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	local head = char:FindFirstChild("Head")
	if head then
		local old = head:FindFirstChild("UP_Nameplate")
		if old then old:Destroy() end
		local plr = Players:GetPlayerFromCharacter(char)
		local name = plr and plr.DisplayName or char:GetAttribute("DisplayName") or char.Name
		local bb = Instance.new("BillboardGui")
		bb.Name = "UP_Nameplate"
		bb.Size = UDim2.fromOffset(130, 22)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 90
		bb.LightInfluence = 0
		bb.Adornee = head
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
		bg.BackgroundTransparency = 0.3
		bg.BorderSizePixel = 0
		bg.Parent = bb
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
		local chip = Instance.new("TextLabel")
		chip.Size = UDim2.new(0, 26, 1, 0)
		chip.BackgroundColor3 = shirt
		chip.BorderSizePixel = 0
		chip.Font = Enum.Font.GothamBlack
		chip.TextSize = 13
		chip.TextColor3 = kit.trim
		chip.Text = slot == 1 and "TW" or tostring(NUMBERS[slot] or slot)
		chip.Parent = bg
		Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.fromOffset(30, 0)
		nameLabel.Size = UDim2.new(1, -34, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 13
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Text = string.upper(name)
		nameLabel.Parent = bg
		bb.Parent = head
	end
end

-- Eigene, frei erfundene Spielernamen für Bots (keine realen Spieler)
local BOT_NAMES = { "Varga", "Okoro", "Lindqvist", "Moreau", "Tanaka", "Ribeiro", "Novak", "Haddad", "Kowal", "Mensah",
	"Albers", "Quiroga", "Sato", "Dimitrov", "Ekwueme", "Laine", "Brandt", "Castell", "Oyelaran", "Petrak" }

-- Laufanimationen für Bots: Roblox-Standardanimationen (R15 Idle/Lauf aus dem Standard-Animate-Skript),
-- kein eigener Upload. Wechsel über Humanoid.Running.
local BOT_ANIMS = { idle = "rbxassetid://507766388", run = "rbxassetid://913376220" }
local function animateBot(model, hum)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	for key, id in pairs(BOT_ANIMS) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		if ok and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Core
			tracks[key] = track
		end
	end
	if not tracks.idle and not tracks.run then return end
	local current
	local function play(key, speed)
		local t = tracks[key]
		if not t then return end
		if current ~= t then
			if current then current:Stop(0.15) end
			t:Play(0.15)
			current = t
		end
		if key == "run" then t:AdjustSpeed(math.clamp(speed / 16, 0.6, 1.5)) end
	end
	play("idle", 0)
	hum.Running:Connect(function(speed)
		if not model.Parent then return end
		if speed > 1 then play("run", speed) else play("idle", 0) end
	end)
end

local function makeBot(td, slot)
	local shirt = slot == 1 and td.keeper or td.color
	local model
	local skin = SKIN[math.random(1, #SKIN)]
	local ok = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = skin
		d.TorsoColor, d.LeftArmColor, d.RightArmColor = shirt, shirt, shirt
		d.LeftLegColor, d.RightLegColor = Color3.fromRGB(30, 30, 30), Color3.fromRGB(30, 30, 30)
		-- athletischere Proportionen: etwas größer, schmaler, schlanker Kopf
		d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = 1.05, 0.9, 0.92, 0.95
		model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then model = simpleRig(shirt) end
	model:SetAttribute("SkinColor", skin)
	model:SetAttribute("DisplayName", BOT_NAMES[math.random(1, #BOT_NAMES)])
	applyKit(model, td, slot)
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
	animateBot(model, hum)
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
	-- Teamtrikot erst nach geladenem Avatar anziehen (sonst lädt die eigene Kleidung danach nach)
	task.spawn(function()
		if not plr:HasAppearanceLoaded() then
			local done = false
			local conn = plr.CharacterAppearanceLoaded:Connect(function() done = true end)
			local t0 = os.clock()
			while not done and os.clock() - t0 < 6 do task.wait(0.2) end
			conn:Disconnect()
		end
		if plr.Character == char and char.Parent then applyKit(char, TEAM[teamName], slot) end
	end)
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
	local hl, hw = CFG.HalfLength - 2, CFG.HalfWidth - 2
	return Vector3.new(OX + math.clamp(p.X - OX, -hl, hl), CFG.GroundY, OZ + math.clamp(p.Z - OZ, -hw, hw))
end

-- KI v2: Bots führen den Ball mit derselben Ballführung wie Menschen (dribble) und entscheiden am Ball
-- zwischen Schuss, Pass auf einen freien Mitspieler und Dribbling mit Ausweichen. Ohne Ball: Pressing durch
-- den nächsten Feldspieler, Absicherung durch den zweitnächsten, Freilaufen bei eigenem Ballbesitz.

-- Kleinster Abstand eines Gegners zur Passlinie a -> b (größer = freier Passweg)
local function laneOpen(a, b, opps)
	local ab = flat(b - a)
	local len = ab.Magnitude
	if len < 1e-3 then return math.huge end
	local dir = ab / len
	local best = math.huge
	for _, o in ipairs(opps) do
		local ap = flat(o.root.Position - a)
		local t = math.clamp(ap:Dot(dir), 0, len)
		best = math.min(best, (ap - dir * t).Magnitude)
	end
	return best
end

local function nearestOpp(pos, opps)
	local best, bd = nil, math.huge
	for _, o in ipairs(opps) do
		local d = flat(o.root.Position - pos).Magnitude
		if d < bd then best, bd = o, d end
	end
	return best, bd
end

-- Bester freier Mitspieler: Passweg frei, Empfänger ungedeckt, möglichst nach vorn.
-- Rückpässe nur als Sicherheitspass unter starkem Druck (allowBack) und höchstens 15 Studs zurück.
local function choosePass(td, m, list, opps, allowBack)
	local s = td.sign
	local bp = Ball.Position
	local best, bestScore = nil, -math.huge
	for _, o in ipairs(list) do
		if o ~= m and o.slot ~= 1 then
			local op = o.root.Position + Vector3.new(s * 3, 0, 0) -- leicht in den Lauf spielen
			local dist = flat(op - bp).Magnitude
			local ahead = (op.X - bp.X) * s
			if dist > 8 and dist < 60 and ahead > (allowBack and -15 or -3) then
				local lane = laneOpen(bp, op, opps)
				if lane > 4 then
					local _, press = nearestOpp(op, opps)
					local score = ahead * (ahead >= 0 and 0.8 or 2) + math.min(lane, 12) * 1.2 + math.min(press, 15) * 0.8 - dist * 0.1
					if score > bestScore then best, bestScore = o, score end
				end
			end
		end
	end
	return best
end

local function passTo(td, m, o)
	local bp = Ball.Position
	local target = o.root.Position + Vector3.new(td.sign * 3, 0, 0)
	local d = flat(target - bp)
	kickBall(unit(d, Vector3.new(td.sign, 0, 0)) * math.clamp(d.Magnitude * 1.3, 32, 70) + Vector3.new(0, 2, 0), m.model)
end

-- Schuss ins vom Torwart entferntere Eck
local function shoot(td, m, opps)
	local s = td.sign
	local bp = Ball.Position
	local kz = 0
	for _, o in ipairs(opps) do
		if o.slot == 1 then kz = o.root.Position.Z - OZ end
	end
	local side = kz > 0 and -1 or 1
	local aim = Vector3.new(OX + s * (CFG.HalfLength + 4), 0, OZ + side * (CFG.GoalHalfWidth - 2.5) + (math.random() - 0.5) * 3)
	local dir = unit(flat(aim - bp), Vector3.new(s, 0, 0))
	kickBall(dir * CFG.ShotPower * (0.85 + math.random() * 0.2) + Vector3.new(0, 3 + math.random() * 8, 0), m.model)
end

-- Gewonnener Zweikampf: Ball zum freien Mitspieler spitzeln, sonst nach vorn
local function botKick(td, m, list, opps)
	local now = os.clock()
	if (botCd[m.model] or 0) > now then return end
	botCd[m.model] = now + 0.6
	local o = choosePass(td, m, list, opps)
	if o then passTo(td, m, o) return end
	local dir = CFrame.Angles(0, (math.random() - 0.5) * 0.8, 0) * Vector3.new(td.sign, 0, 0)
	kickBall(dir * 32 + Vector3.new(0, 1, 0), m.model)
end

-- Bot am Ball: Entscheidung höchstens alle BotDecision Sekunden, dazwischen Dribbling
local function carryBall(td, m, list, opps)
	local s = td.sign
	local root = m.root
	local bp = Ball.Position
	local toGoal = flat(Vector3.new(OX + s * CFG.HalfLength, 0, OZ) - bp)
	local _, press = nearestOpp(bp, opps)
	local now = os.clock()
	if (botCd[m.model] or 0) <= now then
		botCd[m.model] = now + CFG.BotDecision
		local goalDist = toGoal.Magnitude
		if goalDist < 24 or (goalDist < CFG.BotShootRange and math.abs(bp.Z - OZ) < 30 and press > 4) then
			shoot(td, m, opps)
			return
		end
		if press < CFG.BotPressure then
			-- unter Druck: Pass nach vorn; nur bei sehr engem Gegner auch Sicherheitspass zurück
			local o = choosePass(td, m, list, opps, press < 3.5)
			if o then passTo(td, m, o) return end
		elseif math.random() < 0.12 then
			-- gelegentlicher Steilpass, wenn ein Mitspieler deutlich weiter vorn frei ist
			local o = choosePass(td, m, list, opps)
			if o and (o.root.Position.X - bp.X) * s > 15 then passTo(td, m, o) return end
		end
	end
	-- Dribbling Richtung Tor; steht ein Gegner im Weg, seitlich ausweichen
	local dir = unit(toGoal, Vector3.new(s, 0, 0))
	local opp, od = nearestOpp(root.Position + dir * 6, opps)
	if opp and od < 9 then
		local away = flat(root.Position - opp.root.Position)
		local perp = Vector3.new(-dir.Z, 0, dir.X)
		dir = unit(dir + perp * ((away:Dot(perp) >= 0) and 0.9 or -0.9), dir)
	end
	m.hum:MoveTo(clampField(root.Position + dir * 12))
end

local function carrierTeam()
	if not (ballCarrier and ballCarrier.Parent) then return nil end
	local plr = Players:GetPlayerFromCharacter(ballCarrier)
	if plr then return plr.Team and plr.Team.Name end
	return ballCarrier:GetAttribute("Team")
end

local function keeper(td, m, bp, list, opps)
	local s = td.sign
	-- Rechnung in Arena-Koordinaten (Feldmitte = 0), das Laufziel geht danach zurück in Weltkoordinaten
	local wbp = bp
	bp = Vector3.new(bp.X - OX, bp.Y, bp.Z - OZ)
	local gx = -s * CFG.HalfLength
	local boxX, boxZ = math.min(20, CFG.HalfLength * 0.35), math.min(22, CFG.HalfWidth - 2)
	local inBox = math.abs(bp.X - gx) < boxX and math.abs(bp.Z) < boxZ
	local target
	if inBox then
		-- torseitig hinter den Ball stellen (statt auf den Ball zu laufen und ihn ins eigene Tor zu schieben)
		local goalCenter = Vector3.new(gx, 0, 0)
		target = flat(bp) + unit(flat(goalCenter - bp), Vector3.new(-s, 0, 0)) * 2.5
	else
		target = Vector3.new(gx + s * 3, 0, math.clamp(bp.Z * 0.35, -CFG.GoalHalfWidth + 2, CFG.GoalHalfWidth - 2))
	end
	local minX, maxX = math.min(gx + s * 1.5, gx + s * boxX), math.max(gx + s * 1.5, gx + s * boxX)
	target = Vector3.new(OX + math.clamp(target.X, minX, maxX), CFG.GroundY, OZ + math.clamp(target.Z, -boxZ, boxZ))
	m.hum:MoveTo(target)

	local rel = wbp - m.root.Position
	local now = os.clock()
	-- nicht eingreifen, wenn ein eigener Mitspieler den Ball führt
	if flat(rel).Magnitude < 6.5 and rel.Y < 7 and (botCd[m.model] or 0) < now and carrierTeam() ~= td.name then
		botCd[m.model] = now + 0.8
		local speed = Ball.AssemblyLinearVelocity.Magnitude
		local chance = speed > 70 and 0.6 or (speed > 40 and 0.8 or 0.97)
		if rel.Y > 1.5 then m.hum.Jump = true end
		if math.random() < chance then
			-- Spieleröffnung: freien Mitspieler anspielen, sonst weit klären
			local o = speed <= 40 and choosePass(td, m, list, opps)
			if o then
				passTo(td, m, o)
			else
				kickBall(Vector3.new(s * 75, 30, (math.random() * 2 - 1) * 35), m.model)
			end
			if speed > 40 then msg("Parade! TW " .. td.name); sfx("Save") end
		end
	end
end

local function thinkTeam(teamName)
	local td = TEAM[teamName]
	local s = td.sign
	local bp = Ball.Position
	local list = members(teamName)
	local opps = members(teamName == "Rot" and "Blau" or "Rot")
	local cTeam = carrierTeam()
	local weHave = cTeam == teamName
	local theyHave = cTeam ~= nil and not weHave
	local ownGoal = Vector3.new(OX - s * CFG.HalfLength, 0, OZ)
	-- Ohne eigenen Ballbesitz: nächster Feldspieler presst, zweitnächster sichert zwischen Ball und Tor ab
	local order = {}
	if not weHave then
		for _, m in ipairs(list) do
			if m.slot ~= 1 then table.insert(order, m) end
		end
		table.sort(order, function(a, b)
			return flat(a.root.Position - bp).Magnitude < flat(b.root.Position - bp).Magnitude
		end)
	end
	local presser, cover = order[1], order[2]
	for _, m in ipairs(list) do
		if m.e.kind == "bot" then
			if m.slot == 1 then
				keeper(td, m, bp, list, opps)
			elseif ballCarrier == m.model then
				carryBall(td, m, list, opps)
			else
				local home = slotPos(td, m.slot)
				local defender = m.slot <= math.ceil((#SLOTS + 1) / 2) -- 5 Plätze: 2-3 hinten; 3 Plätze: 2 hinten
				local target
				if m == presser then
					target = bp - Vector3.new(s, 0, 0) * 1.2
				elseif m == cover and theyHave then
					target = bp + unit(flat(ownGoal - bp), Vector3.new(-s, 0, 0)) * 12
				elseif weHave then
					-- Freilaufen: Verteidiger hinter dem Ball, Stürmer vor dem Ball und in die Breite
					if defender then
						target = Vector3.new(bp.X - s * 16, 0, OZ + (home.Z - OZ) * 1.2)
					else
						target = Vector3.new(bp.X + s * 20, 0, OZ + (home.Z - OZ) * 2.2)
					end
				else
					-- Formation: zwischen Grundposition und Ball, Verteidiger tiefer
					local pull = defender and 0.35 or 0.55
					target = Vector3.new(home.X + (bp.X - home.X) * pull, 0, OZ + (home.Z - OZ) * 0.9 + (bp.Z - OZ) * 0.3)
				end
				m.hum:MoveTo(clampField(target))
				-- Zweikampf gegen den gegnerischen Ballführer (Mensch oder Bot): nur aus kurzer Distanz,
				-- begrenzte Erfolgschance, Pause nach Fehlversuch
				local dist = flat(bp - m.root.Position).Magnitude
				if theyHave and dist < CFG.TackleRange and bp.Y < CFG.GroundY + 5 then
					local now = os.clock()
					if (botCd[m.model] or 0) <= now then
						if math.random() < CFG.TackleChance then
							botKick(td, m, list, opps)
						else
							botCd[m.model] = now + CFG.TackleRetry
						end
					end
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
	local list = queuedPlayers()
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	for idx, plr in ipairs(list) do
		if idx <= (#SLOTS - 1) * 2 then
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
	-- Nachbesetzen: makeBot kann warten (Avatar laden). Meldet sich in dieser Zeit ein bereits eingeteilter Spieler
	-- ab oder verlässt er das Spiel, bliebe sein Platz leer – solche Lücken vor dem Anpfiff mit Bots füllen.
	local again = true
	while again do
		again = false
		for teamName, td in pairs(TEAM) do
			for slot = 1, #SLOTS do
				local e = roster[teamName][slot]
				if not e or (e.kind == "player" and not e.player.Parent) then
					roster[teamName][slot] = nil
					local bot = makeBot(td, slot)
					if roster[teamName][slot] then
						bot:Destroy() -- inzwischen anderweitig besetzt
					else
						roster[teamName][slot] = { kind = "bot", model = bot }
					end
					again = true
				end
			end
		end
	end
end

local function cleanup()
	clearBots()
	-- nur die Teilnehmer dieser Arena zurückholen; alle anderen Spieler bleiben, wo sie sind
	local participants = {}
	for _, slots in pairs(roster) do
		for _, e in pairs(slots) do
			if e.kind == "player" and e.player.Parent then table.insert(participants, e.player) end
		end
	end
	roster = { Rot = {}, Blau = {} }
	for _, plr in ipairs(participants) do
		plr.Team = LobbyTeam
		local char = plr.Character
		if char then
			highlight(char, nil)
			teleport(plr, EXIT_CF)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
			char:SetAttribute("BaseSpeed", 16)
		end
	end
	resetBall()
end

-- Lebenszeichen und Generation der Spielschleife (siehe Watchdog unten an der Hauptschleife)
local loopBeat, loopGen = os.clock(), 0
local function runMatch()
	local myGen = loopGen
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
		if myGen ~= loopGen then return end -- Watchdog hat neu gestartet: diesen alten Match-Thread beenden
		loopBeat = os.clock()
		if humanCount() == 0 then break end
		if pendingGoal then
			local t = pendingGoal
			scores[t] += 1
			updateScore()
			-- Serverbestätigtes Tor-Ereignis für das GOAL-Cinematic der Clients
			State:SetAttribute("LastGoalTeam", t)
			State:SetAttribute("LastGoalAurora", pendingGoalAurora)
			State:SetAttribute("GoalSeq", (State:GetAttribute("GoalSeq") or 0) + 1)
			-- Torjubel: Bots des Torteams springen zweimal (Armbewegung zeigen die Clients, siehe AuroraFX.startMotion)
			for _, e in pairs(roster[t]) do
				local hum = e.kind == "bot" and e.model and e.model.Parent and e.model:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.Jump = true
					task.delay(0.9, function() if hum.Parent then hum.Jump = true end end)
				end
			end
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
	if not td or not findPlayerSlot(plr) then return end -- nur Teilnehmer dieser Arena
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
		kickBall(look * CFG.PassPower + Vector3.new(0, 3, 0), char)
	elseif kind == "Shot" then
		-- Ladung = serverseitig gemessene Haltedauer seit "ChargeStart"; ein mitgeschickter Wert wird ignoriert
		local began = chargeStart[plr]
		chargeStart[plr] = nil
		if not began or now - began > CFG.ChargeMaxHold then
			KickEvent:FireClient(plr, "NoCharge")
			return
		end
		local pw = math.clamp((now - began) / CFG.ChargeTime, 0, 1)
		kickBall(look * (CFG.ShotMin + (CFG.ShotMax - CFG.ShotMin) * pw) + Vector3.new(0, 6 + 30 * pw, 0), char)
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
	if not teamName and queued(plr) and (inMatch() or phase == "Goal") then
		teamName, slot = joinRunningMatch(plr)
	end
	if teamName and phase ~= "Lobby" and phase ~= "Intermission" and phase ~= "End" then
		placePlayer(plr, teamName, slot)
	elseif plr.Character then
		-- nur angemeldete Spieler in die Stadion-Lobby holen; alle anderen spawnen, wo die Welt sie hinstellt
		if queued(plr) then
			teleport(plr, EXIT_CF)
			plr.Character:SetAttribute("BaseSpeed", 16)
		end
	end
end

-- Abmeldung: Der Spieler verlässt den Kader sofort (noch vor jedem Warten), sein Platz geht im laufenden Match an
-- einen Bot. An den Ausgang dieser Arena kommt er nur, wenn er nirgends mehr angemeldet ist – wechselt er in eine
-- andere Arena, stellt ihn deren Anmeldung hin (sie läuft verzögert, also immer nach dieser Abmeldung).
local function leaveMatch(plr)
	local teamName, slot = findPlayerSlot(plr)
	if not teamName then return end
	if auroraHold and auroraHold.player == plr then auroraHold = nil end
	roster[teamName][slot] = nil
	plr.Team = LobbyTeam
	local char = plr.Character
	if char then
		highlight(char, nil)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 16 end
		char:SetAttribute("BaseSpeed", 16)
		if (plr:GetAttribute("UP_Arena") or "") == "" then teleport(plr, EXIT_CF) end
	end
	if phase ~= "Lobby" and phase ~= "Intermission" and phase ~= "End" and not roster[teamName][slot] then
		local bot = makeBot(TEAM[teamName], slot) -- kann kurz warten (Avatar laden)
		if not roster[teamName][slot] and phase ~= "Lobby" and phase ~= "Intermission" and phase ~= "End" then
			roster[teamName][slot] = { kind = "bot", model = bot }
		else
			bot:Destroy()
		end
	end
end

local function onPlayer(plr)
	if A.stadium and plr:GetAttribute("UP_Arena") == nil then
		plr:SetAttribute("UP_Arena", CFG.AutoQueue and A.id or "")
	end
	plr:GetAttributeChangedSignal("UP_Arena"):Connect(function()
		if queued(plr) then
			-- Verzögert, damit die Abmeldung in der bisherigen Arena sicher zuerst abgeschlossen ist
			task.defer(function()
				if not queued(plr) or findPlayerSlot(plr) or not plr.Character then return end
				if inMatch() or phase == "Goal" then
					-- Anmeldung während eines laufenden Matches: wie ein Spät-Beitritt
					local teamName, slot = joinRunningMatch(plr)
					if teamName then placePlayer(plr, teamName, slot) return end
				end
				-- sonst an den Wartepunkt dieser Arena
				teleport(plr, EXIT_CF)
				plr.Character:SetAttribute("BaseSpeed", 16)
			end)
		else
			leaveMatch(plr)
		end
	end)
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

-- Ballgefühl: serverseitiges Dribbling mit Ballannahme. Der nächste Feldspieler (Mensch) in DribbleRange
-- führt den Ball: der Ball wird weich zu einem Punkt vor seinen Füßen gezogen und läuft mit seinem Tempo mit;
-- ein ankommender Pass wird dabei auf Führungstempo abgebremst (Ballannahme). Berechnet nur aus Server-
-- Positionen, der Client sendet dafür nichts. Kurz nach jeder Schuss-/Passaktion (KickGrace) greift es nicht,
-- damit gespielte Bälle den Fuß verlassen. Bots bleiben bei ihrer Kick-Logik und können den Ball abnehmen.
-- Ballführer kann ein Mensch oder ein Bot sein: ballCarrier = Figur (Model), ballOwner = Player nur bei Menschen.
-- Clients sehen den Ballführer über State.BallCarrier (ObjectValue) bzw. State@BallOwner (UserId, 0 = kein Mensch).
local CarrierValue = State:WaitForChild("BallCarrier")
local function setCarrier(model, plr)
	if ballCarrier ~= model then
		ballCarrier = model
		CarrierValue.Value = model
	end
	if ballOwner ~= plr then
		ballOwner = plr
		State:SetAttribute("BallOwner", plr and plr.UserId or 0)
	end
end
local function setOwner(plr) -- Kurzform: Ballführer zurücksetzen
	if plr == nil then setCarrier(nil, nil) end
end
-- Kandidat prüfen: lebende Figur, Ballhöhe passt zu den Füßen (keine Annahme beim Überspringen)
local function canControl(root, hum, bp)
	if not (root and hum and hum.Health > 0) then return false end
	local feetY = root.Position.Y - hum.HipHeight - root.Size.Y / 2
	return math.abs(bp.Y - (feetY + 1.1)) < 2.5
end
local function dribble()
	if os.clock() - lastBallKickAt < CFG.KickGrace then setCarrier(nil, nil) return end
	local bp = Ball.Position
	if bp.Y > CFG.GroundY + 3 then setCarrier(nil, nil) return end
	-- Harte Schüsse lassen sich nicht einfach stoppen (nur der bisherige Ballführer behält den Ball)
	local ballSpeed = flat(Ball.AssemblyLinearVelocity).Magnitude
	local trappable = ballSpeed <= CFG.TrapMaxSpeed
	local best, bestRoot, bestPlr, bestD = nil, nil, nil, CFG.DribbleRange
	local carried = ballCarrier and ballCarrier.Parent
	local function consider(model, root, hum, plr, bias)
		if not canControl(root, hum, bp) then return end
		if not trappable and model ~= ballCarrier then return end
		-- Bots nehmen nur freie Bälle automatisch an; einem Ballführer (Gegner wie Mitspieler) nehmen sie den
		-- Ball ausschließlich über den begrenzten Zweikampf in thinkTeam ab. Menschen haben keine Tackle-Taste:
		-- sie gewinnen den Ball durch Nähe.
		if not plr and carried and model ~= ballCarrier then return end
		local d = flat(bp - root.Position).Magnitude + bias
		-- Hysterese: der Ballführer behält den Ball etwas länger, damit er bei Richtungswechseln nicht verspringt
		if model == ballCarrier then d -= 0.6 end
		if d < bestD then best, bestRoot, bestPlr, bestD = model, root, plr, d end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and findPlayerSlot(plr) then -- nur Teilnehmer dieser Arena
			consider(char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid"), plr, -0.3)
		end
	end
	for _, teamName in ipairs({ "Rot", "Blau" }) do
		for slot, e in pairs(roster[teamName]) do
			if e.kind == "bot" and slot ~= 1 and e.model and e.model.Parent then
				consider(e.model, e.model:FindFirstChild("HumanoidRootPart"), e.model:FindFirstChildOfClass("Humanoid"), nil, 0)
			end
		end
	end
	setCarrier(best, bestPlr)
	if not best then return end
	auroraShot = nil -- Ballannahme beendet jeden AURORA-Schuss
	local look = unit(flat(bestRoot.CFrame.LookVector), Vector3.new(1, 0, 0))
	-- Menschen: Die Figurgeschwindigkeit stammt aus der Physik der (clientbesessenen) Figur und ist damit
	-- nicht vertrauenswürdig: nur endliche Werte zulassen und auf das serverseitig erlaubte Höchsttempo
	-- (BaseSpeed × Sprintfaktor) begrenzen; Bots (serverbesessen) auf ihr Lauftempo. Ergebnis absolut ≤ DribbleMaxBall.
	local runVel = flat(bestRoot.AssemblyLinearVelocity)
	local runMag = runVel.Magnitude
	if runMag ~= runMag or runMag == math.huge then runVel = Vector3.zero end -- NaN oder unendlich
	local allowed = bestPlr and ((best:GetAttribute("BaseSpeed") or 16) * CFG.SprintFactor) or CFG.KeeperSpeed
	if runVel.Magnitude > allowed then runVel = runVel.Unit * allowed end
	local target = Vector3.new(bestRoot.Position.X, bp.Y, bestRoot.Position.Z) + look * CFG.DribbleDist
	local pull = flat(target - bp) * CFG.DribbleGain
	local desired = runVel + pull
	local maxSpeed = math.min(runVel.Magnitude * 1.5 + 8, CFG.DribbleMaxBall)
	if desired.Magnitude > maxSpeed then desired = desired.Unit * maxSpeed end
	local vel = Ball.AssemblyLinearVelocity
	Ball.AssemblyLinearVelocity = Vector3.new(desired.X, math.min(vel.Y, 2), desired.Z)
	-- Rollbewegung passend zur Laufrichtung (Radius 1,1)
	Ball.AssemblyAngularVelocity = Vector3.yAxis:Cross(desired) / 1.1
end

local aiAcc = 0
RunService.Heartbeat:Connect(function(dt)
	if not inMatch() then
		if auroraHold then auroraHold = nil end
		setOwner(nil)
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
	if not pendingGoal and not auroraHold then dribble() end
	local p = Ball.Position
	local lx, lz = p.X - OX, p.Z - OZ -- Ball in Arena-Koordinaten
	-- Tor?
	if not pendingGoal and math.abs(lz) < CFG.GoalHalfWidth and p.Y < CFG.GroundY + CFG.GoalHeight then
		if lx > CFG.HalfLength + 1.2 then pendingGoal = "Rot"
		elseif lx < -CFG.HalfLength - 1.2 then pendingGoal = "Blau" end
		if pendingGoal then
			local shot = auroraShot
			pendingGoalAurora = shot ~= nil and os.clock() < shot.expires and shot.team == pendingGoal
			auroraShot = nil
		end
	end
	-- Ball verloren?
	if p.Y < CFG.GroundY - 21 or math.abs(lx) > CFG.HalfLength + 20 or math.abs(lz) > CFG.HalfWidth + 20 then resetBall() end
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

-- Ausdauer, Sprint und Bewegungsplausibilität serverseitig (läuft auch außerhalb des Matches).
-- Gilt für alle Spieler auf dem Server und läuft deshalb nur einmal, nicht je Arena.
if not G.playerLoop then
G.playerLoop = true
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
end

---------------------------------------------------------------- Hauptschleife
-- Die Spielschleife läuft in eigenem Thread mit Generationszähler. Ein Watchdog startet sie neu, wenn sie
-- 60 s kein Lebenszeichen gibt. Anlass: In Studio hat ein „Script timeout“ (Studio-Hänger) den einzigen
-- Schleifen-Thread beendet; das Spiel blieb danach dauerhaft in „Anpfiff in 1s“ stehen.
resetBall()
local function gameLoop(gen)
	while gen == loopGen do
		loopBeat = os.clock()
		setPhase("Lobby")
		State:SetAttribute("TimeLeft", 0)
		if #queuedPlayers() < CFG.MinPlayers then
			msg("Warte auf Spieler …")
			repeat task.wait(1); loopBeat = os.clock() until #queuedPlayers() >= CFG.MinPlayers or gen ~= loopGen
		end
		if gen ~= loopGen then return end
		setPhase("Intermission")
		for t = CFG.Intermission, 1, -1 do
			State:SetAttribute("TimeLeft", t)
			task.wait(1)
			loopBeat = os.clock()
		end
		if #queuedPlayers() >= CFG.MinPlayers and gen == loopGen then
			local ok, err = pcall(runMatch)
			if not ok then
				warn("[UltimatePitch] " .. tostring(err))
				pcall(cleanup)
			end
		end
	end
end
local function startLoop()
	loopGen += 1
	loopBeat = os.clock()
	task.spawn(gameLoop, loopGen)
end
startLoop()
task.spawn(function()
	while true do
		task.wait(5)
		if os.clock() - loopBeat > 60 then -- großzügig: Bot-Aufbau beim Anstoß lädt Avatare
			warn("[UltimatePitch] Spielschleife ohne Lebenszeichen – Neustart")
			pcall(cleanup)
			startLoop()
		end
	end
end)
end -- createArena

createArena({ id = "Stadium", stadium = true, origin = Vector3.zero, halfLength = 80, halfWidth = 50, goalHalfWidth = 12 })

-- Weitere Arenen (z. B. der Bolzplatz in M2) entstehen über diese Schnittstelle. Sie liegt unter dem Server-Skript
-- in ServerScriptService und ist damit für Clients nicht erreichbar.
local createFn = Instance.new("BindableFunction")
createFn.Name = "CreateArena"
createFn.OnInvoke = function(cfg)
	assert(type(cfg) == "table" and cfg.stadium ~= true, "ungültige Arena-Konfiguration")
	assert(type(cfg.id) == "string" and #cfg.id > 0 and #cfg.id <= 32 and not cfg.id:find("[^%w_]"), "ungültige Arena-Id")
	assert(typeof(cfg.origin) == "Vector3", "origin fehlt")
	for _, key in ipairs({ "halfLength", "halfWidth", "goalHalfWidth" }) do
		assert(type(cfg[key]) == "number" and cfg[key] == cfg[key] and cfg[key] > 0 and cfg[key] <= 200, key .. " ungültig")
	end
	assert(cfg.goalHalfWidth < cfg.halfWidth, "Tor breiter als das Feld")
	assert(cfg.halfLength >= 15 and cfg.halfWidth >= 10, "Feld zu klein")
	assert(type(cfg.slots) == "table" and #cfg.slots >= 2 and #cfg.slots <= 5, "slots: 2 bis 5 Plätze je Team")
	for _, sl in ipairs(cfg.slots) do
		assert(type(sl) == "table" and type(sl.d) == "number" and type(sl.z) == "number", "slot ungültig")
	end
	createArena(cfg)
	return true
end
createFn.Parent = script
