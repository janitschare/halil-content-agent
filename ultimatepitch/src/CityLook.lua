-- UltimatePitch · City Look (M4, ModuleScript unter UltimatePitchServer)
-- Baut die Abend-Optik des ersten Bezirks nach der Art Direction vom 11.11.2026 (docs/art): UP-Monument mit Brunnen,
-- Wegweiser, Live-Rangliste, Fassade des SPECTRA DOME (LED, Banner, Videowand, Stadioneingang, Lichtkegel),
-- Graffiti und Zuschauer am Street Court, Schaufenster von Fashion District und Player Agency, Sportwagen, Fahnen.
-- Roblox-Grundteile, SurfaceGuis und eingebaute Schriften/Partikel. Sportwagen, Sneaker und Schreibtisch als Cube-3D-Meshes
-- (Props.lua, ServerStorage.UP_Props; eigene Assets ohne Logos/Marken), ohne Vorlage wie bisher aus Grundteilen.
-- Tags für die Clients (Grafikprofil): "UP_CityDetail" = reine Deko ohne Kollision, wird auf „Niedrig“ lokal entfernt;
-- "UP_CityFX" = Partikel, Lichtkegel, Lichtquellen und dekorative SurfaceGuis, auf „Niedrig“ aus; "UP_Spin" = Modell, das der Client langsam dreht.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local CityLook = {}
local Props = require(script.Parent:WaitForChild("Props"))

local GOLD = Color3.fromRGB(255, 196, 64)
local CYAN = Color3.fromRGB(40, 210, 255)
local VIOLET = Color3.fromRGB(150, 70, 255)
local PINK = Color3.fromRGB(255, 70, 170)
local NIGHT = Color3.fromRGB(12, 14, 24)
local STEEL = Color3.fromRGB(70, 78, 96)
local WHITE = Color3.new(1, 1, 1)

-- Außenwand des SPECTRA DOME (Dome.lua: Innenkante 118/74 + Rückwand-Abstand 57,8; Wand 1,5 dick, 48 hoch)
local DOME_A, DOME_B = 175.8, 131.8

local function part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
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

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

local function surface(p, face, ppS, brightness)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppS or 20
	gui.LightInfluence = 0
	gui.Brightness = brightness or 1
	gui.Parent = p
	return gui
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = WHITE
	l.TextScaled = true
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end

-- Krone aus Grundteilen: cf = Mitte der Grundlinie, LookVector = Blickrichtung (Vorderseite), w = Breite
local function crown(cf, w, parent, color)
	color = color or GOLD
	local h = w * 0.26
	local d = w * 0.12
	local m = Instance.new("Model")
	m.Name = "Crown"
	deco({ Name = "CrownBand", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Material = Enum.Material.Neon, Color = color }, m)
	for i, x in ipairs({ -0.36, 0, 0.36 }) do
		local s = (i == 2 and 0.34 or 0.26) * w
		local top = h * 0.55 + s * 0.707
		deco({ Name = "CrownSpike", Size = Vector3.new(s, s, d * 0.6), CFrame = cf * CFrame.new(x * w, h * 0.55, 0) * CFrame.Angles(0, 0, math.pi / 4),
			Material = Enum.Material.Neon, Color = color }, m)
		deco({ Name = "CrownGem", Shape = Enum.PartType.Ball, Size = Vector3.one * w * 0.1, CFrame = cf * CFrame.new(x * w, top, 0),
			Material = Enum.Material.Neon, Color = color }, m)
	end
	m.Parent = parent
	return m
end

-- Punkt und Außennormale auf der Dome-Außenwand (d = Abstand nach außen)
local function domePoint(theta, d)
	return Vector3.new((DOME_A + d) * math.cos(theta), 0, (DOME_B + d) * math.sin(theta))
end
local function domeNormal(theta)
	return Vector3.new(math.cos(theta) / DOME_A, 0, math.sin(theta) / DOME_B).Unit
end

