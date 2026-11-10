-- UltimatePitch v0.5 – Command-Bar-Installer (Alternative zur .rbxlx)
-- Test vorher stoppen! Einfügen, Enter, dann Spielen. Die Welt baut sich beim Start.
if game:GetService("RunService"):IsRunning() then
	error("❌ Erst Test stoppen (rotes Quadrat), dann erneut ausführen!")
end
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
-- Schutz: Der Installer löscht nichts. Vorhandene UltimatePitch-Objekte werden nur nach ausdrücklicher
-- Bestätigung (_G.UP_REPLACE = true) ersetzt und vorher nach ServerStorage verschoben (Rückgängig: Strg+Z).
local old = {}
for _, o in pairs({ SSS:FindFirstChild("UltimatePitchServer"), SPS:FindFirstChild("UltimatePitchClient"),
	workspace:FindFirstChild("UltimatePitch"), game:GetService("ReplicatedStorage"):FindFirstChild("UltimatePitch") }) do
	table.insert(old, o)
end
if #old > 0 and _G.UP_REPLACE ~= true then
	local names = {}
	for _, o in ipairs(old) do table.insert(names, o:GetFullName()) end
	error("⚠ Nichts verändert: vorhandene UltimatePitch-Objekte gefunden (" .. table.concat(names, ", ") .. "). " ..
		"Zum Ersetzen zuerst  _G.UP_REPLACE = true  ausführen, dann den Installer erneut. Alte Objekte werden nach ServerStorage gesichert.")
end
_G.UP_REPLACE = nil
game:GetService("ChangeHistoryService"):SetWaypoint("Vor UltimatePitch v0.5")
if #old > 0 then
	local backup = Instance.new("Folder")
	backup.Name = "UP_Backup_" .. os.date("%Y%m%d_%H%M%S")
	for _, o in ipairs(old) do o.Parent = backup end
	backup.Parent = game:GetService("ServerStorage")
	print("ℹ Alte UltimatePitch-Objekte gesichert: ServerStorage." .. backup.Name)
