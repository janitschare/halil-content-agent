-- UltimatePitch v0.5 · 2-Client-Test KickAnim (nur Test-Place, nicht Teil des Builds).
-- Ablauf: 2 Spieler im laufenden Match -> Startsignal -> warten, bis BEIDE Clients "go" melden (simulierte
-- Clients laufen im Hintergrund teils stark gedrosselt) -> 30 s lang dem ersten Spieler alle 3 s den Ball
-- vorlegen (seine Sonde spielt dann selbst einen echten Pass über das Kick-RemoteEvent) -> Stoppsignal ->
-- bis zu 60 s auf die Endberichte warten -> StudioTestService-Lauf mit strengem Ergebnis beenden.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
-- true = Negativkontrolle: Clients schalten die Kickanimation ab (Ergebnis muss dann rot sein)
local NEG_CONTROL = false

local folder = Instance.new("Folder")
folder.Name = "UP_Sec"
local report = Instance.new("RemoteEvent")
report.Name = "Report"
report.Parent = folder
folder.Parent = RS

local tStart = nil
local reports, arrived = {}, {}
report.OnServerEvent:Connect(function(plr, key, text)
	local k = plr.Name .. ":" .. tostring(key)
	reports[k] = tostring(text)
	arrived[k] = tStart and string.format("%.1f", os.clock() - tStart) or "vor Start"
end)

-- Diagnose: kommen die Pass-Anfragen des Passers am Server an?
local passReq = 0
RS:WaitForChild("UltimatePitch"):WaitForChild("Kick").OnServerEvent:Connect(function(_, kind)
	if kind == "Pass" then passReq += 1 end
end)

local function finish(result)
	pcall(function() game:GetService("StudioTestService"):EndTest(result) end)
end

local function waitFor(names, suffix, timeout)
	local t = os.clock()
	while os.clock() - t < timeout do
		local all = true
		for _, n in ipairs(names) do
			if not reports[n .. suffix] then all = false end
		end
		if all then return true end
		task.wait(0.5)
	end
	return false
end

task.spawn(function()
	local t0 = os.clock()
	while #Players:GetPlayers() < 2 and os.clock() - t0 < 120 do task.wait(0.5) end
	local State = RS:WaitForChild("UltimatePitch"):WaitForChild("State")
	while State:GetAttribute("Phase") ~= "Playing" and os.clock() - t0 < 180 do task.wait(0.5) end
	local plist = Players:GetPlayers()
	if #plist < 2 or State:GetAttribute("Phase") ~= "Playing" then
		finish({ ok = false, why = "kein Match mit 2 Spielern", players = #plist })
		return
	end
	local names = { plist[1].Name, plist[2].Name }
	local first = plist[1]
	folder:SetAttribute("NegControl", NEG_CONTROL)
	folder:SetAttribute("Passer", first.Name)
	tStart = os.clock()
	folder:SetAttribute("Start", true)
	local bothGo = waitFor(names, ":go", 90)
	local goWait = os.clock() - tStart
	local ball = workspace.UltimatePitch.Ball
	local feeds = 0
	local tEnd = os.clock() + 30
	while os.clock() < tEnd do
		local root = first.Character and first.Character:FindFirstChild("HumanoidRootPart")
		if root and (State:GetAttribute("Phase") == "Playing" or State:GetAttribute("Phase") == "GoldenGoal") then
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
			ball.AssemblyLinearVelocity = Vector3.zero
			ball.CFrame = CFrame.new(root.Position.X, 2.1, root.Position.Z) + look * 2.6
			feeds += 1
		end
		task.wait(3)
	end
	folder:SetAttribute("Stop", true)
	waitFor(names, ":kick", 60)

	-- Grün nur mit Endberichten beider Spieler, ohne Clientfehler, mit sichtbar animierten Kicks auf
	-- jedem Client und mindestens einem animierten Kick des jeweils anderen Spielers (Netzwerkpfad).
	local why = {}
	if not bothGo then table.insert(why, "nicht beide Clients bereit") end
	for _, p in ipairs(plist) do
		local r = reports[p.Name .. ":kick"]
		if not r then
			table.insert(why, p.Name .. ": kein Endbericht")
		else
			-- Bewertet wird die Kicksignatur (> 1,1 rad), nicht die grobe 0,3-Schwelle: die Negativkontrolle
			-- zeigte, dass die Laufanimation allein ~43 % der Ereignisse über 0,3 rad bringt.
			local sig = tonumber(r:match(" kicksignatur=(%d+)")) or 0
			local errors = tonumber(r:match("fehler=(%d+)")) or 0
			local fps = tonumber(r:match("fps=([%d%.]+)")) or 0
			if fps < 2 then table.insert(why, p.Name .. ": Client gedrosselt (fps " .. fps .. "), Lauf ungültig") end
			if sig == 0 then table.insert(why, p.Name .. ": keine Kicksignatur") end
			if errors > 0 then table.insert(why, p.Name .. ": " .. errors .. " Fehler") end
			if p ~= first and (tonumber(r:match("anderer_kicksignatur=(%d+)")) or 0) == 0 then
				table.insert(why, p.Name .. ": Pass des anderen Spielers nicht animiert gesehen")
			end
		end
	end
	local result = { ok = #why == 0, why = table.concat(why, "; "), passer = first.Name, feeds = feeds,
		passRequests = passReq, goWait = string.format("%.1f", goWait) }
	for k, v in pairs(reports) do result[k] = v end
	for k, v in pairs(arrived) do result["t_" .. k] = v end
	finish(result)
end)
