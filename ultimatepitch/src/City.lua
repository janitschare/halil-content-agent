-- UltimatePitch · ULTIMATE CITY, erster Bezirk (ModuleScript unter UltimatePitchServer)
-- Prozedural aus Roblox-Grundteilen; Palmen, Laternen und Bänke als Cube-3D-Meshes über Props.lua (ohne Vorlage
-- ebenfalls aus Grundteilen): Plaza mit Spawn, Stadionzugang zum SPECTRA DOME,
-- Umfeld des Bolzplatzes (Käfig, Stufen, Flutlicht) und drei Ladenfronten als Ausblick. Die Beitritts-Pads
-- werden hier nur gebaut; die Anmeldung selbst entscheidet der Server (siehe Server-Skript).
local City = {}
local Props = require(script.Parent:WaitForChild("Props"))

local ASPHALT = Color3.fromRGB(46, 50, 58)
local PAVING = Color3.fromRGB(150, 154, 164)
local PAVING_DARK = Color3.fromRGB(96, 100, 112)
local PLAZA = Color3.fromRGB(62, 66, 86)      -- M4: dunkler Glanzboden (nasser Look der Referenz)
local PLAZA_BAND = Color3.fromRGB(44, 48, 66)
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

-- Palme aus Grundteilen (Rückfall ohne Mesh-Vorlage): leicht gebogener Stamm aus vier Abschnitten, sieben Wedel, Kokosnüsse
local function palmParts(pos, lean, parent)
	local up = Vector3.new(0, 1, 0)
	local p = pos + Vector3.new(0, 1, 0)
	for i = 1, 4 do
		local dir = (up + lean * (i * 0.07)).Unit
		local nxt = p + dir * 3.6
		part({ Name = "PalmTrunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.8, 1.5 - i * 0.12, 1.5 - i * 0.12),
			CFrame = CFrame.lookAt((p + nxt) / 2, nxt) * CFrame.Angles(0, math.pi / 2, 0), Material = Enum.Material.Wood,
			Color = i % 2 == 0 and Color3.fromRGB(110, 80, 52) or Color3.fromRGB(96, 68, 44) }, parent)
		p = nxt
	end
	for i = 0, 6 do
		local yaw = i / 7 * math.pi * 2
		deco({ Name = "PalmFrond", Size = Vector3.new(1.9, 0.25, 8.6),
			CFrame = CFrame.new(p) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-24 - (i % 2) * 10), 0, 0) * CFrame.new(0, 0, -4.1),
			Material = Enum.Material.SmoothPlastic, Color = i % 2 == 0 and Color3.fromRGB(46, 140, 70) or Color3.fromRGB(36, 116, 58) }, parent)
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		deco({ Name = "Coconut", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = p + Vector3.new(math.cos(a) * 0.7, -0.6, math.sin(a) * 0.7),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(80, 56, 30) }, parent)
	end
end

-- Palme (M4, Art Direction) im Pflanzkübel mit goldener Kante. Krone und Stamm als Cube-3D-Mesh (Props "Palm"),
-- gedreht nach der Neigung; das Mesh selbst kollidiert nicht, ein unsichtbarer Zylinder hält Spieler am Stamm auf.
local function palm(pos, lean, parent)
	local yaw = math.atan2(-lean.X, -lean.Z)
	if Props.place("Palm", CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, yaw, 0), parent,
		{ Name = "PalmMesh", CanCollide = false, CanQuery = false, CanTouch = false }) then
		part({ Name = "PalmTrunkCollider", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 1.4, 1.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1, CastShadow = false }, parent)
	else
		palmParts(pos, lean, parent)
	end
	part({ Name = "Planter", Size = Vector3.new(5, 1, 5), Position = pos + Vector3.new(0, 0.5, 0),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(28, 30, 42) }, parent)
	-- goldene Leuchtkante am Kübelrand (nur der Rand, nicht die ganze Fläche)
	for _, e in ipairs({ { 0, 2.45, 5.2, 0.3 }, { 0, -2.45, 5.2, 0.3 }, { 2.45, 0, 0.3, 4.6 }, { -2.45, 0, 0.3, 4.6 } }) do
		deco({ Name = "PlanterGlow", Size = Vector3.new(e[3], 0.12, e[4]), Position = pos + Vector3.new(e[1], 1.02, e[2]), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 196, 64) }, parent)
	end
end