end
local s = Instance.new("Script") s.Name = "UltimatePitchServer" s.Source = [==[-- UltimatePitch v0.5 · Server (baut die Welt beim Start selbst)
local VERSION = "0.5"

-- Gemeinsamer Zustand aller Arenen (M1b): Spielerwerte (Ausdauer, Sprint, Bewegungsprüfung, Cooldown) gelten
-- serverweit; jedes Match läuft als eigene Instanz in seiner Arena (siehe createArena).
local G = {
	arenas = {},
	chargeStart = {}, sprintWanted = {}, stamina = {}, motion = {}, auroraReady = {},
	playerLoop = false,
}

local RS = game:GetService("ReplicatedStorage")
-- Karriere (M3): Pitch Coins, Scout, Shop – Belohnungen vergibt nur der Server am Matchende
local Career = require(script:WaitForChild("Career"))
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

-- Lobby (schwebt über der Seitenlinie, Blick aufs Feld) – entfällt, sobald die Stadt den Einstieg übernimmt
if A.lobby ~= false then
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
end

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
	AutoQueue = false, -- Beitritt über die Pads der Stadt; true meldete jeden Spieler beim Betreten des Servers im Stadion an
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
local lastTouch = nil -- letzter Mensch am Ball (Kick, Dribbling, Körperkontakt; nil nach Bot-Kontakt/Reset): Tor für sein Team
local goalsBy = {} -- [Player] = Tore im laufenden Match (Grundlage der Karriere-Belohnung)
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
	lastTouch = nil -- nach Anstoß/Ball-Reset zählt erst die nächste echte Berührung
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
	lastTouch = kicker and Players:GetPlayerFromCharacter(kicker) or nil
	auroraShot = nil -- jede neue Ballaktion beendet die Zuordnung zum letzten AURORA-Schuss
	local k = Ball:FindFirstChild("Kick")
	if k then
		k.PlaybackSpeed = 0.9 + math.min(vel.Magnitude, 120) / 400
		k:Play()
	end
	pcall(function() Ball:SetNetworkOwner(nil) end)
	Ball.AssemblyLinearVelocity = vel
	if kicker then EffectEvent:FireAllClients("KickAnim", 0, kicker, A.id) end
end
-- Körperkontakt einer Figur (Spieler oder Bot) mit dem Ball; Arena-Geometrie zählt nicht.
-- Ein Mensch wird letzter Ballkontakt (Torschütze), ein Bot löscht ihn; eine andere Figur als der Schütze
-- beendet außerdem die Zuordnung zum AURORA-Schuss.
Ball.Touched:Connect(function(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if not model or not model:FindFirstChildOfClass("Humanoid") then return end
	lastTouch = Players:GetPlayerFromCharacter(model)
	local shot = auroraShot
	if shot and model ~= shot.player.Character then auroraShot = nil end
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
	Career.decorate(char) -- gekaufte Optik (Schuhe, Binde, Rückennummer); Bots bleiben unverändert
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
		-- nach dem Match ist der Spieler wieder frei in der Stadt (neuer Beitritt über das Pad)
		if plr:GetAttribute("UP_Arena") == A.id then plr:SetAttribute("UP_Arena", "") end
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
	goalsBy, lastTouch = {}, nil
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
	-- Karriere: nur vollständig gespielte Matches (mit Sieger) werden belohnt, nur Spieler, die bis zum Ende dabei sind
	if winner then
		local results = {}
		for teamName, slots in pairs(roster) do
			for _, e in pairs(slots) do
				if e.kind == "player" and e.player.Parent and e.player:GetAttribute("UP_Arena") == A.id then
					table.insert(results, { player = e.player, won = teamName == winner, goals = goalsBy[e.player] or 0 })
				end
			end
		end
		Career.onMatchEnd(A.id, results)
	end
	goalsBy = {}
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
		EffectEvent:FireAllClients("AuroraWindup", plr.UserId, CFG.AuroraWindup, A.id)
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
		EffectEvent:FireAllClients("AuroraCancel", plr.UserId, nil, A.id)
		return
	end
	local td = TEAM[plr.Team and plr.Team.Name]
	local look = unit(flat(root.CFrame.LookVector), Vector3.new(td and td.sign or 1, 0, 0))
	kickBall(look * CFG.AuroraSpeed + Vector3.new(0, CFG.AuroraLift, 0))
	lastTouch = plr
	auroraShotSeq += 1
	auroraShot = { id = auroraShotSeq, player = plr, team = plr.Team and plr.Team.Name,
		expires = os.clock() + CFG.AuroraGoalWindow }
	State:SetAttribute("AuroraShotId", auroraShotSeq)
	EffectEvent:FireAllClients("AuroraKick", plr.UserId, nil, A.id)
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
	if model then lastTouch = plr end
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
			-- Torschütze nur bei Toren fürs eigene Team (kein Eigentor-Bonus)
			local scorer = lastTouch
			if scorer and scorer.Parent and scorer.Team and scorer.Team.Name == pendingGoal then
				goalsBy[scorer] = (goalsBy[scorer] or 0) + 1
			end
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

-- ULTIMATE CITY, erster Bezirk (M2): Plaza mit Spawn vor der Südseite des SPECTRA DOME, Stadionzugang und Bolzplatz.
-- Spieler starten frei auf der Plaza und melden sich über ein Pad für eine Arena an.
local PlayersService = game:GetService("Players")
local LAYOUT = {
	groundY = 1,
	plaza = Vector3.new(0, 0, -215),
	stadiumPad = Vector3.new(0, 1.2, -158),
	courtPad = Vector3.new(86, 1.2, -235),
	court = { origin = Vector3.new(130, 0, -235), halfLength = 30, halfWidth = 18 },
}
createArena({ id = "Stadium", stadium = true, lobby = false, origin = Vector3.zero, halfLength = 80, halfWidth = 50, goalHalfWidth = 12,
	exitCFrame = CFrame.lookAt(Vector3.new(16, 5, -174), Vector3.new(0, 5, -158)) })
createArena({ id = "StreetCourt", origin = LAYOUT.court.origin, halfLength = LAYOUT.court.halfLength, halfWidth = LAYOUT.court.halfWidth,
	goalHalfWidth = 6, matchTime = 120, slots = { { d = 3, z = 0 }, { d = 12, z = -7 }, { d = 22, z = 7 } },
	exitCFrame = CFrame.lookAt(Vector3.new(78, 5, -222), Vector3.new(86, 5, -235)) })
local city = require(script:WaitForChild("City")).build(workspace:WaitForChild("UltimatePitch"), LAYOUT)
Career.init(city.folder, LAYOUT)

-- Beitritt: Wer nirgends angemeldet ist und ein Pad betritt, wird für dessen Arena angemeldet. Berührungen
-- clientbesessener Figuren meldet der Client selbst; der Server prüft deshalb zusätzlich die tatsächliche
-- Position der Figur (HumanoidRootPart über der Pad-Fläche, kleine Toleranz), bevor er anmeldet.
local padTouch = {}
local function standsOnPad(char, pad)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local rel = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= pad.Size.X / 2 + 2 and math.abs(rel.Z) <= pad.Size.Z / 2 + 2 and rel.Y > -1 and rel.Y < 7
end
for arenaId, pad in pairs(city.pads) do
	pad.Touched:Connect(function(hit)
		local char = hit.Parent
		local plr = char and PlayersService:GetPlayerFromCharacter(char)
		local hum = plr and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or plr.Character ~= char then return end
		if not standsOnPad(char, pad) then return end
		local now = os.clock()
		if (padTouch[plr] or 0) + 1.5 > now then return end
		padTouch[plr] = now
		if (plr:GetAttribute("UP_Arena") or "") == "" then plr:SetAttribute("UP_Arena", arenaId) end
	end)
end
PlayersService.PlayerRemoving:Connect(function(plr) padTouch[plr] = nil end)

-- Verlassen: Der Client darf nur seine eigene Anmeldung zurücknehmen (zurück in die Stadt), sonst nichts.
RS:WaitForChild("UltimatePitch"):WaitForChild("Kick").OnServerEvent:Connect(function(plr, kind)
	if kind == "Leave" and (plr:GetAttribute("UP_Arena") or "") ~= "" then plr:SetAttribute("UP_Arena", "") end
end)

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
]==]
local sd = Instance.new("ModuleScript") sd.Name = "Dome" sd.Source = [==[-- UltimatePitch · SPECTRA DOME (ModuleScript unter UltimatePitchServer)
-- Eigener prozeduraler Stadionbau aus Roblox-Grundteilen: elliptischer Zwei-Rang-Kessel mit Umlauf und
-- Spielertunnel, Zuschauer im Unterrang, LED-Ringe (Cyan, Pink nur als Akzent), offenes Dach mit radialen
-- Trägern, Flutlicht und Anzeigetafel. Keine externen Assets. Zuschauer und Sitzreihen tragen das Tag
-- "UP_Crowd", damit Clients sie im Low-Grafikprofil ausblenden können.
local CollectionService = game:GetService("CollectionService")

local Dome = {}

local SEGMENTS = 48
local INNER_A, INNER_B = 118, 74 -- Innenkante des Kessels (Halbachsen X/Z); schließt Spielfeld samt Banden ein
local LOWER_ROWS, UPPER_ROWS = 8, 10
local ROW_DEPTH = 2.8
local CONCOURSE = 6
local ROOF_Y = 50
local TUNNEL_SEGMENTS = { [12] = true, [13] = true } -- Unterrang-Lücke bei +Z (Mitte der Längsseite)

local CONCRETE = Color3.fromRGB(38, 44, 62)
local CONCRETE_UPPER = Color3.fromRGB(30, 35, 52)
local STEEL = Color3.fromRGB(70, 78, 96)
local CYAN = Color3.fromRGB(40, 210, 255)
local BLUE = Color3.fromRGB(40, 90, 255)
local PINK = Color3.fromRGB(255, 70, 170)
local SEAT_COLORS = { Color3.fromRGB(28, 70, 190), Color3.fromRGB(220, 226, 236), Color3.fromRGB(20, 150, 210) }
local FAN_COLORS = {
	Color3.fromRGB(215, 40, 40), Color3.fromRGB(40, 90, 230), Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(255, 200, 40), Color3.fromRGB(30, 30, 30), Color3.fromRGB(40, 200, 220),
}

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

local function deco(props, parent)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props, parent)
end

-- Punkt auf der um d nach außen versetzten Ellipse
local function ring(theta, d)
	return Vector3.new((INNER_A + d) * math.cos(theta), 0, (INNER_B + d) * math.sin(theta))
end

-- Teil entlang eines Ellipsenbogens zwischen zwei Winkeln: X = Tiefe (radial), Y = Höhe, Z = Bogenlänge
local function arcPart(theta1, theta2, d, y, depth, height, props, parent, isDeco)
	local p1, p2 = ring(theta1, d), ring(theta2, d)
	local mid = (p1 + p2) / 2 + Vector3.new(0, y, 0)
	local length = (p2 - p1).Magnitude + 0.35
	props.Size = Vector3.new(depth, height, length)
	props.CFrame = CFrame.lookAt(mid, mid + (p2 - p1))
	return (isDeco and deco or part)(props, parent)
end

local function rowRadius(row)
	if row <= LOWER_ROWS then return (row - 0.5) * ROW_DEPTH end
	return LOWER_ROWS * ROW_DEPTH + CONCOURSE + (row - LOWER_ROWS - 0.5) * ROW_DEPTH
end

local function rowTop(gy, row)
	if row <= LOWER_ROWS then return gy + 1.5 + row * 1.5 end
	return gy + 20 + (row - LOWER_ROWS) * 2.1
end

-- Großbildwand hinter dem rechten Tor (+X, gegenüber der Anzeigetafel). Zeigt live Spielstand und Zeit;
-- bei einem serverbestätigten Tor (GoalSeq) für 3 s „GOAL!“ in Teamfarbe, bei AURORA-Toren in Grün.
-- Nur ereignisgesteuerte Eigenschaftsänderungen (keine Dauer-Tweens auf dem Server).
function Dome.buildScreen(dome, gy, state)
	local pos = Vector3.new(INNER_A + 26, gy + 37, 0)
	local screen = part({ Name = "VideoScreen", Size = Vector3.new(58, 22, 2),
		CFrame = CFrame.lookAt(pos, Vector3.new(0, gy + 37, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(8, 10, 18) }, dome)
	deco({ Name = "VideoScreenFrame", Size = Vector3.new(59.6, 23.6, 0.4), CFrame = screen.CFrame * CFrame.new(0, 0, 1.2),
		Material = Enum.Material.Neon, Color = BLUE, Transparency = 0.15 }, dome)
	part({ Name = "VideoScreenMount", Size = Vector3.new(40, 4, 3), CFrame = screen.CFrame * CFrame.new(0, -13, 2),
		Material = Enum.Material.Metal, Color = STEEL }, dome)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8 -- 464 × 176 px: TextScaled ist auf 100 px begrenzt, so füllt der Spielstand die Wand
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = screen
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(6, 12, 34)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(20, 60, 160), Color3.fromRGB(6, 12, 34))
	grad.Rotation = 90
	grad.Parent = bg
	local function text(name, y, h, size)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true -- ohne RichText: RichText + TextScaled verkleinert die Schrift stark
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Parent = bg
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.Parent = l
		return l
	end
	local brand = text("Brand", 0.04, 0.16, 60)
	brand.TextColor3 = CYAN
	brand.Text = "SPECTRA DOME"
	local big = text("Big", 0.24, 0.5, 220)
	local sub = text("Sub", 0.76, 0.18, 70)

	local showingGoalUntil = 0
	local function live()
		if os.clock() < showingGoalUntil then return end
		grad.Color = ColorSequence.new(Color3.fromRGB(20, 60, 160), Color3.fromRGB(6, 12, 34))
		big.TextColor3 = Color3.new(1, 1, 1)
		big.Text = string.format("%d : %d", state:GetAttribute("RedScore") or 0, state:GetAttribute("BlueScore") or 0)
		local t = state:GetAttribute("TimeLeft") or 0
		sub.Text = string.format("ROT  ·  %d:%02d  ·  BLAU", t // 60, t % 60)
	end
	local lastSeq = state:GetAttribute("GoalSeq") or 0
	state.AttributeChanged:Connect(function(name)
		if name == "GoalSeq" then
			local seq = state:GetAttribute("GoalSeq") or 0
			if seq > lastSeq then
				local team = state:GetAttribute("LastGoalTeam") or ""
				local aurora = state:GetAttribute("LastGoalAurora") == true
				local col = aurora and Color3.fromRGB(10, 160, 110) or (team == "Rot" and Color3.fromRGB(190, 30, 45) or Color3.fromRGB(30, 70, 220))
				grad.Color = ColorSequence.new(col, Color3.fromRGB(6, 12, 34))
				big.TextColor3 = Color3.fromRGB(255, 228, 138)
				big.Text = "GOAL!"
				sub.Text = (aurora and "AURORA BREAK  ·  " or "") .. string.upper(team)
				showingGoalUntil = os.clock() + 3
				task.delay(3.05, live)
			end
			lastSeq = seq
		elseif name == "RedScore" or name == "BlueScore" or name == "TimeLeft" then
			live()
		end
	end)
	live()
	return screen
end

-- Lichttraversen: zwei Stahlträger längs über dem Feld (z = ±42, 44 Studs über dem Rasen), an der
-- Dach-Innenkante abgehängt. Je 6 Strahlerköpfe mit SpotLight zielen schräg auf die eigene Feldhälfte
-- (Abstand ~58 Studs, innerhalb der Lichtreichweite von 60). Die SpotLights tragen das Tag "UP_FieldLight":
-- Clients schalten Schatten je Grafikprofil lokal ein/aus.
local GANTRY_Z, GANTRY_H = 42, 44
local LAMP_X = { -75, -45, -15, 15, 45, 75 }
function Dome.buildGantries(dome, gy)
	local folder = Instance.new("Folder")
	folder.Name = "Gantries"
	folder.Parent = dome
	local y = gy + GANTRY_H
	local edgeA = INNER_A + 20
	local edgeB = INNER_B + 20
	for _, side in ipairs({ -1, 1 }) do
		local z = side * GANTRY_Z
		local halfLen = edgeA * math.sqrt(1 - (GANTRY_Z / edgeB) ^ 2)
		deco({ Name = "GantryBeam", Size = Vector3.new(halfLen * 2, 2.2, 2.2), CFrame = CFrame.new(0, y, z),
			Material = Enum.Material.DiamondPlate, Color = STEEL }, folder)
		deco({ Name = "GantryChord", Size = Vector3.new(halfLen * 2, 0.5, 0.5), CFrame = CFrame.new(0, y + 2.2, z),
			Material = Enum.Material.Metal, Color = STEEL }, folder)
		deco({ Name = "GantryLED", Size = Vector3.new(halfLen * 2 - 4, 0.3, 0.6), CFrame = CFrame.new(0, y - 1.25, z),
			Material = Enum.Material.Neon, Color = CYAN }, folder)
		-- Abhängungen zur Dachkante und Fachwerk-Streben
		for _, sx in ipairs({ -1, 1 }) do
			local top = Vector3.new(sx * halfLen, ROOF_Y - 0.6, z)
			local bottom = Vector3.new(sx * (halfLen - 6), y + 1, z)
			deco({ Name = "GantryHanger", Size = Vector3.new(0.4, 0.4, (top - bottom).Magnitude),
				CFrame = CFrame.lookAt((top + bottom) / 2, top), Material = Enum.Material.Metal, Color = STEEL }, folder)
		end
		for k = -10, 9 do
			local x0 = k * (halfLen / 10)
			local a, b = Vector3.new(x0, y + 1.1, z), Vector3.new(x0 + halfLen / 10, y + 2.2, z)
			deco({ Name = "GantryStrut", Size = Vector3.new(0.3, 0.3, (b - a).Magnitude),
				CFrame = CFrame.lookAt((a + b) / 2, b), Material = Enum.Material.Metal, Color = STEEL }, folder)
		end
		for _, x in ipairs(LAMP_X) do
			local headPos = Vector3.new(x, y - 2, z)
			local target = Vector3.new(x * 0.92, gy, -side * 6)
			local head = deco({ Name = "GantryLamp", Size = Vector3.new(4.2, 2.6, 2),
				CFrame = CFrame.lookAt(headPos, target), Material = Enum.Material.Metal, Color = Color3.fromRGB(26, 30, 40) }, folder)
			local lens = deco({ Name = "GantryLens", Size = Vector3.new(3.6, 2, 0.2), CFrame = head.CFrame * CFrame.new(0, 0, -1.05),
				Material = Enum.Material.Neon, Color = Color3.fromRGB(240, 248, 255) }, folder)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Front
			light.Brightness = 2.4
			light.Range = 60
			light.Angle = 80
			light.Color = Color3.fromRGB(236, 244, 255)
			light.Shadows = true
			light.Parent = lens
			CollectionService:AddTag(light, "UP_FieldLight")
		end
	end
end

function Dome.build(root, gy, state)
	local dome = Instance.new("Folder")
	dome.Name = "SpectraDome"
	local bowl = Instance.new("Folder"); bowl.Name = "Bowl"; bowl.Parent = dome
	local crowd = Instance.new("Folder"); crowd.Name = "Crowd"; crowd.Parent = dome
	local led = Instance.new("Folder"); led.Name = "LED"; led.Parent = dome
	local roof = Instance.new("Folder"); roof.Name = "Roof"; roof.Parent = dome

	local rng = Random.new(20261106)
	local function tagCrowd(p) CollectionService:AddTag(p, "UP_Crowd") end

	for i = 0, SEGMENTS - 1 do
		local t1, t2 = i / SEGMENTS * math.pi * 2, (i + 1) / SEGMENTS * math.pi * 2
		local sector = SEAT_COLORS[(math.floor(i / 4) % #SEAT_COLORS) + 1]
		for row = 1, LOWER_ROWS + UPPER_ROWS do
			local isLower = row <= LOWER_ROWS
			if not (isLower and TUNNEL_SEGMENTS[i] and row <= 5) then
				local d = rowRadius(row)
				local top = rowTop(gy, row)
				local base = isLower and gy or (gy + 14)
				arcPart(t1, t2, d, (top + base) / 2, ROW_DEPTH + 0.05, top - base, {
					Name = "Step", Material = Enum.Material.Concrete, Color = isLower and CONCRETE or CONCRETE_UPPER,
				}, bowl)
				-- Sitzreihe als farbiger Streifen, darauf Zuschauer (Unterrang einzeln, Oberrang als Farbfläche)
				local seat = arcPart(t1, t2, d - 0.4, top + 0.35, 1.2, 0.7, {
					Name = "Seats", Material = Enum.Material.Fabric, Color = sector,
				}, crowd, true)
				tagCrowd(seat)
				if isLower then
					-- Dichte Publikumsmasse: durchgehender „Oberkörper“-Streifen je Reihe in gemischter Shirtfarbe,
					-- darauf einzelne hellere Figuren als Akzente (statt Einzelwürfeln mit Lücken)
					local body = arcPart(t1, t2, d + 0.2, top + 1.25, 1.1, 1.5, {
						Name = "CrowdBody", Material = Enum.Material.Fabric,
						Color = FAN_COLORS[rng:NextInteger(1, #FAN_COLORS)]:Lerp(Color3.fromRGB(30, 34, 50), 0.45),
					}, crowd, true)
					tagCrowd(body)
					for k = 1, 3 do
						if rng:NextNumber() < 0.85 then
							local a = t1 + (t2 - t1) * (k - 0.5) / 3
							local pos = ring(a, d) + Vector3.new(0, top + 1.5, 0)
							local fan = deco({
								Name = "Fan", Size = Vector3.new(1.1, 2.1, 1.1),
								CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
								Color = FAN_COLORS[rng:NextInteger(1, #FAN_COLORS)], Material = Enum.Material.SmoothPlastic,
							}, crowd)
							tagCrowd(fan)
							CollectionService:AddTag(fan, "UP_CrowdDetail") -- Einzelfiguren: im Profil „Mittel“ aus
						end
					end
				else
					local fill = arcPart(t1, t2, d + 0.3, top + 1.2, 1.4, 1.6, {
						Name = "CrowdFill", Material = Enum.Material.Fabric,
						Color = FAN_COLORS[rng:NextInteger(1, #FAN_COLORS)]:Lerp(sector, 0.35),
					}, crowd, true)
					tagCrowd(fill)
				end
			end
		end

		-- Umlauf zwischen den Rängen und Rückwand mit Tunnel-Ausschnitt
		local concourseD = LOWER_ROWS * ROW_DEPTH + CONCOURSE / 2
		arcPart(t1, t2, concourseD, gy + 14.5, CONCOURSE, 1, { Name = "Concourse", Material = Enum.Material.Slate, Color = Color3.fromRGB(24, 28, 40) }, bowl)
		local backD = rowRadius(LOWER_ROWS + UPPER_ROWS) + ROW_DEPTH
		arcPart(t1, t2, backD, gy + 24, 1.5, 48, { Name = "OuterWall", Material = Enum.Material.Metal, Color = Color3.fromRGB(20, 24, 36) }, bowl)

		-- LED-Ringe: Unterrang-Front und Oberrang-Front in Cyan/Blau
		arcPart(t1, t2, -0.6, gy + 3.2, 0.3, 0.6, { Name = "LEDLower", Material = Enum.Material.Neon, Color = CYAN }, led, true)
		arcPart(t1, t2, LOWER_ROWS * ROW_DEPTH + CONCOURSE - 0.3, gy + 19.5, 0.3, 0.8, { Name = "LEDUpper", Material = Enum.Material.Neon, Color = BLUE }, led, true)

		-- Dach: Platte vom Außenrand zur Innenkante (offen über dem Feld), Innenkante mit Pink-Akzent
		local inner = ring((t1 + t2) / 2, 20)
		local outer = ring((t1 + t2) / 2, backD)
		local roofMid = (inner + outer) / 2 + Vector3.new(0, ROOF_Y - 1.5, 0)
		local p1, p2 = ring(t1, 20), ring(t2, 20)
		local q1, q2 = ring(t1, backD), ring(t2, backD)
		local width = math.max((p2 - p1).Magnitude, (q2 - q1).Magnitude) + 0.4
		local radial = Vector3.new(outer.X - inner.X, 0, outer.Z - inner.Z)
		deco({
			Name = "RoofPanel", Size = Vector3.new(width, 0.6, radial.Magnitude),
			CFrame = CFrame.lookAt(roofMid, roofMid + radial) * CFrame.Angles(math.rad(-4), 0, 0),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(18, 22, 36), -- geschlossene Dachfläche über den Rängen
		}, roof)
		arcPart(t1, t2, 20, ROOF_Y - 0.6, 1.2, 1.2, { Name = "InnerRing", Material = Enum.Material.Metal, Color = STEEL }, roof, true)
		arcPart(t1, t2, 19.3, ROOF_Y - 1.6, 0.3, 0.5, { Name = "LEDRoof", Material = Enum.Material.Neon, Color = PINK }, led, true)

		-- Radiale Träger, Stützen und Flutlicht an jedem vierten Segment
		if i % 4 == 0 then
			local truss = deco({
				Name = "RoofTruss", Size = Vector3.new(1.2, 2.4, radial.Magnitude),
				CFrame = CFrame.lookAt(roofMid + Vector3.new(0, 1.2, 0), roofMid + Vector3.new(0, 1.2, 0) + radial),
				Material = Enum.Material.Metal, Color = STEEL,
			}, roof)
			truss.Name = "RoofTruss"
			-- Leuchtband unter dem Träger (Hallen-Look)
			deco({ Name = "LEDTruss", Size = Vector3.new(0.35, 0.35, radial.Magnitude - 2),
				CFrame = truss.CFrame * CFrame.new(0, -1.45, 0), Material = Enum.Material.Neon, Color = CYAN }, led)
			part({ Name = "Column", Size = Vector3.new(2, ROOF_Y - gy, 2), Position = outer + Vector3.new(0, (ROOF_Y + gy) / 2, 0),
				Material = Enum.Material.Metal, Color = STEEL }, roof)
			-- Dachkanten-Strahler nur noch als Leuchtkörper: Lichtquellen haben max. 60 Studs Reichweite und
			-- erreichten das Feld von hier (~140 Studs) nie. Das Feld beleuchten die Traversen (buildGantries).
			local lampPos = inner + Vector3.new(0, ROOF_Y - 2.6, 0)
			deco({
				Name = "Floodlight", Size = Vector3.new(5, 1.2, 3),
				CFrame = CFrame.lookAt(lampPos, Vector3.new(0, gy, 0)),
				Material = Enum.Material.Neon, Color = Color3.fromRGB(235, 248, 255),
			}, roof)
		end
	end

	Dome.buildGantries(dome, gy)

	-- Spielertunnel hinter der Lücke im Unterrang
	local tunnelMid = ring((12.5 / SEGMENTS) * math.pi * 2, 8)
	part({ Name = "Tunnel", Size = Vector3.new(14, 9, 18), CFrame = CFrame.lookAt(tunnelMid + Vector3.new(0, gy + 4.5, 0), Vector3.new(0, gy + 4.5, 0)),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 12, 18) }, bowl)
	deco({ Name = "TunnelLight", Size = Vector3.new(10, 0.4, 0.4), CFrame = CFrame.lookAt(tunnelMid + Vector3.new(0, gy + 8.6, -2), Vector3.new(0, gy + 8.6, 0)),
		Material = Enum.Material.Neon, Color = CYAN }, led)

	-- Anzeigetafel über dem Oberrang hinter dem linken Tor, zeigt Spielstand und Zeit aus State
	local boardPos = Vector3.new(-(INNER_A + 24), gy + 40, 0)
	-- Breite entlang lokal X, Front (-Z) zeigt zum Feld (vorher 2 × 16 × 44: Tafel stand hochkant zur Seite)
	local board = part({ Name = "Scoreboard", Size = Vector3.new(44, 16, 2), CFrame = CFrame.lookAt(boardPos, Vector3.new(0, gy + 40, 0)),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 12, 20) }, dome)
	local frameGlow = deco({ Name = "ScoreboardFrame", Size = Vector3.new(45.2, 17.2, 0.4), CFrame = board.CFrame * CFrame.new(0, 0, 1.2),
		Material = Enum.Material.Neon, Color = CYAN, Transparency = 0.2 }, led)
	frameGlow.Name = "ScoreboardFrame"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Brightness = 1.2 -- unter der Bloom-Schwelle, damit die Tafel nicht überstrahlt
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(6, 10, 22)
	text.RichText = true
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = gui
	local function refresh()
		local t = state:GetAttribute("TimeLeft") or 0
		text.Text = string.format('<font color="#ff5a5a">ROT</font> %d : %d <font color="#6fb4ff">BLAU</font>\n<font size="40" color="#28d2ff">SPECTRA DOME  %d:%02d</font>',
			state:GetAttribute("RedScore") or 0, state:GetAttribute("BlueScore") or 0, t // 60, t % 60)
	end
	state.AttributeChanged:Connect(refresh)
	refresh()

	Dome.buildScreen(dome, gy, state)
	dome.Parent = root
	return dome
end

return Dome
]==] sd.Parent = s
local sc = Instance.new("ModuleScript") sc.Name = "City" sc.Source = [==[-- UltimatePitch · ULTIMATE CITY, erster Bezirk (ModuleScript unter UltimatePitchServer)
-- Prozedural aus Roblox-Grundteilen, keine externen Assets: Plaza mit Spawn, Stadionzugang zum SPECTRA DOME,
-- Umfeld des Bolzplatzes (Käfig, Stufen, Flutlicht) und drei Ladenfronten als Ausblick. Die Beitritts-Pads
-- werden hier nur gebaut; die Anmeldung selbst entscheidet der Server (siehe Server-Skript).
local City = {}

local ASPHALT = Color3.fromRGB(46, 50, 58)
local PAVING = Color3.fromRGB(150, 154, 164)
local PAVING_DARK = Color3.fromRGB(96, 100, 112)
local STEEL = Color3.fromRGB(70, 78, 96)
local CYAN = Color3.fromRGB(40, 210, 255)
local GOLD = Color3.fromRGB(255, 200, 60)
local RED = Color3.fromRGB(215, 40, 55)
local BLUE = Color3.fromRGB(40, 100, 255)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

local function deco(props, parent)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return part(props, parent)
end

-- Beschriftung auf einer Teilefläche
local function sign(p, face, text, color, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = bg or Color3.fromRGB(10, 14, 24)
	l.BorderSizePixel = 0
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	pad.Parent = l
	return l
end

local function tree(pos, parent)
	part({ Name = "Trunk", Size = Vector3.new(1.6, 8, 1.6), Position = pos + Vector3.new(0, 4, 0),
		Material = Enum.Material.Wood, Color = Color3.fromRGB(92, 64, 44) }, parent)
	deco({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 10, 10), Position = pos + Vector3.new(0, 11, 0),
		Material = Enum.Material.Grass, Color = Color3.fromRGB(52, 128, 62) }, parent)
	deco({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), Position = pos + Vector3.new(2.5, 14, 1),
		Material = Enum.Material.Grass, Color = Color3.fromRGB(64, 146, 70) }, parent)
	part({ Name = "Planter", Size = Vector3.new(5, 1, 5), Position = pos + Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Concrete, Color = PAVING_DARK }, parent)
end

local function lamp(pos, parent)
	part({ Name = "LampPole", Size = Vector3.new(0.6, 14, 0.6), Position = pos + Vector3.new(0, 7, 0),
		Material = Enum.Material.Metal, Color = STEEL }, parent)
	local head = deco({ Name = "LampHead", Size = Vector3.new(2.4, 0.6, 2.4), Position = pos + Vector3.new(0, 14.2, 0),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 244, 214) }, parent)
	local light = Instance.new("PointLight")
	light.Range = 28
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Parent = head
end

local function bench(pos, yaw, parent)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part({ Name = "BenchSeat", Size = Vector3.new(7, 0.5, 2), CFrame = cf * CFrame.new(0, 1.6, 0),
		Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(140, 100, 66) }, parent)
	part({ Name = "BenchBack", Size = Vector3.new(7, 1.8, 0.4), CFrame = cf * CFrame.new(0, 2.7, 0.9),
		Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(140, 100, 66) }, parent)
	for _, x in ipairs({ -3, 3 }) do
		part({ Name = "BenchLeg", Size = Vector3.new(0.4, 1.4, 1.8), CFrame = cf * CFrame.new(x, 0.7, 0),
			Material = Enum.Material.Metal, Color = STEEL }, parent)
	end
end

-- Beitritts-Pad: leuchtende Platte mit Schild; die Berührung wertet der Server aus
local function joinPad(name, pos, color, title, subtitle, parent)
	local pad = part({ Name = name, Size = Vector3.new(10, 0.4, 10), Position = pos,
		Material = Enum.Material.Neon, Color = color }, parent)
	deco({ Name = name .. "Frame", Size = Vector3.new(11.2, 0.3, 11.2), Position = pos - Vector3.new(0, 0.1, 0),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(16, 20, 30) }, parent)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadLabel"
	bb.Size = UDim2.fromOffset(280, 78)
	bb.StudsOffset = Vector3.new(0, 8, 0)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Parent = pad
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0.58, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = title
	t.Parent = bg
	local s = Instance.new("TextLabel")
	s.Position = UDim2.fromScale(0, 0.58)
	s.Size = UDim2.new(1, 0, 0.36, 0)
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.GothamBold
	s.TextScaled = true
	s.TextColor3 = Color3.new(1, 1, 1)
	s.Text = subtitle
	s.Parent = bg
	return pad
end

-- L = { groundY, plaza = Vector3, stadiumPad = Vector3, courtPad = Vector3,
--       court = { origin = Vector3, halfLength, halfWidth } }
function City.build(parent, L)
	local city = Instance.new("Folder")
	city.Name = "City"
	local gy = L.groundY
	local function G(x, y, z) return Vector3.new(x, gy + y, z) end
	local px, pz = L.plaza.X, L.plaza.Z

	-- Boden des Bezirks (knapp unter Rasen-/Platzhöhe, damit nichts flimmert) und Plaza-Pflaster
	part({ Name = "DistrictGround", Size = Vector3.new(340, 1, 226), Position = G(40, -0.55, -241),
		Material = Enum.Material.Asphalt, Color = ASPHALT }, city)
	part({ Name = "Plaza", Size = Vector3.new(110, 0.2, 84), Position = G(px, 0.02, pz),
		Material = Enum.Material.Slate, Color = PAVING }, city)
	for i = -2, 2 do
		deco({ Name = "PlazaBand", Size = Vector3.new(110, 0.05, 1.2), Position = G(px, 0.14, pz + i * 16),
			Material = Enum.Material.Slate, Color = PAVING_DARK }, city)
	end
	-- Mittelpunkt: Emblem-Scheibe mit Leuchtring
	deco({ Name = "EmblemRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 30, 30),
		CFrame = CFrame.new(G(px, 0.16, pz)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Neon, Color = CYAN }, city)
	local emblem = part({ Name = "Emblem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 27, 27),
		CFrame = CFrame.new(G(px, 0.2, pz)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Slate, Color = Color3.fromRGB(18, 24, 40) }, city)
	sign(part({ Name = "EmblemText", Size = Vector3.new(16, 0.1, 9), Position = G(px, 0.4, pz), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false }, city), Enum.NormalId.Top, "ULTIMATE CITY", CYAN).BackgroundTransparency = 1
	emblem.CastShadow = false

	-- Spawn auf der Plaza (einziger Standard-Spawn der Welt)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CitySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 0.4, 10)
	spawn.Position = G(px, 0.25, pz - 26)
	spawn.Material = Enum.Material.Slate
	spawn.Color = PAVING_DARK
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = city

	-- Bäume, Laternen, Bänke rund um die Plaza
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			tree(G(px + sx * 50, 0, pz - 30 + i * 30), city)
			lamp(G(px + sx * 40, 0, pz - 36 + i * 36), city)
		end
		bench(G(px + sx * 30, 0, pz - 18), sx * math.pi / 2, city)
		bench(G(px + sx * 30, 0, pz + 18), sx * math.pi / 2, city)
	end

	-- Stadionzugang: Weg von der Plaza, Torbogen mit Schild, Beitritts-Pad davor
	local sp = L.stadiumPad
	part({ Name = "StadiumWalk", Size = Vector3.new(26, 0.2, math.abs(sp.Z - 14 - (pz + 42)) + 30), Position = G(sp.X, 0.03, (sp.Z + 14 + pz + 42) / 2),
		Material = Enum.Material.Slate, Color = PAVING }, city)
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "GatePylon", Size = Vector3.new(4, 26, 4), Position = G(sp.X + sx * 15, 13, sp.Z + 12),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(20, 24, 36) }, city)
		deco({ Name = "GateLED", Size = Vector3.new(0.4, 24, 0.4), Position = G(sp.X + sx * 15, 13, sp.Z + 9.8),
			Material = Enum.Material.Neon, Color = CYAN }, city)
	end
	local header = part({ Name = "GateHeader", Size = Vector3.new(38, 7, 3), Position = G(sp.X, 24, sp.Z + 12),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 14, 24) }, city)
	sign(header, Enum.NormalId.Front, "SPECTRA DOME", CYAN)
	local pads = {}
	pads.Stadium = joinPad("PadStadium", sp, CYAN, "SPECTRA DOME", "5 gegen 5  ·  Pad betreten", city)

	-- Bolzplatz-Umfeld: Käfig um das Feld der Arena, Stufen, Flutlicht, Schild, Beitritts-Pad
	local c = L.court
	local ox, oz, hl, hw = c.origin.X, c.origin.Z, c.halfLength, c.halfWidth
	local cage = Instance.new("Folder")
	cage.Name = "StreetCourt"
	cage.Parent = city
	local function post(x, z)
		deco({ Name = "CagePost", Size = Vector3.new(0.5, 12, 0.5), Position = G(x, 6, z), Material = Enum.Material.Metal, Color = STEEL }, cage)
	end
	for i = 0, 6 do
		local x = ox - hl - 1 + i * (hl * 2 + 2) / 6
		post(x, oz - hw - 1); post(x, oz + hw + 1)
	end
	for i = 1, 3 do
		local z = oz - hw - 1 + i * (hw * 2 + 2) / 4
		post(ox - hl - 1, z); post(ox + hl + 1, z)
	end
	for _, y in ipairs({ 4, 8, 12 }) do
		for _, sz in ipairs({ -1, 1 }) do
			deco({ Name = "CageRail", Size = Vector3.new(hl * 2 + 2.5, 0.3, 0.3), Position = G(ox, y, oz + sz * (hw + 1)),
				Material = Enum.Material.Metal, Color = STEEL }, cage)
		end
		for _, sx in ipairs({ -1, 1 }) do
			deco({ Name = "CageRail", Size = Vector3.new(0.3, 0.3, hw * 2 + 2.5), Position = G(ox + sx * (hl + 1), y, oz),
				Material = Enum.Material.Metal, Color = STEEL }, cage)
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		deco({ Name = "CageMesh", Size = Vector3.new(hl * 2 + 2, 12, 0.1), Position = G(ox, 6, oz + sz * (hw + 1)),
			Material = Enum.Material.DiamondPlate, Color = STEEL, Transparency = 0.82 }, cage)
	end
	-- Stufen hinter der Nordseite und Farbakzente der Teams an den Toren
	for i = 1, 3 do
		part({ Name = "Step", Size = Vector3.new(hl * 1.4, 1.2, 3), Position = G(ox, 0.6 + (i - 1) * 1.2, oz - hw - 3 - i * 3),
			Material = Enum.Material.Concrete, Color = PAVING_DARK }, cage)
	end
	deco({ Name = "GoalGlowRot", Size = Vector3.new(0.4, 0.3, 14), Position = G(ox - hl - 6.4, 0.2, oz), Material = Enum.Material.Neon, Color = RED }, cage)
	deco({ Name = "GoalGlowBlau", Size = Vector3.new(0.4, 0.3, 14), Position = G(ox + hl + 6.4, 0.2, oz), Material = Enum.Material.Neon, Color = BLUE }, cage)
	for _, sx in ipairs({ -1, 1 }) do
		local base = G(ox + sx * (hl + 5), 0, oz + hw + 5)
		part({ Name = "CourtLightPole", Size = Vector3.new(0.8, 22, 0.8), Position = base + Vector3.new(0, 11, 0), Material = Enum.Material.Metal, Color = STEEL }, cage)
		local head = deco({ Name = "CourtLight", Size = Vector3.new(5, 1, 2.4),
			CFrame = CFrame.lookAt(base + Vector3.new(0, 22, 0), G(ox, 0, oz)), Material = Enum.Material.Neon, Color = Color3.fromRGB(240, 248, 255) }, cage)
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Front
		sl.Range = 60
		sl.Angle = 80
		sl.Brightness = 1.2
		sl.Parent = head
	end
	local board = part({ Name = "CourtSign", Size = Vector3.new(26, 5, 0.6), Position = G(ox, 15, oz + hw + 1.4),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 14, 24) }, cage)
	sign(board, Enum.NormalId.Front, "STREET COURT  ·  3 v 3", GOLD)
	sign(board, Enum.NormalId.Back, "STREET COURT  ·  3 v 3", GOLD)
	pads.StreetCourt = joinPad("PadStreetCourt", L.courtPad, GOLD, "STREET COURT", "3 gegen 3  ·  Pad betreten", city)
	part({ Name = "CourtWalk", Size = Vector3.new(math.abs(L.courtPad.X - (px + 55)) + 12, 0.2, 14), Position = G((L.courtPad.X + px + 55) / 2, 0.03, L.courtPad.Z),
		Material = Enum.Material.Slate, Color = PAVING }, city)

	-- Ladenfronten: Fashion District ist seit M3 geöffnet (Theke und Shop im Career-Modul), die anderen folgen
	local SHOPS = { { "FASHION DISTRICT", Color3.fromRGB(255, 90, 170) }, { "FOOTBALL ACADEMY", Color3.fromRGB(70, 255, 150) }, { "PLAYER AGENCY", GOLD } }
	for i, shop in ipairs(SHOPS) do
		local x = px - 56 + (i - 1) * 56
		local z = pz - 42 - 22
		part({ Name = "ShopBody", Size = Vector3.new(48, 34, 26), Position = G(x, 17, z),
			Material = Enum.Material.Concrete, Color = Color3.fromRGB(34 + i * 6, 38 + i * 6, 52 + i * 6) }, city)
		deco({ Name = "ShopWindow", Size = Vector3.new(36, 12, 0.3), Position = G(x, 8, z + 13.1),
			Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 200, 255), Transparency = 0.35 }, city)
		deco({ Name = "ShopTrim", Size = Vector3.new(48.4, 0.6, 0.6), Position = G(x, 16, z + 13.2), Material = Enum.Material.Neon, Color = shop[2] }, city)
		local sb = part({ Name = "ShopSign", Size = Vector3.new(40, 6, 0.6), Position = G(x, 21, z + 13.4),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 14, 24) }, city)
		sign(sb, Enum.NormalId.Back, shop[1], shop[2])
		local open = i == 1
		local soon = part({ Name = "ShopSoon", Size = Vector3.new(16, 2.4, 0.4), Position = G(x, open and 6 or 3.4, z + 13.5),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 14, 24) }, city)
		sign(soon, Enum.NormalId.Back, open and "JETZT GEÖFFNET" or "ERÖFFNET BALD", open and shop[2] or Color3.new(1, 1, 1))
	end

	city.Parent = parent
	return { folder = city, pads = pads, spawn = spawn }
end

return City
]==] sc.Parent = s
local sk = Instance.new("ModuleScript") sk.Name = "Career" sk.Source = [==[-- UltimatePitch · Karriere, Pitch Coins, Scout und Shop (ModuleScript unter UltimatePitchServer)
-- Alles serverseitig: Coins, Karrierestufe, Besitz und Ausrüstung führt nur der Server und spiegelt sie in
-- Player-Attribute (nur lesend für Clients) und leaderstats. Clients senden über RemoteEvent "Career" lediglich
-- Absichten (Scout-Angebot annehmen, Artikel kaufen/anlegen); jede Absicht wird auf Stufe, Preis, Guthaben,
-- Besitz und Nähe zum NPC/Laden geprüft und gedrosselt.
-- SPEICHERSTAND (freigegeben 10.11.2026): dauerhaft per DataStore "UP_Career_v1" über CareerStore (UpdateAsync mit
-- Sitzungssperre). Laden beim Betreten, Autosave alle 60 s (erneuert zugleich die Sperre), letzter Stand beim Verlassen
-- und beim Herunterfahren. Studio greift nie auf den Live-Datenbestand zu: ohne Attribut "off" (nur diese Sitzung);
-- Workspace-Attribut UP_CareerMemoryStore = true vor dem Start nutzt eine Speicher-Attrappe und legt
-- ServerStorage.UP_CareerTest (BindableFunction) für Prüfungen an; UP_CareerStudioDataStore = true nutzt in einer
-- veröffentlichten Test-Place den getrennten DataStore "UP_Career_v1_STUDIO".
-- Keine Robux, keine Zufallspakete: Coins gibt es nur fürs Spielen.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local CareerStore = require(script.Parent:WaitForChild("CareerStore"))

local Career = {}

local STAGES = { "Street Rookie", "Local Talent", "Scouted Player" }
local REWARD = { match = 10, win = 15, goal = 5, scout = 50 }
-- Shop-Sortiment (reine Optik im Matchtrikot, kein spielerischer Vorteil)
local ITEMS = {
	{ id = "boots_neon", name = "Neon-Schuhe", price = 40, slot = "boots", color = Color3.fromRGB(70, 255, 150) },
	{ id = "armband", name = "Kapitänsbinde", price = 60, slot = "armband", color = Color3.fromRGB(255, 200, 60) },
	{ id = "number_gold", name = "Goldene Rückennummer", price = 80, slot = "number", color = Color3.fromRGB(255, 200, 60) },
	{ id = "boots_gold", name = "Goldene Schuhe", price = 120, slot = "boots", color = Color3.fromRGB(255, 200, 60) },
}
local ITEM = {}
for _, it in ipairs(ITEMS) do ITEM[it.id] = it end
Career.ITEMS = ITEMS
-- Katalog für die Shop-Anzeige (nur Anzeige; Preise und Besitz prüft der Server bei jeder Anfrage)
local CATALOG = {}
for _, it in ipairs(ITEMS) do
	table.insert(CATALOG, { id = it.id, name = it.name, price = it.price, slot = it.slot, color = it.color })
end

local INTERACT_RANGE = 14 -- Studs zwischen Spieler und Scout bzw. Ladentheke
local REQUEST_GAP = 0.3   -- Sekunden zwischen zwei Anfragen eines Spielers

local AUTOSAVE = 60       -- Sekunden zwischen zwei Autosave-Durchläufen; jeder Durchlauf erneuert die Sitzungssperre

-- [Player] = { coins, stage, owned = {id=true}, equipped = {slot=id}, matches, goals,
--              save = "loading"|"ok"|"off"|"error"|"lost", dirty, saving, left, final }
local data = {}
local lastRequest = {}
local remote, scoutRoot, shopRoot
local persist          -- CareerStore-Objekt oder nil (kein Speichern möglich)
local memoryStore      -- nur im Studio-Testmodus
local pending = 0      -- laufende Lade-/Abschlussvorgänge (BindToClose wartet darauf)

local function fresh()
	return { coins = 0, stage = 1, owned = {}, equipped = {}, matches = 0, goals = 0, save = persist and "loading" or "off" }
end

local function list(t)
	local out = {}
	for k, v in pairs(t) do
		if v == true then table.insert(out, k) else table.insert(out, v) end
	end
	table.sort(out)
	return table.concat(out, ",")
end

-- Werte an Attribute/leaderstats spiegeln; jede Änderung markiert den Stand fürs nächste Speichern
local function sync(plr, clean)
	local d = data[plr]
	if not d then return end
	if not clean then d.dirty = true end
	plr:SetAttribute("CareerSave", d.save)
	plr:SetAttribute("PitchCoins", d.coins)
	plr:SetAttribute("CareerStage", STAGES[d.stage])
	plr:SetAttribute("CareerStageIndex", d.stage)
	plr:SetAttribute("CareerOwned", list(d.owned))
	plr:SetAttribute("CareerEquipped", list(d.equipped))
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = d.coins
		ls.Stufe.Value = STAGES[d.stage]
	end
end

local function toast(plr, text)
	if remote and plr.Parent then remote:FireClient(plr, "Toast", text) end
end

local function addCoins(plr, amount, reason)
	local d = data[plr]
	if not d or amount <= 0 then return end
	d.coins += amount
	sync(plr)
	toast(plr, string.format("+%d Pitch Coins  ·  %s", amount, reason))
end

local function near(plr, root)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hrp and hum and hum.Health > 0 and root and (hrp.Position - root.Position).Magnitude <= INTERACT_RANGE
end

-- Matchende (vom Server-Skript je Arena aufgerufen, nur für vollständig gespielte Matches):
-- results = { { player = Player, won = bool, goals = number } }
function Career.onMatchEnd(arenaId, results)
	for _, r in ipairs(results) do
		local plr, d = r.player, data[r.player]
		if d and plr.Parent then
			d.matches += 1
			d.goals += r.goals
			local coins = REWARD.match + (r.won and REWARD.win or 0) + REWARD.goal * math.min(r.goals, 10)
			addCoins(plr, coins, r.won and "Sieg!" or "Match beendet")
			-- Karriere: das erste Street-Court-Match ruft den Scout auf den Plan
			if arenaId == "StreetCourt" and d.stage == 1 then
				d.stage = 2
				sync(plr)
				toast(plr, "Ein Talent-Scout hat dich beobachtet! Sprich mit ihm am Street Court.")
			end
		end
	end
end

-- Optik des Matchtrikots je nach angelegter Ausrüstung (vom Server-Skript in applyKit aufgerufen)
function Career.decorate(char)
	local plr = Players:GetPlayerFromCharacter(char)
	local d = plr and data[plr]
	local old = char:FindFirstChild("UP_Armband", true)
	if old then old:Destroy() end
	if not d then return end
	local boots = d.equipped.boots and ITEM[d.equipped.boots]
	if boots then
		for _, n in ipairs({ "LeftFoot", "RightFoot" }) do
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then p.Color = boots.color end
		end
	end
	if d.equipped.armband then
		local arm = char:FindFirstChild("LeftUpperArm")
		if arm and arm:IsA("BasePart") then
			local band = Instance.new("Part")
			band.Name = "UP_Armband"
			band.Size = Vector3.new(arm.Size.X + 0.08, 0.32, arm.Size.Z + 0.08)
			band.Color = ITEM.armband.color
			band.Material = Enum.Material.SmoothPlastic
			band.CanCollide, band.CanQuery, band.CanTouch, band.Massless = false, false, false, true
			band.CFrame = arm.CFrame * CFrame.new(0, arm.Size.Y * 0.18, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = arm, band
			weld.Parent = band
			band.Parent = arm
		end
	end
	if d.equipped.number then
		local torso = char:FindFirstChild("UpperTorso")
		local gui = torso and torso:FindFirstChild("KitNumber")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label then label.TextColor3 = ITEM.number_gold.color end
	end
end

-- Scout-NPC am Street Court: eigene Figur aus Grundfarben (kein Asset), ProximityPrompt startet das Gespräch
local function buildScout(parent, pos, facing)
	local model
	pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Color3.fromRGB(198, 140, 100)
		desc.TorsoColor = Color3.fromRGB(28, 34, 52)
		desc.LeftArmColor, desc.RightArmColor = Color3.fromRGB(28, 34, 52), Color3.fromRGB(28, 34, 52)
		desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(46, 52, 70), Color3.fromRGB(46, 52, 70)
		model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not model then return nil end
	model.Name = "TalentScout"
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = "TALENT-SCOUT"
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 60
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	model:PivotTo(CFrame.lookAt(pos, facing))
	model.Parent = parent
	local root = model:FindFirstChild("HumanoidRootPart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sprechen"
	prompt.ObjectText = "Talent-Scout"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(plr)
		local d = data[plr]
		if not d or not near(plr, root) then return end
		if d.stage == 1 then
			toast(plr, "Scout: „Zeig mir erst, was du kannst – spiel ein Match auf dem Street Court.“")
		elseif d.stage == 2 then
			remote:FireClient(plr, "ScoutOffer", REWARD.scout)
		else
			toast(plr, "Scout: „Du bist im Talentprogramm. Weiter so – die Akademie öffnet bald!“")
		end
	end)
	return root
end

-- Ladentheke vor dem Fashion District
local function buildShop(parent, pos)
	local counter = Instance.new("Part")
	counter.Name = "ShopCounter"
	counter.Anchored = true
	counter.Size = Vector3.new(12, 3.4, 3)
	counter.Position = pos + Vector3.new(0, 1.7, 0)
	counter.Material = Enum.Material.SmoothPlastic
	counter.Color = Color3.fromRGB(28, 32, 46)
	counter.Parent = parent
	local top = Instance.new("Part")
	top.Name = "ShopCounterTop"
	top.Anchored, top.CanCollide = true, false
	top.Size = Vector3.new(12.4, 0.3, 3.4)
	top.Position = pos + Vector3.new(0, 3.55, 0)
	top.Material = Enum.Material.Neon
	top.Color = Color3.fromRGB(255, 90, 170)
	top.Parent = parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop öffnen"
	prompt.ObjectText = "Fashion District"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(function(plr)
		if data[plr] and near(plr, counter) then remote:FireClient(plr, "OpenShop", CATALOG) end
	end)
	return counter
end

local function onRequest(plr, kind, arg)
	local d = data[plr]
	if not d or type(kind) ~= "string" then return end
	local now = os.clock()
	if (lastRequest[plr] or 0) + REQUEST_GAP > now then return end
	lastRequest[plr] = now
	if d.save == "loading" or d.left then
		-- erst nach dem Laden handeln, sonst würde der geladene Stand Käufe dieser Sekunden überschreiben
		toast(plr, "Dein Spielstand wird noch geladen …")
		return
	end
	if kind == "AcceptScout" then
		if d.stage ~= 2 or not near(plr, scoutRoot) then return end
		d.stage = 3
		sync(plr)
		addCoins(plr, REWARD.scout, "Talentvertrag unterschrieben")
		toast(plr, "Neue Stufe: SCOUTED PLAYER! Gönn dir etwas im Fashion District.")
	elseif kind == "Buy" then
		local it = type(arg) == "string" and ITEM[arg]
		if not it or d.owned[it.id] or not near(plr, shopRoot) then return end
		if d.coins < it.price then
			toast(plr, string.format("Dir fehlen noch %d Pitch Coins.", it.price - d.coins))
			return
		end
		d.coins -= it.price
		d.owned[it.id] = true
		d.equipped[it.slot] = it.id
		sync(plr)
		toast(plr, it.name .. " gekauft und angelegt – zu sehen im nächsten Match.")
	elseif kind == "Equip" then
		local it = type(arg) == "string" and ITEM[arg]
		if not it or not d.owned[it.id] or not near(plr, shopRoot) then return end
		if d.equipped[it.slot] == it.id then d.equipped[it.slot] = nil else d.equipped[it.slot] = it.id end
		sync(plr)
	end
end

---------------------------------------------------------------- Speicherstand
local SAVE_MSG = {
	error = "Dein Spielstand konnte gerade nicht geladen werden. Fortschritt dieser Sitzung wird nicht gespeichert – bitte später neu beitreten.",
	lost = "Dein Spielstand wird inzwischen von einem anderen Server geführt. Fortschritt hier wird nicht mehr gespeichert.",
}

local function setSave(plr, d, state)
	d.save = state
	if plr.Parent then plr:SetAttribute("CareerSave", state) end
	if SAVE_MSG[state] then toast(plr, SAVE_MSG[state]) end
end

-- Laden beim Betreten. Was in den Sekunden davor verdient wurde (Matchende), wird zum geladenen Stand addiert.
local function loadPlayer(plr, d)
	pending += 1
	local status, loaded, token = persist.load(plr.UserId, function()
		-- wird nur aufgerufen, wenn das Laden länger dauert (fremde Sperre beim Serverwechsel oder Störung)
		if not d.waitNotified then
			d.waitNotified = true
			toast(plr, "Dein Spielstand wird geladen – das dauert gerade etwas länger. Käufe sind gleich wieder möglich.")
		end
		return d.left
	end)
	if status == "cancelled" then
		pending -= 1
		return
	end
	if status ~= "ok" then
		warn("[Career] Laden fehlgeschlagen für " .. plr.UserId .. ": " .. tostring(loaded))
		setSave(plr, d, "error")
		pending -= 1
		return
	end
	loaded.coins = math.min(loaded.coins + d.coins, CareerStore.MAX_COINS)
	loaded.matches += d.matches
	loaded.goals += d.goals
	loaded.stage = math.max(loaded.stage, d.stage)
	local earned = d.coins > 0 or d.matches > 0 or d.stage > 1
	d.coins, d.stage, d.owned, d.equipped = loaded.coins, loaded.stage, loaded.owned, loaded.equipped
	d.matches, d.goals = loaded.matches, loaded.goals
	d.token = token
	d.save = "ok"
	if d.left then
		-- während des Ladens gegangen: Stand sofort zurückschreiben und Sperre freigeben
		persist.save(plr.UserId, d, d.token, true)
	else
		sync(plr, true)
		d.dirty = earned
	end
	pending -= 1
end

-- Ein Speicherdurchlauf für einen Spieler (nicht während eines anderen Speichervorgangs desselben Spielers)
local function saveNow(plr, d, release)
	while d.saving do task.wait(0.1) end
	-- nach dem letzten Speichern (Sperre freigegeben) darf kein Zwischenstand die Sperre neu setzen
	if d.save ~= "ok" or (d.final and not release) then return end
	d.saving = true
	d.dirty = false
	local status, err = persist.save(plr.UserId, d, d.token, release)
	d.saving = false
	if status == "lost" then
		setSave(plr, d, "lost")
	elseif status ~= "ok" then
		d.dirty = true
		warn("[Career] Speichern fehlgeschlagen für " .. plr.UserId .. ": " .. tostring(err))
	end
	return status
end

-- Letztes Speichern beim Verlassen oder Herunterfahren (genau einmal je Spieler, gibt die Sperre frei)
local function finalSave(plr, d)
	if d.final then return end
	d.final, d.left = true, true
	pending += 1
	if persist and d.save == "ok" then saveNow(plr, d, true) end
	if data[plr] == d then data[plr] = nil end
	lastRequest[plr] = nil
	pending -= 1
end

local function autosaveLoop()
	while true do
		task.wait(AUTOSAVE)
		for plr, d in pairs(data) do
			-- auch unveränderte Stände speichern: nur so bleibt die Sitzungssperre frisch
			if d.save == "ok" and not d.left and not d.saving then
				task.spawn(saveNow, plr, d, false)
				task.wait(0.5) -- Anfragen verteilen
			end
		end
	end
end

-- Studio-Testmodus: Prüfschnittstelle auf die Speicher-Attrappe (nur Server, nur mit UP_CareerMemoryStore)
local function testHook()
	local fn = Instance.new("BindableFunction")
	fn.Name = "UP_CareerTest"
	fn.OnInvoke = function(cmd, userId, arg)
		local plr = userId and Players:GetPlayerByUserId(userId)
		if cmd == "read" then
			return HttpService:JSONEncode(memoryStore:read(CareerStore.key(userId)) or {})
		elseif cmd == "write" then
			memoryStore:write(CareerStore.key(userId), HttpService:JSONDecode(arg))
			return true
		elseif cmd == "fail" then
			memoryStore.failNext = arg
			return true
		elseif cmd == "flush" then
			local n = 0
			for p, d in pairs(data) do
				if d.save == "ok" and not d.left then saveNow(p, d, false) n += 1 end
			end
			return n
		elseif cmd == "rejoin" and plr and data[plr] then
			-- Verlassen und erneutes Betreten desselben Spielers nachstellen (gleiche Funktionen wie im Spiel);
			-- arg (JSON) ersetzt dazwischen den gespeicherten Stand, z. B. einen älteren oder beschädigten Datensatz
			finalSave(plr, data[plr])
			if arg then memoryStore:write(CareerStore.key(userId), HttpService:JSONDecode(arg)) end
			local d = fresh()
			data[plr] = d
			sync(plr, true)
			loadPlayer(plr, d)
			return d.save .. " coins=" .. d.coins .. " stage=" .. d.stage
		end
		return nil
	end
	fn.Parent = ServerStorage
end

local function onPlayer(plr)
	local d = fresh()
	data[plr] = d
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = ls
	local stage = Instance.new("StringValue")
	stage.Name = "Stufe"
	stage.Parent = ls
	ls.Parent = plr
	sync(plr, true)
	if persist then task.spawn(loadPlayer, plr, d) end
end

-- L = LAYOUT aus dem Server-Skript (Plaza, Court), cityFolder = workspace.UltimatePitch.City
function Career.init(cityFolder, L)
	local shared = RS:WaitForChild("UltimatePitch")
	remote = Instance.new("RemoteEvent")
	remote.Name = "Career"
	remote.Parent = shared
	local gy = L.groundY
	local court = L.court
	-- Scout steht an der Plaza-Seite des Street Court, Blick zur Plaza
	local scoutPos = Vector3.new(court.origin.X - court.halfLength - 14, gy + 3, court.origin.Z + court.halfWidth + 6)
	scoutRoot = buildScout(cityFolder, scoutPos, Vector3.new(L.plaza.X, gy + 3, L.plaza.Z))
	-- Theke vor dem Fashion District (erste Ladenfront links)
	shopRoot = buildShop(cityFolder, Vector3.new(L.plaza.X - 56, gy, L.plaza.Z - 42 - 22 + 18))
	-- Speicher wählen. Live-Server einer veröffentlichten Place: DataStore "UP_Career_v1". Studio nie den Live-Bestand:
	-- Attrappe (UP_CareerMemoryStore), getrennter Studio-DataStore (UP_CareerStudioDataStore) oder kein Speichern.
	local storeObj, storeName
	if RunService:IsStudio() then
		if workspace:GetAttribute("UP_CareerMemoryStore") == true then
			memoryStore = CareerStore.memory()
			storeObj = memoryStore
		elseif workspace:GetAttribute("UP_CareerStudioDataStore") == true and game.PlaceId ~= 0 then
			storeName = "UP_Career_v1_STUDIO"
		end
	elseif game.PlaceId ~= 0 then
		storeName = "UP_Career_v1"
	end
	if storeName then
		local ok, ds = pcall(function() return DataStoreService:GetDataStore(storeName) end)
		if ok then storeObj = ds else warn("[Career] DataStore nicht verfügbar: " .. tostring(ds)) end
	end
	if storeObj then
		persist = CareerStore.new(storeObj, { jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false)),
			items = ITEM, stages = #STAGES })
		task.spawn(autosaveLoop)
		if memoryStore then testHook() end
	end
	print("[Career] Speicherstand: " .. (memoryStore and "Studio-Attrappe" or storeObj and ("DataStore " .. storeName) or "aus (nur diese Sitzung)"))
	remote.OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(plr)
		local d = data[plr]
		if d then finalSave(plr, d) end
	end)
	-- Herunterfahren: alle noch offenen Stände speichern und bis zu 25 s auf laufende Vorgänge warten
	game:BindToClose(function()
		for plr, d in pairs(data) do task.spawn(finalSave, plr, d) end
		local t0 = os.clock()
		task.wait()
		while pending > 0 and os.clock() - t0 < 25 do task.wait(0.2) end
	end)
end

return Career
]==] sk.Parent = s
local sp = Instance.new("ModuleScript") sp.Name = "CareerStore" sp.Source = [==[-- UltimatePitch · dauerhafter Karriere-Speicherstand (ModuleScript unter UltimatePitchServer, nur Server)
-- Ein Datensatz je Spieler (Schlüssel "u_<UserId>") mit Coins, Stufe, Besitz, Ausrüstung und Statistik.
-- Alle Zugriffe laufen über UpdateAsync mit einer Sitzungssperre (lock = { job = JobId, sid = Ladekennung, t = os.time() }):
--   * Laden sperrt den Datensatz für genau diesen Ladevorgang. Ist eine Sperre noch frisch (ein anderer Server spielt
--     oder speichert gerade beim Serverwechsel), wird gewartet, bis sie freigegeben wird oder abläuft – nie übernommen.
--   * Der haltende Server erneuert seine Sperre mit jedem Autosave (Aufrufer: regelmäßig, auch ohne Änderungen);
--     eine Sperre älter als LOCK_TIMEOUT stammt von einem abgestürzten Server und darf übernommen werden.
--   * Speichern schreibt nur, solange genau die eigene Sperre im Datensatz steht; sonst "lost".
--   * Verlassen speichert ein letztes Mal und gibt die Sperre frei.
-- Schlägt das Laden fehl, liefert load "error": Der Aufrufer speichert dann für diesen Spieler nichts, damit ein
-- vorhandener Spielstand nicht durch einen leeren überschrieben wird.
local HttpService = game:GetService("HttpService")

local CareerStore = {}
CareerStore.SCHEMA = 1
CareerStore.LOCK_TIMEOUT = 300 -- Sekunden, danach gilt eine fremde Sperre als verwaist
CareerStore.MAX_COINS = 10000000

local function key(userId)
	return "u_" .. tostring(userId)
end
CareerStore.key = key

-- Gespeicherte Rohdaten in einen gültigen Spielstand überführen: falsche Typen, unbekannte Artikel, Ausrüstung
-- ohne Besitz oder im falschen Platz und Ausreißer werden verworfen bzw. begrenzt.
function CareerStore.sanitize(raw, items, stageCount)
	local d = { coins = 0, stage = 1, owned = {}, equipped = {}, matches = 0, goals = 0 }
	if type(raw) ~= "table" then return d end
	local function int(v, lo, hi)
		if type(v) ~= "number" or v ~= v then return lo end
		return math.clamp(math.floor(v), lo, hi)
	end
	d.coins = int(raw.coins, 0, CareerStore.MAX_COINS)
	d.stage = int(raw.stage, 1, stageCount)
	d.matches = int(raw.matches, 0, 1e9)
	d.goals = int(raw.goals, 0, 1e9)
	if type(raw.owned) == "table" then
		for _, id in ipairs(raw.owned) do
			if type(id) == "string" and items[id] then d.owned[id] = true end
		end
	end
	if type(raw.equipped) == "table" then
		for slot, id in pairs(raw.equipped) do
			local it = type(id) == "string" and items[id]
			if it and d.owned[id] and it.slot == slot then d.equipped[slot] = id end
		end
	end
	return d
end

function CareerStore.serialize(d)
	local owned = {}
	for id in pairs(d.owned) do table.insert(owned, id) end
	table.sort(owned)
	local equipped = {}
	for slot, id in pairs(d.equipped) do equipped[slot] = id end
	return { schema = CareerStore.SCHEMA, coins = d.coins, stage = d.stage, owned = owned, equipped = equipped,
		matches = d.matches, goals = d.goals }
end

-- store: DataStore oder CareerStore.memory()
-- opts = { jobId, items, stages, now?, wait?, newToken?, retries?, lockWait?, maxLockWait? }
function CareerStore.new(store, opts)
	local self = {}
	local jobId = opts.jobId
	local now = opts.now or os.time
	local wait = opts.wait or task.wait
	local newToken = opts.newToken or function() return HttpService:GenerateGUID(false) end
	local retries = opts.retries or 4 -- Fehlversuche (Netz/Budget) bis "error"
	local lockWait = opts.lockWait or 5 -- Sekunden zwischen zwei Versuchen bei fremder Sperre
	-- so lange höchstens auf eine fremde, frische Sperre warten (sie läuft spätestens nach LOCK_TIMEOUT ab, weil
	-- der haltende Server sie nur durch regelmäßiges Speichern erneuert); danach "error" statt Übernahme
	local maxLockWait = opts.maxLockWait or (CareerStore.LOCK_TIMEOUT + 30)

	-- Sperre eines anderen Ladevorgangs (anderer Server oder früherer Beitritt), die noch nicht abgelaufen ist
	local function freshLock(old)
		local lock = type(old) == "table" and old.lock
		return type(lock) == "table" and type(lock.t) == "number" and now() - lock.t < CareerStore.LOCK_TIMEOUT
	end

	-- Lädt und sperrt. Jeder Ladevorgang erhält eine eigene Kennung (token); nur mit ihr darf später gespeichert
	-- werden. Eine frische Sperre wird nie übernommen, nur eine freigegebene oder abgelaufene.
	-- cancelled(): optional, bricht das Warten ab (Spieler hat das Spiel verlassen).
	-- Rückgabe: "ok", data, token | "error", Meldung | "cancelled"
	function self.load(userId, cancelled)
		local errors, waited = 0, 0
		local token = newToken()
		while true do
			local blocked, newer, raw = false, false, nil
			local ok, err = pcall(function()
				store:UpdateAsync(key(userId), function(old)
					blocked, newer, raw = false, false, old
					if type(old) == "table" and type(old.schema) == "number" and old.schema > CareerStore.SCHEMA then
						newer = true -- von einer neueren Spielversion geschrieben: nicht anfassen
						return nil
					end
					if freshLock(old) then
						blocked = true
						return nil
					end
					local rec = type(old) == "table" and old or {}
					rec.lock = { job = jobId, sid = token, t = now() }
					return rec, { userId }
				end)
			end)
			if ok and newer then return "error", "Spielstand stammt aus einer neueren Version" end
			if ok and not blocked then return "ok", CareerStore.sanitize(raw, opts.items, opts.stages), token end
			if cancelled and cancelled() then return "cancelled" end
			if ok then
				if waited >= maxLockWait then return "error", "Spielstand wird noch von einem anderen Server gehalten" end
				waited += lockWait
				wait(lockWait)
			else
				errors += 1
				if errors >= retries then return "error", tostring(err) end
				wait(2 ^ errors)
			end
		end
	end

	-- Speichert; schreibt nur, wenn der Datensatz noch genau mit der Sperre dieses Ladevorgangs (token) belegt ist.
	-- Eine fehlende oder fremde Sperre bedeutet: ein anderer Server hat übernommen (und ggf. schon freigegeben).
	-- release = Sperre freigeben (letztes Speichern). Rückgabe: "ok" | "lost" | "error", Meldung
	function self.save(userId, data, token, release)
		local errors = 0
		while true do
			local lost = false
			local ok, err = pcall(function()
				store:UpdateAsync(key(userId), function(old)
					lost = false
					local lock = type(old) == "table" and old.lock
					if type(lock) ~= "table" or lock.sid ~= token or lock.job ~= jobId then
						lost = true
						return nil
					end
					local rec = CareerStore.serialize(data)
					if not release then rec.lock = { job = jobId, sid = token, t = now() } end
					return rec, { userId }
				end)
			end)
			if ok then return lost and "lost" or "ok" end
			errors += 1
			if errors >= retries then return "error", tostring(err) end
			wait(2 ^ errors)
		end
	end

	return self
end

-- Speicher-Attrappe mit derselben UpdateAsync-Schnittstelle: Werte werden wie im echten Store als JSON abgelegt.
-- failNext = n lässt die nächsten n Zugriffe mit einem Fehler scheitern. Für Selbsttests und den Studio-Testmodus.
function CareerStore.memory()
	local m = { data = {}, failNext = 0, calls = 0 }
	function m:UpdateAsync(k, fn)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("simulierter DataStore-Fehler")
		end
		local old = self.data[k] and HttpService:JSONDecode(self.data[k]) or nil
		local new = fn(old)
		if new ~= nil then self.data[k] = HttpService:JSONEncode(new) end
		return new
	end
	function m:read(k)
		return self.data[k] and HttpService:JSONDecode(self.data[k]) or nil
	end
	function m:write(k, v)
		self.data[k] = HttpService:JSONEncode(v)
	end
	return m
end

return CareerStore
]==] sp.Parent = s
local c = Instance.new("LocalScript") c.Name = "UltimatePitchClient" c.Source = [==[-- UltimatePitch v0.5 · Client (HUD, Eingaben, Effekte, Sound, Grafikprofile).
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
-- Arena-Sicht (M2): Der Client folgt der Arena, für die der Server den Spieler angemeldet hat (Player-Attribut
-- UP_Arena). `State` ist eine lokale Kopie des Zustands dieser Arena; HUD, Effekte und Matchday lesen nur sie.
-- Ohne Anmeldung gilt Phase "Free" (freies Herumlaufen in der Stadt). GoalSeq und MessageId sind lokale Zähler,
-- die nur bei echten Ereignissen steigen – ein Arenawechsel löst also weder Torjubel noch alte Meldungen aus.
local StadiumState = SHARED:WaitForChild("State")
local State = Instance.new("Folder")
State.Name = "UP_ViewState"
local carrierView = Instance.new("ObjectValue")
carrierView.Name = "BallCarrier"
carrierView.Parent = State
local VIEW_DEFAULTS = { Phase = "Free", RedScore = 0, BlueScore = 0, TimeLeft = 0, Message = "", LastGoalTeam = "", LastGoalAurora = false,
	BallOwner = 0, ArenaId = "", Origin = Vector3.zero, HalfLength = 80, HalfWidth = 50, GoalHalfWidth = 12 }
for k, v in pairs(VIEW_DEFAULTS) do State:SetAttribute(k, v) end
State:SetAttribute("GoalSeq", 0)
State:SetAttribute("MessageId", 0)
local function arenaRoot(id)
	local base = workspace:FindFirstChild("UltimatePitch")
	if not base or id == "Stadium" then return base end
	local arenas = base:FindFirstChild("Arenas")
	return arenas and arenas:FindFirstChild(id)
end
local function ballOf(id)
	local root = arenaRoot(type(id) == "string" and id or "Stadium")
	return root and root:FindFirstChild("Ball")
end
local function sourceState(id)
	if id == "Stadium" then return StadiumState end
	local arenas = SHARED:FindFirstChild("Arenas")
	local folder = arenas and arenas:FindFirstChild(id)
	return folder and folder:FindFirstChild("State")
end
local viewConns = {}
local bindGen = 0
local function bindArena(id)
	bindGen += 1
	local myGen = bindGen
	for _, c in ipairs(viewConns) do c:Disconnect() end
	table.clear(viewConns)
	local wanted = type(id) == "string" and id ~= ""
	local src = wanted and sourceState(id) or nil
	if not src then
		for k, v in pairs(VIEW_DEFAULTS) do State:SetAttribute(k, v) end
		carrierView.Value = nil
		if wanted then
			-- Zustand der Arena ist noch nicht repliziert (Reihenfolge nicht garantiert): nachträglich binden,
			-- sofern inzwischen kein anderer Wechsel/Verlassen stattgefunden hat (Generation)
			task.spawn(function()
				local t0 = os.clock()
				while myGen == bindGen and os.clock() - t0 < 30 do
					task.wait(0.25)
					if myGen == bindGen and sourceState(id) then bindArena(id) return end
				end
			end)
		end
		return
	end
	local srcGoal, srcMsg = src:GetAttribute("GoalSeq") or 0, src:GetAttribute("MessageId") or 0
	local function copy(name)
		local v = src:GetAttribute(name)
		if name == "GoalSeq" then
			if (v or 0) > srcGoal then State:SetAttribute("GoalSeq", (State:GetAttribute("GoalSeq") or 0) + 1) end
			srcGoal = v or 0
		elseif name == "MessageId" then
			if (v or 0) > srcMsg then State:SetAttribute("MessageId", (State:GetAttribute("MessageId") or 0) + 1) end
			srcMsg = v or 0
		else
			State:SetAttribute(name, v)
		end
	end
	for name in pairs(src:GetAttributes()) do
		if name ~= "GoalSeq" and name ~= "MessageId" then copy(name) end
	end
	table.insert(viewConns, src.AttributeChanged:Connect(copy))
	local carrier = src:FindFirstChild("BallCarrier")
	if carrier then
		carrierView.Value = carrier.Value
		table.insert(viewConns, carrier.Changed:Connect(function(model) carrierView.Value = model end))
	end
end
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
local PHASE_TEXT = { Lobby = "LOBBY · WARTE AUF SPIELER", Playing = "LIVE", GoldenGoal = "GOLDEN GOAL",
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
		or "F/Klick halten Schuss · E Pass · Shift Sprint · R AURORA · M Effekte · G Grafik · L Verlassen" })
local gfxLabel = make("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -28), Size = UDim2.fromOffset(240, 14),
	TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.45, Text = "" })

-- Frei in der Stadt (nirgends angemeldet): Match-Anzeigen aus, Hinweis auf die Pads an
local MATCH_HINT = hint.Text
local cityHint = corner(make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(560, 32),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.25, TextSize = 15,
	Text = "ULTIMATE CITY  ·  Betritt ein leuchtendes Pad, um einem Match beizutreten" }), 8)