---------------------------------------------------------------- Plaza-Monument: leuchtender Ball auf UP-Sockel
local function monument(parent, c)
	local m = Instance.new("Model")
	m.Name = "UP_Monument"
	local up = CFrame.Angles(0, 0, math.pi / 2) -- Zylinderachse senkrecht
	part({ Name = "Basin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 25, 25), CFrame = CFrame.new(c + Vector3.new(0, 0.8, 0)) * up,
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(30, 34, 50), Reflectance = 0.1 }, m)
	deco({ Name = "BasinGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 25.7, 25.7), CFrame = CFrame.new(c + Vector3.new(0, 1.3, 0)) * up,
		Material = Enum.Material.Neon, Color = CYAN }, m)
	deco({ Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 23.4, 23.4), CFrame = CFrame.new(c + Vector3.new(0, 1.66, 0)) * up,
		Material = Enum.Material.Glass, Color = Color3.fromRGB(50, 140, 230), Transparency = 0.25, Reflectance = 0.2 }, m)
	-- Sockel mit UP-Schriftzug auf allen Seiten, goldene Kanten
	local plinth = part({ Name = "Plinth", Size = Vector3.new(8, 6, 8), Position = c + Vector3.new(0, 4.6, 0),
		Material = Enum.Material.SmoothPlastic, Color = NIGHT, Reflectance = 0.08 }, m)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			deco({ Name = "PlinthEdge", Size = Vector3.new(0.3, 6, 0.3), Position = c + Vector3.new(sx * 4, 4.6, sz * 4), Material = Enum.Material.Neon, Color = GOLD }, m)
		end
	end
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		local gui = surface(plinth, face, 24, 1.3)
		label(gui, { Position = UDim2.fromScale(0.08, 0.32), Size = UDim2.fromScale(0.84, 0.46), Text = "UP", TextColor3 = GOLD })
		label(gui, { Position = UDim2.fromScale(0.05, 0.8), Size = UDim2.fromScale(0.9, 0.12), Text = "ULTIMATE PITCH", Font = Enum.Font.GothamBold })
	end
	for _, dir in ipairs({ Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) }) do
		local base = c + Vector3.new(0, 5.9, 0) + dir * 4.05
		crown(CFrame.lookAt(base, base + dir), 3.4, m)
	end
	-- Ball: Glashülle, leuchtender Kern, 12 Felder (Ikosaeder-Ecken); dreht sich auf dem Client langsam
	local center = c + Vector3.new(0, 7.6 + 5.9, 0)
	local ball = Instance.new("Model")
	ball.Name = "UP_MonumentBall"
	-- undurchsichtiger Leuchtkern (eine Glashülle würde den Kern in Roblox abdunkeln)
	local core = deco({ Name = "BallCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 11.4, Position = center,
		Material = Enum.Material.Neon, Color = Color3.fromRGB(110, 200, 255) }, ball)
	local phi = (1 + math.sqrt(5)) / 2
	local verts = {}
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			table.insert(verts, Vector3.new(0, a, b * phi))
			table.insert(verts, Vector3.new(a, b * phi, 0))
			table.insert(verts, Vector3.new(b * phi, 0, a))
		end
	end
	for _, v in ipairs(verts) do
		local n = v.Unit
		deco({ Name = "BallPatch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4),
			CFrame = CFrame.lookAt(center + n * 5.72, center + n * 7) * CFrame.Angles(0, math.pi / 2, 0),
			Material = Enum.Material.SmoothPlastic, Color = NIGHT }, ball)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = CYAN, 34, 2.2
	light.Parent = core
	tag(light, "UP_CityFX")
	ball.WorldPivot = CFrame.new(center)
	ball:SetAttribute("SpinSpeed", 14)
	tag(ball, "UP_Spin")
	ball.Parent = m
	-- Umlaufring in Gold (geneigt), dreht sich gegenläufig
	local ring = Instance.new("Model")
	ring.Name = "UP_MonumentRing"
	local R, N = 8.4, 28
	local tilt = CFrame.new(center) * CFrame.Angles(math.rad(18), 0, math.rad(8))
	for i = 0, N - 1 do
		local a = i / N * math.pi * 2
		local p = tilt * CFrame.new(R * math.cos(a), 0, R * math.sin(a))
		deco({ Name = "RingSeg", Size = Vector3.new(0.35, 0.35, 2 * math.pi * R / N + 0.2),
			CFrame = CFrame.lookAt(p.Position, p.Position + (tilt.RightVector * -math.sin(a) + tilt.LookVector * -math.cos(a))),
			Material = Enum.Material.Neon, Color = GOLD }, ring)
	end
	ring.WorldPivot = CFrame.new(center)
	ring:SetAttribute("SpinSpeed", -32)
	tag(ring, "UP_Spin")
	tag(ring, "UP_CityDetail")
	ring.Parent = m
	-- Brunnen: vier Wasserstrahlen vom Beckenrand schräg nach innen
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local inward = -Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = c + Vector3.new(0, 1.8, 0) - inward * 9.5
		local dir = (inward * 0.45 + Vector3.new(0, 1, 0)).Unit
		local tangent = Vector3.yAxis:Cross(inward).Unit
		local host = deco({ Name = "FountainJet", Size = Vector3.one * 0.4, CFrame = CFrame.fromMatrix(pos, tangent, dir), Transparency = 1 }, m)
		local e = Instance.new("ParticleEmitter")
		e.Rate = 24
		e.Lifetime = NumberRange.new(1.0, 1.25)
		e.Speed = NumberRange.new(19, 22)
		e.SpreadAngle = Vector2.new(4, 4)
		e.Acceleration = Vector3.new(0, -34, 0)
		e.Drag = 0.3
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.15) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.9) })
		e.Color = ColorSequence.new(Color3.fromRGB(175, 225, 255))
		e.LightEmission = 0.5
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = host
		tag(e, "UP_CityFX")
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------- Wegweiser
-- entries: { text, target = Vector3 (Weltpunkt, in dessen Richtung der Pfeil zeigt), color, soon = bool }
local function signpost(parent, pos, entries)
	local m = Instance.new("Model")
	m.Name = "Signpost"
	part({ Name = "SignPole", Size = Vector3.new(0.8, 17, 0.8), Position = pos + Vector3.new(0, 8.5, 0), Material = Enum.Material.Metal, Color = NIGHT }, m)
	deco({ Name = "SignCap", Size = Vector3.new(1.2, 0.4, 1.2), Position = pos + Vector3.new(0, 17.2, 0), Material = Enum.Material.Neon, Color = GOLD }, m)
	for i, e in ipairs(entries) do
		local y = 15.6 - (i - 1) * 1.95
		local d = Vector3.new(e.target.X - pos.X, 0, e.target.Z - pos.Z).Unit
		local mid = pos + Vector3.new(0, y, 0) + d * 5
		local cf = CFrame.lookAt(mid, mid + d)
		local board = part({ Name = "SignBoard", Size = Vector3.new(0.35, 1.55, 8.4), CFrame = cf, Material = Enum.Material.SmoothPlastic,
			Color = e.soon and Color3.fromRGB(30, 32, 42) or NIGHT, CanCollide = false }, m)
		deco({ Name = "SignTip", Size = Vector3.new(0.35, 1.1, 1.1), CFrame = cf * CFrame.new(0, 0, -4.2) * CFrame.Angles(math.pi / 4, 0, 0),
			Material = Enum.Material.SmoothPlastic, Color = board.Color }, m)
		deco({ Name = "SignStripe", Size = Vector3.new(0.4, 0.14, 8.4), CFrame = cf * CFrame.new(0, -0.7, 0), Material = Enum.Material.Neon,
			Color = e.soon and Color3.fromRGB(110, 114, 130) or e.color }, m)
		for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
			local gui = surface(board, face, 30, 1.2)
			label(gui, { Position = UDim2.fromScale(0.04, 0.1), Size = UDim2.fromScale(0.92, 0.7), Text = e.text .. (e.soon and "  ·  BALD" or ""),
				TextColor3 = e.soon and Color3.fromRGB(150, 156, 172) or WHITE })
		end
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------- Live-Rangliste (Pitch Coins der Spieler auf diesem Server)
local function leaderboard(parent, pos, lookAt)
	local m = Instance.new("Model")
	m.Name = "Leaderboard"
	local cf = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "BoardPost", Size = Vector3.new(0.9, 12, 0.9), CFrame = cf * CFrame.new(sx * 8.6, 6, 0.4), Material = Enum.Material.Metal, Color = NIGHT }, m)
	end
	local screen = part({ Name = "BoardScreen", Size = Vector3.new(18, 11, 0.8), CFrame = cf * CFrame.new(0, 9.6, 0),
		Material = Enum.Material.SmoothPlastic, Color = NIGHT }, m)
	for _, y in ipairs({ -5.6, 5.6 }) do
		deco({ Name = "BoardTrim", Size = Vector3.new(18.4, 0.3, 0.9), CFrame = cf * CFrame.new(0, 9.6 + y, 0), Material = Enum.Material.Neon, Color = GOLD }, m)
	end
	crown(cf * CFrame.new(0, 15.3, 0), 4, m)
	local gui = surface(screen, Enum.NormalId.Front, 28, 1.25)
	frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 14, 30) })
	label(gui, { Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.16), Text = "RANGLISTE", TextColor3 = GOLD })
	label(gui, { Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.07), Text = "PITCH COINS  ·  LIVE AUF DIESEM SERVER",
		Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(170, 185, 220) })
	local rows = {}
	for i = 1, 5 do
		local row = frame(gui, { Position = UDim2.fromScale(0.05, 0.3 + (i - 1) * 0.134), Size = UDim2.fromScale(0.9, 0.115),
			BackgroundColor3 = i == 1 and Color3.fromRGB(60, 46, 14) or Color3.fromRGB(22, 28, 50), BackgroundTransparency = 0.1 })
		Instance.new("UICorner", row).CornerRadius = UDim.new(0.2, 0)
		label(row, { Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.08, 0.8), Text = tostring(i), TextColor3 = i == 1 and GOLD or WHITE })
		rows[i] = {
			name = label(row, { Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.5, 0.76), Text = "—", TextXAlignment = Enum.TextXAlignment.Left }),
			stage = label(row, { Position = UDim2.fromScale(0.6, 0.25), Size = UDim2.fromScale(0.18, 0.5), Text = "", Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(170, 185, 220) }),
			coins = label(row, { Position = UDim2.fromScale(0.78, 0.12), Size = UDim2.fromScale(0.2, 0.76), Text = "", TextColor3 = GOLD,
				TextXAlignment = Enum.TextXAlignment.Right }),
		}
	end
	m.Parent = parent
	return function(list)
		for i, r in ipairs(rows) do
			local e = list[i]
			local name, stage, coins = e and e.name or "—", e and e.stage or "", e and tostring(e.coins) or ""
			if r.name.Text ~= name then r.name.Text = name end
			if r.stage.Text ~= stage then r.stage.Text = stage end
			if r.coins.Text ~= coins then r.coins.Text = coins end
		end
	end
