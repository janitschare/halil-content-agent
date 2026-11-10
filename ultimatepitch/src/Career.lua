-- UltimatePitch · Karriere, Pitch Coins, Scout und Shop (ModuleScript unter UltimatePitchServer)
-- Alles serverseitig: Coins, Karrierestufe, Besitz und Ausrüstung führt nur der Server und spiegelt sie in
-- Player-Attribute (nur lesend für Clients) und leaderstats. Clients senden über RemoteEvent "Career" lediglich
-- Absichten (Scout-Angebot annehmen, Artikel kaufen/anlegen); jede Absicht wird auf Stufe, Preis, Guthaben,
-- Besitz und Nähe zum NPC/Laden geprüft und gedrosselt.
-- SPEICHERSTAND: bewusst noch nicht dauerhaft (kein DataStore, Freigabe ausstehend). Fortschritt gilt pro Sitzung.
-- Keine Robux, keine Zufallspakete: Coins gibt es nur fürs Spielen.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

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

local data = {}       -- [Player] = { coins, stage, owned = {id=true}, equipped = {slot=id}, matches, goals }
local lastRequest = {}
local remote, scoutRoot, shopRoot

local function list(t)
	local out = {}
	for k, v in pairs(t) do
		if v == true then table.insert(out, k) else table.insert(out, v) end
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function sync(plr)
	local d = data[plr]
	if not d then return end
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

local function onPlayer(plr)
	data[plr] = { coins = 0, stage = 1, owned = {}, equipped = {}, matches = 0, goals = 0 }
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = ls
	local stage = Instance.new("StringValue")
	stage.Name = "Stufe"
	stage.Parent = ls
	ls.Parent = plr
	sync(plr)
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
	remote.OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(plr)
		data[plr] = nil
		lastRequest[plr] = nil
	end)
end

return Career