local function updateFree()
	local free = (State:GetAttribute("Phase") or "Free") == "Free"
	bug.Visible, dock.Visible, cityHint.Visible = not free, not free, free
	hint.Text = free and "SPECTRA DOME: 5 gegen 5  ·  STREET COURT: 3 gegen 3  ·  G Grafik" or MATCH_HINT
end
State:GetAttributeChangedSignal("Phase"):Connect(updateFree)
updateFree()

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
local inDome = false -- vom Zonenlicht gesetzt: Stadionatmosphäre gibt es nur im Stadion
local function ambienceLevel()
	local ph = State:GetAttribute("Phase") or "Lobby"
	local target = (ph == "Playing" or ph == "GoldenGoal" or ph == "Goal") and 0.45 or 0.2
	if not inDome then target = 0 end
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
Effect.OnClientEvent:Connect(function(kind, userId, arg, arenaId)
	if type(userId) ~= "number" then return end
	local ball = ballOf(arenaId) -- Ball der Arena, in der die Aktion stattfindet
	if kind == "AuroraWindup" then AuroraFX.windup(userId, tonumber(arg) or 0.3, ball)
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
	-- die Atmosphären-Dichte setzt das Zonenlicht (unten) passend zum Profil
	AuroraFX.fxScale = name == "Niedrig" and 0.5 or 1
	gfxLabel.Text = "GRAFIK: " .. string.upper(name) .. (touchOnly and "" or "  (G)")
end
-- Matchday-Atmosphäre: Anstoß-Intro und Torjubel im Stadion (rein optisch, siehe Matchday.lua)
local Matchday = require(script:WaitForChild("Matchday"))
Matchday.start(State, gui, {
	reducedMotion = function() return AuroraFX.reducedMotion end,
	fxScale = function() return AuroraFX.fxScale end,
	profile = function() return profile end,
	isStadium = function() return State:GetAttribute("ArenaId") == "Stadium" end,
})
CollectionService:GetInstanceAddedSignal("UP_Crowd"):Connect(function(p) if profile then styleCrowd(p) end end)
-- Karriere (M3): Pitch Coins, Stufe, Meldungen, Scout-Gespräch und Shop (nur Anzeige, Werte vom Server)
require(script:WaitForChild("CareerUI")).start(gui, RS:WaitForChild("UltimatePitch"):WaitForChild("Career"))
CollectionService:GetInstanceAddedSignal("UP_FieldLight"):Connect(function(l) if profile then styleLight(l) end end)
applyProfile(autoProfile())
task.delay(3, function() applyProfile(profile) end) -- Lighting-Effekte entstehen serverseitig evtl. später
---------------------------------------------------------------- Zonenlicht (nur lokale Darstellung)
-- Das Nachtspiel-Licht gehört zum SPECTRA DOME, nicht zur ganzen Welt: Ist die Kamera im Stadion, blendet
-- dieser Client in ~1 s vom Grundlicht der Welt (Server: später Nachmittag) auf das Stadionlicht über und
-- beim Verlassen wieder zurück. Andere Spieler und der Server sind davon nicht betroffen.
local DOME_A, DOME_B, DOME_TOP = 178, 134, 58 -- Außenkante des Kessels (Halbachsen X/Z) und Dachhöhe
local ZONE = {
	city = { clock = 16.6, brightness = 2.2, outdoor = Color3.fromRGB(140, 142, 150), ambient = Color3.fromRGB(92, 96, 110),
		density = 0.28, atmoColor = Color3.fromRGB(190, 205, 230), decay = Color3.fromRGB(120, 140, 170), glare = 0.1, haze = 1.2,
		bloom = 0.4, bloomSize = 24, threshold = 1.2, ccBright = 0, contrast = 0.08, saturation = 0.12, tint = Color3.new(1, 1, 1) },
	dome = { clock = 20.3, brightness = 1.5, outdoor = Color3.fromRGB(120, 140, 185), ambient = Color3.fromRGB(60, 72, 120),
		density = 0.26, atmoColor = Color3.fromRGB(40, 70, 170), decay = Color3.fromRGB(20, 30, 90), glare = 0.4, haze = 1.4,
		bloom = 0.9, bloomSize = 30, threshold = 1.05, ccBright = 0.05, contrast = 0.16, saturation = 0.3, tint = Color3.fromRGB(228, 236, 255) },
}
local zoneK, zoneApplied, zoneProfile = nil, nil, nil
local function applyZone(k)
	local a, b = ZONE.city, ZONE.dome
	local function n(key) return a[key] + (b[key] - a[key]) * k end
	local function c(key) return a[key]:Lerp(b[key], k) end
	Lighting.ClockTime = n("clock")
	Lighting.Brightness = n("brightness")
	Lighting.OutdoorAmbient = c("outdoor")
	Lighting.Ambient = c("ambient")
	local atmo = Lighting:FindFirstChild("UP_Atmosphere")
	if atmo then
		atmo.Density = n("density") * (profile == "Niedrig" and 0.46 or 1)
		atmo.Color, atmo.Decay, atmo.Glare, atmo.Haze = c("atmoColor"), c("decay"), n("glare"), n("haze")
	end
	local bloom = Lighting:FindFirstChild("UP_Bloom")
	if bloom then bloom.Intensity, bloom.Size, bloom.Threshold = n("bloom"), n("bloomSize"), n("threshold") end
	local cc = Lighting:FindFirstChild("UP_Color")
	if cc then cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = n("ccBright"), n("contrast"), n("saturation"), c("tint") end
end
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local p = cam.CFrame.Position
	local inside = (p.X / DOME_A) ^ 2 + (p.Z / DOME_B) ^ 2 < 1 and p.Y < DOME_TOP
	local target = inside and 1 or 0
	if inside ~= inDome then
		inDome = inside
		ambienceLevel()
	end
	if zoneK == nil then zoneK = target end -- beim Start ohne Überblendung
	if zoneK ~= target then
		zoneK = math.clamp(zoneK + (target > zoneK and 1 or -1) * dt, 0, 1)
	end
	-- nur schreiben, wenn sich etwas geändert hat (Blendwert oder Grafikprofil)
	if zoneK ~= zoneApplied or profile ~= zoneProfile then
		zoneApplied, zoneProfile = zoneK, profile
		applyZone(zoneK)
	end
end)

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
-- Match verlassen und zurück in die Stadt: nur eine Absicht, die Abmeldung macht der Server
CAS:BindAction("UP_Leave", function(_, st)
	if st == Enum.UserInputState.Begin and State:GetAttribute("Phase") ~= "Free" then Kick:FireServer("Leave") end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.L)

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
	topButton("UP_LeaveBtn", -134, "EXIT", function() if State:GetAttribute("Phase") ~= "Free" then Kick:FireServer("Leave") end end)