end

---------------------------------------------------------------- Fassade des SPECTRA DOME (Südseite zur Plaza)
local function domeFacade(parent, gy)
	local f = Instance.new("Folder")
	f.Name = "DomeFacade"
	-- LED-Bänder entlang der Außenwand (nur die zur Stadt gewandte Hälfte) und senkrechte Lichtlisenen
	local SEG = 24
	for i = 0, SEG - 1 do
		local t1, t2 = math.pi + i / SEG * math.pi, math.pi + (i + 1) / SEG * math.pi
		for _, band in ipairs({ { y = 8, h = 0.7, color = CYAN }, { y = 45.6, h = 1, color = VIOLET } }) do
			local p1, p2 = domePoint(t1, 1), domePoint(t2, 1)
			local mid = (p1 + p2) / 2 + Vector3.new(0, gy + band.y, 0)
			deco({ Name = "FacadeLED", Size = Vector3.new(0.3, band.h, (p2 - p1).Magnitude + 0.3), CFrame = CFrame.lookAt(mid, mid + (p2 - p1)),
				Material = Enum.Material.Neon, Color = band.color }, f)
		end
		if i % 3 == 0 and i > 0 then
			local p = domePoint(t1, 1) + Vector3.new(0, gy + 27, 0)
			tag(deco({ Name = "FacadePilaster", Size = Vector3.new(0.35, 36, 0.35), Position = p, Material = Enum.Material.Neon,
				Color = (i / 3) % 2 == 0 and VIOLET or CYAN }, f), "UP_CityDetail")
		end
	end
	-- Kronen-Banner links und rechts der Videowand
	for k, off in ipairs({ -0.19, -0.135, -0.08, 0.08, 0.135, 0.19 }) do
		local th = 1.5 * math.pi + off * math.pi
		local n = domeNormal(th)
		local p = domePoint(th, 1.4) + Vector3.new(0, gy + 24, 0)
		local cf = CFrame.lookAt(p, p + n)
		local banner = part({ Name = "DomeBanner", Size = Vector3.new(7, 20, 0.3), CFrame = cf, Material = Enum.Material.Fabric,
			Color = k % 2 == 0 and Color3.fromRGB(120, 24, 48) or Color3.fromRGB(70, 26, 130), CanCollide = false }, f)
		for _, y in ipairs({ -9.85, 9.85 }) do
			deco({ Name = "BannerTrim", Size = Vector3.new(7.2, 0.4, 0.4), CFrame = cf * CFrame.new(0, y, 0), Material = Enum.Material.Neon, Color = GOLD }, f)
		end
		crown(cf * CFrame.new(0, 3.2, -0.25), 4.4, f)
		local gui = tag(surface(banner, Enum.NormalId.Front, 16, 1.2), "UP_CityFX")
		label(gui, { Position = UDim2.fromScale(0.08, 0.48), Size = UDim2.fromScale(0.84, 0.2), Text = "UP", TextColor3 = GOLD })
		label(gui, { Position = UDim2.fromScale(0.06, 0.7), Size = UDim2.fromScale(0.88, 0.06), Text = "ULTIMATE PITCH", Font = Enum.Font.GothamBold })
	end
	-- Name, Videowand und Stadioneingang am Scheitel der Südseite (Blick zur Plaza = -Z)
	local apex = domePoint(1.5 * math.pi, 0)
	local out = Vector3.new(0, 0, -1)
	local function at(y, d) local p = apex + out * d + Vector3.new(0, gy + y, 0) return CFrame.lookAt(p, p + out) end
	local nameBoard = part({ Name = "DomeName", Size = Vector3.new(58, 6, 1), CFrame = at(40.5, 3.2), Material = Enum.Material.SmoothPlastic, Color = NIGHT }, f)
	local ng = surface(nameBoard, Enum.NormalId.Front, 16, 1.4)
	label(ng, { Size = UDim2.fromScale(1, 1), Text = "SPECTRA DOME", TextColor3 = WHITE, TextStrokeColor3 = CYAN, TextStrokeTransparency = 0.2 })
	crown(at(43.5, 3.6), 5.2, f)
	part({ Name = "ScreenBack", Size = Vector3.new(67, 19.5, 4), CFrame = at(27, 1.8), Material = Enum.Material.Metal, Color = NIGHT }, f)
	local screen = part({ Name = "VideoWall", Size = Vector3.new(64, 16, 0.6), CFrame = at(27, 4), Material = Enum.Material.SmoothPlastic, Color = NIGHT }, f)
	for _, y in ipairs({ -8.6, 8.6 }) do
		deco({ Name = "ScreenTrim", Size = Vector3.new(67, 0.45, 0.6), CFrame = at(27 + y, 4.1), Material = Enum.Material.Neon, Color = VIOLET }, f)
	end
	local sg = surface(screen, Enum.NormalId.Front, 14, 1.5)
	local bg = frame(sg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 10, 40) })
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 20, 120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 12, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 60, 120)) })
	grad.Parent = bg
	label(sg, { Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.94, 0.12), Text = "ULTIMATE PITCH  ·  SPECTRA DOME", TextColor3 = GOLD,
		Font = Enum.Font.GothamBold })
	local main = label(sg, { Position = UDim2.fromScale(0.04, 0.25), Size = UDim2.fromScale(0.92, 0.4), Text = "VOM BOLZPLATZ ZUM SUPERSTAR",
		Font = Enum.Font.LuckiestGuy, TextStrokeColor3 = VIOLET, TextStrokeTransparency = 0.1 })
	local ticker = frame(sg, { Position = UDim2.fromScale(0, 0.76), Size = UDim2.fromScale(1, 0.24), BackgroundColor3 = Color3.fromRGB(8, 8, 18) })
	local tickerText = label(ticker, { Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.94, 0.7), Text = "", TextColor3 = CYAN })
	-- Eingangsportal mit Tunnel-Leuchtrahmen (der eigentliche Beitritt ist das Pad vor dem Tor)
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "PortalColumn", Size = Vector3.new(3, 16, 5), CFrame = at(8, 2.5) * CFrame.new(sx * 14.5, 0, 0), Material = Enum.Material.Metal, Color = NIGHT }, f)
		deco({ Name = "PortalLED", Size = Vector3.new(0.4, 15, 0.4), CFrame = at(8, 5.1) * CFrame.new(sx * 13, 0, 0), Material = Enum.Material.Neon, Color = CYAN }, f)
	end
	local beam = part({ Name = "PortalBeam", Size = Vector3.new(32, 4, 5), CFrame = at(15, 2.5), Material = Enum.Material.Metal, Color = NIGHT }, f)
	label(surface(beam, Enum.NormalId.Front, 20, 1.3), { Size = UDim2.fromScale(1, 1), Text = "STADION EINGANG", TextColor3 = CYAN })
	deco({ Name = "TunnelBack", Size = Vector3.new(26, 13, 0.4), CFrame = at(6.5, 1.4), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(6, 8, 16) }, f)
	for k, s in ipairs({ 1, 0.78, 0.58 }) do
		local w, h, y = 25 * s, 12.5 * s, 6.5 - (1 - s) * 3
		local d = 1.4 + k * 0.45
		for _, e in ipairs({ { 0, h / 2, w, 0.25 }, { -w / 2, 0, 0.25, h }, { w / 2, 0, 0.25, h } }) do
			tag(deco({ Name = "TunnelFrame", Size = Vector3.new(e[3], e[4], 0.2), CFrame = at(y, d) * CFrame.new(e[1], e[2], 0),
				Material = Enum.Material.Neon, Color = k == 2 and VIOLET or CYAN }, f), "UP_CityDetail")
		end
	end
	-- Lichtkegel vom Dachrand in den Abendhimmel
	for k, off in ipairs({ -0.32, -0.12, 0.12, 0.32 }) do
		local th = 1.5 * math.pi + off * math.pi
		local base = domePoint(th, -2) + Vector3.new(0, gy + 49, 0)
		local host = deco({ Name = "SearchLight", Size = Vector3.new(1.6, 0.8, 1.6), Position = base, Material = Enum.Material.Neon,
			Color = k % 2 == 0 and VIOLET or CYAN }, f)
		local a0 = Instance.new("Attachment")
		a0.Parent = host
		local a1 = Instance.new("Attachment")
		a1.Parent = host
		a1.WorldPosition = base + Vector3.new(off * 260, 260, -60 + math.abs(off) * 80)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = 2.5, 18
		b.Color = ColorSequence.new(host.Color)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
		b.LightEmission, b.LightInfluence = 1, 0
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = host
		tag(b, "UP_CityFX")
	end
	f.Parent = parent
	return main, tickerText
