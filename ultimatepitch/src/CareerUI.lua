-- UltimatePitch · Karriere-Anzeige (ModuleScript unter UltimatePitchClient)
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
	local chip = corner(make("Frame", { Position = UDim2.new(0, 16, 0.4, 0), Size = UDim2.fromOffset(196, 52),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.15 }, gui), 8)
	make("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.35 }, chip)
	local coinIcon = corner(make("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = GOLD, Rotation = 45 }, chip), 4)
	make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = -45,
		Text = "P", TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = PANEL }, coinIcon)
	local coinLabel = make("TextLabel", { Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -48, 0, 28), TextSize = 22,
		Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = "0" }, chip)
	local stageLabel = make("TextLabel", { Position = UDim2.fromOffset(10, 31), Size = UDim2.new(1, -20, 0, 16), TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.2, Text = "" }, chip)

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
	local toastBox = make("Frame", { Position = UDim2.new(0, 16, 0.4, 60), Size = UDim2.fromOffset(340, 240),
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