end

CAS:SetPosition("UP_Shot", UDim2.new(0.15, 0, 0.05, 0))
CAS:SetPosition("UP_Pass", UDim2.new(-0.25, 0, 0.45, 0))
CAS:SetPosition("UP_Sprint", UDim2.new(-0.25, 0, 0.0, 0))
CAS:SetPosition("UP_Aurora", UDim2.new(0.15, 0, 0.5, 0))

-- Arena-Sicht starten: aktuelle Anmeldung übernehmen und Änderungen folgen
player:GetAttributeChangedSignal("UP_Arena"):Connect(function() bindArena(player:GetAttribute("UP_Arena")) end)
bindArena(player:GetAttribute("UP_Arena"))
]==]
local ca = Instance.new("ModuleScript") ca.Name = "AuroraFX" ca.Source = [==[-- UltimatePitch · AURORA BREAK Darstellung (ModuleScript unter UltimatePitchClient)
-- Reine Optik: reagiert auf Server-Ereignisse (AuroraWindup/AuroraKick/AuroraCancel, GoalSeq) und entscheidet nichts.
-- Kickanimation prozedural über R15-Motor6D.Transform (keine hochgeladene Animation), Kick-Marker bei Anlaufende.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local AuroraFX = {}
AuroraFX.reducedMotion = false
AuroraFX.fxScale = 1 -- Grafikprofil: 1 = Hoch/Mittel, 0.5 = Niedrig (weniger Partikel und Bildschirmstreifen)
AuroraFX.markers = {} -- Testmesswerte: Zeitpunkte von Anlauf, Kick-Marker und Server-Kick je Schütze

local GREEN = Color3.fromRGB(70, 255, 150)
local CYAN = Color3.fromRGB(40, 220, 255)
local GOLD = Color3.fromRGB(255, 200, 60)
local WHITE = Color3.fromRGB(245, 255, 250)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "UP_LocalFX"
fxFolder.Parent = workspace

local function fxPart(props, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = fxFolder
	Debris:AddItem(p, life)
	return p
end

-- Posen als Winkel (rad) je Gelenk; Zeit relativ zum Kick-Marker (0 = Ballkontakt).
-- Schussbein rechts (hip/knee), Standbein links (lhip/lknee), Oberkörper (waist = Drehung, lean = Rücklage), Arme.
-- Vorzeichen (in Studio gemessen): positiver Hüftwinkel schwingt das Bein nach VORN, negativer nach hinten;
-- negativer Kniewinkel beugt den Unterschenkel nach hinten. Kontaktpose: Fußmitte ca. 1,5 Studs vor dem
-- Körper auf Ballhöhe (Ball liegt beim Anlauf 2,6 Studs vor dem Schützen am Boden, Radius 1,1).
local POSES = {
	{ t = -0.30, hip = 0, knee = 0, lhip = 0, lknee = 0, waist = 0, lean = 0, lsh = 0, rsh = 0 },
	{ t = -0.16, hip = -0.4, knee = -0.6, lhip = 0.15, lknee = -0.3, waist = 0.15, lean = 0, lsh = -0.4, rsh = 0.3 },   -- Anlauf
	{ t = -0.07, hip = -0.9, knee = -1.4, lhip = 0.25, lknee = -0.45, waist = 0.4, lean = -0.05, lsh = -1.0, rsh = 0.6 }, -- Ausholen
	{ t = 0.00, hip = 0.7, knee = -0.1, lhip = 0.2, lknee = -0.5, waist = -0.2, lean = 0.1, lsh = 0.4, rsh = -0.5 },     -- Kontakt
	{ t = 0.10, hip = 1.4, knee = -0.05, lhip = 0.1, lknee = -0.3, waist = -0.35, lean = 0.15, lsh = 0.6, rsh = -0.8 },  -- Durchschwung
	{ t = 0.45, hip = 0, knee = 0, lhip = 0, lknee = 0, waist = 0, lean = 0, lsh = 0, rsh = 0 },                         -- Ausschwingen
}
-- Der Ball ist serverseitig. Beim Client kommt seine Geschwindigkeit sofort an, die sichtbare Position aber mit
-- Interpolationsverzögerung (gemessen ~0,2 s). Darum hängt der sichtbare Kontakt an der Ballbewegung: Die
-- Kontaktpose wird gehalten, bis der Ball sich sichtbar vom Fuß löst (höchstens CONTACT_HOLD); löst er sich
-- früher, springt die Animation in den Kontakt. „Löst sich“ = schnell UND weiter als die Haltedistanz entfernt.
local CONTACT_HOLD = 0.25
local BALL_MOVING = 30
local HOLD_DIST = 3.3 -- Server hält den Ball im Anlauf 2,6 Studs vor dem Schützen

local function sample(t)
	if t <= POSES[1].t then return POSES[1] end
	for i = 1, #POSES - 1 do
		local a, b = POSES[i], POSES[i + 1]
		if t <= b.t then
			local u = (t - a.t) / (b.t - a.t)
			u = u * u * (3 - 2 * u)
			local out = {}
			for k, v in pairs(a) do out[k] = v + (b[k] - v) * u end
			return out
		end
	end
	return POSES[#POSES]
end

-- R15-Gelenk finden: klassisch Motor6D, mit AvatarJointUpgrade AnimationConstraint (gleicher Name, beide haben .Transform)
local function joint(char, partName, jointName)
	local p = char:FindFirstChild(partName)
	local j = p and p:FindFirstChild(jointName)
	if not j then j = char:FindFirstChild(jointName, true) end
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then return j end
	return nil
end
AuroraFX.joint = joint

-- Overlay nach dem Animator: PreSimulation (Nachfolger von Stepped), Stepped nur als Rückfall
local preSim = RunService.PreSimulation or RunService.Stepped

local active = {} -- laufende Kickanimation je Figur: { conn, joints }
local function stopKick(char)
	local a = active[char]
	if not a then return end
	active[char] = nil
	if a.conn.Connected then a.conn:Disconnect() end
	for _, j in pairs(a.joints) do
		if j.Parent then j.Transform = CFrame.identity end
	end
end
AuroraFX.stopKick = stopKick

-- Prozedurale R15-Kickanimation; meldet den Kick-Marker über onMarker. Fehlen die Gelenke (R6/eigenes Rig),
-- läuft nur der Marker – die Server-Logik hängt ohnehin nicht an der Animation.
local function playKick(char, windup, onMarker, ball)
	stopKick(char)
	local joints = {
		hip = joint(char, "RightUpperLeg", "RightHip"),
		knee = joint(char, "RightLowerLeg", "RightKnee"),
		lhip = joint(char, "LeftUpperLeg", "LeftHip"),
		lknee = joint(char, "LeftLowerLeg", "LeftKnee"),
		waist = joint(char, "UpperTorso", "Waist"),
		lsh = joint(char, "LeftUpperArm", "LeftShoulder"),
		rsh = joint(char, "RightUpperArm", "RightShoulder"),
	}
	local start = os.clock()
	local contactAt = windup
	local fired = false
	local heldSince = nil
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	local function ballMoving()
		if not (ball and ball.Parent and rootPart) then return false end
		local d = ball.Position - rootPart.Position
		return ball.AssemblyLinearVelocity.Magnitude > BALL_MOVING and Vector3.new(d.X, 0, d.Z).Magnitude > HOLD_DIST
	end
	local function step()
		local t = os.clock() - start - contactAt
		if t < 0 and ballMoving() then
			-- Ball fliegt schon: sofort in die Kontaktphase
			start = os.clock() - contactAt
			t = 0
		elseif t >= 0 and not fired then
			-- Kontaktpose halten, bis der Ball sichtbar losfliegt (oder Haltezeit vorbei ist)
			heldSince = heldSince or os.clock()
			if not ballMoving() and os.clock() - heldSince < CONTACT_HOLD then
				start = os.clock() - contactAt
				t = 0
			end
		end
		if not fired and t >= 0 and (ballMoving() or (heldSince and os.clock() - heldSince >= CONTACT_HOLD)) then
			fired = true
			onMarker("Kick")
		end
		if not char.Parent or t > POSES[#POSES].t then stopKick(char) return end
		local pose = sample(t)
		if joints.hip then joints.hip.Transform = CFrame.Angles(pose.hip, 0, 0) end
		if joints.knee then joints.knee.Transform = CFrame.Angles(pose.knee, 0, 0) end
		if joints.lhip then joints.lhip.Transform = CFrame.Angles(pose.lhip, 0, 0) end
		if joints.lknee then joints.lknee.Transform = CFrame.Angles(pose.lknee, 0, 0) end
		if joints.waist then joints.waist.Transform = CFrame.Angles(pose.lean, pose.waist, 0) end
		if joints.lsh then joints.lsh.Transform = CFrame.Angles(0, 0, pose.lsh) end
		if joints.rsh then joints.rsh.Transform = CFrame.Angles(0, 0, pose.rsh) end
	end
	active[char] = { conn = preSim:Connect(step), joints = joints }
	return joints.hip ~= nil
end
AuroraFX.playKick = playKick

-- Prozedurale R15-Bewegungsebene (rein optisch, je Client): Sprint-Vorlage, Ballkontakte beim Dribbeln,
-- Annahme-Pose bei Besitzwechsel, Torjubel des Torteams. Schreibt absolute Gelenk-Transforms in
-- PreSimulation (wie die Kickpose) und nur, solange ein Effekt aktiv ist; eine laufende Kickpose hat Vorrang.
-- Vorzeichen in Studio gemessen: Hüfte/Schulter +X = nach vorn, rechte Schulter +Z / linke −Z = seitlich hoch.
local MOTION_RANGE = 150 -- Studs zur Kamera; weiter entfernte Figuren bleiben bei der Standardanimation
local SPRINT_SPEED = 20.5 -- über Gehtempo 18 (Sprint 26), Bots laufen 17-19
local CELEBRATE_TIME, RECEIVE_TIME = 2.4, 0.3
local TOUCH_CYCLE, TOUCH_WINDOW = 0.5, 0.16
function AuroraFX.startMotion(State)
	-- Schwache Schlüssel: entfernte/respawnte Figuren dürfen nicht in den Tabellen hängen bleiben
	local celebrate = setmetatable({}, { __mode = "k" })
	local receive = setmetatable({}, { __mode = "k" })
	local jointCache = setmetatable({}, { __mode = "k" })
	local touched = setmetatable({}, { __mode = "k" }) -- im letzten Frame überschriebene Gelenke je Figur
	local function jointsOf(char)
		local j = jointCache[char]
		if not j then
			j = {
				hip = joint(char, "RightUpperLeg", "RightHip"), knee = joint(char, "RightLowerLeg", "RightKnee"),
				waist = joint(char, "UpperTorso", "Waist"),
				lsh = joint(char, "LeftUpperArm", "LeftShoulder"), rsh = joint(char, "RightUpperArm", "RightShoulder"),
			}
			-- nur vollständig gefundene Gelenke dauerhaft merken (beim Spawn fehlen sie evtl. noch kurz)
			if j.hip and j.knee and j.waist and j.lsh and j.rsh then jointCache[char] = j end
		end
		return j
	end
	local function characters()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then table.insert(list, plr.Character) end
		end
		local root = workspace:FindFirstChild("UltimatePitch")
		local bots = root and root:FindFirstChild("Bots")
		if bots then
			for _, b in ipairs(bots:GetChildren()) do table.insert(list, b) end
		end
		return list
	end
	-- Ballführer (Mensch oder Bot) aus State.BallCarrier; Annahme-Pose beim Wechsel
	local carrierValue = State:WaitForChild("BallCarrier", 10)
	if carrierValue then
		carrierValue.Changed:Connect(function(model)
			if model then receive[model] = os.clock() end
		end)
	end
	local lastSeq = State:GetAttribute("GoalSeq") or 0
	State:GetAttributeChangedSignal("GoalSeq"):Connect(function()
		local seq = State:GetAttribute("GoalSeq") or 0
		if seq > lastSeq then
			local team = State:GetAttribute("LastGoalTeam") or ""
			for _, char in ipairs(characters()) do
				if char:GetAttribute("KitTeam") == team then celebrate[char] = os.clock() + CELEBRATE_TIME end
			end
		end
		lastSeq = seq
	end)
	preSim:Connect(function()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		local now = os.clock()
		local ownerChar = carrierValue and carrierValue.Value
		for _, char in ipairs(characters()) do
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and not active[char] and (root.Position - camPos).Magnitude < MOTION_RANGE then
				local j = jointsOf(char)
				local set = {}
				local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				local function put(name, cf)
					local jt = j[name]
					if jt and jt.Parent then jt.Transform = cf set[name] = true end
				end
				if celebrate[char] and now < celebrate[char] then
					-- Jubel: Arme im V nach oben, leicht winkend, Oberkörper etwas zurück
					local wave = math.sin(now * 9) * 0.18
					put("rsh", CFrame.Angles(0.35, 0, 2.4 + wave))
					put("lsh", CFrame.Angles(0.35, 0, -2.4 - wave))
					put("waist", CFrame.Angles(-0.15, 0, 0))
				else
					celebrate[char] = nil
					local rec = receive[char]
					if rec and now - rec < RECEIVE_TIME then
						-- Annahme: Schussbein federt nach vorn, Arme zur Balance seitlich, Oberkörper leicht zurück
						local s = math.sin(math.pi * (now - rec) / RECEIVE_TIME)
						put("hip", CFrame.Angles(0.7 * s, 0, 0))
						put("knee", CFrame.Angles(-0.7 * s, 0, 0))
						put("waist", CFrame.Angles(-0.12 * s, 0, 0))
						put("rsh", CFrame.Angles(0, 0, 0.5 * s))
						put("lsh", CFrame.Angles(0, 0, -0.5 * s))
					else
						receive[char] = nil
						if char == ownerChar and speed > 4 then
							-- Ballkontakte beim Dribbeln: kurzer Tipp mit dem rechten Fuß im Takt
							local phase = now % TOUCH_CYCLE
							if phase < TOUCH_WINDOW then
								local s = math.sin(math.pi * phase / TOUCH_WINDOW)
								put("hip", CFrame.Angles(0.45 * s, 0, 0))
								put("knee", CFrame.Angles(-0.35 * s, 0, 0))
							end
						end
						if speed > SPRINT_SPEED then
							-- Sprint: Oberkörper nach vorn gelegt
							put("waist", CFrame.Angles(0.2, 0, 0))
						end
					end
				end
				-- Gelenke, die im letzten Frame überschrieben wurden und jetzt frei sind, zurück an den Animator
				local prev = touched[char]
				if prev then
					for name in pairs(prev) do
						if not set[name] and j[name] and j[name].Parent then j[name].Transform = CFrame.identity end
					end
				end
				touched[char] = set
			elseif root and not active[char] and touched[char] then
				-- außer Reichweite: zuletzt überschriebene Gelenke freigeben (eine laufende Kickpose bleibt unberührt)
				local j = jointsOf(char)
				for name in pairs(touched[char]) do
					if j[name] and j[name].Parent then j[name].Transform = CFrame.identity end
				end
				touched[char] = nil
			end
		end
	end)
end

-- Normale Pässe/Schüsse/Paraden (Server meldet "KickAnim" mit der Figur): kurze Variante derselben Kickpose.
-- Läuft keine AURORA-Animation an der Figur, sonst wird nichts überschrieben.
function AuroraFX.quickKick(char, ball)
	if not (char and char.Parent) or active[char] then return end
	playKick(char, 0.1, function() end, ball)
end

-- Freie Soundeffekte (ProSoundEffects, Roblox Creator Store): AURORA-Knall am Kontaktpunkt, räumlich
local BOOM_ID = "rbxassetid://9120769331" -- Wind Whoosh Sonic Boom Low End Impact 1
local function spatialSound(id, pos, volume, speed, life)
	local holder = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos) }, life)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMinDistance = 30
	s.RollOffMaxDistance = 400
	s.Parent = holder
	s:Play()
	return s
end

-- Einblendung für den Schützen: „AURORA BREAK“ schlägt kurz groß ein (bei Reduced Motion ohne Skalierung)
local function callout()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	local sg = Instance.new("ScreenGui")
	sg.Name = "UP_AuroraCallout"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 6
	sg.Parent = pg
	Debris:AddItem(sg, 1.2)
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.3)
	t.Size = UDim2.new(0.8, 0, 0, 80)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = "AURORA BREAK"
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Rotation = -3
	t.Parent = sg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(200, 255, 225), GREEN)
	g.Rotation = 90
	g.Parent = t
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(0, 60, 40)
	st.Thickness = 4
	st.Parent = t
	local sc = Instance.new("UIScale")
	sc.Scale = AuroraFX.reducedMotion and 1 or 1.8
	sc.Parent = t
	if not AuroraFX.reducedMotion then
		TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(0.6, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
end

local function ringBurst(pos, color, delay, size, life)
	task.delay(delay, function()
		local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2, 2), Color = color, Transparency = 0.2,
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) }, life + 0.1)
		TweenService:Create(ring, TweenInfo.new(life, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.2, size, size), Transparency = 1 }):Play()
	end)