end

---------------------------------------------------------------- Graffiti (SurfaceGui mit eingebauten Schriften)
local SPRAY = { Color3.fromRGB(255, 70, 170), Color3.fromRGB(150, 70, 255), Color3.fromRGB(40, 210, 255), Color3.fromRGB(255, 196, 64),
	Color3.fromRGB(255, 90, 60), Color3.fromRGB(70, 255, 150) }
local function graffiti(p, face, seed, texts)
	local rng = Random.new(seed)
	local gui = tag(surface(p, face, 14, 1.15), "UP_CityFX")
	frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 72, 82) })
	for _ = 1, 9 do
		local s = rng:NextNumber(0.25, 0.6)
		local blob = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.15, 0.85)),
			Size = UDim2.fromScale(s * 0.4, s * 1.4), BackgroundColor3 = SPRAY[rng:NextInteger(1, #SPRAY)], BackgroundTransparency = rng:NextNumber(0.15, 0.45),
			Rotation = rng:NextNumber(-30, 30) })
		Instance.new("UICorner", blob).CornerRadius = UDim.new(0.5, 0)
	end
	for _, t in ipairs(texts) do
		local l = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(t.x, t.y), Size = UDim2.fromScale(t.w, t.h), Text = t.text,
			Font = t.font, TextColor3 = t.color, Rotation = t.rot or 0 })
		local stroke = Instance.new("UIStroke")
		stroke.Thickness, stroke.Color = t.stroke or 3, Color3.fromRGB(12, 10, 20)
		stroke.Parent = l
	end
