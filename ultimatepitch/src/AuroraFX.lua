-- UltimatePitch · AURORA BREAK Darstellung (ModuleScript unter UltimatePitchClient)
-- Reine Optik: reagiert auf Server-Ereignisse (AuroraWindup/AuroraKick/AuroraCancel, GoalSeq) und entscheidet nichts.
-- Kickanimation prozedural über R15-Motor6D.Transform (keine hochgeladene Animation), Kick-Marker bei Anlaufende.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local AuroraFX = {}
AuroraFX.reducedMotion = false
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

-- Posen als Winkel (rad) je Gelenk; Zeit relativ zum Kick-Marker (0 = Ballkontakt)
local POSES = {
	{ t = -0.30, hip = 0, knee = 0, waist = 0, lsh = 0, rsh = 0 },
	{ t = -0.10, hip = 0.95, knee = -1.25, waist = 0.35, lsh = -0.9, rsh = 0.7 },   -- Ausholen
	{ t = 0.00, hip = -1.35, knee = -0.15, waist = -0.25, lsh = 0.5, rsh = -0.6 },  -- Kontakt (Marker "Kick")
	{ t = 0.12, hip = -1.6, knee = 0, waist = -0.35, lsh = 0.7, rsh = -0.8 },       -- Durchschwung
	{ t = 0.45, hip = 0, knee = 0, waist = 0, lsh = 0, rsh = 0 },                   -- Ausschwingen
}

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
local function playKick(char, windup, onMarker)
	stopKick(char)
	local joints = {
		hip = joint(char, "RightUpperLeg", "RightHip"),
		knee = joint(char, "RightLowerLeg", "RightKnee"),
		waist = joint(char, "UpperTorso", "Waist"),
		lsh = joint(char, "LeftUpperArm", "LeftShoulder"),
		rsh = joint(char, "RightUpperArm", "RightShoulder"),
	}
	local start = os.clock()
	local fired = false
	local function step()
		local t = os.clock() - start - windup
		if not fired and t >= 0 then
			fired = true
			onMarker("Kick")
		end
		if not char.Parent or t > POSES[#POSES].t then stopKick(char) return end
		local pose = sample(t)
		if joints.hip then joints.hip.Transform = CFrame.Angles(pose.hip, 0, 0) end
		if joints.knee then joints.knee.Transform = CFrame.Angles(pose.knee, 0, 0) end
		if joints.waist then joints.waist.Transform = CFrame.Angles(0, pose.waist, 0) end
		if joints.lsh then joints.lsh.Transform = CFrame.Angles(0, 0, pose.lsh) end
		if joints.rsh then joints.rsh.Transform = CFrame.Angles(0, 0, pose.rsh) end
	end
	active[char] = { conn = preSim:Connect(step), joints = joints }
	return joints.hip ~= nil
end
AuroraFX.playKick = playKick

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
	pe.Rate = own and 90 or 35
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
function AuroraFX.windup(userId, windup)
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
	end)
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
	if own then AuroraFX.speedLines(36, 0.45) end

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
	if own then cameraPush(14) elseif root and workspace.CurrentCamera
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