end

local function flash(root, color, brightness, life)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = brightness
	light.Parent = root
	TweenService:Create(light, TweenInfo.new(life), { Brightness = 0 }):Play()
	Debris:AddItem(light, life + 0.05)
end

-- FOV-Push: Ausgangs-FOV merken (nicht fest 70), überlappende Pushes kehren zum ursprünglichen Wert zurück
local pushBase, pushToken = nil, 0
local function cameraPush(amount)
	local cam = workspace.CurrentCamera
	if AuroraFX.reducedMotion or not cam then return end
	pushBase = pushBase or cam.FieldOfView
	pushToken += 1
	local my, base = pushToken, pushBase
	TweenService:Create(cam, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { FieldOfView = base + amount }):Play()
	task.delay(0.16, function()
		if my ~= pushToken then return end
		local back = TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { FieldOfView = base })
		back.Completed:Connect(function() if my == pushToken then pushBase = nil end end)
		back:Play()
	end)
end

-- Kurzer Kamera-Impuls beim Kontakt (nur Schütze, aus bei Reduced Motion): 0,22 s abklingendes Zittern,
-- nach der Standard-Kamera angewendet; die Kamera kehrt danach von selbst in ihre Bahn zurück.
local shakeId = 0
local function cameraShake(strength, duration)
	if AuroraFX.reducedMotion then return end
	shakeId += 1
	local name = "UP_AuroraShake" .. shakeId
	local t0 = os.clock()
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		local k = 1 - (os.clock() - t0) / duration
		if k <= 0 or not cam then RunService:UnbindFromRenderStep(name) return end
		local a = strength * k * k
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(math.sin(os.clock() * 90) * a), math.rad(math.cos(os.clock() * 70) * a), 0)
	end)