end

---------------------------------------------------------------- Figuren (Zuschauer, Schaufensterpuppen, Agent)
local function figure(parent, cf, colors, opts)
	opts = opts or {}
	local model
	pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = colors.head or Color3.fromRGB(198, 150, 110)
		desc.TorsoColor = colors.shirt
		desc.LeftArmColor, desc.RightArmColor = colors.arms or colors.shirt, colors.arms or colors.shirt
		desc.LeftLegColor, desc.RightLegColor = colors.legs, colors.legs
		model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not model then return nil end
	model.Name = opts.name or "CityFigure"
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		elseif opts.faceless and d:IsA("Decal") and d.Name == "face" then
			d:Destroy()
		end
	end
	if opts.chest then
		local torso = model:FindFirstChild("UpperTorso")
		if torso then label(surface(torso, Enum.NormalId.Front, 40, 1), { Position = UDim2.fromScale(0.25, 0.2), Size = UDim2.fromScale(0.5, 0.5),
			Text = opts.chest, TextColor3 = GOLD }) end
	end
	-- Füße auf den Boden: Unterkante des Modells an die Zielhöhe setzen
	model:PivotTo(cf)
	local bbCF, size = model:GetBoundingBox()
	model:PivotTo(cf + Vector3.new(0, cf.Position.Y - (bbCF.Position.Y - size.Y / 2), 0))
	tag(model, "UP_CityDetail")
	model.Parent = parent
	return model
end

---------------------------------------------------------------- Schaufenster vor einer Ladenfront
local function showcase(parent, x, facadeZ, gy, color)
	local m = Instance.new("Model")
	m.Name = "Showcase"
	local zc = facadeZ + 1.7
	part({ Name = "ShowcaseBase", Size = Vector3.new(34, 0.6, 3.4), Position = Vector3.new(x, gy + 3.7, zc), Material = Enum.Material.SmoothPlastic, Color = NIGHT }, m)
	part({ Name = "ShowcaseTop", Size = Vector3.new(34, 0.6, 3.4), Position = Vector3.new(x, gy + 14.3, zc), Material = Enum.Material.SmoothPlastic, Color = NIGHT }, m)
	deco({ Name = "ShowcaseBack", Size = Vector3.new(34, 10, 0.2), Position = Vector3.new(x, gy + 9, facadeZ + 0.15), Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(26, 22, 44) }, m)
	-- Scheibe bewusst nicht aus Glass-Material: Roblox blendet SurfaceGuis hinter Glas aus (Trikotnummern, Taktiktafel)
	part({ Name = "ShowcaseGlass", Size = Vector3.new(34, 10, 0.2), Position = Vector3.new(x, gy + 9, facadeZ + 3.35), Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(200, 220, 255), Transparency = 0.86, Reflectance = 0.2 }, m)
	for _, e in ipairs({ { 0, 4.05, 34.4, 0.35 }, { 0, 13.95, 34.4, 0.35 }, { -17.1, 9, 0.35, 10.2 }, { 17.1, 9, 0.35, 10.2 } }) do
		deco({ Name = "ShowcaseFrame", Size = Vector3.new(e[3], e[4], 0.35), Position = Vector3.new(x + e[1], gy + e[2], facadeZ + 3.5),
			Material = Enum.Material.Neon, Color = color }, m)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 14, 1.2
	light.Parent = m:FindFirstChild("ShowcaseTop")
	tag(light, "UP_CityFX")
	m.Parent = parent
	return m, gy + 4.0, zc
end

