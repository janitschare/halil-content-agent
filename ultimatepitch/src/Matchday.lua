-- UltimatePitch · Matchday-Atmosphäre (ModuleScript unter UltimatePitchClient)
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

local opts = { reducedMotion = function() return false end, fxScale = function() return 1 end, profile = function() return "Hoch" end }

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
	sub.Text = "ANPFIFF  ·  SPECTRA DOME"
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
local function pyro(goalX, color)
	local scale = opts.fxScale()
	for _, z in ipairs({ -30, -17, 17, 30 }) do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(goalX, 1.5, z)
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
			cameraFlight()
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
			-- Rot greift +X an, Blau −X: Pyro am getroffenen Tor
			local goalX = (team == "Rot" and 1 or -1) * (HALF_LENGTH + 4)
			pyro(goalX, color)
			flashLEDs(color)
			crowdJump()
		end
		lastSeq = seq
	end)
	-- Respawn während des Intros: Tweens stoppen und Kamera sofort freigeben
	Players.LocalPlayer.CharacterAdded:Connect(abortFlight)
end

return Matchday