end

-- Bildschirm-Speedlines (nur Schütze, aus bei Reduced Motion): radiale Streifen vom Bildrand zur Mitte hin,
-- die nach außen wegschießen. Eigene ScreenGui ohne Inset, räumt sich nach `life` selbst ab.
function AuroraFX.speedLines(count, life)
	if AuroraFX.reducedMotion then return end
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	local sg = Instance.new("ScreenGui")
	sg.Name = "UP_AuroraScreen"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 5
	sg.Parent = pg
	Debris:AddItem(sg, life + 0.1)
	local rng = Random.new()
	for i = 1, count do
		local angle = (i / count) * 360 + rng:NextNumber(-6, 6)
		local rad = math.rad(angle)
		local dir = Vector2.new(math.cos(rad), math.sin(rad))
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(0, 0)
		holder.Position = UDim2.fromScale(0.5 + dir.X * 0.26, 0.5 + dir.Y * 0.26)
		holder.Rotation = angle
		holder.Parent = sg
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.Size = UDim2.fromOffset(rng:NextInteger(220, 420), rng:NextInteger(3, 8))
		line.BackgroundColor3 = i % 3 == 0 and GREEN or WHITE
		line.BackgroundTransparency = 0.15
		line.Parent = holder
		TweenService:Create(holder, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5 + dir.X * 0.75, 0.5 + dir.Y * 0.75) }):Play()
		TweenService:Create(line, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }):Play()
	end