local function sneaker(parent, pos, color, yaw)
	local mesh = Props.place("Sneaker", CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0), parent,
		{ Name = "Sneaker", CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	if mesh then
		tag(mesh, "UP_CityDetail")
		return
	end
	tag(deco({ Name = "SneakerSole", Size = Vector3.new(0.7, 0.25, 1.6), Position = pos + Vector3.new(0, 0.12, 0), Material = Enum.Material.SmoothPlastic, Color = WHITE }, parent), "UP_CityDetail")
	tag(deco({ Name = "SneakerUpper", Size = Vector3.new(0.66, 0.55, 1.2), Position = pos + Vector3.new(0, 0.5, 0.15), Material = Enum.Material.SmoothPlastic, Color = color }, parent), "UP_CityDetail")
end

local function subSign(parent, cf, text, color, w)
	local p = part({ Name = "SubSign", Size = Vector3.new(w, 1.6, 0.4), CFrame = cf, Material = Enum.Material.SmoothPlastic, Color = NIGHT, CanCollide = false }, parent)
	label(surface(p, Enum.NormalId.Front, 30, 1.4), { Position = UDim2.fromScale(0.03, 0.12), Size = UDim2.fromScale(0.94, 0.76), Text = text, TextColor3 = color })
	return p
end

---------------------------------------------------------------- Sportwagen (Deko)
local function car(parent, cf, color, glow, meshName)
	local m = Instance.new("Model")
	m.Name = "SportCar"
	-- Cube-3D-Mesh (Vorderseite -Z wie die Bauteil-Version) mit Neon-Unterbodenlicht, das seitlich etwas hervorsteht
	if Props.place(meshName, cf, m, { Name = "CarMesh" }) then
		tag(deco({ Name = "CarUnderglow", Size = Vector3.new(7.6, 0.1, 11.4), CFrame = cf * CFrame.new(0, 0.12, 0), Material = Enum.Material.Neon, Color = glow }, m),
			"UP_CityDetail")
		m.Parent = parent
		return m
	end
	part({ Name = "CarBody", Size = Vector3.new(5.6, 1.4, 12), CFrame = cf * CFrame.new(0, 1.3, 0), Material = Enum.Material.SmoothPlastic, Color = color, Reflectance = 0.25 }, m)
	part({ ClassName = "WedgePart", Name = "CarHood", Size = Vector3.new(5.6, 0.8, 3.4), CFrame = cf * CFrame.new(0, 2.4, -4.3), Material = Enum.Material.SmoothPlastic,
		Color = color, Reflectance = 0.25 }, m)
	part({ Name = "CarCabin", Size = Vector3.new(4.6, 1.3, 4.2), CFrame = cf * CFrame.new(0, 2.65, 0.8), Material = Enum.Material.Glass,
		Color = Color3.fromRGB(18, 22, 32), Transparency = 0.1 }, m)
	part({ ClassName = "WedgePart", Name = "CarWindshield", Size = Vector3.new(4.6, 1.3, 2.2), CFrame = cf * CFrame.new(0, 2.65, -2.4), Material = Enum.Material.Glass,
		Color = Color3.fromRGB(18, 22, 32), Transparency = 0.1 }, m)
	part({ ClassName = "WedgePart", Name = "CarRear", Size = Vector3.new(4.6, 1.3, 1.6), CFrame = cf * CFrame.new(0, 2.65, 3.7) * CFrame.Angles(0, math.pi, 0),
		Material = Enum.Material.SmoothPlastic, Color = color, Reflectance = 0.25 }, m)
	deco({ Name = "CarSpoiler", Size = Vector3.new(5.4, 0.2, 1), CFrame = cf * CFrame.new(0, 2.75, 5.4), Material = Enum.Material.SmoothPlastic, Color = NIGHT }, m)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part({ Name = "CarWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 2.4, 2.4), CFrame = cf * CFrame.new(sx * 2.75, 1.2, sz * 3.8),
				Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(16, 16, 20) }, m)
			deco({ Name = "CarRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.16, 1.3, 1.3), CFrame = cf * CFrame.new(sx * 2.76, 1.2, sz * 3.8),
				Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 196, 210) }, m)
		end
		deco({ Name = "CarHeadlight", Size = Vector3.new(1.4, 0.35, 0.2), CFrame = cf * CFrame.new(sx * 1.9, 1.75, -6.05), Material = Enum.Material.Neon, Color = WHITE }, m)
		deco({ Name = "CarTaillight", Size = Vector3.new(1.6, 0.3, 0.2), CFrame = cf * CFrame.new(sx * 1.8, 1.75, 6.05), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 40, 60) }, m)
	end
	tag(deco({ Name = "CarUnderglow", Size = Vector3.new(4.8, 0.1, 10.4), CFrame = cf * CFrame.new(0, 0.35, 0), Material = Enum.Material.Neon, Color = glow }, m), "UP_CityDetail")
	m.Parent = parent
	return m
end

---------------------------------------------------------------- Fahnenmast mit Kronen-Banner
local function flagPole(parent, pos, color)
	part({ Name = "FlagPole", Size = Vector3.new(0.5, 16, 0.5), Position = pos + Vector3.new(0, 8, 0), Material = Enum.Material.Metal, Color = NIGHT }, parent)
	local b = deco({ Name = "FlagBanner", Size = Vector3.new(0.2, 9, 3.6), Position = pos + Vector3.new(0, 10.8, 0), Material = Enum.Material.Fabric, Color = color }, parent)
	tag(b, "UP_CityDetail")
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local gui = tag(surface(b, face, 16, 1.2), "UP_CityFX")
		label(gui, { Position = UDim2.fromScale(0.1, 0.12), Size = UDim2.fromScale(0.8, 0.3), Text = "UP", TextColor3 = GOLD })
		frame(gui, { Position = UDim2.fromScale(0, 0.94), Size = UDim2.fromScale(1, 0.06), BackgroundColor3 = GOLD })
	end
end

