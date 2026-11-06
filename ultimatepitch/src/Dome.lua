-- UltimatePitch · SPECTRA DOME (ModuleScript unter UltimatePitchServer)
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
					for k = 1, 3 do
						if rng:NextNumber() < 0.75 then
							local a = t1 + (t2 - t1) * (k - 0.5) / 3
							local pos = ring(a, d) + Vector3.new(0, top + 1.5, 0)
							local fan = deco({
								Name = "Fan", Size = Vector3.new(1.1, 2.1, 1.1),
								CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
								Color = FAN_COLORS[rng:NextInteger(1, #FAN_COLORS)], Material = Enum.Material.SmoothPlastic,
							}, crowd)
							tagCrowd(fan)
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
			Material = Enum.Material.Glass, Transparency = 0.45, Color = Color3.fromRGB(26, 34, 52),
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
			part({ Name = "Column", Size = Vector3.new(2, ROOF_Y - gy, 2), Position = outer + Vector3.new(0, (ROOF_Y + gy) / 2, 0),
				Material = Enum.Material.Metal, Color = STEEL }, roof)
			local lampPos = inner + Vector3.new(0, ROOF_Y - 2.6, 0)
			local lamp = deco({
				Name = "Floodlight", Size = Vector3.new(5, 1.2, 3),
				CFrame = CFrame.lookAt(lampPos, Vector3.new(0, gy, 0)),
				Material = Enum.Material.Neon, Color = Color3.fromRGB(235, 248, 255),
			}, roof)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Front
			light.Brightness = 2.4
			light.Range = 60
			light.Angle = 70
			light.Color = Color3.fromRGB(220, 240, 255)
			light.Parent = lamp
		end
	end

	-- Spielertunnel hinter der Lücke im Unterrang
	local tunnelMid = ring((12.5 / SEGMENTS) * math.pi * 2, 8)
	part({ Name = "Tunnel", Size = Vector3.new(14, 9, 18), CFrame = CFrame.lookAt(tunnelMid + Vector3.new(0, gy + 4.5, 0), Vector3.new(0, gy + 4.5, 0)),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 12, 18) }, bowl)
	deco({ Name = "TunnelLight", Size = Vector3.new(10, 0.4, 0.4), CFrame = CFrame.lookAt(tunnelMid + Vector3.new(0, gy + 8.6, -2), Vector3.new(0, gy + 8.6, 0)),
		Material = Enum.Material.Neon, Color = CYAN }, led)

	-- Anzeigetafel über dem Oberrang hinter dem linken Tor, zeigt Spielstand und Zeit aus State
	local boardPos = Vector3.new(-(INNER_A + 24), gy + 40, 0)
	local board = part({ Name = "Scoreboard", Size = Vector3.new(2, 16, 44), CFrame = CFrame.lookAt(boardPos, Vector3.new(0, gy + 40, 0)),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(10, 12, 20) }, dome)
	local frameGlow = deco({ Name = "ScoreboardFrame", Size = Vector3.new(0.4, 17, 45), CFrame = board.CFrame * CFrame.new(0, 0, -0.9),
		Material = Enum.Material.Neon, Color = CYAN, Transparency = 0.2 }, led)
	frameGlow.Name = "ScoreboardFrame"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Brightness = 2
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

	dome.Parent = root
	return dome
end

return Dome