-- Laterne: Cube-3D-Mesh (Props "StreetLamp"), Ausleger zu faceTo gedreht, Licht am Lampenkopf; sonst Mast mit Leuchtkopf
local function lamp(pos, parent, faceTo)
	local mesh = Props.place("StreetLamp", CFrame.lookAt(pos, Vector3.new(faceTo.X, pos.Y, faceTo.Z)), parent, { Name = "StreetLamp" })
	if mesh then
		local head = mesh:GetAttribute("HeadOffset")
		local a = Instance.new("Attachment")
		a.Name = "LampLight"
		a.Position = (typeof(head) == "Vector3" and head or Vector3.new(0, mesh.Size.Y / 2, 0)) - Vector3.new(0, 0.7, 0)
		a.Parent = mesh
		local glow = Instance.new("PointLight")
		glow.Range = 28
		glow.Brightness = 0.8
		glow.Color = Color3.fromRGB(255, 236, 200)
		glow.Parent = a
		return
	end
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
	if Props.place("Bench", cf, parent, { Name = "Bench" }) then return end -- Cube-3D-Mesh, Sitzfläche nach -Z
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
	bb.Size = UDim2.fromScale(13, 3.6) -- in Studs: wird mit der Entfernung kleiner und verdeckt die Dome-Fassade nicht
	bb.StudsOffset = Vector3.new(0, 5, 0) -- tief genug, damit es die Videowand der Dome-Fassade nicht verdeckt
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
		Material = Enum.Material.SmoothPlastic, Color = PLAZA, Reflectance = 0.12 }, city)
	for i = -2, 2 do
		deco({ Name = "PlazaBand", Size = Vector3.new(110, 0.05, 1.2), Position = G(px, 0.14, pz + i * 16),
			Material = Enum.Material.SmoothPlastic, Color = PLAZA_BAND, Reflectance = 0.1 }, city)
	end
	-- Mittelpunkt: Emblem-Scheibe mit Leuchtring (darauf steht das UP-Monument aus CityLook)
	deco({ Name = "EmblemRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 30, 30),
		CFrame = CFrame.new(G(px, 0.16, pz)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Neon, Color = CYAN }, city)
	local emblem = part({ Name = "Emblem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 27, 27),
		CFrame = CFrame.new(G(px, 0.2, pz)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Slate, Color = Color3.fromRGB(18, 24, 40) }, city)
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

	-- Palmen, Laternen, Bänke rund um die Plaza
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			palm(G(px + sx * 50, 0, pz - 30 + i * 30), Vector3.new(-sx, 0, (i - 1) * 0.6), city)
			lamp(G(px + sx * 40, 0, pz - 36 + i * 36), city, G(px, 0, pz - 36 + i * 36))
		end
		bench(G(px + sx * 30, 0, pz - 18), sx * math.pi / 2, city)
		bench(G(px + sx * 30, 0, pz + 18), sx * math.pi / 2, city)
	end

	-- Stadionzugang: Weg von der Plaza, Torbogen mit Schild, Beitritts-Pad davor
	local sp = L.stadiumPad
	part({ Name = "StadiumWalk", Size = Vector3.new(26, 0.2, math.abs(sp.Z - 14 - (pz + 42)) + 30), Position = G(sp.X, 0.03, (sp.Z + 14 + pz + 42) / 2),
		Material = Enum.Material.SmoothPlastic, Color = PLAZA, Reflectance = 0.12 }, city)
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "GatePylon", Size = Vector3.new(4, 16, 4), Position = G(sp.X + sx * 15, 8, sp.Z + 12),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(20, 24, 36) }, city)
		deco({ Name = "GateLED", Size = Vector3.new(0.4, 14, 0.4), Position = G(sp.X + sx * 15, 8, sp.Z + 9.8),
			Material = Enum.Material.Neon, Color = CYAN }, city)
	end
	-- niedriges Tor (M4): die Videowand der Dome-Fassade bleibt von der Plaza aus frei sichtbar
	local header = part({ Name = "GateHeader", Size = Vector3.new(38, 4, 3), Position = G(sp.X, 14, sp.Z + 12),
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
		Material = Enum.Material.SmoothPlastic, Color = PLAZA, Reflectance = 0.12 }, city)

	-- Ladenfronten: Fashion District ist seit M3 geöffnet (Theke und Shop im Career-Modul). Die Schaufenster von Fashion
	-- District und Player Agency baut CityLook (M4); Glasfenster und Hinweisschild hier nur noch an der Academy.
	local SHOPS = { { "FASHION DISTRICT", Color3.fromRGB(255, 90, 170) }, { "FOOTBALL ACADEMY", Color3.fromRGB(70, 255, 150) }, { "PLAYER AGENCY", GOLD } }
	for i, shop in ipairs(SHOPS) do
		local x = px - 56 + (i - 1) * 56
		local z = pz - 42 - 22
		part({ Name = "ShopBody", Size = Vector3.new(48, 34, 26), Position = G(x, 17, z),
			Material = Enum.Material.Concrete, Color = Color3.fromRGB(34 + i * 6, 38 + i * 6, 52 + i * 6) }, city)
		if i == 2 then
			deco({ Name = "ShopWindow", Size = Vector3.new(36, 12, 0.3), Position = G(x, 8, z + 13.1),
				Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 200, 255), Transparency = 0.35 }, city)
		end
		deco({ Name = "ShopTrim", Size = Vector3.new(48.4, 0.6, 0.6), Position = G(x, 16, z + 13.2), Material = Enum.Material.Neon, Color = shop[2] }, city)
		local sb = part({ Name = "ShopSign", Size = Vector3.new(40, 6, 0.6), Position = G(x, 21, z + 13.4),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 14, 24) }, city)
		sign(sb, Enum.NormalId.Back, shop[1], shop[2])
		if i == 2 then
			local soon = part({ Name = "ShopSoon", Size = Vector3.new(16, 2.4, 0.4), Position = G(x, 3.4, z + 13.5),
				Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 14, 24) }, city)
			sign(soon, Enum.NormalId.Back, "ERÖFFNET BALD", Color3.new(1, 1, 1))
		end
	end

	city.Parent = parent
	return { folder = city, pads = pads, spawn = spawn }
end

return City