end

local function charOf(userId)
	local plr = Players:GetPlayerByUserId(userId)
	return plr and plr.Character, plr
end

-- Aura am Schützen: aufsteigende Leuchtfunken (Standard-Partikeltextur von Roblox, kein externes Asset)
-- und Lichtzacken rund um den Körper. Räumt sich nach `duration` selbst ab.
function AuroraFX.aura(root, own, duration)
	local att = Instance.new("Attachment")
	att.Name = "UP_AuroraAura"
	att.Position = Vector3.new(0, -1, 0)
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(WHITE, GREEN)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0.1, 1)
	pe.Lifetime = NumberRange.new(0.35, 0.6)
	pe.Speed = NumberRange.new(6, 12)
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, 10, 0)
	pe.Rate = (own and 90 or 35) * AuroraFX.fxScale
	pe.Parent = att
	task.delay(duration, function() pe.Enabled = false end)
	Debris:AddItem(att, duration + 0.7)
	local spikes = own and 8 or 4
	for i = 1, spikes do
		local a = (i / spikes) * math.pi * 2
		local offset = Vector3.new(math.cos(a), 0, math.sin(a)) * 2.2
		local base = root.Position + offset - Vector3.new(0, 2, 0)
		local spike = fxPart({ Size = Vector3.new(0.22, 3, 0.22), Color = i % 2 == 0 and CYAN or GREEN, Transparency = 0.25,
			CFrame = CFrame.lookAt(base, base + offset * 0.9 + Vector3.new(0, 4, 0)) * CFrame.Angles(math.rad(-90), 0, 0) }, duration + 0.1)
		TweenService:Create(spike, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = spike.CFrame + Vector3.new(0, 3, 0) + offset * 0.4, Transparency = 1, Size = Vector3.new(0.1, 5.5, 0.1) }):Play()
	end
end

-- Anlauf: Animation + gestaffelte Ringe + Aura; volle Effektmenge nur für den eigenen Schützen (FX-Budget)
function AuroraFX.windup(userId, windup, ball)
	local char, plr = charOf(userId)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local own = plr == Players.LocalPlayer
	AuroraFX.markers[userId] = { windupAt = os.clock() }
	local feet = root.Position - Vector3.new(0, 2.8, 0)
	ringBurst(feet, GREEN, 0, 14, 0.4)
	ringBurst(feet, CYAN, 0.08, 18, 0.4)
	if own then ringBurst(feet, GOLD, 0.16, 22, 0.45) end
	flash(root, GREEN, own and 5 or 2.5, windup + 0.2)
	AuroraFX.aura(root, own, windup + 0.35)
	playKick(char, windup, function(name)
		local m = AuroraFX.markers[userId]
		if not m then return end
		m.markerAt = os.clock()
		m.marker = name
		-- Messwert für Tests (lokal, nicht repliziert): Abstand Anlaufbeginn -> Kick-Marker
		if own then Players.LocalPlayer:SetAttribute("AuroraMarkerDelay", m.markerAt - m.windupAt) end
	end, ball)
end

-- Server hat am Kick-Marker geschossen: Ball-Kern, Spur, Streifen, Bodenimpuls, Kamera
function AuroraFX.kick(userId, ball)
	local char, plr = charOf(userId)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local own = plr == Players.LocalPlayer
	local m = AuroraFX.markers[userId]
	if m then
		m.kickAt = os.clock()
		-- Messwert für Tests: Abstand Anlaufbeginn -> serverbestätigter Schuss
		if own then Players.LocalPlayer:SetAttribute("AuroraKickDelay", m.kickAt - m.windupAt) end
	end
	if not ball then return end
	spatialSound(BOOM_ID, ball.Position, own and 1.2 or 0.9, 1.05, 6)
	if own then callout() end
	local life = 1.1
	-- Lichtkern: kleiner leuchtender Kern + weicher Halo (beide halbtransparent, Bloom macht das Leuchten),
	-- statt einer undurchsichtigen Kugel. Spur am Kern, Punktlicht färbt Rasen und Spieler.
	local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.1, 2.1, 2.1), Color = Color3.fromRGB(210, 255, 230),
		Transparency = 0.15, CFrame = ball.CFrame }, life + 0.1)
	local halo = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(4.6, 4.6, 4.6), Color = GREEN, Transparency = 0.72,
		CFrame = ball.CFrame }, life + 0.1)
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 1.1, 0); a0.Parent = core
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -1.1, 0); a1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.4
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Color = ColorSequence.new(WHITE, CYAN)
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.Parent = core
	local glow = Instance.new("PointLight"); glow.Color = GREEN; glow.Range = 22; glow.Brightness = 6; glow.Parent = core
	TweenService:Create(core, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(1.4, 1.4, 1.4), Transparency = 0.7 }):Play()
	TweenService:Create(halo, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(2.4, 2.4, 2.4), Transparency = 1 }):Play()
	TweenService:Create(glow, TweenInfo.new(life), { Brightness = 0 }):Play()
	-- Impact-Blitz am Kontaktpunkt: kurz aufblähende helle Kugel (0,2 s)
	local burst = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Color = WHITE, Transparency = 0.3,
		CFrame = ball.CFrame }, 0.25)
	TweenService:Create(burst, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(own and 16 or 10, own and 16 or 10, own and 16 or 10), Transparency = 1 }):Play()
	local follow
	follow = RunService.RenderStepped:Connect(function()
		if not core.Parent or not ball.Parent then follow:Disconnect() return end
		core.CFrame = ball.CFrame
		halo.CFrame = ball.CFrame
	end)
	task.delay(life, function() if follow.Connected then follow:Disconnect() end end)
	if own then AuroraFX.speedLines(math.floor(36 * AuroraFX.fxScale), 0.45) end

	local origin = root and root.Position or ball.Position
	local forward = root and Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit or Vector3.new(1, 0, 0)
	ringBurst(origin - Vector3.new(0, 2.8, 0), WHITE, 0, own and 26 or 16, 0.35)
	local streaks = own and 10 or 4
	for i = 1, streaks do
		local angle = (i / streaks) * math.pi * 2
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, angle) * forward)
		local s = fxPart({ Size = Vector3.new(0.25, 0.25, 6), Color = i % 2 == 0 and GREEN or WHITE, Transparency = 0.1,
			CFrame = CFrame.lookAt(origin + dir * 3, origin + dir * 9) }, 0.4)
		TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.lookAt(origin + dir * 14, origin + dir * 22), Transparency = 1 }):Play()
	end
	if own then cameraPush(14) cameraShake(0.9, 0.22) elseif root and workspace.CurrentCamera
		and (workspace.CurrentCamera.CFrame.Position - root.Position).Magnitude < 60 then cameraPush(5) end
end

function AuroraFX.cancel(userId)
	AuroraFX.markers[userId] = nil
	local char = charOf(userId)
	if char then stopKick(char) end
end

local TEAM_TINT = {
	Rot = { band = Color3.fromRGB(200, 30, 45), tint = Color3.fromRGB(255, 215, 215) },
	Blau = { band = Color3.fromRGB(30, 70, 220), tint = Color3.fromRGB(210, 222, 255) },
}
local AURORA_TINT = { band = Color3.fromRGB(10, 150, 110), tint = Color3.fromRGB(200, 255, 230) }

-- GOAL-Cinematic: nur auf das serverbestätigte Tor-Ereignis (GoalSeq), nie bei Fehlschüssen
function AuroraFX.goal(gui, team, aurora)
	local look = aurora and AURORA_TINT or TEAM_TINT[team] or TEAM_TINT.Blau
	-- Querband hinter dem Titel in Teamfarbe (AURORA: Grün), fährt von links ein (bei Reduced Motion ohne Fahrt)
	local band = Instance.new("Frame")
	band.Name = "GoalBand"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Size = UDim2.new(1.3, 0, 0, 205) -- umfasst Titel und Untertitel des Banners
	band.Rotation = -4
	band.BorderSizePixel = 0
	band.ZIndex = 0
	band.BackgroundColor3 = look.band
	band.BackgroundTransparency = 0.15
	local fadeEdges = Instance.new("UIGradient")
	fadeEdges.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0.1),
		NumberSequenceKeypoint.new(0.82, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fadeEdges.Parent = band
	for _, y in ipairs({ 0, 1 }) do
		local edge = Instance.new("Frame")
		edge.AnchorPoint = Vector2.new(0, y)
		edge.Position = UDim2.fromScale(0, y)
		edge.Size = UDim2.new(1, 0, 0, 5)
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = GOLD
		edge.ZIndex = 0
		edge.Parent = band
	end
	band.Position = AuroraFX.reducedMotion and UDim2.fromScale(0.5, 0.55) or UDim2.fromScale(-0.7, 0.55)
	band.Parent = gui
	if not AuroraFX.reducedMotion then
		TweenService:Create(band, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.55) }):Play()
	end
	task.delay(1.3, function()
		TweenService:Create(band, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, e in ipairs(band:GetChildren()) do
			if e:IsA("Frame") then TweenService:Create(e, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play() end
		end
	end)
	Debris:AddItem(band, 1.7)

	-- Banner in Bildmitte (Torpause, kein laufendes Spiel): großer goldener Titel + Untertitel
	local banner = Instance.new("Frame")
	banner.Name = "GoalBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.55)
	banner.Size = UDim2.new(0.92, 0, 0, 190) -- schmale Bildschirme: 92 % Breite, höchstens 640 px
	banner.BackgroundTransparency = 1
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 190)
	limit.Parent = banner
	banner.Rotation = -4
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 140)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Text = "GOAL!"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = banner
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 244, 170), GOLD)
	gradient.Rotation = 90
	gradient.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 50, 0)
	stroke.Thickness = 5
	stroke.Parent = title
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 140)
	sub.Size = UDim2.new(1, 0, 0, 44)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBlack
	sub.TextScaled = true
	sub.Text = (aurora and "AURORA BREAK  ·  " or "") .. string.upper(team)
	sub.TextColor3 = aurora and Color3.fromRGB(150, 255, 200) or Color3.new(1, 1, 1)
	sub.TextStrokeTransparency = 0.2
	sub.Parent = banner
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = banner
	banner.Parent = gui
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.3, function()
		TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(banner, 1.7)
	if AuroraFX.reducedMotion then return end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "UP_GoalGrade"
	cc.Saturation = aurora and -0.75 or -0.4
	cc.Contrast = 0.15
	cc.TintColor = look.tint -- Team- bzw. AURORA-Färbung des Bildes
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	Debris:AddItem(cc, 1.1)
	if aurora then
		local white = Instance.new("Frame")
		white.Size = UDim2.fromScale(1, 1)
		white.BackgroundColor3 = WHITE
		white.BackgroundTransparency = 0.55
		white.ZIndex = 0
		white.Parent = gui
		TweenService:Create(white, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(white, 0.4)
	end
end

return AuroraFX
]==] ca.Parent = c
local cm = Instance.new("ModuleScript") cm.Name = "Matchday" cm.Source = [==[-- UltimatePitch · Matchday-Atmosphäre (ModuleScript unter UltimatePitchClient)
-- Rein optisch, je Client, reagiert nur auf serverbestätigte Zustände (State@Phase, State@GoalSeq):
--   * Anstoß-Intro: kurzer Kameraflug durch den SPECTRA DOME + Einblendung „ROT vs BLAU“ beim Matchstart
--   * Torjubel im Stadion: Pyro-Fontänen am Tor, LED-Ringe blinken in Teamfarbe, Publikum springt
-- Reduzierte Bewegung: kein Kameraflug, kein Blinken, kein Springen (nur Einblendung bzw. ruhige Teamfarbe).
-- Grafikprofil: Publikum springt nur im Profil „Hoch“, Pyro-Menge skaliert mit fxScale.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Matchday = {}

local TEAM_COLOR = { Rot = Color3.fromRGB(230, 40, 55), Blau = Color3.fromRGB(40, 100, 255) }
local AURORA_COLOR = Color3.fromRGB(70, 255, 150)
local HALF_LENGTH = 80
local INTRO_TIME = 3 -- Sekunden; läuft im Countdown der Vorbereitung (TimeLeft 3 → Anpfiff)
local CELEBRATE_TIME = 2.4

local opts = { reducedMotion = function() return false end, fxScale = function() return 1 end, profile = function() return "Hoch" end,
	isStadium = function() return true end }

local fxFolder = Instance.new("Folder")
fxFolder.Name = "UP_MatchdayFX"
fxFolder.Parent = workspace

---------------------------------------------------------------- Anstoß-Intro
local function titleCard(gui)
	local card = Instance.new("Frame")
	card.Name = "UP_KickoffCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(460, 110)
	card.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.Parent = gui
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
	local function chip(x, text, color)
		local c = Instance.new("TextLabel")
		c.AnchorPoint = Vector2.new(0.5, 0)
		c.Position = UDim2.new(0.5, x, 0, 14)
		c.Size = UDim2.fromOffset(150, 48)
		c.BackgroundColor3 = color
		c.BorderSizePixel = 0
		c.Font = Enum.Font.GothamBlack
		c.TextSize = 30
		c.TextColor3 = Color3.new(1, 1, 1)
		c.Text = text
		c.Parent = card
		Instance.new("UICorner", c).CornerRadius = UDim.new(0, 8)
		return c
	end
	chip(-110, "ROT", TEAM_COLOR.Rot)
	chip(110, "BLAU", TEAM_COLOR.Blau)
	local vs = Instance.new("TextLabel")
	vs.AnchorPoint = Vector2.new(0.5, 0)
	vs.Position = UDim2.new(0.5, 0, 0, 14)
	vs.Size = UDim2.fromOffset(60, 48)
	vs.BackgroundTransparency = 1
	vs.Font = Enum.Font.GothamBlack
	vs.TextSize = 24
	vs.TextColor3 = Color3.fromRGB(255, 220, 90)
	vs.Text = "vs"
	vs.Parent = card
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 70)
	sub.Size = UDim2.new(1, 0, 0, 28)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 16
	sub.TextColor3 = Color3.fromRGB(40, 210, 255)
	sub.Text = opts.isStadium() and "ANPFIFF  ·  SPECTRA DOME" or "ANPFIFF  ·  STREET COURT"
	sub.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = opts.reducedMotion() and 1 or 0.7
	scale.Parent = card
	if not opts.reducedMotion() then
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(INTRO_TIME - 0.5, function()
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
		end
		TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end)
	Debris:AddItem(card, INTRO_TIME + 0.2)
end

-- Kameraflug: von hoch über der Ecke in einem Bogen zur Spielfeldmitte; danach immer zurück zur Standardkamera.
-- Gemeinsamer Abbruch für reguläres Ende und Respawn: laufende Tweens stoppen, dann Kamera freigeben.
local introToken = 0
local introTweens = {}
local function abortFlight()
	introToken += 1
	for _, tw in ipairs(introTweens) do tw:Cancel() end
	table.clear(introTweens)
	local c = workspace.CurrentCamera
	if c and c.CameraType == Enum.CameraType.Scriptable then
		c.CameraType = Enum.CameraType.Custom
		local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then c.CameraSubject = hum end
	end
end
local function cameraFlight()
	local cam = workspace.CurrentCamera
	if not cam or opts.reducedMotion() then return end
	abortFlight() -- evtl. noch laufenden Flug sauber beenden
	local my = introToken
	local center = Vector3.new(0, 4, 0)
	-- Flugbahn innerhalb des Kessels (Innenkante x ±118 / z ±74, Dach 50): von der Ecke über die Längsseite
	local keys = {
		CFrame.lookAt(Vector3.new(-100, 42, -52), center),
		CFrame.lookAt(Vector3.new(-25, 34, -62), center),
		CFrame.lookAt(Vector3.new(70, 24, -46), center),
	}
	local ok = pcall(function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = keys[1]
		local seg = (INTRO_TIME - 0.4) / (#keys - 1)
		for i = 2, #keys do
			local tw = TweenService:Create(cam, TweenInfo.new(seg, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = keys[i] })
			table.insert(introTweens, tw)
			task.delay(seg * (i - 2), function() if my == introToken then tw:Play() end end)
		end
	end)
	-- Rückgabe der Kamera ist garantiert (auch bei Fehler); ein späterer Flug/Respawn hat den Token bereits erhöht
	task.delay(ok and INTRO_TIME or 0, function()
		if my == introToken then abortFlight() end
	end)
end

---------------------------------------------------------------- Torjubel im Stadion
local function pyro(goalPos, gw, color)
	local scale = opts.fxScale()
	for _, dz in ipairs({ -(gw + 18), -(gw + 5), gw + 5, gw + 18 }) do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(goalPos.X, goalPos.Y + 2.5, goalPos.Z + dz)
		p.Parent = fxFolder
		local att = Instance.new("Attachment")
		att.Parent = p
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.3, color),
			ColorSequenceKeypoint.new(1, color) })
		pe.LightEmission = 1
		pe.LightInfluence = 0
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(0.05, 1)
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(40, 62)
		pe.SpreadAngle = Vector2.new(10, 10)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Acceleration = Vector3.new(0, -35, 0)
		pe.Rate = 110 * scale
		pe.Parent = att
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 24
		light.Brightness = 4
		light.Parent = p
		TweenService:Create(light, TweenInfo.new(1.8), { Brightness = 0 }):Play()
		task.delay(1.6, function() pe.Enabled = false end)
		Debris:AddItem(p, 3.5)
	end
