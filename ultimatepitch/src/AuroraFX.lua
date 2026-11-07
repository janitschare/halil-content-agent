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
	end, workspace:FindFirstChild("UltimatePitch") and workspace.UltimatePitch:FindFirstChild("Ball"))
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