---------------------------------------------------------------- Aufbau
-- city = workspace.UltimatePitch.City, L = LAYOUT des Server-Skripts, state = Stadion-State (für die Videowand)
function CityLook.build(city, L, state)
	local gy = L.groundY
	local px, pz = L.plaza.X, L.plaza.Z
	local function G(x, y, z) return Vector3.new(x, gy + y, z) end
	local look = Instance.new("Folder")
	look.Name = "CityLook"

	-- Plaza: Monument in der Mitte, Leuchtkanten, Rangliste und Wegweiser
	monument(look, G(px, 0, pz))
	for _, e in ipairs({ { 0, 42, 110, 0.5, VIOLET }, { 0, -42, 110, 0.5, VIOLET }, { -55, 0, 0.5, 84, CYAN }, { 55, 0, 0.5, 84, CYAN } }) do
		deco({ Name = "PlazaEdgeLED", Size = Vector3.new(e[3], 0.08, e[4]), Position = G(px + e[1], 0.14, pz + e[2]), Material = Enum.Material.Neon, Color = e[5] }, look)
	end
	local updateBoard = leaderboard(look, G(px - 36, 0, pz + 26), G(px, 0, pz - 10))
	local c = L.court
	signpost(look, G(px + 44, 0, pz - 9), {
		{ text = "SPECTRA DOME", target = L.stadiumPad, color = CYAN },
		{ text = "STREET COURT", target = L.courtPad, color = GOLD },
		{ text = "FASHION DISTRICT", target = G(px - 56, 0, pz - 64), color = PINK },
		{ text = "PLAYER AGENCY", target = G(px + 56, 0, pz - 64), color = GOLD, soon = true },
		{ text = "ACADEMY", target = G(px, 0, pz - 70), color = Color3.fromRGB(70, 255, 150), soon = true },
		{ text = "CAR DISTRICT", target = G(px + 200, 0, pz - 40), color = CYAN, soon = true },
		{ text = "WOHNVIERTEL", target = G(px - 200, 0, pz + 20), color = VIOLET, soon = true },
	})

	-- Weg zum Stadion: Fahnen
	for _, sx in ipairs({ -1, 1 }) do
		for k, z in ipairs({ -152, -164 }) do
			flagPole(look, G(L.stadiumPad.X + sx * 16.5, 0, z), (k + (sx > 0 and 1 or 0)) % 2 == 0 and Color3.fromRGB(120, 24, 48) or Color3.fromRGB(70, 26, 130))
		end
	end

	-- Dome-Fassade mit Videowand
	local main, ticker = domeFacade(look, gy)

	-- Street Court: Graffiti-Wände und Zuschauer auf den Stufen
	local ox, oz, hl, hw = c.origin.X, c.origin.Z, c.halfLength, c.halfWidth
	local east = part({ Name = "GraffitiWallEast", Size = Vector3.new(1.2, 10, 44), Position = G(ox + hl + 9, 5, oz), Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(90, 92, 100) }, look)
	graffiti(east, Enum.NormalId.Left, 11, {
		{ text = "ULTIMATE", x = 0.32, y = 0.34, w = 0.5, h = 0.38, font = Enum.Font.PermanentMarker, color = GOLD, rot = -6, stroke = 4 },
		{ text = "PITCH", x = 0.36, y = 0.7, w = 0.42, h = 0.4, font = Enum.Font.PermanentMarker, color = PINK, rot = -4, stroke = 4 },
		{ text = "UP", x = 0.78, y = 0.48, w = 0.2, h = 0.7, font = Enum.Font.Bangers, color = Color3.fromRGB(40, 210, 255), rot = 8, stroke = 5 },
		{ text = "#10", x = 0.92, y = 0.85, w = 0.1, h = 0.22, font = Enum.Font.PermanentMarker, color = WHITE },
	})
	local south = part({ Name = "GraffitiWallSouth", Size = Vector3.new(64, 9, 1.2), Position = G(ox, 4.5, oz - hw - 14), Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(90, 92, 100) }, look)
	graffiti(south, Enum.NormalId.Back, 23, {
		{ text = "VOM BOLZPLATZ", x = 0.27, y = 0.36, w = 0.46, h = 0.4, font = Enum.Font.Bangers, color = WHITE, rot = -3, stroke = 4 },
		{ text = "ZUM SUPERSTAR", x = 0.31, y = 0.74, w = 0.5, h = 0.4, font = Enum.Font.Bangers, color = GOLD, rot = -3, stroke = 4 },
		{ text = "STREET", x = 0.76, y = 0.45, w = 0.34, h = 0.55, font = Enum.Font.PermanentMarker, color = Color3.fromRGB(70, 255, 150), rot = 7, stroke = 4 },
	})
	local SPECTATOR_KITS = {
		{ shirt = Color3.fromRGB(20, 20, 24), legs = Color3.fromRGB(20, 20, 24) },
		{ shirt = Color3.fromRGB(235, 235, 240), legs = Color3.fromRGB(30, 34, 52), head = Color3.fromRGB(240, 200, 160) },
		{ shirt = Color3.fromRGB(190, 30, 40), legs = Color3.fromRGB(20, 20, 24), head = Color3.fromRGB(120, 80, 50) },
		{ shirt = Color3.fromRGB(110, 60, 200), legs = Color3.fromRGB(235, 235, 240), head = Color3.fromRGB(230, 180, 140) },
	}
	task.spawn(function()
		for k, s in ipairs({ { -14, 1 }, { -5, 2 }, { 6, 1 }, { 15, 2 } }) do
			local z = oz - hw - 3 - s[2] * 3
			local top = 0.6 + (s[2] - 1) * 1.2 + 0.6
			local pos = G(ox + s[1], top, z)
			figure(look, CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)), SPECTATOR_KITS[k], { name = "Spectator" })
		end
	end)

	-- Fashion District: Schaufenster mit Puppen in Trikots und Sneakern, Unterläden
	local facadeZ = pz - 64 + 13
	local fx = px - 56
	local _, floorY = showcase(look, fx, facadeZ, gy, PINK)
	local KITS = {
		{ shirt = Color3.fromRGB(16, 16, 20), legs = Color3.fromRGB(16, 16, 20), head = Color3.fromRGB(210, 212, 220), chest = "10" },
		{ shirt = Color3.fromRGB(240, 240, 245), legs = Color3.fromRGB(90, 40, 170), head = Color3.fromRGB(210, 212, 220), chest = "7" },
		{ shirt = Color3.fromRGB(170, 24, 40), legs = Color3.fromRGB(16, 16, 20), head = Color3.fromRGB(210, 212, 220), chest = "9" },
	}
	task.spawn(function()
		for k, dx in ipairs({ -11, 0, 11 }) do
			local pos = Vector3.new(fx + dx, floorY, facadeZ + 1.7)
			figure(look, CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)), KITS[k], { name = "Mannequin", faceless = true, chest = KITS[k].chest })
		end
	end)
	for k, dx in ipairs({ -15.2, -6, 5.2, 14.4 }) do
		sneaker(look, Vector3.new(fx + dx, floorY, facadeZ + 1.6), SPRAY[k], k % 2 == 1 and math.pi / 2 - 0.3 or -math.pi / 2 + 0.3) -- Seitenansicht zur Straße
	end
	subSign(look, CFrame.lookAt(G(fx - 12, 17.15, facadeZ + 0.4), G(fx - 12, 17.15, facadeZ + 5)), "SNEAKER STORE", PINK, 14)
	subSign(look, CFrame.lookAt(G(fx + 12, 17.15, facadeZ + 0.4), G(fx + 12, 17.15, facadeZ + 5)), "TRIKOT-SHOP", PINK, 14)
	subSign(look, CFrame.lookAt(G(fx, 17.15, facadeZ + 0.4), G(fx, 17.15, facadeZ + 5)), "JETZT GEÖFFNET", WHITE, 8)

	-- Player Agency: Büro-Schaufenster, Agent, Taktiktafel, Sportwagen davor
	local ax = px + 56
	local _, aFloor = showcase(look, ax, facadeZ, gy, GOLD)
	local deskPos = Vector3.new(ax - 6, aFloor, facadeZ + 1.4)
	local desk = Props.place("AgencyDesk", CFrame.lookAt(deskPos, deskPos + Vector3.new(0, 0, 1)), look,
		{ Name = "AgencyDesk", CanCollide = false, CanQuery = false, CanTouch = false }) -- Front zur Straße, hinter der Scheibe
		or deco({ Name = "AgencyDesk", Size = Vector3.new(8, 2.4, 1.6), Position = deskPos + Vector3.new(0, 1.2, 0), Material = Enum.Material.Wood,
			Color = Color3.fromRGB(60, 40, 30) }, look)
	tag(desk, "UP_CityDetail")
	local board = deco({ Name = "TacticsBoard", Size = Vector3.new(9, 5, 0.2), Position = Vector3.new(ax + 9, aFloor + 4.5, facadeZ + 0.4), Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 110, 60) }, look)
	tag(board, "UP_CityDetail")
	local tg = surface(board, Enum.NormalId.Back, 24, 1.1)
	frame(tg, { Position = UDim2.fromScale(0.495, 0.05), Size = UDim2.fromScale(0.01, 0.9), BackgroundColor3 = WHITE })
	for _, d in ipairs({ { 0.1, 0.5 }, { 0.25, 0.2 }, { 0.25, 0.8 }, { 0.4, 0.35 }, { 0.4, 0.65 }, { 0.6, 0.5 }, { 0.75, 0.25 }, { 0.75, 0.75 }, { 0.88, 0.5 } }) do
		local dot = frame(tg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(d[1], d[2]), Size = UDim2.fromScale(0.05, 0.09),
			BackgroundColor3 = d[1] < 0.5 and GOLD or WHITE })
		Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)
	end
	local agentPos = Vector3.new(ax - 1, aFloor, facadeZ + 1.7)
	task.spawn(figure, look, CFrame.lookAt(agentPos, agentPos + Vector3.new(0, 0, 1)), { shirt = Color3.fromRGB(20, 22, 30),
		legs = Color3.fromRGB(20, 22, 30), head = Color3.fromRGB(200, 150, 110) }, { name = "Agent" })
	subSign(look, CFrame.lookAt(G(ax, 17.15, facadeZ + 0.4), G(ax, 17.15, facadeZ + 5)), "VERTRÄGE  ·  TRANSFERS  ·  KARRIERE  ·  BALD", GOLD, 34)
	car(look, CFrame.new(G(px + 70, 0, pz - 43)) * CFrame.Angles(0, math.rad(80), 0), Color3.fromRGB(240, 190, 20), CYAN, "SportCarGold")
	car(look, CFrame.new(G(px + 87, 0, pz - 45)) * CFrame.Angles(0, math.rad(100), 0), Color3.fromRGB(200, 20, 30), VIOLET, "SportCarViolet")

	look.Parent = city

	-- Live-Inhalte: Rangliste (alle 3 s) und Videowand (Spruch / Top-Spieler im Wechsel, Ticker mit dem Stadionstatus)
	task.spawn(function()
		local tick = 0
		while look.Parent do
			local list = {}
			for _, p in ipairs(Players:GetPlayers()) do
				table.insert(list, { name = p.DisplayName, coins = p:GetAttribute("PitchCoins") or 0, stage = p:GetAttribute("CareerStage") or "" })
			end
			table.sort(list, function(a, b) return a.coins > b.coins end)
			if tick % 3 == 0 then updateBoard(list) end
			local top = list[1]
			local slides = { "VOM BOLZPLATZ ZUM SUPERSTAR" }
			if top and top.coins > 0 then table.insert(slides, "TOP-SPIELER: " .. string.upper(top.name) .. "  ·  " .. top.coins .. " COINS") end
			local text = slides[math.floor(tick / 6) % #slides + 1]
			if main.Text ~= text then main.Text = text end
			local ph = state and state:GetAttribute("Phase") or "Lobby"
			local live
			if ph == "Playing" or ph == "Goal" or ph == "GoldenGoal" then
				local t = state:GetAttribute("TimeLeft") or 0
				live = string.format("LIVE   ROT  %d : %d  BLAU   ·   %d:%02d", state:GetAttribute("RedScore") or 0, state:GetAttribute("BlueScore") or 0,
					math.floor(t / 60), t % 60)
			elseif ph == "Intermission" then
				live = string.format("ANPFIFF IN %d S   ·   5 GEGEN 5", state:GetAttribute("TimeLeft") or 0)
			else
				live = "5 GEGEN 5   ·   PAD VOR DEM EINGANG BETRETEN"
			end
			if ticker.Text ~= live then ticker.Text = live end
			tick += 1
			task.wait(1)
		end
	end)
	return look
end

return CityLook
