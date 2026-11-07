-- UltimatePitch v0.4 · A/B-Probe für einen alternativen Publikumssektor (nur Test-Place, nicht Teil des Builds).
-- Variante B ersetzt im Unterrang von 6 Segmenten (hinter dem linken Tor) die Einzelteile (Sitzreihe, CrowdBody,
-- Figuren) durch je EINE schräge Platte mit SurfaceGui: pro Reihe 7 stilisierte Figuren (Trikot-Rechteck + runder
-- Kopf) aus Frames. Keine externen Assets. Variante A (Teile) bleibt erhalten und wird nur verschoben, sodass ein
-- Client per Umschalten beide Varianten unter gleichen Bedingungen messen kann.
-- Aufruf in der laufenden Test-Session (Server): require-frei per execute_luau einfügen; legt _G.UP_CrowdAB an.
local CollectionService = game:GetService("CollectionService")

local INNER_A, INNER_B = 118, 74
local SEGMENTS, LOWER_ROWS, ROW_DEPTH = 48, 8, 2.8
local GY = 1
local SECTOR = { 22, 23, 24, 25, 26, 27 } -- um θ = π, also hinter dem linken Tor (-X)
local FAN_COLORS = {
	Color3.fromRGB(215, 40, 40), Color3.fromRGB(40, 90, 230), Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(255, 200, 40), Color3.fromRGB(30, 30, 30), Color3.fromRGB(40, 200, 220),
}
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(141, 92, 62), Color3.fromRGB(96, 62, 44) }

local function ring(theta, d)
	return Vector3.new((INNER_A + d) * math.cos(theta), 0, (INNER_B + d) * math.sin(theta))
end
local function rowRadius(row) return (row - 0.5) * ROW_DEPTH end
local function rowTop(row) return GY + 1.5 + row * 1.5 end

local dome = workspace:FindFirstChild("UltimatePitch"):FindFirstChild("SpectraDome", true)
local crowd = dome:FindFirstChild("Crowd")

-- Variante A: Unterrang-Teile der Sektor-Segmente einsammeln (Winkel der Teilposition)
local inSector = {}
for _, i in ipairs(SECTOR) do inSector[i] = true end
local partsA = {}
for _, p in ipairs(crowd:GetChildren()) do
	if p:IsA("BasePart") then
		local pos = p.Position
		local theta = math.atan2(pos.Z / INNER_B, pos.X / INNER_A) % (2 * math.pi)
		local seg = math.floor(theta / (2 * math.pi) * SEGMENTS)
		local lower = pos.Y < GY + 16
		if inSector[seg] and lower then table.insert(partsA, p) end
	end
end

-- Variante B: eine Platte pro Segment mit SurfaceGui-Figuren
local folderB = Instance.new("Folder")
folderB.Name = "UP_CrowdAB_B"
local rng = Random.new(20261107)
local frames = 0
for _, i in ipairs(SECTOR) do
	local t1, t2 = i / SEGMENTS * math.pi * 2, (i + 1) / SEGMENTS * math.pi * 2
	local tm = (t1 + t2) / 2
	local d0, d1 = rowRadius(1) - 1.2, rowRadius(LOWER_ROWS) + 1.2
	local p0 = ring(tm, d0) + Vector3.new(0, rowTop(1) + 0.6, 0)
	local p1 = ring(tm, d1) + Vector3.new(0, rowTop(LOWER_ROWS) + 2.4, 0)
	local dm = (d0 + d1) / 2
	local width = (ring(t2, dm) - ring(t1, dm)).Magnitude + 0.3
	local slope = (p1 - p0).Unit
	local tangent = (ring(t2, dm) - ring(t1, dm)).Unit
	local toField = -Vector3.new(math.cos(tm) / INNER_A, 0, math.sin(tm) / INNER_B).Unit
	-- fromMatrix(pos, X, Y, Z): Front (-Z) soll zum Feld zeigen
	if tangent:Cross(slope):Dot(toField) > 0 then tangent = -tangent end
	local plate = Instance.new("Part")
	plate.Name = "CrowdPlate"
	plate.Anchored, plate.CanCollide, plate.CanQuery, plate.CanTouch, plate.CastShadow = true, false, false, false, false
	plate.Material = Enum.Material.Fabric
	plate.Color = Color3.fromRGB(26, 30, 46)
	plate.Size = Vector3.new(width, (p1 - p0).Magnitude, 0.2)
	plate.CFrame = CFrame.fromMatrix((p0 + p1) / 2, tangent, slope)
	CollectionService:AddTag(plate, "UP_Crowd")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.LightInfluence = 1
	gui.Parent = plate
	local per = 7
	for row = 1, LOWER_ROWS do
		local y = 1 - row / LOWER_ROWS -- Reihe 1 (vorn) unten
		for k = 1, per do
			if rng:NextNumber() < 0.88 then
				local x = (k - 0.5) / per + rng:NextNumber(-0.03, 0.03)
				local body = Instance.new("Frame")
				body.AnchorPoint = Vector2.new(0.5, 1)
				body.Position = UDim2.fromScale(x, y + 0.92 / LOWER_ROWS)
				body.Size = UDim2.new(0, rng:NextInteger(10, 13), 0.55 / LOWER_ROWS, 0)
				body.BorderSizePixel = 0
				body.BackgroundColor3 = FAN_COLORS[rng:NextInteger(1, #FAN_COLORS)]
				body.Parent = gui
				local head = Instance.new("Frame")
				head.AnchorPoint = Vector2.new(0.5, 1)
				head.Position = UDim2.fromScale(0.5, 0)
				head.Size = UDim2.fromOffset(8, 8)
				head.BorderSizePixel = 0
				head.BackgroundColor3 = SKIN[rng:NextInteger(1, #SKIN)]
				Instance.new("UICorner", head).CornerRadius = UDim.new(1, 0)
				head.Parent = body
				frames += 2
			end
		end
	end
	plate.Parent = folderB
end
folderB.Parent = dome

local instB = #folderB:GetDescendants()
local instA = 0
for _, p in ipairs(partsA) do instA += 1 + #p:GetDescendants() end
workspace:SetAttribute("UP_CrowdAB", string.format("A_teile=%d A_instanzen=%d | B_platten=%d B_frames=%d B_instanzen=%d",
	#partsA, instA, #folderB:GetChildren(), frames, instB))
_G.UP_CrowdAB = { partsA = partsA, folderB = folderB }
return workspace:GetAttribute("UP_CrowdAB")