end

local ledToken = 0
local function flashLEDs(color)
	local root = workspace:FindFirstChild("UltimatePitch")
	local dome = root and root:FindFirstChild("SpectraDome")
	local led = dome and dome:FindFirstChild("LED")
	if not led then return end
	ledToken += 1
	local my = ledToken
	local parts, base = {}, {}
	for _, p in ipairs(led:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			base[p] = p:GetAttribute("UP_BaseColor") or p.Color
			p:SetAttribute("UP_BaseColor", base[p]) -- Grundfarbe merken, auch bei überlappenden Toren
		end
	end
	local steady = opts.reducedMotion()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if my ~= ledToken or t > CELEBRATE_TIME then
			conn:Disconnect()
			if my == ledToken then
				for _, p in ipairs(parts) do p.Color = base[p] end
			end
			return
		end
		local on = steady or (math.floor(t / 0.22) % 2 == 0)
		local c = on and color or Color3.new(1, 1, 1)
		for _, p in ipairs(parts) do p.Color = c end
	end)
end

local crowdToken = 0
local function crowdJump()
	if opts.reducedMotion() or opts.profile() ~= "Hoch" then return end
	crowdToken += 1
	local my = crowdToken
	local fans = CollectionService:GetTagged("UP_CrowdDetail")
	local base, phase = {}, {}
	local rng = Random.new()
	for _, p in ipairs(fans) do
		base[p] = p:GetAttribute("UP_BaseCFrame") or p.CFrame
		p:SetAttribute("UP_BaseCFrame", base[p])
		phase[p] = rng:NextNumber(0, math.pi * 2)
	end
	local t0, acc = os.clock(), 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		if my ~= crowdToken or t > CELEBRATE_TIME then
			conn:Disconnect()
			if my == crowdToken then
				for _, p in ipairs(fans) do if p.Parent then p.CFrame = base[p] end end
			end
			return
		end
		acc += dt
		if acc < 1 / 30 then return end -- 30 Hz genügen für das Springen und schonen schwache Geräte
		acc = 0
		local fade = math.min(1, (CELEBRATE_TIME - t) / 0.4)
		for _, p in ipairs(fans) do
			if p.Parent then
				p.CFrame = base[p] + Vector3.new(0, math.abs(math.sin(t * 9 + phase[p])) * 0.9 * fade, 0)
			end
		end
	end)
end

---------------------------------------------------------------- Start
function Matchday.start(State, gui, options)
	for k, v in pairs(options or {}) do opts[k] = v end
	-- Intro in den letzten INTRO_TIME Sekunden der Vorbereitung (Countdown TimeLeft), damit es genau mit dem
	-- Anpfiff endet und niemand während des Kameraflugs schon spielen muss
	local introDone = false
	State:GetAttributeChangedSignal("TimeLeft"):Connect(function()
		if State:GetAttribute("Phase") ~= "Intermission" then return end
		local t = State:GetAttribute("TimeLeft") or 0
		if t == math.ceil(INTRO_TIME) and not introDone then
			introDone = true
			titleCard(gui)
			if opts.isStadium() then cameraFlight() end -- der Flug führt durch den SPECTRA DOME
		end
	end)
	State:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = State:GetAttribute("Phase")
		if ph == "Intermission" then introDone = false end
		-- Anpfiff: falls der Flug noch läuft (Zeitversatz), spätestens jetzt beenden
		if ph == "Playing" then task.delay(0.3, function() if introTweens[1] then abortFlight() end end) end
	end)
	local lastSeq = State:GetAttribute("GoalSeq") or 0
	State:GetAttributeChangedSignal("GoalSeq"):Connect(function()
		local seq = State:GetAttribute("GoalSeq") or 0
		if seq > lastSeq then
			local team = State:GetAttribute("LastGoalTeam") or ""
			local aurora = State:GetAttribute("LastGoalAurora") == true
			local color = aurora and AURORA_COLOR or TEAM_COLOR[team] or Color3.new(1, 1, 1)
			-- Rot greift +X an, Blau −X: Pyro am getroffenen Tor der eigenen Arena (Lage und Maße aus dem Zustand)
			local origin = State:GetAttribute("Origin") or Vector3.zero
			local hl = State:GetAttribute("HalfLength") or HALF_LENGTH
			pyro(origin + Vector3.new((team == "Rot" and 1 or -1) * (hl + 4), 0, 0), State:GetAttribute("GoalHalfWidth") or 12, color)
			if opts.isStadium() then
				flashLEDs(color)
				crowdJump()
			end
		end
		lastSeq = seq
	end)
	-- Respawn während des Intros: Tweens stoppen und Kamera sofort freigeben
	Players.LocalPlayer.CharacterAdded:Connect(abortFlight)
end

return Matchday
]==] cm.Parent = c
local ck = Instance.new("ModuleScript") ck.Name = "CareerUI" ck.Source = [==[-- UltimatePitch · Karriere-Anzeige (ModuleScript unter UltimatePitchClient)
-- Rein darstellend: Coins, Karrierestufe, Meldungen, Scout-Gespräch und Shop. Werte kommen ausschließlich aus
-- den vom Server gesetzten Player-Attributen; Knöpfe senden nur Absichten an RemoteEvent "Career".
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CareerUI = {}

local PANEL = Color3.fromRGB(10, 14, 24)
local GOLD = Color3.fromRGB(255, 200, 60)
local ACCENT = Color3.fromRGB(40, 210, 255)
local PINK = Color3.fromRGB(255, 90, 170)
local SLOT_NAME = { boots = "Schuhe", armband = "Binde", number = "Rückennummer" }

local function make(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		o.BackgroundTransparency = 1
		o.Font = Enum.Font.GothamBold
		o.TextColor3 = Color3.new(1, 1, 1)
	end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
	return o
end
local function button(parent, text, color, props)
	local b = corner(make("TextButton", { BackgroundTransparency = 0, BackgroundColor3 = color, Text = text, TextSize = 15,
		Font = Enum.Font.GothamBlack, TextColor3 = PANEL }, parent), 6)
	for k, v in pairs(props or {}) do b[k] = v end
	return b
end

function CareerUI.start(gui, remote)
	local player = Players.LocalPlayer

	------------------------------------------------------------ Coins und Stufe (linker Rand, mittig: oben links liegen Roblox-Chat und Anzeigetafel)
	local chip = corner(make("Frame", { Position = UDim2.new(0, 16, 0.4, 0), Size = UDim2.fromOffset(196, 68),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.15 }, gui), 8)
	make("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.35 }, chip)
	local coinIcon = corner(make("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = GOLD, Rotation = 45 }, chip), 4)
	make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = -45,
		Text = "P", TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = PANEL }, coinIcon)
	local coinLabel = make("TextLabel", { Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -48, 0, 28), TextSize = 22,
		Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = "0" }, chip)
	local stageLabel = make("TextLabel", { Position = UDim2.fromOffset(10, 31), Size = UDim2.new(1, -20, 0, 16), TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.2, Text = "" }, chip)
	-- Speicherstatus (vom Server gesetzt): geladen/gespeichert, lädt, nur diese Sitzung, gestört
	local saveLabel = make("TextLabel", { Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 0, 14), TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, chip)
	local SAVE_TEXT = {
		loading = { "● SPIELSTAND LÄDT …", Color3.fromRGB(190, 205, 230) },
		ok = { "● AUTOSAVE AN", Color3.fromRGB(70, 255, 150) },
		off = { "● OHNE SPEICHERN (TEST)", Color3.fromRGB(150, 156, 172) },
		error = { "● SPEICHERN GESTÖRT", Color3.fromRGB(255, 110, 110) },
		lost = { "● ANDERER SERVER", Color3.fromRGB(255, 110, 110) },
	}
	local function refreshSave()
		local t = SAVE_TEXT[player:GetAttribute("CareerSave") or "loading"] or SAVE_TEXT.loading
		saveLabel.Text, saveLabel.TextColor3 = t[1], t[2]
	end
	player:GetAttributeChangedSignal("CareerSave"):Connect(refreshSave)
	refreshSave()

	local shown = 0
	local function refreshCoins()
		local target = player:GetAttribute("PitchCoins") or 0
		local from = shown
		shown = target
		if target > from then
			-- kurzes Hochzählen und Aufleuchten bei Gewinn
			task.spawn(function()
				for i = 1, 12 do
					if shown ~= target then return end
					coinLabel.Text = tostring(math.floor(from + (target - from) * i / 12 + 0.5))
					task.wait(0.03)
				end
			end)
			coinIcon.Size = UDim2.fromOffset(26, 26)
			coinIcon.Position = UDim2.fromOffset(7, 6)
			TweenService:Create(coinIcon, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(10, 9) }):Play()
		else
			coinLabel.Text = tostring(target)
		end
	end
	local function refreshStage()
		stageLabel.Text = string.upper(player:GetAttribute("CareerStage") or "Street Rookie") .. "  ·  KARRIERE"
	end
	player:GetAttributeChangedSignal("PitchCoins"):Connect(refreshCoins)
	player:GetAttributeChangedSignal("CareerStage"):Connect(refreshStage)
	refreshCoins()
	refreshStage()

	------------------------------------------------------------ Meldungen (links unter den Coins, gestapelt)
	local toastBox = make("Frame", { Position = UDim2.new(0, 16, 0.4, 76), Size = UDim2.fromOffset(340, 240),
		BackgroundTransparency = 1 }, gui)
	make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Left, SortOrder = Enum.SortOrder.LayoutOrder }, toastBox)
	local toastSeq = 0
	local function toast(text)
		toastSeq += 1
		local t = corner(make("TextLabel", { Size = UDim2.fromOffset(340, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = toastSeq,
			BackgroundTransparency = 0.12, BackgroundColor3 = PANEL, TextSize = 14, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, Text = text }, toastBox), 6)
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, t)
		make("Frame", { Size = UDim2.new(0, 3, 1, 16), Position = UDim2.fromOffset(-12, -8), BackgroundColor3 = GOLD }, t)
		local kids = 0
		for _, c in ipairs(toastBox:GetChildren()) do
			if c:IsA("TextLabel") then kids += 1 end
		end
		if kids > 4 then
			local oldest
			for _, c in ipairs(toastBox:GetChildren()) do
				if c:IsA("TextLabel") and (not oldest or c.LayoutOrder < oldest.LayoutOrder) then oldest = c end
			end
			if oldest then oldest:Destroy() end
		end
		task.delay(5, function()
			if not t.Parent then return end
			TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.5)
			t:Destroy()
		end)
	end

	------------------------------------------------------------ Dialog-Grundgerüst
	local function panel(title, color, w, h)
		local p = corner(make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Visible = false }, gui), 10)
		make("UIStroke", { Color = color, Thickness = 2, Transparency = 0.2 }, p)
		-- an kleine Bildschirme anpassen (Rand 12 px), damit der Schließen-Knopf immer erreichbar bleibt
		local function fit()
			local area = gui.AbsoluteSize
			p.Size = UDim2.fromOffset(math.max(240, math.min(w, area.X - 24)), math.max(160, math.min(h, area.Y - 24)))
		end
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
		make("TextLabel", { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -60, 0, 26), Text = title, TextSize = 20,
			Font = Enum.Font.GothamBlack, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left }, p)
		local close = button(p, "X", Color3.fromRGB(60, 66, 84), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(30, 30), TextColor3 = Color3.new(1, 1, 1) })
		close.Activated:Connect(function() p.Visible = false end)
		return p
	end

	------------------------------------------------------------ Scout-Gespräch
	local scout = panel("TALENT-SCOUT", ACCENT, 440, 230)
	local scoutText = make("TextLabel", { Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 1, -116), TextSize = 16, TextWrapped = true,
		Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "" }, scout)
	make("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 11 }, scoutText)
	scoutText.TextScaled = true
	local accept = button(scout, "UNTERSCHREIBEN", GOLD, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -16),
		Size = UDim2.new(0.58, -27, 0, 42), TextScaled = true })
	local later = button(scout, "SPÄTER", Color3.fromRGB(60, 66, 84), { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -16),
		Size = UDim2.new(0.42, -27, 0, 42), TextColor3 = Color3.new(1, 1, 1), TextScaled = true })
	for _, b in ipairs({ accept, later }) do
		make("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10 }, b)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	end
	accept.Activated:Connect(function()
		scout.Visible = false
		remote:FireServer("AcceptScout")
	end)
	later.Activated:Connect(function() scout.Visible = false end)

	------------------------------------------------------------ Shop (Fashion District)
	local shop = panel("FASHION DISTRICT", PINK, 460, 360)
	make("TextLabel", { Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -36, 0, 18), TextSize = 12, TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "Nur Optik im Matchtrikot · bezahlt mit Pitch Coins aus deinen Matches" }, shop)
	-- scrollbar, falls die Liste auf kleinen Bildschirmen (Querformat) nicht ganz passt
	local listFrame = make("ScrollingFrame", { Position = UDim2.fromOffset(18, 66), Size = UDim2.new(1, -30, 1, -80), BackgroundTransparency = 1,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = PINK }, shop)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
	local catalog = {}

	local function has(attr, id)
		return string.find("," .. (player:GetAttribute(attr) or "") .. ",", "," .. id .. ",", 1, true) ~= nil
	end
	local function renderShop()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local coins = player:GetAttribute("PitchCoins") or 0
		for i, it in ipairs(catalog) do
			local row = corner(make("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.fromRGB(22, 28, 42) }, listFrame), 8)
			corner(make("Frame", { Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = it.color }, row), 6)
			make("TextLabel", { Position = UDim2.fromOffset(58, 8), Size = UDim2.new(1, -210, 0, 22), Text = it.name, TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left }, row)
			make("TextLabel", { Position = UDim2.fromOffset(58, 30), Size = UDim2.new(1, -210, 0, 18), Text = SLOT_NAME[it.slot] or it.slot,
				TextSize = 12, TextTransparency = 0.35, TextXAlignment = Enum.TextXAlignment.Left }, row)
			local owned, equipped = has("CareerOwned", it.id), has("CareerEquipped", it.id)
			local text, color, kind
			if equipped then
				text, color, kind = "ANGELEGT", Color3.fromRGB(70, 255, 150), "Equip"
			elseif owned then
				text, color, kind = "ANLEGEN", ACCENT, "Equip"
			else
				text, color, kind = it.price .. " COINS", coins >= it.price and GOLD or Color3.fromRGB(90, 96, 112), "Buy"
			end
			local b = button(row, text, color, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(136, 38) })
			b.Activated:Connect(function() remote:FireServer(kind, it.id) end)
		end
	end
	for _, attr in ipairs({ "PitchCoins", "CareerOwned", "CareerEquipped" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if shop.Visible then renderShop() end
		end)
	end

	-- Fenster schließen, wenn der Spieler weggeht oder einem Match beitritt
	local function closeAll()
		shop.Visible, scout.Visible = false, false
	end
	player:GetAttributeChangedSignal("UP_Arena"):Connect(closeAll)
	task.spawn(function()
		while gui.Parent do
			task.wait(0.5)
			if shop.Visible or scout.Visible then
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local city = workspace:FindFirstChild("UltimatePitch") and workspace.UltimatePitch:FindFirstChild("City")
				local counter = city and city:FindFirstChild("ShopCounter")
				local npc = city and city:FindFirstChild("TalentScout")
				local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart")
				if shop.Visible and (not root or not counter or (root.Position - counter.Position).Magnitude > 18) then shop.Visible = false end
				if scout.Visible and (not root or not npcRoot or (root.Position - npcRoot.Position).Magnitude > 18) then scout.Visible = false end
			end
		end
	end)

	remote.OnClientEvent:Connect(function(kind, arg)
		if kind == "Toast" and type(arg) == "string" then
			toast(arg)
		elseif kind == "ScoutOffer" then
			shop.Visible = false
			scoutText.Text = "„Ich habe dein Spiel auf dem Street Court gesehen. So ein Talent sieht man nicht oft!\n\n"
				.. "Unterschreib bei unserem Talentprogramm – als Startgeld gibt es " .. tostring(arg) .. " Pitch Coins.“"
			accept.Text = "UNTERSCHREIBEN  +" .. tostring(arg)
			scout.Visible = true
		elseif kind == "OpenShop" and type(arg) == "table" then
			catalog = arg
			scout.Visible = false
			renderShop()
			shop.Visible = true
		end
	end)
end

return CareerUI
]==] ck.Parent = c
s.Parent = SSS
c.Parent = SPS
game:GetService("ChangeHistoryService"):SetWaypoint("UltimatePitch v0.5")
print("✅ UltimatePitch v0.5 installiert – Spielen drücken!")
