-- UltimatePitch · City Look, Client-Seite (M4, ModuleScript unter UltimatePitchClient)
-- Rein lokale Darstellung der vom Server gebauten Stadt-Optik (CityLook.lua):
--   "UP_CityDetail" (Deko ohne Kollision): auf „Niedrig“ lokal aus der Welt genommen (spart Rendering wirklich,
--                   Ausblenden allein brachte laut Messung vom 07.11. nichts), sonst wieder eingehängt.
--   "UP_CityFX" (Partikel, Lichtkegel, Lichtquellen, dekorative SurfaceGuis): auf „Niedrig“ aus.
--   "UP_Spin" (Monument-Ball, Ring): dreht sich langsam um die senkrechte Achse, nur in Kameranähe, nicht auf „Niedrig“
--                   und nicht bei reduzierter Bewegung.
-- Andere Spieler und der Server sind davon nicht betroffen.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local CityFX = {}

local profile = "Hoch"
local stash = {} -- [Instance] = ursprünglicher Parent (auf „Niedrig“ lokal entfernte Deko)
local spins = {} -- [Model] = { pivot = CFrame, angle = number }
local SPIN_RANGE = 260
local reducedMotion = function() return false end -- vom Client gesetzt (AuroraFX.reducedMotion)

-- Reduzierte Bewegung (Barrierefreiheit): hält die Drehung an, solange die Einstellung aktiv ist
function CityFX.setReducedMotion(getter)
	reducedMotion = getter
end

local function styleDetail(inst)
	if profile == "Niedrig" then
		if inst.Parent and not stash[inst] then
			stash[inst] = inst.Parent
			inst.Parent = nil
		end
	elseif stash[inst] then
		inst.Parent = stash[inst]
		stash[inst] = nil
	end
end

local function styleFX(inst)
	if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Light") or inst:IsA("SurfaceGui") then
		inst.Enabled = profile ~= "Niedrig"
	end
end

function CityFX.applyProfile(name)
	profile = name
	if name == "Niedrig" then
		for _, inst in ipairs(CollectionService:GetTagged("UP_CityDetail")) do styleDetail(inst) end
	else
		for inst, parent in pairs(stash) do
			stash[inst] = nil
			if parent.Parent ~= nil or parent == workspace then inst.Parent = parent end
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged("UP_CityFX")) do styleFX(inst) end
end

local function addSpin(m)
	if m:IsA("Model") and not spins[m] then
		spins[m] = { pivot = m:GetPivot(), angle = 0 }
	end
end

-- Später eintreffende Teile (Replikation, Figuren werden serverseitig nachgeladen) gleich passend behandeln.
-- Das Entfernen geschieht verzögert, nicht mitten im Hinzufügen-Signal.
CollectionService:GetInstanceAddedSignal("UP_CityDetail"):Connect(function(inst)
	if profile == "Niedrig" then task.defer(styleDetail, inst) end
end)
CollectionService:GetInstanceAddedSignal("UP_CityFX"):Connect(styleFX)
CollectionService:GetInstanceAddedSignal("UP_Spin"):Connect(addSpin)
for _, m in ipairs(CollectionService:GetTagged("UP_Spin")) do addSpin(m) end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	if profile == "Niedrig" or reducedMotion() then return end
	acc += dt
	if acc < 1 / 30 then return end -- 30 Schritte pro Sekunde genügen für die langsame Drehung
	local step = acc
	acc = 0
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	for m, s in pairs(spins) do
		if m.Parent then
			local pos = s.pivot.Position
			if not camPos or (camPos - pos).Magnitude < SPIN_RANGE then
				s.angle = (s.angle + math.rad(m:GetAttribute("SpinSpeed") or 10) * step) % (2 * math.pi)
				m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, s.angle, 0) * (CFrame.new(pos):Inverse() * s.pivot))
			end
		elseif not m:IsDescendantOf(game) and not stash[m] then
			spins[m] = nil -- vom Server entfernt
		end
	end
end)

return CityFX
